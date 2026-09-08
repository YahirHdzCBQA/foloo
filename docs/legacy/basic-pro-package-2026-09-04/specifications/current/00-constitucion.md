# 00 · Constitución de Foloo Basic

Principios no negociables. Cualquier decisión de implementación que contradiga uno de estos artículos es un defecto, aunque la funcionalidad "sirva".

---

## Artículo 1 — El contexto de uso manda sobre todo lo demás

La app se usa **de pie, en el piso de una expo, con una sola mano**, mientras la persona sostiene una tarjeta que le acaban de dar y alguien le sigue hablando. El wifi del recinto es malo o inexistente.

De ahí se derivan cuatro reglas que no se negocian:

1. Un lead completo se registra en **menos de 60 segundos**, desde abrir la app hasta el acuse.
2. **Todo funciona sin conexión.** Lo que necesita red se degrada; nunca bloquea.
3. **Nada de teclear lo que ya está impreso** en la tarjeta.
4. **Un solo pulgar alcanza todos los controles** de la acción principal.

Si una funcionalidad es correcta pero agrega pasos, la funcionalidad está mal.

---

## Artículo 2 — El lead nunca se pierde

El guardado local ocurre **antes** de cualquier intento de red, siempre. Ningún fallo de OCR, de hoja de cálculo, de subida de archivos o de conexión puede impedir que un lead quede registrado.

Corolario: **no existe un estado en el que el usuario pierda datos ya capturados.** Ni al cerrar la app, ni al perder señal, ni al fallar un servicio externo, ni al eliminar un evento.

---

## Artículo 3 — Ninguna credencial vive en el teléfono

Las llaves de API — visión, hoja de cálculo, almacenamiento y, donde exista, correo — viven **solo en el servidor**. La app habla exclusivamente con el backend propio de Foloo por HTTPS.

Razón de negocio: un APK se descompila. Una llave expuesta es una fuga de datos personales de terceros y una multa.

Corolario arquitectónico: **la app entrega el registro, el servidor decide a dónde va.** Cambiar el destino de los datos (hoja → CRM) no debe obligar a publicar una versión nueva de la app.

---

## Artículo 4 — Offline no es un error

Estar sin conexión es el estado normal en una expo, no una falla. Se comunica con calma: gris, icono `wifi-off` y una frase que tranquiliza.

> "Se guarda en tu teléfono. Se sube cuando haya señal."

Nunca en rojo. Nunca con signo de admiración. Nunca bloqueando.

---

## Artículo 5 — Ningún estado se comunica solo con color

Sincronizado, pendiente, sin conexión y error llevan **siempre** icono **y** palabra, además del color. Un usuario con daltonismo, con el teléfono al sol o con brillo bajo tiene que poder leer el estado.

---

## Artículo 6 — El sistema de diseño es cerrado

Cuatro colores: `#FFFFFF`, `#1F1F1F`, `#C9FA00` (lima), `#888888`. Todo lo demás se **deriva** de ellos y está en `tokens/colors.css`. No se inventan valores.

- Texto sobre lima siempre `#1F1F1F`. Blanco sobre lima está prohibido.
- **Un solo elemento lima por pantalla.** Dos elementos lima significan que nada es primario.
- Tema claro primero; el oscuro es un remapeo de tokens, no una reescritura.
- Tres tipografías con roles exclusivos: **Nexa Black/Heavy** para títulos y números grandes, **Poppins 500/600** para botones, etiquetas y chips (≤20 caracteres), **DM Sans 400/500/700** para todo el texto largo y todo el contenido del usuario.
- Sin gradientes, sin vidrio, sin glow, sin neón, sin imágenes de fondo, sin sombras internas. Radio 0px no existe: el círculo es la forma base de la marca.
- Presupuesto de movimiento: retroalimentación 100 ms · cambio de estado 150 ms · hojas 200 ms · **techo duro 250 ms**. `prefers-reduced-motion` colapsa todo a 1 ms.
- El **único momento expresivo** del sistema es la confirmación de lead guardado.

---

## Artículo 7 — Ergonomía de una mano

- Área táctil mínima absoluta: **48 dp**. Ningún control por debajo.
- La acción principal vive en un **dock fijo inferior de 56 dp** de alto, con hairline de 1px arriba.
- **Las acciones destructivas nunca van en el tercio inferior.** "Eliminar evento" y "Cerrar sesión" viven lejos del pulgar, con su propio contorno.
- Orientación **vertical únicamente**.

---

## Artículo 8 — La voz del producto

- Se habla de **tú**. El producto nunca dice "nosotros".
- Sentence case en todo. Sin ALL CAPS salvo el eyebrow de 11px.
- Sin signos de admiración. Sin emoji, nunca, en ningún lugar.
- Los errores dicen qué pasó y cuál es la salida, y no piden disculpas:
  > "Tarjeta ilegible. Escribe los datos a mano."
  > Nunca: "Ups, algo salió mal."
- Los estados vacíos son invitaciones a capturar, no callejones.
- Español y inglés son ambos de primera clase. El español corre 15–30% más largo: sin botones de ancho fijo, sin etiquetas forzadas a una línea.

---

## Artículo 9 — Datos personales de terceros

Se están capturando datos de personas que no son el usuario. La LFPDPPP aplica desde el primer lead, no desde el primer cliente, y **aplica igual cuando la app no envía nada**: el deber nace al guardar el dato, no al usarlo. El cumplimiento (`RC-*`) no es backlog.

---

## Artículo 10 — Lo que no está escrito, se pregunta

El agente **no inventa** comportamiento faltante. Si algo no está en `01-especificacion.md` ni visible en los mockups, se busca en `03-decisiones-abiertas.md`. Si tampoco está ahí, se levanta como decisión nueva y se detiene esa rama del trabajo.

Inventar un campo, un estado o un flujo cuesta más caro que preguntar.
