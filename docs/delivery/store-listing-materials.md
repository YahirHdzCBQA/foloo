# STORE-02B — Identidad visual y materiales de tienda

- Corte: **2026-10-09**.
- Estado: **PREPARADO COMO BORRADOR; pendiente aprobación y producción de
  assets por CBQA Solutions**.
- Tipo: inventario, propuesta y checklist. No publica, no cambia el producto y
  no autoriza reemplazar iconos o splash.
- Trazas: `REL-06`, `REL-07`, `RNF-02`, `RNF-06`, E-12 y `f5-08`.
- Dependencias: [`store-readiness.md`](store-readiness.md), `D-01`–`D-04`,
  `D-11` y `D-13`.

Este documento es el paquete operativo de STORE-02B. Las propuestas describen
solo capacidades reales del Foloo V1 vigente. No anuncian compra, pagos,
automatización, transcripción, Google Sheets, equipos ni Microsoft Sign-In. La
ficha no está lista para cargarse hasta que CBQA apruebe identidad, copy, datos
legales y bloqueos de STORE-01.

## 1. Inventario de identidad y recursos actuales

### Marca usada dentro de Flutter

| Recurso | Dimensiones / formato | Uso observado | Evaluación STORE-02B |
|---|---:|---|---|
| `app/assets/branding/foloo_logo_light_v1.png` | 2452×971, PNG RGBA | Logo oscuro + lima con tagline sobre fondo claro | Recurso Foloo real en uso. Aprobación final de marca no consta en el repo. |
| `app/assets/branding/foloo_logo_light_v2.png` | 2443×780, PNG RGBA | Logo sin tagline sobre fondo claro | Recurso Foloo real en uso. Aprobación final pendiente. |
| `app/assets/branding/foloo_logo_dark_v1.png` | 2540×1005, PNG RGBA | Variante clara + lima con tagline sobre fondo oscuro | Recurso Foloo real en uso. Aprobación final pendiente. |
| `app/assets/branding/foloo_logo_dark_v2.png` | 2530×808, PNG RGBA | Variante sin tagline sobre fondo oscuro | Recurso Foloo real en uso. Aprobación final pendiente. |
| `app/assets/branding/foloo_mark_light.png` | 1500×1500, PNG RGB | Símbolo lima sobre fondo claro | Candidato de origen para un icono, no un icono de tienda aprobado. |
| `app/assets/branding/foloo_mark_dark.png` | 1500×1500, PNG RGB | Símbolo lima sobre fondo oscuro | Candidato de origen para variante oscura, no un icono aprobado. |

`app/lib/theme/brand_theme.dart` centraliza las cuatro variantes de logo. Las
pantallas de Login, perfil, origen, headers, drawer, onboarding de correo y
confirmación consumen esos assets. El par `foloo_mark_*` no está registrado en
`FolooBrand`; se usa directamente donde corresponde. No hay archivo vectorial,
manual de marca, grid, safe area, derechos/cesión ni fuente maestra versionada.

### Iconos instalables

| Plataforma | Evidencia | Estado |
|---|---|---|
| iOS/iPadOS | `AppIcon.appiconset`: 15 PNG + `Contents.json`, incluidos 1024×1024 y variantes 20/29/40/60/76/83.5 pt | **Placeholder**: todos muestran el logo azul predeterminado de Flutter. El 1024×1024 no tiene alpha, pero la identidad es incorrecta. |
| Android | `mipmap-mdpi`…`mipmap-xxxhdpi`: cinco PNG legacy de 48, 72, 96, 144 y 192 px | **Placeholder**: icono Flutter. No hay adaptive icon, foreground/background ni monochrome icon. |
| Google Play | No existe gráfico 512×512 separado | **Faltante**. El launcher icon no sustituye automáticamente el asset de Play. |

No se propone un logotipo nuevo. CBQA debe aprobar si el símbolo `oo` será la
base del icono y entregar o autorizar una composición maestra. Solo después se
generarán derivados Apple/Android/Play sin editar silenciosamente la marca.

### Splash / launch

