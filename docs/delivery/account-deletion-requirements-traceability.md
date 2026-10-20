# STORE-02E-01 — Requisitos y trazabilidad de Account Deletion

- Estado: **FORMALIZACIÓN DOCUMENTAL COMPLETADA; sin implementación**
- Fecha: 2026-10-20
- Escenario canónico: `E-14`
- Decisión abierta: `D-13`
- Contrato: [`account-deletion-contract.md`](account-deletion-contract.md)
- Diseño: [`account-deletion-technical-design.md`](account-deletion-technical-design.md)
- API propuesta: [`account-deletion-openapi.yaml`](account-deletion-openapi.yaml)
- Decisiones arquitectónicas candidatas:
  [`../decisions/ADR-AD-account-deletion-candidates.md`](../decisions/ADR-AD-account-deletion-candidates.md)

Este documento cierra únicamente STORE-02E-01 como trabajo SDD. Los requisitos
canónicos viven en `product-spec.md` y su aceptación en E-14. No autoriza DDL,
endpoints, recursos AWS, pantallas, borrados, pruebas destructivas ni cierre de
`D-13`. Los identificadores `AD-*` de STORE-02D se conservan como antecedentes,
no como un segundo namespace de producto.

## 1. Estado de aprobación

| Marca | Significado |
|---|---|
| Formalizado | Requisito incorporado al SDD; todavía puede tener parámetros bloqueados explícitos |
| Aprobación externa | Legal, Seguridad, Infra, Operación, TI o Payments debe validar antes de implementar la rama indicada |
| Candidato | Alternativa técnica o valor propuesto; no es decisión aceptada |
| Implementado | No aplica a STORE-02E-01; no existe funcionalidad de Account Deletion en HEAD |

Los acuerdos de Producto/CBQA comunicados el 2026-10-20 permiten formalizar el
comportamiento base. No convierten automáticamente backups de 15 días,
reautenticación de cinco minutos, HMAC/DynamoDB, retenciones legales, proveedor
de pagos, ruta pública o alcance regional en decisiones aprobadas.

## 2. Requisitos, criterios y pruebas

