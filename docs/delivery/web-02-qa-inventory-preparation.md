# WEB-02 — Inventario privado PostgreSQL DEV

Estado vigente: desplegada y utilizada en AWS DEV mediante invocaciones autorizadas de `qa-inventory`, exclusivamente READ ONLY. `web-02-qa-inventory-dev` terminó en EXECUTE_COMPLETE; el inventario permitió comprobar pertenencia y conteos antes de la eliminación y cero registros owner-scoped después de `completed`.

La limpieza administrativa final retiró la cuarta autorización web temporal y dejó QA destructivo=false, allowlist destructiva vacía y acceso normal=false. Se conservan tres identidades web QA y runtime/procesamiento habilitados. La configuración privada QA_INVENTORY_* de MigrationFunction no fue retirada por esas limpiezas; permanece ligada a la identidad ya eliminada. No concede acceso web ni admisión destructiva. Las secciones de preparación siguientes son históricas, no instrucciones vigentes para desplegar ni repetir invocaciones.
Trazas: AUT-10, AUT-18–21, RNF-09, E-14; D-13 sigue bloqueando producción.
No cambia STORE-02, Billing ni el frontend. Sin nuevas dependencias.

## Contrato y límites

La Lambda operativa MigrationFunction acepta explícitamente `{"action":"qa-inventory"}`.
No admite otros campos, SQL ni identidad en el evento. Acciones desconocidas fallan
antes de leer secretos. `apply`/`status` conservan sus flujos; el inventario retorna
antes de entrar a ellos. No invocar la Lambda con `{}`: ese contrato histórico
aplica migraciones.

La configuración privada fija el sub sintético y su hash. CDK comprueba que
corresponda a la única entrada destructiva QA existente y también esté en QA web.
Runtime comprueba hash, ambiente DEV, región y ARN de MigrationFunction de la
cuenta DEV. No se resuelve identidad por correo en la acción. El contexto opcional
`qaInventorySubject` está ausente por defecto; sin configuración se rechaza.
Cambiar esa identidad requiere otra actualización operativa revisada.

La acción usa el secreto de aplicación existente (`foloo_app`), nunca el secreto
administrativo. Conserva TLS con validación. No se recuperó ningún secreto durante
esta preparación. En ejecución futura la propia Lambda necesitará leer el secreto,
como el backend actual; su valor nunca sale en la respuesta ni se registra.

Una conexión dedicada inicia REPEATABLE READ / READ ONLY; también se fija
`default_transaction_read_only=on` al conectar. Timeouts: conexión 5 s, sentencia
5 s, locks 1 s, sesión inactiva en transacción 5 s, cliente de consulta 8 s.
Una consulta estática parametrizada por sub devuelve agregados; éxito termina en
ROLLBACK y la conexión se destruye siempre. Fallos de conexión, esquema o consultas
producen únicamente `qa_inventory_unavailable`; no se reporta ausencia como éxito.

Salida: existencia/conteos de usuario interno, cuentas personales y workspaces
(incluidos soft-deleted, con conteos separados de vigentes), membresías del usuario,
membresías owner, estados de suscripción, presencia de referencias Stripe y fechas
Billing, y conteos en las 15 tablas de datos personales/operativos incluidas.
No devuelve IDs, correos, secretos, tokens ni filas de contenido. Los nombres de
tablas son constantes; no se aceptan nombres del invocador. Tablas faltantes o
estados inesperados fallan sin intentar migraciones.

Límite: es inventario PostgreSQL; no consulta Stripe ni prueba que no existan
objetos externos huérfanos. `billing_events` no tiene ownership por cuenta y no se
escanea. Los conteos no demuestran por sí solos que el contenido sea sintético.
No se incluye ningún endpoint público ni llamada a ensure_personal_workspace.

## Evidencia local

- 17/17 pruebas focalizadas: identidad/entorno/ARN, configuración CDK, proyección
  segura, ausencia de datos, READ ONLY/parametrización/rollback, fallos de SQL,
  conexión y secretos, separación de migraciones y regresiones status/apply.
- Typecheck, build y lint focalizado aprobados.
- CDK CLI oficial, `--no-lookups`, salida nueva privada; GetAtt ClientId conservado.
- El synth completo propone 13 paquetes Lambda: NO desplegarlo.
- Candidata aislada basada en la plantilla efectiva: solo
  `MigrationFunction1060F2E0.Properties.Code`, tres variables QA_INVENTORY_*
  y metadato de ruta de asset generado por CLI para esa misma función.
