# 05 · Especificación funcional — Foloo Pro (delta)

> **Este documento es un delta, no una especificación completa.**
> Todo lo definido en `01-especificacion.md` aplica íntegro a Pro. Aquí solo está lo que **se agrega** o **se modifica**.
> Si algo no aparece en este archivo, se comporta exactamente como en Basic.
> La frontera entre versiones vive en `04-matriz-de-capacidades.md`, no en el texto de los requerimientos.

---

## 1. Qué agrega Pro y por qué

Basic resuelve **capturar**: que ningún lead se pierda. Basic no envía nada — el seguimiento lo hace una persona a mano, desde la hoja de cálculo.

**Pro es donde el producto empieza a responder solo.** Toda la salida hacia el lead vive aquí.

La frase que se dice cien veces en una expo es *"ahorita te mando la información"*. Con Basic, alguien tiene que acordarse el lunes. Con Pro, el correo sale solo, **con la información adjunta**, elegida en el momento, antes de que el vendedor salga del piso.

| Bloque nuevo | Problema que resuelve |
|---|---|
| **Correos automáticos** | Nadie se acuerda el lunes. En Basic el seguimiento depende de que una persona abra la hoja. |
| **Contenido** | El vendedor prometió una ficha técnica. Sin esto la manda tarde, o no la manda. |
| **Plantillas de correo** | El mensaje lo controla quien lo firma, sin depender del desarrollador para cambiar una línea. |
| **Transcripción** | La nota de voz es rápida de grabar y lenta de consumir. Marketing no va a escuchar 40 audios. |
| **Lugar en lead directo** | Un lead fuera de evento no tiene "evento" que citar en el correo. Sin ese dato el mensaje suena genérico. |

**Cambio de métrica.** La meta de "100% de las tarjetas con contacto antes de 24 horas" — la que originó el proyecto — solo es alcanzable por el producto en Pro. Basic garantiza que el dato esté; Pro garantiza que salga. Ver `D-13`.

---

## 2. Cambios en el modelo de datos

### 2.1 Entidad nueva: Archivo de contenido

| Campo | Tipo | Obligatorio | Origen |
|---|---|---|---|
| `id` | texto | sí | generado |
| `nombreMostrar` | texto | sí | usuario — es lo que ve el lead en el correo |
| `nombreArchivo` | texto | sí | del archivo original (ej. `scanley-ims.pdf`) |
| `mime` | texto | sí | sistema — solo `application/pdf` en v1 |
| `bytes` | número | sí | sistema |
| `url` | enlace | sí | subida al servidor |
| `rutaLocal` | texto | no | caché en el dispositivo |
| `todosLosEventos` | booleano | sí | usuario — interruptor maestro |
| `eventos` | lista de `eventoId` | no | usuario — se ignora si `todosLosEventos = true` |
| `subidoPor` | `usuarioId` | sí | sistema |
| `fechaAlta` | fecha y hora ISO | sí | sistema |

**Relación:** un archivo aplica a muchos eventos; un evento tiene muchos archivos. `todosLosEventos` es un atajo que **sustituye** la lista, no la complementa: cuando está activo, la selección individual se ignora y así se le dice al usuario en pantalla ("Ignora la selección de abajo").

### 2.2 Entidad nueva: Plantilla de correo

| Campo | Tipo | Obligatorio | Origen |
|---|---|---|---|
| `id` | texto | sí | generado |
| `tipo` | `evento` \| `directo` | sí | sistema — exactamente dos plantillas por cuenta |
| `asunto` | texto | sí | usuario |
| `cuerpo` | texto largo | sí | usuario |
| `fechaEdicion` | fecha y hora ISO | sí | sistema |
| `editadaPor` | `usuarioId` | sí | sistema |

### 2.3 Cambios en la entidad Lead

| Campo | Cambio | Nota |
|---|---|---|
| `lugar` | **nuevo** · texto · obligatorio si `origen = directo` | Dónde surgió la conversación. Sustituye `{lugar}` en la plantilla |
| `transcripcion` | **nuevo** · texto largo · opcional | Resultado del servidor sobre el audio ya subido |
| `adjuntos` | **nuevo** · lista de `archivoId` · opcional | Los archivos que efectivamente se enviaron con ese lead |
| `estadoTranscripcion` | **nuevo** · `pendiente` \| `lista` \| `noDisponible` | El lead se guarda antes de que exista transcripción |
| `estadoCorreoLead` | **nuevo** · `enviado` \| `enCola` \| `fallido` | No existe en Basic |
| `estadoCorreoMarketing` | **nuevo** · `enviado` \| `enCola` \| `fallido` | No existe en Basic |