| ID | Precondición | Resultado verificable | Error / borde verificable | Pruebas | Dependencia o aprobación |
|---|---|---|---|---|---|
| `AUT-18` | Cuenta sintética; sesión Cognito válida; superficie Android, iOS o web | Las tres entradas abren el mismo preflight/backend y el owner deriva del JWT | Offline o soporte/email conocido no crea solicitud | `AD-T-01`, `AD-T-02`, `AD-T-20` | TI/Legal valida ruta de `DEC-AD-12`; `ADR-002` |
| `AUT-19` | Sesión válida pero señal de interacción reciente variable | Backend acepta solo evidencia Cognito reciente y nunca credenciales del cliente | Ausente/caducada/no verificable responde `reauthentication_required` sin barrier | `AD-T-03`, `AD-T-04` | Seguridad aprueba mecanismo y ventana; cinco minutos sigue propuesta `DEC-AD-09` |
| `AUT-20` | Preflight vigente, reauth válida y confirmación explícita | Confirmación persiste request+barrier atómicamente y es irreversible/idempotente | Doble tap/concurrencia devuelve la misma solicitud; fallo transaccional no bloquea parcialmente | `AD-T-05`, `AD-T-06` | Producto/Legal valida copy; `DEC-AD-05`/`06` |
| `AUT-21` | Eliminación aceptada; identidad equivalente antes/después de 30 días | Antes rechaza sin filtrar historial; después crea identidad/cuenta/workspace vacíos y nuevos | Nuevo `sub` federado no evade ventana; ninguna herencia de datos/PRO | `AD-T-17`, `AD-T-18`, `AD-T-19` | Seguridad/Legal/Producto; trial nuevo pendiente; `DEC-AD-03`/`05`, `ADR-AD-02/03` |
| `SYN-11` | Outbox 0 o >0; online/offline; export disponible/no disponible | Preflight ofrece sync y export voluntaria; continuar con pendientes exige consentimiento | Offline no acepta; fallo/cancelación de sync/export no elimina ni bloquea | `AD-T-02`, `AD-T-07`, `AD-T-08` | Copy Producto/Legal; `DEC-AD-06`/`11`, `ADR-001/004` |
| `SYN-12` | Barrier aceptada; uno o varios dispositivos; almacenamiento multi-owner | Sync/timers se detienen y cada dispositivo purga solo owner mediante manifest reintentable | Filesystem parcial, otro owner y legacy owner-null permanecen seguros | `AD-T-09`, `AD-T-10`, `AD-T-11` | Seguridad revisa cifrado/paths; `DEC-AD-08`, `ADR-001/004` |
| `MON-13` | Entitlement `active` y proveedor de pagos aprobado | Renovación se cancela/verifica antes de comunicar éxito; resultado queda resoluble | `pending`/fallo no se presenta como cancelado ni como reembolso | `AD-T-21`, `AD-T-22` | FL-021, `D-01`–`D-04`, `DEC-AD-10`; rama no implementable hoy |
| `INF-15` | Request aceptada | Estados avanzan durablemente y al día 15 existe `completed` o `blocked` escalado | Job detenido/retry agotado conserva barrier y no falsea éxito | `AD-T-12`, `AD-T-23` | Operación/Legal valida SLA regional y owner; `DEC-AD-04`/`07` |
| `INF-16` | Inventario congelado y políticas aprobadas | OAuth→S3→PostgreSQL→Cognito se ejecuta/verifica en orden; Cognito termina último | Fallo parcial conserva referencias mínimas y reanuda la etapa correcta | `AD-T-12`, `AD-T-13`, `AD-T-14` | Legal define retención; IAM/Infra; `ADR-002/003/005/007` |
| `INF-17` | Conexión Google/Microsoft existente, expirada o ausente | Tokens/ciphertext/state/PKCE quedan revocados o inutilizables y luego eliminados | Provider caído produce retry/`blocked`, nunca reutilización ni éxito falso | `AD-T-15`, `AD-T-16` | Owner operativo y límites; `DEC-AD-07`, `ADR-006/007` |
| `INF-18` | Barrier vigente, token viejo, callback/replay o request ordinaria | Toda ruta rechaza antes de provisión/mutación con `account_deletion_pending` | Caída del ledger se comporta según política fail-closed aprobada; no ejecuta `ensure_personal_workspace` | `AD-T-24`, `AD-T-25`, `AD-T-26` | `ADR-AD-01/03/04`; Seguridad/Infra debe aprobar disponibilidad |
| `INF-19` | Cognito vigente o ya eliminado | Estado autenticado funciona antes del finalizer; receipt hash permite estado mínimo después | Receipt inválido/expirado/rate-limited no filtra existencia ni PII | `AD-T-27`, `AD-T-28`, `AD-T-29` | Seguridad/Legal aprueba expiración/canal/notificación |
| `INF-20` | Registro nuevo con email verificado y/o federado | Ledger seudonimizado aplica 30 días, rotación y expiración sin email claro | Alias/case/Unicode/keyVersion no evade; expiración TTL tardía no prolonga por sí sola | `AD-T-17`, `AD-T-18`, `AD-T-30` | `ADR-AD-01/02/03`; canonicalización y plazo del registro por Legal/Seguridad |
| `INF-21` | Restore autorizado de snapshot anterior a la eliminación | Ledger vigente se reconcilia y la cuenta no reaparece antes de abrir tráfico | Ledger inaccesible o reconciliación incompleta impide reapertura | `AD-T-31`, `AD-T-32` | `ADR-AD-01/05`; backup 15 días es propuesta `DEC-AD-02`, no política |
| `RNF-09` | Logs, tablas, métricas, receipts y alertas del pipeline | Inspección no encuentra PII/secretos/IDs internos claros; accesos/keys son auditables | Error provider o soporte no añade email, `sub`, tokens, paths u object keys | `AD-T-33`, `AD-T-34` | Threat model y key management por Seguridad; `DEC-AD-03` |
| `RNF-10` | Concurrencia, retries, fallo inyectado y dos dispositivos | Cada etapa produce una sola consecuencia y puede reanudarse | Retry agotado queda `blocked`; jamás `completed` por timeout o excepción | `AD-T-05`, `AD-T-12`, `AD-T-25`, `AD-T-35` | Retry budgets/alertas/runbook por Operación |
| `RC-06` | Matriz Legal aprobada por categoría/región | Datos personales/operativos se borran; solo excepciones justificadas se aíslan y expiran | Categoría sin base/plazo bloquea implementación, no se retiene por defecto | `AD-T-36`, `AD-T-37` | Legal/Contabilidad; `DEC-AD-01`/`03`/`13`/`14` |
| `RC-07` | Política backup/legal hold aprobada | Inventario distingue copia ordinaria/hold y restore nunca resucita cuenta | Backup vencido o hold sin autorización produce hallazgo/incidente | `AD-T-31`, `AD-T-38` | Infra/Legal; 15 días pendiente `DEC-AD-02` |
| `RC-08` | App ES/EN y web pública publicada por TI | Misma información, autenticación, confirmación y tracking en las tres superficies | URL/copy no aprobado no se publica; web no crea pipeline alterno | `AD-T-01`, `AD-T-20`, `AD-T-39` | TI/Legal/Producto; `DEC-AD-12`/`14` |
| `RC-09` | Existen correo entregado, export o retención aprobada | Aviso delimita copias externas y obligaciones sin prometer borrado imposible | No se marca copia externa como eliminada sin evidencia/control | `AD-T-40`, `AD-T-41` | Legal define roles/mercados; `DEC-AD-13`/`14` |
| `RC-10` | Cuenta PRO y política/proveedor real | Cancelación, notificación y evidencia retenida siguen política aprobada | Fallo comercial queda resoluble y no impide reconocer solicitud de derechos | `AD-T-21`, `AD-T-22`, `AD-T-42` | FL-021, Payments/Legal, `D-01`–`D-04`, `DEC-AD-10` |

