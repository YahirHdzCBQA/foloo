# 02 · Escenarios de aceptación — Foloo V1

Cada escenario cubre el producto unificado. No existe una variante por edición.

## E-01 · Alta, confirmación, sesión y perfil

**Trazas:** `AUT-01`–`AUT-17`, `AUT-22`–`AUT-24`, `SYN-09`, `SAL-08`, `SAL-09`.

- Dado un email nuevo, al registrarse con contraseña, entonces Cognito envía un
  código de seis dígitos y la app solicita confirmación sin pedir perfil.
- Login y Crear cuenta ofrecen email/contraseña, Google y Sign in with Apple
  (`AUT-22`). Microsoft Sign-In no aparece deshabilitado ni como opción futura;
  solo un build de validación DEV con `FOLOO_MICROSOFT_SIGNIN=true` lo muestra
  (`AUT-17`, `AUT-23`). Apple entra por Cognito, el owner es el `sub` y un
  correo relay de Apple no une cuentas. Si un proveedor no está configurado, su
  botón muestra un error recuperable ES/EN y los demás métodos siguen
  funcionando (`AUT-24`). Google solicita selección de
  cuenta en cada acción explícita, autentica mediante Cognito y omite el código
  manual; su OAuth nunca se reutiliza como conexión sender.
- El alta email/password acepta Gmail, Outlook, Hotmail y dominios empresariales
  válidos admitidos por Cognito. La contraseña creada pertenece a Foloo y no es
  la contraseña del proveedor del correo.
- Código inválido/vencido, reenvío, usuario confirmado, red y error inesperado
  se expresan en ES/EN sin texto AWS crudo.
- Login válido restaura el `sub`; perfil incompleto abre Tu perfil vacío, sin
  Yahir/CBQA u otra identidad demo, y perfil completo abre Inicio.
- En identidad Google federada, `username` técnico, atributo `email` y `sub`
  permanecen separados: la UI muestra `email`, nunca `google_*`, mientras
  ownership continúa usando exclusivamente `sub`.
- Al completar un perfil nuevo se ofrece una cuenta de envío Google/Microsoft.
  Si Auth fue federado, “Usar la cuenta con la que te registraste” abre un OAuth
  sender independiente del mismo proveedor; Auth por contraseña no infiere
  proveedor. Conectar u omitir permite continuar; omitir no bloquea Leads ni
  reaparece cada inicio. Usuarios con perfil previo no repiten onboarding y la
  disposición local de este paso nunca suplanta el estado OAuth.
- El menú muestra la foto durable del perfil y el email canónico de Auth; sin
  foto usa iniciales y al cambiar de `sub` no conserva la identidad anterior.
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

**Trazas:** `CAP-01`–`CAP-06`, `OCR-01`–`OCR-10`.

- Cámara o galería ejecutan ML Kit local y precargan solo valores reconocidos.
- Correcciones manuales no se sobrescriben sin acción explícita.
- Tarjeta ilegible deja todos los campos manuales disponibles.
- Foto puede reprocesarse, reemplazarse o quitarse antes de guardar.
- La captura conserva cuatro pasos en un scroll, progreso superior y CTA fijo.
- Guardar con faltantes desplaza al primero y lo identifica sin perder datos.
- Cámara de tarjeta pide permiso solo al tocar cámara. Denegación temporal puede
  reintentarse; bloqueo/restricción ofrece Ajustes. Al volver se revalida sin
  abrir cámara, mientras galería y captura manual siguen disponibles. Cancelar,
  cámara ausente, archivo inválido y OCR fallido nunca se presentan como el
  mismo error. Android recupera una selección perdida sin duplicarla.

## E-04 · Voz, texto e imágenes de referencia

**Trazas:** `CAP-07`, `CAP-08`, `OCR-10`, `VOZ-01`–`VOZ-08`.

- Grabar muestra onda/tiempo, detener no usa micrófono y después permite
  reproducir, borrar o regrabar.
- Micrófono se solicita solo al intentar grabar. Una denegación temporal permite
  reintento; bloqueo permanente/restricción ofrece Ajustes y continuar con nota
  escrita. Al volver se revalida sin iniciar grabación automáticamente; voz y
  texto siguen siendo opcionales.
- Una sesión de cámara acepta una, dos o tres imágenes y finaliza con ✓; si ya
  existen dos solo agrega una. Galería respeta el mismo máximo.
