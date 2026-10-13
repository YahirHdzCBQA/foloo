# STORE-02C — Privacidad, protección de datos y cumplimiento de tiendas

**Estado:** especificación técnica preliminar, 2026-10-09. No constituye
asesoría legal, no autoriza llenar formularios de tienda y no resuelve `D-13`.

Esta es la fuente operativa consolidada de STORE-02C. Complementa, sin
duplicar, la auditoría general de [`store-readiness.md`](store-readiness.md) y
los materiales de [`store-listing-materials.md`](store-listing-materials.md).
Su alcance se traza a `AUT-*`, `CAP-*`, `OCR-*`, `VOZ-*`, `SYN-*`, `REG-*`,
`CON-*`, `PLT-*`, `SAL-*`, `MON-*`, `INF-*`, `RNF-*`, `RC-*`, `REL-*`, E-01,
E-03–E-13 y ADR-001–007.

## 1. Método, alcance y nivel de certeza

Se inspeccionaron Flutter, Drift, el filesystem privado, Amplify/Cognito,
sincronización/outbox, API Gateway/Lambda, PostgreSQL, S3, OAuth de sender,
KMS/Secrets Manager, CloudWatch, manifests iOS/Android y dependencias. Las
matrices se basan en el comportamiento actual del repositorio; las prácticas
operativas de producción y contratos con proveedores requieren evidencia
externa de CBQA.

- **C — confirmado:** demostrado por código, IaC, SDD o configuración
  versionada.
- **P — pendiente:** depende de `D-13`, Legal, Producto, operación PROD,
  contratos o un Privacy Report/artefacto Release aún no producido.
- **No presente:** no se encontró implementación. No equivale a promesa futura.

Apple considera “recopilado” el dato transmitido fuera del dispositivo y
accesible más allá de lo necesario para atender la solicitud en tiempo real.
Google considera “recopilado” cualquier dato enviado fuera del dispositivo,
incluso si el procesamiento es efímero; sus excepciones de “compartido” para
encargados de tratamiento y acciones iniciadas por la persona usuaria no
cambian el hecho de que pueda ser “recopilado”. Por ello las dos matrices no
son intercambiables.

## 2. Inventario de datos personales

### 2.1 Contenido, finalidad, origen y ubicación

| Categoría | Datos y origen | Finalidad | Local | Remoto | Certeza |
|---|---|---|---|---|---|
| Cuenta e identidad | Email, `sub`, username técnico, proveedor, estado de sesión; entregados por la persona usuaria/Cognito/Google | Alta, verificación, autenticación y ownership | Tokens en secure storage de Amplify; identidad activa en memoria; no tokens en Drift | Cognito; API recibe JWT y usa `sub` | C |
| Perfil vendedor | Nombre, empresa y foto opcional ingresados/seleccionados por el vendedor | Identidad dentro de Foloo y firma | Nombre/empresa en Drift; foto en directorio privado y ruta owner-scoped | Nombre/empresa en PostgreSQL. El backend admite position/phone/photo URL, pero el cliente actual no los sincroniza | C |
| Eventos | Nombre, inicio, fin, activo y asociaciones | Organizar captura/contenido | Drift | PostgreSQL | C |
| Leads/contactos de terceros | Nombre, apellido, puesto, empresa, email, teléfono, tipo, interés, origen, lugar, nota, fecha, capturó, evento, folio | Registro, consulta, exportación y seguimiento | Drift | PostgreSQL | C |
| Tarjeta e imágenes | Tarjeta y hasta tres referencias; cámara/galería. OCR deriva texto del dispositivo | Evidencia/contexto y ayuda de captura | JPEG normalizado en directorio privado + metadata Drift | S3 privado + metadata PostgreSQL | C |
| OCR | Píxeles temporales y texto reconocido | Prellenar campos para revisión humana | Procesamiento ML Kit local; el resultado aceptado se convierte en Lead | No se encontró envío de la imagen a un OCR remoto; el Lead/imagen sí sincroniza por sus flujos normales | C; confirmar SDK en artefacto Release |
| Voice Note | Audio M4A, duración y metadata, grabado por el vendedor | Recordatorio/reproducción | Directorio privado + Drift | S3 privado + PostgreSQL | C |
| PDF/Content | PDF, nombre real/visible, tamaño, hash, asignaciones y selecciones congeladas | Biblioteca y adjuntos de seguimiento | Copia privada + Drift | S3 privado + PostgreSQL | C |
| Plantillas y correo | Asunto, cuerpo, firma, idioma, destinatario, adjuntos, intentos, estados, error técnico, sender y provider message ID | Preparar, confirmar, enviar y mostrar historial | Drift guarda templates, snapshot HTML/plain, destinatario e intención | PostgreSQL; Gmail API o Microsoft Graph reciben el mensaje y adjuntos confirmados | C |
| OAuth de sender | Provider subject, sender address, state hash, PKCE cifrado temporal, access/refresh tokens cifrados, key ID y estado | Autorizar envío desde cuenta elegida | Flutter no recibe/persiste tokens sender; solo estado seguro de conexión | PostgreSQL cifrado con KMS; secretos de cliente en Secrets Manager; provider Lambda | C |
| Sincronización | IDs lógicos, owner, entidad/acción, payload, idempotency key, revisiones, intentos, errores, fechas | Offline-first, retry, deduplicación y reconciliación | Outbox Drift | Idempotency records, revisiones y timestamps PostgreSQL | C |
| Trial/entitlement | Estado `trial/trial_exhausted/active/expired`, leads usados, reservas locales y timestamps | Limitar solo creación de nuevos Leads | Cache/reservas Drift owner-scoped | Cuenta PostgreSQL; sin compra, recibo ni dato financiero en FL-020 | C |
| Preferencias | Idioma, apariencia y rutas owner-scoped; conectividad observada | UX y operación local | Drift | No se encontró sync de idioma/apariencia | C |
| Exportaciones | Las 13 columnas REG-09–REG-13 elegidas por evento o Lead directo | Exportar XLSX/CSV y compartir | Archivo temporal eliminado al cerrar share sheet; el destino elegido queda fuera de Foloo | No pasa por backend Foloo | C |
| Logs/diagnóstico | Request ID, route, status, duración, tipo/código de error; en debug IDs lógicos/operaciones sync y error social sanitizado | Soporte, seguridad y diagnóstico | Consola debug; no SDK de crash/analytics configurado | CloudWatch para Lambda/API/DB/provider | C para campos; P para política PROD |

