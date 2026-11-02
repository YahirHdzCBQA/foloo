# STORE-02D — Entrega E: validación local y plan de QA DEV

Fecha: 2026-11-02. Trazas: AUT-18–AUT-21, SYN-11/12, MON-13,
INF-15–INF-21, RNF-09/10, RC-06–RC-10 y escenario E-14.
No autoriza publicación, despliegues, activación ni eliminación.

## Base verificada

Working trees inicialmente limpios. Foloo en
`feature/STORE-02D/account-deletion-release`: A `0f7772a`, B `2d389e0`,
C `06a9716`. Landing en `feature/STORE-02D/web-account-deletion`: D
`8c8dde8`, confirmada antes de E. Se revisaron requisitos y escenario E-14,
D-03/04/13, arquitectura, traceability, roadmap, contrato de eliminación y
runbook operacional. Las políticas expresas STORE-02D gobiernan eliminación
PRO; no se amplían los planes comerciales ni se resuelven decisiones legales.

La evidencia histórica de STORE-02/WEB-02 en DEV no demuestra que los nuevos
incrementos A–D estén desplegados ni probados end-to-end. Esta entrega no
consultó ni modificó AWS o Stripe.

## Resultado reproducible

- Backend: 347 casos descubiertos; primera ejecución 345 PASS, 1 FAIL de entorno
  (`listen EPERM` al abrir loopback), 1 omitido. La repetición completa de
  `billing.test.ts` con loopback permitido aprobó 38/38, incluido el caso
  bloqueado. Resultado combinado: 346 casos distintos aprobados, 1 NOT RUN.
  El omitido requiere `BILLING_TEST_DATABASE_URL` contra una base desechable:
  escribe fixtures y no debe apuntar a DEV compartido ni producción.
- Typecheck backend y build TypeScript: PASS; salida de build aislada en /tmp.
- ESLint fuente `src test infra scripts`: PASS. Lint global inicialmente
  inspeccionaba bundles privados `.env.*`; se excluyeron esos directorios
  generados igual que `dist`/`cdk.out`. Lint global repetido: PASS. No se excluye
  código mantenido ni se cambia lógica funcional.
- Flutter: 78/78 pruebas focalizadas PASS (deletion, sync, content sync,
  auth repository y Cognito service/flow). `flutter analyze --no-pub`: PASS.
  Son pruebas Dart/widget en host, no ejecución física Android/iOS.
- Web: 55/55 unitarias/contratos PASS; validación estática PASS; build DEV
  reproducible, 89 archivos idénticos entre dos ejecuciones, sin diff en dist.
- Chrome simulado: `web02-check`, `store02d-check`, `native-auth-check`: PASS.
  Rutas e identidad simuladas; no credenciales reales ni llamadas a AWS.
- Typecheck de presentation/deletion UI web: PASS. El grafo JS global conserva
  la deuda de tipado documentada en D; no se afirma typecheck global web.

Comandos (usar Node 22 en PATH):

```sh
# foloo/backend
npm test
node --import tsx --test test/billing.test.ts
node node_modules/typescript/bin/tsc --noEmit
node node_modules/typescript/bin/tsc --outDir /tmp/store02d-e-backend-build
npm run lint
# foloo/app
flutter test --no-pub test/account_deletion_test.dart test/sync_engine_test.dart test/content_sync_test.dart test/auth_repository_test.dart test/cognito_auth_service_test.dart test/cognito_auth_flow_test.dart
flutter analyze --no-pub
# foloo-landing
node --test scripts/tests/*.test.mjs
python3 scripts/build.py --environment dev
python3 scripts/validate.py
./infra/node_modules/.bin/tsc --allowJs --checkJs --noEmit --target es2022 --module nodenext --lib es2022,dom src/web/deletion-copy.mjs src/web/deletion-ui.mjs
# Playwright ya instalado, resuelto mediante NODE_PATH; Chrome local:
node scripts/web02-check.cjs
node scripts/store02d-check.cjs
node scripts/native-auth-check.cjs
```

## Matriz de cobertura

