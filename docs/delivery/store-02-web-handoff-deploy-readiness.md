# STORE-02.5 — Cognito Web y preparación de despliegue AWS DEV

> Documento histórico de readiness al 2026-10-21. No describe el estado final
> desplegado. Consulte
> [`store-02-account-deletion-closure.md`](store-02-account-deletion-closure.md).

- Fecha de corte: 2026-10-21
- Ambiente objetivo: AWS DEV (`837153590200`, `us-east-1`,
  `FolooBackend-dev`)
- Estado: **STORE-02.5 alineado y auditado localmente; no autoriza deploy, migración,
  activación ni eliminación**
- Trazas: `AUT-18`–`AUT-21`, `SYN-11`, `SYN-12`, `MON-13`,
  `INF-15`–`INF-21`, `RNF-09`, `RNF-10`, `RC-06`–`RC-10`, E-14 y D-13

Este documento reconcilia el código local posterior a las tres correcciones
críticas de STORE-02 con el estado de AWS DEV reportado por el responsable. No
sustituye `account-deletion-contract.md`, el OpenAPI ni las decisiones
pendientes. D-13 continúa abierta y `ADR-AD-01`–`ADR-AD-06` siguen siendo
candidatas no aceptadas.

## 1. Estado real al corte

### 1.1 Confirmado en el repositorio local

| Componente                      | Estado                                   | Evidencia y límite                                                                                                                                |
| ------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Confirmación e idempotencia     | Preparado localmente                     | Transición condicional `awaiting_confirmation -> requested`, `Idempotency-Key` de confirmación, receipt único cifrado y outbox DynamoDB atómico   |
| Despacho durable                | Preparado localmente, inactivo           | SQS FIFO, GSI `entity_type-created_at-index`, recuperador y regla EventBridge; Lambda y regla quedan apagadas                                     |
| Eliminación S3                  | Preparada localmente, no validada en DEV | Inventario durable anterior al borrado, paginación, lotes, retries y verificación contra manifest original                                        |
| Eliminación PostgreSQL          | Preparada localmente, no validada en DEV | Scope `user/account/workspace` congelado y verificación de todas las tablas owner-scoped actuales                                                 |
| Protección de nuevas escrituras | Preparada localmente, no aplicada        | Migración `010_account_deletion_write_fence.sql`, guard API/OAuth y quietud de 11 minutos para PUT presignados                                    |
| Restore/reconciliación          | Preparada localmente, inactiva           | Reaplica barrera y encola una purga owner-scoped idempotente; requiere `recoveryRunId` controlado                                                 |
| API Account Deletion            | Implementada, apagada                    | Controller real detrás de `FOLOO_ACCOUNT_DELETION_ENABLED`; controller fail-closed responde `503`                                                 |
| Flutter                         | Implementado, oculto                     | Entrada protegida por dart-define; conserva receipt en secure storage, pero no existe todavía una superficie post-logout para consultar su estado |
| Cognito guards                  | Lambdas sintetizadas, no adjuntas        | PreSignUp y PostAuthentication permanecen con flag `false`; CDK no modifica el User Pool preexistente                                             |
| Notificación transaccional      | Desacoplada y apagada                    | Modo explícito `disabled\|ses`; `disabled` no invoca la Lambda SES ni crea retries/DLQ, mientras receipt/status siguen siendo autoritativos       |
| Cognito Web                     | Preparado localmente, no desplegado      | App Client público separado, code grant, sin secreto, Cognito+Google, callbacks HTTPS exactos; PKCE S256 corresponde a `foloo-landing`            |
| API para navegador              | Preparada localmente, no desplegada      | Segunda audiencia JWT exacta y CORS limitado a `https://foloo.io`; conserva la audiencia móvil                                                    |
| Stripe/PRO                      | Bloqueado                                | La interfaz no simula cancelación; una suscripción activa no puede completar el flujo sin el proveedor real/política aprobada                     |

La suite local documentada antes de este handoff pasó backend, Flutter,
typecheck/build y synth. El synth repetido para este corte confirma:

- `FOLOO_UNLIMITED_QA_MODE=true`;
- `FOLOO_ACCOUNT_DELETION_ENABLED=false` en API, worker, finalizador y email;
- registration guard, outbox recovery, reconciler y SES verified en `false`;
- cola con `DelaySeconds=660`;
- GSI `entity_type-created_at-index`;
- `ACCOUNT_DELETION_NOTIFICATION_MODE=disabled` en API y worker;
- el template candidato agrega CORS exacto, cliente web y segunda audiencia,
  pero ninguno está desplegado todavía.

Validación local de STORE-02.5:

- `npm run typecheck`: aprobado;
- `npm run build`: aprobado;
- lint focalizado de código, infraestructura y pruebas modificadas: aprobado;
- `npm test`: 184/184 pruebas aprobadas;
- `cdk synth` DEV con Unlimited activo: aprobado usando los dos ARN KMS
  existentes y habilitados;
- `git diff --check`: aprobado.

La síntesis empaqueta la migración 010 dentro del asset, pero no la ejecuta.

### 1.2 Estado AWS DEV verificado read-only el 2026-10-21

- Identidad: cuenta `837153590200`, principal `foloo-deployer`, región
  `us-east-1`.
