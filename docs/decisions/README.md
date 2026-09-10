# Decisiones de arquitectura

Los ADR aceptados complementan, pero no sustituyen, el alcance V1.

- ADR-001: Drift + SQLite y medios privados locales.
- ADR-002: AWS Cognito mediante la frontera AuthRepository/AuthService.
- ADR-003: API Gateway/Lambda y PostgreSQL privado en AWS RDS.
- ADR-004: outbox persistente, retry e integración segura Drift/API.
- Pendientes: S3/acceso/retención, correo y pagos.

Las decisiones de producto/técnica aún abiertas están en
`../product/open-decisions.md`. No se aprueba un
proveedor o contrato porque aparezca como ejemplo en un documento histórico.

La documentación Basic/Pro fue eliminada después de consolidar sus decisiones
vigentes en el producto unificado.
