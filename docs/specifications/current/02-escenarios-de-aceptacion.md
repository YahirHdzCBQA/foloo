# 02 · Escenarios de aceptación

Escenarios verificables, en Gherkin, trazados a los IDs de `01-especificacion.md`. Cada escenario debe poder ejecutarse en un teléfono real sin conocimiento previo del código.

**Convención:** un requerimiento se considera implementado cuando todos sus escenarios pasan. Un escenario sin ID trazado no es válido.

---

## E-01 · Entrar y preparar la jornada — `AUT-01`, `AUT-04`, `EVT-03`

```gherkin
Escenario: Primer arranque, usuario sin eventos
  Dado que la app se instala por primera vez
  Cuando el vendedor entra con usuario y contraseña válidos
  Entonces se le pide el perfil una sola vez: nombre, empresa y foto
  Y al continuar llega a "¿Dónde estás conectando hoy?"
  Y ve el formulario de crear evento ya listo, no una lista vacía
  Y lee "Aún no tienes eventos. Este será el primero y queda activo."

Escenario: Segundo arranque, con eventos existentes
  Dado que el vendedor ya tiene 5 eventos y una sesión previa
  Cuando cierra sesión y vuelve a entrar
  Entonces NO se le vuelve a pedir el perfil
  Y ve la lista de sus eventos con el último activo preseleccionado
  Y cada evento muestra su fecha y su conteo de leads

Escenario: La sesión sobrevive al cierre de la app
  Dado que el vendedor inició sesión
  Cuando mata la app y la vuelve a abrir
  Entonces entra directo, sin pedir contraseña
```

---

## E-02 · Lead directo — `CAP-01`, `CAP-03`, `CAP-04`

```gherkin
Escenario: Capturar sin evento asociado
  Dado que el vendedor está en "¿Dónde estás conectando hoy?"
  Cuando elige "Lead directo"
  Entonces lee "Se guarda sin evento, en tu base general de leads."
  Y el botón principal dice "Capturar conexión"
  Cuando guarda un lead
  Entonces el registro queda con origen "directo" y sin evento
  Y su folio empieza con "FOL-"

Escenario: El origen persiste entre capturas
  Dado que el vendedor eligió "Lead directo"
  Cuando guarda un lead y el acuse lo regresa a captura
  Entonces el origen sigue siendo "Lead directo"
  Y no tiene que volver a elegirlo
```

---

## E-03 · Lectura de la tarjeta — `OCR-01` … `OCR-09`, `RNF-01`

```gherkin
Escenario: Tarjeta girada 90°, sostenida en la mano
  Dado que el vendedor está en el paso 01 y hay conexión
  Cuando toma la foto de la tarjeta de referencia girada 90°
  Entonces en menos de 5 segundos los campos del paso 02 quedan precargados
  Y nombre, apellido, empresa, correo y teléfono son correctos
  Y el renglón dice "Tarjeta lista · datos aplicados"
  Y aparece el botón "Reprocesar"

Escenario: La lectura no pisa lo corregido a mano
  Dado que el vendedor corrigió el campo Empresa a mano
  Cuando toca "Reprocesar"
  Entonces el valor corregido de Empresa se conserva
  Y los campos que seguían vacíos sí se llenan

Escenario: Servicio de lectura caído
  Dado que el servicio de lectura está apagado a propósito
  Cuando el vendedor toma la foto
  Entonces lee "Tarjeta ilegible. Escribe los datos a mano."
  Y puede escribir todos los campos y guardar el lead normalmente
  Y el mensaje NO está en rojo con signo de admiración

Escenario: Sin foto no hay Reprocesar
  Dado que el vendedor está en el paso 01 sin foto
  Entonces lee "Sin foto aún"
  Y el botón "Reprocesar" no existe en pantalla

Escenario: El dato que no está en la tarjeta se queda vacío
  Dado que la tarjeta de referencia no trae puesto
  Cuando se lee la tarjeta
  Entonces el campo Puesto queda vacío
  Y no contiene ningún valor inventado
```

---

## E-04 · Tipo de lead e interés — `CAP-09`, `CAP-10`, `CAP-11`

