# STORE-02 — Cierre técnico y evidencia de eliminación de cuenta

- Fecha de cierre en AWS DEV: 2026-10-26
- Resultado: **PASS en DEV con una identidad sintética; NO APTO todavía para producción**
- Alcance canónico: `AUT-18`–`AUT-21`, `SYN-11`–`SYN-12`, `MON-13`,
  `INF-15`–`INF-21`, `RNF-09`–`RNF-10`, `RC-06`–`RC-10` y E-14
- Decisión abierta: `D-13`
- ADR: ADR-001–ADR-007 vigentes; `ADR-AD-01`–`ADR-AD-06` continúan candidatas

Este documento consolida el estado final comprobado de STORE-02. Sustituye como
fuente de estado a los reportes de preparación que conservan el corte histórico
de cada incremento. La validación en DEV demuestra el flujo técnico, pero no
resuelve políticas legales ni autoriza producción.

## 1. Implementación entregada

- Flutter ofrece preflight, advertencia irreversible, reautenticación
  interactiva, confirmación, cierre de sesión y conservación segura del receipt.
- El backend acepta una solicitud autenticada e idempotente, resuelve el correo
  verificado en Cognito sin confiar en datos enviados por el cliente y exige que
  el `sub` coincida con la identidad validada por API Gateway.
- Ledger, receipt opaco, tombstone, barrera PostgreSQL y Registration Guards
  impiden nuevas escrituras, reprovisionamiento y acceso con sesiones antiguas.
- Outbox durable, SQS/DLQ, worker con checkpoints, finalizer, recuperador y
  reconciliador permiten reintentos idempotentes y recuperación tras fallos.
- El worker congela el alcance owner-scoped, inventaría objetos S3 antes de
  borrar y elimina/verifica OAuth, S3, PostgreSQL y Cognito en ese orden seguro.
- La migración `010_account_deletion_write_fence.sql` está aplicada en DEV con
  18 triggers y cero barreras inconsistentes al cierre de la prueba.
- La allowlist destructiva de DEV fue independiente de Web Sessions y limitada
  a la identidad sintética usada en QA. Intake y procesamiento se habilitaron
  escalonadamente; no constituyen configuración de producción.
- SES permanece desacoplado: receipt/status son autoritativos aunque las
  notificaciones estén deshabilitadas. Stripe no simula cancelaciones.

## 2. Incidentes encontrados y correcciones verificadas

1. **Confirmación HTTP 401.** El access token válido no incluía `email` ni
   `email_verified`. Se mantuvo como bearer y se añadió resolución interna en
   Cognito, comparación exacta de `sub` y exigencia de correo verificado. El
   cliente nunca puede aportar el correo como prueba de identidad.
2. **Bloqueo PostgreSQL por clave foránea.** `email_connections` se intentaba
   borrar antes que `email_send_intents`. El orden owner-scoped ahora elimina
   primero dependientes, dentro de la transacción e idempotentemente.
3. **Recuperación de outbox sin permisos.** El recuperador carecía de
   `dynamodb:UpdateItem` y `dynamodb:DeleteItem`. IAM se acotó a esas acciones
   sobre la tabla del ledger. No se amplió a otras tablas.
4. **Workflow bloqueado y entregas duplicadas.** El receipt, tombstone, outbox y
   mensajes se conservaron durante la contención. Tras desplegar las
   correcciones, el mismo workflow reanudó desde `blocked`; las entregas
   repetidas no repitieron borrados ni alteraron el estado `completed`.

## 3. Evidencia funcional real en AWS DEV

La prueba destructiva utilizó exclusivamente una cuenta Cognito nativa y
sintética con workspace personal de un miembro, trial, sin referencias Stripe,
dos Leads sincronizados y siete objetos S3 inventariados.

- La solicitud fue aceptada con receipt único; la app cerró sesión y el acceso
  posterior quedó bloqueado.
- El workflow terminó `completed` con checkpoints de revocación OAuth,
  inventario/borrado S3, inventario/borrado PostgreSQL y eliminación de identidad.
