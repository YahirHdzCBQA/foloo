# Especificación de producto — Foloo V1

- Estado: vigente
- Corte funcional: 2026-09-09
- Producto: una sola app móvil Flutter para iOS y Android
- Autoridad: alcance validado 2026-09-07 con actualización explícita del tablero
  operativo 2026-09-08

## Principios no negociables

- El contexto es de pie, con una mano, presión y conectividad irregular.
- Lead y medios se guardan durablemente antes de cualquier red.
- Señal, correo o pago nunca borran ni ocultan datos capturados.
- Ningún secreto de servicio vive en Flutter; Cognito protege sus tokens fuera
  de Drift.
- Offline es normal y está separado de autenticación/disponibilidad backend.
- Estado y selección nunca dependen solo del color.
- CTA principal fijo de 56 dp, objetivos táctiles ≥44 dp y UI vertical.
- Lima se reserva para CTA, selección activa o marca.
- ES/EN y claro/oscuro son de primera clase.
- Lo no especificado o contradictorio se registra como decisión abierta.

## 1. Objetivo y modelo comercial

Foloo permite que una persona vendedora capture, conserve, consulte y dé
seguimiento a contactos en eventos o encuentros directos, incluso sin señal.

No existen ediciones Basic/Pro. Una cuenta nueva puede guardar cinco leads. Al
intentar guardar el sexto, Foloo conserva el formulario y presenta el paywall.
Una suscripción anual activa habilita captura ilimitada. Un estado de pago
inactivo nunca elimina ni oculta datos existentes y no impide consulta,
edición, exportación o reintentos pendientes.

## 2. Alcance

### 2.1 Dentro de V1

- Cognito real: alta, confirmación por email, login, restore y logout.
- Perfil Foloo, eventos, origen evento/directo y lugar del directo.
- Captura de tarjeta y OCR en dispositivo con Google ML Kit.
- Datos del contacto, tipo, interés, voz, texto e imágenes de referencia.
- Persistencia Drift/SQLite, operación offline total y sincronización futura.
- Registros, detalle editable y visor de imágenes.
- Biblioteca PDF, asignación a eventos, plantillas y correo con adjuntos.
- Exportación XLSX y CSV por evento, incluida operación sobre datos locales.
- Tema claro/oscuro, ES/EN y navegación móvil.
- Trial de cinco leads, paywall y suscripción anual.

### 2.2 Fuera de V1

- Transcripción automática o con IA de la nota de voz.
- Lectura de QR.
- Web para configurar contenido/correo.
- Dashboard Foloo Teams, roles y multiusuario.
- Dashboard administrativo Foloo HQ.
- Códigos promocionales.
- Google Sheets.
- CRM, scoring, analítica avanzada y resúmenes con IA.
- Edición interna del contenido de los PDF.

## 3. Actores y entidades

### 3.1 Identidad y perfil

Cognito administra identidad, email, contraseña, confirmación y sesión. El
`sub` es el identificador técnico estable. Foloo administra un perfil separado:
`nombre`, `puesto`, `empresa`, `telefono` y `fotoLocal/fotoUrl` opcional.

### 3.2 Evento

`id`, `ownerUserId`, `nombre`, `fechaInicio`, `fechaFin`, `activo`,
`eliminado`, asignaciones de contenido y marcas de auditoría. Un lead de evento
referencia su evento; un lead directo conserva `lugar`.

### 3.3 Lead

Un Lead pertenece al Cognito `sub` activo y contiene identidad local,
fecha/hora, origen, evento o lugar, capturó, nombre, apellido, puesto, empresa,
correo, teléfono, tipo, interés, nota escrita, foto de tarjeta, nota de voz,
hasta tres imágenes de referencia, adjuntos congelados y estados locales/remotos
de sincronización y correo. El folio comercial puede existir internamente, pero
no sustituye la identidad técnica local ni se muestra en el detalle actual.

### 3.4 Contenido, plantilla y suscripción

- Archivo de contenido: PDF, nombre visible, metadata, eventos aplicables,
  copia local y futura referencia remota.
- Plantilla: una para evento y una para lead directo, con asunto, cuerpo, firma,
  variables validadas y pie legal no editable.
