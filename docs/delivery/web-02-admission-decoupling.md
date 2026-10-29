# WEB-02 — Local STORE-02 admission decoupling

Status: local preparation only. No AWS queries, writes, Change Sets, deployments, live requests or changes to private deployment contexts in this task. Existing destructive QA authorization and the three web QA identities remain untouched.

Traces: AUT-18/AUT-19, INF-15–INF-21, RNF-09/RNF-10, E-14. Read product-spec, relevant E-14 acceptance scenarios, open-decisions D-13, architecture overview, traceability and roadmap. This change does not approve candidate ADR-AD decisions, production, legal retention, payment policy or public activation.

## Coupling found

`infra/foloo_backend_stack.ts` previously derived both FOLOO_ACCOUNT_DELETION_ENABLED and FOLOO_ACCOUNT_DELETION_QA_ENABLED from accountDeletionQa.enabled. `infra/config.ts` required one QA subject and tied intake/worker dependency checks to that same flag. Runtime composition unconditionally constructed the QA-only guard; disabled/empty QA therefore prevented API/worker composition rather than merely rejecting new admissions. The worker also required a nonempty QA hash string.

## Minimal separation

- `accountDeletionRuntimeEnabled` controls functional composition (existing FOLOO_ACCOUNT_DELETION_ENABLED). For a legacy configuration that omits it, runtime falls back to the old QA flag; migration must explicitly pin it true before removing QA.
- `accountDeletionNormalAccessEnabled` controls the new FOLOO_ACCOUNT_DELETION_NORMAL_ACCESS_ENABLED in API and worker. Default false, no implicit activation when QA is disabled.
- Existing `accountDeletionQaEnabled` and subject hashes control only the exceptional DEV allowlist. It still requires exactly one valid subject when on. Explicit decoupled configuration requires an empty list when QA is off.
- Existing intake, worker, finalizer, event source, recovery and registration-guard controls retain their meanings and dependencies. Runtime can remain on when both admission modes are off.
- Normal and QA admission cannot both be on. Mode selection must be explicit; switching QA off never chooses normal admission.
- Production remains rejected by the admission factory and existing DEV-only infrastructure configuration. This is preparation, not production policy approval.

| Runtime | Normal | QA | New private deletion requests |
|---|---|---|---|
| off | off | off | Runtime unavailable |
| on | off | off | Denied; receipt lookup, barriers and processing of accepted work remain operational |
| on | off | on | Existing exact synthetic-subject allowlist |
| on | on | off | Explicit DEV self-service admission, followed by all existing workflow controls |
| off | either on | any | Invalid configuration |
| any | on | on | Invalid configuration |

## Normal authorization boundary

The normal gate admits an authenticated subject to the existing controller; it is not authorization to erase an arbitrary account. API Gateway/BFF validates Cognito access tokens, the controller extracts sub from trusted claims (not email, body or workspace parameters), and HMAC owner binding restricts current/preflight/confirmation to that identity. Confirmation still validates Cognito auth_time, verified-email resolution, current review/owner, irreversible acceptance, pending-sync acknowledgement, subscription conditions and stable idempotency. Owner/workspace erasure remains in the existing adapters; no team/admin deletion authority is added.

For cookie-authenticated web operations the existing BFF still requires session, allowed Origin and CSRF. Mobile bearer-token operations retain their existing JWT boundary; a web CSRF check is not substituted for mobile authentication. Refresh does not replace interactive recent authentication. Neither auth-age nor review expiry changed.

Receipt lookup stays on its existing capability-token path, without weakening token validation. The executor is not gated on new-request admission: accepted records keep their barriers and workflow checks and can complete/recover with admission closed. Disconnected OAuth behavior and staged erasure adapters are unchanged.

## Gates not resolved here

D-13 still blocks production/public release: regional retention and legal holds, backup policy, approval of the auth-age window, accountable operations, payment/legal coordination, third-party lead data, minors/regions and final disclosures. The technical self-service rule is supported by AUT-18/AUT-19; who may enable it in DEV or publish it remains a separate approval. No frontend flag or approval Boolean is treated as legal compliance.

## Migration and rollback — future authorization required

