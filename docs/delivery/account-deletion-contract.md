# STORE-02D — Contrato de eliminación integral de cuenta

- Estado: **acuerdos de Producto/CBQA comunicados; pendiente autorización formal
  de implementación y validaciones Legal/Seguridad/Infra/Payments**
- Fecha: 2026-10-20
- Alcance: Foloo V1, iOS/Android, recurso web y backend AWS
- Decisión abierta: `D-13`
- Trazas canónicas STORE-02E-01: `AUT-18`–`AUT-21`, `SYN-11`, `SYN-12`,
  `MON-13`, `INF-15`–`INF-21`, `RNF-09`, `RNF-10`, `RC-06`–`RC-10` y E-14;
  reutiliza `AUT-10`, `SYN-01`–`SYN-10`, `INF-02`–`INF-14` y ADR-001–007
- Decisiones/arquitectura: ADR-001–ADR-007
- Preparación técnica STORE-02E:
  [`account-deletion-technical-design.md`](account-deletion-technical-design.md)
- Requisitos y trazabilidad STORE-02E-01:
  [`account-deletion-requirements-traceability.md`](account-deletion-requirements-traceability.md)

Este documento convierte la propuesta preliminar de STORE-02C en un contrato
técnico verificable para STORE-02E. No es asesoría legal, no autoriza una
migración o despliegue y **no cierra `D-13`**. El 2026-10-20 se comunicaron los
acuerdos de Producto/CBQA para `DEC-AD-01`–`DEC-AD-14`. Esos acuerdos fijan
dirección funcional, pero no equivalen a una aprobación conjunta de Legal,
Seguridad, Infra, Payments ni a autorización para implementar STORE-02E. Cada
validación y responsable pendiente se conserva explícitamente.

## 1. Resultado y límites de STORE-02D

Foloo no tiene hoy eliminación integral de cuenta. Logout, tombstones de
Event/Lead/Content y desconexión de sender son operaciones distintas. El flujo
propuesto debe eliminar la cuenta y los datos asociados bajo control de Foloo,
preservar únicamente las excepciones aprobadas, impedir que sync o una sesión
antigua reconstruyan datos y producir una confirmación sin PII.

Este contrato adopta como dirección técnica:

1. solicitud autenticada e idempotente;
2. barrera durable `deletion_pending` antes de cualquier borrado;
3. job asíncrono orquestado, reanudable y observable;
4. Cognito como último sistema activo que se elimina;
5. purga local selectiva por Cognito `sub`;
6. una ruta web que usa el mismo pipeline backend;
7. retención solo para categorías administrativas, contables o legales cuya
   base y plazo sean confirmados por Legal/Contabilidad;
8. posibilidad de crear una cuenta nueva con el mismo correo solo después de
   30 días, sin restaurar datos ni beneficios de la cuenta eliminada.

Producto definió un máximo operativo de 15 días para completar o escalar la
eliminación; el proceso comienza cuanto antes y no existe una espera obligatoria.
Su viabilidad operativa y cumplimiento por región siguen pendientes. La
retención ordinaria de backups por 15 días y la reautenticación reciente de
cinco minutos continúan como propuestas sujetas a Infra/Seguridad. Son tres
relojes distintos: eliminación operativa, expiración de backups y frescura de
autenticación.

## 2. Hechos verificados en la implementación actual

- Cognito `sub`, no email, determina ownership. API Gateway valida JWT y el
  backend resuelve `sub → app_user → account → workspace`.
- `ensure_personal_workspace(subject)` crea de nuevo esa cadena si no encuentra
  un workspace personal activo. Sin una barrera previa, una solicitud retrasada
  o sesión antigua podría reprovisionar una cuenta parcialmente borrada.
- PostgreSQL usa claves foráneas mayoritariamente sin `ON DELETE CASCADE`; la
  limpieza requiere un orden explícito.
- Drift schema v12 conserva perfil, eventos, Leads/medios, Content, templates,
  follow-ups/intents, conexión sender, entitlement, reservas, preferencias y
  outbox por owner. Algunas filas heredadas admiten owner nulo.
- Medios/PDF viven en storage privado local y S3; PostgreSQL conserva metadata
  y object keys. El bucket es privado, no versionado, `RETAIN` y sin lifecycle.
- ApiFunction posee hoy `s3:GetObject`/`s3:PutObject`, no `DeleteObject`.
- Desconectar sender solo marca la conexión `disconnected`; no demuestra
  revocación remota ni borra ciphertext.
- `Amplify.Auth.signOut()` termina la sesión móvil, pero no elimina Cognito,
  PostgreSQL, S3, Drift ni medios.
- DEV conserva backup RDS por un día y logs API/provider/migration por una
  semana. PROD y su política de recuperación continúan pendientes.

## 3. Invariantes del contrato

1. El backend deriva identidad exclusivamente del JWT Cognito validado; email,
   username técnico, body o receipt nunca sustituyen `sub` como owner.
2. La operación es idempotente. Repetir la misma solicitud devuelve el mismo
   request/receipt y nunca inicia dos limpiezas concurrentes.
3. La barrera se confirma en PostgreSQL antes de responder que la solicitud fue
   aceptada. Desde entonces no se admiten nuevas mutaciones, OAuth, envíos ni
   consumo ordinario de outbox.
4. Un JWT firmado que aún no expire no puede evadir la barrera. Revocar tokens
   no sustituye la verificación server-side de `deletion_pending`.
5. Ningún pull, retry, callback OAuth, idempotency replay o provisión automática
   puede resucitar la cuenta o sus entidades.
6. El job nunca borra por email, nombre o prefijo aportado por Flutter. Trabaja
   con account/workspace/user y keys resueltos server-side.
7. Cognito se elimina al final, después de que datos/credenciales controlados
   por Foloo estén borrados o formalmente retenidos.
8. La purga local afecta solo al owner solicitado. No borra filas ni archivos
   de otra cuenta utilizada en el mismo dispositivo.
9. La UI no presenta “eliminada” hasta recibir un estado backend verificable.
   Sin red solo puede mostrar que la solicitud aún no fue enviada.