El email, teléfono, imágenes, voz y notas de un Lead son datos de **terceras
personas** capturados por el vendedor. CBQA debe definir base jurídica,
información al titular, rol controlador/encargado y reglas de prospección; el
hecho de que el vendedor los introduzca no elimina esa obligación.

### 2.2 Servicios, acceso, transferencias, eliminación y retención

| Categoría | Servicios y acceso | Transferencias | Eliminación actual | Retención | Evidencia / riesgo principal |
|---|---|---|---|---|---|
| Cuenta | Cognito/Amplify; el `sub` delimita owner/workspace | Dispositivo↔Cognito y JWT↔API AWS | Solo logout; no `DeleteUser`/AdminDeleteUser ni UI/API de cuenta | P (`D-13`) | `cognito_auth_service.dart`, ADR-002. Riesgo P0 de tienda |
| Perfil | Solo owner autenticado; backend workspace-scoped | App↔API/RDS | No borrado de perfil/cuenta | P | `LocalProfiles`, `seller_profiles`; foto local no entra en cleanup de cuenta |
| Eventos | Owner/workspace | App↔API/RDS | Tombstone; conserva Leads y relaciones | Física P | `EventRepository`, `deleteEvent`; no equivale a borrar cuenta |
| Leads | Owner/workspace; destinatario recibe únicamente correo confirmado | App↔API/RDS; export user-initiated | Tombstone local/remoto; media no se elimina físicamente | Física P | `LocalLeads.deletedAt`, `leads.deleted_at`; datos ocultos siguen almacenados |
| Imágenes/voz | Owner mediante URL firmada temporal; AWS como encargado | PUT/GET directo S3 por URL temporal | No hay borrado postguardado; borrar Lead no ejecuta `DeleteObject` | P (`D-05`, `D-06`, `D-13`) | ADR-005, bucket `RETAIN`; riesgo de objetos huérfanos |
| PDFs | Owner mediante URL firmada; adjunto se comparte solo tras confirmación | S3; Gmail/Graph y destinatario si se envía | Content usa tombstone; no `DeleteObject`; copia local se conserva | P (`D-13`) | `ContentRepository.delete`, ADR-005 |
| Email | Owner; proveedor y destinatario reciben contenido/adjuntos | API/provider Lambda→Google/Microsoft→destinatario | Historial/intenciones no se borran; desconexión solo marca estado | P; opt-out histórico no es flujo activo | migraciones 004–006/ADR-006/007; marketing/base legal abierta |
| Tokens sender | Solo backend/provider Lambda; cifrado KMS | OAuth endpoints/provider APIs | Desconectar marca `disconnected`; no se encontró revocación remota ni borrado de ciphertext | P | `PostgresEmailRepository.disconnect`; riesgo de credencial retenida |
| Sync | Owner local y workspace remoto | App↔API | Tombstones se preservan para anti-resurrección; no existe barrera de cuenta | Idempotencia 7 días; resto P | migration 001 confirma 7 días solo para idempotencia |
| Trial | Owner/account | App↔API/RDS | Borrar Lead no devuelve cupo; no eliminación de cuenta | P | migration 007, `LocalTrialReservations` |
| Logs | Personal autorizado de AWS/CBQA según roles aún por auditar | Servicios AWS/CloudWatch | Log groups DEV: 1 semana y DESTROY; snapshots/RDS separados | DEV C=1 semana; PROD P | IaC. Request/route sin body; debug contiene IDs técnicos locales |
| Export | Persona usuaria y app receptora elegida | Share sheet user-initiated | Temporal Foloo se elimina; copia del receptor no controlada por Foloo | Receptor/OS | `DeviceRecordsFileSharer`; advertir al usuario sobre destino |

