# STORE-01 — Auditoría de preparación para App Store y Google Play

- Corte: **2026-10-08**
- Actualización operativa: **2026-10-09**, estado Google Play y enlace a
  STORE-02C; la auditoría original no se reejecutó en consolas.
- Tipo: investigación y documentación; no implementa ni publica cambios.
- Publisher confirmado por Producto: **CBQA Solutions**, empresa legalmente
  constituida.
- Apple: se reutiliza la cuenta existente de CBQA Solutions que ya distribuye
  Foloo por TestFlight. No se crea ni modifica otra cuenta.
- Google Play: existe una cuenta Organization registrada a nombre de CBQA. La
  invitación de developer fue enviada; acceso corporativo y verificaciones de
  identidad, sitio web y teléfono siguen pendientes.

Este documento concentra la evidencia de STORE-01. No sustituye requisitos de
Producto, decisiones abiertas, asesoría legal ni el estado en las consolas.

## Escala de estado

- **Listo y verificado:** existe evidencia técnica suficiente para este corte.
- **Parcial:** existe una base válida, pero falta completar o verificar algo.
- **Pendiente:** no existe la pieza necesaria.
- **Bloqueado:** depende de una decisión o implementación previa.
- **Validación externa:** solo puede confirmarse en una cuenta, con Producto o
  con asesoría legal.

## Resumen ejecutivo

Foloo **no está lista todavía para envío público**. La aplicación iOS tiene
Bundle ID, Team ID, versión, permisos y distribución TestFlight existentes, y
Android ya apunta a API 36. Sin embargo, los bloqueos P0 son:

1. no existe eliminación de cuenta ni de datos asociados;
2. no existen aviso de privacidad/términos publicados ni declaraciones de
   App Privacy/Data Safety verificadas; STORE-02C aporta matrices preliminares;
3. Google Sign-In en iOS exige evaluar e implementar la alternativa de login de
   la guía 4.8 de Apple; el login propio por email no se documenta todavía como
   una excepción válida;
4. solo existe configuración DEV; no hay ambiente PROD aprobado;
5. Android Release usa la clave debug y no hay evidencia de Play App Signing ni
   de un AAB de distribución;
6. los iconos son todavía los assets predeterminados de Flutter;
7. FL-021 y `D-01`–`D-04` impiden ofrecer o describir una compra real;
8. `D-13` impide cerrar retención, eliminación física y comunicación legal.

La cuenta Apple no debe recrearse. El proyecto y el archive local usan Team ID
`PU238KF2F9`; el provisioning profile inspeccionado identifica al equipo como
`Cbqa Solutions Mexico, S.C`. El archive local disponible está firmado con una
identidad **Apple Development** y perfil de desarrollo comodín: confirma equipo
y bundle, pero no demuestra la firma final App Store. El Product Owner confirma
por separado que la distribución TestFlight vigente pertenece a CBQA Solutions.
App Store Connect debe confirmar el nombre legal exacto del seller, vigencia,
roles, acuerdos y el build que realmente está en TestFlight.

## Matriz App Store

