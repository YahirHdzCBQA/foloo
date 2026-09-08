# Trazabilidad vigente — Foloo V1

Este índice cubre especificación, aceptación, evidencia actual y trabajo
operativo. “Evidencia” no significa aceptación productiva.

| IDs | Área | Escenarios | Evidencia principal | Pendientes 2026-09-08 |
|---|---|---|---|---|
| `AUT-01`–`AUT-13` | Cognito, perfil, ownership | E-01 | `app/lib/auth/`, `app/lib/app.dart`, auth/ownership tests | f1-01, f1-02, f4-02 |
| `EVT-01`–`EVT-12` | Eventos/origen | E-02 | event/origin screens, repositories, selection policy/tests | f1-03–f1-05 |
| `CAP-01`–`CAP-12` | Captura/guardado/medios | E-03–E-05, E-11 | lead capture, multi-photo, Drift LeadRepository | f1-06, f1-08, f1-09, f1-11, f1-12, f1-14, f1-24 |
| `OCR-01`–`OCR-09` | ML Kit | E-03 | recognition/parser/preprocessor services and tests | f1-07, f5-04 |
| `VOZ-01`–`VOZ-08` | Voice Note/texto | E-04 | voice service/state/widget/records tests | f1-10, f1-21–f1-23 |
| `SYN-01`–`SYN-10` | Local/offline/sync | E-05, E-09 | Drift schema/repositories, private media, connectivity | f1-13, f1-20, f1-21, f4-01, f4-03 |
| `REG-01`–`REG-13` | Registros/detalle/export | E-06, E-10 | records screen/tests; export dialog demo | f1-16–f1-19, f2-06, f2-07, f5-12 |
| `CON-01`–`CON-10` | PDF/contenido | E-07 | content screen, picker, assignment sheet | f2-01–f2-03 |
| `PLT-01`–`PLT-07` | Plantillas | E-08 | email screen demo | f2-04 |
| `SAL-01`–`SAL-07` | Correo | E-08 | confirmation/email UI demos only | f2-05, f4-04, f4-12 |
| `NAV-01`–`NAV-07` | Shell, tema, idioma | E-12 | drawer, theme, l10n and navigation/localization tests | f1-15, f1-25, f1-26 |
| `MON-01`–`MON-08` | Trial/suscripción | E-11 | no production implementation | f3-01–f3-08 |
| `INF-01`–`INF-04` | Cloud/operación | E-09, E-12 | ADR-001/002 only for Drift/Cognito | f4-01–f4-12 |
| `RNF-01`–`RNF-08` | Calidad transversal | E-12 | mixed unit/widget evidence | f5-01–f5-06 |
| `RC-01`–`RC-05` | Legal/privacidad | E-08, E-12 | requirements only | f4-10, f5-09 |
| `REL-01`–`REL-08` | Producción | E-12 | local automated tests only | f5-01–f5-12 |

## Fuente operativa

La auditoría renglón por renglón de los 65 pendientes está en
`../migration/current-implementation-gap-analysis.md`. El workbook original
no fue editado. Estados aproximados se basan en archivos y tests del commit
`f5f207c`; no reemplazan QA manual, backend o aceptación de tiendas.

## Historial

El índice Basic/Pro anterior se conserva en
`../legacy/basic-pro-package-2026-09-04/specifications/traceability.md`.
Ninguna equivalencia de edición sigue vigente. Los IDs de la versión unificada
se interpretan exclusivamente por el texto actual.