Infraestructura confirmada: S3 bloquea acceso público, usa SSE-S3 y TLS; RDS
está cifrado, privado y con backup DEV de un día; tokens sender se cifran con
KMS; sesiones Cognito usan almacenamiento seguro Amplify. No hay cifrado
adicional de SQLite/media local más allá del sandbox/protección del sistema
operativo (ADR-001): Legal/Seguridad deben decidir si es suficiente en `D-13`.

No se encontró SDK de publicidad, ATT, IDFA, Firebase Analytics, Sentry ni
plugin Analytics registrado en Amplify. `amplify_analytics_pinpoint` aparece
como dependencia transitiva en el lockfile, pero el runtime agrega únicamente
`AmplifyAuthCognito`; esto debe reconfirmarse con el Privacy Report del archive
Release y el inventario SBOM antes de declarar “sin tracking”.

## 3. Matriz preliminar Apple App Privacy

No cargar esta tabla en App Store Connect hasta que Legal/Producto validen
finalidad, proveedores y comportamiento del RC. Casi todos los datos remotos se
vinculan al `sub`/workspace; “no tracking” es una conclusión técnica
preliminar, no una declaración publicada.

| Tipo Apple propuesto | Ejemplos Foloo | Recopilado | Vinculado | Finalidad propuesta | Necesario/opcional | Tracking |
|---|---|---|---|---|---|---|
| Contact Info — Name | vendedor y Lead | Sí | Sí | App Functionality / Account Management | vendedor requerido; Lead requerido | No evidenciado |
| Contact Info — Email Address | cuenta, Lead, sender/destinatario | Sí | Sí | App Functionality / Account Management | cuenta requerida; Lead puede usar teléfono; sender opcional | No evidenciado |
| Contact Info — Phone Number | Lead; profile backend futuro no enviado hoy | Sí para Lead | Sí | App Functionality | opcional si hay email | No evidenciado |
| Contact Info — Other User Contact Info | empresa, puesto, lugar | Sí | Sí | App Functionality | mixto | No evidenciado |
| User Content — Photos or Videos | tarjeta, referencias; foto de perfil solo local hoy | Sí para media sincronizada | Sí | App Functionality | opcional | No evidenciado |
| User Content — Audio Data | Voice Note | Sí | Sí | App Functionality | opcional | No evidenciado |
| User Content — Emails or Text Messages | follow-up, asunto, cuerpo, firma, destinatario | Sí | Sí | App Functionality | opcional hasta confirmar envío | No evidenciado |
| User Content — Other User Content | notas, PDFs, nombres de archivo, plantillas | Sí | Sí | App Functionality | opcional | No evidenciado |
| Identifiers — User ID | Cognito `sub`, account/workspace y IDs owner-scoped | Sí | Sí | App Functionality / Account Management / Security | requerido | No evidenciado |
| Usage Data — Product Interaction | sync/intentos/trial y acciones de correo | Posible Sí | Sí | App Functionality / Security | requerido para funciones usadas | No evidenciado |
| Diagnostics — Other Diagnostic Data | route/status/duración/error/request ID | Sí | Potencialmente; request ID correlacionable | App Functionality / Security | requerido operacionalmente | No evidenciado |

No hay evidencia actual de Health, Fitness, Location, Contacts address book,
Browsing History, Advertising Data, Purchases/payment information ni Device ID.
El nombre de Evento no es calendario del sistema. Google OAuth y Gmail/Graph
son servicios distintos: el primero autentica o autoriza; el segundo recibe el
correo que el vendedor confirma.

Validaciones antes de publicar App Privacy:

1. decidir con Legal si empresa/puesto/lugar se declaran como Other User
   Contact Info, Other User Content o ambos según el formulario vigente;
