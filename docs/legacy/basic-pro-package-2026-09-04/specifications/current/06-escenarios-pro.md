# 06 · Escenarios de aceptación — Pro (delta)

> Los escenarios `E-01` a `E-13` de `02-escenarios-de-aceptacion.md` **aplican íntegros a Pro**, con tres ajustes:
> - `E-05` deja de tener el escenario "Sin transcripción" — en Pro se sustituye por `EP-05`.
> - `E-06` pasa de 1 a 4 confirmaciones en el acuse — ver `EP-06`.
> - `E-12` deja de tener el escenario "Basic no envía nada" — en Pro se sustituye por `EP-11`.
>
> Aquí solo están los escenarios nuevos.

---

## EP-01 · Biblioteca de contenido — `CON-01`, `CON-02`, `CON-06`, `CON-13`

```gherkin
Escenario: Subir un PDF con nombre para mostrar
  Dado que el vendedor está en Contenido
  Cuando toca "Subir PDF" y elige "catalogo-empaque-2026.pdf"
  Entonces se abre la hoja de subida
  Y ve el nombre del archivo y su peso
  Y puede escribir un nombre para mostrar distinto
  Cuando escribe "Catálogo de empaque 2026" y confirma
  Entonces el archivo aparece en la biblioteca con ese nombre
  Y el encabezado actualiza el conteo y el peso total

Escenario: Solo se aceptan PDF
  Cuando el vendedor intenta subir un archivo .docx
  Entonces se rechaza con un mensaje que dice qué formato se acepta
  Y no aparece un error genérico

Escenario: El filtro es un selector, no píldoras
  Dado que la cuenta tiene 12 eventos
  Cuando el vendedor abre Contenido
  Entonces el filtro por evento es un selector desplegable
  Y cada opción muestra su conteo de archivos
  Y no hay ninguna lista con desplazamiento horizontal
```

---

## EP-02 · Asignar archivos a eventos — `CON-03`, `CON-04`, `CON-11`, `CON-15`

```gherkin
Escenario: Asignar a 2 de 12 eventos con buscador
  Dado que la cuenta tiene 12 eventos
  Cuando el vendedor sube un archivo
  Entonces ve un buscador arriba de la lista de eventos
  Y el contador dice "0 de 12"
  Cuando busca y marca "Expo Alimentaria México" y "Expo Empaque Norte"
  Entonces el contador dice "2 de 12"
  Y la lista tiene scroll propio sin empujar el dock
  Cuando guarda
  Entonces el archivo aparece con esos dos eventos como chips en la biblioteca

Escenario: El activo va primero
  Cuando el vendedor abre "Editar eventos del archivo"
  Entonces el evento activo aparece primero, bajo el rótulo "Evento activo"
  Y el resto aparece debajo, bajo "Anteriores"

Escenario: Todos los eventos ignora la selección
  Dado un archivo asignado a 2 eventos
  Cuando el vendedor activa "Todos los eventos"
  Entonces la app dice explícitamente que ignora la selección de abajo
  Y el archivo aplica a los 12 eventos
  Cuando lo desactiva
  Entonces la selección previa de 2 eventos se conserva

Escenario: Editar sin volver a subir
  Cuando el vendedor toca un archivo existente en la biblioteca
  Entonces puede cambiar a qué eventos aplica
  Y no se le pide volver a elegir el archivo
```

---

## EP-03 · Contenido en la captura — `CON-05`, `CON-10`, `CON-16`

