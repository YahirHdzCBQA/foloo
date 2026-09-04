# 04 · Matriz de capacidades — Basic vs Pro

> **Este archivo es la única fuente de verdad sobre qué versión tiene qué.**
> Si otro documento contradice esta tabla, gana esta tabla y el otro documento se corrige.
> Ningún requerimiento en `01-especificacion.md` ni en `05-especificacion-pro.md` debe llevar marcas de versión en su texto: la frontera vive aquí y solo aquí.

---

## Cómo leer

- **Basic = el núcleo.** `01-especificacion.md` describe Basic completo.
- **Pro = Basic + delta.** `05-especificacion-pro.md` describe **solo lo que cambia**. Todo lo que no aparezca ahí, se comporta exactamente como en Basic.
- Un agente que construye **Basic** lee: `00`, `01`, `02`, `03`. Nada más.
- Un agente que construye **Pro** lee: `00`, `01`, `02`, **`04`, `05`, `06`, `07`**.

| Símbolo | Significado |
|---|---|
| ● | Incluido |
| ○ | No incluido |
| ◐ | Incluido con diferencias — ver la columna de nota |

---

## Matriz

### Acceso y perfil

| Capacidad | Basic | Pro | Nota |
|---|:---:|:---:|---|
| Login con usuario y contraseña | ● | ● | Idéntico |
| Perfil del vendedor (nombre, empresa, foto) | ● | ● | Idéntico |
| Insignia de plan en el menú | ◐ | ◐ | Etiqueta estática: "Basic" / "Pro" |
| Cerrar sesión | ● | ● | Idéntico |
| Roles y permisos | ○ | ○ | Fuera en ambas |

### Eventos

| Capacidad | Basic | Pro | Nota |
|---|:---:|:---:|---|
| Crear, editar, eliminar evento | ● | ● | Idéntico |
| Evento activo, contadores de leads | ● | ● | Idéntico |
| Asignar contenido al crear el evento | ○ | ● | `CON-08` |
| Lista de eventos que escala a 12+ | ○ | ● | Buscador y scroll propio · `CON-11` |

### Origen del lead

| Capacidad | Basic | Pro | Nota |
|---|:---:|:---:|---|
| Captura con evento | ● | ● | Idéntico |
| Captura como lead directo | ● | ● | Comportamiento base idéntico |
| Campo **Lugar** en lead directo | ○ | ● | `CAP-20`. Alimenta `{lugar}` en la plantilla |

### Captura

| Capacidad | Basic | Pro | Nota |
|---|:---:|:---:|---|
| 4 pasos en una sola pantalla con scroll | ● | ● | Idéntico |
| Lectura de tarjeta con cámara o galería | ● | ● | Idéntico |
| Datos editables, la lectura no pisa correcciones | ● | ● | Idéntico |
| Tipo de lead (Proveedor / Partner / Cliente) | ● | ● | Idéntico |
| Nivel de interés | ● | ● | Idéntico |
| **Contenido a compartir** dentro del paso 03 | ○ | ● | `CON-05` |
| Nota de voz: grabar, reproducir, borrar | ● | ● | Idéntico |
| **Transcripción de la nota de voz** | ○ | ● | `TRA-01`. Invierte `D-01` para Pro |
| Nota escrita | ● | ● | Idéntico |
| **Imágenes adicionales del contacto (0–3)** | ○ | ● | Captura individual o sesión continua de cámara, persistencia local y consulta · `CAP-22`, `CAP-23`, `REG-13` |
| Texto del botón principal | ◐ | ◐ | Basic: "Guardar" · Pro: `Guarda y da "foloo"` |

### Acuse

| Capacidad | Basic | Pro | Nota |
|---|:---:|:---:|---|
| Folio, nombre, empresa, regreso automático en 3 s | ● | ● | Idéntico |
| Confirmaciones que se marcan una por una | ◐ | ◐ | Basic: **1 línea** (la fila en la hoja) · Pro: **4 líneas** |
| Confirmación de correo al lead | ○ | ● | `CAP-21` |
| Confirmación de Copia Admin | ○ | ● | `CAP-21` |
| Conteo de archivos adjuntos en la confirmación | ○ | ● | `CAP-21` |

### Salida de datos

| Capacidad | Basic | Pro | Nota |
|---|:---:|:---:|---|
| Fila por lead en la hoja del evento | ● | ● | Idéntico |
| Enlaces de audio y foto en la hoja | ● | ● | Idéntico |
| Columnas de estado de correo en la hoja | ○ | ● | Pro las **agrega al final**, no reordena |
| Envío de correos | ○ | ● | Ver bloque "Correo" |

### Registros y consulta

