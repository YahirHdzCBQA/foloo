# 02 · Escenarios de aceptación — Foloo V1

Cada escenario cubre el producto unificado. No existe una variante por edición.

## E-01 · Alta, confirmación, sesión y perfil

**Trazas:** `AUT-01`–`AUT-14`, `SYN-09`, `SAL-08`, `SAL-09`.

- Dado un email nuevo, al registrarse con contraseña, entonces Cognito envía un
  código y la app solicita confirmación sin pedir datos de perfil.
- Código inválido/vencido, reenvío, usuario confirmado, red y error inesperado
  se expresan en ES/EN sin texto AWS crudo.
- Login válido restaura el `sub`; perfil incompleto abre Tu perfil y perfil
  completo abre Inicio.
- Al completar un perfil nuevo se ofrece una cuenta de envío Google/Microsoft
  distinta de la cuenta Foloo. Conectar u omitir permite continuar; omitir no
  bloquea Leads ni reaparece cada inicio. Usuarios con perfil previo no repiten
  onboarding y la disposición local de este paso nunca suplanta el estado OAuth.
- Cerrar/reabrir restaura sesión válida. Logout vuelve a Login y conserva datos.
- Dos `sub` no ven perfil, eventos, leads o preferencias del otro; filas
  históricas no se reclaman.

## E-02 · Eventos, origen y fecha real

**Trazas:** `EVT-01`–`EVT-12`.

- Crear evento permite elegir inicio/fin y lo deja activo.
- La lista muestra activo una vez, futuros por inicio ascendente y pasados por
  fin descendente usando la fecha local real.
- Sin selección manual válida, el evento futuro más próximo queda activo y se
  reevalúa al cambiar de día; una selección manual válida no se sobrescribe.
- Editar nombre/fechas persiste primero en Drift, sobrevive restart/logout y
  sincroniza por outbox; un pull no revierte una mutación pendiente. Unicode
  escrito por el usuario se conserva sin normalización destructiva.
- Eliminar exige confirmación ES/EN. Cancelar no cambia nada; confirmar marca
  tombstone local y remoto sin borrar, reasignar ni ocultar los Leads asociados.
  La eliminación sobrevive restart/logout y un pull no resucita el evento.
- Conteos reflejan los Leads locales.
- Evento y Lead directo alternan; directo exige Lugar y ambos contextos
  persisten entre capturas.

## E-03 · Tarjeta, OCR y captura manual

**Trazas:** `CAP-01`–`CAP-06`, `OCR-01`–`OCR-09`.

- Cámara o galería ejecutan ML Kit local y precargan solo valores reconocidos.
- Correcciones manuales no se sobrescriben sin acción explícita.
- Tarjeta ilegible deja todos los campos manuales disponibles.
- Foto puede reprocesarse, reemplazarse o quitarse antes de guardar.
- La captura conserva cuatro pasos en un scroll, progreso superior y CTA fijo.
- Guardar con faltantes desplaza al primero y lo identifica sin perder datos.

## E-04 · Voz, texto e imágenes de referencia

**Trazas:** `CAP-07`, `CAP-08`, `VOZ-01`–`VOZ-08`.

- Grabar muestra onda/tiempo, detener no usa micrófono y después permite
  reproducir, borrar o regrabar.
- Permiso denegado mantiene nota escrita; voz y texto son opcionales.
- Una sesión de cámara acepta una, dos o tres imágenes y finaliza con ✓; si ya
  existen dos solo agrega una. Galería respeta el mismo máximo.
- Guardar y reabrir conserva voz e imágenes. V1 no muestra transcripción.

## E-05 · Guardado local y acuse

**Trazas:** `CAP-09`–`CAP-12`, `SYN-01`.

- Al guardar, Lead y medios existen en Drift/storage privado antes de cualquier
  intento remoto.
- Si la escritura local falla, no se muestra éxito y el formulario permanece.
- El acuse informa únicamente estados reales, permite volver ahora y vuelve
  automáticamente conservando origen/evento.
- El intento de guardar el sexto Lead conserva el borrador y abre paywall.

## E-06 · Registros y detalle editable

**Trazas:** `REG-01`–`REG-08`.

- “Todos los eventos” muestra todos; elegir uno filtra y actualiza conteos sin
  cambiar el evento activo.
- Búsqueda, tipo y orden funcionan offline sobre Drift.
- El renglón comunica interés, voz y sync con icono/palabra.
- El detalle reproduce voz, abre tarjeta/referencias completas y muestra
  fecha/hora, origen y capturó.
- Tras renombrar un evento, el detalle de sus Leads muestra el nombre vigente
  desde la relación local, no un snapshot antiguo; también resuelve el nombre
  del evento eliminado lógicamente. Un Lead directo muestra "Lead directo · Lugar"
  (o su equivalente EN) si Lugar existe, y solo "Lead directo" si falta.
- Corregir los campos estructurados de `REG-07` persiste primero en Drift,
  actualiza por outbox y no cambia owner, UUID, captura, origen, evento o medios.