10. Fallos parciales quedan en un estado recuperable; nunca se ocultan como
    éxito y nunca obligan a repetir etapas ya confirmadas.
11. Backups restaurados deben reaplicar el ledger/barrera de eliminaciones antes
    de aceptar tráfico; de otro modo podrían reintroducir datos borrados.
12. Copias ya exportadas, correos aceptados por Gmail/Graph/destinatarios y
    archivos guardados en apps externas quedan fuera del control técnico de
    Foloo y deben explicarse en la política.

## 4. Matriz de datos y disposición propuesta

`Borrar` significa eliminación física del sistema indicado. `Retener` requiere
base y plazo aprobados; sin ellos la fila permanece bloqueada para STORE-02E.

| Categoría | Owner / ubicación actual | Dependencias | Disposición propuesta | Riesgo / decisión pendiente |
|---|---|---|---|---|
| Identidad Cognito | User Pool; `sub`, username, email, proveedor, atributos y sesiones | Root de ownership y login | Resolver server-side el Cognito Username exacto, global sign-out/revocación y `AdminDeleteUser` al final | Federados requieren su username técnico, nunca uno enviado por Flutter; linking Google/Apple futuro; reautenticación y SLA |
| `app_users` | PostgreSQL, por `cognito_sub` | Accounts, memberships, perfil, Leads y email | Borrar al final de la transacción de datos | Barrera no puede depender de esta fila después del borrado |
| Account/workspace/member | PostgreSQL | Contenedor de todos los recursos y entitlement | Marcar pending; borrar después de hijos | Teams futuro fuera de V1; suscripción pendiente FL-021 |
| Perfil vendedor | PostgreSQL `seller_profiles`; Drift `LocalProfiles`; foto local/url | Firma de templates/intents y Drawer | Borrar DB/local/foto S3 si existe | Retención no justificada hoy |
| Events | PostgreSQL/Drift | Leads, templates de evento y Content assignments | Borrar después de Leads/templates; no solo tombstone | Leads históricos referencian Event |
| Leads y contacto | PostgreSQL/Drift | Media, email follow-ups, outbox, trial | Borrar junto con notas y snapshots | Datos de terceros; rol CBQA/vendedor requiere Legal |
| Tarjeta, referencias y voz | Archivos privados + Drift; S3 + `lead_media` | Lead, key derivada por workspace | Capturar keys, borrar S3 con verificación y luego metadata/local | Consentimiento; objetos huérfanos; D-05/D-06 |
| Content/PDF | Archivo privado + Drift; S3 + `content_files` | Events y snapshots de email | Capturar keys, borrar S3, metadata/asignaciones y copia local | Copias adjuntas ya enviadas no son recuperables por Foloo |
| Templates Event/Direct | Drift/PostgreSQL | Owner, Event, idioma | Borrar | Pueden contener firma/datos personales |
| Follow-ups e intents | Drift/PostgreSQL | Lead, conexión, Content, remitente/destinatario | Borrar cuerpo, destinatario, IDs y estado salvo excepción aprobada | Historial/evidencia de envío y obligaciones legales |
| Copias Gmail/Graph/destinatario | Proveedor y buzones externos | Envío ya aceptado | Fuera de control; no prometer borrado | Debe comunicarse explícitamente |
| Conexión OAuth sender | PostgreSQL; subject/address/ciphertext/KMS/status | Google/Microsoft/provider Lambda | Intentar revocar; borrar ciphertext, states y PKCE | Política por proveedor y conducta si revocación falla |
| OAuth states/PKCE | PostgreSQL, temporal y cifrado | Callback público | Invalidar/borrar inmediatamente | Callback tardío debe quedar bloqueado |
| Opt-outs/tokens históricos | PostgreSQL, hashes/ciphertext | Historial de correo | Borrar o retener minimizado según Legal | FL-019.5 retiró comportamiento activo, no las tablas |
| Trial/entitlement | Account + Drift reservations/snapshot | Creación histórica de Leads | Borrar; una cuenta nueva no recupera beneficios anteriores | Si se justifica prevención de abuso, usar solo registro seudonimizado mínimo con finalidad/plazo aprobados |
| Idempotency records | PostgreSQL | Mutaciones/replays | Borrar con workspace; receipt de deletion usa ledger separado | Ventana mínima post-delete por retries requiere plazo |
| Drift estructurado | `foloo.sqlite`, owner-scoped | UI, sync y múltiples cuentas del dispositivo | Purga transaccional selectiva | Owner nullable histórico no se adjudica ni borra por inferencia |
| Outbox | Drift `SyncOperations` | Mutaciones y snapshots JSON | Detener y purgar para ese owner tras aceptación | Elegir conducta de pendientes antes de confirmar |
| Preferencias | Drift owner-scoped + legacy global | Tema, idioma/onboarding/auth bootstrap | Borrar solo `LocalUserPreferences` del owner | No borrar globales ni valores de otra cuenta |
| Archivos privados locales | Directorio de aplicación | Paths Drift y foto por owner | Manifest local reintentable y borrado solo bajo root gestionado | No perder paths antes de terminar borrado de archivos |
| Exportaciones | Temporal Foloo y destino elegido por usuario | App receptora/share sheet | Borrar temporal gestionado; destino externo fuera de control | Informar límites de alcance |
| Logs técnicos | CloudWatch | Diagnóstico/requestId | No registrar PII; expirar según plazo aprobado | Retención PROD y accesos `APROBACIÓN REQUERIDA` |
| Backups/snapshots | RDS/AWS | Recuperación operativa | Propuesta: expiración ordinaria en 15 días; restore reaplica ledger antes de servir | Infra/Seguridad validan viabilidad; Legal separa legal hold del backup ordinario |
| Registros administrativos/contables/legales | Sistemas contables, facturación o evidencia de pago futuros | Compras, suscripciones, facturas y obligaciones aplicables | Retener únicamente categorías realmente exigidas, aisladas del producto, y eliminar al vencer su plazo | Legal/Contabilidad definen categorías, base, región, acceso y plazo; no retención indefinida por defecto |
| Request/receipt de deletion | Nueva persistencia minimizada | Idempotencia, soporte, anti-resurrección y bloqueo de nuevo registro por 30 días | Conservar solo hashes/estado/timestamps/códigos no PII durante el plazo mínimo aprobado | Diseño técnico debe cubrir email verificado e IdP externo sin conservar PII innecesaria |
| Métricas/auditoría administrativa | Nueva telemetría sin payload | Operación/seguridad | Conteos y stage/error sanitizados | Acceso, plazo y responsable `APROBACIÓN REQUERIDA` |