- Cámara de referencias y foto de perfil usan el mismo contrato de permiso,
  Settings, revalidación y errores que la tarjeta, sin pedir CAMERA para galería.
- La recuperación de imágenes perdidas de `image_picker` se ejecuta únicamente
  en Android; entrar a Perfil/Captura en iOS sin imagen es un estado normal y no
  muestra error ni inicia cámara.
- Guardar y reabrir conserva voz e imágenes. V1 no muestra transcripción.
- Una voz detenida pero todavía no guardada sobrevive navegación temporal a
  otra sección o al navegador OAuth y reaparece al volver; cancelar/descartar
  sí elimina explícitamente ese borrador privado.

## E-05 · Guardado local y acuse

**Trazas:** `CAP-09`–`CAP-12`, `SYN-01`.

- Al guardar, Lead y medios existen en Drift/storage privado antes de cualquier
  intento remoto.
- Si la escritura local falla, no se muestra éxito y el formulario permanece.
- El acuse informa únicamente estados reales, permite volver ahora y vuelve
  automáticamente a los siete segundos conservando origen/evento.
- El intento de guardar el sexto Lead conserva el borrador y abre paywall.

## E-06 · Registros y detalle editable

**Trazas:** `REG-01`–`REG-08`, `REG-15`–`REG-18`, `SAL-10`.

- “Todos” muestra la vista general; “Todos los eventos” incluye únicamente
  orígenes event y “Leads directos” únicamente origen direct. Elegir un evento
  filtra y actualiza conteos sin cambiar el evento activo.
- Búsqueda, tipo y orden funcionan offline sobre Drift.
- El renglón comunica interés, voz, correo y sync; correo usa icono accesible
  entre voz y sync para no enviado/pendiente/enviando/enviado/error/por confirmar.
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
- Swipe revela Correo o Eliminar sin ejecutar por el gesto; Correo abre Review
  incluso sin envío previo y Eliminar exige confirmación. Ambas acciones son
  accesibles también desde el detalle.
- Confirmar eliminación oculta inmediatamente el Lead offline, conserva su
  media/historial, encola tombstone y evita resurrección tras pull o reinicio.
- Después de Contenido compartido, Seguimiento reutiliza la fuente Drift como
  tarjeta compacta de contacto/correo/estado; tocarla abre snapshot, adjuntos,
  estado/causa real y retry/reenvío. Correo no duplica lista.

## E-07 · Contenido PDF y asignación

**Trazas:** `CON-01`–`CON-13`, `EVT-11`.

- Biblioteca vacía muestra el estado aprobado y Subir PDF abre archivos.
- Solo PDF avanza a nombre visible y selección buscable de eventos.
- Todos los eventos domina sin borrar selecciones individuales.
- Todos los eventos sigue siendo semántica exclusiva de Evento. Un Lead directo
  inicia sin Content preseleccionado, permite elegir explícitamente cualquier
  PDF activo y conserva esa selección offline en su snapshot local.
- Editar abre nombre visible y asignaciones actuales en un mismo flujo. Guardar
  persiste ambos local-first y encola sync sin renombrar el archivo físico;
  cancelar no cambia nada. Las selecciones futuras leen el nombre vigente y
  los snapshots históricos conservan el nombre congelado.
- Swipe derecha abre el mismo editor de asignaciones y swipe izquierda revela
  Eliminar sin ejecutar por gesto; el menú accesible ofrece ambas acciones sin
  depender del swipe.
- Crear evento permite seleccionar contenido existente o iniciar PDF.
- Biblioteca y Crear evento explican brevemente la relación Content → Evento →
  adjunto; el modal conserva scroll, aire y Subir contenido accesible.
- Adjuntos elegidos quedan congelados por Lead y un PDF atascado no bloquea
  Leads.
- El PDF de hasta 25 000 000 bytes se copia a almacenamiento privado antes de
  encolarse, se abre offline desde esa copia y no se desaloja automáticamente.
  Un archivo mayor, inválido o sin espacio disponible se rechaza con error ES/EN.
- Upload/confirmación a S3 y descarga autenticada usan URLs temporales sin
  persistirlas; un retry conserva identidad y copia local. El borrado lógico
  deja de ofrecer el Content activo y no borra S3 ni adjuntos históricos.