| Plataforma | Evidencia | Estado |
|---|---|---|
| iOS/iPadOS | `LaunchScreen.storyboard`; `LaunchImage.imageset` contiene tres PNG transparentes de 1×1 | Template Flutter/base, sin identidad Foloo. No hay variante Dark aprobada. |
| Android | `drawable/launch_background.xml` y `drawable-v21/launch_background.xml` | Fondo blanco o color de sistema; bloque de imagen comentado. Sin artwork Foloo ni configuración SplashScreen API dedicada. |

### Recursos de ficha

No existen en el repositorio capturas de App Store/Google Play, feature graphic
de Play, app previews, video, arte promocional, captions localizados ni un
paquete versionado de metadata. La ausencia es correcta para este corte: no se
generaron imágenes ficticias ni se capturó PII.

### Clasificación final

- **Vigentes dentro del producto, final por confirmar:** seis PNG Foloo y los
  tokens `ink`, `lime`, `gray`, `fieldFill` y `danger` de `FolooBrand`.
- **Placeholders confirmados:** AppIcon iOS/iPadOS, launcher icon Android y
  launch/splash de ambas plataformas.
- **Faltantes:** master de icono aprobado, derivados instalables, adaptive y
  monochrome Android, icono Play 512, feature graphic, screenshots ES/EN y
  documentación formal de marca/licencias.

## 2. Matriz vigente de requisitos visuales

Consulta oficial: **2026-10-09**. Revalidar inmediatamente antes de STORE-04,
porque las tiendas pueden cambiar dispositivos, campos y políticas.

| Material | Apple App Store | Google Play | Estado Foloo / acción |
|---|---|---|---|
| Nombre | 2–30 caracteres, localizable | máximo 30 caracteres, localizable | Propuesta: `Foloo`; confirmar disponibilidad, marca y capitalización. |
| Icono | Fuente iOS/iPadOS 1024×1024 en asset catalog/Icon Composer; el sistema genera tamaños menores | PNG 32-bit con alpha, 512×512, máx. 1024 KB | Faltan masters Foloo aprobados. No reutilizar icono Flutter. |
| Variantes de icono | Apple contempla default/dark/clear/tinted; el sistema puede generar las no provistas | Launcher moderno requiere adaptive foreground/background; monochrome recomendado para themed icons | Diseñar desde una misma identidad aprobada y probar máscaras/contraste. |
| Screenshots de teléfono | 1–10 por localización, JPEG/JPG/PNG sin alpha. Para 6.9″ se aceptan, según dispositivo, 1260×2736, 1290×2796 o 1320×2868 en retrato | 2 mínimos en total y hasta 8 por tipo; JPEG o PNG 24-bit sin alpha; lado 320–3840 px y el mayor ≤2× el menor | Preparar 7 retratos ES y 7 EN. Para calidad/recomendación Play: 1080×1920 o superior, 9:16. |
| Screenshots tablet | 13″ requerido si el binario corre en iPad: 2064×2752 o 2048×2732 retrato | Hasta 8 por tablet 7″/10″; Google recomienda al menos 4, 1080–7680 px y 9:16/16:9 | Foloo declara iPhone+iPad (`TARGETED_DEVICE_FAMILY=1,2`): falta set iPad ES/EN y QA real. Para Play tablet, decidir soporte tras QA large-screen. |
| Feature graphic | No equivale a un requisito base de ficha iOS | Obligatorio: JPEG o PNG 24-bit sin alpha, 1024×500 | Faltante; requiere composición aprobada, sin precio/ranking/store badges. |
| Video/app preview | Opcional; hasta 3 por tamaño/localización | Opcional, una URL de YouTube; feature graphic funciona como portada | Diferido; no producir hasta tener RC estable. |
| Texto promocional | Máx. 170 caracteres | No hay campo equivalente; short description cumple otra función | Propuesta ES/EN abajo. |
| Subtítulo / descripción corta | Subtítulo máximo 30 caracteres | Descripción corta máxima 80 caracteres | Propuestas distintas y dentro de límite. |
| Descripción completa | Texto plano, máximo 4000 caracteres | Máximo 4000 caracteres | Borradores ES/EN abajo, sin HTML ni promesas pendientes. |
| Keywords | Máximo 100 bytes; no repetir nombre/empresa ni marcas ajenas | Sin campo keywords; no hacer keyword stuffing en descripción | Propuestas Apple ES/EN abajo. |
| Localización | Metadata y screenshots por idioma | Listing y gráficos localizables; alt text recomendado | Preparar ES y EN como sets completos, no mezclar captions. |

