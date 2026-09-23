# Trazabilidad y estado de implementación — Foloo V1

## Requisito → escenario → decisión/ADR → evidencia

| IDs | Escenario | Decisión/ADR | Evidencia / pendientes |
|---|---|---|---|
| `AUT-*` | E-01 | ADR-002/006 | `app/lib/auth/`; perfil → onboarding opcional de cuenta de envío owner-scoped; f1-01, f1-02, f4-02 |
| `EVT-*` | E-02 | ADR-001/004 | FL-017 estabiliza create/update/delete remoto, tombstones y confirmación; tests event sync/UI/backend; f1-03–05 |
| `CAP-*`, `OCR-*` | E-03–E-05 | ADR-001; D-11 | captura/ML Kit/Drift; f1-06–09, 11–14, 24 |
| `VOZ-*` | E-04 | ADR-001; D-05/D-06 | voice service/media/tests; f1-10, 21–23 |
| `SYN-*` | E-05/E-09/E-13 | ADR-001/003/004/005; D-13 | Drift, outbox owner-scoped, retry/reconciliación FL-015 y transferencia media FL-016 |
| `REG-*` | E-06/E-10 | ADR-001/004; D-06 | FL-017: filtro/detalle/edición optimista y export XLSX/CSV local; f1-16–19, f2-06/07, f5-12 |
| `CON-*` | E-07 | D-11/D-13 | FL-018: 25 MB/PDF, copia privada durable, outbox/S3 y tombstone; D-11 afecta solo fidelidad visual y D-13 retención física; f2-01–03 |
| `PLT-*`, `SAL-*` | E-01/E-08 | ADR-006/007; D-09 y D-14–D-20 resueltas | FL-019 CLOSED y validada físicamente: renderer/editor, Drift v10 con segmentos semánticos y dirty state independiente, jerarquía Foloo→seller→Evento, preparación única reconciliable antes de `foloo`, snapshot congelado, estado Drift reactivo, outbox, OAuth state+PKCE, Gmail/Graph, KMS, D-19 y opt-out. FL-019.5 queda limitada al polish visual de Review y espera mockup; f2-04/05, f4-04/12 |
| `NAV-*` | E-12 | ADR-001 | drawer/theme/l10n; f1-15/25/26 |
| `MON-*` | E-11 | D-01–D-04/D-11 | sin implementación; f3-01–08 |
| `INF-*`, `RC-*` | E-09/E-12/E-13 | ADR-001/002/003/005/006/007; D-10/D-13 | backend AWS FL-014 y S3 privado/presigned/confirmación FL-016; FL-019 implementa egreso seguro y opt-out técnico; compliance postal sigue pendiente |
| `REL-*`, `RNF-*` | E-12 | decisiones aplicables | suite local parcial y round-trip UTF-8 en app/backend; f5-01–12 |

Los IDs antiguos aún presentes en código/tests describen el origen histórico de
una implementación. El texto actual de `docs/product/product-spec.md` gobierna;
no existe compatibilidad funcional Basic/Pro.

### Compatibilidad de trazas existentes en código/tests

| Traza histórica aún visible | Traza V1 actual |
|---|---|
| `AUT-08` logout | `AUT-11` |
| `AUT-10` alta | `AUT-04` |
| `AUT-11` confirmación/reenvío | `AUT-05`, `AUT-06` |
| `AUT-12` Cognito `sub` | `AUT-10` |
| `EVT-12` selección automática | `EVT-06` |
| `EVT-13` agrupación por fecha | `EVT-07`, `EVT-08` |
| `CAP-22`, `CAP-23`, `REG-13` imágenes | `CAP-08`, `REG-06` |
| `CON-08` contenido al crear evento | `CON-06`, `EVT-11` |
| `SYN-05` indicador de conexión | `SYN-03` |
| `REG-07` detalle solo lectura | `REG-05`; edición vigente en `REG-07` |

## Auditoría de los 65 pendientes contra el repositorio

- Corte: commit `f5f207c`, 2026-09-08.
- Fuente: hoja `Pendientes` del XLSX entregado; el archivo original no se editó.
- Estados: **I** implementado localmente con evidencia; **P** parcial/demo o
  falta aceptación remota; **F** sin implementación suficiente.
- Totales aproximados: **15 I · 21 P · 29 F = 65**.

Ningún **I** sustituye QA de dispositivo, backend, seguridad o aceptación de
Producto. El código de edition gating existente es obsoleto aunque la función
interna sea reutilizable.

## F1 · Producto, núcleo de captura (26)