- Email Review de un Lead directo muestra exactamente los Content seleccionados
  y los congela con las mismas reglas de Evento, sin envío automático.

## E-08 · Plantillas y correo

**Trazas:** `PLT-01`–`PLT-13`, `SAL-01`–`SAL-11`, `RC-01`, ADR-006/007.

- Event/Direct ES/EN eligen por origen estructurado; asunto, cuerpo y firma
  editados sobreviven reinicio y cambio de cuenta. Preview del Lead real no envía.
- Sin plantilla persistida, el asunto inicial es `Damos seguimiento, {nombre}`
  en ES y `Following up, {nombre}` en EN, renderizado con el nombre real. Una
  plantilla personalizada o un follow-up histórico congelado no se reescriben.
- Evento resuelve override propio → predeterminada del vendedor → default Foloo;
  Directo omite el nivel Evento. Restaurar Foloo solo cambia el editor hasta
  Guardar; “Usar plantilla predeterminada” elimina el override y recupera
  herencia viva. Ninguna edición de plantilla crea preparación o envío.
- El override de Evento reutiliza los mismos chips, rayo, selector, inserción al
  cursor y validación ES/EN de Correo; guardar/cancelar y reabrir el sheet no
  deja overlays ni controladores desmontados, y persiste solo para ese evento.
- Solo los nueve tokens `PLT-03` se guardan; tokens desconocidos o llaves
  incompletas se rechazan. Datos históricos ausentes nunca producen tokens
  literales, `null`, `undefined` ni información inventada. `{contenido}` usa
  el snapshot histórico del Lead y representa varios PDF con nombres humanos.
- Todas las variantes base ES/EN de Evento/Directo generan un `<p>` por bloque,
  reservan `<br>` para saltos internos como la firma y controlan el margen
  inline; no combinan párrafos con `<br>` vacíos que multipliquen el espacio en
  Gmail, Outlook u otros clientes comunes.
- Tocar un token lo inserta en la selección/caret del asunto o cuerpo que tenga
  el foco (y en el último campo activo si el teclado perdió foco), sin borrar
  texto adyacente ni moverlo siempre al final.
- FL-019.5 no genera footer/enlace de baja, no expone GET/POST unsubscribe ni
  crea nuevos bloqueos por destinatario. Migraciones/tablas históricas se
  preservan y la decisión no se presenta como cumplimiento legal.
- Al confirmar, backend obtiene el nombre del perfil owner/workspace y congela
  `{nombre} - Foloo` en la intención; nombre vacío o inseguro congela `Foloo`.
  Gmail lo codifica en MIME y Graph lo solicita como `from.emailAddress.name`
  sin cambiar la dirección autorizada. Retry mantiene el snapshot, reenvío
  manual toma el nombre vigente e intenciones históricas nulas usan `Foloo` sin
  recalcular. La representación final en Gmail/Outlook es best effort.
- Guardar Lead confirma primero la persistencia local y abre “Revisar” con
  destinatario no editable, texto concreto sin tokens y todos los adjuntos
  seleccionados. Antes de `foloo`, Back → editar Lead → Guardar actualiza la
  misma preparación: A+B puede pasar a A o volver a A+B, Records refleja esa
  selección y nombre/apellido/empresa/puesto/evento/lugar rerenderizan asunto y
  cuerpo. Asunto y cuerpo detectan edición manual por separado. Un literal
  agregado (por ejemplo `❤️`) se conserva, pero los segmentos procedentes de
  los nueve tokens se actualizan con el Lead vigente; otra aparición literal
  coincidente con el valor anterior no se reemplaza globalmente. Destinatario y
  adjuntos también se reconcilian, incluso offline y tras reabrir la app. No se
  duplica Lead ni preparación; solo `foloo` congela el follow-up y crea la
  intención.
  Con teclado visible, la revisión sigue siendo desplazable, conserva la
  edición y mantiene el CTA accesible; tap fuera o drag descartan el teclado.
  Falta de email se muestra sin crear envío imposible. Confirmación online
  refleja la respuesta real del proveedor; offline persiste la intención y la
  outbox la reanuda al recuperar señal, incluso tras reinicio.
- Pendiente/Enviando/Enviado/Error/Estado por confirmar se muestran con texto,
  sin equiparar aceptación a entrega. Timeout ambiguo tras posible aceptación
  jamás reintenta solo; nuevo intento exige advertencia/decisión. Un reenvío
  manual posterior es una intención distinta del retry técnico.
