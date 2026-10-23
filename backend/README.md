# Foloo backend — Foloo V1

Node.js 22 + TypeScript foundation for the protected Foloo `/v1` API. It is a
modular serverless monolith: API Gateway HTTP API validates Cognito JWTs, one
application Lambda derives ownership from `sub`, and PostgreSQL runs privately
on RDS. Flutter stays write-first in Drift and synchronizes through the outbox.

## Boundaries

Implemented: account/workspace bootstrap, seller profile, events, leads, lead
media metadata, validation, idempotent creates, safe errors, migrations,
structured logging, private S3 media/Content transfer, Event/Lead sync, the
FL-019 Google/Microsoft email boundary, and FL-020 server-authoritative trial
enforcement, plus FL-021 web Checkout/Portal and signed billing webhooks. Mobile sync uses the Flutter outbox. Not implemented: payment
processing configuration in Stripe, Teams, transcription or
later phases.

The OpenAPI contract is in `openapi/foloo-v1.yaml`. `ownerId`, `workspaceId`,
`sub` and email from request payloads are never authorization inputs.

## Local validation

```bash
npm ci
npm run format:check
npm run lint
npm run typecheck
npm test
npm run build
npx cdk synth -c environment=dev
```

No real AWS users or resources are required by unit tests.

For an already reachable development PostgreSQL instance, migrations may also
run locally with `DATABASE_URL` (admin connection) and
`APP_DATABASE_PASSWORD` supplied by the shell/secret manager. Never place these
values in `.env` files committed to Git.

## Defined AWS DEV resources

- one VPC with two isolated subnets and no NAT Gateway;
- one private Single-AZ `db.t4g.micro` RDS PostgreSQL 16 instance (20 GiB gp3,
  autoscaling ceiling 50 GiB, one-day backup, snapshot on stack removal);
- Security Groups allowing PostgreSQL 5432 only from Foloo Lambdas;
- one Secrets Manager interface VPC endpoint;
- one S3 Gateway VPC endpoint, without NAT;
- one private S3 media bucket with Block Public Access, S3-managed encryption,
  enforced TLS and retention on stack removal;
- generated admin and limited application database secrets;
- one protected API Lambda and one non-routed migration Lambda;
- API Lambda object permissions limited to `s3:GetObject`/`s3:PutObject` on the
  media bucket;
- one API Gateway HTTP API with Cognito JWT authorizer using the existing DEV
  User Pool/App Client; Cognito is referenced by issuer values, never created;
- CloudWatch logs retained seven days; Lambdas use the account's available
  unreserved concurrency.

RDS, allocated storage, two Secrets Manager secrets and the interface endpoint
have recurring cost even while idle. S3, API Gateway, Lambda and logs are
usage-based; the S3 Gateway endpoint has no hourly charge. DEV intentionally
omits NAT, Multi-AZ and RDS Proxy. Before PROD, review media retention,
Multi-AZ, deletion protection, longer backups, alarms, rotation,
capacity/concurrency and RDS Proxy based on measured connections.

## Safe deployment workflow (not executed by Codex)

Use AWS IAM Identity Center (preferred) or an assumed deployment role; never
Root access keys. First inspect the existing identity and preview every change:

```bash
aws sso login --profile foloo-dev
aws sts get-caller-identity --profile foloo-dev
aws cognito-idp describe-user-pool --user-pool-id us-east-1_QVm3dWe4O --region us-east-1 --profile foloo-dev
AWS_PROFILE=foloo-dev npx cdk bootstrap aws://ACCOUNT_ID/us-east-1
AWS_PROFILE=foloo-dev npx cdk diff -c environment=dev
```

Confirm the diff contains no Cognito create/update/delete and review the
continuous-cost resources above. Then deploy explicitly:

```bash
AWS_PROFILE=foloo-dev npx cdk deploy -c environment=dev --require-approval broadening
```

After deployment, invoke the private migration Lambda named by the stack output.
Its role can read the admin/app secrets; the public API Lambda can read only the
limited app secret.

```bash
aws lambda invoke --function-name MIGRATION_FUNCTION_NAME --payload '{}' --cli-binary-format raw-in-base64-out --region us-east-1 --profile foloo-dev migration-result.json
```