| Capacidad | Basic | Pro | Nota |
|---|:---:|:---:|---|
| Lista, búsqueda, filtros por tipo | ● | ● | Idéntico |
| Detalle de la conexión en solo lectura | ● | ● | Idéntico salvo transcripción |
| Transcripción visible en el detalle | ○ | ● | `TRA-04` |
| Imágenes adicionales visibles en el detalle | ○ | ● | `REG-13` |
| Exportación XLS / CSV | ● | ● | Idéntico |
| Sincronización manual y automática | ● | ● | Idéntico |

### Contenido — **exclusivo de Pro**

| Capacidad | Basic | Pro | Nota |
|---|:---:|:---:|---|
| Biblioteca de archivos PDF | ○ | ● | `CON-01` |
| Subir archivo con nombre para mostrar | ○ | ● | `CON-02` |
| Asignar un archivo a N eventos | ○ | ● | `CON-03` |
| "Todos los eventos" como interruptor maestro | ○ | ● | `CON-04` |
| Eliminar archivo de la biblioteca | ○ | ● | `CON-07` |
| Filtro por evento en la biblioteca | ○ | ● | `CON-06` |
| Adjuntos en el correo al lead | ○ | ● | `CON-09` |

### Correo — **exclusivo de Pro**

> **Basic no envía correos.** Decisión de los solicitantes, registrada en `D-13`. Es un cambio de alcance respecto de la v1.0 del PDF, donde el envío eran seis requerimientos *Debe*.

| Capacidad | Basic | Pro | Nota |
|---|:---:|:---:|---|
| Correo automático al lead | ○ | ● | `SAL-05` |
| Correo automático a marketing / Copia Admin | ○ | ● | `SAL-07`. Pro lo llama "Copia Admin" |
| Cola de reintentos de correo | ○ | ● | `SAL-08` |
| Estado de envío por lead en la hoja | ○ | ● | `SAL-09` |
| Editor de plantilla dentro de la app | ○ | ● | `PLT-01` |
| Dos plantillas independientes (evento / directo) | ○ | ● | `PLT-02` |
| Chips de variables disponibles | ○ | ● | `PLT-04` |
| Previsualización con el último lead real | ○ | ● | `PLT-05` |
| Aviso de privacidad y baja en el correo | ○ | ● | `PLT-08`, `RC-01`, `RC-02` |
| Proveedor de correo transaccional | ○ | ● | `RNF-15` |

### Privacidad y cumplimiento

| Capacidad | Basic | Pro | Nota |
|---|:---:|:---:|---|
| Retención y borrado de audios y fotos | ● | ● | `RC-03` |
| Acceso autenticado a audios | ● | ● | `RC-04` |
| Aviso verbal al capturar | ● | ● | `RC-05` |
| Aviso de privacidad por canal digital | ○ | ● | Basic se quedó sin canal al salir el correo. Ver `D-14` |
| Opción de baja | ○ | ● | `RC-02`, `PLT-08` |

### Navegación y apariencia

| Capacidad | Basic | Pro | Nota |
|---|:---:|:---:|---|
| Menú lateral, tema claro / oscuro | ● | ● | Idéntico |
| Idiomas Español / Inglés | ● | ● | Estado compartido de sesión · `NAV-09`, `RNF-19` |
| Destinos: Home, Registros, Mis eventos | ● | ● | Idéntico |
| Destinos: **Contenido**, **Correo** | ○ | ● | `NAV-08` |

### Fuera de alcance en ambas versiones

QR de gafetes · integración directa a CRM · panel de métricas · dashboard web · biblioteca de documentos en web · puntuación de leads con IA · resúmenes de conversación con IA · publicación en tiendas · lógica de cobro o de planes.

---

## Conteo de pantallas

| Versión | Pantallas | Diferencia |
|---|---|---|
| Basic | 16 | — |
| Pro | 21 | +5: `07` Contenido, `07a` Subir contenido, `07b` Editar eventos del archivo, `08` Correo evento, `08a` Correo lead directo |

Las 16 pantallas de Basic existen igual en Pro, con cuatro de ellas modificadas: captura (paso 03 gana contenido, paso 04 gana transcripción), lead directo (gana el campo Lugar), acuse (pasa de 1 a 4 confirmaciones) y menú (gana Contenido y Correo).

---

## Regla de construcción

**Una sola base de código.** Pro no es una app distinta: es la misma app con capacidades habilitadas.

- La diferencia entre versiones se resuelve con una **bandera de capacidad por cuenta**, entregada por el servidor en el login junto con el campo `plan` del usuario.
- La app **no decide** qué versión es. Lo decide el servidor.
- Una capacidad apagada **no se muestra en gris ni con candado**: simplemente no está. Basic no es una demo de Pro.
- Las pantallas exclusivas de Pro no existen en el árbol de navegación de una cuenta Basic.

Razón: mantener dos ramas o dos apps duplica el costo de cada corrección y garantiza que una de las dos se quede atrás. Ver `DP-08`.