- Seguimientos se ordena por fecha descendente y cada renglón identifica Lead,
  destinatario, Evento/Lugar, fecha, asunto y estado mediante texto e icono;
  el color es apoyo visual y nunca el único indicador.
- Cinco ciclos Capture → Revisar → Back conservan un único Lead y una única
  preparación activa. Back conserva los literales editados manualmente y la
  semántica durable de las variables por campo, reconcilia los demás datos
  fuente y la Voice Note usa su path definitivo reproducible.
  La intención nace solo al pulsar `foloo`; desde ahí cambios posteriores de
  Lead, Content o plantilla no reescriben el snapshot histórico.
- Mientras Correo permanece visible, cambios persistidos en Drift actualizan
  conexión/templates sin polling; el historial reactivo vive en Registros.
- Adjuntos congelados se validan en backend. PDF borrado/no disponible o exceso
  de tamaño no se omite en silencio: el vendedor decide omitirlo para esa
  intención o cancelar. El Lead y su snapshot no cambian.
- Google conecta por OAuth sin cambios y Microsoft conecta cuentas personales
  compatibles —como Outlook o Hotmail— con least privilege. Antes del OAuth de
  Microsoft, onboarding y Correo informan que cuentas empresariales, educativas
  o administradas por una organización no están soportadas en esta versión; la
  aclaración no deshabilita el botón ni se presenta como error. Sin conexión o
  con autorización revocada hay CTA de conectar/reconectar sin perder datos. Un
  pendiente de identidad anterior requiere confirmar el nuevo remitente. Los
  envíos históricos mantienen su remitente efectivo y ninguna cuenta B accede
  a conexión, plantilla o follow-up de A.
- Correo consulta el backend al abrirse y al volver del navegador. Con conexión
  muestra proveedor, dirección enmascarada y estado; jamás infiere conexión por
  haber tocado OAuth ni reutiliza el estado visual de otro `sub`.
- Conectar o cambiar la cuenta de envío abre el selector de cuentas del
  proveedor; cambiar identidad conserva el historial y exige la confirmación
  prevista por `SAL-09` antes de usarla para un pendiente previo.
- Microsoft Graph `202 Accepted` sin cuerpo se registra como Enviado/aceptado,
  no como respuesta perdida. El historial nunca vuelve a mostrar variables de
  plantilla crudas después de reconciliar con backend.
- Review muestra Asunto/Mensaje/Firma con lápiz y edición inline sin crear
  intención hasta `foloo`. Templates representan tokens internos como chips
  humanos; rayo inserta en cursor, tocar chip reemplaza ese segmento y preview
  vivo nunca muestra llaves técnicas.

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

## E-10 · Exportación por evento o Leads directos

**Trazas:** `REG-09`–`REG-13`, `REL-08`.

- Exportar abre XLSX/CSV con XLSX inicial.
- Elegir evento produce exclusivamente datos locales de ese owner/evento;
  elegir Leads directos incluye únicamente origen Directo. Ambos incluyen
  pendientes, funcionan offline y una vista agregada exige elegir un alcance.
- La elección de evento es de una sola acción: la fila completa es táctil y no
  muestra un indicador circular de selección múltiple.
- Las trece columnas aparecen en el orden de `REG-11`, con vacíos como celda
  vacía, encabezados ES/EN y fecha local con offset.
- CSV usa BOM UTF-8 y escaping RFC 4180; XLSX es un archivo real. Ambos
  preservan Unicode, omiten medios/IDs/estado técnico y conservan Compartir
  mediante la hoja del sistema con el filename de `REG-12`.
- En Android 10+, Guardar en dispositivo abre el selector nativo, propone el
  filename y MIME correctos, no solicita acceso amplio al almacenamiento y
  distingue éxito, cancelación y error sin inventar una ubicación.
- El retorno del share sheet muestra éxito genérico; solo diferencia
  cancelación/destino cuando la plataforma lo reporta, sin inventar rutas.

## E-11 · Trial y suscripción

**Trazas:** `MON-01`–`MON-12`, `MON-14`–`MON-20`, Constitución Art. 9.

- Leads 1–5 se guardan; el sexto conserva borrador y abre paywall.
- Evento y Directo consumen un uso histórico; borrar, tombstonear, reiniciar o
  logout/login no devuelve usos ni reinicia el contador.
