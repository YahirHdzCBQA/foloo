# Foloo — Paquete de especificación (Basic y Pro)

**Producto:** Foloo · app móvil de captura y seguimiento de leads en eventos
**Versiones especificadas:** Basic (v1) y Pro (v1)
**Solicitante:** Marketing / CBQA Solutions
**Stack acordado:** Flutter (iOS + Android) + backend propio · desarrollo guiado por especificación (SDD)
**Fecha:** agosto 2026

---

## Modelo del paquete: núcleo + delta

**Basic es el núcleo. Pro es Basic más un delta.**

No hay dos especificaciones paralelas ni requerimientos marcados `[Basic]` / `[Pro]` renglón por renglón. Lo primero garantiza que las dos diverjan en silencio; lo segundo obliga al agente a sostener un filtro mental a lo largo de noventa requerimientos, y se le filtra.

La frontera entre versiones vive en **un solo archivo**: `04-matriz-de-capacidades.md`. Es el único lugar donde se responde "¿Basic tiene esto?", y el único que hay que actualizar cuando la respuesta cambie.

### La frontera más importante

**Basic no envía correos.** Ni al lead, ni a marketing. Decisión de los solicitantes, registrada en `D-13`.

| | Promesa | Cómo se cumple |
|---|---|---|
| **Basic** | Que ningún lead se pierda | Todo lead capturado llega completo a la hoja de cálculo el mismo día. El seguimiento lo hace una persona, a mano. |
| **Pro** | Que cada lead reciba contacto el mismo día | El correo sale solo, con la información adjunta |

Consecuencia para el desarrollo: **el proveedor de correo, la cola de reintentos, los estados de envío y las plantillas no se construyen para Basic.** Se construyen completos en Pro. Y consecuencia para el negocio: la métrica de "contacto en 24 horas" que originó el proyecto solo la puede cumplir el producto en Pro.

---

## Orden de lectura

### Si construyes Basic

| # | Archivo | Qué contiene |
|---|---|---|
| 0 | `00-constitucion.md` | Principios no negociables. |
| 1 | `01-especificacion.md` | El qué: alcance, entidades, flujos, 16 pantallas, ~90 requerimientos con ID estable. |
| 2 | `02-escenarios-de-aceptacion.md` | Escenarios verificables en Gherkin. |
| 3 | `03-decisiones-abiertas.md` | Lo que no está decidido. |

**No leas los archivos 04 a 07.** No aplican.

### Si construyes Pro

| # | Archivo | Qué contiene |
|---|---|---|
| 0 | `00-constitucion.md` | Igual. Los principios no cambian entre versiones. |
| 1 | `01-especificacion.md` | Aplica **íntegro**. Pro incluye todo Basic. |
| 2 | `02-escenarios-de-aceptacion.md` | Aplica íntegro, con dos ajustes que indica `06`. |
| 3 | `03-decisiones-abiertas.md` | Vigente, salvo `D-01` que se resuelve distinto — ver `DP-05`. |
| 4 | `04-matriz-de-capacidades.md` | **Empieza aquí.** Qué tiene cada versión y cómo se separan en una sola base de código. |
| 5 | `05-especificacion-pro.md` | El delta: 5 pantallas nuevas, 4 modificadas, ~45 requerimientos nuevos. |
| 6 | `06-escenarios-pro.md` | Escenarios del delta. |
| 7 | `07-decisiones-abiertas-pro.md` | Decisiones que nacen con Pro. |

---

## Cómo se usa esto en SDD

```
00-constitucion.md    →  reglas del juego (constitution)
01-especificacion.md  →  spec del núcleo (= Basic completo)
04-matriz...md        →  frontera entre versiones, fuente única
05-especificacion-pro →  spec del delta Pro
02 / 06               →  criterios de "listo"
03 / 07               →  bloqueadores explícitos
                          ↓
                       plan técnico   (lo produce el dev/agente)
                          ↓
                       tareas         (lo produce el dev/agente)
                          ↓
                       implementación
```

**Regla de trazabilidad:** todo commit, prueba y tarea referencia al menos un ID (`CAP-04`, `CON-09`, `PLT-05`, `RNF-14`…). Un cambio de comportamiento sin ID asociado es un cambio de alcance y necesita actualizarse aquí primero.

**Regla de versión:** ningún requerimiento lleva marcas de versión en su texto. Si necesitas saber si algo aplica a Basic, la respuesta está en `04`, no en el requerimiento.

---

## Insumos de referencia

| Insumo | Qué aporta | Autoridad |
|---|---|---|
| `Foloo Mockups Basic.html` — 16 pantallas, 390×844 | Comportamiento visible, copys, estados | **Autoridad sobre la UI de Basic** |
| `Foloo Mockups App Pro.html` — 21 pantallas, 390×844 | Lo mismo para Pro | **Autoridad sobre la UI de Pro** |
| `Foloo Captura.dc.html` (una versión por paquete) | Pantalla de captura al detalle | Autoridad sobre la captura de su versión |
| `_ds/foloo-design-system/` | Tokens de color, tipografía, espaciado, radios, movimiento | **Autoridad sobre el sistema visual.** No se introducen valores nuevos. |
| `requerimientoscapturaleads_1.pdf` (v1.0) | Requerimientos de negocio originales | Autoridad sobre el **porqué**. Donde este paquete difiere, manda este paquete y la diferencia queda registrada en `03` o `07`. |
| `foloo-mvp.html` | Prototipo web anterior | Solo referencia. **No es contrato.** Su arquitectura (llamada de visión desde el cliente) es explícitamente lo que no debe hacerse. |

Si un texto de este paquete contradice un mockup, gana el mockup y se corrige el texto.

---

## Convención de identificadores

| Prefijo | Área | Versión |
|---|---|---|
| `AUT-` | Autenticación, perfil y sesión | Ambas |
| `EVT-` | Eventos | Ambas |
| `CAP-` | Captura del lead | Ambas |
| `OCR-` | Lectura de la tarjeta | Ambas |
| `VOZ-` | Nota de voz | Ambas |
| `SYN-` | Persistencia local y sincronización | Ambas |
| `SAL-` | Salida de datos: hoja y correos | Ambas |
| `REG-` | Registros, detalle y exportación | Ambas |
| `NAV-` | Navegación, menú y apariencia | Ambas |
| `RNF-` | Requerimientos no funcionales | Ambas |
| `RC-` | Privacidad y cumplimiento | Ambas |
| `SAL-05`…`SAL-10`, `SAL-13`…`SAL-15` | Correos automáticos | **Solo Pro** |
| `CON-` | Biblioteca de contenido y adjuntos | **Solo Pro** |
| `PLT-` | Plantillas de correo | **Solo Pro** |
| `TRA-` | Transcripción | **Solo Pro** |
| `P-` | Pantallas | Ambas |
| `F-` | Flujos | Ambas |
| `D-` / `DP-` | Decisiones abiertas de Basic / de Pro | — |
| `E-` / `EP-` | Escenarios de aceptación de Basic / de Pro | — |

Prioridad: **Debe** (bloquea la entrega) · **Debería** (entra si no compromete lo anterior) · **Podría** (backlog explícito).
