# Plan de implementación propuesto — Foloo V1 unificado

Este documento ordena trabajo; no autoriza iniciar ninguna FL ni es una promesa
de fecha. Cada FL termina solo con requisitos/escenarios trazados y evidencia.

## FL-013A / FL-013B / FL-013C

- **FL-013A COMPLETADO:** AuthRepository/AuthService, ownership Drift y FakeAuth
  controlado.
- **FL-013B COMPLETADO en código; validación manual pendiente:** Cognito DEV,
  alta/confirmación/login/restore/logout y `sub`.
- **FL-013C COMPLETADO al aprobar este paquete:** realineación documental.
- **FL-013D COMPLETADO:** runtime unificado, sin selector/gating Basic/Pro;
  Contenido, Correo e imágenes disponibles para toda cuenta V1 y transcripción
  automática retirada de la UI.
- No continuar automáticamente.

## FL-014 — Backend Foundation & API

**Estado:** **COMPLETADO, desplegado y validado en AWS DEV.**

- Backend Node.js/TypeScript, API Gateway `/v1`, Lambda y contratos.
- Cognito `sub` verificado → cuenta/workspace → recursos.
- PostgreSQL en RDS privado, migraciones e IaC AWS CDK reproducible.
- UUID offline, revisión e idempotencia preparan sync sin activarla.
- Trazas: `INF-01`, `INF-03`, `INF-05`–`INF-14`, `SYN-06`, `AUT-10`, E-13.
- ADR-003 cierra D-12. No incluye S3, correo, monetización ni sync móvil.

## FL-015 — Sync offline

**Estado:** **COMPLETADO en repositorio; validación manual contra AWS DEV
pendiente.**

**Objetivo:** conectar Drift con la API existente mediante operaciones
idempotentes y reconciliación local-first.

- Outbox Drift por owner, retry/backoff y reconciliación completa segura según
  los contratos GET actuales; no se inventa cursor.
- Mapping Drift ↔ contratos `/v1`; pruebas offline/reconexión sin duplicados.
- No incluir binarios: S3 permanece FL-016.
- Trazas: `SYN-04`–`SYN-10`, `RNF-07`.
- ADR-004 define idempotencia, aislamiento y política conservadora de conflictos.

## FL-016 — Media & Content Storage / S3

**Estado:** **CLOSED, desplegado y validado físicamente.**

**Objetivo:** subir/reanudar Leads y binarios sin pérdidas/duplicados.

- Extiende la outbox FL-015 con autorización, PUT S3 directo, confirmación y
  lectura temporal para tarjeta, referencias y voz.
- Bucket privado cifrado, sin NAT; Lambda verifica por endpoint Gateway S3.
- PostgreSQL conserva metadata/estado mediante migration 002; no binarios.
- Trazas: `SYN-04`–`SYN-10`, `INF-02`, `RC-02`, `RC-03`.
- La política final de retención sigue pendiente en D-13; D-05 no impide el
  techo técnico antiabuso y el contrato PDF quedó definido en FL-018.

## FL-017 — Records + XLSX/CSV Export

**Estado:** **CLOSED, desplegado y validado físicamente.**

- Records local-first, detalle y edición estructurada con revisión optimista.
- Exportación local por evento a XLSX/CSV y hoja de compartir.
- Trazas: `REG-01`–`REG-18`, `SYN-*`, `REL-08`, E-06/E-09/E-10.
- Feedback Post-TestFlight: header global con Drawer, filtros explícitos, swipe
  Correo/Eliminar y tombstone de Lead offline-first.
- `D-07` resuelta el 2026-09-15; `D-06` sigue bloqueando edición de medios.

## FL-018 — Content/PDF

**Estado:** **CLOSED, desplegado y validado físicamente.**

**Objetivo:** sustituir contenido PDF demo por persistencia local/remota.

- Biblioteca PDF, asignación/evento y adjuntos congelados.
- Feedback Post-TestFlight: Content explícito para Lead directo, swipe
  Editar/Eliminar y edición conjunta de nombre visible/asignaciones con
  alternativa accesible en biblioteca.