- PostgreSQL no conservó datos owner-scoped de la identidad de prueba.
- Los siete objetos inventariados fueron verificados como ausentes en S3.
- Cognito confirmó ausencia de la identidad al terminar el finalizer.
- Receipt y tombstone durables permanecieron disponibles para estado y
  protección anti-resurrección.
- El outbox final quedó reconciliado; SQS y DLQ quedaron vacías. El Event Source
  Mapping y el scheduler de recuperación volvieron a su estado operativo.
- No reaparecieron errores de FK ni `AccessDeniedException`; las entregas
  duplicadas fueron idempotentes.
- Las identidades QA A/B, Web Sessions, Billing y Unlimited QA permanecieron
  intactos durante las verificaciones no destructivas.

## 4. Evidencia automatizada

Las suites cubren, con identidades sintéticas: confirmación concurrente,
idempotencia, outbox y fallo de SQS; inventario S3 paginado y más de 1.000
objetos; aislamiento entre propietarios; fallos parciales y retries; write
fence, segundo dispositivo y restore; verificación Cognito de correo; contexto
de triggers; allowlist destructiva; eliminación relacional; IAM y CDK; y purga
local Flutter. Los resultados exactos de la ejecución de cierre se registran en
la sección 7 para no presentar como aprobada una prueba no ejecutada.

## 5. Pendientes antes de producción

- `D-13` sigue abierta: Legal/Privacidad debe aprobar categorías, base y plazos
  de retención, datos de terceros, menores/mercados, backup y legal hold.
- Seguridad debe aprobar canonicalización, KMS HMAC/rotación, política de
  reautenticación, acceso operativo y respuesta a incidentes.
- Infra/Operaciones debe formalizar backup/restore con reaplicación del ledger,
  monitoreo, alarmas con destinatarios, runbooks, ownership y SLA.
- Payments debe cerrar el tratamiento de suscripciones Stripe activas; ninguna
  confirmación puede afirmar una cancelación no realizada.
- Falta validar el recurso público de `foloo.io`, notificaciones reales SES,
  política/entregabilidad, QA iOS y matriz completa de publicación.
- Deben sustituirse allowlists/flags de QA por una política de producción
  aprobada y ejecutar una revisión separada antes de habilitar tráfico real.

## 6. Limpieza y conservación de evidencia

Se retiró del repositorio el diagnóstico owner-scoped temporal usado antes de
la prueba destructiva: cuatro módulos backend, su adaptador DynamoDB, pruebas y
wiring CDK. Sus recursos AWS ya habían sido eliminados mediante un Change Set
auditado. No tenía endpoint, trigger ni consumidor vigente. Se conserva aquí la
evidencia agregada necesaria: workspace exclusivo, un miembro, trial sin Stripe,
dos Leads, seis medios, siete objetos S3 y cero anomalías de ownership.

Se conservaron migraciones SQL, ledger/guards, fixtures defensivas, contratos,
ADR, documentación SDD histórica, configuración de Billing, Cognito, KMS,
Unlimited QA, Web Sessions y pruebas de regresión. No se realizó refactorización
arquitectónica ni limpieza basada solo en tamaño.

## 7. Validaciones de cierre

Resultados observados en la revisión de cierre:

- Backend: typecheck, build, ESLint y Prettier aprobados; suite completa con
  281 tests aprobados, una integración PostgreSQL omitida por no existir una
  base local descartable y un smoke HTTP inicialmente bloqueado por el sandbox.
  Ese smoke se repitió fuera del sandbox y Billing aprobó 35/35.
- Suite focalizada Account Deletion: 83/83 aprobados.
- Flutter: formato sin cambios, `flutter analyze` sin hallazgos y 303/303 tests
  aprobados.
- Dependencias: `npm ls --all --omit=optional` y `flutter pub deps` resolvieron
  correctamente; las dependencias opcionales de plataformas no anfitrionas son
  ausencias esperadas de npm.
- CDK synth completado con contextos efectivos de DEV. `cdk diff
--no-change-set` contra `FolooBackend-dev` reportó cero diferencias.
- Referencias documentales verificadas y `git diff --check` aprobado.