## 5. Arquitectura propuesta

```text
Flutter o recurso web
  │ JWT Cognito + prueba de autenticación reciente + idempotency key
  ▼
POST /v1/account-deletion-requests
  │ transacción: request + deletion_pending + barrera subject_hash
  ▼
Step Functions (ejecución = requestId, una sola vez)
  ├─ revocar sender mediante EmailProviderFunction
  ├─ borrar/verificar objetos S3 mediante worker acotado
  ├─ borrar/anonimizar PostgreSQL en orden de FK
  ├─ global sign-out Cognito
  └─ AdminDeleteUser Cognito + completar receipt

GET /v1/account-deletion-requests/current
  └─ estado autenticado mientras Cognito siga activo

POST /v1/account-deletion-status con receipt opaco en el body
  └─ solo estado no PII cuando Cognito ya no exista; nunca token en URL
```

### 5.1 Fronteras

- **ApiFunction:** autentica, comprueba reautenticación, crea/consulta request y
  aplica barrera. No recibe permisos destructivos de S3/Cognito.
- **Orquestador:** conserva stage/retry y llama workers. Su execution name es el
  request UUID para impedir ejecuciones duplicadas.
- **DB worker en VPC:** congela keys, aplica eliminación relacional y retención
  aprobada. No tiene permiso Cognito.
- **S3 worker:** recibe solo workspace/request resuelto, usa keys congeladas y
  valida cada resultado de `DeleteObjects`.
- **Provider boundary:** amplía el contrato existente para revocar Google/
  Microsoft best effort verificable y destruir ciphertext/state/PKCE.
- **Identity finalizer fuera de VPC:** solo `AdminUserGlobalSignOut` y
  `AdminDeleteUser` sobre el User Pool Foloo. Cognito sigue siendo broker.
- **Flutter/web:** nunca reciben object keys, ciphertext, secretos, IAM ni una
  lista de recursos a borrar.

Step Functions es la alternativa recomendada porque las etapas atraviesan RDS,
S3, proveedores y Cognito, pueden exceder el timeout de ApiFunction y necesitan
retry individual. Un endpoint síncrono monolítico queda rechazado por riesgo de
timeout y borrado parcial.

### 5.2 Barrera anti-resurrección

La migración debe introducir un ledger durable separado de `app_users`, con un
`subject_hash = HMAC(secret, cognito_sub)`; no email ni `sub` crudo como receipt.
El backend calcula el hash y, bajo el mismo advisory lock de provisión:

1. consulta la barrera;
2. rechaza `pending/completed` con `account_deletion_pending` o
   `account_deleted`;
3. solo si no existe barrera ejecuta provisión normal.

`ensure_personal_workspace` debe sustituirse o envolverse por una resolución
atómica que incluya esa comprobación. Revisar la barrera únicamente después de
provisionar deja una carrera y no es aceptable.

Todos los endpoints protegidos, callbacks OAuth, sync push/pull y replay de
idempotencia aplican la misma resolución. Un token revocado aún puede conservar
una firma/expiración válidas para verificadores JWT; por eso Cognito global
sign-out no reemplaza esta barrera.

La barrera debe impedir también que una identidad nueva —incluido un IdP
externo— recree la cuenta con el mismo correo verificado durante 30 días. Al
vencer el plazo podrá registrarse como cuenta totalmente nueva, sin restaurar
datos, beneficios ni relaciones anteriores. El identificador mínimo, su HMAC,
normalización, rotación y resolución entre proveedores quedan pendientes de
diseño y validación de Seguridad/Legal; no se autoriza conservar email en claro.
Una restauración de backup debe importar/aplicar el ledger más reciente antes
de abrir el backend a tráfico.

En la aceptación se resuelve también el Cognito Username exacto desde claims
confiables o una consulta administrativa por `sub`; nunca desde el body móvil.
Es temporal, se protege hasta el finalizer y se elimina al completar. Esto es
necesario porque una identidad federada puede requerir su username técnico en
`AdminUserGlobalSignOut`/`AdminDeleteUser`, mientras `sub` continúa siendo el
owner canónico de los datos Foloo.

## 6. Estado y ciclo de vida

### 6.1 Estados server-side

| Estado | Significado | Operaciones permitidas |
|---|---|---|
| `requested` | Solicitud aceptada y barrera confirmada | Consultar estado; iniciar job |
| `in_progress` | Al menos una etapa está ejecutándose/reintentando | Consultar estado; ninguna mutación de producto |
| `blocked` | Requiere intervención o decisión; no es fracaso silencioso | Consultar estado/soporte; barrera permanece |
| `completed` | Datos controlados por Foloo eliminados/retención aplicada y Cognito finalizado | Solo receipt opaco hasta su expiración |

No existe estado de cancelación después de la aceptación definitiva del
backend. `failed` no debe ser terminal: un error técnico queda `in_progress`
con retry o `blocked` con código sanitizado. Nunca se reactiva la cuenta
automáticamente ni se restaura la cuenta anterior.

### 6.2 Solicitud y reautenticación

1. La persona abre Cuenta → Eliminar cuenta.
2. Foloo consulta backend y muestra datos en alcance, outbox pendiente y límites
   de datos externos/retención.
3. Se exige prueba de autenticación reciente. Producto propone una ventana
   máxima de cinco minutos, siempre verificada por backend; Seguridad debe
   validar la señal y el mecanismo para email/password y Google. No basta
   confirmar email en UI ni enviarlo en el body.
