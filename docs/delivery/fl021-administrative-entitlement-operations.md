# FL-021 Private Administrative Entitlement Operations

This runbook covers the IAM-only DEV boundary for administrative Foloo PRO
access (`MON-21`, `MON-22`). It does not implement payments and does not change
the five historical lead limit for FREE accounts.

It also owns private `preauthorization-status`, `preauthorize`, and
`revoke-preauthorization` operations. Each accepts one operator-supplied email,
canonicalizes it in memory, and persists only a versioned KMS HMAC. The
approved inventory must never enter source, CDK context, environment variables,
outputs, logs, or Flutter.

## Deployment prerequisites

- Migration `012_trial_subscription_foundation.sql` is applied and verified.
- The dedicated PostgreSQL login secret contains only
  `foloo_entitlement_operator`; the application role remains unable to mutate
  entitlement grants or their audit records.
- CDK creates the dedicated IAM user `foloo-entitlement-operator` without a
  console password or access key. Its only policy allows `sts:AssumeRole` and
  `sts:SetSourceIdentity` on the DEV operator role; it has no direct service
  permissions.
- The DEV operator role accepts only that user with MFA, the exact source
  identity `foloo-entitlement-operator`, and a role-session name matching
  `fl021-*`. Sessions last at most one hour. Operator identity is never
  accepted from the Lambda request body.
- The operator role has an identity policy allowing only
  `lambda:InvokeFunction` on the deployed administrative function; no public
  principal, route, URL, schedule, or service trigger can invoke it.
- CloudTrail data events/management events retain the assumed-role session that
  performed each invocation. PostgreSQL audit rows intentionally store the
  authorized role ARN and the mandatory reason.

The CDK opt-in is `administrativeEntitlementEnabled=true`. It is rejected
outside DEV and creates no API Gateway route or Function URL.

After deployment, an authorized IAM administrator must register one MFA device
for the dedicated user. CDK intentionally creates neither a console password
nor an access key. If CLI operation is approved, create at most one base access
key separately, store it in an OS keychain or approved credential vault, and
use it only to request the temporary role session. Never put it in source,
shell history, shared scripts, CloudFormation outputs, or logs.

The operator request must supply the registered MFA device, a unique
`fl021-*` role-session name, `SourceIdentity=foloo-entitlement-operator`, and a
duration no greater than 3600 seconds. For example, using protected shell
variables rather than literal credentials or MFA codes:

```sh
aws sts assume-role \
  --role-arn arn:aws:iam::837153590200:role/foloo-dev-fl021-entitlement-operator \
  --role-session-name "fl021-<ticket>-<utc-timestamp>" \
  --source-identity foloo-entitlement-operator \
  --serial-number "<registered-mfa-device-arn>" \
  --token-code "$FOLOO_OPERATOR_MFA_CODE" \
  --duration-seconds 3600 \
  --profile foloo-entitlement-operator-base
```

Verify the assumed-role ARN and source identity in CloudTrail before the first
entitlement operation. Disable/delete the base access key when the operator is
not in use and rotate it under the normal credential policy.

`automaticEntitlementEnabled=true` provisions the passive queue, DLQ, HMAC key
and worker. `automaticEntitlementEnqueueEnabled` and
`automaticEntitlementWorkerEnabled` are independent activation controls. Load
and verify every preauthorization before enabling either processor.

## Private operation

Invoke from an approved private operator environment after assuming the
authorized role. Resolve the function name from the private CloudFormation
output and write the response to a protected operator terminal or file.

```sh
aws lambda invoke \
  --function-name "$ADMINISTRATIVE_ENTITLEMENT_FUNCTION_NAME" \
  --cli-binary-format raw-in-base64-out \
  --payload '{"action":"status","email":"<verified-account-email>"}' \
  --profile foloo-dev \
  --region us-east-1 \
  /dev/stdout
```

Grant and revoke requests add a non-empty, auditable reason:

```json
{
  "action": "grant",
  "email": "<verified-account-email>",
  "reason": "<approved reason>"
}
```

Preauthorization uses the same mandatory reason without creating Cognito users
or grants:

```json
{
  "action": "preauthorize",
  "email": "<approved-email>",
  "reason": "<approved inventory reason>"
}
```

```json
{
  "action": "revoke",
  "email": "<verified-account-email>",
  "reason": "<approved reason>"
}
```

The Lambda resolves the email inside Cognito and passes only the verified
parent `sub` to PostgreSQL. It fails closed for missing, ambiguous, disabled,
unverified, unsupported federated, Stripe-linked, `legacy_active`, or
inconsistent accounts. Repeating an already satisfied grant or revoke is
idempotent.

## Verification and reversal

1. Run `status` before and after every approved change.
2. Verify the CloudTrail invocation principal and the corresponding
   `entitlement_grant_audit` action/reason through the private database
   diagnostic path.
3. Revoking an administrative grant restores the exact prior `trial` or
   `trial_exhausted` state and never decrements historical lead use.
4. To remove the operational boundary, first revoke any grants that the
   Product Owner has ended, disable operator-role invocation, then deploy with
   `administrativeEntitlementEnabled=false`. Removing the Lambda does not and
   must not rewrite entitlement data.

Rollback of infrastructure is therefore separate from entitlement reversal.
Never delete grant or audit rows manually, never use `foloo_app` for this
workflow, and never treat a failed invocation as a successful grant/revoke.

## Controlled automatic activation in DEV

Activation is allowed only after the IAM-only diagnostic confirms the complete
approved inventory as `active`, with no `consumed`, `revoked`, missing, or
errored entries. This gate is evidence for `MON-21`, `INF-17`–`INF-21`, and
`RNF-09`; an expired operator session is a stop condition, never a reason to
substitute a broader deployment identity.

The activation Change Set must contain exactly these effective changes:

1. Set the `PostAuthentication` enqueue flag to `true`.
2. Enable the automatic-entitlement SQS event source mapping.
3. Set API `FOLOO_UNLIMITED_QA_MODE` to `false`.

Keeping the three changes in one audited Change Set avoids a lasting mixed
configuration. The transition is nevertheless safe under CloudFormation's
resource ordering: enabling the empty consumer first is inert, while enabling
the producer first only creates durable encrypted SQS work that the consumer
can process after it is enabled. The worker still revalidates Cognito identity
and verified email and consumes each preauthorization transactionally.

After activation, verify the deployed flags, Lambda health, queue/DLQ depth,
CloudWatch errors, and one expressly authorized synthetic login before any
broader QA. A successful authentication is not evidence of PRO until the
private entitlement status reports the automatic grant. Do not use an existing
customer account for this proof.

Flutter release builds must omit `FOLOO_UNLIMITED_QA_MODE` or set it to
`false`. An older QA build compiled with the flag enabled may allow local lead
composition past five, but the backend remains authoritative and rejects the
sixth FREE lead while preserving its local draft. Coordinate distribution so
that this temporary UX mismatch is not mistaken for data loss.

### Operational rollback

If automatic processing is unhealthy, first disable the
`PostAuthentication` enqueue flag so no new messages are produced. Keep the
event source mapping enabled while already accepted messages drain; inspect and
resolve any DLQ entries through a separately authorized procedure. Once the
queue is empty, disable the event source mapping. Do not revoke
preauthorizations or grants as an infrastructure rollback, and do not restore
Unlimited QA unless the Product Owner authorizes that separate temporary
control.
