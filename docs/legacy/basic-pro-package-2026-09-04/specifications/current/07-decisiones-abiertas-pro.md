# 07 · Decisiones abiertas — Pro

Las decisiones `D-01` a `D-12` de `03-decisiones-abiertas.md` siguen vigentes para Pro, con una excepción registrada abajo (`DP-05`).

Estas son las que nacen con Pro. Mismo principio: **el agente no inventa respuestas**.

---

## Bloqueantes

### `DP-01` · Dónde viven realmente los archivos

**El conflicto.** La interfaz dice "Los archivos viven en tu teléfono y se adjuntan al correo cuando hay señal." Pero el correo lo manda el servidor (Artículo 3, `SAL-04`). Un servidor no puede adjuntar un archivo que solo existe en el teléfono.

**Las tres lecturas posibles, y solo una funciona.**

1. El archivo se sube al servidor al agregarlo a la biblioteca; la copia local es caché para poder verlo y seleccionarlo sin conexión. El lead viaja con `archivoId`.
2. El archivo viaja con cada lead desde el teléfono. Significa subir 3 MB por lead, 200 veces en una expo, con el wifi del recinto. Inviable.
3. La app manda el correo. Rompe el Artículo 3 y expone credenciales.

**Lo que este documento asume.** Opción 1. Está escrita en `05-especificacion-pro.md` §4 como restricción de arquitectura.

**Lo que hay que confirmar.** Que el copy de la interfaz no engañe al vendedor. "Viven en tu teléfono" es cierto para su experiencia, pero si Legal pregunta dónde están los archivos, la respuesta es "en el servidor también". Vale la pena revisar la redacción con Marketing.

**Decide:** Desarrollador (arquitectura) + Marketing (copy). **Bloquea:** `CON-09`, `CON-12`, `SYN-10`.

---

### `DP-02` · Límite de peso de los adjuntos

**Los números del mockup.** Tres archivos: 1.2 MB, 2.8 MB y 940 KB. Un correo con los tres pesa ~5 MB.

**El problema.** Un evento con 200 leads y 5 MB de adjuntos por correo son **1 GB de salida en un día**, más el costo del proveedor. Y varios proveedores rechazan el mensaje completo por tamaño: Amazon SES corta en 10 MB para mensajes crudos, y los límites diarios de Gmail (~100 envíos gratuito, ~1,500 Workspace) ya eran un riesgo en Basic (`RNF-10`).

**Un correo rechazado por tamaño es un lead sin seguimiento**, que es exactamente lo que el producto existe para evitar.

**Opciones.**
1. Adjuntos reales, con tope duro por correo y aviso antes de guardar.
2. Enlaces de descarga en lugar de adjuntos. Más barato, mejor entregabilidad, permite medir quién abrió — pero pierde el "ya lo tienes en tu bandeja".
3. Híbrido: adjuntar bajo cierto peso, enlazar por encima. Es lo más robusto y lo más caro de construir.

**Hay que decidir dos números:** peso máximo por archivo y peso máximo por correo.

**Decide:** Marketing + Desarrollador. **Bloquea:** `CON-14`, `RNF-15`, `SAL-05`.

---

### `DP-03` · ¿Las plantillas son del vendedor o de la empresa?

**Situación.** El editor de plantillas vive en la app del vendedor. No hay nada que indique si el cambio es suyo o de toda la cuenta.

**Por qué importa.** Si cada vendedor edita su plantilla, marketing pierde el control del mensaje de marca en el primer correo que un prospecto recibe de la empresa. Si es de la empresa, un vendedor puede cambiarle el correo a todos sin querer.

**Opciones.**
1. Por usuario. Cada quien firma como quiere. Marketing pierde control.
2. Por cuenta, editable por cualquiera. Rápido y peligroso.
3. Por cuenta, editable solo por un administrador. Necesita roles, que están fuera de alcance en ambas versiones.

**Sin resolver esto, `PLT-01` no se puede implementar correctamente.** Es una decisión de gobernanza, no técnica.

**Decide:** Marketing + Dirección. **Bloquea:** `PLT-01`, `PLT-02`, `PLT-07`.

---

### `DP-04` · Dónde se configura "Copia Admin"

**Situación.** La confirmación del acuse Pro dice **"Copia Admin"** y muestra `marketing@cbqasolutions.com`. Con el correo fuera de Basic, esta dirección **no tiene pantalla de configuración en ninguna de las 21 pantallas Pro**, y tampoco existía una en Basic.

**Preguntas.**
- ¿Dónde se captura esa dirección? ¿Configuración de servidor, o hace falta una pantalla?
- ¿Es una dirección por cuenta, o una por evento?
- ¿Puede haber más de un destinatario?

