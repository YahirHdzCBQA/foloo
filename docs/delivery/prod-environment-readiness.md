# Preparación local de AWS PROD para publicación

**Estado:** preparación local; PROD no está desplegado ni operativo.

**Trazas:** `AUT-01`, `AUT-10`, `AUT-17`–`AUT-24`, `MON-01`, `MON-21`,
`SYN-11`–`SYN-12`, `INF-04`, `INF-06`, `INF-15`–`INF-21`, `RNF-09`–`RNF-10`,
`RC-05`–`RC-10`, `REL-06`.

## Frontera Flutter

`FOLOO_ENVIRONMENT` selecciona únicamente identificadores públicos. Debug sin
selector conserva DEV. Todo Release requiere `dev` o `prod`; un Release DEV
requiere además `FOLOO_ALLOW_DEV_RELEASE=true`. Un candidato público PROD debe
recibir:

- `FOLOO_AWS_REGION` desde la región aprobada de la assembly;
- `FOLOO_COGNITO_USER_POOL_ID` desde `UserPoolId`;
- `FOLOO_COGNITO_APP_CLIENT_ID` desde `MobileAppClientId`;
- `FOLOO_COGNITO_HOSTED_UI_DOMAIN` desde `CognitoDomain`;
- `FOLOO_API_BASE_URL` desde `ApiUrl`;
- opcionalmente los redirects públicos `FOLOO_AUTH_SIGN_IN_REDIRECT` y
  `FOLOO_AUTH_SIGN_OUT_REDIRECT` si cambian de los deep links existentes.

La validación rechaza configuración incompleta, URL API sin HTTPS y cualquier
identificador conocido de DEV. Ninguno de estos valores es un secreto. Los
flags funcionales actuales continúan siendo `--dart-define` independientes y
no se infieren del entorno. Para tienda usar exclusivamente
`bash app/scripts/build-store-release.sh ios|android` con esos cinco outputs
verificados en el entorno. Confirmar el siguiente número libre en la consola
y pasarlo como `FOLOO_STORE_BUILD_NUMBER`; el valor de pubspec no determina
el candidato. El script habilita el borrado in-app para ambos
candidatos y exige `FOLOO_APPLE_SIGNIN=true` para iOS tras verificar D-21.
Usa los deep links nativos ya registrados. La firma se proporciona mediante
Xcode o las cuatro variables Android documentadas en Gradle.

## Frontera CDK

`-c environment=prod -c prodCognitoDomainPrefix=<prefijo-aprobado>` sintetiza
dos stacks con dependencia explícita:

- `FolooIdentity-prod` crea el User Pool protegido, cliente móvil público,
  dominio independiente, dos claves KMS retenidas de STORE-02D y tres
  contenedores Secrets Manager vacíos (`Google`, `Apple` y Gmail/Outlook).
- `FolooBackend-prod` consume esos outputs y crea el runtime aislado. Su VPC es
  `10.43.0.0/16`; DEV conserva `10.42.0.0/16`.

Los stacks PROD tienen termination protection y etiqueta `Environment=prod`.
La identidad SES `foloo.io` se importa por nombre: PROD puede autorizar
`ses:SendEmail`, pero no crea, reemplaza ni administra la identidad/DKIM ya
verificada en la cuenta. La preparación previa registra un template DEV idéntico antes y después
de su cambio CDK. La revisión PROD-01 se limita a cambios locales en la
ruta de build y documentación, sin editar CDK.

Google y Apple permanecen ausentes en el primer despliegue. Para incorporarlos
se requieren contextos explícitos (`prodGoogleClientId`,
`prodAppleServicesId`, `prodAppleTeamId`, `prodAppleKeyId`) y sus secretos
deben haberse cargado primero en los contenedores PROD. Microsoft Sign-In no
se crea; Microsoft solo continúa como proveedor de correo de seguimientos.

La configuración gestionada de PROD fija Billing/Stripe deshabilitado y no
incluye secretos de Stripe.
Unlimited QA sigue permitido únicamente en DEV. La administración PRO, el
worker automático y STORE-02D son provisionables en PROD por flags explícitos;
las excepciones QA y sus hashes siguen restringidas a DEV. Microsoft continúa
fuera de la versión publicada (`AUT-17`).