- Trazas: `CON-01`–`CON-13`, E-07.
- D-08 resuelta el 2026-09-17: 25 MB/PDF, sin cuota comercial total ni desalojo automático; borrado lógico sin `DeleteObject`. D-11 no bloquea funcionalidad técnica, solo fidelidad visual final.

## FL-019 — Email/Templates

**Estado:** **CLOSED, desplegado y validado físicamente el 2026-09-22.**

- Entrega validada: Gmail OAuth/send, Microsoft OAuth/Graph, defaults Foloo y
  seller, overrides por Evento, Capture → Review → `foloo`, reconciliación
  semántica con ediciones manuales, múltiples PDF, D-19, preservación de Voice
  Note, preparación/intención únicas, estados reactivos, outbox offline,
  unsubscribe GET + POST explícito, terminal `recipient_opted_out`, ES/EN y
  correcciones de teclado/foco/selección.
- Trazas: `PLT-*`, `SAL-*`, `RC-01`, E-08; ADR-006/007.
- D-09 resuelta el 2026-09-18: cuenta autorizada del vendedor, Google OAuth +
  Gmail API y Microsoft OAuth + Graph; sin SES/SMTP para follow-ups.
- D-14–D-20 quedaron resueltas y validadas dentro del contrato de E-08.

## FL-019.5 — Demo Feedback UX & Email Flow Polish

**Estado:** **IMPLEMENTADA LOCALMENTE; pendiente QA físico y configuración social externa.**

- Feedback de demo: login/alta unificados, perfil sin fixtures, onboarding de
  sender, helpers Content, Review/editor inline, acuse de siete segundos,
  seguimiento en Registros, feedback de exportación y templates con chips.
- Feedback adicional: Mis eventos reutiliza swipe accesible, su override usa el
  editor compartido de variables y Registros exporta también Leads directos con
  el mismo contrato XLSX/CSV.
- Google usa federación Cognito ya configurada. Microsoft Sign-In/OIDC queda
  temporalmente fuera de esta versión por el conflicto de issuer observado con
  Entra; Login y Crear cuenta no muestran esa opción, aunque conservan el código
  reutilizable. Cognito continúa siendo el único issuer de Foloo y nunca se
  reutiliza OAuth de sender. La conexión Microsoft para envío permanece activa
  para cuentas personales compatibles; la UI advierte antes de OAuth que cuentas
  empresariales, educativas u organizacionales no están soportadas en esta
  versión. Google sender permanece sin cambios. FL-019.5
  supersede D-16 y retira unsubscribe activo sin destruir migraciones/tablas
  históricas.
- Mantiene preparación/intención únicas, reconciliación, adjuntos, outbox,
  Gmail/Graph, aislamiento y offline-first validados en FL-019.

## FL-020 — Trial & Subscription Foundation

**Objetivo:** foundation y autoridad server-side de creación de Leads.

- Contador histórico 0…5, cuatro estados, saldo, paywall informativo, caché
  owner-scoped y enforcement transaccional/offline.
- Nunca ocultar datos ni perder el sexto Lead en curso.
- Sin compra, precio, receipt, webhook o transición comercial real.
- Trazas: `MON-01`–`MON-11`, E-11, ADR-004.
- Estado: implementado en repositorio; requiere migraciones/QA físico.

## FL-020.5 — Unlimited temporal para QA

**Estado:** **CERRADO — implementado, desplegado y validado en Android físico
contra AWS DEV (2026-10-14).**

- Excepción temporal de `MON-12`, no cambio del producto comercial V1.
- Flutter requiere `--dart-define=FOLOO_UNLIMITED_QA_MODE=true`; sin el define
  conserva el paywall y el límite de cinco.
- La API requiere contexto CDK `unlimitedQaMode=true`, validado exclusivamente
  para DEV. No hay migración: PostgreSQL conserva estado y contador 0…5.
- Con ambos opt-ins, crear Leads no reserva ni consume trial y la UI oculta el
  saldo/paywall que sería engañoso. Consultar, editar, exportar, offline y sync
  mantienen la arquitectura existente.