**Orden de columnas en la hoja.** Los cinco campos nuevos se **agregan al final** del orden definido en `01-especificacion.md` §3.2. Nunca se intercalan. Así, activar Pro sobre una cuenta que venía usando Basic no obliga a migrar ni una fila ya escrita (`SAL-12`).

**Congelado de adjuntos.** `adjuntos` guarda **qué se envió en ese momento**, no una referencia viva a la configuración del evento. Si mañana se quita un archivo del evento, el lead de ayer sigue diciendo la verdad sobre lo que recibió. Esto no es un detalle técnico: es la diferencia entre poder responder "¿qué le mandamos a Mariana?" y no poder.

### 2.4 Cambios en la entidad Evento

| Campo | Cambio |
|---|---|
| `archivos` | **nuevo** · lista de `archivoId` — la vista inversa de la relación |

---

## 3. Pantallas nuevas y modificadas

### 3.1 Nuevas — 5

| ID | Pantalla | Propósito |
|---|---|---|
| `P-17` | Contenido | Biblioteca de archivos. Cada renglón: icono, nombre para mostrar, archivo y peso, chips de eventos donde aplica, papelera. Encabezado con conteo total ("3 archivos · 4.9 MB") y selector de evento como filtro. Dock: "Subir PDF". |
| `P-18` | Subir contenido (hoja) | Se abre al elegir el PDF. Nombre para mostrar, "¿En qué eventos aplica?" con contador ("2 de 12"), buscador, interruptor "Todos los eventos" y lista con scroll propio. Cancelar / Subir. |
| `P-19` | Editar eventos del archivo (hoja) | Se abre al tocar un archivo. Buscador fijo, el evento activo primero bajo el rótulo "Evento activo", el resto bajo "Anteriores", contador de seleccionados en el dock, "Todos los eventos" como interruptor maestro con la aclaración "Ignora la selección de abajo". |
| `P-20` | Correo · plantilla de evento | Segmentado Evento / Lead directo. Asunto, cuerpo, chips de variables, previsualización con datos reales. Dock: "Guardar plantilla". |
| `P-21` | Correo · plantilla de lead directo | La misma pantalla con la otra plantilla. La variable `{evento}` se sustituye por `{lugar}`. |

### 3.2 Modificadas — 4

| ID | Pantalla | Qué cambia |
|---|---|---|
| `P-05` | Lead directo | Gana el campo **Lugar**, obligatorio, con la ayuda "Dónde surgió la conversación. Sustituye {lugar} en el correo; se guarda en tu base general de leads." |
| `P-06` | Crear evento | Gana el bloque "Contenido para este evento" con contador ("2 de 3") y lista de archivos con scroll propio. En el primer uso (`P-03`) el bloque es opcional y dice: "Puedes subirlo ahora o más tarde desde el menú. Sin contenido el correo de seguimiento sale igual, solo sin adjuntos." |
| `P-09` | Captura pasos 03–04 | El paso 03 gana **Contenido a compartir**. El paso 04 gana el bloque **Transcripción** y la etiqueta "Nota de voz (opcional)". |
| `P-10` | Acuse | Pasa de 3 a **4 confirmaciones**, con subtítulo de detalle en cada una. |
| `P-11` | Menú lateral | Gana los destinos **Contenido** y **Correo**. La insignia dice "Pro". |

---

## 4. Requerimientos — Contenido

