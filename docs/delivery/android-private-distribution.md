# STORE-03B — APK Android Release para pruebas privadas

- Estado: preparación técnica; distribución y QA físico pendientes.
- Alcance: APK firmado `com.foloo.foloo`, versión `1.0.0+2`, conectado solo a
  AWS DEV.
- Trazas: `RNF-02`, `RNF-05`–`RNF-07`, `REL-01`, `REL-02`, `REL-06`, `REL-07`
  y E-12.

Este procedimiento no publica Foloo, no crea PROD, no sustituye Google Play
Internal Testing y no modifica iOS. El APK solo puede entregarse a testers
autorizados que utilicen cuentas y datos de prueba.

## Firma y custodia

- El desarrollador de Foloo es custodio temporal del keystore Release.
- El keystore vive fuera del repositorio, bajo
  `$HOME/.foloo/android-signing/`, con directorio `0700` y archivo `0600`.
- Las contraseñas se conservan en macOS Keychain; no existen en Git, Gradle,
  scripts versionados, documentación o argumentos de build.
- Gradle exige `FOLOO_ANDROID_KEYSTORE_PATH`,
  `FOLOO_ANDROID_KEYSTORE_PASSWORD`, `FOLOO_ANDROID_KEY_ALIAS` y
  `FOLOO_ANDROID_KEY_PASSWORD`; Release falla si faltan. Debug no usa esta
  firma.
- Alias aprobado para esta preparación: `foloo-release`. El certificado es
  autofirmado RSA 4096/SHA-256 y el keystore es JKS.
- La transferencia formal a TI de CBQA permanece pendiente de autorización.

Perder el keystore o sus contraseñas impide firmar una actualización compatible
del APK directo. Exponerlos permitiría a un tercero firmar binarios que Android
aceptaría como actualización. No deben compartirse por chat, Teams o correo.

## Respaldo pendiente

El custodio debe crear manualmente una copia cifrada en una ubicación separada,
aprobar quién conoce su passphrase y probar recuperación antes de ampliar el
grupo de testers. Un procedimiento local posible, que solicita la passphrase de
forma interactiva, es:

```sh
gpg --symmetric --cipher-algo AES256 \
  "$HOME/.foloo/android-signing/foloo-release.jks"
```

La copia cifrada no se sube automáticamente. Debe comprobarse restaurándola en
un directorio temporal y validando el alias con `keytool`; después se elimina la
copia temporal. Registrar únicamente fecha, custodio y resultado, nunca la
passphrase ni rutas personales. STORE-03B no considera el respaldo confirmado
hasta recibir esa evidencia.

## Build reproducible DEV

Recuperar las credenciales desde Keychain sin imprimirlas y construir desde
`app/`:

```sh
export FOLOO_ANDROID_KEYSTORE_PATH="$HOME/.foloo/android-signing/foloo-release.jks"
export FOLOO_ANDROID_KEY_ALIAS="foloo-release"
export FOLOO_ANDROID_KEYSTORE_PASSWORD="$(security find-generic-password -a foloo-release -s com.cbqa.foloo.android-signing.store -w)"
export FOLOO_ANDROID_KEY_PASSWORD="$(security find-generic-password -a foloo-release -s com.cbqa.foloo.android-signing.key -w)"

flutter build apk --release \
  --build-name=1.0.0 \
  --build-number=3 \
  --dart-define=FOLOO_API_BASE_URL=https://zbc91cpy10.execute-api.us-east-1.amazonaws.com \
  --dart-define=FOLOO_COGNITO_HOSTED_UI_DOMAIN=us-east-1qvm3dwe4o.auth.us-east-1.amazoncognito.com \
  --dart-define=FOLOO_AUTH_SIGN_IN_REDIRECT=foloo://callback/ \
  --dart-define=FOLOO_AUTH_SIGN_OUT_REDIRECT=foloo://signout/

unset FOLOO_ANDROID_KEYSTORE_PASSWORD FOLOO_ANDROID_KEY_PASSWORD
```