```gherkin
Escenario: El tipo es obligatorio y no tiene default
  Dado que el vendedor llenó nombre, empresa y correo
  Y no eligió tipo de lead
  Cuando toca "Guardar"
  Entonces el guardado se detiene
  Y el paso 03 se señala con icono y texto, no solo con color
  Y nada de lo capturado se pierde

Escenario: Tres tipos disponibles
  Dado que el vendedor está en el paso 03
  Entonces ve exactamente tres opciones: Proveedor, Partner y Cliente
  Y cada una lleva icono y palabra
  Y ninguna viene preseleccionada

Escenario: Interés por defecto
  Dado que el vendedor abre una captura nueva
  Entonces el nivel de interés está en "Medio"
  Y puede moverlo a "Bajo" o "Alto" con un toque
```

---

## E-05 · Nota de voz — `VOZ-01` … `VOZ-07`

```gherkin
Escenario: Grabar 30 segundos en ambas plataformas
  Dado un iPhone con iOS 15 y un Android con Android 10
  Cuando el vendedor graba 30 segundos de nota en cada uno
  Entonces el temporizador avanza en mm:ss durante la grabación
  Y hay una onda viva y la etiqueta "Grabando"
  Y al detener puede reproducir el audio en ambos equipos
  Y puede borrarlo y volver a grabar antes de guardar

Escenario: Sin conexión, el audio no se pierde
  Dado el modo avión encendido
  Cuando el vendedor graba una nota y guarda el lead
  Entonces lee "Se guarda en tu teléfono. Se sube cuando haya señal."
  Y el lead queda guardado con su audio local
  Cuando vuelve la conexión
  Entonces el audio sube solo y su enlace queda en el registro

Escenario: Permiso de micrófono denegado
  Dado que el permiso de micrófono está denegado
  Cuando el vendedor llega al paso 04
  Entonces se le explica la situación
  Y puede terminar el lead con nota escrita
  Y el guardado nunca se bloquea

Escenario: Sin transcripción
  Dado cualquier estado de la app
  Entonces no existe ningún control, campo ni texto que ofrezca transcribir la nota
```

---

## E-06 · Guardado y acuse — `CAP-13` … `CAP-19`

```gherkin
Escenario: Lead completo en menos de 60 segundos
  Dado un cronómetro y la tarjeta de referencia en la mano
  Cuando el vendedor abre la app, fotografía, corrige, clasifica,
        graba una nota corta y toca "Guardar"
  Entonces el acuse aparece antes de los 60 segundos

Escenario: El acuse confirma y regresa solo
  Dado que se guardó un lead con conexión
  Entonces el acuse muestra nombre y empresa del lead
  Y muestra el folio con formato PREFIJO-AAMMDD-NNN
  Y confirma la fila escrita en la hoja del evento, con su hora
  Y NO menciona ningún correo enviado ni en cola
  Y una cuenta regresiva visible dice "Regresas a captura en 3 s"
  Cuando pasan 3 segundos
  Entonces la app vuelve sola a captura con el formulario limpio
  Y el evento y el origen siguen seleccionados

Escenario: Capturar otro sin esperar
  Dado que el acuse está en pantalla
  Cuando el vendedor toca "Capturar otro ahora"
  Entonces vuelve a captura de inmediato

Escenario: El dock nunca se va
  Dado que el vendedor hace scroll en la pantalla de captura
  Entonces el botón "Guardar" sigue visible y fijo abajo
  Y su alto es de 56 dp
```

---

## E-07 · Sin conexión y sincronización — `SYN-01` … `SYN-07`

```gherkin
Escenario: Modo avión de principio a fin
  Dado el modo avión encendido
  Cuando el vendedor captura un lead a mano y lo guarda
  Entonces el lead se guarda y aparece como "Por subir"
  Y el encabezado muestra "Sin conexión" con icono wifi-off en gris
  Cuando se restaura la conexión
  Entonces el lead sube solo, sin que el vendedor toque nada
  Y su estado pasa a "En la hoja"
  Y en la hoja aparece exactamente una fila

Escenario: Reenvío del mismo folio no duplica
  Dado un lead ya sincronizado
  Cuando se fuerza un reenvío del mismo folio
  Entonces la hoja sigue teniendo una sola fila para ese folio

Escenario: Sincronización interrumpida
  Dado 10 leads pendientes
  Cuando la conexión se corta después de subir 4
  Entonces al reanudar solo se suben los 6 restantes
  Y los 4 ya subidos no se reenvían

Escenario: El banner dice el número exacto
  Dado 2 leads pendientes en el evento activo
  Cuando el vendedor abre Registros
  Entonces lee "2 registros esperan señal"
```