1. Preflight read-only against the then-current stack, package hashes, revisions, three-entry web allowlists and current destructive entry. Preserve private template/package snapshots and completed-deletion evidence. Use official CDK CLI and current private context with explicit GetAtt ClientId. Never use the synthetic test assembly as a deployment template.
2. Compatibility stage: explicitly set runtime true and normal false, keep QA and its current hash unchanged. Deploy only reviewed API/worker code plus their normal-admission variable. All other code/assets remain pinned to deployed values in an isolated template. This stage does not remove the current authorization.
3. After compatibility checks, a separately approved cleanup sets QA false and its hash empty in API/worker while keeping runtime, normal=false, intake, guards, worker/finalizer/recovery and web allowlists unchanged. Do not disable STORE-02 infrastructure. New admission is closed intentionally; normal mode was never enabled before cleanup.
4. Optional normal activation is a separate decision, not part of retirement. It requires explicit normal=true, QA=false, empty QA list and applicable approvals. Public storeEnabled remains false throughout these stages.

Stage 1 rollback may use the verified prior packages only while the original QA configuration is still intact. Once QA is off/hash empty, rolling back to old code would cause runtime initialization failure; do not restore old packages alone. Retain a verified compatible decoupled build for recovery. CloudFormation rollback of stage 2 would restore its pre-update QA setting/hash for the already-deleted identity; this is not authorization to recreate a user. If even temporary restoration is unacceptable, stage 2 needs a separately reviewed recovery strategy before execution. Never reintroduce an older unrelated identity or fabricate an operational hash. No automatic rollback is authorized here.

## Expected future isolated resources

- ApiFunctionCE271BD4: code package; FOLOO_ACCOUNT_DELETION_NORMAL_ACCESS_ENABLED=false; later only QA-enabled/hash cleanup.
- AccountDeletionWorkerFunction1D6CBDD8: code package; same new variable; later same QA cleanup.
- WebSessionsFunction, the three web QA hashes, Cognito, IAM, API routes, event mappings, schedulers, other functions, Billing, frontend and public storeEnabled: no intended change.

Runtime activation still supplies the existing email Lambda flag; pinning runtime true keeps it unchanged. A shared dependency change may cause incidental asset differences in a full synth. Do not publish those packages; actual isolation and CloudFormation replacement/runtime audit belong to the future authorized preparation. Lambda UpdateRuntimeOn=Auto can apply a managed runtime update during deployment; compare runtime versions then rather than promise no runtime change from a local synth.

## Local verification

130/130 focused regression tests passed (STORE-02 workflow, controller admission, owner isolation, idempotency, durable adapters, disconnected OAuth, staged executor, BFF session/Origin/CSRF/reauthentication and infrastructure). The strengthened normal-flow test was rerun afterward: 15/15 workflow tests passed. All credentials/identities in tests are synthetic; no network actions or real deletion were invoked.

The infrastructure comparison synthesizes the same stack with QA on and off under explicit runtime=true and normal=false. It asserts exactly four environment-value changes across API and worker (QA flag and hash), and full equality of all other resources and code/IAM properties. This is local evidence, not an AWS Change Set audit.

Typecheck and focused ESLint passed. Build and official CLI synth results are recorded after completion below. The isolated CLI assembly uses a synthetic account/key context, no lookups and no actual private QA configuration; it is not deployable evidence for AWS DEV.

Verdict: prepared locally for separately authorized isolated deployment preparation; not authorization for deployment, normal activation, public release or removal of the effective QA entry.

Final local results: TypeScript typecheck PASS; build PASS; focused ESLint PASS (including the last owner-isolation test changes). Official CDK CLI synth PASS with no lookups after supplying a synthetic AZ cache in a local wrapper. The initial no-cache attempt stopped before any lookup; it was not an AWS failure. Verified CLI output: CDKMetadata and explicit GetAtt ClientId present, runtime/worker true, normal=false, QA=false and empty destructive list. Neither synthetic assembly is suitable for deployment.

Hand-maintained files changed:
- `src/account_deletion/account_deletion_admission.ts` (new).
- `src/account_deletion/account_deletion_composition.ts`.
- `src/account_deletion/account_deletion_http.ts`.
- `src/account_deletion/account_deletion_worker_lambda.ts`.
- `src/config/environment.ts`.
- `src/transport/lambda.ts`.
- `infra/config.ts`, `infra/app.ts`, `infra/foloo_backend_stack.ts`.
- `test/account_deletion_admission.test.ts` (new).
- `test/account_deletion_workflow.test.ts`.
- `test/unlimited_qa_configuration.test.ts`.
- `test/account_deletion_ledger_infrastructure.test.ts`.
- This document. Build output is local generated output only.