Plan de producción recomendado, una vez autorizado: mantener fuentes maestras
sin PII fuera de los exports, exportar assets finales sin alpha donde la tienda
lo exige, conservar el color lima sin pérdida visible y validar cada archivo por
dimensiones, alpha, perfil de color, peso y legibilidad antes de cargarlo.

## 3. Propuesta de ficha — Español

Todo el copy es **borrador sujeto a aprobación de Producto/Legal/Marketing**.

| Campo | Propuesta | Límite comprobado |
|---|---|---:|
| Nombre | **Foloo** | 5/30 |
| Subtítulo App Store | **Captura y sigue tus leads** | 25/30 |
| Descripción corta Play | **Captura, organiza y da seguimiento a tus leads, incluso sin conexión** | 68/80 caracteres (69 bytes UTF-8) |
| Texto promocional Apple | **Convierte cada conversación en un seguimiento claro: captura leads, organiza eventos, comparte contenido y prepara correos desde Foloo.** | 135/170 caracteres |
| Keywords Apple | `leads,eventos,contactos,ventas,seguimiento,tarjetas,OCR,correo,PDF,offline` | 74/100 bytes |
| Categoría primaria propuesta | **Negocios / Business** | Confirmar CBQA |
| Categoría secundaria Apple propuesta | **Productividad / Productivity** | Confirmar CBQA |

### Descripción completa propuesta

Foloo ayuda a vendedores y equipos de campo a convertir conversaciones en
seguimientos organizados, desde la captura inicial hasta el correo revisado por
la persona usuaria.

CAPTURA EN EL MOMENTO

- Registra leads de un evento o conversaciones directas.
- Captura una tarjeta y usa OCR en el dispositivo como apoyo para completar los
  datos, o captura todo manualmente.
- Añade una nota escrita, una nota de voz y hasta tres imágenes de referencia.

ORGANIZA Y CONSULTA

- Agrupa leads por evento y consulta registros, filtros, estados y detalles.
- Corrige datos estructurados sin perder el registro original de captura.
- Exporta registros por evento o leads directos en XLSX o CSV.

COMPARTE CONTENIDO Y DA SEGUIMIENTO

- Conserva una biblioteca privada de documentos PDF y relaciónalos con eventos
  o leads directos.
- Personaliza plantillas en español e inglés.
- Revisa destinatario, asunto, mensaje y archivos antes de confirmar cada
  seguimiento.
- Conecta Google o una cuenta personal Microsoft compatible, como Outlook o
  Hotmail, para enviar desde una cuenta autorizada. Las cuentas Microsoft
  empresariales o educativas no están soportadas en esta versión.

TRABAJA CON O SIN CONEXIÓN

Foloo guarda primero en el dispositivo. La captura, los registros, el contenido
y las plantillas siguen disponibles sin conexión, y la sincronización continúa
cuando vuelve la red. Cada cuenta mantiene sus datos separados.

Disponible en español e inglés, con apariencia clara y oscura.

### Nota interna de publicación

La descripción omite precio, compra y suscripción porque FL-021 está pausada y
`D-01`–`D-04` siguen abiertas. Antes de publicar, Producto/Legal debe definir si
la ficha necesita explicar el límite de cinco Leads y sus términos; no se puede
publicar una promesa de acceso ilimitado ni un mecanismo de compra inexistente.

## 4. Proposed listing — English

All copy is a **draft pending Product/Legal/Marketing approval**.

| Field | Proposal | Checked limit |
|---|---|---:|
| Name | **Foloo** | 5/30 |
| App Store subtitle | **Capture and follow up leads** | 27/30 |
| Play short description | **Capture, organize, and follow up with leads, even when offline** | 62/80 characters |
| Apple promotional text | **Turn every conversation into clear follow-up: capture leads, organize events, share content, and prepare emails from Foloo.** | 123/170 characters |
| Apple keywords | `leads,events,contacts,sales,follow-up,business cards,OCR,email,PDF,offline` | 74/100 bytes |
| Proposed primary category | **Business** | CBQA confirmation required |
| Proposed Apple secondary category | **Productivity** | CBQA confirmation required |