Review `migration-result.json` and CloudWatch logs, then obtain a Cognito access
token through the existing mobile flow and smoke-test `/v1/workspace`. Do not
send tokens or secret values through chat or commit them. A PROD config is
deliberately absent until real values and operational requirements are approved.

## FL-021 billing (MON-14–MON-20)

`POST /v1/billing/checkout-session` and `/portal-session` require Cognito JWT;
account comes only from `sub` and the body is ignored. They return `{url}`.
The public `/v1/billing/webhook` requires a valid Stripe signature over the raw
body; event insertion and entitlement update commit together. No billing SQL
touches leads. Existing `/v1/workspace` supplies subscription status. MON-14
(the informational notice in the app) is app-side and not part of this backend.

The billing provider Lambda runs outside the VPC and alone reads the Stripe
API secret. API reads only the webhook secret through Secrets Manager's VPC
endpoint. Both secrets are referenced, never created by CDK. The legacy `*_ARN`
variable names accept exact secret names or complete ARNs; successful reads
cache for five minutes per Lambda container. The public webhook rejects missing
signatures before reading Secrets Manager and has a 10 requests/s, burst 20
route throttle. The API stage depends on the webhook route so CloudFormation
creates the route before applying that throttle.

### DEV configuration (Stripe test mode)

| Setting                | DEV value                                                             | Override                    |
| ---------------------- | --------------------------------------------------------------------- | --------------------------- |
| Stripe API key secret  | `foloo/dev/stripe-api-key` (raw SecretString, `sk_test_…`)            | —                           |
| Webhook signing secret | `foloo/dev/stripe-webhook-signing` (raw SecretString, `whsec_…`)      | —                           |
| Price                  | `price_1UTTLKCp0Un1sf9uyTk4w9NN` ("Foloo Pro (prueba)", 99 USD/month) | `STRIPE_PRICE_ID`           |
| Success URL            | `https://foloo.io/dashboard?billing=success`                          | `BILLING_SUCCESS_URL`       |
| Cancel URL             | `https://foloo.io/dashboard?billing=cancel`                           | `BILLING_CANCEL_URL`        |
| Portal return URL      | `https://foloo.io/dashboard`                                          | `BILLING_PORTAL_RETURN_URL` |

Billing is enabled by default and synth fails naming any missing value.
`BILLING_ENABLED=false npx cdk synth -c environment=dev` disables it without
removing resources or changing logical IDs; billing requests that pass the
JWT/signature and account checks then return 503 `billing_not_configured`. Secret values are loaded by hand in the console or
from a file (`--secret-string file://…`), never typed on a command line or
committed.

In the Stripe dashboard (test mode), register a webhook at the
`BillingWebhookUrl` stack output for `checkout.session.completed`,
`customer.subscription.updated`, `customer.subscription.deleted` and
`invoice.payment_failed`, and activate the Customer Portal.

### Migration 011 and `only=<migration>`

Billing needs `migrations/011_billing_stripe.sql` (accounts' Stripe IDs and the
append-only `billing_events` receipts). `{"action":"status"}` lists applied
migrations in `appliedMigrations` without writing:

```bash
aws lambda invoke --function-name MIGRATION_FUNCTION_NAME --payload '{"action":"status"}' --cli-binary-format raw-in-base64-out --region us-east-1 --profile foloo-dev status.json
```

To apply one migration while an earlier one stays pending (in DEV, 010 belongs
to STORE-02 and has its own backup/authorization procedure), name it in `only`:

```bash
aws lambda invoke --function-name MIGRATION_FUNCTION_NAME --payload '{"action":"apply","only":"011_billing_stripe.sql"}' --cli-binary-format raw-in-base64-out --region us-east-1 --profile foloo-dev migration-result.json
```

`only` applies that file if it is still pending, returns `{"applied":[]}` if it
was already applied, fails with `does not exist` for an unknown name, and never applies
other pending files. A later `{"action":"apply"}` without `only` applies the
rest in order. DEV applied 011 this way on 2026-10-23.

See [DECISIONES.md](DECISIONES.md) for lifecycle limits and acceptance coverage.