No foloo-landing application/Overrides, live private contexts, allowlists or production configuration were edited. The earlier completed-deletion evidence and cleanup snapshots were not changed.

## Authorized compatibility Change Set preparation — 2026-10-28

Change Set `web-02-store-qa-decoupling-dev`: CREATE_COMPLETE / AVAILABLE; REVERT_DRIFT; evaluated drift IN_SYNC. Not executed. Stack remains UPDATE_COMPLETE.

Only ApiFunctionCE271BD4 and AccountDeletionWorkerFunction1D6CBDD8 are Modify, Replacement=False. Each has exactly three static details, all RequiresRecreation=Never: Code.S3Key, Metadata.aws:asset:path, and addition of FOLOO_ACCOUNT_DELETION_NORMAL_ACCESS_ENABLED=false. No changes to IAM, permissions, routes, Cognito, other resources or runtime properties. Existing runtime/intake/worker gates, destructive QA enabled with one current entry, and three web QA entries are preserved. Public storeEnabled=false and the complete public config digest remain unchanged.

Official CDK CLI synth used an isolated private context and output directory with current effective allowlists and explicit GetAtt ClientId. Full synth changes twelve Lambda asset keys: it must not be deployed. The existing qa-inventory synth binding requires the removed synthetic web authorization; its subject was omitted only from this task-local synthesis to avoid restoring that authorization. MigrationFunction was pinned in full to the deployed template; its configuration and package are unchanged in the isolated candidate. This existing inventory-context dependency remains a separate concern before any full-stack deploy. No application guard was changed to bypass it.

Source-map comparison verified unchanged dependency sources and selected package contents matching local sources. API additionally incorporates the disconnected-OAuth adapter already deployed and validated in the worker; its source is identical to that deployed protection. Worker retains that adapter unchanged.

Only two Lambda assets and the necessary isolated template were staged in the private CDK bucket with verified SHA256 checksums. Verified previous ZIP packages, full deployed template, configurations/revisions, runtime snapshots, candidate manifests, raw Change Set evidence and recovery instructions are retained in the private persistent backend .env.web02-decouple-dev directory selected by this task. No private subjects/hashes are included here.

Recovery: prior packages remain compatible while QA=true and its existing hash remain intact. A future separately authorized isolated rollback restores only prior code plus the previous absence of the new flag; no old unrelated identities should be restored. After later QA retirement, do not roll back to legacy code alone. Runtime UpdateRuntimeOn=Auto remains unchanged: a future Lambda update may apply a managed runtime patch despite no Runtime property diff. Revalidate runtime version and health after any authorized execution.

Final audit: APTO to request execution authorization for this compatibility stage only. No cleanup, normal admission, public activation, execution or Lambda invocation was performed.

## Authorized stage 1 execution — PASS

Executed only `web-02-store-qa-decoupling-dev` in AWS DEV after fresh targeted drift IN_SYNC, unchanged audited Change Set, exact template/configuration revisions and verified private backups. Final Change Set EXECUTE_COMPLETE; FolooBackend-dev UPDATE_COMPLETE. Stack events show only ApiFunctionCE271BD4 and AccountDeletionWorkerFunction1D6CBDD8 updated. Both are Active / Successful and CodeSha256 matches the approved staged ZIP.

Effective changes are the two code packages and added FOLOO_ACCOUNT_DELETION_NORMAL_ACCESS_ENABLED=false (plus expected code size, modification time and revision bookkeeping). Existing runtime/intake/worker and security configurations are preserved. Destructive QA remains enabled with the same single authorization; the three original web QA identities remain unchanged. Public config digest unchanged, storeEnabled=false. Deployed template exactly matches the isolated candidate. Other 12 Lambda configurations and runtimes, resource identities, IAM/routes and other resources remain unchanged.

Both selected functions remain nodejs22.x / arm64, UpdateRuntimeOn=Auto, with unchanged managed RuntimeVersionArn. No managed runtime patch was observed. Post-execution logs were inspected in each function's configured log group: no new events/invocations or error candidates in the observation window. This does not claim an execution smoke test; no Lambda invocation or deletion request was issued.

Private execution snapshots, events, package verification and redacted result remain alongside the persistent original backups and RECOVERY.txt. No rollback was executed. Stage 2 cleanup was neither prepared nor executed; it requires separate authorization.

## Stage 2 preparation — destructive QA retirement