4. Confirmación destructiva explícita genera una idempotency key.
5. Backend crea request+barrera en una transacción y devuelve requestId, receipt
   opaco y estado. Solo entonces el cliente detiene sync y purga local.
6. El receipt-capability se conserva temporalmente en secure storage separado
   de la sesión, nunca en Drift/logs/URL, y se elimina al completar/expirar.
7. El orquestador continúa aunque el dispositivo cierre la app.

### 6.3 Orden remoto obligatorio

1. Congelar inventario de object keys y recursos por workspace.
2. Invalidar callbacks OAuth y bloquear nuevos envíos.
3. Intentar revocación del sender; borrar credenciales cifradas cuando la
   política de fallo aprobada lo permita.
4. Borrar S3 por lotes y comprobar individualmente `Deleted`/`Error`. Una key
   ausente cuenta como estado idempotente esperado.
5. En una transacción PostgreSQL, borrar en orden:
   send intents → follow-ups → templates/event templates → conexiones/states/
   opt-outs → lead media → Leads → Events/Content → idempotency → perfil →
   memberships → workspace → account → app_user. La migración definitiva debe
   derivar el orden desde constraints reales y probar rollback.
6. Aplicar retenciones aprobadas en un almacén separado y minimizado; nunca
   dejar datos activos accesibles por el workspace eliminado.
7. Ejecutar global sign-out y luego `AdminDeleteUser`.
8. Marcar receipt `completed` sin email, nombre, payload u object keys.

Si S3/provider falla, no se eliminan antes las referencias necesarias para
reintentar. Si PostgreSQL hace rollback, la barrera y request permanecen en un
almacén/tabla fuera de la transacción destructiva.

### 6.4 Purga local owner-scoped

Tras aceptación remota, no tras completar todo el job:

1. detener timers/engine para ese `ownerSub`;
2. crear un manifest local reintentable de paths gestionados asociados al
   perfil, Content y Lead media de ese owner;
3. borrar archivos solo si están dentro del root privado Foloo;
4. en transacción Drift borrar outbox, intents/follow-ups/templates/conexión,
   reservas/entitlement, media mediante join con Leads, Leads, Content, Events,
   perfil y preferencias owner-scoped;
5. preservar filas legacy con owner nulo y datos de otros owners;
6. cerrar sesión y limpiar secretos Auth; conservar el receipt-capability en
   secure storage aislado solo hasta completar/expirar y mostrar su estado.

Si el filesystem falla, el manifest permite reintentar sin conservar filas de
producto visibles. Nunca se ejecuta un wipe global de la base compartida.

## 7. Casos operativos

### Sin conexión

- No se acepta ni se presenta como enviada una eliminación offline.
- La pantalla explica que necesita Internet y conserva solo el estado visual;
  no usa la outbox ordinaria para una acción destructiva con reautenticación.
- Captura y demás comportamiento actual continúan hasta que el backend acepte
  la solicitud.

### Outbox pendiente

- Antes de confirmar se muestra el número de cambios/medios pendientes y se
  ofrece sincronizar.
- La recomendación es permitir continuar solo con confirmación expresa de que
  esos datos locales también se eliminarán y quizá nunca lleguen al backend.
- Después de aceptar la solicitud, ninguna operación pendiente se envía; se
  purga con el owner. Esta conducta requiere aprobación de Producto.

### Múltiples dispositivos

- La primera solicitud coloca la barrera global.
- Los demás dispositivos reciben el error estable en su próximo request/pull,
  detienen sync, purgan ese owner y cierran sesión.
- Un cliente antiguo puede no comprender el copy, pero backend nunca acepta sus
  escrituras. La compatibilidad mínima es un error 423 con code estable y sin
  detalles internos.

### Solicitudes repetidas

- Mismo owner + idempotency key devuelve la misma solicitud.
- Una key distinta mientras existe request activo devuelve la solicitud activa,
  no crea otra ejecución.
- Después de `completed`, la barrera responde `account_deleted` durante 30 días
  y el receipt vigente permite consultar únicamente estado.
- Antes de 30 días, un alta con el mismo correo verificado —también mediante
  proveedor externo— se rechaza sin reprovisionar. Después puede crear una
  cuenta nueva, sin datos, beneficios o referencias de la anterior.

### Fallos parciales

- Retries por etapa con backoff y límites operativos.
- `blocked` requiere código no PII, alarma y runbook; nunca reactiva la cuenta.
- Las acciones destructivas son idempotentes: ausencia de fila/objeto/usuario
  cuenta como éxito si el request demuestra que pertenecía al scope congelado.
- Intervención administrativa requiere rol separado y auditado; no edita
  manualmente owner/object keys desde Flutter.
- El owner operativo de incidentes aún no está designado por CBQA; los límites
  de retry, alerta y escalamiento no pueden darse por cerrados hasta asignarlo.

### Retención legal y backups

- Un legal hold aprobado prevalece solo para categorías/plazos documentados.
- Datos retenidos se aíslan del producto, minimizan y dejan de estar disponibles
  para login/sync/uso comercial.
- Backups expiran según política; no se prometen mutaciones selectivas dentro de
  snapshots. Todo restore reaplica el ledger de eliminaciones.
- La UI/política informa claramente categorías y plazo aprobado. Sin aprobación
  no puede publicarse un tiempo concreto.

### Suscripción PRO futura

- La dirección de Producto prevé gestionar suscripciones y pagos desde
  `foloo.io`, no mediante compras integradas en la app; FL-021 debe validar
  proveedor, API y políticas Apple/Google antes de implementarlo.
- Si existe PRO activo, la app muestra sus detalles disponibles y solicita una
  confirmación explícita que cubra eliminación y cancelación de renovaciones.
- El backend solicita al proveedor cancelar renovaciones y comprueba el
  resultado antes de afirmar éxito. Si falla, registra y reintenta/escalona el
  incidente sin perder la capacidad de resolverlo después del borrado.
- La persona recibe un correo con resultado, datos pertinentes y soporte. El
  proceso de cuenta continúa conforme al contrato, sin confundirlo con
  reembolso ni pérdida automática de un periodo ya pagado.