**Lo que este documento asume.** Una dirección por cuenta, configurada del lado del servidor, sin pantalla en la app.

**Riesgo si se asume mal.** Si marketing necesita cambiarla y no hay pantalla, cada cambio pasa por el desarrollador. Es exactamente el problema que `PLT-01` resuelve para las plantillas.

**Decide:** Marketing. **Bloquea:** `SAL-05`, `SAL-07`.

---

### `DP-12` · Todo el correo se construye una sola vez

**Contexto.** Con `D-13`, el envío de correos salió de Basic por decisión de los solicitantes. Eso significa que en el momento de construir Pro **nada de esto existe todavía**: proveedor transaccional, cola de reintentos, estados de envío, plantillas, pie legal, manejo de rebotes y de bajas.

**Lo que hay que decidir antes de empezar Pro.**
- Qué proveedor, con qué dominio y qué buzón visible como remitente (era `D-08`, sigue sin responder).
- Si la cola de correos es la misma cola de sincronización de leads o una separada. Recomendación: separada, por la misma razón que `SYN-10` separa los archivos — un correo atorado no puede frenar la escritura en la hoja.
- Qué pasa con los leads capturados **durante la etapa Basic** cuando la cuenta pasa a Pro. ¿Se les manda el correo con retraso, o se quedan sin él? Mandar un "gusto en coincidir en la expo" tres meses tarde es peor que no mandarlo.

**Recomendación sobre el último punto.** No enviar retroactivamente. El correo se dispara solo para leads capturados a partir de la activación de Pro, y así debe decirlo la app.

**Decide:** Marketing + Desarrollador. **Bloquea:** toda la sección 5 de `05-especificacion-pro.md`.

---

### `DP-05` · La transcripción entra en Pro y no en Basic

**Esto resuelve `D-01` de forma distinta por versión**, y hay que decidir cómo se construye.

- Fuera de Basic (`VOZ-07`).
- Dentro de Pro (`TRA-01`).

**La decisión real no es si existe, sino cómo se construye:**

1. Se construye una vez en el backend y se apaga por bandera de capacidad para cuentas Basic. Consistente con `RNF-18`. El costo del servicio de voz solo se paga cuando se usa.
2. Se pospone hasta que haya clientes Pro. Basic sale antes, Pro se retrasa.

**Lo que este documento asume.** Opción 1.

**Consecuencia que hay que aceptar.** Si el backend de transcripción existe desde el día uno, la decisión de "Basic no transcribe" es comercial, no técnica. Conviene que Marketing lo sepa: es una palanca de precio, no una limitación.

**Decide:** Dirección. **Bloquea:** planeación, no implementación.

---

## No bloqueantes

### `DP-06` · ¿La transcripción es editable?

El documento v1.0 decía "El texto queda editable" (`RF-14`). Los mockups Pro la muestran como bloque de lectura, tanto en captura como en el detalle. Y el detalle es de solo lectura por diseño (`REG-07`, `D-04`).

**Tensión real.** Una transcripción en español de México con jerga de industria va a equivocarse con nombres propios y siglas. Si nadie puede corregirla, marketing lee errores. Pero abrir la edición choca con `D-04`, que está sin resolver.

**Recomendación.** Resolver `D-04` primero. Si el detalle se vuelve editable, la transcripción entra en el mismo mecanismo y esta decisión desaparece sola.

**Decide:** Marketing. **Depende de:** `D-04`.

---

### `DP-07` · Qué muestra el acuse sin conexión

Basic confirma una sola cosa: la fila en la hoja. Pro confirma cuatro. Sin conexión, cuatro renglones en gris diciendo "en cola" son mucho ruido para tres segundos de pantalla.

**Opciones.**
1. Las cuatro en cola, en gris.
2. Una sola línea honesta: "Guardado en tu teléfono. Sale cuando haya señal."
3. Una línea de resumen que se puede expandir.

**Recomendación.** Opción 2. En el piso de una expo, tres segundos alcanzan para leer una frase, no cuatro renglones.

**Decide:** Marketing + Diseño.

---

### `DP-08` · Cómo se distingue Basic de Pro en la práctica

`RNF-18` y la regla de construcción de `04-matriz-de-capacidades.md` dicen: una sola base de código, capacidades habilitadas por el servidor, sin candados ni grises.

**Falta definir.**
- ¿La bandera viene en la respuesta del login, o en un endpoint de capacidades aparte?
- ¿Qué pasa si una cuenta baja de Pro a Basic con archivos ya subidos y leads con adjuntos? Los leads históricos no deberían romperse.
- ¿El cambio de plan aplica al vuelo o hasta el siguiente inicio de sesión? El escenario `EP-10` asume lo segundo.

