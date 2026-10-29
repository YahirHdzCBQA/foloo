# WEB-02 — Disconnected OAuth erasure fix: DEV verified

Current status: deployed and verified in AWS DEV. `web-02-disconnected-oauth-fix-dev` completed successfully; the corrected worker subsequently processed the authorized synthetic deletion to `completed`. The compatible API package later incorporated the identical adapter during admission decoupling.

The disconnected connection's local records and encrypted credentials were removed with the synthetic owner's data. The deployed source skips external revocation for `disconnected`. Existing logs do not audit each provider call: the `oauth_revoked` checkpoint names a stage and does not prove that external revocation occurred, or independently certify its absence. No claim is made about independently observing the external provider's grants.

Destructive QA is now off with an empty allowlist; normal admission is off, runtime/recovery remain on, public storeEnabled=false and the three original web QA entries remain. The deployment-preparation and pre-deletion checks below are historical evidence, not outstanding instructions to repeat QA. See [final admission cleanup](web-02-admission-decoupling.md).
Traces: INF-15–INF-21, RNF-09/RNF-10, E-14; email regression E-08/SAL. D-13 production gates remain open. User authorization explicitly defines the disconnected-connection policy for this focused change.

## Policy and implementation

STORE-02 reads connection status from PostgreSQL. `disconnected` connections are not externally revoked: a shared provider grant must not be revoked as a side effect of erasing this disconnected Foloo connection. The existing owner-scoped transaction still deletes send intents, OAuth states and connection rows, including encrypted credentials. No disconnected token remains in live owner records after successful cleanup. Existing backup retention remains outside this adapter.

`connected` and `reconnect_required` retain mandatory provider revocation; false acknowledgements and provider errors stop cleanup. Unknown states fail before any external side effect. Status is not accepted from the deletion payload. The accepted-request barriers and database write fences remain unchanged. SQL cleanup failures roll back and retries preserve this policy.

Apply at STORE-02 rather than changing Flutter disconnect or the API. Disconnect currently marks status only; clearing credentials immediately would require separately handling NOT NULL ciphertext, stored intents and reconnection semantics. This fix does not claim to change retention before account deletion, nor erase an external grant. It deliberately preserves the external authorization for disconnected connections.

## Validation

- 17 focused tests passed: 8 new policy tests plus 9 existing AWS-adapter tests using synthetic mocks.
- 37 regression tests passed: staged executor, workflow, runtime integration and email application.
- Typecheck, build and focused ESLint passed.
- No live account deletion, provider invocation or PostgreSQL write was tested.

## Historical isolated deployment preparation

Private persistent artifacts: `backend/.env.web02-oauth-*` (latest path also held locally in `/tmp/web02-oauth-fix-path`; backups do not depend on /tmp).

Official CDK CLI synth used the existing private DEV context, four web QA entries, one destructive QA entry and explicit GetAtt ClientId. Full synth changes 12 Lambda package references and MUST NOT be deployed.

`worker-only.template.json` is based on the current deployed template, replacing only the synthesized worker resource. Its only deltas are the worker Code.S3Key and asset path metadata. Other resources, environment variables, IAM, routes, Cognito and allowlists are identical. `assembly/worker-only.assets.json` selects exactly one package. Normalized source maps (including dependencies) differ only in `src/account_deletion/postgres_oauth_erasure.ts`; relative source-map directory depth is not a code change.

Procedure used for the separately authorized deployment (historical):
1. Revalidate stack/account/worker revision and current template against the private snapshots.
2. Upload only the selected worker asset; create one isolated Change Set.
3. Audit only AccountDeletionWorkerFunction1D6CBDD8 code update, no replacements or configuration changes. Stop on any extra resource/dependency effect.
4. Obtain explicit execution authorization; execute and validate CloudFormation, worker health and code hash. Do not invoke the deletion worker manually.

Rollback: verified `worker-before.zip` matches the deployed CodeSha256; `worker-before.json` and `template-before.json` are private persistent snapshots. If rollback is needed, stop deletion QA, evaluate state and obtain authorization for an isolated restoration of the previous code with configuration preserved. The prior package restores the old disconnected-revocation risk: do not resume deletion QA under it. Code rollback cannot undo an external revocation or completed data deletion.

## Historical pre-deletion email check

Use the existing Flutter email history for the synthetic account, backed by GET /v1/email/follow-ups, and its existing connection view (GET /v1/email/connection). Inspect only status/error/attempt metadata; do not confirm, retry, resend, reconnect or expose message content. The follow-up endpoint returns the latest intent per follow-up; the last qa-inventory found one intent and one follow-up. Reconcile counts if new activity occurred; latest-intent status alone does not prove absence of older intents.

Require a terminal known result and no pending/sending/ambiguous outcome before deletion. The current inventory does not expose intent status, so this remains a manual check. Do not call the provider send/revoke operation for diagnostics. These read routes resolve the existing principal and can touch principal timestamps through existing provisioning logic; do not present them as a raw READ ONLY SQL transaction.

Final DEV verdict: PASS for the deployed fix and completed synthetic deletion. The sender was manually disconnected and the user confirmed the prior email was sent and received before deletion. No new send/revoke test is required by this document. D-13, production/store gates and receipt/logout presentation remain independent pending work; no authorization to reactivate admission is implied.
