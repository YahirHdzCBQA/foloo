/** REG-06/07: real SQL media fences on an explicitly disposable local database. */

import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { resolve } from "node:path";
import test from "node:test";
import pg from "pg";
import { ApplicationError } from "../src/application/errors.js";
import type { LeadMediaInput } from "../src/domain/models.js";
import {
  applyMigrations,
  ensureApplicationRole,
} from "../src/persistence/migration_runner.js";
import {
  PostgresFolooRepository,
  requestHash,
} from "../src/persistence/postgres_repository.js";

const socket = process.env.FOLOO_TEST_REFERENCE_PG_SOCKET;

test(
  "IMG-D10/11/16/17/19/20 PostgreSQL fences both orderings and preserves other media",
  {
    skip: !socket,
  },
  async () => {
    assert.match(socket!, /^\/(?:private\/)?tmp\/foloo-fl0251-[\w.-]+$/u);
    const pool = new pg.Pool({ host: socket, database: "postgres", max: 4 });
    try {
      const client = await pool.connect();
      try {
        await ensureApplicationRole(client, "foloo_app", "disposable");
        await ensureApplicationRole(
          client,
          "foloo_entitlement_operator",
          "disposable",
        );
      } finally {
        client.release();
      }
      assert.equal(
        (await applyMigrations(pool, resolve("migrations"))).length,
        15,
      );
      const repository = new PostgresFolooRepository(pool);
      const owner = await repository.resolvePrincipal("synthetic-media-a");
      const other = await repository.resolvePrincipal("synthetic-media-b");
      const capturedAt = "2026-11-27T16:00:00.000Z";
      const lead = async (principal: typeof owner) => {
        const id = randomUUID();
        await repository.createLead(
          principal,
          {
            id,
            capturedAt,
            origin: "direct",
            place: "Test",
            firstName: "Synthetic",
            email: "lead@example.test",
            leadType: "customer",
            interest: "high",
          },
          id,
          requestHash({ id }),
        );
        return id;
      };
      const leadId = await lead(owner);
      const otherLead = await lead(other);
      const reference = (): LeadMediaInput => ({
        id: randomUUID(),
        kind: "reference_image",
        contentType: "image/jpeg",
        byteSize: 42,
        capturedAt,
      });
      const card = { ...reference(), kind: "business_card" as const };
      const first = reference();
      const missing = reference();
      const raced = reference();
      const remove = (image: LeadMediaInput) =>
        repository.deleteLeadMedia(
          owner,
          leadId,
          image.id,
          `delete-${image.id}`,
          requestHash(image),
          "reference_image",
        );
      const isNotFound = (error: unknown) =>
        error instanceof ApplicationError && error.statusCode === 404;
      const isWrongKind = (error: unknown) =>
        error instanceof ApplicationError &&
        error.code === "media_delete_not_allowed";
      await repository.prepareLeadMedia(owner, leadId, card, "card");
      await repository.prepareLeadMedia(owner, leadId, first, "reference");
      await repository.createLeadMedia(
        owner,
        leadId,
        first,
        first.id,
        requestHash(first),
        "reference",
      );
      await assert.rejects(remove(card), isWrongKind);
      await assert.rejects(
        repository.deleteLeadMedia(
          other,
          leadId,
          first.id,
          "foreign-lead",
          requestHash(first),
          "reference_image",
        ),
        isNotFound,
      );
      await assert.rejects(
        repository.deleteLeadMedia(
          other,
          otherLead,
          first.id,
          "foreign-image",
          requestHash(first),
          "reference_image",
        ),
        isNotFound,
      );

      assert.equal((await remove(first)).replayed, false);
      assert.equal((await remove(first)).replayed, true);
      // Even distinct keys on the same deleted reference cannot grow the
      // idempotency table. Unknown IDs don't reserve anything.
      const countDeletes = async () =>
        Number(
          (
            await pool.query<{ count: string }>(
              "SELECT count(*) FROM idempotency_records WHERE workspace_id=$1 AND operation='delete-lead-media'",
              [owner.workspaceId],
            )
          ).rows[0]?.count,
        );
      assert.equal(await countDeletes(), 1);
      const rowsBefore = await repository.listLeadMedia(owner, leadId);
      await Promise.all(
        Array.from({ length: 40 }, async (_, i) => {
          await assert.rejects(
            remove(i === 0 ? missing : reference()),
            isNotFound,
          );
          const result = await repository.deleteLeadMedia(
            owner,
            leadId,
            first.id,
            `repeat-${i}`,
            requestHash(first),
            "reference_image",
          );
          assert.deepEqual(result.value, { id: first.id, deleted: true });
        }),
      );
      assert.equal(await countDeletes(), 1);
      assert.deepEqual(
        await repository.listLeadMedia(owner, leadId),
        rowsBefore,
      );
      await assert.rejects(remove(missing), isNotFound);
      await assert.rejects(
        repository.createLeadMedia(
          owner,
          leadId,
          missing,
          "unprepared-confirmation",
          requestHash(missing),
          "late",
        ),
        isNotFound,
      );
      await repository.prepareLeadMedia(owner, leadId, raced, "prepared");
      await Promise.all([
        remove(raced),
        remove(raced),
        repository
          .createLeadMedia(
            owner,
            leadId,
            raced,
            "concurrent-confirmation",
            requestHash(raced),
            "prepared",
          )
          .catch((error: unknown) => {
            if (!isNotFound(error)) throw error;
          }),
      ]);
      assert.equal(await countDeletes(), 2);
      for (const image of [first, raced]) {
        await assert.rejects(
          repository.prepareLeadMedia(owner, leadId, image, "late"),
          isNotFound,
        );
        await assert.rejects(
          repository.createLeadMedia(
            owner,
            leadId,
            image,
            `late-${image.id}`,
            requestHash(image),
            "late",
          ),
          isNotFound,
        );
      }
      const rows = await repository.listLeadMedia(owner, leadId);
      assert.deepEqual(
        rows.filter((row) => !row.deletedAt).map((row) => row.id),
        [card.id],
      );
      assert.equal(rows.length, 3);
      assert.equal(
        rows.some((row) => row.id === missing.id),
        false,
      );
      assert.deepEqual(await repository.listLeadMedia(other, leadId), []);
    } finally {
      await pool.end();
    }
  },
);
