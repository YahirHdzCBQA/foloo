# Decisiones de arquitectura

Los ADR aceptados complementan, pero no sustituyen, el alcance V1.

- ADR-001: Drift + SQLite y medios privados locales.
- ADR-002: AWS Cognito mediante la frontera AuthRepository/AuthService.
- ADR-003: API Gateway/Lambda y PostgreSQL privado en AWS RDS.
- ADR-004: outbox persistente, retry e integración segura Drift/API.
- ADR-005: S3 privado, transferencia directa temporal y confirmación backend.
- ADR-006: follow-up desde la cuenta autorizada del vendedor mediante Google
  o Microsoft; `D-14`–`D-20` quedaron resueltas el 2026-09-18.
- ADR-007: frontera OAuth, almacenamiento de credenciales, egreso y
  anti-duplicados para FL-019.
- ADR-008: cobro en la web con Stripe Checkout; la app solo informa.
- ADR-009: Sign in with Apple y retoma de Microsoft Sign-In vía Cognito.
- Pendientes: retención/eliminación de medios, compliance postal y pagos.
- Account Deletion tiene seis decisiones agrupadas todavía **no aceptadas** en
  [`ADR-AD-account-deletion-candidates.md`](ADR-AD-account-deletion-candidates.md):
  ledger, HMAC, Cognito, guard anterior a provisioning, restore y reauth.

Las decisiones de producto/técnica aún abiertas están en
`../product/open-decisions.md`. No se aprueba un
proveedor o contrato porque aparezca como ejemplo en un documento histórico.

La documentación Basic/Pro fue eliminada después de consolidar sus decisiones
vigentes en el producto unificado.