| ID | Requerimiento | Prioridad |
|---|---|---|
| `CON-01` | Biblioteca de archivos accesible desde el menú. Cada renglón muestra nombre para mostrar, nombre de archivo, peso y los eventos donde aplica. El encabezado muestra el total de archivos y el peso acumulado. | Debe |
| `CON-02` | Subir un PDF desde el selector de archivos del sistema. Al elegirlo se pide un **nombre para mostrar** — es lo que verá el lead en el correo, no el nombre del archivo. | Debe |
| `CON-03` | Asignar un archivo a uno o varios eventos, con buscador y contador de seleccionados visible ("2 de 12"). La lista tiene scroll propio y no empuja el dock. | Debe |
| `CON-04` | Interruptor maestro "Todos los eventos". Cuando está activo, **ignora la selección individual** y así se lo dice al usuario. Al apagarlo, la selección previa se conserva. | Debe |
| `CON-05` | En el paso 03 de captura aparece **"Contenido a compartir"**: la lista de archivos del evento activo, marcados por defecto, desmarcables por lead. Debajo, el conteo exacto: "2 de 3 archivos de Expo Alimentaria se adjuntan al correo." | Debe |
| `CON-06` | La biblioteca se filtra por evento con un **selector**, no con píldoras. Con doce eventos las píldoras no caben y obligan a desplazamiento horizontal, que es el peor control para una mano. Cada opción del selector lleva su conteo. | Debe |
| `CON-07` | Eliminar un archivo de la biblioteca, con confirmación. Eliminarlo **no altera los leads ya enviados** ni sus adjuntos registrados. | Debe |
| `CON-08` | Al crear un evento se puede asignar contenido en el mismo paso, con contador. En el primer uso es opcional y se explica que el correo sale igual, solo sin adjuntos. | Debe |
| `CON-09` | Los archivos seleccionados se adjuntan al correo del lead. La variable `{contenido}` de la plantilla se sustituye por la lista de adjuntos. | Debe |
| `CON-10` | Los adjuntos enviados quedan **congelados en el registro del lead** (`adjuntos`). Cambiar la biblioteca después no reescribe la historia. | Debe |
| `CON-11` | Toda lista de eventos dentro del módulo de contenido debe funcionar con **12 o más eventos**: buscador fijo arriba, evento activo primero, contador en el dock, scroll propio. | Debe |
| `CON-12` | Los archivos se cachean en el dispositivo para poder consultarlos y adjuntarlos sin conexión. Copy: "Los archivos viven en tu teléfono y se adjuntan al correo cuando hay señal." | Debe |
| `CON-13` | Solo PDF en v1. Otros formatos se rechazan con un mensaje que dice qué se acepta, no un error genérico. | Debe |
| `CON-14` | Límite de peso por archivo y de peso total de la biblioteca, visible antes de subir. Ver `DP-02`. | Debe |
| `CON-15` | Editar los eventos de un archivo existente desde la biblioteca, sin volver a subirlo. | Debe |
| `CON-16` | Si un evento no tiene contenido asignado, la captura no muestra el bloque vacío: lo omite. Un bloque vacío en el paso 03 es un paso más que no aporta. | Debería |

**Restricción de arquitectura.** El texto de la interfaz dice que los archivos viven en el teléfono, y eso es cierto **para el vendedor**. Pero el correo lo manda el servidor (Artículo 3, `SAL-04`), así que el servidor necesita el archivo. La resolución es: **el archivo se sube una vez al servidor al agregarlo a la biblioteca; la copia local es caché**. El lead viaja con la lista de `archivoId`, nunca con los bytes. Ver `DP-01` — es el punto que más fácil se implementa mal.

---

## 5. Requerimientos — Correos automáticos

> **Esto no existe en Basic.** Todos los requerimientos de esta sección son nuevos en Pro. Conservan los identificadores `SAL-05` … `SAL-10` y su trazabilidad a la v1.0 del PDF (`RF-27` … `RF-32`) para que la referencia histórica no se pierda.