- Con snapshot remoto 2/5, offline admite exactamente tres Leads adicionales;
  reservas Drift sobreviven restart y cada retry conserva identidad sin doble consumo.
- `active` permite creación ilimitada; `trial_exhausted` y `expired` abren un
  paywall informativo al intentar comenzar otra captura.
- El backend bloquea el sexto y serializa dos solicitudes concurrentes por el
  último cupo. El cliente no puede concederse `active` ni cambiar el contador.
- Vencimiento bloquea solo nuevas capturas; datos previos siguen visibles,
  editables y exportables.
- Dos dispositivos offline pueden reservar sobre el mismo snapshot. Al volver,
  el servidor acepta solo su saldo; Foloo conserva cualquier excedente local y
  lo marca recuperable, nunca lo borra.
- D-01–D-04 bloquean compra y lifecycle comercial, no la foundation FL-020.
- En un build FL-020.5 con Unlimited QA habilitado tanto en Flutter como en el
  backend DEV, una cuenta con 0, 5 o 10 Leads puede guardar y sincronizar otro
  Lead manual u OCR, online u offline, sin paywall ni saldo engañoso. El estado
  comercial y `trialLeadsUsed` no cambian.
- Sin ambos opt-ins, el sexto Lead vuelve a conservar el borrador y abrir el
  paywall original. Desactivar Unlimited nunca borra ni oculta los Leads ya
  creados; antes de apagar el backend se sincroniza la cola QA pendiente.
- (`MON-14`) Con `trial_exhausted` o `expired`, el aviso de la app explica que
  se alcanzó el límite y que la cuenta se administra en la web; no muestra
  precio, pagar/comprar/upgrade/suscribirse, botón ni enlace.
- (`MON-15`) Checkout con JWT válido crea la sesión para la cuenta del `sub`;
  cuenta, precio o URLs enviados en el cuerpo se ignoran. Dos intentos
  concurrentes reutilizan un solo customer de Stripe.
- (`MON-16`) Un webhook con firma válida sobre el cuerpo crudo (también en
  base64) activa solo la cuenta de `client_reference_id`; firma ausente,
  alterada o vieja responde 400 sin escribir. Entregas repetidas o
  concurrentes aplican una sola vez; si la transacción falla, el reintento
  aplica. `customer.subscription.deleted` vence la cuenta sin borrar ni ocultar
  Leads; eventos fuera de orden no reviven una cuenta vencida.
- (`MON-17`) Portal abre con el customer de la cuenta autenticada; sin customer
  responde 404.
- (`MON-18`) Sin Price ID el backend responde 503 `billing_not_configured` y no
  crea cobros; sin firma rechaza antes de leer secretos; synth falla si billing
  está habilitado sin precio, URLs o nombres de secretos.
- (`MON-19`) Una cuenta `active`, o con suscripción viva en Stripe aunque el
  estado local esté atrasado, recibe 409 con indicación de Portal en vez de
  otro Checkout.
- (`MON-20`) No existe compra nativa en la app; la variante queda Proposed.

## E-12 · Shell, idioma, seguridad y salida

**Trazas:** `NAV-01`–`NAV-07`, `RNF-01`–`RNF-08`, `RC-01`–`RC-05`,
`REL-01`–`REL-08`.

- Drawer derecho, logo Inicio, tema e idioma operan con un solo producto, sin
  textos, insignias o destinos Basic/Pro.
- Desde “¿Dónde estás conectado hoy?” el Drawer permite consultar Registros,
  Contenido, Mis eventos o Correo sin seleccionar Evento/Lead Directo ni iniciar
  captura. Esos cuatro módulos usan título izquierdo y el mismo Drawer a la
  derecha; alternarlos repetidamente reutiliza el shell sin apilar rutas.
- ES↔EN y claro↔oscuro actualizan todas las superficies con contraste y estado
  no dependiente solo de color.
- El estado En línea muestra punto verde y Sin conexión punto rojo; ambos
  conservan texto y semántica accesible y no se comportan como botones.
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

## E-14 · Eliminación integral de cuenta

**Trazas:** `AUT-18`–`AUT-21`, `SYN-11`, `SYN-12`, `MON-13`,
`INF-15`–`INF-21`, `RNF-09`, `RNF-10`, `RC-06`–`RC-10`, `D-13`,
`REL-01`, `REL-06`, `REL-07`, `DEC-AD-01`–`DEC-AD-14` y ADR candidatas
`ADR-AD-01`–`ADR-AD-06`.