2. confirmar si logs PROD se enlazan o desidentifican y su finalidad;
3. revisar Privacy Report, manifests y políticas de todos los SDKs Release;
4. confirmar rol y contratos/DPA de AWS, Google y Microsoft, transferencias
   internacionales y subencargados;
5. confirmar que no existe analytics operativo fuera del repositorio;
6. publicar Privacy Policy URL y una ruta accesible dentro de la app;
7. actualizar la declaración si FL-021 incorpora compras/receipts.

## 4. Matriz preliminar Google Play Data Safety

Google exige declarar datos enviados fuera del dispositivo; datos solo locales
como la foto de perfil actual no se declaran como “collected” por ese hecho
aislado. AWS puede calificar como service provider y una entrega explícita a un
destinatario puede entrar en la excepción de “shared”, pero Legal debe validar
los contratos y la experiencia concreta antes de responder “not shared”.

| Tipo Google propuesto | Recopilado | ¿Compartido? preliminar | Finalidad | Opcionalidad | Cifrado en tránsito | Eliminación hoy |
|---|---|---|---|---|---|---|
| Personal info — Name | Sí | No si AWS es encargado; revisar envío de firma | App functionality / Account management | vendedor requerido; Lead requerido | HTTPS/TLS | No integral |
| Personal info — Email address | Sí | OAuth/proveedor/destinatario: revisar excepciones | Account management / App functionality | cuenta requerida; sender/Lead condicional | Sí | No integral |
| Personal info — Phone number | Sí para Lead | No preliminar | App functionality | opcional si email | Sí | Tombstone de Lead |
| Personal info — User IDs | Sí | No preliminar | Account management / Security | requerido | Sí | No integral |
| Personal info — Address/Other info | No dirección postal estructurada; lugar/empresa/puesto requieren clasificación final | P | App functionality | mixto | Sí | Tombstone de Lead/Event |
| Messages — Emails | Sí | Proveedor/destinatario por acción explícita; validar excepción | App functionality | opcional | Sí hasta proveedor; entrega final depende de email | No integral |
| Photos and videos — Photos | Sí | No preliminar | App functionality | opcional | Sí | Sin físico |
| Audio files — Voice or sound recordings | Sí | No preliminar | App functionality | opcional | Sí | Sin físico |
| Files and docs | Sí | Proveedor/destinatario por acción explícita; validar | App functionality | opcional | Sí | Tombstone, sin físico |
| Other user-generated content | Sí: notas, templates, eventos | No preliminar | App functionality | mixto | Sí | Parcial/tombstone |
| App activity — App interactions/Other actions | Sí: sync, envío, trial | No preliminar | App functionality / Security | necesario al usar función | Sí | No integral |
| App info and performance — Diagnostics | Sí: errores, estados, duración | No preliminar | App functionality / Security | operativo | Sí | CloudWatch DEV 1 semana |

Estado de respuestas globales:

- **Data collected:** sí.
- **Data shared:** pendiente de validación contractual y de las excepciones de
  service provider/user-initiated; no debe responderse todavía.
- **Encrypted in transit:** la ruta Foloo usa HTTPS/TLS y S3 signed HTTPS; se
  debe confirmar el 100 % del artefacto y proveedores antes de marcar “sí”.
- **Deletion mechanism:** no cumple hoy; faltan ruta in-app y recurso web.
- **Ephemeral:** no aplicar a los datos persistidos. OAuth state temporal sí
  expira, pero los tokens/conexión resultantes persisten.
- **Optional/required:** usar la columna anterior; Google exige “required” si
  lo es para cualquier usuario/version activa.

## 5. Estado de borrados actuales

| Acción | Efecto actual | No hace |
|---|---|---|
| Eliminar Lead | Oculta y sincroniza tombstone con revisión; no devuelve trial | No borra media local/S3, correo histórico ni cuenta |
| Eliminar Evento | Tombstone; preserva Leads y relaciones | No borra Leads, Content ni cuenta |
| Eliminar Content | Tombstone y anti-resurrección de metadata | No borra PDF local ni objeto S3 (`D-13`) |
| Desconectar correo | Marca conexión `disconnected` | No prueba revocación provider ni borra ciphertext/historial |
| Logout | Cierra Cognito y cambia AuthState | No borra Drift, media, S3, PostgreSQL ni cuenta |
| Eliminar cuenta | **No existe** | No hay UI, API, job, web resource, receipt ni `DeleteUser` |

Los tombstones son correctos para sincronización de entidades, pero no
satisfacen por sí solos la eliminación integral exigida por Apple/Google.