- Pagos efectuados, reembolsos, periodos vigentes y evidencia contable quedan
  pendientes de FL-021/Legal/Payments; este contrato no implementa pagos.

## 8. Experiencia Flutter propuesta ES/EN

La entrada recomendada es el Drawer/perfil → sección **Cuenta / Account**, con
“Eliminar cuenta” separado visual y semánticamente de “Cerrar sesión”. Debe ser
accesible, no depender del color y conservar objetivos táctiles ≥44 dp.

| Momento | Español propuesto | Inglés propuesto |
|---|---|---|
| Acción | Eliminar cuenta | Delete account |
| Introducción | Elimina tu cuenta de Foloo y los datos asociados. Esta acción no es lo mismo que cerrar sesión. | Delete your Foloo account and associated data. This is different from signing out. |
| Consecuencia | Tus Leads, eventos, archivos, notas de voz, plantillas y conexión de correo dejarán de estar disponibles. | Your leads, events, files, voice notes, templates, and email connection will no longer be available. |
| Datos externos | Los correos ya enviados y las copias exportadas pueden permanecer con sus destinatarios o en otras aplicaciones. | Emails already sent and exported copies may remain with their recipients or in other apps. |
| Offline | Conéctate a Internet para enviar la solicitud de eliminación. No hemos eliminado tu cuenta todavía. | Connect to the Internet to submit your deletion request. Your account has not been deleted yet. |
| Outbox | Tienes {count} cambios pendientes. Si continúas, se eliminarán de este dispositivo y podrían no sincronizarse. | You have {count} pending changes. If you continue, they will be removed from this device and may never sync. |
| Reautenticación | Por seguridad, vuelve a autenticarte para continuar. | For security, authenticate again to continue. |
| Confirmación | Entiendo que esta acción elimina mi cuenta y no podré recuperar los datos borrados. | I understand that this action deletes my account and I cannot recover deleted data. |
| PRO activo | Tienes una suscripción activa. Revisaremos la cancelación de futuras renovaciones y te confirmaremos el resultado; eliminar la cuenta no implica automáticamente un reembolso. | You have an active subscription. We will process cancellation of future renewals and confirm the result; deleting your account does not automatically mean a refund. |
| CTA final | Solicitar eliminación | Request deletion |
| Aceptada | Recibimos tu solicitud. Foloo bloqueó nuevas operaciones y está eliminando tus datos. | We received your request. Foloo has blocked new activity and is deleting your data. |
| En proceso | Eliminación en proceso | Deletion in progress |
| Bloqueada | No pudimos completar una etapa. Tu cuenta permanece bloqueada y la solicitud conserva su lugar. | We could not complete one step. Your account remains locked and your request is still active. |
| Final | La eliminación finalizó. Conserva este comprobante: {receipt}. | Deletion is complete. Keep this receipt: {receipt}. |
| Error previo | No pudimos enviar la solicitud. Tu cuenta no fue bloqueada. Intenta de nuevo. | We could not submit the request. Your account was not locked. Try again. |

Producto definió un máximo operativo de 15 días desde aceptación backend hasta
`completed|blocked`; no obliga a esperar, no retrasa una eliminación que pueda
completarse antes y no define la expiración de backups. El copy publicable y la
promesa por región esperan validación Legal/Operación. “Eliminar ahora” no debe
usarse si el proceso es asíncrono. El receipt debe ser opaco, copiable y no
contener `sub`, email, nombre o workspace ID.

## 9. Recurso web requerido por Google Play

El recurso debe estar en una URL HTTPS corporativa aprobada, mencionar Foloo y
CBQA Solutions y ofrecer una ruta destacada para solicitar eliminación sin
reinstalar la app. No basta una política genérica ni un mailto oculto.

Contrato recomendado:

1. página pública ES/EN con alcance, retención aprobada y soporte;
2. autenticación Cognito para cuentas existentes mediante un App Client web
   público/PKCE y callback separado, sin Client Secret en navegador;
3. reautenticación según el mismo criterio móvil;
4. llamada al mismo `POST /v1/account-deletion-requests`;
5. estado mediante sesión vigente o receipt opaco;
6. fallback asistido para cuentas que no puedan autenticarse, con verificación
   humana documentada; nunca borrar por conocer únicamente un email.

`foloo.io` será el punto principal previsto para suscripciones, pagos,
solicitudes de eliminación y futuras capacidades web. La ruta candidata es
`https://foloo.io/delete-account`, pendiente de validación técnica y
publicación; no se declara disponible todavía. Dominio, hosting, propietario
operativo, contenido legal y fallback requieren validación TI/Legal. El
frontend web no recibe permisos AWS ni implementa un pipeline paralelo.

Apple permite que un proceso tarde si se informa y confirma su finalización,
pero la app debe permitir iniciarlo y no puede ofrecer solo desactivación. Google
requiere ruta in-app y recurso web funcional, visible y capaz de recibir la
solicitud de cuenta y datos asociados.

### 9.1 Dashboard web futuro (fuera de STORE-02D/02E)

Producto registró como dirección futura un dashboard en `foloo.io` con captura
manual de Leads desde navegador. Será deliberadamente más limitado que la app
móvil: sin OCR, notas de voz ni captura de imágenes de referencia, y deberá
orientar a descargar la app para la experiencia completa. Esta idea no tiene FL
asignado, no pertenece a STORE-02E, no altera Foloo V1 y no autoriza pantallas,
endpoints ni infraestructura.

## 10. Cambios previstos para STORE-02E

### PostgreSQL / migración aditiva

Diseñar, tras las aprobaciones:

- `account_deletion_requests`: UUID, referencias account/user solo mientras
  existan (sin FK restrictiva sobre la fase final), subject hash, status/stage,
  idempotency key/hash, timestamps, códigos sanitizados, receipt hash y resumen
  versionado de política aplicada. Tras completar no conserva identificadores
  crudos salvo excepción aprobada;