## 3. Catálogo de casos de prueba

| Casos | Cobertura |
|---|---|
| `AD-T-01`–`04` | Entrada Android/iOS/web, offline, JWT y reautenticación reciente/expirada |
| `AD-T-05`–`08` | Confirmación concurrente/idempotente, outbox, sync y exportación voluntaria |
| `AD-T-09`–`11` | Purga local, manifest, multi-owner y legacy owner-null |
| `AD-T-12`–`16` | Orquestación, orden, S3 parcial, Cognito finalizer y OAuth revoke |
| `AD-T-17`–`19` | Alta antes/después de 30 días, email/password y Google, cuenta realmente nueva |
| `AD-T-20` | E2E web PKCE/CSRF sobre el mismo backend, sin Client Secret |
| `AD-T-21`–`23` | PRO, cancelación verificada, fallos y máximo operativo de 15 días |
| `AD-T-24`–`26` | Barrier antes de principal, token antiguo, callback/replay y dos dispositivos |
| `AD-T-27`–`30` | Receipt, rate limit, privacidad, HMAC/canonicalización/rotación/expiración |
| `AD-T-31`–`32` | Restore anterior y ledger inaccesible; tráfico permanece cerrado |
| `AD-T-33`–`35` | Redacción, IAM/auditoría, retry budgets y ausencia de falso `completed` |
| `AD-T-36`–`38` | Matriz de retención, legal hold y expiración de backup aprobada |
| `AD-T-39`–`42` | Copy ES/EN/accesibilidad, copias externas, terceros y evidencia comercial |

Las pruebas destructivas solo pueden ejecutarse en DEV, con cuentas y datos
sintéticos, aprobación por ejecución y backup/restore runbook validado. Esta
formalización no afirma que exista ninguna de ellas en código.

## 4. DEC-AD → requisitos y gate

