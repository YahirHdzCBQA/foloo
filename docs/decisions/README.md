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
- Pendientes: retención/eliminación de medios, compliance postal y pagos.

Las decisiones de producto/técnica aún abiertas están en
`../product/open-decisions.md`. No se aprueba un
proveedor o contrato porque aparezca como ejemplo en un documento histórico.

La documentación Basic/Pro fue eliminada después de consolidar sus decisiones
vigentes en el producto unificado.