- `account_deletion_barriers`: subject hash único, request, estado y timestamps;
- estado `deletion_pending` consultable sin depender de una account ya borrada;
- índices para request activo, idempotencia y worker polling;
- procedimiento atómico de resolución/provisión con barrera;
- función/queries de borrado con orden de FK y tests de rollback;
- ningún body, token, email, object key o nota dentro del ledger final.

La migración no debe transformar tombstones históricos ni activar borrados al
desplegarse. Debe ser repetible según el runner existente y compatible con
cuentas actuales.

### API y contrato

- `POST /v1/account-deletion-requests`
- `GET /v1/account-deletion-requests/current`
- endpoint `POST` de status por receipt opaco en body, con rate limit y
  expiración; nunca query/path parameter
- error estable `account_deletion_pending` para el resto de rutas
- idempotencia y `auth_time`/prueba reciente verificadas server-side
- OpenAPI sin exponer internal stage, object keys o PII

Los códigos HTTP definitivos se validan con el contrato de errores existente;
423 es la propuesta para cuenta bloqueada, no una decisión de producto.

### Infraestructura e IAM mínimo

| Principal | Permisos nuevos mínimos |
|---|---|
| ApiFunction | `states:StartExecution` solo sobre state machine deletion; acceso DB actual. Sin delete S3/Cognito |
| State machine role | `lambda:InvokeFunction` solo sobre workers de deletion |
| S3 cleanup worker | `s3:DeleteObject` sobre el bucket Foloo; `s3:ListBucket` solo si se aprueba auditoría por prefijo y con condición de prefix |
| Provider worker | Reutilizar secret/KMS actuales; contrato de revocación sin acceso a RDS |
| Identity finalizer | `cognito-idp:AdminUserGlobalSignOut` y `cognito-idp:AdminDeleteUser` solo sobre el User Pool Foloo; permiso de lookup por `sub` solo si el username no puede congelarse de claims confiables |
| DB worker | Secrets RDS y conexión VPC actuales; sin Cognito ni secretos OAuth |

Agregar endpoint privado de Step Functions si ApiFunction en subred aislada lo
requiere; no añadir NAT solo para este flujo. Logs usan requestId/deletionId,
stage y error class, nunca tokens, email, payload, paths u object keys.

### Flutter

- nueva sección Cuenta y pantallas ES/EN;
- repositorio/servicio separado de logout;
- reautenticación por AuthRepository/Cognito, no OAuth sender;
- estado local de cleanup, parada del sync y manifest de paths;
- purga owner-scoped y cierre de sesión;
- manejo compatible del error de barrera en cualquier pantalla/dispositivo;
- sin secretos, permisos móviles ni dependencia nueva salvo justificación.

## 11. Criterios de aceptación candidatos

Estos IDs fueron candidatos de STORE-02D y no forman un namespace canónico.
STORE-02E-01 los promueve o descompone en `AUT-18`–`AUT-21`, `SYN-11`–`SYN-12`,
`MON-13`, `INF-15`–`INF-21`, `RNF-09`–`RNF-10` y `RC-06`–`RC-10`, con criterios
en E-14 y trazabilidad detallada en
[`account-deletion-requirements-traceability.md`](account-deletion-requirements-traceability.md).
Los parámetros sujetos a aprobación permanecen bloqueados.

| ID | Criterio verificable |
|---|---|
| `AD-01` | Cuenta muestra una ruta localizable ES/EN distinta de logout; web permite iniciar sin reinstalar |
| `AD-02` | Sesión fuera de la ventana que apruebe Seguridad —cinco minutos como propuesta— o identidad no reautenticada no puede crear la solicitud; no se usa email como owner |
| `AD-03` | Una aceptación confirma request+barrera atómicamente y repetirla no duplica job |
| `AD-04` | Después de la barrera, ningún endpoint, callback, outbox, pull o token antiguo crea/modifica datos |
| `AD-05` | Cuenta con datos en todos los dominios termina sin filas activas ni objetos S3 del workspace, salvo retención aprobada |
| `AD-06` | Revocación sender y eliminación de ciphertext/state/PKCE son reintentables y verificables por proveedor |
| `AD-07` | Cognito se elimina solo después del cleanup; sesiones de todos los dispositivos dejan de operar |
| `AD-08` | Un segundo dispositivo observa la barrera, detiene sync, limpia solo su owner y no resucita datos |
| `AD-09` | Sin red no se anuncia recepción; outbox pendiente se explica y sigue la decisión aprobada |
| `AD-10` | Fallo S3/provider/DB/Cognito reanuda desde su stage sin repetir efectos ni presentar éxito; una solicitud no supera el máximo operativo aprobado sin quedar `blocked` y escalada |
| `AD-11` | Purga local elimina filas/archivos del owner y conserva intacta otra cuenta del mismo dispositivo |
| `AD-12` | Restore de backup reaplica ledger y no reabre una cuenta eliminada |
| `AD-13` | Logs/receipt omiten PII, tokens, payloads, paths y object keys; acceso administrativo queda auditado |
| `AD-14` | Retención aprobada está aislada, minimizada, no accesible por producto y descrita al usuario |
| `AD-15` | Copias externas y datos fuera de control se explican sin prometer eliminación imposible |
| `AD-16` | Trial/Unlimited y datos de otras cuentas mantienen su comportamiento; deletion no concede ni consume entitlement |
| `AD-17` | Durante 30 días no puede reprovisionarse el mismo correo verificado, incluso con IdP externo; después crea una cuenta nueva sin datos ni beneficios anteriores |
| `AD-18` | Con PRO activo no se afirma cancelación hasta confirmarla; fallos quedan reintentables/escalados y no bloquean la resolución posterior del incidente |

## 12. Matriz mínima de pruebas STORE-02E

- Unitarias: state machine, idempotencia, HMAC/barrier, orden FK, redacción,
  clasificación retryable/blocked y copy ES/EN.
- PostgreSQL: migración sobre esquema 008 con datos; rollback por etapa; dos
  solicitudes concurrentes; `ensure_personal_workspace` bloqueado; restore con
  ledger; ausencia de cascadas ajenas.