| Requisito | Estado | Evidencia | Acción |
|---|---|---|---|
| Cuenta Organization existente | Parcial / validación externa | Confirmación del Product Owner; Team ID en `app/ios/Runner.xcodeproj/project.pbxproj`; perfil local del mismo equipo | Reutilizar cuenta. Account Holder valida membership, seller legal y titularidad del App ID sin cambiar nada. |
| Bundle ID | Listo y verificado | `com.foloo.foloo` en Xcode y archive local | Confirmar que el registro App Store Connect/TestFlight usa exactamente el mismo ID. |
| Firma Release/App Store | Parcial | `CODE_SIGN_STYLE = Automatic`; archive local firmado para Development | Verificar certificado/profile de distribución del build TestFlight y preparar un archive Release reproducible. No crear certificados en STORE-01. |
| Versión/build | Parcial | `app/pubspec.yaml`: `1.0.0+2`; archive local coincide | Definir versión pública y política monotónica de build antes de STORE-04. |
| Deployment/compatibilidad | Parcial | iOS 15.5; familias iPhone+iPad; varias orientaciones | Ejecutar matriz real iPhone/iPad y decidir si iPad/landscape son soporte intencional. |
| Permisos | Parcial | Cámara, micrófono y fotos en `Info.plist` | Localizar ES/EN y ampliar fotos: también perfil e imágenes de referencia, no solo tarjeta. Probar denegación. |
| Entitlements | Parcial | No existe `.entitlements` de Runner | Correcto para el alcance actual solo si capacidades de distribución finales no requieren una. Revalidar tras FL-021 y login Apple. |
| Callback OAuth | Parcial | Cognito usa `foloo://callback/`; Google fue validado físicamente; no hay `CFBundleURLTypes` en el plist fuente/archive inspeccionado | Documentar mecanismo efectivo de Amplify/ASWebAuthenticationSession y probar login, restore y sign-out en el archive candidato. |
| Icono | Pendiente | AppIcon completo en tamaños, 1024 sin alpha, pero contiene el logo predeterminado de Flutter | Reemplazar por icono Foloo aprobado y validar contraste/legibilidad. |
| Launch/branding | Pendiente | Storyboard/assets base de Flutter | Producir y validar launch/branding Foloo sin usar assets temporales. |
| Privacy manifest | Parcial | SDKs incorporan manifests; Runner no tiene `PrivacyInfo.xcprivacy` propio | Generar Privacy Report del archive, revisar required-reason APIs y agregar manifest de app solo con declaraciones comprobadas. |
| App Privacy | Parcial documental | STORE-02C crea inventario/matriz preliminar; no existe URL aprobada ni formulario | Legal/Producto validan `privacy-compliance.md`, Privacy Report y proveedores; luego completar App Store Connect. |
| Eliminación de cuenta | Pendiente crítico | No hay UI/API Cognito/backend; solo tombstones de Event/Lead/Content | Implementar inicio de eliminación dentro de la app y contrato integral según la sección de eliminación. |
| Login guideline 4.8 | Pendiente crítico | Google es login primario; Microsoft Auth está fuera; email/password sigue disponible | Confirmar aplicabilidad con App Review/legal. La lectura conservadora exige una alternativa equivalente, normalmente Sign in with Apple. |
| Export compliance | Validación externa | `ITSAppUsesNonExemptEncryption=false`; Foloo usa TLS, Cognito y secure storage | Responder el cuestionario con asesoría competente y confirmar que el valor `false` expresa una exención válida. |
| Metadatos/edad/categoría | Pendiente | No existe paquete de ficha ES/EN | Crear nombre, subtítulo, descripción, keywords, categoría, edad, copyright, soporte, marketing y review notes. |
| Screenshots/previews | Pendiente | Sin assets versionados de tienda | Capturar dispositivos requeridos y ambas localizaciones después del polish final. |
| Review access | Pendiente | App requiere cuenta y email de confirmación | Preparar cuenta demo estable, instrucciones y, tras FL-021, estados de trial/suscripción revisables. |
| IAP/subscripción | Bloqueado | Sin StoreKit/IAP dependency ni productos | Resolver `D-01`–`D-04`; implementar FL-021, restore, backend verification y lifecycle antes de declarar compra. |
| Soporte/privacidad/términos | Pendiente crítico | No hay URLs ni pantallas legales | Publicar URLs corporativas, accesibles y consistentes con la app y ficha. |
| TestFlight | Parcial / validación externa | Producto confirma distribución activa | Revisar build, external testing, crash feedback y compliance; TestFlight no equivale a App Review pública. |

## Matriz Google Play

