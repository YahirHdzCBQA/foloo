# FL-023 · TestFlight 1.0.0 Build 5

Candidato privado iOS para AWS DEV. Fecha objetivo 2026-11-11.
Trazas EVT-09/10, SAL-04/07/08/09, REG-15/16, NAV-06, MON-01/21/22,
RNF-07/08 y REL-06/07. Autoridad funcional E-02/E-08/E-11 y la
autorización FL-023 de este incremento; ADR-001/004/006/007/009.
D-13 y D-21 continúan con sus gates de publicación.

## Correcciones locales A/B

La confirmación de un envío sin sender conectado responde
email_connection_required antes de crear la intención en el backend.
Un retry de esa intención local por /send-intents/{id}/retry encuentra un ID
remoto ausente y puede devolver not_found. El repositorio local ahora vuelve
a poner pendiente la confirmación rechazada, conservando ID, payload y clave
de idempotencia. Las operaciones posteriores repetidas no agregan otra
confirmación mientras la original siga pendiente. El lead guardado conserva
sus datos.

La previsualización traduce email_connection_required al texto aprobado ES/EN.
Para un 404, la app exige evidencia local de confirmación rechazada por falta
de conexión y una respuesta autenticada actual que confirme ausencia o
desconexión del sender. Los demás 404 conservan el diagnóstico. Sin esa
evidencia, un fallo de red, sesión o un error diferente conserva su causa.
El reintento informa la ausencia de sender y conserva la intención hasta
conectar la cuenta. El consentimiento OAuth de Gmail/Outlook sigue su flujo.

Lugar/Place conserva label, validación y persistencia; el hint nuevo es
Ej. Oficina del cliente / e.g. Client office, dibujado con inkSecondary.
El controller inicia vacío y solo el texto introducido llega al origen.
La etiqueta ya estaba localizada en el código observado.

## C · Preparación privada de tres preautorizaciones

Los correos aprobados se guardaron solo en payloads privados temporales del
operador, fuera del árbol documental. La consulta de sesión
foloo-entitlement-admin falló porque foloo-entitlement-operator carece de
credenciales de origen. El estado de las tres entradas sigue pendiente de
comprobación; sus candidatos de alta son condicionales.

Tras recuperar la sesión IAM/MFA del operador, consultar
preauthorization-status de cada payload. Preparar/ejecutar preauthorize solo
para status absent y bajo autorización de modificación separada. Para active
o consumed, conservar la entrada y verificar el grant correspondiente. Un
revoked o error se reporta antes de cualquier reactivación. Este plan opera
sobre las tres direcciones individualmente y conserva el inventario previo de
17 sin sustituirlo ni unir cuentas. Un email relay Apple distinto debe
evaluarse por la identidad verificada que resuelve FL-021.

El runbook existente de
[operación administrativa](fl021-administrative-entitlement-operations.md)
define Lambda, rol, payloads y verificaciones. La ausencia de credenciales
del operador impide declarar completada la comprobación de duplicados.

## D · Unlimited QA DEV y reversión

La lectura efectiva del API confirmó Active/Successful y
FOLOO_UNLIMITED_QA_MODE=false. Se preparó un candidato local derivado del
template desplegado de FolooBackend-dev. El diff estructural contiene solo:

Resources/ApiFunctionCE271BD4/Properties/Environment/Variables/FOLOO_UNLIMITED_QA_MODE
false → true.

El template candidato y la referencia anterior permanecen en el directorio
privado temporal del operador. No se creó Change Set. Antes de aplicar con
autorización, refrescar el baseline, revisar drift y un Change Set aislado
que muestre esa única propiedad sin replacement ni cambio de código,
roles, triggers, workers, grants o recursos. Si el template excede el límite
inline, el operador debe autorizar su staging en el bucket existente.
Mantener el contexto CDK DEV unlimitedQaMode=true durante la ventana
temporal para que un despliegue futuro no lo revierta accidentalmente.

Verificar después del cambio autorizado API saludable, flag efectivo, ambos
opt-ins cliente/backend y más de cinco leads guardados y sincronizados con
una cuenta de prueba. Este bypass es de captura QA y no acredita un grant PRO.
FL-021 conserva su procesamiento y autoridad de entitlements.