### Proposed full description

Foloo helps salespeople and field teams turn conversations into organized
follow-up, from the first capture to an email reviewed by the user.

CAPTURE IN THE MOMENT

- Save leads from an event or a direct conversation.
- Capture a business card and use on-device OCR to help fill in details, or
  enter everything manually.
- Add a written note, a voice note, and up to three reference images.

ORGANIZE AND REVIEW

- Group leads by event and browse records, filters, statuses, and details.
- Correct structured details without losing the original capture record.
- Export event records or direct leads as XLSX or CSV.

SHARE CONTENT AND FOLLOW UP

- Keep a private PDF library and associate documents with events or direct
  leads.
- Customize templates in English and Spanish.
- Review the recipient, subject, message, and files before confirming each
  follow-up.
- Connect Google or a compatible personal Microsoft account, such as Outlook
  or Hotmail, to send from an authorized account. Business and educational
  Microsoft accounts are not supported in this version.

WORK ONLINE OR OFFLINE

Foloo saves to the device first. Capture, records, content, and templates remain
available offline, and synchronization continues when connectivity returns.
Each account keeps its data separate.

Available in English and Spanish, with light and dark appearances.

### Internal release note

The description intentionally omits price, purchase, and subscription claims
while FL-021 is paused and `D-01`–`D-04` remain open. Product/Legal must decide
how to disclose the five-lead limit and its terms before publication. The
listing must not imply unlimited creation or a purchase flow that does not
exist.

## 5. Plan de capturas

### Secuencia recomendada

La primera imagen debe mostrar valor, no una pantalla de acceso. Se recomiendan
los mismos siete momentos en sets separados ES/EN:

| Orden | Pantalla/estado real | Caption ES | Caption EN | Evidencia funcional |
|---:|---|---|---|---|
| 1 | Captura con datos de tarjeta ya revisables | **Captura cada oportunidad** | **Capture every opportunity** | `CAP-*`, `OCR-*`, E-03/E-04 |
| 2 | Captura con nota/voz/imágenes, sin datos sensibles | **Añade el contexto que importa** | **Keep the context that matters** | `VOZ-*`, `CAP-07/08` |
| 3 | Mis eventos con activo/futuros/pasados | **Organiza por evento** | **Stay organized by event** | `EVT-*`, E-02 |
| 4 | Registros con búsqueda/filtros/estado | **Encuentra y exporta tus leads** | **Find and export your leads** | `REG-*`, E-06/E-10 |
| 5 | Contenido con PDF demo y asignación | **Comparte el contenido correcto** | **Share the right content** | `CON-*`, E-07 |
| 6 | Revisar correo antes de confirmar | **Revisa antes de enviar** | **Review before you send** | `PLT-*`, `SAL-*`, E-08 |
| 7 | Login vigente con Google y email/password | **Tu trabajo, en tu cuenta** | **Your work, in your account** | `AUT-*`, E-01 |

El beneficio offline puede mostrarse en las capturas 1 o 4 con el indicador real
de Foloo, sin simular éxito remoto. No mostrar Microsoft Sign-In en Login porque
`AUT-17` lo deja fuera; una pantalla de sender Microsoft solo puede usar el
alcance personal descrito en `SAL-06`.

### Datos y producción

- Crear un owner y dataset **exclusivos de marketing**, con nombres, empresas,
  emails, teléfonos, eventos, notas y PDFs ficticios aprobados; nunca reutilizar
  cuentas TestFlight personales, clientes o Leads reales.
- Usar dominios y documentos demo que no puedan disparar un correo real. No
  mostrar tokens, IDs, object keys, rutas locales, errores técnicos ni URLs
  temporales.
- Capturar estados reales del RC, sin dibujar funciones inexistentes ni alterar
  conteos. Si se agregan captions, la UI debe seguir dominando la imagen.
- Producir ES y EN de forma independiente; captions, UI y archivos demo deben
  corresponder al idioma del set.