| Decisión | Requisitos | Estado que conserva STORE-02E-01 |
|---|---|---|
| `DEC-AD-01` | `INF-16`, `RC-06` | Acuerdo de borrado por defecto; categorías Legal pendientes |
| `DEC-AD-02` | `INF-21`, `RC-07` | 15 días para backups sigue propuesta Infra/Legal |
| `DEC-AD-03` | `INF-20`, `RNF-09`, `RC-06` | Registro mínimo acordado; campos/HMAC/plazo/acceso pendientes |
| `DEC-AD-04` | `INF-15` | Máximo operativo formalizado; validación como SLA regional pendiente |
| `DEC-AD-05` | `AUT-20`, `AUT-21`, `INF-20` | Irreversibilidad y 30 días formalizados; mecanismo pendiente |
| `DEC-AD-06` | `AUT-20`, `SYN-11` | Comportamiento formalizado; copy final pendiente |
| `DEC-AD-07` | `INF-15`, `INF-17`, `RNF-10` | Owner/budgets/alertas/runbook pendientes |
| `DEC-AD-08` | `SYN-12`, `RNF-09` | Purga owner-scoped formalizada; revisión de cifrado pendiente |
| `DEC-AD-09` | `AUT-19` | Reauth backend formalizada; cinco minutos/mecanismo pendientes |
| `DEC-AD-10` | `MON-13`, `RC-10` | Contrato condicional formalizado; FL-021/Payments bloquea implementación |
| `DEC-AD-11` | `SYN-11` | Export voluntario formalizado; portabilidad/copy pendientes |
| `DEC-AD-12` | `AUT-18`, `RC-08` | Mismo pipeline formalizado; URL/hosting/publicación pendientes |
| `DEC-AD-13` | `RC-06`, `RC-09` | Sigue sin responsable/definición Legal |
| `DEC-AD-14` | `RC-06`–`RC-10` | Producto multirregión; mercados/idiomas/menores pendientes |

## 5. Subtareas, requisitos y estado

| Subtarea | Requisitos principales | Entrada mínima | Estado después de STORE-02E-01 |
|---|---|---|---|
| `02E-01` Requisitos/trazas | Todos los de este documento | Acuerdos documentados y namespaces canónicos | **Completada documentalmente**; no implementada |
| `02E-02` DDL/barrera | `AUT-21`, `INF-18`, `INF-20`, `INF-21`, `RNF-09/10` | Aprobar `ADR-AD-01`–`05`, Legal/Seguridad/Infra y threat model | Revisión final documentada en `account-deletion-architecture-security-review.md`; **bloqueada para código** hasta incorporar/aprobar cambios |
| `02E-03` API/request | `AUT-18`–`20`, `SYN-11`, `INF-15`, `INF-19` | Aprobar `ADR-AD-06`, copy, receipt y semántica idempotente | Contrato/tests pueden revisarse; código bloqueado |
| `02E-04` Workers | `MON-13`, `INF-15`–`17`, `RC-06/07/09/10` | Retención, IAM, owner operativo, runbooks; Payments para rama PRO | Bloqueada para recursos/código destructivo |
| `02E-05` Flutter | `AUT-18`–`20`, `SYN-11/12`, `RC-08/09` | API/reauth/copy aprobados y barrier real | Prototipo documental permitido; código bloqueado |
| `02E-06` Web | `AUT-18/19`, `RC-08` | TI/Legal, dominio, App Client web PKCE y API aprobada | Arquitectura solamente; publicación bloqueada |
| `02E-07` QA/security | `RNF-09/10`, E-14 completo | Componentes 02–06 y autorización destructiva por ejecución | Diseño/no destructivas permitido; E2E bloqueado |
| `02E-08` Compliance | `RC-06`–`RC-10`, `REL-01`, `REL-06/07` | Evidencia técnica + Legal y stores | Bloqueada; es la única fase que puede cerrar `D-13` |

## 6. Dependencias históricas sin cambio de alcance

- FL-020 aporta entitlement/trial, pero Account Deletion no cambia el límite de
  cinco leads ni Unlimited QA.
- FL-021 debe entregar proveedor y lifecycle de suscripción antes de implementar
  `MON-13`/`RC-10`; Account Deletion no activa compras ni concede PRO.
- ADR-001/004 gobiernan purga local/outbox; ADR-002 identidad; ADR-003
  PostgreSQL; ADR-005 S3; ADR-006/007 OAuth/correo. Ninguna autoriza por sí sola
  recursos destructivos.
- `D-13` permanece abierta hasta STORE-02E-08 y aprobación explícita de todos
  los parámetros que este documento identifica como pendientes.
