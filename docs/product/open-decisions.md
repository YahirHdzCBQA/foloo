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

**Bloquea:** parte post-guardado de `VOZ-03`, `REG-07`, `REG-08`.

### `D-07` · Contrato de exportación XLSX/CSV

**Pregunta:** columnas exactas, orden, nombres, tratamiento de notas/medios y
conducta cuando el filtro está en “Todos los eventos”.

**Bloquea:** `REG-10`–`REG-13`; no bloquea la presencia del selector XLSX/CSV.

### `D-08` · Límites y caché de PDF

**Pregunta:** peso por PDF, total local/remoto y política de desalojo.

**Bloquea:** `CON-09`, `CON-10` e infraestructura/costos asociados.

### `D-09` · Plataforma de correo

El SDD anterior recomendaba evaluar Amazon SES; el tablero 2026-09-08 exige
envío firmado por Google Workspace con DKIM. SPF/DKIM/DMARC, rebotes y
reputación son requisitos, pero ninguna fuente aprueba el proveedor final.

**Bloquea:** backend de `SAL-01`–`SAL-07` y ADR de correo.

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
