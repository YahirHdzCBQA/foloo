# STORE-02D — Operación, SLA y restauración

**Trazas:** `AUT-19`, `MON-13`, `INF-15`–`INF-21`, `RNF-09`, `RNF-10`,
`RC-06`, `RC-07`, `RC-10`, E-14 y D-13.

## Contrato operativo

- El reloj comienza en `acceptedAt`; `operationalDeadline` es 15 días naturales
  después. Alertas preventivas: días 10 y 13; incidente crítico: día 15.
- Owner funcional: equipo de TI de CBQA Solutions. Personas y destinos se
  configuran solo al cerrar `PEND-OPS-01`; el tópico SNS nace sin suscriptores.
- Receipt/status es la fuente autoritativa. SES no cambia el workflow ni prueba
  finalización. Logs/alertas usan requestId opaco, tipo y estado; nunca email,
  `sub`, tokens, object keys, payloads o secretos.
- Logs STORE-02 en DEV retienen siete días. La retención productiva se valida
  con Legal/Seguridad antes de `PEND-PROD-01`.

## Runbooks

### Bloqueo Stripe

1. Confirmar `blocked` y checkpoint de suscripción ausente; no tocar barrera,
   receipt ni outbox.
2. Verificar salud de Billing y binding owner-scoped sin registrar referencias.
3. Dejar que el reconciliador redespache con el mismo request/idempotency key.
4. Solo una confirmación fiable de no renovación habilita etapas destructivas.

### Worker, SQS o DLQ

1. Congelar intake si aparecen fallos múltiples; mantener guards/barrera.
2. Revisar métricas worker, edad de cola, DLQ y checkpoints.
3. Corregir causa y reactivar consumo mediante Change Set auditado; no purgar.
4. Entregas duplicadas deben terminar sin repetir efectos ni mover `completed`.

### Próxima a vencer

1. Día 10: asignar caso y dependencia; día 13: escalar al responsable operativo.
2. Día 15: incidente crítico; conservar `blocked`, barrera y soporte code.
3. Nunca cambiar a `completed` sin verificación OAuth/S3/PostgreSQL/Cognito y,
   cuando aplique, cancelación Stripe confirmada.

### Fallo de notificación

1. Revisar errores SES y DLQ sin reenviar manualmente en paralelo.
2. El claim durable deduplica eventos; un lease vencido permite retry acotado.
3. Informar por receipt/status; correo fallido no bloquea ni revierte borrado.

### Restore de backup

1. Mantener API/intake cerrados. Recuperar primero ledger y tombstones vigentes.
2. Restaurar PostgreSQL y ejecutar reconciliador; reaplicar write fence y purga.
3. Validar cero barreras inconsistentes y ausencia de owners eliminados.
4. Abrir tráfico solo con aprobación de TI. Los backups automáticos ordinarios
   expiran a 15 días; snapshots manuales/exportaciones deben inventariarse y
   retirarse mediante un procedimiento autorizado. Un legal hold permanece segregado y sin uso
   para reactivar cuentas.

### Incidente de seguridad

1. Detener intake y aislar credenciales afectadas sin retirar tombstones.
2. Preservar evidencia mínima PII-free y auditar KMS/IAM/CloudTrail.
3. Escalar a TI/Seguridad/Legal; no revelar existencia de cuentas por soporte.
4. La eliminación asistida exige verificación reforzada de acceso/titularidad.

## Pendientes de lanzamiento

- `PEND-PROD-01`: AWS PROD independiente creado y validado.
- `PEND-LEGAL-01`: categorías y plazos legales/fiscales de México validados.
- `PEND-INFRA-02`: retención/restore comprobados sobre recursos productivos.
- `PEND-OPS-01`: responsables individuales y destinos de alertas asignados.

Estos pendientes no bloquean desarrollo local; sí bloquean habilitación pública.

## PROD-04 · Gates por responsable (corte 2026-11-10)

Esta matriz registra evidencia y comprobaciones pendientes al corte, no
aprobaciones nuevas ni mediciones PROD. El estado de Apple y las pruebas
aisladas se detallan en [revocación Apple](apple-revocation-validation.md).

