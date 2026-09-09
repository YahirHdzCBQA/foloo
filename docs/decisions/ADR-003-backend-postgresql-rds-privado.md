# ADR-003 — Backend serverless y PostgreSQL privado en AWS RDS

- Estado: **Aceptado**
- Fecha: 2026-09-09
- Alcance: FL-014, fundación cloud de Foloo V1
- Trazas: `INF-01`, `INF-03`, `INF-05`–`INF-14`, `SYN-06`, `SYN-10`,
  `AUT-10`, `RNF-05`, `RNF-07`, `RC-03` y E-13

## Contexto

Foloo ya autentica con Cognito y conserva primero en Drift. FL-014 necesita un
destino cloud reproducible, privado y preparado para recibir UUID nacidos
offline, sin implementar todavía el motor de sincronización ni S3. La decisión
de Producto cierra `D-12`: Node.js/TypeScript, API Gateway, Lambda y PostgreSQL
en AWS RDS son obligatorios.

## Decisión

- Se adopta un monolito serverless modular: API Gateway HTTP API con rutas REST
  `/v1`, una Lambda Node.js 22/TypeScript y capas internas de transporte, auth,
  aplicación, dominio y persistencia. No se crean microservicios.
- API Gateway usa un JWT authorizer con issuer del User Pool DEV existente y
  audiencia del App Client público. Cognito no se recrea con IaC. La Lambda
  acepta ownership solo del claim `sub` entregado por el authorizer.
- Cada `sub` se provisiona idempotentemente como usuario, cuenta personal,
  workspace personal y membresía owner. Los recursos pertenecen al workspace;
  esto permite una evolución futura sin implementar Teams, roles de negocio ni
  invitaciones en V1.
- PostgreSQL 16 vive en una instancia RDS privada, Single-AZ DEV, en subredes
  aisladas. El Security Group de RDS acepta 5432 exclusivamente desde el de
  Lambda. No hay NAT Gateway.
- RDS genera la contraseña en Secrets Manager. Lambda la obtiene por un
  interface VPC endpoint privado; el secreto no se materializa en código ni en
  variables de entorno. El rol Lambda recibe solo lectura de ese secreto.
- DEV usa conexión directa con un pool pequeño reutilizado por entorno caliente
  y concurrencia reservada limitada. No se agrega RDS Proxy por su costo fijo;
  se debe reevaluar antes de elevar concurrencia o pasar a producción.
- UUID de eventos/leads/media pueden ser creados por Flutter y se preservan.
  `revision`, timestamps, soft deletion e idempotencia preparan FL-015. Los
  binarios permanecen fuera de PostgreSQL; S3 corresponde a FL-016.
- AWS CDK administra solo los recursos nuevos de FL-014. El despliegue usa IAM
  Identity Center o un rol IAM de desarrollo con permisos acotados; nunca Root
  ni access keys dentro del repositorio/app.

## Consecuencias

- El interface endpoint de Secrets Manager, RDS y almacenamiento generan costo
  continuo aun sin tráfico; API Gateway/Lambda/logs son principalmente por uso.
- Sin NAT, la Lambda no tiene salida general a Internet. Eso es intencional para
  FL-014; futuras integraciones deben justificar endpoint privado o egress.
- La instancia directa es suficiente para DEV limitado, pero el límite de
  conexiones debe observarse. Producción debe revisar Multi-AZ, backups,
  deletion protection, RDS Proxy, alarmas y rotación.
- FL-014 define/implementa el destino cloud, no conecta Drift ni presenta estados
  remotos como completados.