## 6. Propuesta técnica para `D-13` — sin aprobar

### 6.1 Flujo recomendado

1. **Descubrimiento:** Ajustes/Cuenta muestra “Eliminar cuenta” y explica que
   no es logout ni borrar un Lead. Debe existir ES/EN y accesibilidad.
2. **Consecuencias:** resumen de cuenta, perfil, Leads/Eventos, media, PDFs,
   emails, conexiones, otros dispositivos, trial/suscripción y cualquier dato
   legalmente retenido. No prometer plazo hasta que Legal lo defina.
3. **Reautenticación reciente:** contraseña/código para cuenta local y flujo
   apropiado del proveedor federado. No aceptar solo presencia de sesión vieja.
4. **Confirmación explícita:** acción destructiva final, idempotency key y
   consentimiento inequívoco. Si no hay red, no afirmar que la solicitud fue
   recibida; mantenerla como borrador local visible hasta envío autenticado.
5. **Aceptación server-side:** endpoint owner-scoped crea una solicitud con
   estados `requested → in_progress → completed|blocked`, timestamp y receipt.
   En una transacción coloca account/workspace en `deletion_pending` y bloquea
   nuevas escrituras, nuevos OAuth y consumo del outbox.
6. **Barrera anti-resurrección:** todos los endpoints y sync rechazan el owner
   en eliminación con un código estable. Otros dispositivos cancelan push,
   descartan outbox owner-scoped y limpian local al observar la barrera; ningún
   pull puede recrear filas.
7. **Revocación:** desconectar/revocar sender donde el proveedor lo soporte,
   eliminar credenciales OAuth cifradas, state/PKCE y sesiones. Separar tokens
   de Auth Cognito de tokens sender.
8. **Datos activos:** borrar o anonimizar, en orden transaccional seguro,
   templates, follow-ups/intents, Leads, Eventos, Content, perfil, entitlement,
   memberships, workspace/account y app user. Los registros legalmente
   retenidos deben separarse, minimizarse, bloquearse y comunicarse.
9. **Binarios:** enumerar por workspace desde metadata y/o prefijo, ejecutar
   `DeleteObject` para imágenes, audios y PDFs, verificar resultados y reintentar
   idempotentemente. El bucket actual no tiene versionado; backups/replicas y
   objetos huérfanos necesitan política explícita.
10. **Cognito al final:** borrar/revocar la identidad solo después de preservar
    un mecanismo seguro de finalizar/confirmar el job. Definir cómo se trata el
    vínculo Google y, si se aprueba, Apple.
11. **Dispositivo:** tras aceptación remota, detener sync y purgar todas las
    filas Drift, outbox, preferencias y archivos privados de ese owner; limpiar
    secure storage/sesión. No borrar datos de otro owner del mismo dispositivo.
12. **Confirmación:** pantalla/receipt y, si Legal lo autoriza, notificación sin
    PII indicando aceptación y posterior finalización. El recurso web consulta
    el mismo pipeline, no una lista manual paralela.

### 6.2 Recurso web Google Play

Debe ser público, funcional y nombrar Foloo/CBQA Solutions; permitir iniciar la
solicitud sin reinstalar la app, autenticar/verificar al solicitante, explicar
pasos y consecuencias y entregar estado/confirmación. Puede ser un formulario
seguro o portal; una política genérica sin camino destacado no basta. La URL
final es dato pendiente de CBQA/TI/Legal y no se inventa aquí.

### 6.3 Alternativas

| Alternativa | Evaluación |
|---|---|
| Job asíncrono orquestado e idempotente | **Recomendada.** Tolera S3/proveedores/retries y produce evidencia; mayor trabajo backend/operación |
| Endpoint síncrono monolítico | Menor superficie inicial, pero timeouts y borrado parcial son riesgos altos |
| Soporte manual por email | Puede complementar excepciones, pero no sustituye la ruta directa Apple ni la ruta in-app/web Play para este producto |
| Solo soft delete/desactivar | No cumple eliminación integral y mantiene riesgo de resurrección |

### 6.4 Decisiones aún requeridas en `D-13`

- plazos y base legal por categoría, backups, logs e idempotencia;
- cifrado local adicional y protección de archivos en iOS/Android;
- retención de historial de email, evidencia antifraude y trial;
- SLA, periodo de gracia/cancelación y posibilidad de recuperación;
- conducta con suscripción cuando FL-021 se reactive;
- revocación verificable por proveedor y tratamiento de objetos huérfanos;
- rol de CBQA frente al vendedor y los Leads de terceros;
- proceso de derechos de acceso, rectificación, oposición y portabilidad.

## 7. Autenticación y Apple Guideline 4.8

