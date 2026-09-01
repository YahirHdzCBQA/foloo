# 03 · Decisiones abiertas

Lo que **no** está decidido. El agente no inventa respuestas: si el trabajo toca una de estas decisiones, se detiene esa rama y se escala.

Cada decisión tiene: qué falta, por qué importa, qué está bloqueando y quién decide.

---

## Bloqueantes — hay que responderlas antes de escribir código de esa área

### `D-01` · La transcripción de la nota de voz sale de Basic

**Situación.** El documento de requerimientos v1.0 marcaba la transcripción como *Debe* (`RF-14`, `RF-17`). Ni los mockups de Basic ni el design system la contemplan: el design system la lista explícitamente como fuera de alcance, y el paso 04 de los mockups solo muestra grabadora, reproductor y "Nota escrita (opcional)".

**Lo que este documento asume.** Basic graba y reproduce; **no transcribe**. La nota escrita cubre la necesidad.

**Por qué importa.** Es la diferencia entre necesitar un servicio de voz a texto en el backend desde el día uno o no necesitarlo. Cambia el costo, el tiempo y la superficie de datos personales.

**Riesgo si se confirma la salida.** Marketing recibe audios que alguien tiene que escuchar. Si el volumen del evento es alto, eso puede matar la promesa de "contacto en 24 horas".

**Decide:** Marketing. **Bloquea:** `VOZ-07`, `SAL-07`, `RC-03`.

---

### `D-02` · El campo "Siguiente paso" desaparece

**Situación.** El v1.0 lo tenía como *Debe* (`RF-10`) con catálogo de cuatro valores: enviar información, agendar llamada, cotizar, solo seguimiento. En los mockups de Basic, el paso 03 solo tiene tipo de lead y nivel de interés.

**Opciones.**
1. Se elimina de Basic. Menos toques, captura más rápida. Marketing pierde la señal de qué hacer con cada lead.
2. Se conserva como cuarto control del paso 03. Un toque más por lead.
3. Se infiere del nivel de interés. Frágil y probablemente equivocado.

**Lo que este documento asume.** Opción 1 — no está en el modelo de datos de Basic.

**Por qué importa.** Es una columna de la hoja y una variable de la plantilla de correo (`siguientePaso` existía en el correo al lead del v1.0). Agregarlo después es una migración de la hoja.

**Decide:** Marketing. **Bloquea:** modelo de datos (§3.2), `SAL-01`, `SAL-05`.

---

### `D-03` · Prefijo del folio y unicidad

**Situación.** Los mockups muestran dos formatos: `EXP-260812-001` en el acuse (prefijo del evento) y `FOL-260812-014` en el detalle de una conexión.

**Lo que este documento asume.** Prefijo de 3 letras del código del evento; `FOL` para lead directo. Consecutivo de 3 dígitos por evento y por día.

**Preguntas sin responder.**
- ¿Qué pasa si dos vendedores capturan en paralelo en el mismo evento? Con consecutivo generado en el cliente, dos personas producen el mismo folio y la idempotencia (`SYN-04`) se rompe silenciosamente — que es exactamente el escenario que más duele.
- ¿El consecutivo se reinicia cada día o corre continuo por evento?
- ¿3 dígitos alcanzan? Un evento grande puede pasar de 999.

**Recomendación.** El consecutivo lo asigna el servidor, o el cliente incluye un identificador de dispositivo en la llave. La parte legible puede seguir siendo la misma.

**Decide:** Desarrollador, con visto bueno de Marketing sobre el formato legible. **Bloquea:** `SYN-04`, `CAP-17`.

---

### `D-04` · ¿Se puede editar un lead después de guardarlo?

**Situación.** El detalle de la conexión es explícitamente de solo lectura en los mockups: "No se edita aquí."

**El problema real.** Un correo mal leído es un lead perdido en silencio, y eso a veces se descubre después. Si nunca se puede corregir, el error queda para siempre en la hoja.

**Opciones.**
1. Solo lectura, como el mockup. Se corrige directo en la hoja de cálculo.
2. Edición solo mientras el lead esté pendiente de subir.
3. Edición siempre, con actualización de la fila en la hoja por folio.

**Lo que este documento asume.** Opción 1, porque es lo que muestra el mockup — pero es la decisión que más probablemente haya que revisar.

**Decide:** Marketing. **Bloquea:** `REG-07`.

---

### `D-05` · Alcance del backend

La lectura de tarjeta ya obliga a tener servidor (Artículo 3). Falta decidir si **ese mismo servicio** se encarga también de la hoja, de los archivos y de los correos, o si se reparte.

**Recomendación fuerte:** uno solo. Repartir la lógica entre dos lugares es lo que hace que un cambio de destino de datos obligue a tocar la app, que es justo lo que `SAL-04` intenta evitar.