```gherkin
Escenario: Los archivos del evento vienen marcados
  Dado un evento con 3 archivos asignados
  Cuando el vendedor llega al paso 03 de captura
  Entonces ve "Contenido a compartir" con los 3 archivos marcados
  Y lee "3 de 3 archivos de Expo Alimentaria se adjuntan al correo."

Escenario: Desmarcar por lead
  Cuando el vendedor desmarca "CBQA General · Portafolio"
  Entonces el conteo dice "2 de 3 archivos de Expo Alimentaria se adjuntan al correo."
  Cuando guarda el lead
  Entonces el correo al lead lleva exactamente 2 adjuntos
  Y los nombres visibles son los nombres para mostrar, no los de archivo

Escenario: Evento sin contenido
  Dado un evento sin archivos asignados
  Cuando el vendedor llega al paso 03
  Entonces el bloque "Contenido a compartir" no aparece
  Y no hay un bloque vacío ocupando espacio

Escenario: Los adjuntos quedan congelados
  Dado un lead enviado con 2 adjuntos
  Cuando después se elimina uno de esos archivos de la biblioteca
  Y se abre el detalle de ese lead
  Entonces sigue mostrando los 2 archivos que efectivamente recibió
```

## EP-03A · Imágenes adicionales del contacto — `CAP-22`, `CAP-23`, `REG-13`

```gherkin
Escenario: Agregar, quitar y limitar imágenes antes de guardar
  Dado que el vendedor usa una cuenta Pro en el paso 04
  Entonces ve "Imágenes de referencia (opcional)" con contador "0 de 3"
  Cuando agrega tres imágenes desde cámara o galería
  Entonces ve las tres previsualizaciones y ya no puede agregar una cuarta
  Cuando quita una antes de guardar
  Entonces el contador dice "2 de 3" y vuelve a estar disponible Agregar

Escenario: Persistencia y consulta posterior
  Dado que un lead Pro se guardó con dos imágenes adicionales
  Cuando se cierra y abre de nuevo la base local
  Y se consulta el lead desde Registros
  Entonces el detalle muestra las dos imágenes
  Y tocar una abre su vista completa

Escenario: Capturar una, dos o tres fotos sin volver al formulario
  Dado que el vendedor abre "Tomar foto" sin imágenes adicionales previas
  Cuando captura una foto
  Entonces permanece en la sesión fotográfica y ve un indicador de una foto
  Y puede confirmar con ✓ o capturar otra
  Cuando captura una segunda y una tercera foto
  Entonces los indicadores muestran el total acumulado
  Y al llegar a tres no puede capturar una cuarta
  Cuando confirma con ✓
  Entonces vuelve a CaptureLead y ve las mismas previsualizaciones

Escenario: Completar posteriormente el espacio restante
  Dado que CaptureLead ya contiene dos imágenes adicionales
  Cuando el vendedor vuelve a abrir "Tomar foto"
  Entonces la sesión muestra que ya existen dos
  Y solo permite capturar una imagen adicional
  Cuando confirma
  Entonces CaptureLead contiene exactamente tres imágenes

Escenario: Basic no expone imágenes adicionales
  Dado el mismo binario con una cuenta Basic
  Cuando recorre toda la captura y el detalle
  Entonces no existe el bloque de imágenes adicionales
```

---

## EP-04 · Plantillas de correo — `PLT-01` … `PLT-10`

```gherkin
Escenario: Dos plantillas independientes
  Dado que el vendedor está en Correo
  Cuando alterna entre "Evento" y "Lead directo"
  Entonces ve dos plantillas distintas
  Y las variables cambian: {evento} en una, {lugar} en la otra
  Cuando edita y guarda la de evento
  Entonces la de lead directo queda intacta

Escenario: Previsualización con datos reales
  Dado un último lead capturado con 2 adjuntos
  Cuando el vendedor abre la plantilla de evento
  Entonces la previsualización muestra el nombre real del lead
  Y el asunto con el evento real sustituido
  Y los 2 adjuntos con su nombre y su peso
  Y una etiqueta que dice que son los datos del último lead capturado

Escenario: Variable mal escrita
  Cuando el vendedor escribe "{evnto}" en el asunto y toca "Guardar plantilla"
  Entonces el guardado se detiene
  Y el mensaje dice cuál variable no existe
  Y no se guarda una plantilla que enviaría llaves crudas al lead

Escenario: Insertar variable con un toque
  Cuando el vendedor toca el chip "{empresa}"
  Entonces la variable se inserta en la posición del cursor

Escenario: El pie legal no es editable
  Cuando el vendedor borra todo el cuerpo y guarda
  Y se envía un lead
  Entonces el correo sigue llevando el aviso de privacidad
  Y sigue llevando la opción de darse de baja

Escenario: La plantilla no vive en la app
  Cuando se edita y guarda una plantilla
  Entonces el cambio aplica al siguiente lead
  Y no hace falta publicar una versión nueva de la app
```