### 7.1 Estado actual

- Email/password Cognito con confirmación y recuperación.
- Google Sign-In federado por Cognito para la cuenta primaria de Foloo.
- Microsoft Sign-In de Auth oculto/fuera de esta versión; Microsoft sender es
  un OAuth separado que no autentica Foloo.
- `sub` continúa siendo la identidad/owner; email no es primary key.

### 7.2 Aplicabilidad y riesgo

La guía 4.8 vigente aplica cuando un login social/tercero crea o autentica la
cuenta primaria. Foloo ofrece Google para ese fin. La excepción “exclusivamente
el sistema propio de la empresa” no aplica literalmente mientras Google esté
presente; Foloo tampoco exige una cuenta empresarial/educativa existente ni es
cliente de un único servicio tercero. Tener email/password no ofrece por sí
solo la privacidad de email requerida a la alternativa equivalente.

**Conclusión preliminar:** riesgo de rechazo **alto** si se envía iOS con Google
Sign-In y sin una alternativa que satisfaga 4.8. La ruta conservadora es Sign
in with Apple. Solo App Review/Legal pueden aceptar una excepción concreta; no
debe asumirse.

### 7.3 Cambio propuesto si se aprueba

- Configurar Apple como IdP en Cognito, manteniendo Cognito como broker.
- Habilitar capability/identificadores Apple y callback OIDC de Cognito; guardar
  claves privadas solo en infraestructura/secret manager, nunca Flutter.
- Agregar el botón Apple conforme a HIG, ES/EN y tests de callback/restore/logout.
- Obtener nombre/email solo en el primer consentimiento y soportar Hide My
  Email; nunca usar email/Apple subject como owner.
- Definir **account linking** antes de lanzar. El mismo humano que ya usa
  email/Google podría recibir otro `sub`; no unir silenciosamente por email ni
  reasignar datos. Diseñar reautenticación de ambas identidades y auditoría.
- Integrar revocación de tokens y notificaciones server-to-server al eliminar
  cuenta, de acuerdo con el flujo de Apple.

Dependencias: decisión Producto/Legal, acceso Apple Account Holder/Admin,
configuración Cognito/Apple, secretos de infraestructura, UX, backend de
linking/deletion y QA físico. Esfuerzo técnico preliminar **M–L (1–2 sprints)**
sin contar espera de cuentas/revisión ni la eliminación integral `D-13`. La
alternativa de retirar Google solo en iOS reduciría 4.8 a login propio, pero
cambia el producto, crea divergencia entre plataformas y requiere aprobación.

## 8. Auditoría de permisos y medios

| Recurso | Uso real | iOS actual | Android actual | Evaluación |
|---|---|---|---|---|
| Cámara | tarjeta, referencias y foto de perfil | `NSCameraUsageDescription` existe, solo menciona tarjeta y solo ES | No `CAMERA`; `image_picker` delega a app de cámara | iOS string incompleto/no localizado; Android mínimo correcto para intent externo |
| Fotos/galería | tarjeta, referencias y perfil | `NSPhotoLibraryUsageDescription` existe, solo tarjeta/ES | Sin `READ_MEDIA_IMAGES`/storage; picker del sistema | iOS string incompleto/no localizado; Android minimiza permisos |
| Micrófono | Voice Note | `NSMicrophoneUsageDescription` claro pero solo ES | `RECORD_AUDIO` | Justificado; validar solicitud contextual y string EN |
| Archivos | importar PDF | document picker, sin purpose string específico | SAF/file picker, sin permiso amplio | Correcto y minimizado |
| Storage local | Drift, media/PDF/export temporal | sandbox | app-private/SAF | Sin permiso amplio; correcto |
| Red | Cognito/API/S3/OAuth | entitlement del sistema | `INTERNET` solo visible en manifests debug/profile del repo | P0: verificar merged Release; si falta, la app Android release no tendrá red |

No se encontró acceso a Contacts, Location, Calendar, Bluetooth, tracking o
almacenamiento Android amplio. No agregar permisos “por si acaso”. Antes de
STORE-03:

1. localizar purpose strings iOS ES/EN y describir tarjeta, referencias y
   perfil con lenguaje específico;
2. generar manifest merged Android Release y archive iOS Privacy Report;
3. revisar manifests de ML Kit, picker, record, file picker, pdfrx, share_plus,
   Amplify y connectivity;
4. decidir si la app necesita `PrivacyInfo.xcprivacy` propio solo con APIs y
   datos comprobados; actualmente no existe en Runner;
5. probar denegación/limited photos y recuperación sin bloquear captura manual.

## 9. Documentos legales y preguntas para abogados