---

## E-08 · Registros y detalle — `REG-01` … `REG-08`

```gherkin
Escenario: Lista con estado por renglón
  Dado un evento con 6 leads, 2 de ellos pendientes
  Cuando el vendedor abre Registros
  Entonces el encabezado dice "6 leads · 2 por subir"
  Y cada renglón muestra riel de color según el nivel de interés
  Y cada renglón muestra nombre, empresa y tipo
  Y el estado de cada renglón lleva icono Y etiqueta accesible

Escenario: Búsqueda sin conexión
  Dado el modo avión encendido
  Cuando el vendedor escribe "lácteo" en el buscador
  Entonces la lista filtra en vivo por nombre y por empresa

Escenario: Filtro por tipo
  Cuando el vendedor toca el filtro "Partners"
  Entonces solo quedan visibles los leads de tipo Partner
  Y el conteo del encabezado refleja lo filtrado

Escenario: Detalle de la conexión
  Cuando el vendedor toca un renglón
  Entonces se abre el detalle en solo lectura
  Y ve chips de tipo, interés y estado de subida
  Y ve correo, teléfono y puesto
  Y si hay nota de voz, ve su duración y puede reproducirla
  Y ve la nota escrita
  Y ve fecha y hora, origen y quién capturó
  Y no ve el folio
  Y no hay ningún control para editar

Escenario: Lead sin foto de tarjeta
  Dado un lead capturado a mano, sin foto
  Cuando se abre su detalle
  Entonces lee "Sin foto de la tarjeta" en lugar de un hueco roto
```

---

## E-09 · Exportación — `REG-09` … `REG-12`

```gherkin
Escenario: Elegir formato
  Cuando el vendedor toca "Exportar"
  Entonces se abre un diálogo con XLS marcado por defecto y CSV como alternativa
  Y lee exactamente qué se baja, con el conteo y el nombre del evento

Escenario: Acentos correctos en Excel español
  Dado un lead con el nombre "Óscar Buendía"
  Cuando se exporta a CSV y se abre en Excel en español
  Entonces los acentos se ven correctamente
  Y el archivo lleva BOM UTF-8

Escenario: Exportar sin conexión incluye pendientes
  Dado el modo avión y 2 leads pendientes
  Cuando el vendedor exporta
  Entonces el archivo incluye los 6 leads, incluidos los 2 pendientes
```

---

## E-10 · Eventos — `EVT-01` … `EVT-12`

```gherkin
Escenario: Crear evento y capturar en él
  Cuando el vendedor crea un evento con nombre y fechas
  Entonces ese evento queda activo
  Y los leads que capture después quedan asociados a él
  Y su folio empieza con el prefijo del código del evento

Escenario: Eliminar un evento no toca la hoja
  Dado un evento con 6 leads ya sincronizados
  Cuando el vendedor lo elimina desde "Mis eventos"
  Entonces antes de confirmar lee
    "Al eliminar un evento sus leads dejan de aparecer en la app.
     La hoja de cálculo no se toca."
  Y tras confirmar, esos leads ya no aparecen en la app
  Y la hoja de cálculo conserva las 6 filas intactas

Escenario: La acción destructiva está lejos del pulgar
  Cuando el vendedor abre "Editar evento"
  Entonces "Eliminar evento" NO está en el dock inferior
  Y tiene contorno propio, separado del resto

Escenario: Advertencia con pendientes
  Dado un evento con 2 leads pendientes de subir
  Cuando el vendedor intenta eliminarlo
  Entonces se le advierte explícitamente antes de confirmar

Escenario: Un solo evento activo
  Dado 5 eventos existentes
  Cuando el vendedor activa uno distinto
  Entonces exactamente uno queda marcado como "Activo"

Escenario: Selección automática usa la fecha local real
  Dado que no hubo una selección manual válida durante la interacción
  Y existen eventos futuros con fechas distintas
  Cuando la fecha local del dispositivo cambia de día
  Entonces queda activo el evento vigente que incluye hoy o, si no existe,
    el futuro cuya fecha de inicio está más próxima a hoy
  Y el cálculo no usa una fecha fija del código

Escenario: La selección manual tiene prioridad
  Dado que el vendedor eligió manualmente un evento válido
  Cuando cambia el día o existe otro evento futuro más cercano
  Entonces la selección manual se conserva
  Cuando crea un evento nuevo
  Entonces el evento recién creado queda activo y cuenta como selección manual
```