**Preguntas.** ¿Dónde se hospeda? ¿Quién lo opera? ¿Qué pasa cuando se cae durante un evento?

**Decide:** Desarrollador + Dirección. **Bloquea:** toda la sección 6.10.

---

### `D-06` · Qué confirma el acuse

**Situación.** Con los correos fuera de Basic, la única confirmación real que el sistema puede dar es la fila escrita en la hoja. El estado renderizado del mockup muestra exactamente eso — una sola línea: "En la hoja de cálculo del evento" — así que la interfaz ya era consistente con esta decisión. La nota de "tres pendientes" del mockup quedó obsoleta.

**Lo que hay que resolver.**
- ¿La subida del audio y de la foto merecen su propia línea, o se dan por incluidas en la fila?
- Sin conexión no se puede confirmar nada. ¿El acuse muestra una línea en gris con "en cola", o una frase directa: "Guardado en tu teléfono. Sube cuando haya señal."?

**Recomendación.** Una línea con conexión, una frase sin ella. En el piso de una expo, tres segundos alcanzan para leer una cosa.

**Decide:** Marketing + Diseño. **Bloquea:** `CAP-17`.

---

### `D-13` · Los correos salen de Basic y entran en Pro

**Situación.** Por decisión de los solicitantes, el envío automático de correos queda fuera de Basic. En la v1.0 del PDF eran seis requerimientos *Debe* (`RF-27` … `RF-32`) y sostenían la métrica central del proyecto: contacto en menos de 24 horas.

**Lo que este documento asume.** Fuera de Basic, dentro de Pro. Los requerimientos viven completos en `05-especificacion-pro.md` (`SAL-05` … `SAL-10`).

**Lo que hay que aceptar conscientemente.**

La métrica de éxito de Basic ya no puede ser "100% de las tarjetas con correo enviado antes de 24 horas", porque Basic no envía. Pasa a ser "100% de las tarjetas capturadas y en la hoja el mismo día". El seguimiento lo hace una persona, a mano, desde la hoja.

Eso es una promesa distinta, y vale la pena decirlo en voz alta antes del primer evento: **Basic quita el riesgo de perder el dato, no el riesgo de que nadie lo use.** El problema original tenía dos mitades — las tarjetas se perdían *y* llegaban tarde. Basic resuelve la primera. Si nadie abre la hoja el mismo día, el número de "contacto en 24 horas" no se va a mover, y eso no será una falla de la app.

**Qué conviene definir aunque no sea de software.** Quién abre la hoja, cuándo, y con qué compromiso de respuesta. Sin eso, Basic entrega datos limpios a tiempo a un proceso que sigue siendo manual.

**Decide:** Marketing + Dirección. **Bloquea:** nada del código; bloquea la definición de la métrica de aceptación del proyecto.

---

### `D-14` · Cómo se entrega el aviso de privacidad sin correo

**El hueco.** `RC-01` exige cumplir la LFPDPPP: el lead tiene que saber que sus datos se están guardando y por qué. En la v1.0 ese aviso viajaba en el correo. Basic no envía correos, así que **se quedó sin canal de entrega**.

La obligación no desaparece con el correo. Solo desaparece la forma de cumplirla.

**Opciones a evaluar con Legal.**
1. Aviso verbal al momento de la captura, reforzando `RC-05`, con un texto corto que el vendedor memorice.
2. Aviso impreso o en tarjeta que el vendedor entregue al recibir la tarjeta del lead.
3. Mostrar el aviso en la pantalla de captura y que el vendedor le enseñe el teléfono al lead.
4. Adelantar el envío de un correo mínimo, solo con el aviso — lo que reabre parcialmente `D-13`.

**No soy abogado y esto no es asesoría legal.** Lo que sí puedo señalar con confianza es que el hueco existe y que apareció como efecto lateral de sacar el correo, no como una decisión consciente. Conviene que Legal lo vea antes del primer evento, no después de capturar doscientas tarjetas.

**Decide:** Legal / Dirección. **Bloquea:** `RC-01`. **Fecha límite útil:** antes del primer evento.

---

## No bloqueantes — se pueden responder durante el desarrollo

### `D-07` · Destino final de los datos

La hoja de cálculo es suficiente para Basic, pero conviene saber ahora si el paso siguiente es HubSpot o Salesforce, para modelar `tipo` e `interes` con los mismos valores que usa el CRM y no migrar después.

Ojo: `tipo` pasó de dos valores (v1.0) a tres en Basic. Si el CRM tiene su propio catálogo, esta es la última oportunidad barata de alinearlo.

**Decide:** Dirección.

---

### `D-08` · Volumen esperado y cuenta de envío

