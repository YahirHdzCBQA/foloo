# STORE-02E-02B — Ledger y guard aislados

- Fecha: 2026-10-20
- Estado: **base implementada y validada en AWS DEV; documento conserva el corte histórico del incremento 02B**
- Trazas: `AUT-21`, `INF-18`, `INF-20`, `INF-21`, `RNF-09`, `RNF-10`,
  E-14, `AD-T-17`, `AD-T-18`, `AD-T-24`–`AD-T-26`, `AD-T-30`–`AD-T-32`
- Decisiones: `ADR-AD-01`–`ADR-AD-05` continúan candidatas; D-13 abierta

Este incremento materializó contratos y adaptadores aislados para probar la
separación entre el bloqueo temporal por correo y el tombstone durable por
`sub`. La integración y validación posteriores se consolidan en
[`store-02-account-deletion-closure.md`](store-02-account-deletion-closure.md).

## Componentes implementados

### Identidad seudonimizada

`pseudonymous_identity.ts` conserva sin cambios la política provisional de
correo `foloo-email-v1-provisional` y agrega
`PseudonymousSubjectIdentifierService` con domain separation
`foloo-cognito-sub-v1`. El `sub` no se normaliza ni se convierte de case: el
caller debe entregar exactamente el claim canónico verificado que Foloo usa
como owner. Correo y subject producen namespaces y digests distintos.

La evidencia de `email_verified` y la autenticidad de `sub` siguen siendo
precondiciones de una frontera server-side futura. El guard aislado no puede
demostrarlas por sí solo.

### Contrato de ledger

`account_deletion_ledger.ts` define:

- `registration blocker`: HMAC de email + `blockedUntil`, autoritativo por
  comparación lógica durante 30 días;
- `subject tombstone`: HMAC de `sub`, estado `pending|deleted`, sin TTL;
- request durable: referencia de idempotencia entre ambos registros;
- aceptación atómica e idempotente y transición atómica a `deleted`.

El día 30 exacto permite registro (`now >= blockedUntil`). El TTL es solo
limpieza del blocker y no participa en la decisión. El tombstone no expira con
el blocker.

### Adaptador DynamoDB

`dynamodb_account_deletion_ledger.ts` implementa el contrato mediante lecturas
consistentes y `TransactWriteItems`:

1. una transacción crea request, tombstone y blocker;
2. conditions impiden reutilizar `deletionId`, subject o email todavía
   bloqueado por otra solicitud;
3. una carrera de la misma solicitud se resuelve como idempotente después de
   releer el request;
4. una transición modifica request y tombstone juntos;
5. no se persisten correos ni subjects en claro.

Errores de almacenamiento no se convierten en permiso. La capa guard devuelve
un error genérico fail-closed, sin copiar PII ni el error interno.

### AccountDeletionGuard

`account_deletion_guard.ts` expone decisiones `active`, `deletion_pending`,
`deleted` y `registration_blocked`. Lee todas las versiones HMAC configuradas y
escribe solo con la versión activa, preparando rotación sin reinterpretar
digests existentes. También crea la barrera de 30 días y marca el tombstone
como eliminado, siempre a través del contrato de ledger.

El router reconoce el namespace STORE-02 mediante un controller fail-closed.
El stack prepara variables e IAM para ledger/HMAC/queue, pero la composición
activa no se construye mientras el flag siga en `false`. No hay guard activo
en `PrincipalResolver`, Cognito ni sincronización, y trial/PRO/Unlimited QA no
cambian.

## Infraestructura preparada pero inactiva

`account_deletion_ledger_infrastructure.ts` se instancia ahora en el template
DEV, pero no ha sido desplegado. Define:

- tabla on-demand con PK seudonimizada;
- cifrado administrado por AWS, PITR, TTL auxiliar, deletion protection y
  `RETAIN`;
- llave KMS HMAC-256 dedicada y permisos `GenerateMac`/`VerifyMac`;
- cola FIFO, DLQ cifrada, cinco reintentos y alarma de mensajes fallidos;
- alarmas de system errors y throttling;
- grants item-scoped sin `Scan` ni borrado de ledger.

El stack incorpora endpoints privados DynamoDB, KMS y SQS, worker en VPC y un
finalizador Cognito fuera de VPC con IAM limitado al User Pool. Todos conservan
`FOLOO_ACCOUNT_DELETION_ENABLED=false`; el worker devuelve fallos parciales y
el finalizador rechaza llamadas si una entrega accidental ocurre. Falta aprobar
destinos de alarma, tags, budgets y la composición destructiva final.