| Área | Resultado | Tipo y evidencia / límite |
| --- | --- | --- |
| Free/trial y PRO inactiva | PASS | Unitarias: stripe_subscription_cancellation; contrato web no pide cancelación |
| PRO activa | PASS | Billing provider, staged executor y UI web: acknowledgement, binding propietario, cancelación antes de borrado |
| Stripe timeout, fallo, recuperación | PASS | Simulado: clave estable, bloqueo sin éxito falso, reintento de etapa |
| Webhooks duplicados/fuera de orden | PASS | billing.test: entrega concurrente, deleted seguido de active atrasado, rollback/retry |
| Reautenticación 5 minutos | PASS | API declara 300 segundos; workflow/BFF validan auth_time; refresh no renueva evidencia; UI vuelve a pedir consentimiento |
| Preflight, confirmación concurrente e idempotencia | PASS | workflow, DynamoDB simulado, BFF y navegador; una aceptación/receipt |
| Receipt/status sin sesión, logout fallido y respuesta tardía | PASS | Flutter service y Chrome; receipt en memoria, POST, sin URL/storage; polling no oculta aceptación |
| requested/blocked/completed | PASS | Contratos, UI y executor; no equiparar aceptación a terminación |
| 423 y segundo dispositivo | PASS | Sync/widget simulados, detención concurrente y purga owner-scoped con manifiesto |
| Android/iOS y dispositivo secundario físicos | NOT RUN | Requiere dispositivos y entorno QA autorizado |
| SES fallo, duplicados y concurrencia | PASS | Claims y retry con mocks, no prueba entrega real ni ausencia absoluta de duplicados ante fallo incierto del proveedor |
| Deadline 15 días, días 10/13/15 y reconciliador | PASS | Reloj simulado, lease y métricas; alarmas en pruebas de plantilla CDK |
| Restore/tombstones | PASS | Adaptadores simulados y contratos de fences; no prueba restore de backup real |
| Ownership/OAuth desconectado | PASS | erasure inventory, guard, BFF y oauth_disconnected_erasure: cleanup local sin revocación externa |
| Seguridad receipt/CSRF/identidad/flags | PASS | Tests de contratos/BFF/Chrome, sin secretos en URLs o almacenamiento web |
| Auth, sync, Billing, WEB-01/02 | PASS | Suites anteriores y regresiones focalizadas |
| PR #5 específica | BLOCKED | No se identificó commit/alcance en historial y documentación locales; se necesita enlace o SHA, no se asume cubierta |
| PostgreSQL Billing real | NOT RUN | Suite omitida sin BILLING_TEST_DATABASE_URL desechable |
| Stripe test mode, SES y pipeline AWS reales | NOT RUN | No se autorizó ejecución remota ni destrucción |
| Conservación contable/legal integral | BLOCKED | D-13: falta aprobar categorías, base, acceso, región y plazo; no se inventa política fiscal |

## Contratos y límites comprobados

Web y Flutter reutilizan verify/preflight/confirm/status del backend. El BFF
limita rutas privadas y aplica sesión, Origin/CSRF e identidad. Flutter recibe
JWT del mismo owner. La respuesta usa el envelope `data`; el receipt se
consulta por POST sin sesión. Los errores y estados conocidos son compatibles.
No se encontró una incompatibilidad funcional demostrada en estos recorridos.

El backend confirma cancelación de futuras renovaciones Stripe antes de las
etapas destructivas; la aceptación ya impone barrera sin gracia de acceso. No
emite reembolsos. Un fallo de Stripe no revierte receipt ni barrera. Se mantiene
el tratamiento local de conexiones OAuth desconectadas.

`pendingSyncCount` servidor es cero para outbox móvil aún local: Flutter aporta
su conteo; la web no detecta datos offline de otro dispositivo. Exportación web
ofrece instrucciones para la función móvil existente, no una descarga web.
El receipt web solo vive en memoria y debe conservarse privadamente antes de
cerrar; pérdida de respuesta con sesión revocada requiere seguimiento seguro,
no otra confirmación. El status público no identifica la etapa Stripe.

`billing_events` conserva solo deduplicación operativa (event_id/type/fecha),
con UPDATE/DELETE revocados al rol de app. El borrado elimina cuenta y bindings
locales, no elimina facturas/pagos de Stripe. Esto no demuestra un archivo
contable legal completo ni plazos de conservación aprobados. D-13 permanece
abierta; implementar nuevas retenciones sin decisión legal sería incorrecto.

Backups ordinarios: CDK declara 15 días RDS; runbook exige reaplicar ledger y
barreras antes de tráfico. No equivale a validación de restauración productiva.
SLA y textos: máximo 15 días naturales desde aceptación, no garantía de borrado
inmediato. TI de CBQA es el equipo responsable, sin inventar personas/destinos.
Recuperación y asistencia no autorizan borrar por conocer un correo.