| ID | Estado | Evidencia actual | Cobertura / siguiente FL |
|---|:---:|---|---|
| f1-01 | I | `auth/`, Login/SignUp/Confirm, Cognito runtime y auth tests | FL-013A/B; validación manual pendiente |
| f1-02 | P | `ProfileSetupScreen`, ProfileRepository | FL-013A; faltan puesto/teléfono y edición completa |
| f1-03 | I | origin screen, `LeadOriginKind`, lugar y persistence | FL-013 + tests de navegación |
| f1-04 | I | EventScreen, confirmación, EventRepository, outbox y POST/PUT/DELETE remoto con tombstone | FL-017 CLOSED; tests Drift/sync/backend/UI y QA física |
| f1-05 | I | `EventSelectionPolicy`, preferencia manual y refresh diario | FL-013A refinement |
| f1-06 | I | LeadCaptureScreen: scroll, progreso y dock | FL-002/008/010 |
| f1-07 | P | ML Kit, parser/preprocessor, reprocesar y tests | FL-005/011; falta campaña de precisión real |
| f1-08 | I | `LeadType` y tres choices | FL-008/010 |
| f1-09 | I | `InterestLevel`, selector y riel Records | FL-004/010 |
| f1-10 | I | VoiceNoteService/state/widget y reproducción | FL-006/010/012 |
| f1-11 | I | nota escrita en LeadDraft/Drift/UI | FL-002/012 |
| f1-12 | I | `_revealFirstInvalidField` y tests de captura | FL-013 |
| f1-13 | I | Drift, ConnectivityService y outbox/API sync local-first | FL-012/012.1/015; correo sigue posterior |
| f1-14 | P | LeadConfirmationScreen y retorno | FL-004/009; estados siguen demo |
| f1-15 | P | AppDrawer expone todos los destinos V1 sin selector/gating | FL-003/009/013D; falta saldo real |
| f1-16 | I | RecordsScreen con evento/búsqueda/tipo/estado y orden estable | FL-017; `records_voice_note_test.dart` |
| f1-17 | I | orden local y `_EmptyRecords` | FL-004/012 |
| f1-18 | I | detalle edita solo campos REG-07, Drift-first + PUT optimista | FL-017; tests de repositorio/sync/backend |
| f1-19 | I | visor modal de tarjeta desde detalle | FL-010/013 |
| f1-20 | P | varios estados usan icono/palabra | FL-010; falta auditoría global |
| f1-21 | I | PrivateMediaStorage persiste tarjeta/voz y FL-016 añade subida S3 validada | FL-016 CLOSED; retención legal/física sigue en D-13 |
| f1-22 | I | reproducción, pausa, borrado y regrabación antes/después cubiertos por widget tests | FL-006/010/013; política remota futura sigue en D-06 |
| f1-23 | F | no existe tope productivo | bloqueado D-05 |
| f1-24 | I | multi-photo, Drift media y visor disponibles para toda cuenta | FL-013A refinement/013D |
| f1-25 | I | themes, toggle y preferencia por usuario | FL-009/011/012 |
| f1-26 | P | ARB ES/EN, selector y localization tests | FL-011; quedan demos/cadenas por auditar |

## F2 · Seguimiento y salida de datos (7)

| ID | Estado | Evidencia actual | Cobertura / siguiente FL |
|---|:---:|---|---|
| f2-01 | I | ContentScreen y repositorio durable owner-scoped con biblioteca/filtro | FL-018 CLOSED; QA física |
| f2-02 | I | PdfPickerService, copia privada, visor offline, outbox y S3 | FL-018 CLOSED; límite 25 MB validado |
| f2-03 | I | asignación Event↔Content y tombstone sin resurrección ni cascada destructiva | FL-018 CLOSED; D-13 conserva cleanup físico abierto |
| f2-04 | I | FL-019: EmailScreen Event/Direct ES/EN persiste en Drift v10; preview usa Lead real y el snapshot revisado queda congelado en la outbox; renderer backend conserva whitelist y footer fijo | FL-019 CLOSED; QA física final aprobada |
| f2-05 | I | Follow-up e intención owner-scoped, confirmación explícita, Gmail/Graph, D-19, reintento seguro, estado ambiguo, opt-out y reenvío manual | FL-019 CLOSED; ADR-006/007; QA física final aprobada |
| f2-06 | I | XLSX real por evento, columnas/filename ES/EN y share sheet | FL-017; `records_export_service_test.dart` |
| f2-07 | I | CSV BOM UTF-8, RFC 4180, Unicode y share sheet | FL-017; `records_export_service_test.dart` |

## F3 · Monetización (8)

| ID | Estado | Evidencia actual | Cobertura / siguiente FL |
|---|:---:|---|---|
| f3-01 | F | sin contador server-side | FL de monetización; política bloqueada por D-01 |
| f3-02 | F | no hay saldo de trial real | FL de monetización |
| f3-03 | F | no hay paywall aprobado | bloqueado D-01/D-11 |
| f3-04 | F | no hay precio/productos | bloqueado D-02 |
| f3-05 | F | no hay compra | bloqueado D-01 |
| f3-06 | F | no hay webhooks | FL backend/pago |
| f3-07 | F | no hay caché de suscripción | FL monetización/offline |
| f3-08 | F | no hay vencimiento/gracia | bloqueado D-03/D-04 |

## F4 · Infraestructura (12)

