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
con código por email, y Google usa federación Cognito. Microsoft Sign-In/OIDC
queda temporalmente fuera de esta versión después de presentar conflictos de
issuer en la federación con Entra; su código reutilizable permanece fuera de la
UI. El App Client móvil continúa sin secret.
MFA de usuario y passwordless están fuera. El `sub` Cognito es ownership
estable. Perfil Foloo no es un atributo Cognito. Auth social y OAuth sender son
boundaries independientes.

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

ADR-003 gobierna la fundación y ADR-005 el boundary de medios. FL-016 añade un
bucket S3 privado para tarjeta, imágenes de referencia y Voice Note. FL-018
reutiliza ese bucket para Content/PDF. Flutter
obtiene una autorización corta de la API, transfiere directamente al objeto y
confirma por la API; Lambda verifica S3 antes de actualizar PostgreSQL.
FL-019 usa Google y cuentas Microsoft personales compatibles como proveedores de follow-up desde la cuenta
autorizada del vendedor; la outbox lleva el snapshot local inmutable y la
intención a una frontera backend de proveedor, sin credenciales de
correo en Flutter. ADR-007 mantiene API/RDS en subredes aisladas y lleva el
egreso a una Lambda de proveedor sin VPC, invocada por un endpoint privado de
Lambda. Esa frontera lee secretos OAuth de aplicación y cifra/descifra tokens
renovables con KMS, pero no tiene acceso a PostgreSQL. El callback OAuth
son las únicas rutas públicas sin JWT y usan respectivamente state+PKCE de un
solo uso y token opaco.

La cuenta Cognito autentica Foloo; la cuenta Google/Microsoft solo autoriza el
envío y puede ser distinta. Tras perfil, un paso opcional guarda por `sub`
únicamente si fue completado/omitido; no guarda ni concede conexión. El estado
OAuth real se consulta al backend al entrar a Correo y al reanudar desde el
navegador. La respuesta móvil se limita a provider, identidad enmascarada y
estado; los tokens permanecen cifrados server-side.

### Boundary de identidad y tenancy

API Gateway valida issuer/audience/tiempo del JWT. La Lambda obtiene `sub` solo
de `requestContext.authorizer.jwt.claims`; ignora campos de ownership del body.
Una provisión transaccional e idempotente resuelve:

`Cognito sub → user → personal account → personal workspace → owner membership`

Eventos, Leads y metadata se consultan siempre por `workspace_id`. El modelo de
membresía admite una evolución posterior, pero FL-014 no implementa Teams.

### Red, secretos y conexiones DEV

- VPC con subredes aisladas en dos AZ y sin NAT Gateway.
- Endpoint Gateway S3 para verificación privada desde Lambda, sin NAT.
- RDS PostgreSQL privado, Single-AZ, sin exposición pública.
- SG RDS: inbound 5432 únicamente desde SG Lambda.
- Credencial RDS generada en Secrets Manager; Lambda la lee mediante endpoint
  VPC de Secrets Manager y permiso IAM limitado al secreto.
- Pool PostgreSQL reutilizado por entorno Lambda, máximo dos conexiones por
  entorno caliente. DEV usa la concurrencia no reservada disponible de la
  cuenta; RDS Proxy se reevalúa si las métricas muestran presión de conexiones.
- Logs JSON con requestId y sin payload/token/PII. Retención DEV: una semana.

### Boundary de medios privados

La key se deriva en backend como
`media/workspaces/{workspaceId}/leads/{leadId}/{mediaId}`. El JWT resuelve el
workspace; Flutter no suministra owner ni key. Las autorizaciones PUT duran 10
minutos y las GET 5 minutos, no se persisten y cada retry conserva `mediaId`.
S3 verifica longitud, MIME y metadata firmada; la confirmación además lee una
muestra para validar JPEG/M4A antes de declarar `available`. El archivo local se
conserva. La retención/borrado definitivo continúa abierta en D-13.

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

- API versionada, validación, error envelope e idempotencia de mutaciones
  soportadas, incluidas las correcciones de Lead y Evento y tombstone de Evento.
- Ownership/tenancy y persistencia de cuenta/workspace, perfil, eventos, Leads
  y metadata sin binarios.
- Autoridad futura del trial y suscripción, webhooks y reconciliación.
- Storage S3 protegido, retención y URLs no públicas.
- Sync reanudable de Leads y medios con colas independientes.
- Plantillas server-side, sustitución, adjuntos y correo mediante la identidad
  Google/Microsoft autorizada del vendedor (ADR-006/007, `PLT-*` y `SAL-*`).
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
7. Guardar prepara un follow-up local y abre “Revisar”; no sincroniza todavía
   ese follow-up ni crea intención. El CTA `foloo` congela la edición concreta,
   encola follow-up + intención en orden y dispara sync cuando hay conectividad.
   El snapshot revisado queda congelado antes de sync;
   destinatario, adjuntos y footer de baja se resuelven server-side. El backend
   envía con Google/Microsoft autorizada;
   los estados regresan al dispositivo. Una aceptación ambigua no se reintenta
   automáticamente.
8. Vencimiento limita solo nuevas capturas y nunca oculta datos existentes.

## Decisiones pendientes

Ver `../product/open-decisions.md`: pago/tiendas,
precio/vencimiento/reembolso, Voice Note, edición post-guardado, Teams, mockups
y retención. La base cloud quedó resuelta por ADR-003 y el contrato/proveedores
de correo por ADR-006/007. Solo el polish visual de Review espera mockup en
FL-019.5.