- Desactivar exige una nueva configuración/backend y un build móvil sin el
  define. Los Leads existentes permanecen; las colas QA deben sincronizarse
  antes de retirar la excepción server-side.
- `FolooBackend-dev` quedó en `UPDATE_COMPLETE` con el flag global DEV activo.
  El APK Release `1.0.0+7`, firmado con el mismo certificado del Build 6,
  aprobó 8/8 pruebas físicas Android reportadas: actualización sin pérdida,
  Leads 6/7/10 sin paywall, sync online/offline, OCR Cámara/Galería,
  XLSX/CSV y persistencia tras reinicio. La evidencia detallada está en
  `android-private-distribution.md`.
- El cierre no autoriza publicación, Google Play, pagos, suscripciones reales,
  uso en PROD ni declara validación Unlimited en iOS.

## FL-020.6 — QA Corrections: sender identity + camera permissions

**Estado:** **CERRADO — implementado, desplegado en AWS DEV y validado
físicamente en iOS y Android el 2026-10-16.**

- **FL-020.6-A:** `SAL-11` congela en cada intención el nombre visible derivado
  exclusivamente de `seller_profiles.name`, con fallback `Foloo`, seguridad de
  headers, RFC 2047 para Gmail y `from.emailAddress.name` best effort para Graph.
  La migración aditiva `008_email_sender_identity.sql` está aplicada en AWS DEV;
  Gmail y Outlook fueron validados físicamente por el responsable de QA.
- **FL-020.6-B:** `OCR-10` centraliza CAMERA, Settings/revalidación, errores
  diferenciados y recuperación Android de `image_picker` para tarjeta,
  referencias y perfil; galería/captura manual permanecen independientes.
  La corrección limita la recuperación de datos perdidos a Android y amplía
  `VOZ-06` con permiso contextual de micrófono, Ajustes y retorno sin
  autograbación. El responsable de QA validó funcionalmente el flujo en iPhone
  y tablet Android.
- Infraestructura: `FolooBackend-dev` quedó `UPDATE_COMPLETE`, ApiFunction
  `Active / Successful`, migration `008_email_sender_identity.sql` aplicada y
  Unlimited QA activo exclusivamente en DEV.
- Android: APK Release Build 8 `1.0.0+8`, package `com.foloo.foloo`, conectado
  a AWS DEV y firmado con el mismo certificado de Build 7; validado en tablet.
- Evidencia automatizada final: `flutter analyze` sin problemas y 292/292
  pruebas Flutter aprobadas. La evidencia física fue reportada por el
  responsable de QA; no se inventan logs ni pruebas adicionales.
- No modifica Unlimited QA, trial, pagos ni la dirección OAuth autorizada.
- Trazas: `OCR-10`, `VOZ-06`, `SAL-11`, E-03/E-04/E-08; ADR-001/006/007.

**Evidencia asociada:** `email_sender_identity.test.ts`,
  `email_application.test.ts`, `email_migration_contract.test.ts`,
  `camera_access_service_test.dart`, `multi_photo_capture_test.dart` y
  `unified_v1_frontend_test.dart`.

El cierre no resuelve el límite de Voice Note `D-05`, la edición postguardado
de medios `D-06` ni los mockups finales `D-11`. Tampoco implementa FL-021,
FL-022, pagos, PROD o publicación en tiendas.

## FL-021 — Paywall & Payments

**Objetivo:** compra aprobada y transiciones comerciales confiables sobre la
autoridad de FL-020.

- Bloqueos: D-01–D-04 y mockups D-11.

## FL-022 — Infra/Production Hardening

**Objetivo:** entornos, CI/CD, crashes/logs, backups, retención y costos.

- Trazas: `INF-04`, `RC-*`, `RNF-*`.
- Bloqueo: D-13.

## FL-023 — V1 E2E + Field QA

**Objetivo:** cerrar `REL-01`–`REL-08`.