- Stack `FolooBackend-dev`: `UPDATE_COMPLETE`.
- Drift: `IN_SYNC`, cero recursos drifted.
- API Lambda y worker: activos, Account Deletion `false`; API conserva
  Unlimited `true`.
- El notification mode aún no existe en las Lambdas desplegadas, como se
  espera antes del deploy pasivo de STORE-02.4/02.5.
- Ledger DynamoDB: `ACTIVE`, cifrado y deletion protection activos, sin GSI.
- Cola Account Deletion: vacía y `DelaySeconds=0`.
- No existe Lambda/regla EventBridge de outbox recovery desplegada.
- HTTP API: sin CORS; authorizer acepta solo el cliente móvil
  `6jong3atp2crqcsde6g215ant8`.
- Cognito: solo existe `foloo-mobile-dev`; el App Client web aún no existe.
- Managed Login `us-east-1qvm3dwe4o` está `ACTIVE` para el User Pool esperado;
  Google existe como IdP. Microsoft también existe en el pool, pero queda
  excluido explícitamente del cliente web candidato.
- El cliente móvil conserva code grant, scopes `openid email profile`,
  callback `foloo://callback/` y logout `foloo://signout/`; STORE-02.5 no lo
  modifica.
- Las dos claves importadas están `Enabled`: HMAC-256
  `GENERATE_VERIFY_MAC` y recipient key `SYMMETRIC_DEFAULT`.
- Migración 009 fue confirmada previamente como aplicada. La 010 permanece
  documentada como pendiente; no se invocó MigrationFunction ni se consultó
  PostgreSQL en esta auditoría.

La ausencia del GSI/outbox/CORS/App Client y el estado actual de cola/API
confirman que las fases locales no están desplegadas. Debe repetirse el
preflight read-only inmediatamente antes de preparar el Change Set.

## 2. Handoff para `foloo.io/delete-account`

### 2.1 Frontera funcional

La web debe ser otra superficie del mismo proceso; no debe crear otro backend,
ledger ni identidad. El owner siempre deriva del claim Cognito `sub`. El email
es atributo verificado de presentación/bloqueo seudonimizado, nunca primary
key. Microsoft Sign-In continúa fuera de esta versión.

Flujo previsto:

1. `GET https://foloo.io/delete-account` muestra explicación, acceso y soporte.
2. Si no hay sesión, inicia Cognito Managed Login.
3. Cognito devuelve Authorization Code al callback HTTPS de la web.
4. El cliente web valida `state`, intercambia el code con PKCE y conserva el
   access token únicamente durante la sesión mínima necesaria.
5. La web llama los mismos endpoints STORE-02 con `Authorization: Bearer
<access-token>`.
6. Antes del preflight llama la verificación de reautenticación. Si `recent`
   es `false`, fuerza una interacción nueva de Cognito y vuelve a verificar;
   nunca envía passwords ni un booleano de confianza al backend.
7. Después de confirmar, guarda el receipt opaco de forma segura, elimina los
   tokens Cognito locales y consulta el estado mediante receipt.

### 2.2 App Client web preparado localmente

CDK prepara un App Client público separado en el mismo User Pool
`us-east-1_QVm3dWe4O`:

- sin Client Secret;
- Authorization Code Grant;
- PKCE S256 obligatorio en el cliente;
- scopes `openid email profile`;
- proveedores `COGNITO` y `Google`;
- callback `https://foloo.io/auth/callback`;
- logout `https://foloo.io/login`;
- sin implicit grant;
- sin Microsoft en esta versión.

Estas URLs deben ser confirmadas por TI contra el routing CloudFront/S3 antes
del deploy. El callback debe intercambiar el code y
limpiar code/state de la barra con `history.replaceState`; no debe enviarlos a
analytics, logs o soporte.

El template añade el client ID web a `jwtAudience` sin retirar el App Client
móvil `6jong3atp2crqcsde6g215ant8`. El `sub` del User Pool continúa siendo el
owner canónico entre ambos clientes. Cognito no tiene una propiedad de App
Client que imponga PKCE: `foloo-landing` debe generar verifier/challenge S256 y
validar `state`; no debe usar implicit grant ni un client secret.

Configuración que consume `foloo-landing` después del deploy pasivo:

| Clave          | Valor                                                    |
| -------------- | -------------------------------------------------------- |
| Region         | `us-east-1`                                              |
| User Pool      | `us-east-1_QVm3dWe4O`                                    |
| Hosted UI      | `us-east-1qvm3dwe4o.auth.us-east-1.amazoncognito.com`    |
| Web Client ID  | output CloudFormation `WebUserPoolClientId`              |
| Redirect URI   | `https://foloo.io/auth/callback`                         |
| Logout URI     | `https://foloo.io/login`                                 |
| Scopes         | `openid email profile`                                   |
| Response type  | `code` con PKCE S256                                     |
| API            | `https://zbc91cpy10.execute-api.us-east-1.amazonaws.com` |
| Browser origin | `https://foloo.io`                                       |

### 2.3 Managed Login, email/password y Google

- Email/password: se usa la pantalla administrada de Cognito; la web no recibe
  ni procesa la contraseña.
- Google: Managed Login fuerza el IdP Google ya configurado en el User Pool o
  permite elegirlo en la pantalla administrada.