Los identificadores Cognito y URLs anteriores son configuración pública DEV;
no son secretos. Futuras entregas conservan package/certificado y aumentan
`build-number`. Antes de elegirlo se compara con todas las entregas previas; no
se presupone disponibilidad en Play Console.

## Evidencia técnica de la preparación

El 2026-10-13 se generó el APK privado `foloo-dev-1.0.0+2-release.apk`. La
verificación local confirmó:

- package `com.foloo.foloo`, versión `1.0.0`, `versionCode` 2 y SDK 29–36;
- firma APK v2 válida con un único certificado `CN=Foloo Android Release,
  O=CBQA Solutions`, diferente del certificado Android Debug;
- manifest fusionado con `INTERNET`, `RECORD_AUDIO`, conectividad y los deep
  links `foloo://callback/` y `foloo://signout/`;
- `flutter analyze` sin issues y 274 pruebas Flutter aprobadas;
- configuración R8 limitada a ignorar referencias de ML Kit a reconocedores de
  scripts opcionales no incluidos. Foloo conserva el reconocedor latino y no se
  modifica el comportamiento OCR.

El APK y su hash pertenecen a cada ejecución y no se versionan. Antes de
compartir una copia se recalcula el SHA-256 y se comunica por un canal separado.
La validación anterior es técnica; no sustituye la instalación ni el QA físico.

## Instalación sin USB

1. Recibir el APK mediante un enlace privado autorizado y comprobar su SHA-256
   contra el valor comunicado por un canal separado.
2. Descargarlo y abrirlo desde Descargas/Archivos.
3. Cuando Android lo solicite, permitir temporalmente “instalar apps
   desconocidas” solo para esa aplicación de descarga.
4. Instalar Foloo, abrirla e iniciar sesión con una cuenta de prueba autorizada.
5. Retirar después el permiso para instalar desde esa fuente.

No se debe desactivar Play Protect. Los nombres de opciones pueden variar por
fabricante y versión de Android.

### Actualizaciones y problemas frecuentes

- Una actualización necesita `com.foloo.foloo`, el mismo certificado y un
  `versionCode` superior. Si coinciden, normalmente se instala sobre la versión
  anterior conservando datos.
- “Aplicación no instalada” puede indicar firma distinta, versión inferior,
  archivo incompleto o espacio insuficiente. Comparar hash y versión antes de
  cualquier desinstalación.
- Desinstalar puede borrar Leads, medios, PDF y operaciones todavía locales.
  Sincronizar y confirmar pendientes antes de considerarlo.
- Si el navegador no vuelve al login, verificar navegador predeterminado,
  conectividad y callback Cognito; no reinstalar como primera medida.
- Si falla Internet, confirmar red y recordar que el APK apunta a DEV. Offline
  no equivale a logout.
- Si micrófono está denegado, habilitarlo desde Ajustes de Foloo; no se requieren
  permisos amplios de fotos o almacenamiento para los pickers actuales.
- Si la app se cierra al iniciar, registrar versión Android, modelo, hora y paso
  exacto sin compartir tokens, contraseñas o datos de Leads.

## Checklist de QA físico pendiente

- [ ] Descarga e instalación sin USB; hash verificado.
- [ ] Inicio de sesión email/password y Google; callback y restore de sesión.
- [ ] Captura Evento y Directo; OCR de tarjeta real; cámara y galería.
- [ ] Nota escrita, Voice Note y sus permisos.
- [ ] Guardado local, reinicio y datos conservados.
- [ ] Sync AWS DEV, outbox, pérdida y recuperación de conectividad sin duplicar.
- [ ] Registros, edición, Eventos y aislamiento entre dos cuentas de prueba.
- [ ] Content/PDF: importar, ver offline, asignar y soft-delete.
- [ ] Exportación CSV/XLSX y share sheet con Unicode.
- [ ] Conexión sender compatible, revisión y envío de correo de prueba.
- [ ] Trial de cinco Leads y bloqueo recuperable del sexto.
- [ ] Logout sin borrar datos de producto.
- [ ] Actualización sobre un APK previo compatible, cuando exista.