### Matriz D-13

| Tema | Decisión vigente | Implementación y evidencia | Validación pendiente | Nueva aprobación requerida |
| --- | --- | --- | --- | --- |
| Datos activos · DEC-AD-01/08/11/13, RC-06/09 | Borrado físico de datos personales y operativos por defecto. Exportación previa voluntaria. Purga local selectiva. | Inventario owner-scoped y adaptadores S3, PostgreSQL, Cognito y OAuth. PASS DEV histórico para un owner sintético. Purga móvil y aislamiento cubiertos localmente. | Cotejar inventario completo, datos de terceros, copias externas, objetos y medios. Probar varios owners y dispositivo secundario. | Legal/Contabilidad debe enumerar cada excepción administrativa, contable o legal con base, finalidad, región, acceso y caducidad. Seguridad resuelve si hace falta cifrado local adicional. Legal confirma roles sobre datos de terceros y textos de portabilidad. |
| Copias ordinarias · DEC-AD-02, RC-07 | Retención ordinaria de 15 días. | CDK define 15 días para RDS PROD y 1 día para DEV. El ledger DynamoDB tiene PITR habilitado sin período explícito en la plantilla. CloudFormation documenta 35 días por defecto; es una inferencia de la plantilla, no una medición del entorno. | Medir configuración y expiración reales por servicio. Revisar PITR del ledger y copias adicionales contra el alcance aprobado. | Mantener los 15 días como regla. Si el ledger necesita una ventana distinta por su función de barrera, documentarla y obtener aprobación explícita para esa categoría. |
| Snapshots manuales y legal holds · DEC-AD-01/02, RC-07 | Separar excepciones legales de copias ordinarias. Tráfico cerrado hasta reconciliar cualquier restore. | El runbook separa snapshots manuales y legal holds. CDK contempla snapshot de RDS al retirar el recurso. | Inventariar snapshots iniciales, finales, copias y exportaciones. Verificar segregación, acceso, retiro y recuperación. | Legal fija base y caducidad de excepciones. TI asigna responsable, caducidad y evidencia de retiro para copias manuales; Seguridad aprueba la frontera de restore. |
| Irreversibilidad · DEC-AD-05/06, AUT-19, INF-18 | Sin cancelación tras aceptación. Ofrecer sync o continuar con consentimiento explícito. | Solicitud y barrera durables, fencing PostgreSQL, idempotencia y purga owner-scoped. Histórico DEV y pruebas locales de concurrencia, 423 y reanudación. | Verificar tokens antiguos, callbacks tardíos y segundo dispositivo físico, incluido trabajo local pendiente. | No se reabre la regla. Validar textos finales sobre alcance y pérdida de pendientes. |
| Ledger, receipt y alta posterior · DEC-AD-03/05, INF-19/20 | Registro mínimo seudonimizado. Receipt opaco. Alta nueva tras 30 días, sin datos ni beneficios anteriores. | Ledger DynamoDB fuera de PostgreSQL. El bloqueo de registro tiene expiración. Hay registros de solicitud y tombstones sin expiración explícita al escribirlos. El workflow calcula validez de receipt de 30 días, la bóveda SES configura 16 días y el inventario configura TTL de 31 días. Son valores observados en código. | Validar acceso sin sesión, vencimiento, ausencia de PII en receipt/logs, normalización, federados y rotación. Probar el límite de alta sin recuperar el owner previo. | Legal/Seguridad aprueban campos, claves, finalidad y plazo por registro y respaldo. Producto/Legal cierran elegibilidad de un nuevo trial. La expiración del receipt y la ventana de reingreso son relojes independientes. |
| Restore y resurrección · INF-18/20/21 | Reaplicar el ledger vigente antes de abrir tráfico. | El reconciliador vuelve a cercar owners y despacha purga. Entrega E cubre adaptadores simulados. El contador de trabajos programados no acredita su terminación. | Restaurar copia anterior en entorno aislado, conectar ledger vigente, verificar barreras, drenar trabajo y confirmar cero datos eliminables, sin reprovisionamiento ni callbacks, antes de tráfico. | TI/Seguridad autorizan procedimiento y responsables. Coordinar retención de tombstones con la vida de toda copia restaurable. |
| Reintentos y alertas · DEC-AD-04/07, INF-15/19 | Techo de 15 días naturales desde aceptación. Avisos operativos días 10/13 y crítico al 15. TI CBQA responsable. SES ES/EN. | Checkpoints, recuperación, DLQ, scheduler y alarmas con evidencia local. Cola y DLQ tienen 14 días en CDK. | Demostrar recuperación durable tras pérdida o expiración del mensaje, deduplicación, entrega SES y escalamiento real. | Designar destinatarios titulares y suplentes, canal y responsable de incidentes. Los plazos aprobados se mantienen. |
| Entrada móvil y web · DEC-AD-12, AUT-18, RC-08/09 | Inicio desde móvil y recurso público en foloo.io con el mismo proceso autenticado. | Flutter y BFF con preflight, confirmación y receipt. Entrega E cubre contratos y navegador simulado. El registro WEB-02 de DEV deja admisión normal y destructiva QA cerradas; no prueba disponibilidad pública actual. | Dispositivos iOS/Android y navegador contra PROD. Verificar titularidad, CSRF, callbacks, receipt sin sesión, URL externa y acceso de un owner solo Apple. | TI autoriza publicación; Legal/Producto aprueban contenido y soporte. |
| Reautenticación · DEC-AD-09, AUT-19 | Cognito interactivo, máximo cinco minutos. | API y BFF validan auth_time. Cobertura local de refresh silencioso, expiración y reconfirmación. | Confirmar por método real el owner y auth_time antes y después de la ventana. | Mantener cinco minutos. Cualquier recuperación asistida requiere diseño y aprobación propios si se propone. |
| Apple sin credencial · ADR-009, D-13/D-21 | Apple vía Cognito sigue aprobado. El ADR exige revocar el token al borrar. | Cognito canjea el código Apple; Flutter recibe tokens Cognito. STORE-02D revoca senders y finaliza Cognito. No hay revocación Apple implementada. | Confirmar credencial con el mismo Services ID y owner. Validar por separado permiso, errores transitorios y rama sin credencial. | Seguridad/Producto/Legal aprueban el camino TN3194 para completar el borrado Foloo, indicar revocación manual, responder al aviso de credencial revocada según la integración y reflejar la diferencia en el receipt. El fallo transitorio con credencial sigue siendo reintentable. |
| Renovación PRO · DEC-AD-10, MON-13/21, RC-10 | Cuando existe una renovación vinculada, aceptar/bloquear primero y confirmar cancelación antes de finalizar. Sin gracia ni reembolso automático. | Entrega A/E cubre cancelación simulada y fallo reintentable. PRO administrativo conserva su régimen y la purga invalida sus preautorizaciones. | Confirmar que PROD inicial carece de vínculos comerciales y verificar borrado del grant/selector administrativo. Si se introduce una renovación en una versión posterior, exigir su prueba específica. | Ninguna autorización de checkout para 1.0. Legal/Contabilidad cierra exclusivamente retención o derechos aplicables. FL-022 queda diferida. |