| ID | Requerimiento | Prioridad | Traza v1.0 |
|---|---|---|---|
| `SAL-05` | Al confirmar el registro se disparan dos correos: uno al lead y uno a la dirección de Copia Admin configurada. | Debe | RF-27 |
| `SAL-06` | El correo al lead sale con el nombre del remitente de la empresa (`capturadoPor`), no con una cuenta genérica sin identidad. | Debe | RF-28 |
| `SAL-07` | El correo a **Copia Admin** incluye todos los campos del lead, la nota escrita, la transcripción y el enlace al audio. Asunto filtrable: `[Tipo] Nombre · Empresa`. | Debe | RF-29 |
| `SAL-08` | Si un correo falla, el registro se guarda igual y el correo queda en cola de reintento. **Un correo caído nunca pierde el lead.** | Debe | RF-30 |
| `SAL-09` | Registrar el estado de envío de cada correo por lead — enviado, en cola o fallido — visible en la hoja y en el detalle de la conexión. | Debe | RF-31 |
| `SAL-10` | Las plantillas se editan sin tocar código. En Pro esto se resuelve con el editor dentro de la app (`PLT-01`), no con un archivo de configuración. | Debe | RF-32 |
| `SAL-13` | **El envío lo ejecuta el servidor.** La app nunca abre un cliente de correo ni compone un mensaje. Ninguna credencial de correo vive en el binario. | Debe | Art. 3 |
| `SAL-14` | El disparo del correo está atado a la escritura de la fila, no al toque de "Guardar". Un lead que aún no llega a la hoja no manda correos. | Debe | `SYN-04` |
| `SAL-15` | Verificar el peso de los adjuntos y el volumen del día contra los límites del proveedor **antes de enviar**, no después del rechazo. Ver `DP-02`. | Debe | nuevo |

**Contenido del correo al lead.** Asunto y cuerpo salen de la plantilla editable (§6). El pie legal — aviso de privacidad y opción de baja — se agrega siempre, fuera del cuerpo editable (`PLT-08`).

**Por qué el envío entra hasta Pro.** Fue decisión de los solicitantes, no una limitación técnica (`D-13`). La consecuencia para el desarrollo es concreta: el proveedor de correo transaccional, la cola de reintentos, los estados de envío y las plantillas **no se construyen para Basic**. Se construyen aquí, completos, de una sola vez.

---

## 6. Requerimientos — Plantillas de correo

| ID | Requerimiento | Prioridad |
|---|---|---|
| `PLT-01` | Editor de plantilla dentro de la app, accesible desde el menú. Asunto y cuerpo editables, con "Guardar plantilla" en el dock. | Debe |
| `PLT-02` | **Dos plantillas independientes**: una para leads de evento y otra para leads directos. Se alternan con un control segmentado. Guardar una no toca la otra. | Debe |
| `PLT-03` | La plantilla que se usa la determina el `origen` del lead, sin que el vendedor elija nada al capturar. | Debe |
| `PLT-04` | Chips con las variables disponibles, tocables para insertarlas en el cursor. Evento: `{nombre}`, `{empresa}`, `{evento}`, `{contenido}`, `{capturadoPor}`. Lead directo: las mismas, con `{lugar}` en lugar de `{evento}`. | Debe |
| `PLT-05` | Previsualización en vivo con los datos del **último lead capturado** de ese tipo, incluidos los adjuntos reales con su peso. Etiquetada como tal: "Con los datos del último lead capturado." | Debe |
| `PLT-06` | Validar antes de guardar que no haya variables inexistentes ni llaves sin cerrar. Un `{evnto}` mal escrito llega al lead como texto crudo. | Debe |
| `PLT-07` | La plantilla vive en el servidor, no en el binario. Editarla no requiere publicar una versión de la app. | Debe |
| `PLT-08` | El pie del correo conserva siempre el aviso de privacidad y la opción de baja (`RC-01`, `RC-02`), **fuera del cuerpo editable**. El usuario no puede borrarlos por accidente. | Debe |
| `PLT-09` | Si la plantilla nunca se ha editado, arranca con un texto por defecto funcional, no vacío. | Debe |
| `PLT-10` | Restaurar la plantilla por defecto en un toque. | Debería |

**Texto por defecto — plantilla de evento**

```
Asunto: Seguimiento · {evento}

Hola {nombre},

Gusto en coincidir en {evento}. Te comparto la información que platicamos:

{contenido}

Quedo al pendiente para lo que necesites.

Saludos,
{capturadoPor}
```

**Texto por defecto — plantilla de lead directo:** idéntico, sustituyendo `{evento}` por `{lugar}`.

---

## 7. Requerimientos — Transcripción

> Esto **invierte `D-01` para Pro**. La transcripción está fuera de Basic y dentro de Pro. La decisión de arquitectura correspondiente está en `DP-05`.