- Backend integración: email/password y Google; token viejo; dos dispositivos;
  OAuth callback tardío; outbox; cada fallo S3/provider/DB/Cognito.
- S3: cero/uno/más de 1 000 objetos, key ausente, error parcial y objeto de otro
  workspace nunca eliminado.
- OAuth: Google/Microsoft conectado/desconectado/reconnect_required, revocación
  fallida y ciphertext inutilizable/borrado.
- Flutter iOS/Android: claro/oscuro, ES/EN, offline, pending/blocked/completed,
  restart, otra cuenta en el mismo dispositivo, accesibilidad y deep link web.
- Seguridad: IDOR/owner spoofing, receipt guessing/rate limiting, replay,
  privilege escalation, PII en logs y permisos IAM efectivos.
- Tiendas: ruta in-app visible, URL web pública funcional y declaraciones
  App Privacy/Data Safety coherentes con evidencia final.

No se prueban borrados reales en PROD. DEV usa cuentas/datos sintéticos y una
aprobación explícita por ejecución destructiva.

## 13. Subtareas implementables para STORE-02E

1. **STORE-02E-01 — Aprobaciones y trazas:** resolver las decisiones de la
   sección 14 y crear IDs/requisito/escenario canónicos.
2. **STORE-02E-02 — DDL y barrera:** migración, ledger, resolución atómica y
   compatibilidad con schema 008.
3. **STORE-02E-03 — API/request:** POST/GET, reautenticación, idempotencia,
   receipt y error estable.
4. **STORE-02E-04 — Orquestación/workers:** DB, S3, provider y Cognito con IAM
   mínimo y runbooks.
5. **STORE-02E-05 — Flutter:** UX ES/EN, estados, error global, sync stop y
   purga owner-scoped.
6. **STORE-02E-06 — Recurso web:** dominio aprobado, Cognito/PKCE, mismo API,
   status y fallback asistido.
7. **STORE-02E-07 — QA/security:** pruebas automatizadas, cuenta sintética DEV,
   multi-dispositivo, restore y evidencia de tienda.
8. **STORE-02E-08 — Compliance final:** política, formularios y cierre D-13 solo
   después de aprobación/evidencia.

Las subtareas 02–06 no deben empezar como implementación funcional antes de
cerrar 01. Sí pueden prepararse, sin crear DDL, endpoints, pantallas o recursos:
threat model; casos de prueba; diagramas; diseño de identificador seudonimizado
para la barrera de 30 días; contrato OpenAPI en borrador; prototipos y copy no
publicable; evaluación de revocación/cancelación por proveedor; y arquitectura
de la ruta web. `02E-07` puede preparar toda la matriz no destructiva.

## 14. Acuerdos comunicados y validaciones requeridas

Estados usados:

- **Acuerdo Producto/CBQA comunicado:** dirección funcional registrada a partir
  de la revisión; no sustituye las validaciones especializadas ni autoriza
  implementación.
- **Propuesta pendiente:** valor todavía sujeto a validación del área indicada.
- **Validación pendiente:** el área indicada debe confirmar viabilidad/política.
- **Formalmente aprobada:** exige evidencia, responsable y fecha, además de las
  validaciones aplicables. No se registra una autorización integral de
  STORE-02E al corte de este documento.

| ID | Acuerdo o propuesta registrada | Estado | Validaciones todavía requeridas |
|---|---|---|---|
| `DEC-AD-01` | Borrar datos personales/operativos; retener solo información administrativa, contable o legal realmente exigida, nunca indefinidamente por defecto | Acuerdo Producto/CBQA comunicado; autorización de implementación pendiente | Legal/Contabilidad definen categorías, base, región y plazos |
| `DEC-AD-02` | Backups ordinarios: **15 días propuestos** y ledger obligatorio para impedir resurrección | Propuesta pendiente, no política aprobada | Infra/Seguridad validan periodo, accesos y runbook; Legal separa legal hold |
| `DEC-AD-03` | Registro mínimo seudonimizado solo con propósito, justificación y plazo definidos | Acuerdo Producto/CBQA comunicado; diseño pendiente | Legal/Seguridad definen campos, HMAC, plazo y acceso |
| `DEC-AD-04` | Máximo operativo de **15 días** desde aceptación hasta `completed|blocked`; iniciar y completar cuanto antes | Regla de Producto comunicada; promesa operativa/legal aún no validada | Operación/Legal validan viabilidad por región, escalamiento y confirmación |
| `DEC-AD-05` | Irreversible tras aceptación. El mismo correo puede registrarse después de **30 días** como cuenta nueva, sin datos/beneficios anteriores | Regla de Producto/CBQA comunicada; mecanismo pendiente | Seguridad/Legal validan enforcement mínimo, IdP externos, PII y excepciones |
| `DEC-AD-06` | Ofrecer sync; permitir continuar con advertencia irreversible y confirmación explícita | Acuerdo Producto/CBQA comunicado; copy/implementación pendientes | Producto/Legal validan copy/consentimiento; QA cubre outbox |
| `DEC-AD-07` | Reintentos automáticos, registro de fallos y escalamiento | Acuerdo comunicado; **owner operativo no designado** | Operación/Seguridad fijan responsable, límites, alertas, runbook y `blocked` |
| `DEC-AD-08` | Purga local selectiva por owner; cifrado local se evalúa por separado | Acuerdo Producto/CBQA comunicado | Seguridad/Legal revisan protección; QA valida dispositivo multi-owner |
| `DEC-AD-09` | Reautenticación máxima propuesta de **5 minutos**, obligatoriamente verificada por backend | Propuesta pendiente | Seguridad valida señal Cognito, reloj, federación y fallback |
| `DEC-AD-10` | Pagos/suscripciones previstos en `foloo.io`; advertir PRO, cancelar renovaciones, confirmar resultado, notificar por email y conservar resolución de fallos | Dirección Producto/CBQA comunicada; FL-021/implementación pendientes | Payments/Legal validan proveedor/API, pagos, reembolsos, periodos y políticas Apple/Google |
| `DEC-AD-11` | Exportación previa voluntaria; nunca requisito para eliminar | Acuerdo Producto/CBQA comunicado | Legal confirma portabilidad y Producto el copy |
| `DEC-AD-12` | `foloo.io` como punto principal; ruta candidata `foloo.io/delete-account`; app/web comparten pipeline | Dirección Producto/CBQA comunicada; ruta no publicada | TI valida hosting, TLS, owner, monitoreo y soporte; Legal contenido |
| `DEC-AD-13` | Mantener abierta la definición de roles y atención de derechos sobre datos de terceros en Leads | Responsable no designado; decisión Legal pendiente | Legal define controlador/encargado por mercado, proceso y owner operativo |
| `DEC-AD-14` | Foloo es multirregión; no asumir lanzamiento exclusivo en México | Dirección comunicada; alcance de lanzamiento pendiente | Dirección/Producto/Legal confirman países, idiomas, edad mínima y controles |

