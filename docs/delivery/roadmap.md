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

## FL-016 — Media & Content Storage / S3 (implementada en repositorio)

**Objetivo:** subir/reanudar Leads y binarios sin pérdidas/duplicados.

- Extiende la outbox FL-015 con autorización, PUT S3 directo, confirmación y
  lectura temporal para tarjeta, referencias y voz.
- Bucket privado cifrado, sin NAT; Lambda verifica por endpoint Gateway S3.
- PostgreSQL conserva metadata/estado mediante migration 002; no binarios.
- Trazas: `SYN-04`–`SYN-10`, `INF-02`, `RC-02`, `RC-03`.
- Validación AWS DEV y política final de retención siguen pendientes. D-05 no
  impide el techo técnico antiabuso; el contrato PDF se definió en FL-018 y
  D-13 no se considera resuelta.

## FL-017 — Records + XLSX/CSV Export

**Estado:** estabilización en repositorio; pendiente deploy DEV y nueva validación
física sobre la misma instalación de iPhone. No cerrar todavía.

- Records local-first, detalle y edición estructurada con revisión optimista.
- Exportación local por evento a XLSX/CSV y hoja de compartir.
- Trazas: `REG-01`–`REG-13`, `SYN-*`, `REL-08`, E-06/E-09/E-10.
- `D-07` resuelta el 2026-09-15; `D-06` sigue bloqueando edición de medios.

## FL-018 — Content/PDF

**Objetivo:** sustituir contenido PDF demo por persistencia local/remota.

- Biblioteca PDF, asignación/evento y adjuntos congelados.
- Trazas: `CON-*`, E-07.
- D-08 resuelta el 2026-09-17: 25 MB/PDF, sin cuota comercial total ni desalojo automático; borrado lógico sin `DeleteObject`. D-11 no bloquea funcionalidad técnica, solo fidelidad visual final.

## FL-019 — Email/Templates

**Objetivo:** plantillas productivas y envío server-side con cumplimiento.

- Trazas: `PLT-*`, `SAL-*`, `RC-01`, E-08; ADR-006.
- D-09 resuelta el 2026-09-18: cuenta autorizada del vendedor, Google OAuth +
  Gmail API y Microsoft OAuth + Graph; sin SES/SMTP para follow-ups.
- D-14–D-20 resueltas el 2026-09-18; implementar el contrato de E-08 y el
  egreso seguro documentado en ADR-007. No cerrar hasta deploy y validación
  física Google, Microsoft, offline, adjuntos, baja y anti-duplicados.
- Implementación local 2026-09-18: OAuth Google/Microsoft, follow-up/outbox,
  Gmail/Graph, adjuntos, opt-out, KMS y Lambda de egreso separada. Microsoft
  conserva `Mail.Send` y nunca eleva a `Mail.ReadWrite`; sigue pendiente la
  configuración externa, deploy y validación física.
- QA Google 2026-09-19 confirmó autorización/callback real. El ajuste vigente
  añade cuenta de envío opcional después del perfil, grandfathering de perfiles
  existentes y refresh backend-authoritative al volver de OAuth/Correo; no
  confunde la cuenta Cognito con el remitente ni condiciona captura.
- Corrección local 2026-09-20: Guardar → Revisar → `foloo`, snapshot concreto
  antes de outbox, confirmación online/offline veraz, asunto renderizado en
  backend y aceptación Graph `202` sin cuerpo. Pendiente deploy y QA física.

## FL-020 — Trial & Subscription Foundation

**Objetivo:** autoridad server-side y captura ilimitada tras pago.

- Contador, saldo, paywall, flujo aprobado, webhook, caché y vencimiento.
- Nunca ocultar datos ni perder el sexto Lead en curso.
- Trazas: `MON-*`, E-11.
- Bloqueos: D-01–D-04 y mockups D-11.

## FL-021 — Paywall & Payments

**Objetivo:** UI y compra aprobadas sobre la autoridad de FL-020.

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

## Exclusiones del plan V1

No existen fases Basic E2E, capability Basic/Pro, Pro E2E, transcripción Pro ni
Google Sheets. Backlog no se introduce en estas FL.