- Suscripción: estado server-side por cuenta, trial consumido, vigencia y caché
  local verificable. No se define aquí proveedor o política de tienda.

## 4. Requerimientos funcionales

### 4.1 Autenticación y perfil

| ID | Requerimiento |
|---|---|
| `AUT-01` | Runtime normal autentica con AWS Cognito por email y contraseña; la UI no llama Cognito directamente. |
| `AUT-02` | La sesión válida se restaura al abrir sin pedir login de nuevo; perder red no equivale a logout. |
| `AUT-03` | La persona puede mostrar/ocultar la contraseña y recibe errores de dominio ES/EN, nunca mensajes AWS crudos. |
| `AUT-04` | Self sign-up solicita solo email y contraseña. |
| `AUT-05` | El alta requiere código enviado por email y admite reenvío cuando Cognito lo permita. |
| `AUT-06` | Código incorrecto, vencido, cuenta confirmada, red y error inesperado tienen estados recuperables ES/EN. |
| `AUT-07` | Después de autenticar, un perfil incompleto abre “Tu perfil”; uno completo abre Inicio. |
| `AUT-08` | El perfil Foloo solicita nombre, puesto, empresa, teléfono y foto opcional; no convierte esos campos en atributos Cognito obligatorios. |
| `AUT-09` | El perfil se persiste y puede editarse desde el menú. |
| `AUT-10` | Cognito `sub`, nunca email, es ownership de perfil, eventos, leads, preferencias y medios. |
| `AUT-11` | Logout Cognito limpia sesión sensible y vuelve a Login sin borrar datos del producto. |
| `AUT-12` | Filas históricas sin owner o de FakeAuth se preservan y no se reasignan silenciosamente. |
| `AUT-13` | MFA de usuario, passwordless, social login y UI de recuperación quedan fuera; account recovery permanece habilitado en Cognito para una FL futura. |

### 4.2 Eventos y origen

| ID | Requerimiento |
|---|---|
| `EVT-01` | Crear evento con nombre, fecha inicial y fecha final editables mediante el calendario Foloo. |
| `EVT-02` | Editar nombre/fechas y eliminar lógicamente un evento sin borrar sus leads. |
| `EVT-03` | Mostrar conteo total y por subir calculado desde los leads persistidos del evento. |
| `EVT-04` | Permitir seleccionar manualmente un evento activo y conservarlo al reingresar. |
| `EVT-05` | Un evento recién creado queda activo. |
| `EVT-06` | Sin selección manual válida, elegir el evento futuro más cercano usando la fecha real del dispositivo; reevaluar al cambiar de día. |
| `EVT-07` | Mis eventos separa activo, futuros y pasados; el activo no se duplica. Futuros ordenan por inicio ascendente y pasados por fin descendente. |
| `EVT-08` | Un evento es vigente mientras `inicio <= hoy <= fin`; futuro si inicia después; pasado si terminó antes. |
| `EVT-09` | El origen se elige entre Evento y Lead directo y persiste entre capturas consecutivas. |
| `EVT-10` | Evento muestra selector, fecha y creación rápida; directo exige un lugar de captura persistente y no asocia evento. |
| `EVT-11` | Crear evento puede asignar contenido existente y abrir el flujo local de selección de PDF. |
| `EVT-12` | Filtros de Registros y Contenido no cambian el evento activo de captura. |

### 4.3 Captura, OCR y datos