---

## EP-05 · Transcripción — `TRA-01` … `TRA-07`

```gherkin
Escenario: La transcripción no bloquea el guardado
  Dado que el vendedor grabó 30 segundos de nota
  Cuando toca "Guarda y da foloo"
  Entonces el acuse aparece sin esperar a la transcripción
  Y el lead queda guardado con estadoTranscripcion "pendiente"
  Cuando el servidor termina de procesar
  Entonces el detalle de la conexión muestra la transcripción

Escenario: Mismo resultado en ambas plataformas
  Dado un iPhone y un Android grabando la misma frase
  Entonces ambas transcripciones son equivalentes
  Porque el procesamiento ocurre en el servidor, no en el dispositivo

Escenario: Transcripción no disponible
  Dado que el servicio de transcripción falla
  Cuando se abre el detalle del lead
  Entonces el estado dice que no está disponible
  Y no hay un espacio en blanco sin explicación
  Y el lead sigue completo, con su audio y su nota escrita

Escenario: Coexisten transcripción y nota escrita
  Dado un lead con nota de voz y nota escrita
  Cuando se abre su detalle
  Entonces se ven las dos, cada una con su rótulo
  Y ambas llegan al correo de Copia Admin
```

---

## EP-11 · Correos automáticos — `SAL-05` … `SAL-15`, `RC-01`, `RC-02`

```gherkin
Escenario: Los dos correos salen
  Dado un lead con correo válido y conexión
  Cuando el vendedor guarda
  Entonces el lead recibe su correo en menos de 2 minutos
  Y el remitente visible lleva el nombre de quien capturó
  Y Copia Admin recibe su aviso con todos los campos, la nota,
    la transcripción y el enlace al audio
  Y el asunto de Copia Admin permite filtrar por tipo, nombre y empresa

Escenario: El correo entrega el aviso de privacidad
  Cuando el lead recibe su correo
  Entonces incluye el enlace al aviso de privacidad
  Y explica que entregó su tarjeta en el evento X
  Y ofrece una forma clara de darse de baja

Escenario: Un correo caído no pierde el lead
  Dado que el proveedor de correo está caído
  Cuando el vendedor guarda un lead
  Entonces la fila se escribe en la hoja igual
  Y el correo queda en cola de reintento
  Y el estado del correo aparece como "en cola" en la hoja y en el detalle
  Cuando el proveedor vuelve
  Entonces el correo sale, una sola vez

Escenario: El correo no se dispara antes que la fila
  Dado un lead pendiente de subir
  Entonces no sale ningún correo
  Porque el disparo está atado a la escritura en la hoja, no al toque de Guardar

Escenario: Baja respetada
  Dado un lead que se dio de baja
  Cuando se le intenta enviar cualquier correo posterior
  Entonces no se envía
  Y la baja queda registrada en la hoja
```

---

## EP-06 · Acuse de 4 confirmaciones — `CAP-21`

```gherkin
Escenario: Cuatro confirmaciones con detalle verificable
  Dado un lead con correo válido y 2 adjuntos, con conexión
  Cuando el vendedor guarda
  Entonces el acuse marca cuatro líneas, una por una, con su hora
  Y la primera dice la fila exacta y el nombre de la hoja
  Y la segunda dice la dirección del lead
  Y la tercera dice la dirección de Copia Admin
  Y la cuarta dice cuántos archivos y sus nombres
  Y una cuenta regresiva devuelve a captura en 3 segundos

Escenario: Acuse sin conexión
  Dado el modo avión encendido
  Cuando el vendedor guarda un lead con adjuntos
  Entonces las cuatro líneas se muestran en cola, no como error
  Y el lead aparece como "Por subir" en Registros
```