La política RDS local queda declarada de forma explícita:

| Entorno | BackupRetentionPeriod | DeletionProtection |
| --- | ---: | --- |
| DEV | 1 (estado operativo/Free Tier existente) | false |
| PROD | 15 (`RC-07`, pendiente de confirmar elegibilidad/costo) | true |

### Presupuesto operativo

Con tráfico inicial bajo, la topología cabe razonablemente en el objetivo de
USD 125/mes, pero no es una garantía contractual. El costo fijo dominante son
los cuatro interface VPC endpoints en dos AZ (ocho endpoint-AZ; la tarifa
publicada para us-east-1 es aproximadamente USD 0.01/h por endpoint-AZ), seguido
por RDS PostgreSQL `db.t4g.micro`, almacenamiento/backups, claves KMS y secretos.
Como orden de magnitud, se debe presupuestar USD 80–115/mes antes de tráfico,
logs, CPU credits y crecimiento de backups. S3/DynamoDB gateway endpoints no
agregan cargo horario. Referencias: [AWS PrivateLink](https://docs.aws.amazon.com/vpc/latest/privatelink/privatelink-access-aws-services.html),
[RDS PostgreSQL](https://aws.amazon.com/rds/postgresql/pricing/),
[Secrets Manager](https://aws.amazon.com/secrets-manager/pricing/) y
[KMS](https://aws.amazon.com/kms/pricing/).

Antes de crear recursos, el operador debe guardar una estimación en AWS Pricing
Calculator, confirmar el plan autorizado y crear alertas de presupuesto al
50/80/100 %. Los presupuestos y la concurrencia Lambda permanecen fuera de CDK
por decisión operativa. Revisar el costo real diariamente durante la primera
semana y semanalmente durante el primer mes.

La topología existente se reutiliza: VPC/subredes aisladas, HTTP API y JWT,
Lambdas, RDS PostgreSQL, S3 privado, KMS, Secrets Manager, SQS/DLQ,
EventBridge, SES, DynamoDB de eliminación, workers y observabilidad. No se
copian bases, buckets, colas, claves, tokens, usuarios ni secretos.

### Valores y decisiones pendientes antes del primer Change Set

1. Confirmar disponibilidad real del prefijo de dominio Cognito elegido.
2. Confirmar el plan AWS, presupuesto/alertas y la concurrencia Lambda.
   Solicitar aumento solo si las cuotas efectivas impiden operar los workers.
3. Crear primero `FolooIdentity-prod` sin IdPs; cargar por consola/flujo seguro
   los tres secretos vacíos. Nunca pasar secretos por contextos CDK.
4. Google/Apple en sus consolas con callbacks PROD y los identificadores
   públicos reales. Gmail/Outlook requieren callbacks al API PROD y valores
   separados en `foloo/prod/email-providers`.
5. Identidad/rol operador PROD con MFA y SourceIdentity, sin credenciales ni
   nombres reutilizados de DEV.
6. Decisión D-13, restauración ensayada, retención/costo RDS y legal/operación
   antes de habilitar eliminación pública.
7. Adjuntar declarativamente los triggers `PreSignUp` y `PostAuthentication`
   al User Pool una vez que sus Lambdas PROD existan, mediante el par obligatorio
   `prodPreSignUpFunctionArn`/`prodPostAuthenticationFunctionArn`. Los ARN se
   obtienen de outputs reales de `FolooBackend-prod`, nunca se inventan. Este es
   un Change Set de identidad separado y un gate antes de habilitar guards o
   preautorizaciones automáticas.
8. Dominio/API PROD resultante para el build Flutter y el sitio público.

No se debe sintetizar un template “final” con ARN o endpoints ficticios. Se
pueden usar fixtures únicamente en pruebas locales que no se publiquen.

## Migraciones 001–015

1. Crear el stack pasivo y verificar RDS `available` y MigrationFunction
   `Active/Successful`.
2. Crear snapshot manual cifrado y esperar `available`.
3. En una base nueva, verificar la lista ordenada en la assembly y ejecutar
   `apply` por primera vez antes de `status`. El `status` actual consulta
   `schema_migrations` y `app_users`, que todavía no existen antes de 001.
4. Aplicar únicamente por MigrationFunction, respetando el runner transaccional
   y advisory lock. Para despliegue inicial se recomienda lotes con punto de
   detención; nunca ejecutar SQL manual.
5. Tras cada lote que incluya 001 o posterior, ejecutar `status` y verificar
   los registros aplicados y la salud RDS. Después de 015, contrastar la lista
   completa, roles/privilegios, constraints y cero cuentas/workspaces iniciales.
6. Abrir tráfico solo con 001–015 verificadas, 18 write fences y cero
   barreras inconsistentes. `status` no devuelve `integrityConsistent`; ese
   campo pertenece a la prevalidación FL-021. El stack inicial ya contiene API
   y permite crear usuarios por correo. Mantenerlo sin tráfico de clientes
   hasta aplicar las migraciones y validar los guards.
7. Ante respuesta ambigua, consultar estado real antes de cualquier reintento.
   Restaurar snapshot requiere una autorización separada y un nuevo endpoint,
   no un rollback improvisado.

## Carga privada de las 17 preautorizaciones

La lista aprobada permanece en el inventario operativo privado; no se incluye
en Flutter, CDK, variables, documentación pública ni logs. En PROD:

1. Desplegar migraciones `012`–`014` y la infraestructura administrativa en
   modo pasivo.
2. Crear/registrar el operador PROD con MFA, SourceIdentity y sesión de una
   hora; verificar CloudTrail.
3. Con sesión temporal, consultar `preauthorization-status` para cada entrada.
4. Ejecutar `preauthorize` solo para ausentes, con motivo auditable. El servicio
   canonicaliza el correo y genera un HMAC con la clave PROD; no se copian los
   selectores HMAC de DEV.
5. Verificar 17 activas, cero errores y cero grants. No crear usuarios Cognito.
6. Habilitar PostAuthentication y Event Source Mapping en un Change Set
   separado. Al primer login, el worker revalida `sub` y correo verificado;
   Apple Private Relay distinto no coincide. Cada correo conserva una cuenta y
   workspace independientes.

## `foloo.io` y eliminación pública

`https://foloo.io/privacidad/` es contenido legal externo al stack. Debe
referenciar el responsable, categorías, retención, derechos, contacto y flujo
de eliminación aprobados para PROD; D-13/RC-05 siguen siendo gate.

`https://foloo.io/delete-account` usa la configuración pública del sitio para
API, User Pool, cliente web, dominio Cognito, callback/logout y entorno. El
cambio mínimo es sustituir esos valores DEV por outputs PROD en una publicación
web separada y atómica, sin cambiar rutas ni contrato STORE-02D. Antes de
publicar se verifican PKCE/cookies/orígenes, callback BFF, preflight,
reautenticación, receipt, logout, CSP/CORS y cache invalidation. La ruta no debe
apuntar a PROD mientras alguno de esos valores siga en DEV.

## Secuencia remota propuesta (cada paso requiere autorización)

1. Aprobar prefijo Cognito, cuota, presupuesto y decisiones D-13/RC.
2. Sintetizar/auditar `FolooIdentity-prod` sin proveedores; preparar su primer
   Change Set y validar Add/Modify/Remove/Replacement/costo antes de ejecutarlo.
3. Tras ejecutarlo con autorización separada, cargar secretos mediante el
   canal aprobado y preparar las integraciones externas. Mantener los IdPs
   apagados durante el arranque del backend.
4. Sintetizar una assembly reproducible y preparar el Change Set pasivo de
   `FolooBackend-prod`; no ejecutarlo hasta
   revisar Add/Modify/Remove/Replacement, IAM y costos.
5. Ejecutar backend pasivo, snapshot y migraciones 001–015 por gates separados.
   Mantener deshabilitados el intake, los consumidores y el acceso web normal.
6. Adjuntar/verificar triggers Cognito en un cambio aislado; desplegar la
   administración PRO pasiva y cargar 17 preautorizaciones con HMAC PROD.
   Habilitar Google y, después de resolver D-21/ADR-009, Apple, coordinando
   la allowlist efectiva de Registration Guards con el cambio de identidad.
7. Validar backend/E2E sintético PROD, recuperación y restauración.
8. Tras aprobar D-13, preparar y verificar el runtime de borrado, worker,
   finalizador, recovery y restore reconciler. Verificar ESM, guard de
   registro, alarmas y SES. Abrir admisión solo después, con
   `accountDeletionNormalAccessEnabled` y `accountDeletionQaIntakeEnabled`
   (este último controla el intake general pese al nombre). Mantener
   `accountDeletionQaEnabled` apagado y sin hashes. Coordinar el acceso web
   normal y publicar la configuración web PROD en su propio cambio.
9. Generar candidatos IPA/AAB solo con los cinco valores Flutter PROD
   verificados y sin `FOLOO_ALLOW_DEV_RELEASE`.

No existe autorización en esta preparación para ninguno de esos pasos.

## PROD-01 · Dictamen al 10 de noviembre de 2026

**NO-GO para ejecutar despliegue y para enviar a revisión.** Los dos stacks
están definidos localmente. El primer despliegue pasivo y la apertura de
producción tienen gates distintos. E-01, E-08–E-14 y REL-06/07 definen las
pruebas; la evidencia DEV y los APK privados acreditan implementación, no
operación ni aprobación de PROD.

| Prioridad | Gate | Evidencia o decisión pendiente |
| --- | --- | --- |
| P0 | Despliegue pasivo | CBQA debe confirmar cuenta destino, facturación, región, rol de despliegue y acceso operativo del administrador actual. Si se usa una cuenta nueva, obtener su contexto AZ y verificar bootstrap, SCP y cuotas. La afiliación a Organizations es un gate si CBQA la exige para operar o facturar. |
| P0 | Despliegue pasivo | Confirmar prefijo Cognito, parámetros efectivos, capacidad y revisión de Change Sets solo para los stacks PROD. Ningún ARN de otro entorno, incluidos triggers y claves históricas. |
| P0 | Apertura y ambas tiendas | D-13 requiere aprobación Legal/Seguridad/TI, retención por categoría, contactos de alertas, protección de respaldos/manuales, simulacro de restore y publicación de eliminación web PROD. Acreditar el ciclo de 30 días, incluida la política de elegibilidad para un trial nuevo. |
| P0 | iOS | D-21 y ADR-009 requieren Apple Developer, IdP/callback PROD y E2E. El worker revoca OAuth de remitentes y el finalizador elimina Cognito. Falta evidencia de revocación de tokens de Sign in with Apple. Validar la frontera y aprobar la solución con Seguridad/Producto antes de habilitar Apple público. |
| P0 | Ambas tiendas | El paywall vigente MON-14/E-11 promete agregar leads desde la web aunque el CTA esté oculto. Con el lanzamiento sin checkout público, Producto debe aprobar copy ES/EN coherente con lo disponible y definir el contenido del sitio y de las fichas. Mantener FREE/PRO como estados de captura con las mismas capacidades. |
| P1 | Apertura y ambas tiendas | Verificar las conexiones externas reales. Google OAuth de login y Gmail sender son independientes. El proveedor de seguimiento exige el secreto completo de Google y Microsoft, incluso al conectar uno solo. El sender Microsoft usa la configuración aprobada en ADR-006/007. SES cubre avisos de borrado, con identidad regional, salida de sandbox para destinatarios reales y entrega validada. |
| P1 | Ambas tiendas | Accesos de consola, firma, binarios PROD y evidencia física. Privacidad, URLs públicas, metadatos y acceso de revisión. Confirmar si Play exige prueba cerrada por el tipo y antigüedad de cuenta. |
| P2 | Después de lanzar | RDS Proxy, Multi-AZ y rediseño de red según carga, incidentes o SLO. La topología aprobada puede operar sin ellos. |

### Evidencia local de PROD-01

- Synth sin lookups con fixtures. Ambos stacks PROD y el stack DEV sintetizan.
  En PROD se verificó ausencia de identificadores DEV conocidos, RDS privado
  con respaldo de 15 días y protección, y ningún secreto de Stripe. La
  comparación contra CloudFormation y la salud DEV quedan para verificación
  remota de solo lectura con el contexto operativo.
- Typecheck backend aprobado. Suite con 420 pruebas aprobadas, dos omitidas y
  un smoke HTTP bloqueado por el sandbox. El smoke aislado pasó al habilitar
  loopback local. Flutter aprobó 347 pruebas con loopback local.
- El script pasó validación Bash y pruebas con Flutter simulado para IPA/AAB,
  rechazo de valores incompletos y DEV y exclusión de flags QA. Xcode/SDK iOS 27
  y target Android 36 observados localmente. Los binarios firmados, la
  alineación de 16 KB y la verificación en equipos físicos esperan el candidato
  configurado con outputs reales y firma autorizada.

### Aceptación antes de abrir AWS PROD

- [ ] Confirmar cuenta/región con sesión autorizada, acceso del administrador y
  recursos exclusivos PROD. Comparar issuer/audience, prefijo, claves, secretos,
  bucket, tablas, colas y base con el inventario DEV. Confirmar que ningún
  Change Set toca DEV.
- [ ] Comprobar RDS privado, TLS, backup automático de 15 días, protección
  contra eliminación, SG acotado, S3 privado, KMS/Secrets Manager por entorno,
  SQS/DLQ, alarmas y escalamiento asignado. El snapshot manual requiere política
  de expiración propia. Ensayar restore aislado y reconciliación del ledger
  antes de tráfico.
- [ ] Migraciones 001–015 aplicadas; triggers Cognito del mismo entorno con
  permisos restringidos al pool. Alta/confirmación email, Google, Apple donde
  aplique, JWT DEV rechazado y aislamiento entre dos usuarios PROD.
- [ ] Cinco leads históricos y borrador del sexto. Persistencia offline,
  reconciliación, concurrencia, CSV/XLSX por evento y seguimiento por los
  remitentes habilitados. Verificar grants PRO auditados, invalidación durante
  borrado y ausencia de Unlimited QA, Stripe configurado o checkout accesible.
- [ ] STORE-02D validado con fixtures locales y, solo tras autorización separada,
  identidades sintéticas PROD. Probar reauth de cinco minutos, idempotencia,
  barrera móvil/web, revocación, eliminación verificable, receipt, bloqueo de
  alta equivalente y ausencia de resurrección tras restore.
- [ ] Revisión operativa final antes de distribuir configuración PROD o
  habilitar el acceso web normal. Validar el sitio fuera de este repositorio.

### Aceptación de App Store y Google Play

- [ ] Ambos. Release de la ruta controlada, firma correcta, versión/build
  únicos, backend PROD disponible para revisión, credenciales sintéticas
  vigentes, notas de revisión y flujos físicos. Preparar assets ES/EN,
  permisos, soporte, clasificación y declaraciones de privacidad coherentes
  con SDKs, leads de terceros, medios, remitentes y retención.
- [ ] App Store. App Store Connect y Apple Developer bajo el equipo autorizado,
  Bundle ID y firma de distribución, IPA con Xcode/SDK vigentes, App Privacy,
  manifests de privacidad aplicables, alternativa 4.8 y borrado dentro de la
  app. Validar relay y revocación Apple.
  [Revisión de Apple](https://developer.apple.com/app-store/review/guidelines/)
  · [Borrado](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
  · [SDK mínimo](https://developer.apple.com/news/upcoming-requirements/?id=04282026a).
- [ ] Google Play. Play Console verificada, Play App Signing y clave de subida,
  AAB con target 36 o superior y soporte de páginas 16 KB en bibliotecas
  nativas. Data Safety y URL pública de borrado funcional, además del acceso
  in-app. Si la cuenta es personal y se creó después del 13 de noviembre de
  2023, prever prueba cerrada de 12 testers durante 14 días continuos antes
  de solicitar producción.
  [Target API](https://support.google.com/googleplay/android-developer/answer/11926878)
  · [Páginas de 16 KB](https://developer.android.com/guide/practices/page-sizes)
  · [Borrado y datos](https://support.google.com/googleplay/android-developer/answer/18265346)
  · [Prueba cerrada](https://support.google.com/googleplay/android-developer/answer/14151465).
- [ ] Google Cloud. Consentimiento público del sender y verificación OAuth
  según la categoría real de los scopes; asegurar que no depende de una lista
  de testers. [Verificación OAuth](https://support.google.com/cloud/answer/13463073).