La agenda y espacio de minuta están en
[`account-deletion-cbqa-approval-agenda.md`](account-deletion-cbqa-approval-agenda.md).
`D-13` permanece abierta hasta que las validaciones aplicables tengan respuesta,
responsable, fecha y evidencia y exista autorización formal para implementar.
Un acuerdo de Producto no aprueba por sí solo retenciones, controles de
seguridad, operación, pagos o cumplimiento regional.

## 15. Gates reales para STORE-02E

Preparar diagramas, threat model, casos de prueba y spikes que no creen recursos
ni DDL puede continuar. La implementación funcional se desbloquea así:

| Subtarea STORE-02E | Bloqueos mínimos antes de implementar | Puede comenzar después de |
|---|---|---|
| `02E-01` Aprobaciones/trazas | Requisitos/E-14/trazas formalizados; validaciones, owners y autorización explícita siguen pendientes | **Completada documentalmente**; no habilita código ni resuelve aprobaciones externas |
| `02E-02` DDL/barrera | DEC-AD-01/02/03/05/09, enforcement de 30 días y restore | Solo diseño/spike ahora; implementación tras Legal + Seguridad + Infra |
| `02E-03` API/request | DEC-AD-04/05/06/09/11; errores/receipt y reautenticación | Borrador OpenAPI/tests ahora; implementación tras Seguridad + Producto/Legal |
| `02E-04` Orquestación/workers | DEC-AD-01/02/03/07/10/13/14; IAM, owner y runbooks | Diagramas/provider research ahora; implementación tras Legal + Seguridad + Infra/Operación; Payments para PRO |
| `02E-05` Flutter | DEC-AD-04/05/06/08/09/10/11; copy ES/EN | Prototipo/copy ahora; código tras Seguridad/Legal y autorización funcional |
| `02E-06` Recurso web | DEC-AD-04/05/09/12/14 | Arquitectura ahora; implementación/publicación tras TI + Legal/Seguridad |
| `02E-07` QA/security | Datos sintéticos y plan pueden prepararse ahora; pruebas destructivas esperan 02E-02–06 | Cada componente implementado en DEV y autorización de ejecución |
| `02E-08` Compliance final | Todas las decisiones y evidencia E2E; D-21 cuando corresponda iOS | Cierre técnico/legal y revisión de formularios |

No hay un camino seguro para iniciar DDL, endpoints, pantallas o AWS solo con
los acuerdos comunicados. FL-020, FL-021 y FL-022 conservan sus IDs y alcances
canónicos.

## 16. Riesgos principales

| Riesgo | Severidad | Mitigación contractual |
|---|:---:|---|
| Reprovisión automática tras borrar | Crítica | Barrier HMAC atómica antes de `ensure_personal_workspace` |
| Eliminar Cognito demasiado pronto | Crítica | Cognito último; receipt externo seguro |
| Borrado parcial S3/DB/provider | Alta | Orquestador, inventory congelado, stages idempotentes y `blocked` |
| JWT revocado aún aceptado por validación local | Alta | Barrera consultada en cada principal/request |
| Restore de backup resucita datos | Crítica | Ledger externo y runbook de restore obligatorio |
| Borrar datos de otro owner/dispositivo | Crítica | IDs backend, queries owner-scoped y tests multi-account |
| Perder outbox sin consentimiento | Alta | Conteo, copy y decisión explícita antes de solicitud |
| Retener PII en receipt/logs | Alta | Receipt opaco, hashes, redacción y tests |
| Prometer borrado de correos/exportaciones externos | Media | Disclosure ES/EN y política de alcance |
| Interacción futura con pagos | Alta | DEC-AD-10 y D-01–D-04 antes de FL-021 |

## 17. Fuentes oficiales

- Apple, eliminación dentro de la app y cuenta completa:
  <https://developer.apple.com/support/offering-account-deletion-in-your-app/>
- Google Play, ruta in-app, recurso web y retención legítima comunicada:
  <https://support.google.com/googleplay/android-developer/answer/13327111>
- Cognito `DeleteUser` (autorización por access token):
  <https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_DeleteUser.html>
- Cognito `AdminDeleteUser` (IAM server-side):
  <https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_AdminDeleteUser.html>
- Cognito revocación/global sign-out y límites de JWT autocontenido:
  <https://docs.aws.amazon.com/cognito/latest/developerguide/token-revocation.html>
- S3 `DeleteObjects`, resultados individuales y lotes de hasta 1 000 keys:
  <https://docs.aws.amazon.com/AmazonS3/latest/API/API_DeleteObjects.html>

## 18. Criterio de salida STORE-02D

STORE-02D queda **actualizada con acuerdos comunicados, no autorizada para
implementación**, cuando:

- la matriz coincide con schema/runtime actuales;
- arquitectura, lifecycle, UX, web, IAM, migraciones y pruebas están definidos;
- cada decisión pendiente identifica el área responsable, aunque el owner
  operativo concreto todavía no haya sido designado, sin confundir acuerdo con
  aprobación formal;
- roadmap/traceability enlazan este contrato;
- no se han creado endpoints, DDL, recursos AWS ni borrados;
- `D-13` continúa abierta hasta aprobación expresa.
