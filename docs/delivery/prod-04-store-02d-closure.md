# PROD-04 · Matriz de cierre STORE-02D

**Estado al 10 de noviembre de 2026.** Revisión documental completada. D-13
sigue abierta para activación pública. D-21 conserva la decisión de Apple vía
Cognito y queda pendiente de configuración y validación. Esta matriz separa
aprobaciones, evidencia y comprobaciones. No sustituye las decisiones
vigentes ni autoriza cambios de aplicación o infraestructura.

**Autoridad.** Especificación y E-01/E-14, D-13/D-21, arquitectura, ADR-002/009,
trazabilidad, roadmap y [agenda DEC-AD-01–14](account-deletion-cbqa-approval-agenda.md).
Las ADR-AD candidatas siguen propuestas. Trazas AUT-10/AUT-18–22, SYN-11–12,
MON-13/MON-21, INF-15–21, RNF-09–10, RC-06–10, REL-06–07.

## Matriz D-13

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

Evidencia: [PASS DEV histórico](store-02-account-deletion-closure.md),
[Entrega E local](store-02d-delivery-e.md), [WEB-02](web-02-admission-decoupling.md),
[runbook operativo](account-deletion-operations.md) y [PROD-01](prod-environment-readiness.md).
La matriz no extrapola el PASS sintético DEV a Apple, restore real, web
pública, operación SES o las entregas completas A–E.

## Bloqueos y dependencias de CBQA

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

## Checklist Apple Developer

- [ ] Team y responsable con permisos para Identifiers, Keys y dominios.
- [ ] App ID primario con Sign in with Apple y Bundle ID del candidato.
- [ ] Services ID que usa Cognito, asociación al App ID y mapa de
  agrupamiento de DEV, PROD y otras apps. Distinguirlo del App Client ID
  de Cognito.
- [ ] Key ID, estado y alcance de la clave; custodia y rotación del .p8 por
  canal seguro, con secreto dedicado en PROD. Compartir identificadores y
  referencias aprobadas, sin copiar material privado al repositorio.
- [ ] Dominios/retornos HTTPS autorizados. Distinguir el retorno Cognito
  /oauth2/idpresponse, el posible segundo retorno de prueba y el deep link
  móvil. Confirmar Private Relay y origen de correo si se usa para avisos.
- [ ] Decidir si se registran avisos server-to-server y quién los opera.
- [ ] Inventariar por entorno issuer, UserPoolId, dominio, clientes móvil y
  web, IdP, guards y callbacks. Registrar valores PROD solo desde outputs
  reales aprobados.

**Antes de PROD.** Revisar inventario y agrupamiento en Apple Developer
por un operador autorizado, contrastar manifest/template Cognito,
ejecutar fixtures de identidad de PROD-03 y preparar criterios de prueba
sin secretos. Un entorno aislado autorizado con Apple/Cognito reales
puede validar login, subject y canje con el mismo Services ID antes de
desplegar PROD. El alcance efectivo de revocación no se acredita con
fixtures ni con un canje exitoso.

**Con entorno real.** Validar configuración efectiva de PROD, auth_time
interactivo y acceso móvil/web Apple. Verificar aislamiento del permiso
con evidencia aprobada antes de integrar o probar revocación. Borrado,
revocación, restore y avisos reales requieren autorización independiente.

Fuentes: [runbook PROD-03](prod-03-apple-revocation-validation.md),
[configuración Apple](https://developer.apple.com/documentation/signinwithapple/configuring-your-environment-for-sign-in-with-apple),
[TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple)
y [PITR de DynamoDB](https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-properties-dynamodb-table-pointintimerecoveryspecification.html).

## Siguiente paso mínimo y preservación

CBQA puede cerrar en paralelo dos entregas sin desplegar PROD: asignar
responsables y aprobar la tabla de retención/excepciones con evidencias,
y devolver el inventario Apple no secreto para decidir si procede el
canje aislado sin revocación. El siguiente gate es aprobar el plan de
validación real, con apertura pública posterior a la verificación.

Esta revisión solo añade documentación. No cambia autenticación, captura
u OCR, leads/eventos, voz/notas, offline/sync, exportación, Gmail/Outlook,
FREE, PRO administrativo, borrado ni web. La regresión funcional de la
versión candidata sigue siendo una prueba de lanzamiento.