- E2E iOS/Android, offline/reconexión, OCR real, pago test/live, beta, assets,
  legales y beta de campo.

## FL-024 — Store Release

**Objetivo:** ficha, revisión de tiendas, tag, release notes y soporte V1.

### STORE-01 — Store Publication Readiness Audit

**Estado:** **COMPLETADA como auditoría documental el 2026-10-08; no autoriza
publicación ni implementación.**

- Matriz Apple/Google, inventario de privacidad, eliminación de cuenta,
  dependencias FL-021, checklist empresarial y plan STORE-02–04:
  [`store-readiness.md`](store-readiness.md).
- Publisher confirmado: CBQA Solutions. Se reutiliza la cuenta Apple existente;
  Google Play Console Organization ya existe; quedan pendientes la aceptación
  de acceso corporativo y verificaciones de identidad, sitio y teléfono.
- Bloqueos principales: eliminación de cuenta, privacidad/términos, Apple 4.8,
  PROD, firma Android Release, assets Foloo, `D-01`–`D-04` y `D-13`.
- STORE-02 remedia; STORE-03 prepara/valida RC y consolas; STORE-04 envía con
  autorización explícita. Ninguna fase se inicia automáticamente.

### STORE-02B — Identidad visual y materiales de tienda

**Estado:** **PREPARADA documentalmente el 2026-10-09; pendiente aprobación de
CBQA y producción de assets.**

- Inventario de marca, iconos/splash placeholders, requisitos Apple/Google,
  fichas ES/EN, plan de screenshots y checklist de carga:
  [`store-listing-materials.md`](store-listing-materials.md).
- No cambia Flutter ni reemplaza recursos. El logo/mark Foloo requiere
  aprobación formal y los iconos/launch actuales siguen siendo placeholders.
- Permanece dentro de FL-024/`REL-06`–`REL-07`; no resuelve STORE-01, FL-021,
  `D-01`–`D-04`, `D-11` ni `D-13`, y no autoriza publicación.

### STORE-02C — Privacy, Data Protection & Store Compliance

**Estado:** **ESPECIFICADA documentalmente el 2026-10-09; sin implementación ni
formularios enviados.**

- Inventario técnico de datos, matrices preliminares Apple/Google, auditoría de
  permisos, propuesta D-13, evaluación Apple 4.8 y plan P0/P1/P2:
  [`privacy-compliance.md`](privacy-compliance.md).
- Confirma que no existe eliminación integral; los tombstones actuales no la
  sustituyen. `D-13` permanece abierta y `D-21` registra la elección pendiente
  de Sign in with Apple o retiro de Google en iOS.
- Requiere aprobación Legal/Producto y evidencia del RC antes de llenar App
  Privacy/Data Safety. No cambia Flutter, backend, infraestructura ni cuentas.

### STORE-02D — Account Deletion Contract y resolución de D-13

**Estado:** **ACUERDOS DE PRODUCTO/CBQA COMUNICADOS el 2026-10-20; pendiente
autorización formal y validaciones Legal/Seguridad/Infra/Payments; sin
implementación.**

- Matriz de datos, barrera anti-resurrección, solicitud autenticada, job durable,
  PostgreSQL/S3/OAuth/Cognito, purga Drift owner-scoped, UX ES/EN y recurso web:
  [`account-deletion-contract.md`](account-deletion-contract.md).
- Define los criterios candidatos que STORE-02E-01 formalizó después en el SDD;
  STORE-02D por sí sola no autoriza endpoints, migraciones, AWS, pantallas o
  borrados reales.
- El registro posterior a revisión, acciones pendientes y espacio de validación
  están en
  [`account-deletion-cbqa-approval-agenda.md`](account-deletion-cbqa-approval-agenda.md).
  Producto definió un máximo operativo de eliminación de 15 días y una espera
  de 30 días antes de permitir un alta nueva con el mismo correo; la cuenta
  anterior nunca se recupera. Backups ordinarios de 15 días y reautenticación
  de cinco minutos siguen como propuestas sujetas a validación.