Las dependencias AWS DynamoDB/KMS/SQS/Lambda/SES están justificadas por `INF-18`,
`INF-20` e `INF-21`: ningún cliente existente implementa transacciones y
lecturas consistentes DynamoDB. Agregarla no incorpora el adaptador al bundle
de ninguna Lambda mientras no exista un import desde un entry point.

## Cobertura sintética

- día 29 bloqueado; día 30 exacto y día 31 permitidos;
- estados pending/deleted y restauración simulada de datos operativos viejos;
- solicitudes repetidas y concurrentes;
- conflicto de email activo;
- fallos DynamoDB/HMAC fail-closed sin PII;
- lectura multiversión durante rotación HMAC;
- escritura/lectura/transición DynamoDB e idempotencia tras carrera;
- cifrado/PITR/TTL/deletion protection/alarmas/IAM mínimo en synth;
- composición inactiva en el stack e independencia de trial/Unlimited;
- cifrado KMS del destinatario SES y purga tras confirmación final;
- migración 009 con barrera anterior a provisioning y restore sintético.

Todas las identidades y llaves de prueba son sintéticas.

## Riesgos y aprobaciones pendientes

- Seguridad: canonicalización provisional del local-part, evidencia exacta de
  `email_verified`, confianza del claim `sub`, custodia/rotación KMS HMAC,
  límites de versiones y threat model fail-closed.
- Infra/Operación: propiedad IaC, endpoint DynamoDB, alarm routing, PITR,
  restore/reconciliación, SLO y coste con volumen real.
- Legal: retención final del tombstone y del ledger; D-13 continúa abierta.
- Arquitectura: decidir si el guard vive en Lambda separada o en una frontera
  compartida y aprobar AD-01–AD-05 modificadas.
- Runtime: el wiring API/OAuth/sync/worker está preparado detrás de flag.
  PreSignUp protege únicamente `PreSignUp_ExternalProvider`, donde existe
  evidencia verificada; email/password conserva alta y confirmación Cognito y
  se evalúa junto con Google en PostAuthentication. El User Pool preexistente
  no pertenece al stack: CDK crea handlers, permisos y outputs, pero no modifica
  su `LambdaConfig`. Ambos handlers continúan en pass-through hasta activación.

## Próximo incremento recomendado

Antes de conectar cualquier flujo, aprobar las ADR modificadas y ejecutar una
revisión de Seguridad/Infra del modelo de tabla, KMS HMAC, fail-closed y
restore. Después, un incremento aislado puede implementar los adaptadores KMS
y el handler de guard con fixtures locales, todavía sin asociarlo a Cognito ni
al router. La conexión a runtime debe recibir autorización separada.

## Vertical funcional local preparado en STORE-02

Sobre los contratos aislados anteriores se preparó una vertical comprobable
con datos sintéticos, todavía **inactiva**:

- workflow reanudable con preflight, reautenticación reciente, aceptación
  irreversible, barrera durable, estados, reintentos y verificación final;
- controllers para las rutas del contrato OpenAPI y controller fail-closed que
  responde `503` mientras el feature permanece apagado;
- ejecutor por etapas `OAuth -> S3 -> PostgreSQL -> Cognito`, con checkpoints;
- adaptadores no conectados para inventariar/borrar exclusivamente el grafo
  personal del owner en PostgreSQL y las llaves exactas inventariadas en S3;
- correos ES/EN de recepción y finalización mediante un puerto simulado;
- interfaz Flutter ES/EN, preflight, advertencia de outbox, consentimiento
  irreversible y purga local selectiva por owner;
- interfaz de suscripción que bloquea una cuenta PRO cuando Stripe no está
  disponible, en vez de simular una cancelación exitosa.

El workflow usa DynamoDB durable, receipt indexes y checkpoints reanudables.
La migración 009 agrega la barrera operativa PostgreSQL, funciones de guard y
locking compartido con provisioning. Es transaccional, repetible ante una
ejecución cuyo registro de migración haya fallado y tiene pre/postchecks de solo
lectura. Para este incremento, el responsable confirma que 009 ya está aplicada
en AWS DEV; no se ejecutó ni modificó ninguna migración. La ruta pública
`foloo.io/delete-account` conserva
el contrato del mismo backend, pero no se implementó una segunda web ni se
modificó la landing.

## STORE-02 — Fase crítica de idempotencia y despacho durable (2026-10-21)

La confirmación quedó preparada localmente con estas garantías (`AUT-19`,
`INF-17`, `RNF-09`, `RNF-10`):

- el header `Idempotency-Key` de confirmación se valida y queda asociado al
  request; Flutter conserva la misma clave durante los reintentos;