### Bloqueos y dependencias de CBQA

1. **Legal/Contabilidad y Producto.** Cerrar inventario por categoría
   (datos activos, excepciones, backups, logs, ledger/receipt, inventario
   transitorio y material de notificación), plazos, mercados/idiomas/menores,
   roles sobre leads de terceros, elegibilidad de trial y textos públicos.
2. **Seguridad.** Aprobar HMAC/normalización/rotación y su cobertura federada,
   horizonte de tombstones frente a copias restaurables, secretos y alcance
   del permiso Apple, representación del camino manual y cifrado local.
3. **TI/Operaciones.** Nombrar responsables y destinos de escalamiento,
   confirmar cuenta, facturación y accesos PROD, programar restore aislado,
   verificar expiración efectiva y SES, coordinar dominio y publicación web.
   La revisión de restore no termina al despachar la purga.
4. **Apple y tiendas.** Cerrar D-21, validar borrado móvil y web con el
   candidato firmado y alinear privacidad, soporte y formularios con lo que
   el entorno realmente hace. Solicitar autorización separada antes de
   cualquier prueba destructiva.

## Inventario privado y restauración de WEB-02

### Contrato y límites

La Lambda operativa MigrationFunction acepta explícitamente `{"action":"qa-inventory"}`.
No admite otros campos, SQL ni identidad en el evento. Acciones desconocidas fallan
antes de leer secretos. `apply`/`status` conservan sus flujos; el inventario retorna
antes de entrar a ellos. No invocar la Lambda con `{}`: ese contrato histórico
aplica migraciones.