- Una revisión remota distinta conserva la edición local, muestra conflicto
  recuperable y nunca crea otro Lead.

## E-07 · Contenido PDF y asignación

**Trazas:** `CON-01`–`CON-10`, `EVT-11`.

- Biblioteca vacía muestra el estado aprobado y Subir PDF abre archivos.
- Solo PDF avanza a nombre visible y selección buscable de eventos.
- Todos los eventos domina sin borrar selecciones individuales.
- Editar asignación y eliminar requieren resultado persistente/confirmado.
- Crear evento permite seleccionar contenido existente o iniciar PDF.
- Adjuntos elegidos quedan congelados por Lead y un PDF atascado no bloquea
  Leads.
- El PDF de hasta 25 000 000 bytes se copia a almacenamiento privado antes de
  encolarse, se abre offline desde esa copia y no se desaloja automáticamente.
  Un archivo mayor, inválido o sin espacio disponible se rechaza con error ES/EN.
- Upload/confirmación a S3 y descarga autenticada usan URLs temporales sin
  persistirlas; un retry conserva identidad y copia local. El borrado lógico
  deja de ofrecer el Content activo y no borra S3 ni adjuntos históricos.

## E-08 · Plantillas y correo

**Trazas:** `PLT-01`–`PLT-07`, `SAL-01`–`SAL-09`, `RC-01`, ADR-006/007.

- Event/Direct ES/EN eligen por origen estructurado; asunto, cuerpo y firma
  editados sobreviven reinicio y cambio de cuenta. Preview del Lead real no envía.
- Sin plantilla persistida, el asunto inicial es `Damos seguimiento, {nombre}`
  en ES y `Following up, {nombre}` en EN, renderizado con el nombre real. Una
  plantilla personalizada o un follow-up histórico congelado no se reescriben.
- Solo los nueve tokens `PLT-03` se guardan; tokens desconocidos o llaves
  incompletas se rechazan. Datos históricos ausentes nunca producen tokens
  literales, `null`, `undefined` ni información inventada. `{contenido}` usa
  el snapshot histórico del Lead y representa varios PDF con nombres humanos.
- Footer fijo ES/EN de Evento o Directo incluye enlace de baja operativo y no
  editable. GET, preview o prefetch solo muestran confirmación y no cambian
  datos; POST explícito registra la baja y repetirlo es idempotente. Token
  inválido no cambia datos; otro workspace no se ve afectado; Lead e historial
  se preservan. Una baja real bloquea envíos futuros como estado terminal sin
  retry; sin baja, la misma dirección admite múltiples follow-ups legítimos.
- Guardar Lead confirma primero la persistencia local y abre “Revisar” con
  destinatario inmutable, texto concreto sin tokens y adjuntos congelados. La
  edición ahí no muta la plantilla global; solo `foloo` crea la intención.
  Con teclado visible, la revisión sigue siendo desplazable, conserva la
  edición y mantiene el CTA accesible; tap fuera o drag descartan el teclado.
  Falta de email se muestra sin crear envío imposible. Confirmación online
  refleja la respuesta real del proveedor; offline persiste la intención y la
  outbox la reanuda al recuperar señal, incluso tras reinicio.
- Pendiente/Enviando/Enviado/Error/Estado por confirmar se muestran con texto,
  sin equiparar aceptación a entrega. Timeout ambiguo tras posible aceptación
  jamás reintenta solo; nuevo intento exige advertencia/decisión. Un reenvío
  manual posterior es una intención distinta del retry técnico.
- Adjuntos congelados se validan en backend. PDF borrado/no disponible o exceso
  de tamaño no se omite en silencio: el vendedor decide omitirlo para esa
  intención o cancelar. El Lead y su snapshot no cambian.
- Google/Microsoft conectan por OAuth y least privilege; sin conexión o con
  autorización revocada hay CTA de conectar/reconectar sin perder datos. Un
  pendiente de identidad anterior requiere confirmar el nuevo remitente. Los
  envíos históricos mantienen su remitente efectivo y ninguna cuenta B accede
  a conexión, plantilla, follow-up u opt-out de A.
- Correo consulta el backend al abrirse y al volver del navegador. Con conexión
  muestra proveedor, dirección enmascarada y estado; jamás infiere conexión por
  haber tocado OAuth ni reutiliza el estado visual de otro `sub`.
- Microsoft Graph `202 Accepted` sin cuerpo se registra como Enviado/aceptado,
  no como respuesta perdida. El historial nunca vuelve a mostrar variables de
  plantilla crudas después de reconciliar con backend.

## E-09 · Offline total y sincronización

**Trazas:** `SYN-02`–`SYN-10`, `INF-01`, `INF-02`.

- En modo avión se consultan/cambian datos locales, se capturan Leads, se
  preparan PDF/plantillas y se encolan salidas.
- ConnectivityState cambia sin alterar AuthState.
- Al recuperar señal, colas reanudables avanzan sin duplicados; un archivo
  grande no detiene Leads.