| ID | Estado | Evidencia actual | Cobertura / siguiente FL |
|---|:---:|---|---|
| f4-01 | P | modelo/repositorios locales Drift | FL-012/013A; faltan API/cloud |
| f4-02 | P | Cognito real y `sub` ownership | FL-013B; workspace remoto no existe |
| f4-03 | I | storage privado local + S3 directo/seguro desplegado y validado | FL-016/018 CLOSED; retención D-13 abierta |
| f4-04 | I | frontera de proveedor Google/Microsoft, OAuth, Gmail/Graph, opt-out y estados remotos | FL-019 CLOSED; ADR-006/007; rebote posterior no se inventa como entrega |
| f4-05 | I | confirmación distingue guardado local, pendiente offline, aceptación remota y estado ambiguo | FL-019 CLOSED; Google Sheets sigue fuera de V1 |
| f4-06 | F | no hay modelo org/teams aprobado | bloqueado D-10 |
| f4-07 | P | config Cognito DEV/PROD centralizada | FL-013B; sin staging/secret ops |
| f4-08 | F | sin CI/CD/distribución documentada | FL plataforma |
| f4-09 | F | sin observabilidad/alerta sync | FL plataforma |
| f4-10 | F | sin backup/retención/borrado | bloqueado D-13 |
| f4-11 | F | sin modelo de costo por vendedor | FL infraestructura |
| f4-12 | P | identidad OAuth efectiva y aislamiento implementados; footer/opt-out técnico operativos | FL-019 CLOSED; dirección postal/responsable legal exactos siguen en compliance |

## F5 · Salida a producción (12)

| ID | Estado | Evidencia actual | Cobertura / siguiente FL |
|---|:---:|---|---|
| f5-01 | P | suite Flutter amplia por flujos locales | falta E2E iOS/Android/backend |
| f5-02 | P | `layout_test.dart` y reglas de tema | falta matriz real de dispositivos |
| f5-03 | P | motor/reconexión cubiertos localmente; falta E2E en dispositivo contra AWS | validación manual FL-015 |
| f5-04 | P | unit tests parser/preprocessor/ML Kit boundary | falta evento/tarjetas reales |
| f5-05 | F | no hay pagos | después de monetización |
| f5-06 | F | sin beta de campo documentada | salida a producción |
| f5-07 | F | no hay evidencia repo de cuentas vigentes | operación externa |
| f5-08 | F | sin paquete completo de tienda ES/EN | salida a producción |
| f5-09 | P | permisos cámara/micrófono existen | faltan privacidad/términos/suscripción |
| f5-10 | F | sin envío/revisión de tiendas | salida a producción |
| f5-11 | F | sin tag/release notes/soporte V1 | salida a producción |
| f5-12 | I | exportador XLSX/CSV real, Unicode y share sheet | FL-017 CLOSED; f2-06/f2-07 |

## Convergencia de runtime completada en FL-013D

- Eliminados `AppPlan`, selector demo, condicionales `isPro` y fixtures con
  nombres de edición.
- Contenido, Correo, lugar directo, asignación de PDF e imágenes de referencia
  quedan accesibles para toda cuenta V1.
- Retiradas la UI de transcripción automática y las afirmaciones de Google
  Sheets en acuse/estado. La columna Drift histórica se conserva nullable para
  leer bases existentes sin reset ni pérdida.
- Cognito, ownership y schemaVersion permanecen sin cambios.

## Fundación cloud FL-014

- `backend/src/` implementa la Lambda modular, validación, aislamiento por
  workspace, idempotencia y contrato de errores bajo `/v1`.
- `backend/db/migrations/` define PostgreSQL con UUID, constraints, revisión,
  soft delete e índices; no almacena binarios.
- `backend/infra/` define API Gateway JWT, Lambda/VPC, RDS privado, SGs y
  Secrets Manager sin recrear Cognito.
- `backend/openapi/foloo-v1.yaml` es el contrato desplegable de los endpoints
  implementados. FL-015 conecta sync; FL-016/018 agregan
  autorización/confirmación de medios y Content privados, y FL-019 el correo.

## FL históricas con evidencia reutilizable

| FL | Evidencia |
|---|---|
| FL-001/007 | SDD previo; ahora histórico |
| FL-002–004 | captura, login/drawer, records/event |
| FL-005/011 OCR | ML Kit, parser y preprocesamiento |
| FL-006 | Voice Note |
| FL-008–010 | fidelidad visual, módulos antes llamados Basic/Pro |
| FL-011 | ES/EN |
| FL-012/012.1 | Drift, medios, connectivity, filtro evento, PDF local |
| FL-013/013A | perfil/eventos/origen, imágenes, fecha/agrupación, ownership |
| FL-013B | Cognito real |

## Conclusión

El repositorio ya tiene base móvil local, API/sync, almacenamiento S3, edición y
exportación de Registros, Content/PDF y correo productivo validados. Permanecen
monetización, hardening, QA E2E y tiendas según FL-020–FL-024; FL-019.5 será
únicamente polish visual de Review cuando exista mockup aprobado.