## QA controlado DEV — ejecutar solo tras autorización

1. Identificar PR #5 y fijar commits A–E. Aprobar alcance, región/cuenta DEV,
   flags privados y diferencias reales de infraestructura. Respaldar paquetes,
   configuración y plantillas en almacenamiento privado persistente. No usar
   un synth completo si contiene cambios incidentales. Revisar permisos nuevos
   de Billing/SES/SNS/reconciliación y migraciones realmente pendientes.
2. Solicitar autorización separada de despliegue/migración si procede; auditar
   un Change Set sin ejecutar primero. Mantener normal access y flags públicos
   apagados; no confundir allowlist web con autorización destructiva.
3. Registrar/verificar manualmente cuentas desechables Free/trial y PRO con
   correo controlado. No cuentas habituales. Consultar identidad sin exponerla.
   Autorizar las allowlists separadamente, preservando las tres QA originales.
   Si el modo destructivo admite una identidad, ejecutar las cohortes de forma
   secuencial, con cambio auditado de autorización, nunca hashes ficticios.
4. Con aprobación de Stripe test mode, crear cliente/suscripción sintéticos;
   probar PRO activa e inactiva. Confirmar entorno de prueba y ausencia de
   cobros/cuentas reales. No cancelar Stripe todavía durante preflight.
5. Preparar datos mínimos autorizados (evento/lead/medios), inventariar conteos
   y asociaciones PostgreSQL/S3/Cognito, Billing y OAuth. Remitente dedicado
   desechable: nunca reutilizar una cuenta personal/compartida. No registrar
   tokens, cookies, recibos ni identificadores en reportes públicos.
6. Ejecutar login, reload, ownership, reauth misma/distinta identidad, CSRF,
   verify/current en web y móvil. Abrir dos dispositivos físicos Android/iOS
   con la misma cuenta y conservar otro owner para comprobar aislamiento.
   UI QA aislada sobre origen real; backend es la barrera, no Overrides.
7. Obtener autorización explícita para preflight persistente. Revisar alcance,
   vigencia, outbox y acknowledgements. Obtener autorización independiente de
   confirmación irreversible y cancelación Stripe de prueba. Una confirmación;
   timeout obliga consultar estado antes de repetir con la misma clave.
8. Observar requested/blocked/completed, receipt sin sesión, ledger/outbox y
   checkpoints, SQS/DLQ, protección 423/purga del segundo dispositivo. Los
   escenarios de fallo Stripe/SES y replay de webhooks necesitan autorización
   específica de inyección/reenvío en DEV; no tocar configuraciones compartidas
   para simularlos sin un plan aprobado. Verificar que no hay doble cancelación.
9. Confirmar completed únicamente tras Cognito ausente, conteos PostgreSQL cero,
   objetos S3 ausentes, OAuth tratado según estado, Stripe sin renovación y
   receipt/status coherentes. Verificar envío real SES y destino de alarmas sin
   copiar PII. Conservar únicamente evidencia mínima protegida de auditoría.
10. Probar backup/restore en entorno aislado con autorización separada: ledger
    vigente primero, reaplicar tombstones/fences antes de abrir tráfico. No
    acortar relojes ni manipular registros del flujo real para probar SLA.
11. Limpiar accesos/fixtures/Overrides con autorización; retirar identidad QA
    temporal, conservar originales, ledger y checkpoints. Rollback de código
    compatible no revierte una eliminación ni debe borrar barreras. Concluir
    regresión WEB-01, Billing y sync; registrar resultados por cohorte/dispositivo.

## Dictamen

Código local: APTO PARA COMMIT de esta entrega (ajuste de lint y documentación),
sin cambios funcionales ni flags. Integración local: validada en las suites
indicadas, con PostgreSQL real y PR #5 pendientes explícitos. QA DEV integral:
PENDIENTE, no se reutiliza el PASS histórico para cerrar A–E. Producción:
PENDIENTE, no habilitable con esta evidencia.

Gates independientes: AWS PROD separado; D-13 y validación legal/fiscal México;
backups/restore reales; personas/canales de TI; QA físico Android/iOS; Stripe
E2E de prueba; activación gradual autorizada. El arreglo local de receipt/logout
está probado con mocks y requiere nueva validación real. No se inició ningún
despliegue, migración, envío, cancelación ni eliminación durante E.