Traces AUT-18/AUT-19, INF-17–INF-21, RNF-09/RNF-10; E-14. D-13/public activation remains outside scope.

Change Set `web-02-destructive-qa-cleanup-dev` is CREATE_COMPLETE / AVAILABLE, REVERT_DRIFT, IN_SYNC. Not executed. Only ApiFunctionCE271BD4 and AccountDeletionWorkerFunction1D6CBDD8 appear, Modify / Replacement=False. Exactly four static property changes, RequiresRecreation=Never: in each function, FOLOO_ACCOUNT_DELETION_QA_ENABLED changes true to false, and ACCOUNT_DELETION_QA_SUBJECT_HASHES becomes the empty string. BeforeValueFrom is ACTUAL_STATE for all four values, matching the effective baseline.

Candidate derived from the exact deployed stage-1 template; no full synth deployment or new Lambda assets. Code, metadata, runtime properties, IAM, routes, permissions, GetAtt ClientId, other resources and web authorizations are identical. A private task-local context records runtime=true, normal=false, QA=false and an empty list for eventual declarative integration; no previous context or live configuration was overwritten. The unrelated qa-inventory context dependency noted above remains outside this isolated template.

Stage-1 compatible code verified against deployed CodeSha256 and backed up again. Effective configurations/revisions, runtimes, full current template, isolated candidate, Change Set audit and recovery instructions are stored in the persistent private .env.web02-destructive-cleanup directory. Existing completed-deletion evidence was preserved.

30/30 local non-destructive tests passed: admission, workflow and infrastructure. Coverage verifies closed QA/normal admission, valid runtime composition, receipt access and processing of already accepted work after admission closes, and infrastructure preservation. These are synthetic local tests, not live deletion/worker invocations. Runtime/intake/worker remain enabled in the candidate; recovery/barriers and other controls are unchanged. Three original web QA identities and public storeEnabled=false remain intact. Final live revalidation confirms no active Lambda/runtime/public changes and stack UPDATE_COMPLETE.

Rollback risk: CloudFormation rollback restores the pre-stage QA=true and the current single hash of the already-deleted synthetic identity. It does not recreate that identity or its data, nor enable normal admission. This must be considered when authorizing execution. Keep compatible stage-1 code; never restore legacy code alone. After successful cleanup, prefer recovery retaining both admission modes closed; any return to pre-stage configuration requires explicit separate authorization, never an older or fabricated hash. Runtime UpdateRuntimeOn=Auto can apply an AWS-managed patch on future configuration updates although no runtime property is changed; verify after execution.

Verdict: APTO for separately authorized execution of this Change Set only. No execution, new deletion request, worker invocation, public flag change or PROD operation performed.

## Stage 2 execution — PASS

Executed only `web-02-destructive-qa-cleanup-dev` under explicit user authorization. Fresh full-stack drift detection completed IN_SYNC with zero drifted resources before execution. Approved Change Set, current compatible code/configurations and private backups were revalidated. Final states: EXECUTE_COMPLETE, FolooBackend-dev UPDATE_COMPLETE; API and worker Active / Successful.

Only effective configuration changes: FOLOO_ACCOUNT_DELETION_QA_ENABLED=false and ACCOUNT_DELETION_QA_SUBJECT_HASHES empty in ApiFunctionCE271BD4 and AccountDeletionWorkerFunction1D6CBDD8. Expected revision/modification timestamps changed. CodeSha256/CodeSize are unchanged. Runtime/intake/worker, barriers, recovery and all other configurations remain preserved. Both normal and QA admission are closed. Three original web QA identities remain intact; public config digest unchanged and storeEnabled=false. Deployed template equals the isolated approved candidate.

Other 12 Lambda configurations/runtimes and resource identities/configurations are unchanged, including IAM, routes and permissions. Both selected functions remain nodejs22.x / arm64, UpdateRuntimeOn=Auto with no managed RuntimeVersionArn change. Post-update configured log groups had no new events or invocations during observation; this is not a live processing test. Prior local closed-admission tests establish continued receipt access and accepted-work processing; no new request or worker invocation was issued here.

Persistent private execution evidence, before/after snapshots, full-stack drift result, CloudFormation events, compatible package backups and RECOVERY.txt retained alongside earlier WEB-02 evidence. No rollback performed. Any future recovery must retain compatible code; no automatic reactivation of QA or normal admission is authorized. No further deployment started.