- ¿Cuántos leads por evento y cuántas personas capturando en paralelo? Dimensiona el proveedor de correo (`RNF-10`) y decide `D-03`.
- ¿Desde qué dominio y buzón salen los correos al lead? ¿Quién queda como remitente visible?
- ¿La baja debe propagarse a otras listas de marketing o solo a esta? (`RC-02`)

**Decide:** Marketing.

---

### `D-09` · Alta de usuarios

**Resuelta para V1 por FL-013A.** Hay login pero no hay pantalla de registro ni
de recuperación de contraseña en los mockups.

Las cuentas se crean por administrador/empresa y se entregan al equipo
comercial. Quedan fuera de V1: crear cuenta, recuperación de contraseña, MFA y
login social. AWS Cognito será el proveedor real según ADR-002; su integración
se ejecutará en FL-013B cuando exista AWS DEV.

**Decidió:** Dirección / solicitud FL-013A, 2026-08-31.

---

### `D-10` · Una hoja por evento o una hoja para todo

`SAL-01` dice "la hoja del evento". No está definido si cada evento genera su propia hoja, si todos escriben en una sola con columna de evento, o ambas.

**Implicación.** Con lead directo (`origen = directo`) no hay evento, así que hace falta al menos un destino general.

**Decide:** Marketing.

---

### `D-11` · Retención de audios y fotos

`RC-03` exige un periodo de retención definido con Legal o Dirección. Sin ese número no se puede implementar el borrado automático, y sin borrado automático hay incumplimiento acumulándose desde el primer evento.

**Decide:** Legal / Dirección. **Fecha límite útil:** antes del primer evento.

---

### `D-12` · Licencia de las tipografías

El design system está armado con cortes Trial/Demo de Nexa. Hay que comprar las licencias de producción antes de distribuir la app, aunque sea internamente. Los nombres de archivo se mantienen, así que el cambio no toca código.

**Decide:** Dirección / Marketing.

---

## Resumen de deltas respecto del documento v1.0

Tabla de control de cambios de alcance. Todo lo de aquí ya está reflejado en `01-especificacion.md`.

| Área | v1.0 (PDF) | Basic (este documento) | Estado |
|---|---|---|---|
| Autenticación | Fuera de alcance | Login con usuario y contraseña | **Ampliación** |
| Perfil del vendedor | Campo de ajustes ("quién captura") | Pantalla propia con foto, una sola vez | **Ampliación** |
| Eventos | Un nombre en ajustes | CRUD completo con fechas, activo y contadores | **Ampliación** |
| Origen del lead | Siempre evento | Evento **o** lead directo | **Ampliación** |
| Tipo de lead | 2 valores: Partner, Cliente potencial | 3 valores: Proveedor, Partner, Cliente | **Cambio** — ver `D-07` |
| Siguiente paso | `RF-10`, obligatorio | No existe | **Reducción** — ver `D-02` |
| Nombre | Un solo campo | Nombre + Apellido | **Cambio** |
| Transcripción de voz | `RF-14`, *Debe* | No existe | **Reducción** — ver `D-01` |
| Registros | Lista con contador y estado | + búsqueda, filtros por tipo, detalle en solo lectura, reproductor | **Ampliación** |
| Exportación | CSV | XLS (por defecto) o CSV | **Ampliación** |
| **Correos automáticos** | `RF-27` … `RF-32`, *Debe* | **No existen** | **Reducción** — ver `D-13` |
| Aviso de privacidad y baja | En el correo al lead | Sin canal de entrega definido | **Hueco abierto** — ver `D-14` |
| Apariencia | No mencionada | Tema claro y oscuro | **Ampliación** |
| Edición de un lead guardado | No especificada | Solo lectura | **Definición** — ver `D-04` |
| Publicación en tiendas | Fuera | Fuera | Sin cambio |
| CRM directo | Fuera | Fuera | Sin cambio |
| QR de gafetes | Fuera | Fuera | Sin cambio |
| Panel de métricas | Fuera | Fuera | Sin cambio |

**Lectura del saldo.** Basic es notablemente más grande que el MVP del PDF en todo lo que rodea a la captura — acceso, eventos, consulta — y más chico en lo que sale de ella: sin transcripción, sin siguiente paso y ahora sin correos.

Sacar los correos simplifica bastante el backend: desaparecen el proveedor transaccional, la cola de reintentos de correo, los estados de envío por lead, las plantillas y el riesgo de límites de envío. Lo que queda del lado del servidor es lectura de tarjeta, almacenamiento de archivos y escritura en la hoja.

El riesgo de calendario no está en la pantalla de captura, que ya está resuelta en los mockups. Está en eventos, en sincronización sin duplicados y en el backend de `D-05`. Y el riesgo que no es de software está en `D-13`: la app va a entregar datos limpios y a tiempo a un proceso de seguimiento que sigue siendo manual.