---

## E-11 · Navegación y apariencia — `NAV-01` … `NAV-07`

```gherkin
Escenario: Menú lateral
  Cuando el vendedor toca la hamburguesa
  Entonces el menú entra desde la derecha en 200 ms o menos
  Y muestra su perfil, Home, Registros con contador y Mis eventos con contador
  Y "Cerrar sesión" está al fondo, con contorno propio
  Cuando toca el fondo oscurecido
  Entonces el menú se cierra

Escenario: Retroceso del sistema
  Dado el menú abierto
  Cuando el vendedor usa el gesto o botón de retroceso
  Entonces se cierra el menú y no se navega hacia atrás

Escenario: Tema oscuro
  Cuando el vendedor activa el modo oscuro
  Entonces las 16 pantallas se ven correctamente
  Y la acción primaria pasa a superficie lima con texto #1F1F1F
  Y no hay sombras
  Y la preferencia sobrevive al cierre de la app

Escenario: Movimiento reducido
  Dado "reducir movimiento" activado en el sistema
  Cuando el vendedor guarda un lead
  Entonces la animación del acuse se colapsa a instantánea
  Y el flujo sigue funcionando igual
```

---

## E-12 · Seguridad y cumplimiento — `RNF-06`, `RNF-07`, `RC-04`

```gherkin
Escenario: Binario sin credenciales
  Cuando se descompila el APK e se inspecciona el IPA
  Entonces no aparece ninguna llave de API
  Ni credencial de la hoja de cálculo
  Ni token de almacenamiento

Escenario: Todo el tráfico por HTTPS
  Cuando se intercepta el tráfico de la app con un proxy
  Entonces no hay ninguna petición en texto plano

Escenario: Basic no envía nada
  Cuando se guarda un lead con correo válido y hay conexión
  Entonces NO sale ningún correo al lead
  Y NO sale ningún correo a marketing
  Y en toda la app no existe control, texto ni pantalla que ofrezca enviarlo
  Y el acuse no menciona correos en cola

Escenario: Audio no público por URL
  Dado el enlace de audio de un lead
  Cuando se abre desde una sesión sin autenticar
  Entonces el acceso se rechaza
```

---

## E-13 · Ergonomía — `RNF-04`, `RNF-05`

```gherkin
Escenario: Todo alcanzable con un pulgar
  Dado un teléfono de 390×844 sostenido con una mano
  Entonces toda acción principal cae en el tercio inferior
  Y ninguna acción destructiva cae en el tercio inferior
  Y ningún control interactivo mide menos de 48 dp

Escenario: Etiquetas en español largas
  Dado el idioma español
  Cuando se recorren las 16 pantallas
  Entonces ninguna etiqueta se desborda ni se corta
  Y ningún botón tiene ancho fijo que trunque su texto

Escenario: Estado nunca solo por color
  Cuando se revisa cualquier indicador de sincronización, error u offline
  Entonces siempre hay icono y palabra además del color
```

## E-14 · Idioma — `NAV-09`, `RNF-19`

```gherkin
Escenario: Un solo idioma de sesión
  Dado que la app está en español
  Cuando el usuario elige EN en Login o en el Drawer
  Entonces toda la interfaz cambia inmediatamente a inglés
  Y el selector del otro lugar también refleja EN

Escenario: Fallback e independencia de capabilities
  Dado un idioma de sistema distinto de español o inglés
  Entonces la app inicia en español
  Y cambiar idioma no agrega ni oculta capacidades Basic o Pro
```