| Requisito | Estado | Evidencia | Acción |
|---|---|---|---|
| Cuenta Organization | Parcial / validación externa | Producto confirma cuenta CBQA e invitación developer enviada | Resolver acceso corporativo y verificar owner/roles; completar identidad, sitio web y teléfono sin crear otra cuenta. |
| Application ID | Listo y verificado | `com.foloo.foloo` en `app/android/app/build.gradle.kts` | Confirmar disponibilidad/titularidad en Play Console antes de crear el app record. |
| SDK | Listo técnico / revalidar al envío | minSdk 29; Flutter 3.47.4 resuelve compile/target SDK 36 | API 36 satisface el requisito vigente desde 2026-08-31; volver a consultar política en STORE-04. |
| Gradle/JDK | Parcial | AGP 9.1.0, Kotlin 2.4.0, Java 17; Gradle offline no pudo resolver artefactos transitorios no cacheados | Fijar toolchain CI y ejecutar build Release limpio con red controlada. |
| Firma Release | Pendiente crítico | `release.signingConfig` apunta explícitamente a `debug` | Definir upload key segura y Play App Signing. No reutilizar debug ni guardar claves/contraseñas en Git. |
| AAB | Pendiente | No existe `.aab` en artifacts locales inspeccionados | Generar AAB Release firmado solo en STORE-02/03, luego validar con bundletool/Play. |
| Permisos | Parcial | Main manifest declara `RECORD_AUDIO`; cámara/galería usan intents/pickers | Confirmar manifest fusionado Release y justificación de micrófono. `INTERNET` solo aparece directamente en manifests debug/profile; la generación fusionada no pudo cerrarse offline. |
| OAuth/deep links | Listo parcial | `foloo://callback` y `foloo://signout` con VIEW/BROWSABLE; Custom Tabs query | Probar Google login/sign-out con AAB de internal testing y verificar configuración Android en Cognito. |
| Icono | Pendiente | Solo mipmaps legacy 48–192 con icono Flutter; sin adaptive/monochrome icon | Crear icono Foloo adaptive, foreground/background y monochrome según el soporte objetivo. |
| Nombre visible | Pendiente | `android:label="foloo"` | Confirmar capitalización `Foloo` y localización si aplica. |
| Data Safety | Parcial documental | STORE-02C crea matriz preliminar; no existe formulario ni aprobación legal | Validar `privacy-compliance.md` con RC/SDKs/proveedores y política antes de completar Play Console. |
| Privacy policy | Pendiente crítico | No existe URL pública en repo/app | Publicar URL válida en ficha y acceso dentro de la app. |
| Eliminación de cuenta | Pendiente crítico | Sin ruta in-app ni URL web de solicitud | Google exige ambas rutas para apps que crean cuentas. Implementar y declarar en Data Safety. |
| App content | Pendiente | Sin evidencia de content rating, target audience, ads, app access | Completar cuestionarios con respuestas aprobadas; declarar que no hay ads solo tras verificar SDKs/build. |
| Store listing | Pendiente | Sin descripción, gráficos, screenshots ES/EN ni feature graphic | Preparar ficha/localizaciones finales y datos de contacto verificados. |
| Internal/closed testing | Pendiente | No hay cuenta/track/AAB confirmados | Iniciar internal testing cuando exista cuenta y Release firmada; confirmar qué requisito de testing aplica a la cuenta Organization. |
| Billing/subscripción | Bloqueado | No existe Play Billing dependency/productos | Resolver `D-01`–`D-04`; implementar FL-021, backend verification, restore y lifecycle. |

## Evidencia técnica transversal

### Entornos y servicios

- El runtime móvil arranca siempre con `FolooEnvironment.dev`; PROD lanza
  `UnsupportedError` en `app/lib/auth/cognito_configuration.dart`.
- La API móvil tiene un endpoint DEV como default en
  `app/lib/sync/foloo_api_client.dart`.
- Backend CDK solo acepta `dev` en `backend/infra/config.ts`.
- Cognito es el issuer de cuenta y `sub` es owner. Amplify guarda la sesión
  fuera de Drift; no hay AWS access keys/client secrets en Flutter.
- API Gateway + Lambda validan JWT y PostgreSQL/RDS conserva datos estructurados.
- S3 privado guarda binarios; Block Public Access, TLS y SSE-S3 están activos.
- Credenciales renovables de Gmail/Microsoft sender se cifran con KMS en
  PostgreSQL. Flutter recibe estado e identidad enmascarada, no tokens.
- No existe SDK de publicidad, tracking ni compra declarado directamente. El
  lockfile contiene SDKs Amplify transitorios, incluido Pinpoint; no se configura
  el plugin de Analytics en `main.dart`, pero su inclusión nativa y privacy
  manifest deben revisarse en el archive final.

### Inventario preliminar de datos

Esta tabla es el resumen STORE-01. El inventario por categoría, transferencias,
matrices Apple/Google y evidencia vigente están consolidados en
[`privacy-compliance.md`](privacy-compliance.md).

Este inventario es evidencia para preparar formularios, no una declaración
legal definitiva.