Las pruebas automatizadas no sustituyen esta matriz. STORE-03B permanece
abierta hasta que el desarrollador registre resultados físicos y autorice la
distribución privada.

## STORE-03C — Hallazgos de la primera prueba Android

La primera instalación física aprobó instalación, Auth, cámara/galería, voz,
offline/sync, Eventos/Registros/Content, correo/Trial y logout/restore. Quedan
abiertos:

- OCR: la UI recibió una excepción técnica. El APK inspeccionado sí contiene
  `text-recognition:16.0.1`, bibliotecas nativas y assets del modelo latino; no
  existe evidencia de que las reglas R8 para alfabetos opcionales sean la
  causa. El siguiente build registra únicamente etapa, tipo de excepción y
  código de plataforma, sin imagen, texto, rutas o PII.
- Exportación: Compartir permanece disponible y Android agrega Guardar en
  dispositivo usando el Storage Access Framework a través del selector nativo.
  CSV/XLSX conservan bytes, filename y MIME del generador probado.

El APK de diagnóstico/corrección debe usar `versionCode` 3, el mismo package y
el mismo certificado. Se instala como actualización; no debe desinstalarse la
versión 2 porque podría haber datos locales todavía no sincronizados.

El 2026-10-14 se generó
`foloo-dev-1.0.0+3-store-03c-release.apk`. La inspección confirmó package
`com.foloo.foloo`, certificado idéntico al build 2, firma APK v2 válida, SDK
29–36 y ausencia de permisos amplios de almacenamiento. `flutter analyze` quedó
sin issues y 279 pruebas Flutter aprobaron. Estos resultados no confirman OCR
ni el selector documental en la tablet.

### Evidencia OCR necesaria

Después de actualizar, repetir cámara y galería con una tarjeta de texto latino
nítida. Si reaparece el error técnico, capturar únicamente líneas con la marca
`foloo.ocr`; tienen esta forma y no contienen contenido de la tarjeta:

```text
foloo.ocr: stage=recognition errorType=PlatformException \
platformCode=<code> candidate=<index>
```

Con una estación Android autorizada puede limpiarse Logcat, reproducirse una
sola vez y filtrar `foloo.ocr`. No se deben compartir otras líneas que puedan
contener datos del dispositivo o de la sesión. El código de plataforma es la
evidencia requerida antes de cambiar R8, ML Kit o el pipeline de imagen.

## STORE-03D — Diagnóstico OCR Release controlado

Dos testers reprodujeron el mismo error técnico en Android Release build 3,
tanto desde Cámara como desde Galería. La inspección estática no identifica la
etapa ni el código nativo: el paquete conserva ML Kit Latin bundled y no existe
evidencia para cambiar R8, dependencias o preprocesamiento antes de capturar la
excepción real.

El build privado 4 de STORE-03D debe construirse agregando:

```sh
--dart-define=FOLOO_OCR_QA_DIAGNOSTICS=true
```

Sin ese define, los diagnósticos quedan deshabilitados incluso en Release. Con
el define, `foloo.ocr` emite solo etapa, resultado técnico, tipo/código de
excepción e índice de intento. Nunca registra imagen, texto reconocido, path,
mensaje arbitrario de la excepción, identidad o credenciales. El build 4 no
constituye por sí mismo una corrección del OCR.

En una estación autorizada:

```sh
adb logcat -c
# Reproducir una vez Cámara y una vez Galería.
adb logcat -d -s flutter | grep 'foloo.ocr'
```

Si el fabricante no etiqueta la salida como `flutter`, usar el filtro estricto
sobre el volcado y compartir exclusivamente las líneas `foloo.ocr`:

```sh
adb logcat -d | grep 'foloo.ocr'
```

No desinstalar el build 3. La actualización requiere el mismo package,
certificado y `versionCode` 4. En ese momento STORE-03D permanecía abierta hasta
corregir la causa sustentada por esos registros y validar texto latino real
desde ambas fuentes en un Android físico.

El 2026-10-14 se generó el APK de diagnóstico
`foloo-dev-1.0.0+4-store-03d-ocr-qa-release.apk` con el flag anterior. La
inspección confirmó `com.foloo.foloo`, versión `1.0.0`, `versionCode` 4, SDK
29–36, firma APK v2 y el mismo certificado Release del build 3. Conserva ML Kit
Latin bundled y no agrega permisos. Su SHA-256 es:

```text
aa3def9cf386ea2ed5a02171cfaca7d88e73533975c5f4f5bec8906578951876
```

`flutter analyze` terminó sin issues, la suite completa aprobó 281 pruebas y
las 24 pruebas OCR/preprocesamiento/parser aprobaron. Son pruebas unitarias o
simuladas; ninguna ejecuta el motor nativo ML Kit en un Android físico.

## STORE-03E — Prueba controlada R8 del fallo nativo OCR

Build 4 confirmó en Cámara y Galería:

```text
stage=preprocessing result=preprocessingSucceeded
stage=recognition result=failed errorType=PlatformException platformCode=error
```

El stack nativo ofuscado se repitió en las cinco orientaciones. Retrace con
`build/app/outputs/mapping/release/mapping.txt` del propio build 4 produjo:

```text
java.lang.NullPointerException
  at com.google.android.gms.internal.mlkit_vision_common.zzmj.<init>
     (com.google.mlkit:vision-common@@17.3.0:8)
  at com.google.android.gms.internal.mlkit_vision_common.zzmr.create
     (com.google.mlkit:vision-common@@17.3.0:8)
```

El APK incluye el modelo Latin y sus librerías. Además, la configuración R8
conserva los registrars de componentes ML Kit/Firebase, por lo que el stack
desofuscado no autoriza una regla `-keep` concreta. Nombres ofuscados tampoco
demuestran por sí solos que R8 causó el nulo.

La inspección DEX muestra el nulo inmediato: la fábrica `zzmr` solicita
`SharedPrefManager` al contenedor de componentes ML Kit y lo entrega a
`zzmj`; el constructor ejecuta `SharedPrefManager.getClass()` y falla porque
esa dependencia llegó como `null`. Aún no está probado por qué el contenedor no
la resolvió ni si la transformación R8 lo provocó; esa es precisamente la
variable que aísla build 5.

Para aislarlo, build 5 mantiene exactamente el mismo package, certificado,
configuración DEV, dependencias y pipeline OCR del build 4. La única variable
Android es:

```sh
export FOLOO_ANDROID_DISABLE_R8_FOR_OCR_QA=true
```

Ese flag desactiva minificación y resource shrinking solo durante el build de
QA. Sin el flag, Release conserva ambos. El diagnóstico seguro de STORE-03D
continúa habilitado con `FOLOO_OCR_QA_DIAGNOSTICS=true` para comparar etapas.

Actualizar build 4 con build 5 sin desinstalar. Probar la misma tarjeta nítida
primero desde Cámara y después desde Galería. Registrar si aparecen campos OCR
y compartir exclusivamente líneas `foloo.ocr`; no compartir imagen, texto,
rutas, identidad ni el resto de Logcat.

- Si ambas fuentes funcionan, R8 queda aislado como condición causal y el
  siguiente paso es derivar la regla mínima, reactivarlo y generar otro build.
- Si ambas siguen fallando con el mismo stack, se descarta R8 y se investiga
  inicialización/versiones del plugin y ML Kit sin añadir reglas especulativas.

Antes de la prueba física, STORE-03E permanecía abierta: un build sin R8 no era
una corrección definitiva y las pruebas automatizadas no ejecutaban el motor
Android nativo.