- la transición `awaiting_confirmation -> requested`, el índice del único
  receipt y el item `OUTBOX#<requestId>` se escriben en una sola transacción
  condicional DynamoDB;
- el vault KMS reclama el receipt mediante `attribute_not_exists(pk)`: una
  carrera recupera el receipt ya cifrado en lugar de sustituirlo;
- una caída de SQS no revierte la solicitud aceptada ni pierde el trabajo: el
  outbox permanece `pending`; el envío exitoso marca `dispatched` y elimina el
  item de outbox en otra transacción idempotente;
- un recuperador consulta `dispatch_outbox` mediante el GSI
  `entity_type-created_at-index`, recupera el `sub` cifrado y vuelve a enviar.
  SQS FIFO usa el `requestId` como deduplication ID y el worker conserva sus
  checkpoints, cubriendo la ventana envío-exitoso/marcado-fallido.

La Lambda recuperadora y su regla EventBridge se sintetizan, pero ambas quedan
inactivas: `FOLOO_ACCOUNT_DELETION_OUTBOX_ENABLED=false` y regla `DISABLED`.
Todos los demás flags Account Deletion/registration guard/reconciler/SES siguen
en `false`; `FOLOO_UNLIMITED_QA_MODE=true` se conserva para DEV.

### Despliegue futuro de esta fase (no ejecutado)

1. ejecutar typecheck, pruebas backend/Flutter y `cdk synth` con
   `environment=dev`, `unlimitedQaMode=true` y los dos ARN KMS **existentes**;
2. ejecutar `cdk diff` con el perfil `foloo-dev` y comprobar únicamente: nueva
   Lambda/alarma/regla deshabilitada, GSI de outbox, IAM mínimo y nuevos assets;
3. confirmar expresamente que no existe migration nueva y que 009 continúa
   aplicada; no invocar `MigrationFunction.apply`;
4. desplegar `FolooBackend-dev` con los mismos contextos, manteniendo todos los
   flags destructivos apagados;
5. esperar a que el GSI esté `ACTIVE` y verificar: Unlimited `true`, Lambda de
   recovery `false`, regla EventBridge `DISABLED`, worker/API Account Deletion
   `false` y cero mensajes inesperados/DLQ;
6. no habilitar el schedule ni Account Deletion hasta aprobar Seguridad y
   completar pruebas E2E con una identidad QA ficticia.

Riesgos restantes: la barrera HMAC/PostgreSQL y la aceptación DynamoDB no pueden
formar una transacción distribuida; una caída entre ambas exige reconciliación
operativa. El aviso SES de recepción conserva su mecanismo asíncrono separado y
no forma parte de este outbox SQS. D-13 y ADR-AD continúan abiertas, por lo que
esta fase no autoriza activación.

## STORE-02 — Fase crítica de eliminación verificable (2026-10-21)

El worker queda preparado localmente para conservar evidencia independiente de
los datos que destruye (`INF-17`, `INF-19`, `RNF-09`, `RNF-10`):

- antes del borrado se listan con paginación los dos prefijos canónicos del
  workspace en S3 y se unen con las referencias PostgreSQL; el resultado se
  congela en el ledger DynamoDB existente como manifest inmutable, ordenado,
  deduplicado y dividido en shards de 100 keys con conteo y SHA-256;
- `DeleteObjects` procesa lotes máximos de 1,000, trata ausencia como éxito
  idempotente, falla ante cualquier error parcial y reintenta el manifest
  original. La verificación usa `HeadObject` sobre ese manifest durable y nunca
  vuelve a consultar tablas ya borradas;
- antes de borrar PostgreSQL se congela el trío `user/account/workspace`. El
  borrado transaccional y la comprobación posterior usan esos IDs exactos y
  revisan todas las tablas owner-scoped vigentes, no solo `app_users`;
- las pruebas sintéticas cubren dos propietarios, rollback/reintento SQL,
  errores parciales S3 y un inventario de 1,005 objetos paginado y shardeado.

No se agrega tabla ni migración. Se reutiliza el ledger Account Deletion; el
único cambio CDK es `s3:ListBucket` restringido a
`media/workspaces/*` y `content/workspaces/*`. El bucket actual declara
`versioned: false`. Los manifests expiran a los 31 días como medida operativa
provisional, no como aprobación de retención. Account Deletion, guards,
reconciler, SES y outbox recovery permanecen desactivados; Unlimited QA se
mantiene activo en DEV.

Riesgos pendientes antes de activar: aprobar la retención/cifrado y exposición
operativa de keys S3 en el ledger; asegurar que la barrera impida nuevas
escrituras después de congelar el inventario; decidir el tratamiento futuro si
se habilita versionado S3; y resolver en D-13 cualquier modelo multipropietario
o membresía organizacional fuera del workspace personal V1.