- `D-13` permanece abierta hasta cerrar categorías/base/plazos de retención,
  backups/restore, registro mínimo y barrera de 30 días, reautenticación,
  operación/escalamiento, suscripciones, rol legal sobre terceros, alcance
  regional y recurso web. La promoción a requisitos/E-14 quedó completada en
  STORE-02E-01; la implementación funcional continúa bloqueada hasta recibir
  las aprobaciones aplicables y autorización acotada por subtarea.

### Iniciativa web futura sin FL asignada

**Estado:** idea de Producto; fuera de Foloo V1, STORE-02D y STORE-02E.

- Dashboard desde `foloo.io` con captura manual de Leads en navegador.
- Experiencia limitada frente a la app móvil: sin OCR, notas de voz ni captura
  de imágenes de referencia, con orientación a descargar la app.
- No autoriza pantallas, endpoints, infraestructura ni modifica los
  identificadores actuales. Debe recibir alcance y trazas canónicas antes de
  entrar al roadmap implementable.

### STORE-02E — Preparación técnica de Account Deletion

**Estado:** **IMPLEMENTACIÓN FUNCIONAL LOCAL PREPARADA el 2026-10-20; runtime,
AWS y borrado real desactivados hasta aprobar los gates de D-13/ADR.**

- Arquitectura, flujo Mermaid, barrera de nuevo registro por 30 días, matriz de
  datos, integración abstracta de suscripciones, UX, pruebas y plan incremental:
  [`account-deletion-technical-design.md`](account-deletion-technical-design.md).
- Contrato HTTP implementado localmente detrás de controller fail-closed:
  [`account-deletion-openapi.yaml`](account-deletion-openapi.yaml).
- Requisitos canónicos `AUT-18`–`AUT-21`, `SYN-11`–`SYN-12`, `MON-13`,
  `INF-15`–`INF-21`, `RNF-09`–`RNF-10`, `RC-06`–`RC-10`, escenario E-14,
  criterios y matriz `DEC-AD`/pruebas/subtareas:
  [`account-deletion-requirements-traceability.md`](account-deletion-requirements-traceability.md).
- Seis decisiones de arquitectura permanecen como candidatas no aceptadas:
  [`../decisions/ADR-AD-account-deletion-candidates.md`](../decisions/ADR-AD-account-deletion-candidates.md).
- La revisión contra código/CDK real recomienda modificar AD-01/02/03/05 y
  aceptar AD-04 solo con condiciones; separa blocker de email 30 días de
  tombstone durable de subject, confirma el gap de ownership Cognito y que RDS
  conserva actualmente solo un día de backup automático:
  [`account-deletion-architecture-security-review.md`](account-deletion-architecture-security-review.md).
- STORE-02E-02A añade solo primitivas aisladas de canonicalización y HMAC con
  fixtures sintéticos; no están conectadas a Cognito, rutas ni AWS y no aceptan
  ninguna ADR:
  [`account-deletion-pseudonymous-identity.md`](account-deletion-pseudonymous-identity.md).
- STORE-02E-02B añade contrato de ledger, guard fail-closed y adaptador
  DynamoDB. STORE-02 prepara además la infraestructura CDK, KMS HMAC, workflow
  durable, cola/DLQ, checkpoints, OAuth, SES transaccional independiente y
  finalizador Cognito. La migración 009 prepara la barrera PostgreSQL antes de
  `ensure_personal_workspace`; API, callbacks OAuth, sync y worker tienen una
  composición real detrás de flags. PreSignUp federado y PostAuthentication
  común a email/Google se sintetizan con permisos, sin attachment; el
  reconciliador de restores tampoco se ejecuta. Todo permanece en `false`:
  [`account-deletion-ledger-guard.md`](account-deletion-ledger-guard.md).
- El incremento funcional añade contrato HTTP, verificación de `auth_time`,
  preflight/confirmación idempotentes, receipt hasheado, workflow reanudable,
  executor ordenado, puertos PostgreSQL/S3/OAuth/Cognito/Stripe, correos ES/EN,
  pantalla Flutter y purga Drift/archivos owner-scoped. El destinatario de los
  avisos se cifra con KMS, expira por TTL y SES usa `hello@foloo.io` como From y
  Reply-To sin tocar follow-ups. Sus pruebas usan solo datos sintéticos.