La configuración privada fija el sub sintético y su hash. El helper original requería ambas allowlists; la extensión del 2026-11-04 hizo el selector independiente.
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

### Selector operativo independiente y extensión STORE-02D

El runtime de inventario valida su propio subject/hash privado, ambiente y ARN;
no depende de las allowlists de admisión. La implementación local del 2026-11-04
alinea el helper CDK con esa frontera: `qaInventorySubject` continúa siendo un
opt-in exclusivo de DEV, deriva el hash de forma determinista y ya no exige
activar QA destructivo ni pertenecer a Web Sessions. Valores ausentes cierran el
diagnóstico y valores inválidos o PROD fallan la síntesis.

La misma extensión añade únicamente agregados: miembros totales y ajenos del
workspace personal, notas escritas no vacías, medios por tipo, referencias de
objetos y conteos locales de referencias/estado Billing. Conserva la consulta
estática parametrizada, transacción READ ONLY, timeouts, ROLLBACK, conexión
destruida y respuesta sin filas, IDs ni contenido.

El Change Set temporal, si se autoriza, debe construirse desde la plantilla efectiva y cambiar
solo código, `QA_INVENTORY_SUBJECT` y `QA_INVENTORY_SUBJECT_HASH` de
MigrationFunction. Tras una única invocación autorizada se restaura el código y
selector previos o se retiran las tres variables mediante otro Change Set
auditado. No desplegar el synth completo ni usar el diagnóstico para activar
admisión, Web Sessions o Account Deletion.

D-13, publicación pública/tiendas y presentación del recibo/logout no se resuelven
mediante el inventario y permanecen pendientes independientes.

**Preflight y rollback autorizados.** Validar stack, baseline y artefactos
privados; publicar solo el asset de MigrationFunction y auditar que no
cambien otros recursos. Invocar solo con autorización separada y nunca con
payload vacío. Recuperar Code y Environment previos desde ZIP/hash y plantilla
verificados sin restaurar allowlists antiguas. Rollback no requiere SQL.
El inventario no cubre Stripe, S3 externo ni estados de envío pendientes:
para QA sintético, revisar Registros y estado sender sin enviar ni reconectar;
las rutas API pueden tocar timestamps de principal, no equivalen a READ ONLY.

**Retiro QA y recuperación de admisión.** Tras retirar el hash no volver al
bundle legacy que exigía QA activa para arrancar. Conservar código compatible,
receipt y trabajo aceptado. No reintroducir hashes anteriores ni deshabilitar
guards. Para web, cerrar primero el frontend, después el flag del BFF y, si
se autorizó invalidación, vaciar la allowlist sin borrar DynamoDB/KMS.
No reutilizar assemblies históricas; verificar todas las dependencias
dinámicas y el runtime administrado en cualquier futuro Change Set.

### Migraciones 009/010 y despliegue pasivo

El runbook de STORE-02.5 es histórico; 010 ya está aplicada en DEV (18
triggers al cierre verificado). No repetirla para habilitar la web. En un
entorno nuevo o un restore aprobado, revisar plantilla y drift sin aplicar,
respaldar y verificar RDS, consultar únicamente la acción explícita
`status`, y aplicar solo la migración aprobada por nombre si está pendiente.
No habilitar intake, worker o web por efecto colateral. Verificar fences
antes de tráfico y no restaurar snapshots, retirar triggers ni volver a
código incompatible como reacción automática.