El 2026-10-14 se generó
`foloo-dev-1.0.0+5-store-03e-no-r8-ocr-qa-release.apk`. La inspección confirmó
`com.foloo.foloo`, versión `1.0.0`, `versionCode` 5, SDK 29–36, firma APK v2 y
el mismo certificado Release de build 4. No incluye permisos amplios de
almacenamiento. `apkanalyzer` conserva en DEX la clase y firma originales
`mlkit_vision_common.zzmj.<init>(Context, SharedPrefManager, zzmc, String)`, a
diferencia del build 4 minificado; esto verifica la variable de la prueba sin
atribuir todavía causalidad.

SHA-256 del APK:

```text
935af69d0b8c7a95c7a771cbcef1ec665c4d633bff9a052acbb7119e1a2eaa8c
```

`flutter analyze` terminó sin issues, la suite completa aprobó 281 pruebas,
`dart format` no cambió archivos y `git diff --check` aprobó. El resultado OCR
nativo de ese build fue aprobado posteriormente en la prueba física.

La prueba física de build 5 aprobó OCR latino desde Cámara y Galería. STORE-03E
queda completada como aislamiento: desactivar R8/resource shrinking evita el
fallo, pero ese APK continúa siendo únicamente el fallback privado de
diagnóstico y no la configuración Release definitiva.

## STORE-03F — Corrección mínima con Release optimizado

El grafo resuelto usa `firebase-components:16.1.0`. Su consumer rule contiene:

```text
-keep class * implements com.google.firebase.components.ComponentRegistrar
```

Con AGP 9 strict full mode esa regla conserva la clase, pero no implica
conservar su constructor. El DEX de build 4 confirma que
`CommonComponentRegistrar` permaneció sin `<init>()`; el DEX de build 5 sin R8
sí conserva el constructor. Como `ComponentDiscovery` crea los registrars por
reflexión, la ausencia del constructor impide ejecutar `getComponents()` y deja
sin registrar `SharedPrefManager`, que después llega nulo a `zzmj`.

La corrección de aplicación se limita a:

```text
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
}
```

No conserva todos los miembros de Firebase, ML Kit o Google. El build 6 se
genera sin el flag de STORE-03E: minificación, optimización, obfuscación y
resource shrinking vuelven a estar activos. Tampoco habilita el diagnóstico
OCR opt-in de STORE-03D por defecto.

Build 6 debe instalarse sobre build 5, nunca después de desinstalar. El QA debe
validar Cámara, Galería, extracción de campos, sesión/datos, exportación y una
sincronización básica. Build 5 queda documentado únicamente como fallback
temporal para diagnóstico, no como configuración Release final.

El 2026-10-14 se generó
`foloo-dev-1.0.0+6-store-03f-r8-ocr-fix-release.apk` sin el flag que desactiva
R8 y sin habilitar los diagnósticos OCR. El mapping confirma R8 `9.1.31`; el
tamaño volvió al rango minificado de build 4 y el DEX conserva los constructores
de `CommonComponentRegistrar`, `VisionCommonRegistrar` y `TextRegistrar`, a la
vez que `zzmj` continúa optimizada/ofuscada. Esto verifica que la regla no
desactivó globalmente la optimización.

La inspección confirmó `com.foloo.foloo`, versión `1.0.0`, `versionCode` 6,
SDK 29–36, firma APK v2, el mismo certificado Release de build 5 y ausencia de
permisos amplios de almacenamiento. SHA-256:

```text
d9d0ceee25c9f91baa690b9526f777ad24223b9193570a0f9ca3c6bb70e9d53f
```

`dart format` no cambió archivos, `flutter analyze` terminó sin issues, las 281
pruebas Flutter aprobaron y `git diff --check` quedó limpio.

### Cierre físico STORE-03F

El responsable de QA reportó aprobados sobre `1.0.0+6`, sin desinstalar:

- OCR desde Cámara;
- OCR desde Galería;
- conservación de datos y sesión;
- exportación CSV/XLSX;
- sincronización con AWS DEV;
- persistencia después de reiniciar la aplicación.

No se registran aquí pruebas adicionales no reportadas. Con esa evidencia,
STORE-03F queda **CLOSED** y la regla mínima de `ComponentRegistrar` permanece
en la configuración Release optimizada.

## STORE-03G — Distribución privada del candidato Build 6

El artefacto autorizado para preparar —sin distribuir automáticamente— es:

- archivo: `foloo-dev-1.0.0+6-store-03f-r8-ocr-fix-release.apk`;
- versión: `1.0.0`, `versionCode` 6;
- package: `com.foloo.foloo`;
- entorno: **AWS DEV**, no producción;
- SHA-256:
  `d9d0ceee25c9f91baa690b9526f777ad24223b9193570a0f9ca3c6bb70e9d53f`.

### Compartir con testers autorizados

1. Cargar manualmente el APK en un almacenamiento privado aprobado por CBQA,
   con acceso restringido a testers identificados y sin enlace público.
2. Comunicar el SHA-256 por un canal separado del enlace y exigir su
   verificación antes de instalar.
3. Indicar que el APK usa AWS DEV y solo admite cuentas/datos de prueba
   autorizados.
4. El tester descarga el archivo, habilita temporalmente instalación desde esa
   fuente y elige **Actualizar**; nunca debe desinstalar la versión anterior.
5. Tras instalar, retira el permiso de fuentes desconocidas y confirma que
   sesión y datos locales continúan disponibles.

Un reporte de error debe incluir modelo, versión Android, build `1.0.0+6`, hora
aproximada, módulo, pasos y resultado observado/esperado. Adjuntar únicamente
logs sanitizados solicitados por el equipo; nunca incluir imágenes de tarjetas,
datos de Leads, correos, tokens, contraseñas, rutas privadas o el keystore.

STORE-03G completó la auditoría técnica. La carga o entrega del APK permaneció
pendiente de autorización humana y cualquier operación Git posterior quedó bajo
control exclusivo del desarrollador. No se publicó en Google Play ni se creó
un enlace de distribución.

## STORE-03H — Paquete operativo de distribución privada

**Estado:** preparado, no distribuido. STORE-03F permanece **CLOSED** y Build 6
es el candidato aprobado. La distribución y cualquier operación Git están
reservadas al desarrollador y requieren su autorización expresa.

### Artefacto que debe compartirse

- `foloo-dev-1.0.0+6-store-03f-r8-ocr-fix-release.apk`
- versión `1.0.0`, `versionCode` 6, package `com.foloo.foloo`;
- firma Release: `CN=Foloo Android Release, O=CBQA Solutions`;
- certificado SHA-256:
  `288297a790533fd4f09fd4b262e310bbb4201efc8d0c02c5f4b9991fbb6ee002`;
- APK SHA-256:
  `d9d0ceee25c9f91baa690b9526f777ad24223b9193570a0f9ca3c6bb70e9d53f`;
- entorno: **AWS DEV**; no contiene configuración de producción.

Antes de cada entrega debe recalcularse el hash del archivo que realmente se
subirá. Un nombre, tamaño o hash diferente se trata como otro artefacto y no
hereda la aprobación de Build 6.

### Almacenamiento corporativo propuesto

Usar SharePoint u OneDrive empresarial administrado por CBQA, sujeto a
confirmación de TI, dentro de una carpeta específica de distribución Android:

- acceso nominal solo para responsable de release y testers autorizados;
- enlace restringido a personas invitadas, sin acceso anónimo ni indexación;
- descarga permitida, pero sin edición ni reemplazo por testers;
- fecha de expiración y revocación al terminar la ronda;
- auditoría de accesos habilitada cuando la plataforma lo permita;
- APK separado de keystore, contraseñas y cualquier credencial;
- SHA-256 comunicado por un canal corporativo distinto del enlace.