- Reautenticación: usar una nueva autorización con interacción forzada
  (`prompt=login`, sujeto a validar contra el Managed Login vigente) y después
  comprobar otra vez `/v1/account-deletion-reauthentication/verify`. El backend
  decide mediante `auth_time` y la ventana actual de 300 segundos.
- Un refresh silencioso no es reautenticación suficiente.

Seguridad todavía debe aprobar el comportamiento exacto de reautenticación
para Google y email/password (`ADR-AD-06`). Si Cognito conserva una sesión
Hosted UI pese a `prompt=login`, la web no debe habilitar Confirmar: debe cerrar
la sesión administrada y reiniciar login, o aplicar el mecanismo aprobado.

### 2.4 CORS y seguridad del navegador

El template candidato configura CORS del HTTP API exclusivamente con:

- origin `https://foloo.io` (sin wildcard ni origen de preview implícito);
- métodos `GET`, `POST`, `OPTIONS`;
- headers `Authorization`, `Content-Type`, `Idempotency-Key`;
- exposición de `Retry-After` e `Idempotency-Replayed` solo si la web los usa;
- `max-age=3600` y sin credentials/cookies; la autorización usa Bearer token.

Esta política se aplica al HTTP API completo, pero no concede autorización:
las rutas protegidas siguen requiriendo JWT válido para una de las dos
audiencias exactas. Flutter no depende de CORS y conserva su audiencia móvil.

La web debe aplicar CSP, no persistir tokens/receipt en `localStorage`, no
incluirlos en URLs y redaccionarlos de telemetría. El status público acepta
solo receipt en body; el rate limit de la ruta debe mantenerse.

## 3. Contrato HTTP para el equipo web

Fuente canónica: `account-deletion-openapi.yaml`.

| Método y ruta                                            | Auth                                               | Entrada esencial                     | Éxito                                                             |
| -------------------------------------------------------- | -------------------------------------------------- | ------------------------------------ | ----------------------------------------------------------------- |
| `POST /v1/account-deletion-reauthentication/verify`      | Access JWT                                         | sin body                             | `200` con `recent`, `reauthenticationRequired`, `validUntil`      |
| `POST /v1/account-deletion-requests`                     | Access JWT + `Idempotency-Key`                     | `locale`, `requestedExport` opcional | `201` preflight `awaiting_confirmation`, sync/export/subscription |
| `POST /v1/account-deletion-requests/{requestId}/confirm` | Access JWT + el mismo `Idempotency-Key` en retries | acknowledgements explícitos          | `202` con estado `requested`, receipt y expiración                |
| `GET /v1/account-deletion-requests/current`              | Access JWT                                         | sin body                             | `200` con status mínimo o `null`                                  |
| `POST /v1/account-deletion-status`                       | público, rate-limited                              | `{ "receipt": "..." }`               | `200` con status mínimo                                           |

Reglas de integración:

- enviar el **access token**, no ID token;
- generar claves opacas de 8–128 caracteres y conservar la misma clave para
  retries de la misma operación;
- no regenerar la clave de confirmación después de timeout ambiguo;
- tratar `428` como reautenticación requerida;
- tratar `409` según code: solicitud pendiente, acknowledgement faltante o
  conflicto de idempotencia; no crear otra solicitud a ciegas;
- tratar `410` como preflight vencido y reiniciar el preflight;
- respetar `429`/`Retry-After`;
- `503 account_deletion_unavailable` es el resultado esperado mientras el flag
  esté apagado;
- un `404` del status por receipt no revela si existió una cuenta.

El receipt se devuelve una vez, tiene entropía de 256 bits, se persiste solo
hasheado en el workflow y expira a los 30 días. La web debe advertir que perder
el receipt elimina el autoservicio de seguimiento y remitir a
`hello@foloo.io` sin pedir PII innecesaria.

## 4. Operación sin SES obligatorio

STORE-02.4 implementa `ACCOUNT_DELETION_NOTIFICATION_MODE=disabled|ses`:

- `disabled` construye un notifier no-op y no invoca la Lambda de correo;
- la aceptación, el receipt único y la consulta de status no dependen del
  proveedor de notificación;
- no se generan retries ni mensajes de DLQ por correo intencionalmente apagado;
- una excepción real del notifier en modo `ses` se registra sin PII y no cambia
  `requested`, `completed` ni el resultado irreversible del workflow;
- los fallos reales de borrado conservan su camino `blocked`, checkpoints,
  observabilidad y retry;
- la Lambda/identidad SES existentes se conservan para una activación futura.

El valor CDK permanece `disabled` tanto en API como en worker y
`ACCOUNT_DELETION_SES_IDENTITY_VERIFIED=false`. No se simula un envío. Para
activar `ses` posteriormente se requiere identidad/sending habilitados,
bounce/complaint/suppression operativos y aprobación de Legal/Producto sobre
el canal de aviso. La consulta post-logout en la web sigue dependiendo de que
`foloo-landing` implemente el contrato receipt/status.

## 5. Diff CDK real pendiente de desplegar

`cdk diff --no-change-set` contra AWS DEV confirmó un stack con diferencias,
sin crear Change Set. El inventario corresponde a las fases 1–3 y
STORE-02.4/02.5:

### Altas