- Evento, Lead y metadata de medios respetan dependencia padre-hijo; un fallo
  del padre no envía prematuramente al hijo.
- Un Lead confirmado remotamente no aparece como fallido solo porque alguno de
  sus medios siga pendiente o tenga error.
- Fallo repetido conserva dato, motivo y reintento manual.
- Cerrar/reabrir la app conserva la outbox; reintentar una respuesta perdida usa
  la misma clave idempotente. Un 400 queda detenido y 408/429/5xx/transporte se
  reprograman sin borrar el dato.
- Sin sesión o con otro `sub` no se consume la cola. El pull no pisa entidades
  con mutaciones locales abiertas.
- Tarjeta, imagen de referencia y Voice Note permanecen en storage privado
  local y outbox tras reinicio. Cuando el Lead padre existe remotamente, la app
  solicita una autorización temporal, hace PUT directo al objeto privado y la
  API verifica existencia, tamaño, MIME, metadata y firma básica del archivo
  antes de marcarlo disponible.
- Fallar el PUT o expirar la URL no elimina el archivo ni cambia el UUID lógico:
  el retry solicita otra autorización para la misma key. Un segundo dispositivo
  obtiene únicamente lectura temporal autenticada, nunca una URL pública.

## E-10 · Exportación por evento

**Trazas:** `REG-09`–`REG-13`, `REL-08`.

- Exportar abre XLSX/CSV con XLSX inicial.
- Elegir evento produce exclusivamente datos locales de ese owner/evento,
  incluidos pendientes; “Todos los eventos” exige elegir uno.
- La elección de evento es de una sola acción: la fila completa es táctil y no
  muestra un indicador circular de selección múltiple.
- Las trece columnas aparecen en el orden de `REG-11`, con vacíos como celda
  vacía, encabezados ES/EN y fecha local con offset.
- CSV usa BOM UTF-8 y escaping RFC 4180; XLSX es un archivo real. Ambos
  preservan Unicode, omiten medios/IDs/estado técnico y se comparten mediante
  la hoja del sistema con el filename de `REG-12`.

## E-11 · Trial y suscripción

**Trazas:** `MON-01`–`MON-08`, Constitución Art. 9.

- Leads 1–5 se guardan; el sexto conserva borrador y abre paywall.
- Reinstalar no reinicia contador server-side.
- Webhook/autoridad remota activa captura ilimitada y la caché permite operar
  offline a una persona ya suscrita.
- Vencimiento bloquea solo nuevas capturas; datos previos siguen visibles,
  editables y exportables.
- La construcción queda bloqueada por `D-01`–`D-04`.

## E-12 · Shell, idioma, seguridad y salida

**Trazas:** `NAV-01`–`NAV-07`, `RNF-01`–`RNF-08`, `RC-01`–`RC-05`,
`REL-01`–`REL-08`.

- Drawer derecho, logo Inicio, tema e idioma operan con un solo producto, sin
  textos, insignias o destinos Basic/Pro.
- ES↔EN y claro↔oscuro actualizan todas las superficies con contraste y estado
  no dependiente solo de color.
- Texto de negocio con caracteres Unicode sobrevive sin sustitución al ciclo
  Drift → outbox → API/PostgreSQL → pull → Drift y vuelve a renderizarse igual.
- El binario no expone secretos; medios requieren acceso autorizado.
- El bucket de medios bloquea acceso público, cifra en reposo, exige TLS y no
  entrega credenciales AWS ni URLs firmadas persistentes al cliente.
- Matriz iOS/Android, pruebas reales offline/OCR/pago, legales, tiendas y beta
  satisfacen cada REL antes de declarar V1 lista.

## E-13 · Fundación backend y aislamiento cloud

**Trazas:** `AUT-10`, `SYN-06`, `SYN-10`, `INF-01`, `INF-03`, `INF-05`–`INF-14`, `RC-03`.

- Una solicitud sin JWT Cognito válido no llega a una ruta `/v1` protegida; la
  Lambda rechaza además cualquier evento sin `sub` verificado.
- En la primera solicitud autenticada se obtiene la cuenta/workspace personal
  del `sub`; solicitudes posteriores recuperan la misma identidad técnica.
- El usuario A no puede leer o mutar eventos, leads o metadata del workspace B,
  aunque envíe sus UUID en path/body. Owner, workspace, `sub` y email del body
  nunca deciden autorización.
- UUID creados offline se conservan al crear recursos. Repetir la misma
  creación con igual clave/payload retorna el mismo resultado; reutilizar la
  clave con otro payload responde conflicto.
- Payload inválido recibe 400; ausencia de identidad 401; falta de acceso 403;
  recurso ajeno/no visible 404; conflicto de versión/idempotencia 409. La
  respuesta contiene código, mensaje seguro y requestId.
- RDS queda en subred privada, sin dirección pública, y su puerto 5432 solo
  admite el Security Group de Lambda. DEV no crea NAT ni RDS Proxy.
- Guardar local en Drift continúa sin depender de esta API; FL-014 no activa
  sincronización ni subida de binarios.