### Barreras de activación en AWS DEV

`FOLOO_ACCOUNT_DELETION_ENABLED` vale `false` por defecto y CDK lo fija en
`false`. La Lambda rechaza el arranque si alguien intenta cambiarlo a `true`
antes de sustituir la composición deshabilitada. El drawer Flutter también
permanece oculto con `FOLOO_ACCOUNT_DELETION_ENABLED=false`.

Antes de una prueba destructiva con una identidad QA sintética se requieren,
como mínimo:

1. aprobación de Seguridad para canonicalización, ventana de reautenticación,
   custodia/rotación KMS HMAC y política de recibos;
2. aprobación e instanciación CDK del ledger DynamoDB, endpoint VPC, alarmas e
   IAM mínimo;
3. desplegar stores durables y worker/DLQ aún inactivos; confirmar con evidencia
   de solo lectura que la migración 009 aplicada conserva sus pre/postchecks;
4. aprobar KMS/canonicalización y revisar consultas owner-scoped PostgreSQL/S3;
5. verificar `foloo.io` en SES, salida de sandbox y `hello@foloo.io`;
6. adjuntar PreSignUp y PostAuthentication al User Pool después de desplegar
   ambos en pass-through; habilitarlos requiere autorización separada;
7. adaptador Stripe real para cuentas PRO, o una política aprobada que bloquee
   explícitamente esas solicitudes;
8. revisión de `cdk synth`/`cdk diff`, despliegue inicial con ambos flags
   apagados, smoke tests no destructivos y autorización separada para habilitar
   exclusivamente AWS DEV.

D-13 y ADR-AD-01–ADR-AD-05 permanecen abiertas. Ningún componente nuevo está
autorizado para datos reales ni modifica Trial, PRO o Unlimited QA.

## Operación AWS DEV preparada

El owner operativo inicial es el desarrollador. Los outputs CDK exponen tabla,
queue/DLQ y nombres de Lambda sin revelar secretos. Antes de habilitar:

1. confirmar `UPDATE_COMPLETE` y que todos los flags Account Deletion/SES/
   registro/reconciliador sean `false`;
2. invocar MigrationFunction con `{"action":"status"}` para obtener evidencia
   read-only; los SQL de `migrations/checks/009...pre.sql`/`post.sql` quedan como
   equivalente auditable. Aplicar 009 solo con autorización y repetir status;
3. consultar SES sin envío con `npm run status:account-deletion-ses` usando
   perfil DEV; `VerifiedForSendingStatus`, DKIM y sending deben ser válidos;
4. revisar alarmas de errores Dynamo, throttling, antigüedad de queue, worker,
   reconciliador, email DLQ y deletion DLQ;
5. identificar requests por items `workflow_request`/estado en la tabla y
   contrastar sus checkpoints, mensaje SQS y logs estructurados por requestId;
6. una cuenta solo está completada cuando workflow/tombstone dicen `deleted`,
   S3/PostgreSQL/Cognito verifican ausencia, no quedan mensajes ni DLQ y el
   correo final fue procesado;
7. el reconciliador se invoca manualmente solo después de un restore autorizado
   y con su flag temporal; nunca tiene schedule;
8. ante incidente se vuelve a desplegar la configuración canónica con todos los
   flags `false`; no se borra queue/ledger ni se revierte 009. Los mensajes se
   conservan para diagnóstico y reanudación.

La asociación de triggers se realiza en Cognito → User Pool → Lambda triggers:
Pre sign-up usa el ARN `AccountDeletionPreSignUpFunctionArn` y Post
authentication usa `AccountDeletionPostAuthenticationFunctionArn`. Primero se
adjuntan con `FOLOO_ACCOUNT_DELETION_REGISTRATION_GUARD_ENABLED=false`; no se
habilitan hasta aprobar canonicalización/KMS y completar las pruebas sintéticas.

## Diagnóstico temporal owner-scoped previo a QA destructivo

El diagnóstico privado se desplegó una sola vez para validar la identidad
sintética de QA y después se retiró completamente de AWS mediante Change Set.
Confirmó un workspace personal de un miembro, trial sin Stripe, dos Leads, seis
medios, siete objetos S3 y cero anomalías owner-scoped. El código, pruebas y
wiring CDK temporales también fueron retirados durante el cierre del
repositorio; no existe endpoint administrativo permanente. La evidencia
agregada y el alcance de limpieza se conservan en
[`store-02-account-deletion-closure.md`](store-02-account-deletion-closure.md).