- `AccountDeletionOutboxRecoveryFunction` con role/policy acotados.
- Regla EventBridge cada minuto, creada `DISABLED`.
- Permiso EventBridge → Lambda.
- Alarma de errores del recuperador.
- GSI DynamoDB `entity_type-created_at-index` sobre el ledger existente.
- App Client Cognito `foloo-web-dev` en el User Pool existente, sin secret,
  code grant, Cognito+Google y URLs HTTPS explícitas.
- Output CloudFormation `WebUserPoolClientId`.

### Modificaciones in-place esperadas

- assets de API, worker, MigrationFunction, provider OAuth y reconciliador;
- cola Account Deletion FIFO: `DelaySeconds=660`;
- IAM worker: `s3:ListBucket` limitado a
  `media/workspaces/*` y `content/workspaces/*`;
- IAM reconciler: enviar a la cola;
- IAM recovery: Query DynamoDB, decrypt recipient y enviar SQS;
- bundle de MigrationFunction incluye 010 y sus checks;
- código de inventario, checkpoints, idempotencia, guard y restore.
- authorizer HTTP acepta exactamente el App Client móvil y el web;
- CORS HTTP queda limitado a `https://foloo.io` y los métodos/headers
  documentados;
- API y worker incorporan `ACCOUNT_DELETION_NOTIFICATION_MODE=disabled`.

### Sin cambios automáticos

- CDK no ejecuta migraciones.
- CDK no adjunta los triggers Cognito.
- Los dos KMS de Account Deletion deben importarse por ARN validado; `app.ts`
  falla si faltan, para no crear más claves retenidas.
- No se espera reemplazo de RDS, Cognito User Pool, bucket S3, tabla DynamoDB,
  queues ni KMS. Un `cdk diff` real y el Change Set son la autoridad; cualquier
  replacement o delete detiene el despliegue.
- STORE-02.4 no añade una KMS key. El synth conserva una sola
  `AWS::KMS::Key` ya definida por la infraestructura de email existente; las
  claves de Account Deletion continúan importándose por ARN.
- El diff no reporta bajas ni replacements. RDS, User Pool, bucket S3, tabla,
  queues y KMS no se reemplazan; la tabla y cola reciben updates in-place.

El GSI es una actualización online del ledger y debe esperarse `ACTIVE` antes
de habilitar recovery. El cambio de delivery delay afecta todos los mensajes
nuevos de la cola DEV, pero mientras el flujo esté apagado la cola debe estar
vacía.

## 6. Runbook de despliegue pasivo en AWS DEV

Todos los comandos son para ejecución manual posterior. No se ejecutaron en
esta auditoría. Sustituir los dos ARN con las claves **ya validadas**; no elegir
una de las claves retenidas por nombre o antigüedad.

```bash
cd backend
export FOLOO_IDENTITY_HMAC_KEY_ARN='<existing-validated-hmac-key-arn>'
export FOLOO_RECIPIENT_KEY_ARN='<existing-validated-recipient-key-arn>'
```

### 6.1 Preflight read-only

```bash
aws sts get-caller-identity --profile foloo-dev
aws cloudformation describe-stacks \
  --stack-name FolooBackend-dev \
  --profile foloo-dev --region us-east-1 \
  --query 'Stacks[0].StackStatus' --output text

aws cloudformation detect-stack-drift \
  --stack-name FolooBackend-dev \
  --profile foloo-dev --region us-east-1
# Usar el DetectionId devuelto en describe-stack-drift-detection-status y,
# al finalizar, revisar describe-stack-resource-drifts.
```

Confirmar cuenta `837153590200`, región `us-east-1`, estado
`UPDATE_COMPLETE`, queue/DLQ vacías, alarmas sin datos anómalos, Unlimited
`true` y todos los flags Account Deletion/registration/outbox/reconciler/SES
`false`.

### 6.2 Synth y diff

```bash
npx cdk synth FolooBackend-dev \
  --context environment=dev \
  --context unlimitedQaMode=true \
  --context accountDeletionIdentityHmacKeyArn="$FOLOO_IDENTITY_HMAC_KEY_ARN" \
  --context accountDeletionNotificationRecipientKeyArn="$FOLOO_RECIPIENT_KEY_ARN"

npx cdk diff FolooBackend-dev --no-change-set \
  --profile foloo-dev \
  --context environment=dev \
  --context unlimitedQaMode=true \
  --context accountDeletionIdentityHmacKeyArn="$FOLOO_IDENTITY_HMAC_KEY_ARN" \
  --context accountDeletionNotificationRecipientKeyArn="$FOLOO_RECIPIENT_KEY_ARN"
```

Detenerse ante KMS nuevos, replacement/delete de recursos persistentes,
triggers Cognito, flags activos, cambio de RDS/bucket/User Pool o recursos no
incluidos en el inventario anterior.

### 6.3 Drift/hotswap y Change Set

No usar `--hotswap` ni `--hotswap-fallback`. La detección de STORE-02.5 terminó
`IN_SYNC`; por tanto no se debe añadir `--revert-drift` al siguiente Change Set
salvo que una nueva detección muestre drift clasificado y aprobado. Preparar el
Change Set normal:

```bash
npx cdk deploy FolooBackend-dev \
  --profile foloo-dev \
  --method prepare-change-set \
  --change-set-name store-02-passive-readiness \
  --context environment=dev \
  --context unlimitedQaMode=true \
  --context accountDeletionIdentityHmacKeyArn="$FOLOO_IDENTITY_HMAC_KEY_ARN" \
  --context accountDeletionNotificationRecipientKeyArn="$FOLOO_RECIPIENT_KEY_ARN"
```

Revisar el Change Set en CloudFormation y cancelarlo ante replacements,
deletes o cambios no explicados. Solo después de aprobación expresa se ejecuta
ese Change Set.

### 6.4 Verificación posterior al deploy pasivo

- stack `UPDATE_COMPLETE`;
- tabla y GSI `ACTIVE`;
- queue/DLQ sin mensajes inesperados;
- regla outbox `DISABLED`;
- todos los flags Account Deletion en `false`;
- Unlimited `true`;
- Cognito sin triggers nuevos;
- output `WebUserPoolClientId` presente y App Client sin secret;
- authorizer con las dos audiencias exactas y CORS sin wildcard;
- `ACCOUNT_DELETION_NOTIFICATION_MODE=disabled` en API/worker;
- endpoints Account Deletion devuelven `503`;
- login, sync, leads, medios y follow-up smoke sin regresión;
- CloudWatch sin errores nuevos de API/provider/worker.

## 7. Procedimiento de migración 010

### 7.1 Orden correcto

1. Desplegar primero el stack **con todos los flags apagados** para que la
   MigrationFunction contenga el archivo 010.
2. Confirmar backup recuperable de RDS y ventana de baja actividad.
3. Invocar `status`; debe mostrar 009 aplicada, 010 pendiente, barrera 009
   consistente y cero write-fence triggers.
4. Confirmar el estado de las demás migraciones. La operación debe nombrar
   `010_account_deletion_write_fence.sql` mediante `only`, para no aplicar por
   accidente otra migración pendiente.
5. Con autorización separada, invocar `apply` una vez y solo para 010.
6. Repetir `status`: 010 aplicada y 18 triggers write-fence esperados.
7. Ejecutar los postchecks y smoke de escrituras normales mientras no existe
   ninguna cuenta pending.

### 7.2 Comandos

```bash
export FOLOO_MIGRATION_FUNCTION="$(aws cloudformation describe-stacks \
  --stack-name FolooBackend-dev --profile foloo-dev --region us-east-1 \
  --query "Stacks[0].Outputs[?OutputKey=='MigrationFunctionName'].OutputValue | [0]" \
  --output text)"

aws lambda invoke --function-name "$FOLOO_MIGRATION_FUNCTION" \
  --cli-binary-format raw-in-base64-out --payload '{"action":"status"}' \
  --profile foloo-dev --region us-east-1 \
  /tmp/foloo-account-deletion-status-before.json

# Solo después de backup, revisión del status y autorización explícita:
aws lambda invoke --function-name "$FOLOO_MIGRATION_FUNCTION" \
  --cli-binary-format raw-in-base64-out \
  --payload '{"action":"apply","only":"010_account_deletion_write_fence.sql"}' \
  --profile foloo-dev --region us-east-1 \
  /tmp/foloo-account-deletion-migration-010.json

aws lambda invoke --function-name "$FOLOO_MIGRATION_FUNCTION" \
  --cli-binary-format raw-in-base64-out --payload '{"action":"status"}' \
  --profile foloo-dev --region us-east-1 \
  /tmp/foloo-account-deletion-status-after.json
```

Esperado después: `writeFenceMigrationApplied=true`,
`writeFenceTriggerCount=18`, 009 válida y `inconsistentBarriers=0`.

### 7.3 Riesgos y recuperación

- Crear/recrear triggers toma locks DDL sobre 18 tablas. Ejecutar en ventana de
  baja actividad y vigilar timeout/locks; puede pausar escrituras brevemente.
- El SQL 010 contiene `BEGIN/COMMIT`; un error antes de `COMMIT` revierte sus
  funciones/triggers. Si el SQL confirma pero falla el registro en
  `schema_migrations`, una repetición vuelve a crear los objetos de forma
  idempotente, pero requiere revisión previa.
- No existe down migration aprobada. No retirar triggers automáticamente tras
  un fallo de aplicación: con flags apagados no afectan cuentas activas salvo
  error de implementación, y preservarlos evita abrir una carrera.
- Si los postchecks fallan, mantener Account Deletion apagado, detener el
  rollout, conservar logs/status y decidir entre corrección forward o restore
  de RDS. Un restore exige después el runbook de reconciliación antes de abrir
  tráfico.
- El advisory lock usa `hashtext(sub)`; una colisión solo serializa operaciones
  no relacionadas, pero debe observarse como riesgo de disponibilidad.

## 8. Checklist E2E con datos sintéticos

No iniciar hasta deploy pasivo, migración 010, App Client/CORS, aprobaciones y
autorización destructiva. Usar una cuenta DEV nueva sin datos reales.

### 8.1 Pre-activación

- [ ] Cero replacements/deletes inesperados en Change Set.
- [ ] 010 aplicada y 18 triggers verificados.
- [ ] KMS/HMAC/canonicalización y rotación aprobadas.
- [ ] PreSignUp/PostAuthentication probados primero en pass-through.
- [ ] Reauth Cognito validada con email/password y Google.
- [ ] Política SES obligatoria u opcional aprobada e implementada.
- [ ] Cuenta Free sintética; no usar cuenta PRO mientras Stripe no exista.
- [ ] Queue/DLQ/outbox/alarms observables y owner operativo asignado.
- [ ] Receipt/status visible sin sesión.
- [ ] Backup y recovery runbook listos.