### Documentos a validar/publicar

- Aviso/política de privacidad ES/EN, accesible en web y dentro de la app.
- Términos y condiciones/EULA y condiciones del trial/suscripción cuando aplique.
- Política de retención y eliminación, incluida copia de seguridad y logs.
- Procedimiento de derechos y eliminación de cuenta/datos.
- Anexo sobre Leads/datos de terceros y responsabilidades del vendedor.
- Consentimiento/base legal para Voice Note e imágenes de personas/tarjetas.
- Política de seguimiento comercial electrónico, remitente, opt-out y quejas.
- Inventario de encargados/subencargados y transferencias internacionales.
- Medidas de seguridad, respuesta a incidentes y contacto de privacidad.
- DPA/contratos con AWS, Google y Microsoft y, si aplica, clientes empresa.

### Preguntas concretas para Legal

1. ¿CBQA es controlador, encargado o ambos para vendedor y Lead en cada mercado?
2. ¿Qué base legal permite capturar/importar datos de un Lead y enviar el primer
   seguimiento? ¿Qué disclosure/consentimiento y opt-out son obligatorios?
3. ¿Puede el vendedor grabar voz/fotografiar tarjetas sin consentimiento
   adicional en cada país objetivo?
4. ¿Qué datos deben borrarse, anonimizarse o conservarse y por cuánto tiempo?
5. ¿Cómo se tratan backups, logs, evidencia antifraude, email y trial tras una
   solicitud? ¿Qué excepciones deben comunicarse?
6. ¿Qué países se lanzan y qué mecanismos de transferencia internacional/DPA
   corresponden a AWS/Google/Microsoft?
7. ¿Qué derechos, plazos, verificación de identidad y canal de reclamación se
   publicarán? ¿Quién atiende y audita solicitudes?
8. ¿La comunicación comercial necesita dirección física, baja activa u otros
   elementos que FL-019.5 retiró?
9. ¿Edad mínima/audiencia y tratamiento de datos de menores requieren controles?
10. ¿Qué razón social, domicilio, emails y teléfonos deben aparecer en políticas
    y stores? ¿Cómo conciliar el seller exacto con “CBQA Solutions”?
11. ¿La descripción del trial de cinco Leads y futura suscripción es suficiente
    y compatible con D-01–D-04?
12. ¿Legal acepta la lectura conservadora de Apple 4.8/Sign in with Apple?

## 10. Preguntas para Product Owner / CBQA

1. ¿Aprobar Sign in with Apple o retirar Google en iOS? (`D-21`).
2. ¿Aprobar el job asíncrono y la barrera `deletion_pending` como arquitectura
   de eliminación? ¿Habrá gracia/cancelación?
3. ¿Qué plazo visible se promete y qué confirmación recibe el usuario?
4. ¿Qué experiencia aplica si se solicita offline o existe outbox pendiente?
5. ¿Debe existir exportación de datos personales antes de borrar la cuenta?
6. ¿Qué URL/dominio alojará privacidad, soporte y eliminación web?
7. ¿Quién es owner operativo de solicitudes, incidentes y revocaciones?
8. ¿Qué mercados/idiomas/audiencia entran al primer release?
9. ¿Cuándo se resolverán D-01–D-04/FL-021 y cómo afecta cuenta eliminada con una
   suscripción de tienda aún activa?
10. ¿Qué datos sintéticos y cuentas review se autorizarán para las tiendas?

## 11. Plan posterior priorizado

Estos son delivery items, no requisitos aprobados ni autorización de
implementación.

