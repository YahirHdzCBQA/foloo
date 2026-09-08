# Auditoría de los 65 pendientes contra el repositorio

- Corte: commit `f5f207c`, 2026-09-08.
- Fuente: hoja `Pendientes` del XLSX entregado; el archivo original no se editó.
- Estados: **I** implementado localmente con evidencia; **P** parcial/demo o
  falta aceptación remota; **F** sin implementación suficiente.
- Totales aproximados: **14 I · 22 P · 29 F = 65**.

Ningún **I** sustituye QA de dispositivo, backend, seguridad o aceptación de
Producto. El código de edition gating existente es obsoleto aunque la función
interna sea reutilizable.

## F1 · Producto, núcleo de captura (26)

| ID | Estado | Evidencia actual | Cobertura / siguiente FL |
|---|:---:|---|---|
| f1-01 | I | `auth/`, Login/SignUp/Confirm, Cognito runtime y auth tests | FL-013A/B; validación manual pendiente |
| f1-02 | P | `ProfileSetupScreen`, ProfileRepository | FL-013A; faltan puesto/teléfono y edición completa |
| f1-03 | I | origin screen, `LeadOriginKind`, lugar y persistence | FL-013 + tests de navegación |
| f1-04 | I | EventScreen, create/edit/delete, EventRepository | FL-013; CRUD Drift |
| f1-05 | I | `EventSelectionPolicy`, preferencia manual y refresh diario | FL-013A refinement |
| f1-06 | I | LeadCaptureScreen: scroll, progreso y dock | FL-002/008/010 |
| f1-07 | P | ML Kit, parser/preprocessor, reprocesar y tests | FL-005/011; falta campaña de precisión real |
| f1-08 | I | `LeadType` y tres choices | FL-008/010 |
| f1-09 | I | `InterestLevel`, selector y riel Records | FL-004/010 |
| f1-10 | I | VoiceNoteService/state/widget y reproducción | FL-006/010/012 |
| f1-11 | I | nota escrita en LeadDraft/Drift/UI | FL-002/012 |
| f1-12 | I | `_revealFirstInvalidField` y tests de captura | FL-013 |
| f1-13 | P | Drift y ConnectivityService; UI local disponible | FL-012/012.1; no hay sync/email offline real |
| f1-14 | P | LeadConfirmationScreen y retorno | FL-004/009; estados siguen demo |
| f1-15 | P | AppDrawer con destinos/evento | FL-003/009; falta saldo y retirar plan |
| f1-16 | P | RecordsScreen con evento/búsqueda/tipo/estado | FL-004/012.1; contrato visible no completo |
| f1-17 | I | orden local y `_EmptyRecords` | FL-004/012 |
| f1-18 | F | detalle actual es consulta, no edición persistente | FL-014 propuesta |
| f1-19 | I | visor modal de tarjeta desde detalle | FL-010/013 |
| f1-20 | P | varios estados usan icono/palabra | FL-010; falta auditoría global |
| f1-21 | P | PrivateMediaStorage persiste tarjeta/voz | FL-012; no existe subida BD/S3 |
| f1-22 | I | reproducción, pausa, borrado y regrabación antes/después cubiertos por widget tests | FL-006/010/013; política remota futura sigue en D-06 |
| f1-23 | F | no existe tope productivo | bloqueado D-05 |
| f1-24 | P | multi-photo, Drift media y visor | FL-013A refinement; aún condicionado por AppPlan |
| f1-25 | I | themes, toggle y preferencia por usuario | FL-009/011/012 |
| f1-26 | P | ARB ES/EN, selector y localization tests | FL-011; quedan demos/cadenas por auditar |

## F2 · Seguimiento y salida de datos (7)

| ID | Estado | Evidencia actual | Cobertura / siguiente FL |
|---|:---:|---|---|
| f2-01 | P | ContentScreen y ContentFile demo, filtro visual | FL-009/012.1; sin repositorio durable |
| f2-02 | P | PdfPickerService, empty state y assignment sheet | FL-012.1; no persiste/sube |
| f2-03 | P | UI edita eventos/elimina en memoria | FL-009; falta persistencia/S3 |
| f2-04 | P | EmailScreen con dos plantillas/variables demo | FL-009; falta persistencia/validación/backend |
| f2-05 | F | TODOs y estados demo; no cola/envío | FL posterior tras D-09 |
| f2-06 | F | diálogo ofrece XLS/XLSX, no genera archivo | FL posterior tras D-07 |
| f2-07 | F | diálogo ofrece CSV, no genera/compartir | FL posterior tras D-07 |

## F3 · Monetización (8)

| ID | Estado | Evidencia actual | Cobertura / siguiente FL |
|---|:---:|---|---|
| f3-01 | F | sin contador server-side | bloqueado D-01/D-12 |
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
| f4-03 | P | storage privado local para medios | FL-012; falta S3/retención |
| f4-04 | F | sin servicio de correo/dominio/rebotes | bloqueado D-09 |
| f4-05 | F | confirmación aún contiene demo “hoja” | retirar en FL-014; Sheets backlog |
| f4-06 | F | no hay modelo org/teams aprobado | bloqueado D-10 |
| f4-07 | P | config Cognito DEV/PROD centralizada | FL-013B; sin staging/secret ops |
| f4-08 | F | sin CI/CD/distribución documentada | FL plataforma |
| f4-09 | F | sin observabilidad/alerta sync | FL plataforma |
| f4-10 | F | sin backup/retención/borrado | bloqueado D-13 |
| f4-11 | F | sin modelo de costo por vendedor | FL infraestructura |
| f4-12 | F | sin Google Workspace/DKIM/reputación | bloqueado D-09 |

## F5 · Salida a producción (12)

| ID | Estado | Evidencia actual | Cobertura / siguiente FL |
|---|:---:|---|---|
| f5-01 | P | suite Flutter amplia por flujos locales | falta E2E iOS/Android/backend |
| f5-02 | P | `layout_test.dart` y reglas de tema | falta matriz real de dispositivos |
| f5-03 | F | no hay sync, por tanto no prueba de reconexión E2E | después de sync |
| f5-04 | P | unit tests parser/preprocessor/ML Kit boundary | falta evento/tarjetas reales |
| f5-05 | F | no hay pagos | después de monetización |
| f5-06 | F | sin beta de campo documentada | salida a producción |
| f5-07 | F | no hay evidencia repo de cuentas vigentes | operación externa |
| f5-08 | F | sin paquete completo de tienda ES/EN | salida a producción |
| f5-09 | P | permisos cámara/micrófono existen | faltan privacidad/términos/suscripción |
| f5-10 | F | sin envío/revisión de tiendas | salida a producción |
| f5-11 | F | sin tag/release notes/soporte V1 | salida a producción |
| f5-12 | F | sin generador XLSX/CSV | después de f2-06/f2-07 |

## Código obsoleto por la unificación

- `AppPlan.basic/pro`, selector demo y condicionales `isPro`.
- `pro_demo_data.dart` como autoridad de contenido/transcripción/estados.
- Tests que prueban ausencia/presencia por edición.
- Texto o UI de transcripción.
- Estados de “hoja de cálculo” en acuse.

Se conservan temporalmente porque FL-013C no modifica features. Deben retirarse
en la primera FL de realineación móvil sin perder la implementación reutilizable
de contenido, correo e imágenes.

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

El repositorio ya tiene una base móvil local considerable, pero no una V1
productiva. Los bloques mayores faltantes son: retirar gating, detalle editable,
sync/API/S3/cloud, correo, export real, monetización y salida de tiendas.