### 8.2 Camino feliz por cada método Auth soportado

- [ ] Login email/password; repetir después con Google.
- [ ] Crear perfil, leads, media, PDF y conexión sender sintéticos.
- [ ] Obtener un presigned PUT antes de confirmar para validar la quietud.
- [ ] Reautenticar realmente; backend devuelve `recent=true`.
- [ ] Crear preflight y confirmar con una clave idempotente estable.
- [ ] Doble confirmación concurrente con la misma clave devuelve un solo
      request/receipt; otra clave produce conflicto.
- [ ] Token JWT anterior y segundo dispositivo no pueden sync, subir media,
      mutar datos ni completar callback OAuth.
- [ ] Worker comienza después de la quietud, avanza checkpoints y no duplica
      efectos en retry.
- [ ] S3 se verifica contra el manifest original; PostgreSQL queda en cero para
      todas las tablas del owner; otra cuenta conserva sus datos.
- [ ] OAuth queda inutilizable/eliminado antes de Cognito.
- [ ] Cognito global sign-out/delete ocurre al final.
- [ ] Receipt consulta `completed`; receipt inválido/expirado no filtra PII.
- [ ] Queue/outbox/DLQ quedan en estado esperado y logs no contienen PII.

### 8.3 Fallos controlados

- [ ] SQS no disponible después de aceptar: outbox recupera una sola ejecución.
- [ ] Fallo parcial S3/PostgreSQL/OAuth: status `blocked`, retry continúa desde
      checkpoint y nunca marca `completed` prematuramente.
- [ ] Fallo de notificación: no revierte ni falsea el estado de eliminación.
- [ ] Más de 1,000 objetos y dos owners.
- [ ] Restore controlado: tráfico cerrado, reconciler reestablece barrera,
      reencola purga y solo después se considera reapertura.
- [ ] Registro antes del día 30 bloqueado; desde el instante exacto permitido
      crea cuenta vacía. La política de trial para reingreso sigue pendiente y no
      debe inferirse del test.

## 9. Bloqueos antes de activar

### Críticos técnicos

1. Desplegar fases 1–3 pasivamente y aplicar/verificar migración 010.
2. Desplegar pasivamente y validar el App Client web, audiencia JWT y CORS ya
   preparados localmente.
3. Validar la reautenticación interactiva por proveedor: Flutter ya cierra la
   sesión, exige login del mismo `sub`, retoma el flujo y vuelve a consultar
   `auth_time`; web debe conservar PKCE S256 y el regreso seguro al flujo.
4. Aprobar formalmente la operación receipt/status sin correo o validar SES
   completamente; el desacoplamiento técnico ya está implementado.
5. Integrar en `foloo-landing` el seguimiento post-logout usando receipt.
6. Ejecutar E2E destructivo autorizado en una identidad QA sintética.

### Aprobaciones/operación

1. Seguridad: ADR-AD, canonicalización, KMS/rotación, fail-closed, receipt y
   reauth.
2. Infra: backup/restore, drift/hotswap, runbook, owner de alarmas y RTO/RPO.
3. Legal/Producto: D-13, retención, datos de terceros, 15 días, 30 días,
   notificación sin SES y copy final.
4. Payments: tratamiento de cuentas activas; Free no debe depender de Stripe.
5. TI web: callback/logout, routing CloudFront, CSP, soporte y publicación.

## 10. Próximos pasos priorizados

1. Aprobar este handoff con Backend/Infra/Web/Seguridad y resolver si SES es
   obligatorio.
2. Confirmar con TI las URLs exactas de callback/logout y con Seguridad el
   flujo de reautenticación interactiva.
3. Ejecutar `cdk diff`, drift report y Change Set pasivo; desplegar solo con
   flags apagados y Unlimited activo.
4. Verificar stack/GSI/Lambdas y después aplicar 010 con autorización separada.
5. Configurar la implementación local FOL-WEB-02 con el output
   `WebUserPoolClientId` y este contrato, sin tocar dashboard/pagos.
6. Validar reauth email/password + Google y receipt/status sin sesión.
7. Adjuntar triggers Cognito primero en pass-through; habilitar guards y flujo
   únicamente durante una ventana E2E autorizada.
8. Ejecutar la matriz con una cuenta Free sintética, revisar evidencia y volver
   a flags apagados. No declarar STORE-02 listo para producción con solo DEV.

## 11. FOL-AUTH-02 — servicio local de sesiones web

El backend prepara, sin desplegar ni activar, una Lambda BFF con estos contratos:

- `POST /api/auth/session/srp`: recibe transitoriamente el refresh token que
  resulta del SRP Cognito y crea una sesión opaca; nunca lo devuelve.
- `GET /api/auth/google/start` y `GET /api/auth/google/callback`: code grant
  Google mediante Cognito, `state` de un solo uso y PKCE S256.
- `GET /api/auth/session`, `POST /api/auth/session/refresh` y
  `POST /api/auth/logout`: restauración, renovación condicional y revocación.