- `FOLOO_ACCOUNT_DELETION_ENABLED` permanece `false` en CDK y Flutter. El API
  usa el controller deshabilitado; worker, finalizador, SES, guards Cognito y
  reconciliador rechazan ejecución. El synth contiene recursos
  retenidos/cifrados, pero no se desplegaron. La migración 009 está preparada y
  no ejecutada; el workflow/tombstone durable sigue fuera de PostgreSQL.
- La ruta `foloo.io/delete-account` queda definida por el mismo contrato, pero
  no se creó otra web porque el repositorio de la landing no está presente y
  TI aún no autoriza modificar/desplegar CloudFront/S3.
- D-13 y las validaciones Legal/Seguridad/Infra/Operación/Payments continúan
  abiertas. No se desplegaron recursos, migraciones ni builds.
- `02E-02` dispone de primitivas aisladas 02A/02B, pero su conexión y despliegue
  siguen bloqueados hasta aprobar conjuntamente ledger, HMAC, prevención
  Cognito, guard anterior a provisioning, restore y threat model. `02E-03`
  requiere además aprobar
  reautenticación reciente. `02E-04`–
  `02E-08` conservan los gates específicos del contrato y la matriz de trazas.

### STORE-03B — Android Release APK y distribución privada

**Estado:** **CLOSED TÉCNICAMENTE; QA privado consolidado en Build 6.**

- Sustituye la firma Debug del build Release por un keystore Foloo externo al
  repositorio y credenciales locales inyectadas por entorno. El desarrollador
  es custodio temporal; respaldo cifrado y transferencia formal a TI siguen
  pendientes de confirmación empresarial.
- Produce un APK `1.0.0+2` exclusivamente para pruebas autorizadas contra DEV;
  no crea PROD, no publica en Google Play y no cambia iOS.
- Procedimiento reproducible, instalación, actualización y checklist manual:
  [`android-private-distribution.md`](android-private-distribution.md).
- El QA físico privado quedó completado en Build 6; `REL-01`, `REL-02`,
  `REL-06` y `REL-07` conservan pendientes el acceso a Play Console y los
  requisitos de publicación pública restantes.

### STORE-03C — Corrección OCR y exportaciones Android Release

**Estado:** **CLOSED; exportación validada y OCR resuelto por STORE-03D–03F.**

- El primer QA físico aprobó 8/10 áreas de STORE-03B y dejó abiertos OCR y
  exportación. El APK contiene el modelo latino bundled; la causa técnica OCR
  no puede cerrarse sin la excepción actualmente descartada y se instrumenta
  sin registrar imagen, texto reconocido, rutas ni PII.
- Conserva Compartir y añade Guardar en dispositivo para XLSX/CSV mediante el
  selector nativo Android 10+, sin permisos amplios de almacenamiento.
- Las actualizaciones privadas conservaron package/certificado y aumentaron
  `versionCode`; la validación final consolidada corresponde al build 6.

### STORE-03D — Diagnóstico definitivo de OCR Android Release

**Estado:** **EVIDENCIA NATIVA OBTENIDA; superseded operacionalmente por
STORE-03E.**

- Dos dispositivos Android reproducen el fallo en Cámara y Galería. El build 3
  no entregó la excepción nativa porque el diagnóstico no estaba controlado por
  una configuración Release de QA recuperable.
- Un build privado 4 puede habilitar exclusivamente con
  `FOLOO_OCR_QA_DIAGNOSTICS=true` eventos técnicos sanitizados de preparación,
  intento ML Kit y resultado, deshabilitados por defecto en distribución.
- No cambia R8, modelo, pipeline ni dependencias sin conocer primero etapa,
  tipo/código de plataforma e intento reales. STORE-03D solo puede cerrarse
  cuando Cámara y Galería reconozcan texto latino en Android Release físico.