**Precondiciones:** cuenta Cognito autenticada y datos sintéticos owner-scoped;
políticas Legal/Seguridad/Infra/Payments aplicables aprobadas antes de ejecutar
pruebas destructivas. La ruta pública web usa una cuenta sintética y el mismo
backend que Android/iOS.

- Android, iOS y la página pública permiten llegar al mismo preflight. Offline
  no crea una solicitud ni muestra aceptación; conocer un email o usar soporte
  no autoriza eliminar.
- El preflight muestra alcance, operaciones locales pendientes, exportación
  opcional, límites externos y estado PRO disponible. **Sincronizar primero**
  conserva el flujo normal; continuar sin sincronizar exige consentimiento
  explícito y no presenta la exportación como requisito.
- Sin evidencia Cognito reciente el backend rechaza la confirmación y solicita
  reautenticación. Credenciales o un booleano enviados por el cliente nunca
  sustituyen esa verificación. El valor productivo de frescura se prueba solo
  después de la aprobación de Seguridad.
- Confirmar crea atómicamente una única solicitud y su barrera. Dos taps, dos
  dispositivos o la misma idempotency key devuelven esa solicitud, sin doble
  cancelación, revocación, borrado o receipt. Abandonar el preflight no bloquea
  la cuenta; después de `requested` no existe cancelación ni recuperación.
- Desde `requested`, tokens antiguos, callbacks OAuth, replays, pulls, sync y
  toda mutación reciben `account_deletion_pending` antes de resolver o crear un
  workspace. Ningún dispositivo puede reprovisionar la cuenta.
- El orquestador congela el inventario, cancela renovaciones PRO cuando exista
  un proveedor aprobado, revoca OAuth, elimina/verifica S3 y PostgreSQL y
  finaliza Cognito al último. Fallos parciales reintentan solo su etapa,
  conservan la barrera y pasan a `blocked` con escalamiento; nunca se informa
  `completed` prematuramente.
- La purga móvil elimina Drift, outbox y archivos gestionados únicamente del
  owner borrado. Conserva intactos otro owner y filas legacy sin owner; un
  fallo de filesystem conserva un manifest reintentable y no sigue paths fuera
  del storage privado Foloo.
- `completed` requiere conteos cero para datos eliminables, objetos S3 ausentes,
  OAuth inutilizable y Cognito no encontrado, salvo categorías retenidas bajo
  política aprobada y aislada. El receipt permite consultar estado sin exponer
  email, `sub`, tokens, paths, object keys o IDs internos.
- El proceso comienza cuanto antes y, a más tardar al día 15, termina en
  `completed` o `blocked` con incidente escalado. Publicar ese máximo como SLA
  espera validación regional de Operación/Legal.
- Durante 30 días, email/password y Google con una identidad equivalente son
  rechazados sin revelar historial. Después se crea `sub`, account y workspace
  nuevos, sin datos, PRO, conexiones o beneficios anteriores; la elegibilidad
  de trial usa la política que Producto/Legal aprueben.
- Restaurar un snapshot PostgreSQL anterior no reabre cuenta, workspace,
  callbacks ni sesiones: antes de tráfico se reaplica el ledger vigente. La
  expiración ordinaria de backups se comprueba contra el plazo aprobado; la
  propuesta de 15 días no se prueba como política mientras `D-13` siga abierta.
- Los avisos ES/EN distinguen solicitud, trabajo en curso, bloqueo y
  finalización; explican copias externas y retenciones aprobadas sin prometer
  eliminar datos fuera del control de Foloo.

## Evidencia de cierre FL-020.6

El 2026-10-16 el responsable de QA reportó aprobados en dispositivos físicos
los branches afectados de E-03, E-04 y E-08: permisos/captura multimedia en
iPhone y tablet Android, y nombre visible del remitente mediante Gmail y
Outlook. Android usó el APK Release `1.0.0+8`, package `com.foloo.foloo`,
firmado con el mismo certificado de Build 7 y conectado a AWS DEV con Unlimited
QA. Esta evidencia cierra FL-020.6, no cierra los criterios globales `REL-*`, no
resuelve `D-05`, `D-06` o `D-11` y no declara FL-021/FL-022 implementadas.