| ID | Requerimiento |
|---|---|
| `CAP-01` | Los cuatro pasos viven en una pantalla vertical con progreso superior y CTA inferior fijo de 56 dp. |
| `CAP-02` | Datos: nombre, apellido, puesto, empresa, correo y teléfono, editables y con teclado apropiado. |
| `CAP-03` | Se requiere nombre, empresa y al menos correo válido o teléfono; la definición exacta se conserva del alcance validado. |
| `CAP-04` | Guardar con faltantes desplaza al primer campo inválido, lo identifica con texto/icono y conserva todo lo escrito. |
| `CAP-05` | Tipo único obligatorio: Cliente, Partner o Proveedor; sin valor inicial. |
| `CAP-06` | Interés: Bajo, Medio o Alto, con semáforo y representación textual. |
| `CAP-07` | Nota escrita libre y opcional. |
| `CAP-08` | Agregar/eliminar de cero a tres imágenes de referencia; cámara permite 1/2/3 fotos en una sesión y galería comparte el límite. |
| `CAP-09` | Guardar persiste Lead y medios localmente antes de red. |
| `CAP-10` | El acuse muestra contacto y resultados reales de persistencia/procesamiento; estados futuros no se presentan como completados. |
| `CAP-11` | El acuse ofrece regreso inmediato y regreso automático a captura, conservando origen/evento y limpiando el nuevo formulario. |
| `CAP-12` | El intento de guardar el sexto lead conserva el lead en curso mientras MON-03 abre el paywall. |

| ID | Requerimiento OCR |
|---|---|
| `OCR-01` | Cámara trasera y galería son acciones separadas; también existe captura manual. |
| `OCR-02` | Google ML Kit procesa texto en el dispositivo; no requiere backend para reconocer la tarjeta. |
| `OCR-03` | Se precargan cuando existan nombre, apellido, puesto, empresa, correo y teléfono. |
| `OCR-04` | Los campos siguen editables y una corrección manual no se sobrescribe silenciosamente. |
| `OCR-05` | Error o tarjeta ilegible permite continuar manualmente con explicación útil. |
| `OCR-06` | Se puede reprocesar, reemplazar o quitar la foto antes de guardar. |
| `OCR-07` | La foto original se conserva como medio privado del Lead. |
| `OCR-08` | Se prueban orientación, sombras, tarjetas a dos columnas y material real de evento. |
| `OCR-09` | Procesamiento, memoria y resolución deben ser compatibles con el presupuesto móvil y el flujo menor a 60 segundos. |

### 4.4 Voz y medios

| ID | Requerimiento |
|---|---|
| `VOZ-01` | Grabar/detener con un toque, temporizador y onda viva; detener usa iconografía inequívoca. |
| `VOZ-02` | Antes de guardar se puede reproducir, borrar y volver a grabar. |
| `VOZ-03` | Después de guardar el detalle reproduce la nota; editarla después depende de la misma política definida para el detalle. |
| `VOZ-04` | Audio y tarjeta se copian a storage privado local y sobreviven reinicio/logout. |
| `VOZ-05` | La subida futura es asíncrona y no bloquea guardar. |
| `VOZ-06` | Permiso denegado deja disponible la nota escrita. |
| `VOZ-07` | Duración/peso máximo y aviso están bloqueados por `D-05`; no se inventa un límite. |
| `VOZ-08` | No existe transcripción automática/IA ni UI que la prometa en V1. |

### 4.5 Persistencia, offline y sincronización

| ID | Requerimiento |
|---|---|
| `SYN-01` | Drift/SQLite es la fuente durable local para perfil, preferencias, eventos, leads y metadata de medios. |
| `SYN-02` | Toda la app mantiene consulta y mutaciones locales útiles sin red: captura, registros, contenido, plantillas y cola de correo. |
| `SYN-03` | ConnectivityState es visual y separado de AuthState y disponibilidad del backend. |
| `SYN-04` | Lead, tarjeta, voz, imágenes y PDF usan colas/reintentos independientes para evitar bloqueo en cascada. |
| `SYN-05` | Reintento automático al recuperar conexión y manual desde Registros. |
| `SYN-06` | Sincronización es idempotente y reanudable; el identificador remoto final queda sujeto al contrato API. |
| `SYN-07` | Estado local, pendiente, sincronizado o fallido aparece con icono y palabra en lista y detalle. |
| `SYN-08` | Fallos repetidos conservan datos, motivo legible y acción de reintento. |
| `SYN-09` | Nuevos datos se aíslan por Cognito `sub`; logout no borra colas. |
| `SYN-10` | La implementación cloud sigue Flutter → Drift → sync → API Foloo; no llama proveedores directamente. |

### 4.6 Registros, detalle y exportación

