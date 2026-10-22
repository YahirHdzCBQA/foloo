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

## FL-021 billing (MON-07, MON-15–MON-19)

`POST /v1/billing/checkout-session` and `/portal-session` require Cognito JWT;
account comes only from `sub` and the body is ignored. They return `{url}`.
The public `/v1/billing/webhook` requires a valid Stripe signature over the raw
body; event insertion and entitlement update commit together. No billing SQL
touches leads. Existing `/v1/workspace` supplies subscription status.

The billing provider Lambda runs outside the VPC and alone reads the Stripe
API secret. API reads only the webhook secret through Secrets Manager's VPC
endpoint. Both secrets are referenced, never created: config names default to
`foloo/dev/stripe-api-key` and `foloo/dev/stripe-webhook-signing`. Store each as a
raw SecretString (API key and signing secret respectively).

Supply `STRIPE_PRICE_ID`, `BILLING_SUCCESS_URL`, `BILLING_CANCEL_URL`, and
`BILLING_PORTAL_RETURN_URL` when synthesizing the stack. No prices, currencies
or website URLs are defaulted. CDK injects `STRIPE_SECRET_ARN`,
`STRIPE_WEBHOOK_SECRET_ARN` and `BILLING_PROVIDER_FUNCTION_NAME`; all runtime
billing settings are validated at synth when billing is enabled (the default).
Missing price/URLs fail synth with the missing variable names. Explicitly use
`BILLING_ENABLED=false npx cdk synth -c environment=dev` to disable billing;
resources retain their logical IDs, but billing Lambdas receive no billing
configuration and runtime returns 503 `billing_not_configured`.
The legacy `*_ARN` variable names accept exact secret names or complete ARNs;
CDK injects names to avoid ambiguous partial ARNs. Successful reads cache for
five minutes per Lambda container. The public webhook rejects missing signatures
before reading Secrets Manager and has a 10 requests/s, burst 20 route throttle. Apply migration 009 before enabling webhooks.
Register snapshot events for `checkout.session.completed`,
`customer.subscription.updated`, `customer.subscription.deleted` and
`invoice.payment_failed` at the `BillingWebhookUrl` output. This task does not
create/configure secrets, prices, webhook destinations or Portal in Stripe.
See [DECISIONES.md](DECISIONES.md) for lifecycle limits and acceptance coverage.
