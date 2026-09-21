# Decisiones abiertas — Foloo V1

Estas decisiones no se resuelven por inferencia. Cada una bloquea únicamente el
trabajo indicado.

## Bloqueantes de producto/negocio

### `D-01` · Estrategia de cobro frente a las tiendas

**Pregunta:** compra in-app, pago externo en navegador o external purchase link
permitido por región/tienda.

**Bloquea:** `MON-03`–`MON-06`, paywall, confirmación y revisión de tiendas.

### `D-02` · Precio, moneda y regiones

**Bloquea:** productos, copy y pruebas de `MON-04`.

### `D-03` · Vencimiento, avisos y periodo de gracia

**Bloquea:** estados y aceptación de `MON-06`, `MON-08`.

### `D-04` · Cancelación y reembolsos

**Bloquea:** términos, ficha de tienda y flujo de recuperación comercial.

### `D-05` · Tope de Voice Note

**Pregunta:** límite por duración, peso o ambos; aviso y conducta al alcanzarlo.

**Bloquea:** `VOZ-07`, storage/costos y pruebas móviles.

### `D-06` · Edición de medios después de guardar

El alcance exige detalle editable y el tablero pide regrabar/eliminar Voice
Note antes y después. Falta definir auditoría, reenvío de correo y efecto sobre
adjuntos ya congelados.

**Bloquea:** edición/reemplazo/eliminación post-guardado de medios en `VOZ-03`,
`REG-07` y `REG-08`; no bloquea los campos estructurados aprobados en `REG-07`.

### `D-10` · Contrato API futuro de Foloo Teams

**Bloquea:** cerrar el modelo organizacional futuro de `INF-01`; no autoriza
construir dashboard o roles en V1.

### `D-11` · Mockups faltantes

Faltan diseños aprobados de paywall, confirmación de pago, subida de PDF,
imágenes de referencia y controles post-grabación. La UI existente es evidencia
parcial, no una resolución de Diseño.

**Bloquea:** fidelidad final de `MON-03`, `CON-02`, `CAP-08`, `VOZ-02`.

### `D-13` · Retención, cifrado local y eliminación legal

**Bloquea:** producción de `INF-02`, `RC-02`–`RC-04`.

## FL-019 · Decisiones resueltas el 2026-09-18

`D-09`–`D-20` ya no son bloqueos de producto. Su contrato vigente está en
`PLT-01`–`PLT-07`, `SAL-01`–`SAL-09`, E-08 y ADR-006/007:

- `D-14`: whitelist de nueve variables y render defensivo.
- `D-15`: defaults Event/Direct ES/EN, mensaje personal HTML ligero y plain text,
  asunto/cuerpo/firma editables. El asunto inicial aprobado es
  `Damos seguimiento, {nombre}` / `Following up, {nombre}`; aplica solo cuando
  no existe una plantilla persistida y no reescribe snapshots históricos.
- `D-16`: footer fijo con enlace Foloo de opt-out owner/workspace-scoped. GET
  valida y muestra landing sin efecto lateral; solo POST tras confirmación
  explícita persiste la baja idempotente. El bloqueo posterior es terminal.
  La dirección postal/responsable legal exacto sigue pendiente de compliance;
  no se inventa ni bloquea el mecanismo técnico de baja.
- `D-17`: Lead guardado abre la revisión concreta; solo el CTA `foloo` congela
  y envía o encola; sin email no crea envío; reenvío manual es nueva intención.
- `D-18`: cinco estados visibles y no retry automático tras aceptación ambigua;
  aceptación de proveedor no significa entrega final. Rebotes posteriores,
  si el proveedor los notifica, no se inventan como confirmación en V1.
- `D-19`: ausencia o tamaño de PDF requiere elección explícita del vendedor;
  límite de email depende del proveedor y del MIME, no de CON-10. Microsoft
  V1 usa `Mail.Send` + `offline_access`; `Mail.Read`/`Mail.ReadWrite` no están
  aprobados y un adjunto que los requiera se omite solo con confirmación para
  esa intención o se cancela.
- `D-20`: conectar/reconectar sin pérdida; cambio de identidad exige
  confirmación para pendientes; historial conserva remitente original.