No usar enlaces públicos, servicios personales, adjuntos masivos ni grupos sin
control de membresía. STORE-03H no crea la carpeta, sube el APK ni genera el
enlace.

### Instrucciones para instalar o actualizar

1. Confirmar que el dispositivo usa Android 10 o superior y tiene espacio
   suficiente.
2. Descargar el APK desde el enlace privado y comprobar que su SHA-256 coincide
   exactamente con el valor aprobado.
3. Si Foloo ya está instalada, **no desinstalarla ni borrar sus datos**. Abrir
   el APK y elegir Actualizar; mismo package, certificado y un `versionCode`
   superior permiten conservar la instalación.
4. Si Android lo solicita, autorizar temporalmente a la aplicación usada para
   descargar/abrir el archivo a instalar aplicaciones desconocidas. No
   desactivar Play Protect.
5. Abrir Foloo y confirmar versión `1.0.0+6`, sesión y datos conservados.
6. Retirar inmediatamente el permiso para instalar aplicaciones desconocidas.
7. Usar exclusivamente cuentas y datos de prueba autorizados: el APK se conecta
   a AWS DEV.

Ante “Aplicación no instalada”, detenerse y reportar el mensaje. No desinstalar
como solución: primero verificar hash, espacio, package, firma y versión previa.

### Checklist mínimo del tester

- [ ] APK recibido desde el enlace corporativo restringido.
- [ ] SHA-256 verificado antes de instalar.
- [ ] Instalación o actualización completada sin desinstalar.
- [ ] Aplicación abre y muestra `1.0.0+6`.
- [ ] Sesión y datos locales existentes permanecen disponibles, si aplicaba.
- [ ] Login de prueba y restore de sesión funcionan.
- [ ] OCR Cámara reconoce una tarjeta latina autorizada.
- [ ] OCR Galería reconoce una imagen latina autorizada.
- [ ] CSV y XLSX pueden generarse, compartirse/guardarse y abrirse.
- [ ] Sincronización AWS DEV completa sin duplicar ni perder registros.
- [ ] Reiniciar la aplicación conserva datos y sesión esperados.
- [ ] Se retiró el permiso de instalación desde fuentes desconocidas.
- [ ] Resultado e incidentes quedaron asentados en el registro de la ronda.

### Borrador de mensaje de entrega

> Foloo Android `1.0.0+6` está disponible para una prueba privada autorizada.
> Este build utiliza AWS DEV y debe usarse únicamente con cuentas y datos de
> prueba. Descarga el APK desde el enlace corporativo restringido y verifica
> antes de instalar el SHA-256 enviado por el canal separado. Si ya tienes
> Foloo, elige Actualizar: no desinstales ni borres datos. Al terminar, retira
> el permiso de instalación desde fuentes desconocidas y registra el resultado
> en el formato de QA. No reenvíes el APK ni el enlace.

El responsable añade manualmente el enlace restringido, el canal donde se
comunicó el hash, la fecha límite y el contacto de soporte antes de enviarlo.

### Registro de testers, dispositivos y resultados

Mantener el registro en una ubicación corporativa restringida. No incluir
contraseñas, tokens, contenido de tarjetas, Leads reales ni logs sin sanitizar.

| Ronda | Tester autorizado | Modelo | Android | Build previo | Build probado | Hash verificado | Instalación/actualización | QA | Incidente | Fecha |
|---|---|---|---|---|---|---|---|---|---|---|
| `STORE-03H-01` | Alias corporativo | Pendiente | Pendiente | Pendiente | `1.0.0+6` | Sí/No | Pendiente | Pendiente | ID o ninguno | Pendiente |

Para un incidente registrar modelo, versión Android, hora aproximada, módulo,
pasos, resultado esperado/observado y un identificador del reporte. Evidencia
adicional solo se solicita y comparte sanitizada por el canal aprobado.