| Datos | Local | Remoto/terceros | Finalidad observada | Confirmación pendiente |
|---|---|---|---|---|
| Cuenta: email, Cognito `sub`, sesión | Secure storage Amplify; email visible | Cognito; API usa `sub` | Auth, sesión, ownership | Retención Cognito, recuperación y eliminación |
| Perfil: nombre, empresa, puesto, teléfono, foto | Drift/directorio privado | PostgreSQL; foto remota según flujo disponible | Perfil/firma del vendedor | Estado exacto de foto de perfil en cloud |
| Leads/contactos: nombre, email, teléfono, empresa, puesto, tipo, interés, notas, lugar | Drift | PostgreSQL | Registro y seguimiento comercial | Base legal, avisos a contactos, retención |
| Eventos y conteos | Drift | PostgreSQL | Organización de Leads | Retención |
| Tarjeta, fotos de referencia, voz | Directorio privado | S3 privado + metadata PostgreSQL | Captura/revisión/sync | Retención/eliminación física D-13 |
| PDF/Content | Directorio privado | S3 privado + metadata PostgreSQL | Biblioteca y adjuntos | Retención/eliminación física D-13 |
| OCR | Copia temporal/on-device | ML Kit local según arquitectura | Extraer datos de tarjeta | Verificar comportamiento/telemetría del SDK final |
| Email follow-up, destinatario, asunto/cuerpo/firma, estado | Drift | PostgreSQL; Gmail API o Microsoft Graph al confirmar | Envío solicitado por usuario | Base legal, baja, retención y términos del proveedor |
| Tokens sender | No se entregan a Flutter | Cifrados con KMS en PostgreSQL | Autorizar Gmail/Graph | Revocación efectiva al desconectar/eliminar cuenta |
| Sync/diagnóstico | IDs técnicos, outbox y errores mínimos | CloudWatch: metadata técnica sin payload prevista | Confiabilidad/operación | Retención/DSAR y auditoría de logs final |
| Trial/entitlement | Drift | PostgreSQL | Límite de cinco Leads | Compra/lifecycle FL-021 |

No hay evidencia de acceso a ubicación, contactos del dispositivo, salud,
publicidad o tracking. La cámara/fotos/micrófono se usan únicamente a petición
del usuario. La hoja Apple App Privacy y Google Data Safety deben incluir datos
procesados por Foloo y por socios/SDKs conforme a la definición de cada tienda,
incluidos datos de otras personas contenidos en Leads y medios.

### Controles confirmados y vacíos

Confirmados: HTTPS, JWT Cognito, ownership/workspace server-side, SQLite por
owner, S3 no público, RDS privado/cifrado, KMS para tokens sender, Secrets
Manager, URLs S3 temporales, sin tokens/binarios en outbox y logs backend
estructurados sin payload.

Pendientes: política de privacidad, términos, inventario legal por región,
retención, borrado físico, backup/restore/DR, producción, observabilidad,
revocación OAuth verificable, proceso DSAR, y validación de que ningún SDK
transitorio recolecta más datos que los declarados.

## Eliminación de cuenta y D-13

El logout no elimina datos. Las acciones actuales de eliminar Event, Lead o
Content crean tombstones; no borran cuenta, perfil, Cognito, correo, PostgreSQL,
S3 ni todos los archivos locales. Desconectar correo solo marca la conexión
`disconnected`; no existe evidencia de revocación del grant/token en Google o
Microsoft. No existe endpoint ni UI `Delete account`.

Contrato que debe resolverse antes de stores:

1. opción fácil de encontrar dentro de cuenta/configuración, autenticación
   reforzada y confirmación explícita;
2. solicitud durable, idempotente y owner-scoped que funcione con outbox/offline
   sin prometer borrado antes de llegar al backend;
3. bloqueo/cancelación segura de sync y nuevos envíos durante el proceso;
4. revocación de conexiones Google/Microsoft sender y, cuando aplique, del
   proveedor de login;
5. eliminación/desidentificación de Cognito, perfil, account/workspace,
   Events, Leads, media, Content, follow-ups, tokens y copias locales;
6. limpieza física S3, PostgreSQL, backups y logs según la política aprobada;
7. tratamiento de suscripción activa/cancelación tras FL-021;
8. plazo, confirmación, excepciones legales y evidencia de cumplimiento;
9. URL web pública de solicitud para Google Play, además de la ruta in-app.

`D-13` debe definir retención, backups, obligaciones legales y cleanup físico.
No puede usarse como motivo para omitir el inicio de eliminación exigido por las
tiendas; sí impide prometer qué se borra y cuándo hasta que se resuelva.