- `/api/foloo/v1/account-deletion-*`: proxy de allowlist cerrado; no existe un
  proxy genérico para el API.

La cookie de sesión es `__Host-foloo_session`, `Secure`, `HttpOnly`,
`SameSite=Lax` y `Path=/`. DynamoDB guarda únicamente su SHA-256 y secretos
cifrados individualmente con contexto KMS; aplica TTL y expiración lógica.
Mutaciones requieren `Origin: https://foloo.io` y token CSRF. Las respuestas
usan `Cache-Control: no-store` y los logs omiten cuerpos, cookies, códigos,
tokens y PII.

Los valores DEV de 12 horas absolutas y 30 minutos de inactividad son
configurables y provisionales. `FOLOO_WEB_SESSION_ENABLED=false` fuerza 503
antes de leer credenciales. La ruta pública Cognito continúa siendo
`https://foloo.io/auth/callback`; `foloo-landing`/CloudFront deberá encaminarla
al callback interno del BFF sin cambiar la URI registrada. Esa integración,
la UX SRP, la reautenticación interactiva y la revisión de Seguridad son
dependencias de activación. El cliente móvil, STORE-02 y migración 010 no se
modifican.

## 12. FOL-AUTH-05 — identidad restaurada y callback Google nativo

`GET /api/auth/session` y `POST /api/auth/session/refresh` devuelven el mismo
contrato seguro de restauración:

```json
{
  "authenticated": true,
  "identity": {
    "sub": "identificador-cognito",
    "email": "verified@example.test",
    "emailVerified": true,
    "displayName": "Nombre Foloo"
  },
  "csrfToken": "token-opaco",
  "expiresAt": "fecha-ISO-8601",
  "idleExpiresAt": "fecha-ISO-8601",
  "authenticationTime": "fecha-ISO-8601"
}
```

`sub` proviene del access token validado y debe coincidir con la identidad
hasheada de la sesión. Para SRP, los atributos se leen con `GetUser`; para
OAuth, se usa `userInfo` con los scopes `openid email profile`, evitando pedir
el scope administrativo de Cognito solo para restaurar el perfil. La respuesta
autoritaria también debe coincidir en `sub`. `email` solo se devuelve cuando
Cognito presenta `email_verified=true`; de otro modo vale `null` y
`emailVerified` conserva `false` o `null`. `displayName` se obtiene de
`GET /v1/profile`, que ya está aislado por owner; si no existe perfil o nombre
vale `null`. Un fallo del proveedor o un contrato inválido no se disfraza como
atributo ausente. Nunca se devuelve el access token, refresh token ni username
técnico de Cognito.

La URI publicada `https://foloo.io/auth/callback` se conserva para el flujo
actual. El App Client web declara adicionalmente
`https://foloo.io/api/auth/google/callback`, utilizada exclusivamente por el
BFF. Así CloudFront puede aplicar su behavior `/api/*` existente sin crear un
dispatcher en la ruta legacy. El inicio Google fuerza `prompt=select_account`,
mantiene Authorization Code Grant y PKCE S256, y la transacción guarda un
`state` de un solo uso. El BFF no consume un ID token: la defensa aplicable es
`state` + PKCE y la identidad final se lee mediante access token validado;
`nonce` será obligatorio si una revisión futura empieza a consumir ID tokens.

Dependencias de `foloo-landing` antes de habilitar:

1. Consumir `identity` en restauración y refresh, aceptando valores nullable.
2. Iniciar Google en `/api/auth/google/start` con cookies incluidas y permitir
   las redirecciones del navegador.
3. Mantener `/api/*` sin caché, reenviando query string y cookies, y preservando
   `Set-Cookie`; no enrutar el callback nativo por `/auth/callback`.
4. Conservar `nativeAuthEnabled:false` hasta desplegar el backend pasivo y
   completar QA SRP/Google con cuentas sintéticas.

El despliegue posterior requiere únicamente añadir el segundo callback al App
Client web y actualizar código/configuración de `WebSessionFunction`. No cambia
el cliente móvil ni CloudFront si el behavior `/api/*` verificado se conserva.
STORE-02, SES y Web Sessions permanecen deshabilitados; migración 010 continúa
pendiente.

## 13. FOL-AUTH-08 — activación QA restringida

El callback BFF termina en `/dashboard`, no en `/delete-account`. El dashboard
es una ruta privada existente: restaura la cookie opaca HttpOnly y, sin sesión,
regresa a `/login`. El cambio no altera las URI registradas en Cognito, el
callback legacy ni transporta tokens en la URL.

La activación real queda protegida por dos contextos CDK DEV:

- `webSessionQaEnabled`, falso por defecto.
- `webSessionQaSubjectHashes`, lista separada por comas de SHA-256 base64url
  calculados como `SHA-256("foloo-web-session\0" + sub)`.

Nunca se despliega el `sub` ni el correo en texto claro. Habilitar sin al menos
un hash válido, usar un hash mal formado o intentar habilitar fuera de DEV
falla antes de sintetizar. La misma allowlist se aplica después de Cognito a
SRP y Google, antes de persistir una sesión, y en cada restauración; retirar un
hash revoca el acceso efectivo de sesiones existentes. Una identidad excluida
recibe el mismo `401 web_session_unauthorized`, y sus credenciales de refresh se
revocan sin revelar si pertenece a la lista.