- Limpiar notificaciones y operador; usar hora/batería consistentes. Evitar
  transparencias, compresión visible, marcos de dispositivo obsoletos y PII.
- Validar Light y Dark internamente, pero elegir un tratamiento coherente por
  secuencia. Se puede preparar una segunda variante solo con aprobación.
- iOS: capturar el tamaño aceptado de 6.9″ y un iPad 13″ porque el target actual
  incluye iPad. Android: producir al menos cuatro retratos 1080×1920 para calidad
  de recomendación; el set propuesto de siete cumple el conteo.
- No se generaron capturas en STORE-02B y no se abrieron simuladores/emuladores.

### Alt text sugerido para Google Play

Cada texto debe localizarse y mantenerse ≤140 caracteres. Base ES: “Formulario
de captura de Foloo con datos editables y opciones de nota”; base EN: “Foloo
lead capture form with editable details and note options”. Preparar uno específico
por imagen al producir el set, en vez de repetir una descripción genérica.

## 6. Recursos faltantes y responsables

| Prioridad | Recurso | Criterio de listo | Responsable propuesto |
|---|---|---|---|
| P0 | Aprobación formal de marca/logo | Fuente maestra, usos permitidos, colores, clear space y aprobación escrita | CBQA/Marketing/Legal |
| P0 | Icono maestro Foloo | 1024×1024, legible bajo máscaras y aprobado; sin logo Flutter | Diseño + Producto |
| P0 | Derivados Apple | Asset catalog/Icon Composer, variantes requeridas, sin bordes pre-redondeados | Diseño + iOS |
| P0 | Derivados Android | Adaptive foreground/background, legacy fallbacks y monochrome | Diseño + Android |
| P0 | Icono Google Play | PNG 32-bit 512×512 ≤1024 KB | Diseño |
| P0 | Feature graphic Play | 1024×500 JPEG/PNG sin alpha, focal point seguro, ES/EN si lleva texto | Diseño/Marketing |
| P0 | Screenshots ES/EN | 7 teléfono por idioma; iPad por soporte actual; sin PII | QA + Diseño/Marketing |
| P1 | Splash Foloo | Diseño aprobado Light/Dark y especificación nativa; no animación prometida | Diseño + mobile |
| P1 | Metadata aprobada | Copy ES/EN, categoría, keywords, captions y alt text firmados | Producto/Marketing/Legal |
| P1 | Sitio/soporte/privacidad | URLs públicas y contactos reales | CBQA/Legal/TI |
| P2 | App preview/video | Solo si existe RC estable y guion aprobado | Marketing/QA |

## 7. Información pendiente de CBQA Solutions

No se inventan valores. Cada campo debe entregarse o aprobarse antes de cargar
la ficha.

| Dato | Estado | Confirmación requerida |
|---|---|---|
| Nombre comercial | Parcial | Aprobar `Foloo` y su uso/registro en ambos storefronts. |
| Nombre legal del vendedor | Pendiente exacto | Conciliar “CBQA Solutions” con el seller de App Store Connect (`Cbqa Solutions Mexico, S.C` apareció en evidencia local) y la entidad de Play. |
| Sitio web corporativo | Pendiente | URL pública real; no se propone una. |
| URL de soporte | Pendiente crítico | Página pública con contacto real; Apple exige URL completa. |
| Correo de soporte | Pendiente crítico | Buzón corporativo atendido y SLA/owner. |
| URL de privacidad | Pendiente crítico | Política aprobada y pública, coherente con App Privacy/Data Safety. |
| Términos y eliminación de cuenta | Pendiente crítico | URLs/proceso coherentes con STORE-01 y D-13. |
| Copyright | Pendiente | Año y razón social exacta aprobados. |
| Categorías | Propuesta | Business primaria y Productivity secundaria Apple; aprobar ambas. |
| Países/regiones | Pendiente | Lista de lanzamiento, restricciones legales y soporte disponible. |
| Idioma primario | Pendiente | Recomendada decisión entre ES-MX y EN; ambos listings se preparan. |
| Idiomas publicados | Propuesta | Español e inglés, sujetos a QA completo de metadata y screenshots. |
| Audiencia/clasificación | Pendiente | Completar cuestionarios Apple/Play con Legal/Producto; no asumir edad. |
| Contacto de App Review | Pendiente | Nombre, teléfono, email y cuenta demo estable. |
| Google Play Console | Parcial / pendiente externo | Organization CBQA confirmada e invitación enviada; Israel/TI deben resolver acceso corporativo, owner/roles y verificaciones de identidad, sitio/teléfono. No crear otra cuenta. |
| Pricing/trial | Bloqueado | Resolver `D-01`–`D-04`/FL-021 antes de copy comercial o submission. |