| ID | Requerimiento |
|---|---|
| `REG-01` | Registros lista leads persistidos, con fecha/hora, nombre, empresa, tipo, interés, voz y estado de subida. |
| `REG-02` | Selector incluye “Todos los eventos” y eventos persistidos; filtra sin cambiar el activo. |
| `REG-03` | Buscar por nombre/empresa y filtrar Cliente/Partner/Proveedor funciona localmente. |
| `REG-04` | Orden por fecha y estado vacío invitan a capturar; conteos reflejan el filtro actual. |
| `REG-05` | El detalle muestra contacto, fecha/hora, origen, capturó, medios, notas, adjuntos y estados. |
| `REG-06` | La tarjeta e imágenes de referencia se abren completas en un visor modal. |
| `REG-07` | El detalle permite corregir los campos aprobados y persiste el cambio sin perder ownership o medios. |
| `REG-08` | Voice Note se reproduce desde lista/detalle; controles post-guardado siguen la política de `D-06`. |
| `REG-09` | Exportar ofrece XLSX y CSV por evento; XLSX es la opción inicial. Decisión posterior 2026-09-08. |
| `REG-10` | Exporta datos locales del evento, incluidos pendientes; “Todos los eventos” no crea una exportación multievento implícita. |
| `REG-11` | CSV usa UTF-8 con BOM; XLSX/CSV preservan acentos ES/EN. |
| `REG-12` | El resultado se comparte con la hoja de compartir del sistema. |
| `REG-13` | Columnas exactas y tratamiento de medios quedan bloqueados por `D-07`. |

### 4.7 Contenido, plantillas y correo

| ID | Requerimiento |
|---|---|
| `CON-01` | Biblioteca PDF accesible desde menú, con nombre visible, archivo, peso y eventos aplicables. |
| `CON-02` | Estado vacío “Sin contenido todavía” y Subir PDF abren el selector local, solo PDF. |
| `CON-03` | Al seleccionar PDF se captura nombre visible y eventos aplicables con buscador, contador y scroll propio. |
| `CON-04` | “Todos los eventos” domina la selección individual sin destruirla. |
| `CON-05` | Se puede editar asignación o eliminar un archivo con confirmación. |
| `CON-06` | Crear evento permite asignar contenido y comenzar la selección de un PDF. |
| `CON-07` | Captura muestra contenido del evento preseleccionado y desmarcable por Lead. |
| `CON-08` | Adjuntos elegidos quedan congelados en el Lead; cambios posteriores no reescriben historia. |
| `CON-09` | PDF se conserva localmente y su futura subida no bloquea la cola de Leads. |
| `CON-10` | Límites por archivo/biblioteca y desalojo requieren `D-08`. |

| ID | Requerimiento de plantilla |
|---|---|
| `PLT-01` | Existen dos plantillas editables: evento y directo. |
| `PLT-02` | Cada una conserva asunto, cuerpo y firma; el origen selecciona la correcta automáticamente. |
| `PLT-03` | Variables válidas incluyen contacto/capturó y evento o lugar; contenido representa adjuntos. |
| `PLT-04` | Variables inválidas o llaves abiertas bloquean guardar con explicación. |
| `PLT-05` | Pie de privacidad/baja no es editable ni removible. |
| `PLT-06` | Plantillas tienen default funcional, persistencia local y futura autoridad server-side. |
| `PLT-07` | Texto y variables funcionan en ES/EN sin traducir identificadores contractuales. |

| ID | Requerimiento de salida |
|---|---|
| `SAL-01` | Guardar un Lead programa correo de seguimiento al contacto con la plantilla correspondiente y adjuntos congelados. |
| `SAL-02` | Si no hay red, el correo queda en cola; un fallo nunca revierte el Lead. |
| `SAL-03` | Estado enviado/en cola/fallido es visible y recuperable. |
| `SAL-04` | El servidor ejecuta envío, sustitución y adjuntos; no hay credenciales ni cliente de correo en Flutter. |
| `SAL-05` | Dominio de envío cumple SPF, DKIM, DMARC, rebotes y monitoreo de reputación. |
| `SAL-06` | El tablero exige envío firmado por Google Workspace con DKIM, pero el proveedor final está bloqueado por `D-09`. |
| `SAL-07` | Destinatario sin email, reintento, baja y estados exactos requieren contrato explícito antes del backend. |

