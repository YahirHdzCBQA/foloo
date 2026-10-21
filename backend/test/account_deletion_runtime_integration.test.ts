/** Synthetic integration coverage for inactive STORE-02 production adapters. */

import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import { AccountDeletionRestoreReconciler } from "../src/account_deletion/account_deletion_restore_reconciler.js";
import { AccountDeletionRuntimeGuard } from "../src/account_deletion/account_deletion_runtime_guard.js";

test("INF-18 migration fences provisioning before ensure_personal_workspace", async () => {
  const sql = await readFile(
    new URL("../migrations/009_account_deletion_barrier.sql", import.meta.url),
    "utf8",
  );
  assert.match(sql, /ADD COLUMN IF NOT EXISTS deletion_request_id uuid/u);
  assert.match(
    sql,
    /ADD COLUMN IF NOT EXISTS deletion_pending_at timestamptz/u,
  );
  assert.match(sql, /CREATE UNIQUE INDEX IF NOT EXISTS/u);
  assert.match(sql, /mark_account_deletion_pending/u);
  const lock = sql.indexOf("pg_advisory_xact_lock");
  const guard = sql.indexOf("assert_account_active(p_subject)", lock);
  const insert = sql.indexOf("INSERT INTO app_users", guard);
  assert.ok(lock >= 0 && guard > lock && insert > guard);
});

test("INF-18 pending barriers share the provisioning advisory lock", async () => {
  const sql = await readFile(
    new URL("../migrations/009_account_deletion_barrier.sql", import.meta.url),
    "utf8",
  );
  const functionStart = sql.indexOf("FUNCTION mark_account_deletion_pending");
  const functionEnd = sql.indexOf("$$ LANGUAGE plpgsql;", functionStart);
  const body = sql.slice(functionStart, functionEnd);
  assert.match(body, /pg_advisory_xact_lock\(hashtext\(p_subject\)\)/u);
  assert.match(body, /deletion_request_id = p_request_id/u);
});

test("INF-18 runtime guard denies pending and deleted identities", async () => {
  for (const state of ["deletion_pending", "deleted"] as const) {
    const runtime = new AccountDeletionRuntimeGuard({
      async evaluateIdentity() {
        return { state, deletionId: "11111111-1111-4111-8111-111111111111" };
      },
    } as never);
    await assert.rejects(runtime.assertActive("synthetic-subject"), (error) => {
      return (error as { code?: string }).code === "account_deletion_pending";
    });
  }
});

test("INF-21 restore reconciliation reapplies a fence for stale restored rows", async () => {
  const writes: unknown[][] = [];
  const pool = {
    async query(sql: string, values?: unknown[]) {
      if (sql.startsWith("SELECT cognito_sub")) {
        return {
          rowCount: 2,
          rows: [
            {
              cognito_sub: "stale-deleted",
              created_at: new Date("2032-01-01Z"),
            },
            {
              cognito_sub: "still-active",
              created_at: new Date("2032-01-01Z"),
            },
          ],
        };
      }
      writes.push(values ?? []);
      return { rowCount: 1, rows: [] };
    },
  };
  const reconciler = new AccountDeletionRestoreReconciler(
    pool as never,
    {
      async evaluateIdentity(subject: string) {
        return subject === "stale-deleted"
          ? {
              state: "deleted" as const,
              deletionId: "22222222-2222-4222-8222-222222222222",
            }
          : { state: "active" as const };
      },
    } as never,
  );
  assert.deepEqual(await reconciler.reconcile(), { inspected: 2, fenced: 1 });
  assert.equal(writes.length, 1);
  assert.deepEqual(writes[0]?.slice(0, 2), [
    "stale-deleted",
    "22222222-2222-4222-8222-222222222222",
  ]);
});