- Ningún otro recurso cambia: IAM, permisos, VPC, Cognito, rutas, allowlists
  (cuatro web / una destructiva), Billing, STORE-02 y demás Lambdas idénticos.

Material privado persistente, excluido de Git:
`backend/.env.web02-inventory-20261028T193128/`.
Incluye plantilla desplegada, configuración previa, paquete previo verificado
contra CodeSha256, contexto privado, synth, plantilla `migration-only.template.json`,
manifiesto `assembly/migration-only.assets.json`, hashes del paquete candidato y
diff redactado. No copiar ese contexto ni la plantilla con la identidad a reportes.

## Procedimiento histórico de publicación autorizada

1. Revalidar cuenta/perfil/región, stack estable, plantilla y configuración previa.
   Detener ante concurrencia o cambios externos; conservar respaldo verificado.
2. Publicar solo el asset señalado por `migration-only.assets.json` y la plantilla
   aislada en almacenamiento privado. No publicar el manifest completo ni usar
   `cdk deploy` sobre el assembly completo.
3. Crear y auditar un Change Set: únicamente MigrationFunction, código/configuración,
   sin reemplazos ni recursos adicionales. Esta evaluación AWS se completó antes del despliegue autorizado.
4. Solicitar autorización de ejecución. Tras ejecutarlo, comprobar hash, variables,
   estado, código/configuración de las otras Lambdas y metadatos/allowlists intactos.
   `UpdateRuntimeOn: Auto` puede actualizar la versión administrada; revisarla.
5. Invocación requiere autorización aparte. Usar exactamente la acción explícita,
   nunca payload vacío ni `apply`. Comprobar inventario antes de autorizar preflight.

## Rollback

Ante regresión, detener invocaciones. Preparar una actualización CloudFormation
limitada a restaurar el Code y Environment previos de MigrationFunction desde
el respaldo de este inventario, preservando el estado contemporáneo del resto
(sin volver a plantillas antiguas de allowlists). Auditar y autorizar esa recuperación;
no ejecutar rollback directo Lambda ni cambios de runtime automáticamente.
El zip anterior está conservado y su SHA-256 coincide con CodeSha256; si el asset
S3 anterior no está disponible, se puede republicar ese zip bajo autorización.
La acción no modifica datos; rollback de aplicación no requiere restauración SQL.

Reconciliación: source CDK conserva la acción y contexto privado. Un futuro despliegue
completo deberá resolver/auditar las diferencias incidentales de empaquetado de las
otras Lambdas, no aplicar ciegamente este synth. Las plantillas aisladas conservan
trazabilidad CloudFormation y no introducen cambios directos fuera del stack.

Dictamen vigente del inventario: PASS de ejecución autorizada y comprobación PostgreSQL. No se recuperaron ni publicaron credenciales. Los resultados son agregados: no certifican por sí solos el contenido de cada registro ni recursos externos. No hay nuevas invocaciones autorizadas por este documento.

## Propuesta pendiente del helper CDK

El runtime de inventario valida su propio subject/hash privado, ambiente y ARN;
no depende de las allowlists actuales de admisión. El helper de síntesis sí exige
QA destructivo activo, una entrada destructiva y pertenencia a QA web. Por eso no
puede reproducir la configuración operativa conservada después de la limpieza:
con subject falla; sin subject propone retirar QA_INVENTORY_* del template.

Corrección mínima propuesta, NO implementada: separar la vinculación operativa
opcional del inventario de accountDeletionQa y webSessionQa. Usar un input privado
explícito de inventario, limitado a DEV y a una identidad previamente autorizada,
con subject y hash coincidentes, preservando exactamente las tres variables ya
desplegadas. Mantener rechazo de valores incompletos/inválidos y PROD, derivación
segura del hash y las validaciones runtime existentes. No introducir identidades
ni hashes de reemplazo, no reactivar QA ni ampliar destinos del inventario.

Esto cambia la validación de infraestructura y requiere autorización antes de
editar el helper, su llamada en el stack y sus tests. La autorización propuesta
es solo para implementación local y pruebas: QA off/listas vacías válido con la
misma vinculación operativa; mismatch/PROD inválidos; diff de plantilla cero frente
al estado conservado y ninguna modificación de las allowlists. Cualquier cambio
AWS posterior requerirá otra autorización. No eliminar el helper/import para
ocultar la dependencia y no desplegar el synth completo mientras siga pendiente.

D-13, publicación pública/tiendas y presentación del recibo/logout no se resuelven
mediante el inventario y permanecen pendientes independientes.