Para revertir, cerrar nuevas capturas del candidato Unlimited, sincronizar
sus pendientes e inspeccionar rechazos. Preparar desde el template efectivo
más reciente otro cambio aislado del mismo flag true → false y restaurar
el contexto DEV a false. Mantener los grants, preautorizaciones y datos.
Distribuir un candidato privado con flag cliente false y verificar FREE y
PRO por cuenta. No usar un template antiguo completo para revertir cambios
ajenos introducidos entretanto. PROD y el script de build público conservan
sus controles vigentes.

## F · Compilación y distribución propuestas

El script preparado es
[build-testflight-build5.sh](../../app/scripts/build-testflight-build5.sh).
Desde la raíz:

```bash
bash app/scripts/build-testflight-build5.sh
```

Equivale a flutter build ipa --release --no-pub --build-name=1.0.0
--build-number=5 --export-method=app-store con exactamente estos defines:

```text
FOLOO_ENVIRONMENT=dev
FOLOO_ALLOW_DEV_RELEASE=true
FOLOO_UNLIMITED_QA_MODE=true
FOLOO_APPLE_SIGNIN=true
FOLOO_MICROSOFT_SIGNIN=false
FOLOO_ACCOUNT_DELETION_ENABLED=true
FOLOO_WEB_ACCOUNT_LINK=false
FOLOO_OCR_QA_DIAGNOSTICS=false
```

La configuración DEV selecciona la API zbc91cpy10 de us-east-1 y el pool
us-east-1_QVm3dWe4O, cliente móvil 6jong3atp2crqcsde6g215ant8,
con retorno foloo://callback/ y salida foloo://signout/.

El llavero de esta revisión muestra una identidad Apple Development válida.
Apple Distribution local sigue pendiente. Xcode 27 está disponible.
Antes de exportar confirmar certificado y clave de distribución válidos o
acceso autorizado a la firma gestionada por el equipo, sin revocar ni crear
certificados como parte de este incremento. Confirmar en App Store Connect
que 1.0.0(5) está libre y qué grupo de TestFlight podrá distribuirlo tras
procesamiento/revisión beta aplicable. La disponibilidad de ese grupo y el
build no se ha consultado en esta tarea. La carga requiere autorización.

El resultado esperado es build/ios/archive/Runner.xcarchive y
build/ios/ipa/foloo.ipa. Guardar los artefactos previos antes de ejecutar la
compilación autorizada. Instalar el candidato y comprobar inicio de sesión,
OCR cámara/galería, directo con lugar, evento, seis o más leads offline,
reinicio, sync, detalle, exportación y seguimiento con ambos proveedores.
Validar dos cuentas independientes. No ejecutar borrados en el ensayo.

## Evidencia y límites

Los casos locales de FL-023 reprodujeron 409 y 404 con fixtures, y comprobaron
texto ES/EN, causas ajenas preservadas, preview y retry, reconexión sin nuevo
ID ni clave de idempotencia, aislamiento por owner e hint sin guardar.
La suite general conserva cobertura de captura, OCR, voz, evento/directo,
offline/sync, exportación, Gmail/Outlook y entitlements. El informe final
registra resultados de la corrida posterior a los últimos cambios.

Los controles de firma y distribución, los estados privados de las tres
preautorizaciones y la activación temporal de Unlimited en DEV son gates
externos pendientes. La captura ilimitada del cliente requiere que el API
también tenga el bypass activo. La prueba física de ese candidato sigue
pendiente antes de distribuirlo a testers.

Resultado final local: Flutter 357/357 PASS; backend focalizado 41/41 PASS;
cero casos fallidos u omitidos en esas corridas. flutter analyze --no-pub:
No issues found. El script de build pasó bash -n y validación de sus ocho
defines con un ejecutable Flutter simulado. La comparación estructural del
template candidato confirmó una sola propiedad distinta. Los resultados
no incluyen compilación IPA, instalación física ni operaciones de concesión
en AWS.