## 8. Checklist de carga futura

### Antes de producir assets

- [ ] CBQA aprueba marca, icono base, paleta, tipografía y derechos.
- [ ] Se cierran o separan todos los P0 de `store-readiness.md`.
- [ ] Producto congela las funcionalidades que sí aparecerán en la ficha.
- [ ] FL-021 y la comunicación del trial tienen decisión aprobada.
- [ ] Se valida soporte iPad/large screen o se aprueba una decisión técnica
      separada; STORE-02B no cambia device families.
- [ ] Existe dataset de marketing sintético y owner aislado.

### Producción y QA

- [ ] Exportar iconos Apple, Android y Play desde la misma fuente aprobada.
- [ ] Validar tamaño, formato, alpha, peso, perfil de color, máscara y contraste.
- [ ] Probar icono/launch en Light/Dark y tamaños mínimos, sin reemplazar antes
      de aprobación.
- [ ] Capturar el RC real en ES y EN, teléfono y tablet requeridos.
- [ ] Confirmar que cada captura coincide con el build y no contiene PII.
- [ ] Revisar ortografía, captions, alt text, estados offline y claims.
- [ ] Exportar feature graphic sin precio, ranking, badge o marca ajena.

### Metadata y consola

- [ ] Confirmar nombre disponible, categoría, idioma primario y regiones.
- [ ] Cargar name/subtitle-or-short/full description/keywords correctos por
      plataforma y localización.
- [ ] Cargar soporte, marketing y privacidad con URLs verificadas.
- [ ] Completar age/content rating con respuestas aprobadas.
- [ ] Completar App Privacy y Data Safety desde el inventario verificado.
- [ ] Proveer review notes, cuenta demo y contacto de revisión.
- [ ] Revalidar dimensiones y límites en documentación oficial el día de carga.
- [ ] Hacer revisión de cuatro ojos y conservar evidencia de aprobación.
- [ ] No pulsar Submit/Publish sin autorización explícita de STORE-04.

## Fuentes oficiales

Consulta: **2026-10-09**.

- Apple: [App information y límites de nombre/subtítulo/privacidad](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information),
  [platform version information y límites de metadata](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information),
  [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/),
  [upload previews/screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/),
  [app icons HIG](https://developer.apple.com/design/human-interface-guidelines/app-icons/),
  [asset catalog de iconos](https://developer.apple.com/documentation/xcode/configuring-your-app-icon),
  [categorías](https://developer.apple.com/app-store/categories/).
- Google Play: [crear y configurar la ficha](https://support.google.com/googleplay/android-developer/answer/9859152),
  [preview assets, icono, feature graphic y screenshots](https://support.google.com/googleplay/android-developer/answer/9866151),
  [buenas prácticas de store listing](https://support.google.com/googleplay/android-developer/answer/13393723),
  [metadata policy](https://support.google.com/googleplay/android-developer/answer/9898842).

## Validación de STORE-02B

- Se revisaron SDD, STORE-01, configuración Flutter/iOS/Android, 6 assets de
  marca, 15 PNG AppIcon iOS/iPadOS, 5 launcher icons Android, launch assets y
  8 pantallas representativas.
- Se inspeccionaron dimensiones, alpha, uso en código, placeholders y soporte
  iPhone/iPad.
- Se verificaron límites contra fuentes oficiales vigentes y se contaron los
  campos propuestos.
- No se modificó Flutter, backend, pagos, iconos ni splash; no se ejecutó la
  aplicación, simulador/emulador, build, publicación ni consola de tienda.
