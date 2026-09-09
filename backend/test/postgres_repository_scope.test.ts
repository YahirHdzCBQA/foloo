/** Confirms the PostgreSQL adapter always binds the authenticated workspace. */

import assert from "node:assert/strict";
import test from "node:test";

import type pg from "pg";

import { PostgresFolooRepository } from "../src/persistence/postgres_repository.js";

test("maps Cognito subject to the provisioned account/workspace", async () => {
  const queries: { sql: string; values?: unknown[] }[] = [];
  const pool = {
    query: async (sql: string, values?: unknown[]) => {
      queries.push({ sql, values });
      return {
        rows: [
          {
            user_id: "user-a",
            account_id: "account-a",
            workspace_id: "workspace-a",
          },
        ],
      };
    },
  } as unknown as pg.Pool;
  const principal = await new PostgresFolooRepository(pool).resolvePrincipal(
    "cognito-sub-a",
  );
  assert.deepEqual(principal, {
    subject: "cognito-sub-a",
    userId: "user-a",
    accountId: "account-a",
    workspaceId: "workspace-a",
  });
  assert.deepEqual(queries[0]?.values, ["cognito-sub-a"]);
});

test("scopes lead-media reads by workspace and lead UUID", async () => {
  let values: unknown[] | undefined;
  const pool = {
    query: async (_sql: string, parameters?: unknown[]) => {
      values = parameters;
      return { rows: [] };
    },
  } as unknown as pg.Pool;
  await new PostgresFolooRepository(pool).listLeadMedia(
    {
      subject: "subject-a",
      userId: "user-a",
      accountId: "account-a",
      workspaceId: "workspace-a",
    },
    "lead-b",
  );
  assert.deepEqual(values, ["workspace-a", "lead-b"]);
});
