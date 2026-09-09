# Arquitectura de alto nivel — Foloo V1

## Estado actual aceptado

- Flutter para iOS/Android.
- Drift + SQLite para datos estructurados locales (ADR-001).
- Directorio privado de aplicación para medios locales.
- AWS Cognito DEV mediante Amplify para identidad/sesión (ADR-002).
- Google ML Kit en dispositivo para OCR de tarjetas.
- Un solo producto: no existe una frontera Basic/Pro.

### Autenticación y ownership

`UI → AuthRepository → AuthService → CognitoAuthService`; FakeAuth queda solo
para tests/desarrollo controlado. Cognito DEV usa región `us-east-1`, User Pool
`us-east-1_QVm3dWe4O` y App Client público
`6jong3atp2crqcsde6g215ant8` sin Client Secret. Self sign-up es email/password,
con código por email; MFA de usuario, passwordless y social login están fuera.
El `sub` es ownership estable. Perfil Foloo no es un atributo Cognito.

### Idioma y apariencia

Flutter ARB mantiene ES/EN con un estado compartido por Login y Drawer; español
es fallback. Nombres propios, enums persistidos y tokens de plantilla no se
traducen. Claro/oscuro remapea tokens y preferencias por usuario.

## Fundación cloud implementada en FL-014

```text
Flutter
  ↓
Drift / SQLite
  ↓
Offline Sync
  ↓
Foloo API REST `/v1`
  ↓
API Gateway HTTP API + Cognito JWT authorizer
  ↓
AWS Lambda (Node.js + TypeScript)
  ↓
VPC privada → AWS RDS PostgreSQL
```

ADR-003 gobierna esta fundación. El código e IaC son reproducibles en
`backend/`; el despliegue AWS no se presume realizado. S3 sigue siendo la
dirección para tarjeta, imágenes de referencia, Voice Note y PDF en FL-016.
Sincronización y correo requieren sus propias fases/decisiones.

### Boundary de identidad y tenancy

API Gateway valida issuer/audience/tiempo del JWT. La Lambda obtiene `sub` solo
de `requestContext.authorizer.jwt.claims`; ignora campos de ownership del body.
Una provisión transaccional e idempotente resuelve:

`Cognito sub → user → personal account → personal workspace → owner membership`

Eventos, Leads y metadata se consultan siempre por `workspace_id`. El modelo de
membresía admite una evolución posterior, pero FL-014 no implementa Teams.

### Red, secretos y conexiones DEV

- VPC con subredes aisladas en dos AZ y sin NAT Gateway.
- RDS PostgreSQL privado, Single-AZ, sin exposición pública.
- SG RDS: inbound 5432 únicamente desde SG Lambda.
- Credencial RDS generada en Secrets Manager; Lambda la lee mediante endpoint
  VPC de Secrets Manager y permiso IAM limitado al secreto.
- Pool PostgreSQL reutilizado por entorno Lambda, máximo dos conexiones por
  entorno caliente, más concurrencia reservada DEV. RDS Proxy se reevalúa al
  aumentar concurrencia; no se paga “por si acaso”.
- Logs JSON con requestId y sin payload/token/PII. Retención DEV: una semana.

## Responsabilidades móviles

- Cognito session bootstrap y perfil Foloo separado.
- Repositorios locales aislados por Cognito `sub`.
- Evento/directo, CRUD/selección/agrupación por fecha real.
- Captura, ML Kit, clasificación, voz, texto e imágenes.
- Escritura durable local antes de red.
- Consulta/edición local, contenido/plantillas y exportación por evento.
- Estado de conectividad separado de AuthState y disponibilidad del backend.
- Caché futura de suscripción sin conceder autoridad de pago al cliente.

## Responsabilidades del backend desde FL-014

- API versionada, validación, error envelope e idempotencia de creación.
- Ownership/tenancy y persistencia de cuenta/workspace, perfil, eventos, Leads
  y metadata sin binarios.
- Autoridad futura del trial y suscripción, webhooks y reconciliación.
- Storage S3 protegido, retención y URLs no públicas.
- Sync reanudable de Leads y medios con colas independientes.
- Plantillas server-side, sustitución, adjuntos y correo.
- SPF/DKIM/DMARC, rebotes, bajas y reputación.
- Entregar estado remoto verificable a la app.

No forman parte de V1 Google Sheets, Transcribe/IA, QR, Teams o HQ dashboard.

## Flujo conceptual

1. Cognito restaura `sub`; Foloo carga su perfil/datos locales.
2. El usuario conserva o elige evento/origen.
3. ML Kit local ayuda a completar la tarjeta; captura manual siempre funciona.
4. Guardar confirma Drift y medios privados.
5. El contador remoto autoriza la nueva captura o conserva el borrador y abre
   paywall al sexto Lead.
6. La futura sync envía operaciones idempotentes y medios por colas separadas.
7. El backend prepara correo y adjuntos; los estados regresan al dispositivo.
8. Vencimiento limita solo nuevas capturas y nunca oculta datos existentes.

## Decisiones pendientes

Ver `../product/open-decisions.md`: pago/tiendas,
precio/vencimiento/reembolso, Voice Note, edición post-guardado, export,
límites PDF, correo, Teams, mockups y retención. La base cloud quedó resuelta
por ADR-003.
