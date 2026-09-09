# Foloo backend — FL-014

Node.js 22 + TypeScript foundation for the protected Foloo `/v1` API. It is a
modular serverless monolith: API Gateway HTTP API validates Cognito JWTs, one
application Lambda derives ownership from `sub`, and PostgreSQL runs privately
on RDS. Flutter is not connected yet; Drift remains the write-first authority.

## Boundaries

Implemented: account/workspace bootstrap, seller profile, events, leads, lead
media metadata, validation, idempotent creates, safe errors, migrations and
structured logging. Not implemented: mobile sync, S3/binaries, content upload,
email, payments/trial, Teams, transcription or later-phase integrations.

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
- generated admin and limited application database secrets;
- one protected API Lambda and one non-routed migration Lambda;
- one API Gateway HTTP API with Cognito JWT authorizer using the existing DEV
  User Pool/App Client; Cognito is referenced by issuer values, never created;
- CloudWatch logs retained seven days and API concurrency capped at 10.

RDS, allocated storage, two Secrets Manager secrets and the interface endpoint
have recurring cost even while idle. API Gateway, Lambda and logs are mostly
usage-based. DEV intentionally omits NAT, Multi-AZ and RDS Proxy. Before PROD,
review Multi-AZ, deletion protection, longer backups, alarms, rotation,
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
