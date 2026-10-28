# Decisiones abiertas — Foloo V1

Estas decisiones no se resuelven por inferencia. Cada una bloquea únicamente el
trabajo indicado.

## Bloqueantes de producto/negocio

### `D-01` · Estrategia de cobro frente a las tiendas

Producto/CBQA comunicó la dirección de gestionar suscripciones y pagos desde
`foloo.io`, no mediante compras integradas. Sigue abierta la validación de si y
cómo esa comercialización, enlace o comunicación externa está permitida por
región y tienda, además del proveedor definitivo.

**Estado 2026-10-21:** Producto aprobó la variante A de ADR-008 (cobro web con
Stripe Checkout; la app solo informa, sin precio ni enlace). Queda abierta la
variante B (compra nativa) si las tiendas rechazan la A.

**Pregunta:** compra in-app, pago externo en navegador o external purchase link
permitido por región/tienda.

**Bloquea:** compra/checkout de FL-021, confirmación y revisión de tiendas. No
bloquea el enforcement ni el paywall informativo sin precio de FL-020.

### `D-02` · Precio, moneda y regiones

**Estado 2026-10-28:** los ajustes de contenido del landing
(`foloo-landing-ajustes.md`, paquete de diseño recibido el 2026-10-27) fijan
los planes comerciales:

| Plan       | Precio                                              | Límite                        |
| ---------- | --------------------------------------------------- | ----------------------------- |
| Free trial | Gratis                                              | 5 leads, sin límite de tiempo |
| Foloo      | 89 USD al año · 1,780 MXN al año, impuesto incluido | Sin límite de capturas        |

- Compra anual únicamente: no existe modalidad mensual.
- Las capacidades son las mismas en los dos planes; solo cambia el tope de
  capturas (`MON-01`, `MON-04`).
- Foloo Team solo se menciona como nombre + "Próximamente", sin capacidades
  ni precio (`D-10`).

Siguen abiertos: regiones/países de venta, qué moneda se presenta en cada
región y si "impuesto incluido" aplica también al importe en USD.

**Bloquea:** solo la configuración regional/fiscal del Price de Stripe
(`MON-18`). Ya no bloquea el precio, la moneda base ni el periodo de
`MON-04`.

### `D-03` · Vencimiento, avisos y periodo de gracia

**Bloquea:** reglas temporales reales que produzcan `expired`, avisos y gracia
en FL-021. No bloquea representar ni aplicar un snapshot `expired`.

### `D-04` · Cancelación y reembolsos

Account Deletion debe solicitar la cancelación de renovaciones de una
suscripción PRO activa y comprobar el resultado antes de anunciar éxito. Siguen
abiertos proveedor/API, pagos ya efectuados, periodos pagados, reembolsos y
resolución de fallos en FL-021.

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
imágenes de referencia, controles post-grabación y el polish visual de Email
Review. La UI existente es evidencia parcial, no una resolución de Diseño.

**Bloquea:** fidelidad visual final de `MON-03`, `CON-02`, `CAP-08`, `VOZ-02` y
FL-019.5. No reabre ni cambia la semántica funcional cerrada de FL-019.

### `D-13` · Retención, cifrado local y eliminación legal

STORE-02C confirmó que los tombstones de Event/Lead/Content y el logout no son
eliminación integral de cuenta. STORE-02 ya fue implementado y validado con una
identidad sintética en AWS DEV; antes de habilitar producción deben decidirse, por cada
categoría de datos: base y plazo de retención, backups/logs, borrado físico S3,
revocación OAuth, cifrado local adicional, tratamiento del outbox y barrera
anti-resurrección, excepciones legales, SLA/confirmación y derechos del titular.
El inventario preliminar está en
[`../delivery/privacy-compliance.md`](../delivery/privacy-compliance.md) y el
contrato técnico, matriz y decisiones que necesitan aprobación están en
[`../delivery/account-deletion-contract.md`](../delivery/account-deletion-contract.md).
El registro posterior a revisión y la agenda de validaciones pendientes están en
[`../delivery/account-deletion-cbqa-approval-agenda.md`](../delivery/account-deletion-cbqa-approval-agenda.md).
STORE-02E-01 formaliza el comportamiento estable en `AUT-18`–`AUT-21`,
`SYN-11`–`SYN-12`, `MON-13`, `INF-15`–`INF-21`, `RNF-09`–`RNF-10`,
`RC-06`–`RC-10` y E-14; su matriz de criterios, decisiones y gates está en
[`../delivery/account-deletion-requirements-traceability.md`](../delivery/account-deletion-requirements-traceability.md).
Las alternativas `ADR-AD-01`–`ADR-AD-06` permanecen propuestas no aceptadas.
STORE-02D registra acuerdos de Producto/CBQA comunicados el 2026-10-20: borrado
de datos personales/operativos por defecto; irreversibilidad tras aceptación;
posibilidad de alta nueva con el mismo correo después de 30 días; máximo
operativo de eliminación de 15 días; `foloo.io` como punto previsto para
eliminación y suscripciones; y alcance multirregión. No constituyen autorización
integral para producción. Continúan pendientes: categorías/base/plazos
Legal/Contabilidad; propuesta de backups ordinarios de 15 días; registro mínimo
y enforcement seudonimizado de 30 días; propuesta de reautenticación de cinco
minutos; owner operativo; proveedor/políticas de pagos; rol sobre datos de
terceros; países, idiomas y menores; y validación/publicación web.

**Bloquea:** habilitación de producción de `INF-02`, `RC-02`–`RC-04`, el flujo
in-app/web y las declaraciones finales App Privacy/Data Safety. No invalida la
evidencia técnica DEV ni permite omitir la eliminación exigida por tiendas.

### `D-21` · Alternativa equivalente para Google Sign-In en iOS

**Pregunta:** aprobar Sign in with Apple mediante Cognito o retirar Google
Sign-In de iOS. La lectura conservadora de Apple 4.8 no considera suficiente el
login email/password mientras Google autentique la cuenta primaria; las
excepciones publicadas no describen claramente el producto actual.

**Bloquea:** configuración/implementación de la alternativa, account linking y
submission pública iOS. No cambia `sub` como owner, no autoriza unir cuentas por
email y no afecta el OAuth de sender.

## FL-019 · Decisiones resueltas el 2026-09-18

`D-09`–`D-20` ya no son bloqueos de producto. Su contrato vigente está en
`PLT-01`–`PLT-07`, `SAL-01`–`SAL-09`, E-08 y ADR-006/007:

- `D-14`: whitelist de nueve variables y render defensivo.
- `D-15`: defaults Event/Direct ES/EN, mensaje personal HTML ligero y plain text,
  asunto/cuerpo/firma editables. El asunto inicial aprobado es
  `Damos seguimiento, {nombre}` / `Following up, {nombre}`; aplica solo cuando
  no existe una plantilla persistida y no reescribe snapshots históricos.
- `D-16` (superseded el 2026-09-23 por FL-019.5): el footer/enlace Foloo de
  opt-out dejó de pertenecer a V1. Se conservan historia y tablas sin rutas ni
  comportamiento activo. Esto no afirma cumplimiento; privacidad/base legal y
  requisitos de baja siguen pendientes antes de Store Release.
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