| ID | Requerimiento | Prioridad |
|---|---|---|
| `TRA-01` | Transcribir la nota de voz a texto en **español de México**. | Debe |
| `TRA-02` | La transcripción se hace **del lado del servidor** sobre el audio ya subido. Las APIs de dictado del sistema operativo dan resultados distintos en iOS y Android, y varias exigen conexión activa mientras se habla — en un recinto con mal wifi, eso significa perder la nota. El negocio necesita el mismo resultado en cualquier teléfono del equipo. | Debe |
| `TRA-03` | Es **asíncrona y nunca bloquea**: primero se guarda el lead con su audio, después se actualiza la transcripción. El acuse no espera a que exista. | Debe |
| `TRA-04` | La transcripción se muestra en el detalle de la conexión, bajo la nota de voz, con su propio rótulo. | Debe |
| `TRA-05` | Mientras no exista, el estado es visible y honesto: `pendiente` mientras se procesa, `noDisponible` si falló. Nunca un espacio en blanco sin explicación. | Debe |
| `TRA-06` | La transcripción **no sustituye a la nota escrita**. Ambas conviven y ambas viajan a la hoja y al correo a Copia Admin. | Debe |
| `TRA-07` | Si la transcripción falla, el lead queda completo e íntegro. Nunca se reintenta de forma que bloquee otra sincronización. | Debe |
| `TRA-08` | ¿La transcripción es editable? Ver `DP-06` — **no implementar hasta que se responda.** | — |

---

## 8. Modificaciones a requerimientos de Basic

Estos IDs ya existen en `01-especificacion.md`. En Pro cambian así:

| ID de Basic | Qué cambia en Pro |
|---|---|
| `CAP-03` | Lead directo gana el campo obligatorio **Lugar**. Ya no basta con la frase explicativa. |
| `CAP-13` | El botón principal dice `Guarda y da "foloo"` en lugar de "Guardar". |
| `CAP-17` | El acuse pasa de **1 a 4 confirmaciones**, cada una con subtítulo: fila y nombre de la hoja · correo al lead con su dirección · Copia Admin con su dirección · conteo de adjuntos con sus nombres. Basic solo confirma la fila, porque es lo único que hace. |
| `EVT-01` | Crear evento incorpora la asignación de contenido en el mismo paso. |
| `REG-06` | El detalle de la conexión incluye el bloque de transcripción. |
| `SAL-12` | Pro agrega cinco columnas a la hoja. Se **añaden al final**; el orden de Basic no se toca. |
| `NAV-03` | El menú gana **Contenido** (con contador de archivos) y **Correo**. |
| `VOZ-05` | La nota de voz se rotula explícitamente "(opcional)", porque ahora compite con la transcripción por la atención. |
| `VOZ-07` | **Se revoca en Pro.** La transcripción sí existe. Ver sección 6. |

### Requerimientos nuevos con numeración continua

| ID | Requerimiento | Prioridad |
|---|---|---|
| `CAP-20` | Campo **Lugar** en lead directo, obligatorio, con teclado de texto libre. Persiste entre capturas consecutivas del mismo lugar, igual que el evento activo (`CAP-04`). | Debe |
| `CAP-21` | El acuse muestra 4 confirmaciones con detalle verificable: la fila exacta de la hoja, la dirección de cada correo y los nombres de los archivos adjuntos. Sin conexión, las cuatro se muestran en cola. Ver `DP-07`. | Debe |
| `NAV-08` | Destinos nuevos en el menú: **Contenido** con contador de archivos y **Correo**. | Debe |
| `SYN-10` | La cola de sincronización maneja también archivos de la biblioteca pendientes de subir, separada de la cola de leads. Un PDF de 3 MB atorado no puede bloquear la subida de leads. | Debe |
| `SYN-11` | La idempotencia por folio (`SYN-04`) cubre los adjuntos: reenviar un folio no manda un segundo correo con los mismos archivos. | Debe |

---

## 9. Requerimientos no funcionales adicionales