**Decide:** Desarrollador.

---

### `DP-09` · Editar evento no permite cambiar el contenido

**Inconsistencia detectada en los mockups.** La pantalla `01d` (crear evento) incluye "Contenido para este evento · 2 de 3". La pantalla `06a` (editar evento) **no** lo incluye.

Se puede llegar al mismo resultado por el otro lado — desde la biblioteca, con "Editar eventos del archivo" (`07b`) — pero eso obliga al vendedor a pensar al revés: en lugar de "a este evento le falta la ficha técnica", tiene que pensar "la ficha técnica también aplica a este evento". Con doce eventos y veinte archivos, la segunda ruta es notablemente peor.

**Opciones.**
1. Agregar el bloque de contenido a Editar evento, simétrico con Crear evento.
2. Dejarlo como está y aceptar la ruta indirecta.

**Recomendación.** Opción 1. La asimetría entre crear y editar la misma entidad se siente como un error, no como una decisión.

**Decide:** Diseño + Marketing.

---

### `DP-10` · Nombres de archivo y privacidad del lead

El nombre para mostrar (`CON-02`) es lo que ve el lead. Nadie valida que sea apropiado: un archivo llamado "Precios internos Q4" adjunto a un correo externo es un incidente comercial, no técnico.

**Opciones.** Advertencia al subir · confirmación al adjuntar por primera vez · nada, y confiar en el criterio del vendedor.

**Decide:** Marketing.

---

### `DP-11` · Tope de la caché local

`RNF-16` exige tope y política de desalojo. Falta el número. Veinte archivos de 3 MB son 60 MB, lo cual es razonable; doscientos ya no.

**Preguntas.** ¿Se cachean todos los archivos o solo los del evento activo? ¿Qué se desaloja primero?

**Recomendación.** Cachear solo los archivos de los eventos con actividad reciente. El vendedor no necesita en el bolsillo el portafolio de una expo de hace un año.

**Decide:** Desarrollador.

---

## Resumen de deltas: Basic → Pro

| Área | Basic | Pro | Tipo |
|---|---|---|---|
| **Correos automáticos al lead y a marketing** | No existen | Sí, con cola de reintentos y estados | **Nuevo** — ver `D-13` |
| **Aviso de privacidad y baja** | Sin canal de entrega (`D-14`) | En el correo al lead | **Nuevo** — cierra el hueco de Basic |
| Biblioteca de contenido | No existe | Módulo completo, 3 pantallas | **Nuevo** |
| Adjuntos en el correo | No aplica | Sí, seleccionables por lead | **Nuevo** |
| Plantillas de correo | No aplica | Editor en la app, 2 plantillas, previsualización | **Nuevo** |
| Transcripción de voz | Fuera (`D-01`) | Dentro (`TRA-01`) | **Nuevo** — invierte `D-01` |
| Lead directo | Frase explicativa | Campo **Lugar** obligatorio | **Cambio** |
| Acuse | 1 confirmación (la fila) | 4 confirmaciones con detalle | **Cambio** |
| Botón principal | "Guardar" | `Guarda y da "foloo"` | **Cambio** |
| Crear evento | Nombre y fechas | + asignación de contenido | **Cambio** |
| Menú | 3 destinos | 5 destinos | **Cambio** |
| Escala | No especificada | 12+ eventos, 20+ archivos | **Nuevo NFR** |
| Pantallas | 16 | 21 | +5 |

**Lectura del saldo.** Pro no toca el flujo de captura en su esencia: siguen siendo los mismos 4 pasos, la misma pantalla con scroll, el mismo dock. Lo que agrega vive **alrededor** — antes de la expo (subir contenido, redactar la plantilla) y después de guardar (enviar, adjuntar, transcribir).

Eso es buena noticia para la interfaz: la pantalla más difícil ya está resuelta en Basic.

Es peor noticia para el backend de lo que era antes de sacar los correos de Basic. Al quedar el envío fuera del núcleo, Pro ya no hereda un sistema de correo probado en producción: lo estrena completo — proveedor, cola, reintentos, estados, plantillas, pie legal, rebotes y bajas — al mismo tiempo que estrena adjuntos y transcripción. Tres subsistemas nuevos en una sola entrega.

**Recomendación de secuencia.** Si Pro se puede partir, que el correo simple salga antes que los adjuntos. Un correo de seguimiento sin archivo adjunto ya cumple la promesa de "contacto el mismo día" y despeja `DP-02`, que es la pregunta más cara de responder tarde. Los adjuntos, después.
