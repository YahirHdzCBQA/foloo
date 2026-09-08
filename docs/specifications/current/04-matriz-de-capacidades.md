# 04 · Matriz de capacidades — Foloo V1 unificado

Esta matriz organiza el único producto V1. **No es una frontera comercial**:
todas las capacidades funcionales pertenecen a la misma cuenta. La suscripción
solo gobierna la posibilidad de crear Leads nuevos después del trial.

| # | Capacidad V1 | Requisitos | Estado aproximado al 2026-09-08 |
|---:|---|---|---|
| 01 | Escaneo OCR de tarjetas | `OCR-01`–`OCR-09` | Parcial: ML Kit y UI existen; falta validación de campo |
| 02 | Clasificación e interés | `CAP-05`, `CAP-06` | Implementado localmente |
| 03 | Eventos y leads directos | `EVT-01`–`EVT-12` | Implementado local; falta cloud/sync |
| 04 | Plantillas con variables | `PLT-01`–`PLT-07` | Demo UI; falta persistencia/servidor |
| 05 | Contenido PDF | `CON-01`–`CON-10` | Flujo local parcial; falta persistencia/S3 |
| 06 | Gestión de leads por evento | `REG-01`–`REG-04` | Implementación local sustancial |
| 07 | Detalle de lead | `REG-05`–`REG-08` | Consulta/visores; falta edición |
| 08 | Voice Note | `VOZ-01`–`VOZ-08` | Local sustancial; falta tope y post-edición |
| 09 | Imágenes de referencia | `CAP-08`, `REG-06` | Implementadas localmente detrás de gating obsoleto |
| 10 | Correo de seguimiento | `SAL-01`–`SAL-07` | Solo demo UI; backend bloqueado |
| 11 | Exportar por evento | `REG-09`–`REG-13` | Diálogo demo; archivos no implementados |
| 12 | Offline total y sincronización | `SYN-01`–`SYN-10` | Drift/conectividad existen; sync no |

Capacidades transversales: autenticación/perfil (`AUT-*`), navegación
(`NAV-*`), monetización (`MON-*`), infraestructura (`INF-*`), calidad
(`RNF-*`, `REL-*`) y cumplimiento (`RC-*`).

## Regla de producto

No se oculta Contenido, Correo, imágenes o cualquier otra capacidad por un
“plan”. Debe retirarse el selector de desarrollo `AppPlan.basic/pro` y su
gating en una FL posterior trazada; FL-013C solo documenta la obsolescencia.