| ID | Requerimiento |
|---|---|
| `RNF-14` | La app debe funcionar con **12 o más eventos** y con una biblioteca de al menos **20 archivos** sin degradación de listas, buscadores ni selectores. |
| `RNF-15` | Verificar el volumen esperado contra los límites del proveedor de correo **antes del evento**. Gmail gratuito permite ~100 envíos diarios y Workspace ~1,500; un evento grande supera eso con dos correos por lead, así que conviene evaluar un servicio transaccional (SendGrid, Amazon SES). El peso de los adjuntos se verifica además **antes de cada envío**: un correo rechazado por tamaño es un lead sin seguimiento. Ver `DP-02`. Este requerimiento reemplaza a `RNF-10` de la v1.0, que salió de Basic junto con el correo. |
| `RNF-16` | La caché local de archivos tiene tope y política de desalojo. La app no puede llenar el teléfono del vendedor en silencio. |
| `RNF-17` | La transcripción no forma parte de la ruta crítica de los 60 segundos. Su latencia no se mide contra `RNF-01`. |
| `RNF-18` | **Una sola base de código.** Basic y Pro son la misma app con capacidades habilitadas por el servidor. Ver `04-matriz-de-capacidades.md`, sección "Regla de construcción". |

---

## 10. Privacidad y cumplimiento — adiciones

| ID | Requerimiento |
|---|---|
| `RC-01` | **Se activa en Pro.** El correo al lead entrega el aviso de privacidad y explica por qué se le contacta: entregó su tarjeta en el evento X. Esto cierra el hueco que Basic dejó abierto (`D-14`). |
| `RC-02` | **Se activa en Pro.** El correo al lead incluye una forma clara de darse de baja, y la baja se respeta en la hoja y en envíos posteriores. |
| `RC-08` | La **transcripción es dato personal**: contiene lo que dijo el lead. Queda sujeta al mismo periodo de retención que el audio (`RC-03`) y al mismo control de acceso (`RC-04`). |
| `RC-09` | Los archivos de la biblioteca son material de la empresa, no datos personales. Aun así, los enlaces de descarga no deben quedar públicos por URL si contienen información comercial sensible. |
| `RC-10` | El aviso de privacidad y la opción de baja viven **fuera del cuerpo editable** de la plantilla (`PLT-08`). Un usuario no puede dejar la app en incumplimiento borrando una línea. |
| `RC-11` | Si el lead se da de baja, la baja aplica también a los correos con adjuntos. No hay excepción por "es información que pidió". |

---

## 11. Criterios de aceptación de Pro

Además de los 12 de Basic (`01-especificacion.md` §10), en un teléfono real:

13. Subir un PDF, asignarlo a 2 de 12 eventos con el buscador, y verificar que aparece marcado solo en esos dos.
14. Activar "Todos los eventos" en un archivo y comprobar que la selección individual queda ignorada y así se comunica.
15. Capturar un lead en un evento con 3 archivos, desmarcar uno, y confirmar que el lead recibe exactamente 2 adjuntos con los nombres para mostrar correctos.
16. Verificar que el correo llega con el asunto y el cuerpo de la plantilla editada, con todas las variables sustituidas y **ninguna llave cruda visible**.
17. Capturar un lead directo con Lugar "Oficinas de Grupo Lácteo" y confirmar que el correo usa la plantilla de lead directo con ese texto en asunto y cuerpo.
18. Grabar 30 segundos y comprobar que la transcripción aparece después en el detalle, sin que el acuse la haya esperado.
19. Con modo avión, capturar con adjuntos: el lead se guarda, el acuse muestra las 4 líneas en cola, y al recuperar señal el correo sale con sus adjuntos, una sola vez.
20. Eliminar un archivo de la biblioteca y comprobar que un lead enviado antes sigue mostrando qué recibió.
21. Editar la plantilla, escribir `{evnto}` mal y confirmar que el guardado se detiene con un mensaje que dice cuál variable no existe.
22. Comprobar que el aviso de privacidad y la baja siguen en el correo aunque el usuario haya reescrito todo el cuerpo.
23. Cargar una cuenta con 12 eventos y 20 archivos, y recorrer Contenido, Subir y Editar eventos sin desplazamiento horizontal ni listas que empujen el dock.
24. Iniciar sesión con una cuenta Basic en el mismo binario y confirmar que Contenido y Correo **no aparecen** en el menú, ni en gris, ni con candado, y que guardar un lead **no dispara ningún correo**.
25. Activar Pro sobre una cuenta que venía usando Basic y comprobar que las filas ya escritas en la hoja no se movieron: las columnas nuevas se agregaron al final.

Los escenarios paso a paso están en `06-escenarios-pro.md`.