### 4.8 Navegación, apariencia e idioma

| ID | Requerimiento |
|---|---|
| `NAV-01` | Drawer derecho cierra por scrim, cierre, gesto/back y contiene Inicio, Registros, Mis eventos, Contenido, Correo, Perfil, Apariencia, Idioma y Logout. |
| `NAV-02` | Logo Foloo superior izquierdo vuelve a Inicio donde sea aplicable. |
| `NAV-03` | Drawer muestra identidad, evento activo y saldo del trial/suscripción; no muestra plan Basic/Pro. |
| `NAV-04` | Claro/oscuro remapea tokens y conserva preferencia local por usuario. |
| `NAV-05` | Selector compacto ES/EN en Login y Drawer comparte un solo estado y actualiza la UI al instante. |
| `NAV-06` | Toda cadena nueva de producto y correo existe en ES/EN. |
| `NAV-07` | Logout está visualmente separado y protegido sin violar la zona ergonómica. |

### 4.9 Monetización

| ID | Requerimiento |
|---|---|
| `MON-01` | Cada cuenta nueva dispone de cinco leads guardados gratis; el contador es server-side y no se reinicia al reinstalar. |
| `MON-02` | Saldo y aviso previo al límite son visibles en captura y Drawer. |
| `MON-03` | El intento de guardar el sexto abre paywall y conserva íntegro el Lead en curso. |
| `MON-04` | Suscripción anual activa habilita captura ilimitada; precio, moneda y regiones están bloqueados. |
| `MON-05` | Backend/webhook es fuente de verdad del desbloqueo; el cliente no concede acceso por resultado visual de pago. |
| `MON-06` | Estado de suscripción se cachea para no bloquear offline a quien ya pagó. |
| `MON-07` | Pago inactivo bloquea solo nuevas capturas; datos existentes siguen visibles/editables/exportables. |
| `MON-08` | Compra, vencimiento, gracia, cancelación y reembolso se implementan solo tras resolver `D-01`–`D-04`. |

## 5. Infraestructura y no funcionales

| ID | Requerimiento |
|---|---|
| `INF-01` | Dirección: Flutter → Drift/SQLite → Offline Sync → Foloo API → API Gateway → Lambda Node.js/TypeScript → persistencia cloud. |
| `INF-02` | S3 almacenará tarjeta, imágenes de referencia, voz y PDF con acceso autenticado y retención; permanece para FL-016. |
| `INF-03` | PostgreSQL en AWS RDS es la persistencia cloud relacional; RDS permanece privado y Lambda accede únicamente dentro de la VPC (ADR-003). |
| `INF-04` | DEV/staging/PROD, secretos, CI/CD, observabilidad, respaldos y borrado requieren trabajo de infraestructura trazado. |
| `INF-05` | La API Foloo usa rutas REST versionadas bajo `/v1` y valida inputs en runtime con un contrato de error estable. |
| `INF-06` | API Gateway valida JWT Cognito contra issuer y App Client; el backend deriva ownership únicamente del `sub` verificado. |
| `INF-07` | Cada identidad tiene una cuenta y workspace personal inicial, modelados mediante membresía para permitir evolución organizacional sin implementar Teams. |
| `INF-08` | Recursos cloud usan UUID estable suministrable por el cliente, revisión, timestamps y borrado lógico; el folio comercial nunca es identidad técnica. |
| `INF-09` | Escrituras de creación aceptan una clave de idempotencia y detectan su reutilización con otro payload; FL-015 consumirá esta base sin implementar sync aquí. |
| `INF-10` | Binarios no se guardan en PostgreSQL; FL-014 conserva únicamente metadata y FL-016 incorporará S3. |
| `INF-11` | RDS no es público; PostgreSQL acepta tráfico solo desde el Security Group de Lambda y DEV no incorpora NAT Gateway ni RDS Proxy. |
| `INF-12` | Credenciales de base se generan/guardan en Secrets Manager y se leen por endpoint VPC privado; no existen credenciales AWS, DB o JWT en Flutter/repositorio. |
| `INF-13` | La Lambda reutiliza un pool PostgreSQL pequeño entre invocaciones y limita concurrencia DEV para proteger el presupuesto de conexiones. |
| `INF-14` | Logs JSON incluyen requestId y omiten tokens, contraseñas, payloads y PII; ningún error interno de AWS/PostgreSQL se expone al cliente. |
| `RNF-01` | Captura completa objetivo menor a 60 s; arranque utilizable objetivo menor a 3 s. |
| `RNF-02` | Flutter, iOS 15+, Android 10+, orientación retrato y piso visual 390×844. |
| `RNF-03` | Controles táctiles ≥44 dp, CTA 56 dp, WCAG 2.2 AA y estado no solo por color. |
| `RNF-04` | Soportar al menos 300 leads/evento, 12 eventos y 20 PDF sin degradación visible. |
| `RNF-05` | Sin secretos de servicio; HTTPS; medios cifrados y enlaces autenticados. |
| `RNF-06` | Toda la app y correos operan ES/EN; tipografías/assets críticos son locales. |
| `RNF-07` | Guardados y sincronización no crean duplicados ni pierden cambios locales. |
| `RNF-08` | La política comercial nunca reduce disponibilidad de datos ya capturados. |