## Dependencias de FL-021

Puede prepararse antes de `D-01`–`D-04`: verificación de cuentas Organization,
acuerdos/roles, tax/banking como checklist, namespaces tentativos no creados,
arquitectura de receipt/server notifications, cuentas sandbox/license testers y
copy sin precio que no prometa compra.

Debe esperar decisiones/FL-021: tipo de compra y canal por región, product IDs,
precio/moneda/regiones, grupos de suscripción, trials comerciales, grace period,
cancelación/reembolso, restore purchases, StoreKit/Play Billing, validación
server-side, webhooks/server notifications, entitlement autoritativo y términos
de suscripción. No deben crearse productos de tienda ni firmarse acuerdos pagos
como consecuencia de STORE-01.

## Acciones manuales sin cambio de cuentas

### CBQA Solutions / Uriel

- En Apple Developer y App Store Connect: confirmar Account Holder, membership
  vigente, nombre legal/seller, D-U-N-S, Team ID, App ID `com.foloo.foloo`, app
  record, build TestFlight, roles y ausencia de avisos de compliance.
- Confirmar Agreements; Paid Apps Agreement, tax y banking solo se completan
  cuando la estrategia de FL-021 lo requiera y el representante lo autorice.
- En Google Play Console Organization existente: resolver aceptación con cuenta
  corporativa, confirmar owner/roles y completar verificaciones pendientes de
  identidad, sitio web y teléfono. Confirmar después D-U-N-S, payments profile
  y titularidad de `com.foloo.foloo`; no crear otra cuenta.
- Entregar razón social exacta, D-U-N-S, registro fiscal/mercantil, domicilio,
  teléfono, web corporativa pública, correo de soporte/privacidad y contacto con
  autoridad para obligar legalmente a la empresa.
- Aprobar países, idiomas, edad/audiencia, categoría, soporte, privacidad,
  términos, proceso de eliminación y responsable de solicitudes.
- Resolver `D-01`–`D-04` y `D-13` con Producto/legal.

### Desarrollo

- STORE-02: cerrar producción/configuración, login Apple si aplica, eliminación
  de cuenta, permisos/localización, privacy manifests y builds Release firmados.
- STORE-03: QA release, security/privacy report, account deletion E2E,
  internal/closed testing, TestFlight externo y evidencia de políticas.
- STORE-04: completar fichas, formularios, review access, productos aprobados de
  FL-021 y hacer envíos controlados; responder revisión sin cambios laterales.

### Legal/privacidad

- Base legal y aviso aplicable a datos del usuario y de sus Leads/contactos.
- Roles de CBQA Solutions, AWS, Cognito, Google/Gmail y Microsoft/Graph;
  transferencias internacionales y subencargados.
- Plazos de retención/borrado, backups, logs, facturación y obligaciones legales.
- Consentimiento/avisos para fotografía, tarjeta y grabación de voz.
- Requisitos de marketing electrónico, opt-out/baja y jurisdicciones destino.
- Export compliance de cifrado y términos de suscripción/reembolso.

## Riesgos priorizados

### P0 — bloquean submission

- Eliminación de cuenta inexistente (Apple y Google).
- Política/terms inexistentes y formularios sin validar/enviar; STORE-02C deja
  únicamente matrices preliminares.
- Revisión Apple 4.8 por Google Sign-In sin alternativa equivalente confirmada.
- Runtime exclusivamente DEV.
- Android Release firmado con debug.
- Assets de icono Flutter, no Foloo.
- FL-021/D-01–D-04 si la versión pública mantiene el bloqueo por suscripción.

### P1 — alta probabilidad de rechazo o fallo

- Retención/eliminación física y revocación sender abiertas por D-13.
- Manifest Release Android no verificado; `INTERNET` no está declarado en main.
- Purpose strings iOS solo ES e incompletos para todos los usos de fotos.
- Falta AAB/internal testing, QA iPad/orientaciones y cuenta demo de review.
- `ITSAppUsesNonExemptEncryption=false` sin determinación documentada.

### P2 — calidad operativa/metadata

- Descripción de pubspec aún dice “Frontend prototype”.
- Label Android en minúsculas y launch assets base.
- Falta paquete ES/EN, screenshots, feature graphic, soporte y release notes.
- No hay CI/CD, crash reporting/alertas ni política reproducible de releases.