### Secuencia controlada

1. Crear exclusivamente cuentas Cognito QA sintéticas y verificar su `sub` sin
   registrar correo, contraseña ni token en archivos o comandos compartidos.
2. Calcular localmente los hashes anteriores y preparar un primer Change Set
   pasivo con allowlist, destino `/dashboard` y
   `webSessionQaEnabled=false`. Auditar que Unlimited siga `true`, STORE-02 y
   todos sus guards/reconcilers/SES sigan `false`, y que no existan reemplazos.
3. Desplegar pasivamente backend y frontend con `nativeAuthEnabled:false`.
   Confirmar 503 en las seis rutas de sesión y regresión del login legacy.
4. Preparar un segundo Change Set que cambie únicamente código/configuración de
   WebSessionFunction y `FOLOO_WEB_SESSION_ENABLED=true`, conservando la misma
   allowlist. Ejecutarlo solo durante una ventana QA con monitoreo.
5. Habilitar el frontend únicamente para testers autorizados. No usar el flag
   público como control de seguridad: el backend es la barrera obligatoria.

### Matriz E2E y evidencia

| Caso                      | Resultado aprobatorio                                                     | Evidencia no sensible                         |
| ------------------------- | ------------------------------------------------------------------------- | --------------------------------------------- |
| SRP permitido/denegado    | QA entra; identidad fuera de lista recibe 401 y no crea sesión            | status, request ID y conteo agregado DynamoDB |
| Google y cambio de cuenta | selector visible; QA permitido llega a dashboard; excluido no entra       | secuencia de rutas sin query/código y status  |
| Restauración/perfil       | recarga conserva `sub`, correo verificado y nombre nullable correctos     | captura sin tokens/cookies                    |
| Cookies/CSRF              | cookie Secure+HttpOnly+SameSite=Lax; mutación sin Origin/CSRF falla       | headers redactados y códigos 403/2xx          |
| Refresh/logout            | rotación concurrente converge; logout revoca y siguiente restore da 401   | códigos, versiones/estado agregado            |
| Expiraciones              | 30 min inactiva y 12 h absoluta rechazan; renovar no extiende la absoluta | timestamps redondeados y códigos              |
| Aislamiento               | dos QA no comparten perfil, sesión ni CSRF                                | IDs sintéticos y assertions de owner          |
| Sesiones simultáneas      | cada navegador conserva sesión independiente; logout no cruza usuarios    | estados agregados por sesión                  |
| Regresión                 | login legacy web y móvil siguen operativos; STORE-02 continúa oculto      | checklist manual separado                     |

No se inspecciona el valor de cookies HttpOnly desde JavaScript: se verifica en
DevTools/Playwright por atributos y comportamiento. CloudWatch debe permanecer
sin cuerpos, cookies, credenciales, códigos, tokens ni PII. Revisar errores,
throttles y errores DynamoDB durante toda la ventana; las alarmas no garantizan
notificación si no existe un destino operativo configurado.

### Rollback

Primero volver `nativeAuthEnabled:false`; después ejecutar un Change Set que
restaure `FOLOO_WEB_SESSION_ENABLED=false`. Verificar 503 y login legacy. Para
invalidación inmediata adicional, vaciar la allowlist en el mismo cambio; no
borrar la tabla ni la clave KMS. Las sesiones persistidas quedan inutilizables
por el flag/allowlist y expiran por política/TTL. No se modifica STORE-02 ni se
aplica migración 010.

## 14. FOL-AUTH-09A — barrera del Web App Client en `/v1/*`

El JWT authorizer continúa validando firma, issuer, expiración y audiencia para
los clientes móvil y web. La audiencia web por sí sola no autoriza acceso
directo: antes de ejecutar cualquier ruta protegida, `ApiFunction` valida los
claims verificados `token_use=access`, `iss`, `exp`, `sub` y `client_id`.

- El Mobile App Client conserva acceso sin depender del flag web.
- El Web App Client requiere simultáneamente
  `FOLOO_WEB_SESSION_ENABLED=true` y que
  `SHA-256("foloo-web-session\0" + sub)` en base64url pertenezca a
  `WEB_SESSION_QA_SUBJECT_HASHES`.
- Con flag falso o allowlist vacía, todo token web queda cerrado. No se acepta
  `aud`, headers ni parámetros como sustituto del `client_id` verificado del
  access token.
- El BFF usa el mismo access token web para `/v1/profile`; por tanto funciona
  para SRP y Google únicamente cuando el sujeto QA está autorizado. Los únicos
  bypass son los contratos públicos ya existentes: receipt-status y callback
  OAuth de correo.

La comparación de los templates desplegado y del Change Set
`fol-auth-09-passive-qa-guard` demostró propiedades idénticas en diez
`AWS::Lambda::Permission` y en la integración SRP. CloudFormation propagó la
evaluación dinámica de `Fn::GetAtt(WebSessionsFunction, Arn)`; el nombre físico
de la Lambda no cambia. Los diez permisos tienen recreación condicional porque
`FunctionName` es immutable, pero no existe diferencia efectiva en sus
propiedades; la integración declara `Replacement: False`. El Change Set viejo
no debe ejecutarse: un Change Set nuevo debe incluir además código y variables
de `ApiFunction` para esta barrera y volver a auditar las dependencias.