| ID | Cumplimiento |
|---|---|
| `RC-01` | Cumplir LFPDPPP y entregar aviso/opt-out mediante pie no editable del correo. |
| `RC-02` | Tarjeta, contacto, voz e imágenes tienen retención y eliminación aprobadas. |
| `RC-03` | Acceso a datos y medios se restringe a identidad/organización autorizada. |
| `RC-04` | Eliminación lógica de evento no equivale a eliminación legal. |
| `RC-05` | Publicar privacidad, términos y términos de suscripción antes de tienda. |

## 6. Criterios de salida V1

| ID | Evidencia requerida |
|---|---|
| `REL-01` | Escenarios E-01–E-12 aprobados en iOS y Android. |
| `REL-02` | Prueba real offline/reconexión sin duplicados ni pérdida. |
| `REL-03` | OCR evaluado con tarjetas reales y casos difíciles. |
| `REL-04` | Pago probado en sandbox y entorno aprobado, incluido vencimiento. |
| `REL-05` | Beta con vendedor en evento real y operación con una mano. |
| `REL-06` | Cuentas Apple/Google, assets ES/EN, permisos y legales listos. |
| `REL-07` | Revisión de tiendas, versión etiquetada, notas y soporte definidos. |
| `REL-08` | XLSX/CSV verificados con acentos y caracteres especiales. |

## 7. Doce capacidades de V1

| # | Capacidad | Requisitos principales |
|---:|---|---|
| 01 | OCR de tarjetas | `OCR-*` |
| 02 | Clasificación e interés | `CAP-05`, `CAP-06` |
| 03 | Eventos y Leads directos | `EVT-*` |
| 04 | Plantillas con variables | `PLT-*` |
| 05 | Contenido PDF | `CON-*` |
| 06 | Gestión por evento | `REG-01`–`REG-04` |
| 07 | Detalle de cada Lead | `REG-05`–`REG-08` |
| 08 | Voice Note | `VOZ-*` |
| 09 | Imágenes de referencia | `CAP-08`, `REG-06` |
| 10 | Correo de seguimiento | `SAL-*` |
| 11 | XLSX/CSV por evento | `REG-09`–`REG-13` |
| 12 | Offline total y sincronización | `SYN-*` |

Autenticación, navegación, monetización, infraestructura, calidad y cumplimiento
son transversales. La matriz no representa planes comerciales.

## 8. Fuente y reconciliación

Precedencia: Alcance MVP validado 2026-09-07; Cambios de alcance y Ruta a
producción del mismo día; después el tablero operativo 2026-09-08 donde declara
una actualización explícita. Por ello XLSX/CSV reingresan a V1 y Google Sheets
permanece backlog. ML Kit local reemplaza la antigua dirección de OCR remoto y
la transcripción automática queda fuera. El proveedor de correo no se resolvió:
ver `D-09`.