### STORE-03E — Aislamiento del fallo nativo OCR Android Release

**Estado:** **COMPLETADA COMO DIAGNÓSTICO; Build 5 validado físicamente.**

- Build 4 confirmó preprocesamiento exitoso y un `PlatformException(error)`
  nativo repetible en las cinco orientaciones. Retrace con el mapping exacto
  ubica el `NullPointerException` en `vision-common:17.3.0`, dentro de
  `zzmj.<init>` invocado por `zzmr.create`; eso identifica el punto de fallo,
  pero no prueba por sí solo causalidad de R8.
- Build 5 conserva package, certificado, AWS DEV, dependencias y pipeline OCR;
  solo desactiva minificación y resource shrinking mediante el flag local de
  QA `FOLOO_ANDROID_DISABLE_R8_FOR_OCR_QA=true`.
- Durante STORE-03E no se agregó una regla ProGuard ni se cambió permanentemente
  Release antes de comparar Cámara y Galería en el mismo Android físico. La
  revalidación con R8 activo corresponde a STORE-03F.

Build 5 reconoció correctamente desde Cámara y Galería. Esto confirma que la
diferencia de optimización del build 4 es causal, pero no convierte desactivar
R8 en solución permanente.

### STORE-03F — Corrección ML Kit OCR con R8 habilitado

**Estado:** **CLOSED — BUILD 6 OPTIMIZADO VALIDADO FÍSICAMENTE.**

- `firebase-components:16.1.0` conserva las clases `ComponentRegistrar` con una
  regla anterior a AGP 9 strict full mode. En build 4 R8 mantuvo
  `CommonComponentRegistrar`, pero eliminó su constructor público sin
  argumentos; el descubrimiento reflectivo no pudo crear el registrar y
  `SharedPrefManager` nunca quedó registrado.
- La corrección conserva exclusivamente el constructor público sin argumentos
  de implementaciones `ComponentRegistrar`. R8, optimización, obfuscación y
  resource shrinking permanecen activos; no se conserva globalmente ML Kit ni
  Google.
- QA físico del responsable aprobó en `1.0.0+6`: OCR desde Cámara y Galería,
  conservación de datos/sesión, exportación CSV/XLSX, sincronización AWS DEV y
  persistencia tras reinicio. La regla mínima queda como configuración Release.

### STORE-03G — Cierre técnico y distribución Android privada

**Estado:** **COMPLETADA COMO AUDITORÍA TÉCNICA.**

- Consolida la auditoría STORE-03B–03F y conserva build 6 como candidato privado
  para testers autorizados, siempre contra AWS DEV.
- No publica en Google Play, no crea un enlace público y no distribuye el APK
  automáticamente. Firma, hash, instrucciones y reporte están documentados en
  [`android-private-distribution.md`](android-private-distribution.md).
- La auditoría entregó los cambios listos para integración; las operaciones Git
  posteriores permanecieron bajo control exclusivo del desarrollador y fuera
  del alcance de STORE-03G.

### STORE-03H — Preparación final de distribución Android

**Estado:** **PREPARADA; distribución privada pendiente de autorización.**

- Build 6 (`1.0.0+6`) permanece como único candidato privado aprobado, firmado
  y conectado a AWS DEV; STORE-03F continúa CLOSED.
- Firma, SHA-256, manifest, versión y configuración Release se verifican sobre
  el APK existente, sin reconstruirlo ni modificar funcionalidad.
- Instrucciones de actualización, checklist de tester, mensaje de entrega y
  registro de resultados se consolidan en
  [`android-private-distribution.md`](android-private-distribution.md).
- Cargar, compartir o publicar el artefacto requiere autorización humana. Las
  operaciones Git quedan reservadas al desarrollador: esta actividad no hace
  add, commit, push, checkout, switch, merge, pull, reset ni stash.

## Exclusiones del plan V1

No existen fases Basic E2E, capability Basic/Pro, Pro E2E, transcripción Pro ni
Google Sheets. Backlog no se introduce en estas FL.