---

## EP-07 · Lead directo con Lugar — `CAP-20`, `PLT-03`

```gherkin
Escenario: Lugar es obligatorio
  Dado que el vendedor eligió "Lead directo"
  Cuando intenta continuar sin escribir el lugar
  Entonces se le señala el campo
  Y no puede llegar a captura sin él

Escenario: El lugar llega al correo
  Dado un lead directo con lugar "Oficinas de Grupo Lácteo"
  Cuando se envía el correo
  Entonces el asunto dice "Seguimiento · Oficinas de Grupo Lácteo"
  Y el cuerpo dice "Gusto en coincidir en Oficinas de Grupo Lácteo"
  Y se usó la plantilla de lead directo, no la de evento

Escenario: El lugar persiste entre capturas
  Dado un lead directo ya guardado con lugar "Oficinas de Grupo Lácteo"
  Cuando el acuse devuelve a captura
  Entonces el lugar sigue puesto
  Y el vendedor no tiene que reescribirlo para la siguiente persona del mismo lugar
```

---

## EP-08 · Sincronización con adjuntos — `SYN-10`, `SYN-11`, `CON-12`

```gherkin
Escenario: Un archivo pesado no bloquea los leads
  Dado un PDF de 3 MB pendiente de subir y 5 leads pendientes
  Cuando vuelve una conexión lenta
  Entonces los leads suben sin esperar a que termine el archivo
  Y las dos colas avanzan de forma independiente

Escenario: Adjuntar sin conexión
  Dado el modo avión y un archivo ya cacheado en el teléfono
  Cuando el vendedor captura un lead y lo selecciona
  Entonces el lead se guarda con la referencia al archivo
  Y lee "Los archivos viven en tu teléfono y se adjuntan al correo cuando hay señal."
  Cuando vuelve la señal
  Entonces el correo sale con el adjunto, una sola vez

Escenario: Reenvío no duplica adjuntos
  Dado un lead ya sincronizado con 2 adjuntos
  Cuando se fuerza un reenvío del mismo folio
  Entonces no se envía un segundo correo
  Y la hoja sigue teniendo una sola fila
```

---

## EP-09 · Escala a 12 eventos y 20 archivos — `RNF-14`, `CON-11`

```gherkin
Escenario: Nada de desplazamiento horizontal
  Dado una cuenta con 12 eventos y 20 archivos
  Cuando se recorren Contenido, Subir contenido y Editar eventos del archivo
  Entonces ninguna lista obliga a desplazamiento horizontal
  Y todos los buscadores quedan fijos arriba de su lista
  Y ninguna lista empuja el dock fuera de pantalla
  Y el contador de seleccionados es visible en todo momento
```

---

## EP-10 · Una sola base de código — `RNF-18`

```gherkin
Escenario: Cuenta Basic en el binario Pro
  Dado el mismo binario instalado
  Cuando inicia sesión una cuenta con plan "basic"
  Entonces el menú NO muestra Contenido ni Correo
  Y no aparecen en gris, ni con candado, ni con un aviso de mejora de plan
  Y el paso 03 de captura no muestra "Contenido a compartir"
  Y el paso 04 no muestra transcripción
  Y el acuse muestra 1 confirmación, no 4
  Y al guardar un lead NO sale ningún correo

Escenario: Activar Pro sobre una cuenta que venía en Basic
  Dado una cuenta con 40 leads ya escritos en la hoja desde Basic
  Cuando pasa a plan "pro" y el usuario vuelve a iniciar sesión
  Entonces las columnas nuevas se agregaron al final de la hoja
  Y ninguna fila anterior se movió ni se reordenó
  Y los 40 leads antiguos NO reciben correos retroactivos

Escenario: Cambio de plan sin reinstalar
  Dado una cuenta que pasa de basic a pro del lado del servidor
  Cuando el usuario vuelve a iniciar sesión
  Entonces las capacidades Pro aparecen
  Y no hizo falta instalar otra app
```