| ID/prioridad | Objetivo y dependencias | Componentes/cambios | Riesgos/pruebas/aceptación |
|---|---|---|---|
| `STORE-02C-P0-01` | Resolver `D-13` con Legal/PO | SDD/ADR de retención, backups, cifrado y borrado | Aceptación: tabla aprobada por categoría, base/plazo/owner; sin valores implícitos |
| `STORE-02C-P0-02` | Eliminación integral in-app + web | Flutter ES/EN; API/job/status; migración account deletion; S3/KMS/OAuth/Cognito; sitio web | E2E multi-dispositivo/offline/retry/idempotencia/aislamiento; cero resurrección; receipt; legal approval |
| `STORE-02C-P0-03` | Resolver Apple 4.8 (`D-21`) | Apple+Cognito+Flutter+linking o retirar Google iOS | QA cuenta nueva/existente/relay/logout/delete; nunca merge por email; App Review risk |
| `STORE-02C-P0-04` | Publicar política/choices/support | Web + links in-app + metadata stores | URLs reales, accesibles, ES/EN, revisión Legal; sin contenido provisional |
| `STORE-02C-P0-05` | Cerrar declarations con RC real | Privacy Report/SBOM, App Privacy, Data Safety | Revisión de cuatro ojos; formularios coinciden con red, SDKs y política |
| `STORE-02C-P0-06` | Corregir/validar permisos Release | InfoPlist localization y merged manifest Android; sin permiso extra | Tests allow/deny/limited; strings completos; `INTERNET` en Release |
| `STORE-02C-P0-07` | Completar Play organization | Acceso corporativo, identidad, sitio y teléfono; fuera de código | Evidencia de owner/roles/verificaciones; no pagos/altas sin autorización |
| `STORE-02C-P1-01` | Revocación sender real | backend provider + cleanup de ciphertext; posible migration/audit | Google/Microsoft disconnect/reconnect/delete; tokens inutilizables; errores recuperables |
| `STORE-02C-P1-02` | Seguridad local aprobada | evaluar DB/media protection, redaction y root/device threat model | No pérdida offline; pruebas migración/performance; decisión D-13 |
| `STORE-02C-P1-03` | Gobierno de logs | esquema PROD, redaction, roles, alertas, retención aprobada | No payload/token/PII; tests logger; acceso y borrado auditables |
| `STORE-02C-P1-04` | Cleanup de tombstones/objetos | job seguro tras política D-13 | nunca borrar objeto activo/otro owner; métricas, dry run, retries |
| `STORE-02C-P1-05` | Cumplimiento email | restaurar/ajustar baja, disclosure y historial según Legal | Gmail/Graph, ES/EN, consentimiento y quejas; no envío duplicado |
| `STORE-02C-P2-01` | Portal de privacidad/derechos | acceso/export/rectificación/estado de solicitud | Auth fuerte, descarga segura, expiración y auditoría |
| `STORE-02C-P2-02` | Automatizar evidence drift | SBOM, scan permisos/SDK/network y checklist por release | Falla CI ante SDK/permiso/declaración no revisados |

`P0-02` probablemente requiere una migración aditiva para estado/solicitud de
eliminación y un worker/job; no se diseñará DDL hasta aprobar `D-13`. `P0-03`
puede requerir tablas de linking/auditoría. Ninguna migración existe todavía.

## 12. Bloqueos y riesgos abiertos

- **P0:** cuenta eliminable in-app/web; política/URL; D-13; Apple 4.8; matrices
  finales; permisos Release; acceso/verificaciones Google Play.
- **P1:** revocación sender, cleanup físico, seguridad local, gobierno de logs,
  cumplimiento de email y contratos/DPA.
- **P2:** portal de derechos y automatización de evidencia.
- FL-021/D-01–D-04 siguen pausados y pueden cambiar compras/retención/deletion.
- La eliminación de terceros ya destinatarios de un correo o copias exportadas
  no está bajo control técnico de Foloo; la política debe explicarlo.
- S3 `RETAIN`, RDS snapshot/backups y logs requieren una política coherente; no
  prometer borrado inmediato universal.
- Un mismo dispositivo conserva owners previos por diseño; el cleanup de cuenta
  debe ser selectivo y probado para no filtrar ni borrar otra cuenta.

## 13. Fuentes oficiales vigentes

Consulta: **2026-10-09**.

- Apple: [App Review Guidelines 4.8 y 5.1](https://developer.apple.com/app-store/review/guidelines/),
  [account deletion 5.1.1(v)](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion/),
  [App Privacy details](https://developer.apple.com/app-store/app-privacy-details/),
  [manage App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/),
  [privacy manifests](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests).
- Google Play: [Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469),
  [account deletion](https://support.google.com/googleplay/android-developer/answer/13327111),
  [User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311).

Las fuentes oficiales confirman: Apple exige que las apps con creación de
cuenta permitan iniciar eliminación dentro de la app; Google exige ruta in-app
y recurso web; Apple 4.8 aplica al login social de la cuenta primaria salvo
excepciones específicas; ambos publishers hacen responsable al developer de
declaraciones completas, incluidas prácticas de SDKs/terceros.

## 14. Criterios de salida de STORE-02C

- Inventario y matrices preliminares enlazados desde roadmap/traceability.
- `D-13` ampliada sin resolver y riesgo 4.8 registrado como `D-21`.
- Estado real de Google Play actualizado: Organization existente; invitación,
  acceso corporativo y verificaciones pendientes.
- No se cambió Flutter, backend, infraestructura, manifests ni consolas.
- Antes de STORE-03/04: Legal/PO deben resolver decisiones, ingeniería debe
  implementar P0 y QA debe validar RC/Privacy Report/formularios.