## Plan STORE-02 / STORE-03 / STORE-04

### STORE-02 — Technical & Compliance Remediation

Resolver P0/P1 técnicos sin publicar: PROD separado, signing, iconos/launch,
  permisos, alternativa Apple 4.8, eliminación de cuenta integral, revocación,
  privacy report/manifests y contratos legales aprobados. La especificación
  STORE-02C está en [`privacy-compliance.md`](privacy-compliance.md). FL-021 conserva su
propia autorización y trazabilidad. El inventario y los borradores comerciales
de STORE-02B están en
[`store-listing-materials.md`](store-listing-materials.md); no reemplazan esta
remediación ni autorizan assets/publicación.

### STORE-03 — Release Candidate & Console Preparation

Generar archives/AAB de Release reproducibles; ejecutar E2E en iOS/Android,
restore/offline/delete-account/pagos sandbox; subir únicamente a TestFlight e
internal/closed testing cuando se autorice; completar borradores de fichas y
formularios sin enviar a producción.

### STORE-04 — Submission & Review

Congelar versión/build, tag/release notes, evidencia y demo access; validar una
última vez políticas vigentes; enviar a ambas tiendas con aprobación explícita;
monitorear revisión y documentar cada respuesta/rechazo.

## Checklist empresarial

- [x] Publisher definido: CBQA Solutions.
- [x] Empresa legalmente constituida: confirmado por Producto.
- [x] Cuenta Apple existente: confirmado; no crear otra.
- [ ] Razón social/seller exactos conciliados con App Store Connect, documentos
      y D&B.
- [ ] D-U-N-S y domicilio/telefono/web corporativos vigentes.
- [ ] Account Holder y representante autorizado identificados.
- [ ] Membership Apple vigente y compliance sin pendientes.
- [ ] App ID/app record/build TestFlight bajo el mismo Team ID.
- [ ] Roles mínimos para desarrollo, finanzas, legal y soporte.
- [x] Google Play Console Organization existente a nombre de CBQA.
- [ ] Invitación developer aceptada con acceso corporativo y owner/roles verificados.
- [ ] Identidad, sitio web y teléfono verificados en Play Console.
- [ ] Google payments profile Organization y datos verificados.
- [ ] `com.foloo.foloo` disponible/asignado a CBQA Solutions en Play.
- [ ] Correos corporativos de soporte, privacidad y operaciones.
- [ ] Sitio público con privacidad, términos y eliminación de cuenta.
- [ ] Paid Apps Agreement/tax/banking autorizados cuando FL-021 los requiera.

## Fuentes oficiales consultadas

Consulta: **2026-10-08**. Estas políticas deben revalidarse antes de STORE-04.

- Apple: [Account deletion 5.1.1(v)](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion),
  [App Review Guidelines, incl. 3.1 y 4.8](https://developer.apple.com/app-store/review/guidelines/),
  [App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/),
  [privacy manifests](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk),
  [organization enrollment](https://developer.apple.com/help/account/membership/enrolling-in-the-app/),
  [review access](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review),
  [export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/),
  [publishing workflow](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/overview-of-publishing-your-app-on-the-app-store/).
- Google Play: [account deletion](https://support.google.com/googleplay/android-developer/answer/13327111),
  [Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469),
  [target API levels](https://support.google.com/googleplay/android-developer/answer/11926878),
  [payments policy](https://support.google.com/googleplay/android-developer/answer/9858738),
  [Organization account type](https://support.google.com/googleplay/android-developer/answer/13634885),
  [required account information](https://support.google.com/googleplay/android-developer/answer/13628312),
  [testing tracks](https://support.google.com/googleplay/android-developer/answer/9845334),
  [App Bundles](https://developer.android.com/guide/app-bundle),
  [Play App Signing](https://developer.android.com/studio/publish/app-signing).

## Validación de STORE-01

- Revisión estática completa de SDD, ADRs, Flutter, iOS, Android, auth, datos,
  backend, infraestructura, permisos, OAuth, storage y pagos.
- Se inspeccionó el archive iOS local sin modificar cuentas ni certificados.
- Se intentó generar el manifest fusionado Android Release con Gradle offline;
  la tarea no pudo completarse porque faltan artefactos transitivos de build en
  caché. No se descargaron dependencias ni se generó AAB.
- No se ejecutaron app, deploy, migraciones, uploads, inscripciones ni pagos.
