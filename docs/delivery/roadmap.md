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

## Propuesta FL-014 — Brechas locales restantes de V1

**Objetivo:** completar las brechas locales restantes sin ampliar backend.

- Completar perfil con puesto/teléfono y edición.
- Completar detalle editable para campos no-media y persistencia local.
- Normalizar estado/copy ES/EN y conservar módulos existentes.
- Trazas: `AUT-08`, `REG-05`–`REG-08`, `NAV-01`–`NAV-07`, `VOZ-08`,
  `CON-*`.
- Bloqueos: D-06/D-11 solo para medios/fidelidad faltante.

## Propuesta FL-015 — Contratos API, sync y persistencia cloud

**Objetivo:** cerrar ADRs y contratos antes de construir servicios.

- API idempotente, ownership/tenancy, modelo remoto y reconciliación.
- Selección por ADR de base cloud; modelo preparado para Teams sin construirlo.
- Estados/colas y contrato de trial/suscripción.
- Trazas: `SYN-*`, `INF-01`, `INF-03`.
- Bloqueos: D-10, D-12, D-13.

## Propuesta FL-016 — Sync offline y S3 de medios

**Objetivo:** subir/reanudar Leads y binarios sin pérdidas/duplicados.

- API Gateway/Lambda, colas separadas, retry y reconciliación.
- S3 protegido para tarjeta, referencias, voz y PDF.
- Trazas: `SYN-04`–`SYN-10`, `INF-02`, `RC-02`, `RC-03`.
- Bloqueos: D-05, D-08, D-13.

## Propuesta FL-017 — Contenido y plantillas productivas

**Objetivo:** sustituir modelos demo por persistencia local/remota.

- PDF, asignación/evento, adjuntos congelados y plantillas validadas.
- Trazas: `CON-*`, `PLT-*`, E-07.
- Bloqueos: D-08/D-11.

## Propuesta FL-018 — Correo de seguimiento

**Objetivo:** envío server-side con cola offline y cumplimiento.

- Proveedor por ADR, variables, adjuntos, SPF/DKIM/DMARC, baja, rebotes y
  reputación.
- Trazas: `SAL-*`, `RC-01`, E-08.
- Bloqueos: D-09 y contrato destinatario/estados incluido allí.

## Propuesta FL-019 — Exportación XLSX/CSV por evento

**Objetivo:** generar, validar acentos y compartir archivos locales.

- Trazas: `REG-09`–`REG-13`, `REL-08`, E-10.
- Bloqueo: D-07.

## Propuesta FL-020 — Trial, paywall y suscripción anual

**Objetivo:** autoridad server-side y captura ilimitada tras pago.

- Contador, saldo, paywall, flujo aprobado, webhook, caché y vencimiento.
- Nunca ocultar datos ni perder el sexto Lead en curso.
- Trazas: `MON-*`, E-11.
- Bloqueos: D-01–D-04 y mockups D-11.

## Propuesta FL-021 — Plataforma, privacidad y observabilidad

**Objetivo:** entornos, CI/CD, crashes/logs, backups, retención y costos.

- Trazas: `INF-04`, `RC-*`, `RNF-*`.
- Bloqueo: D-13.

## Propuesta FL-022 — QA de campo y tiendas

**Objetivo:** cerrar `REL-01`–`REL-08`.

- E2E iOS/Android, offline/reconexión, OCR real, pago test/live, beta, assets,
  legales, revisión, tag, release notes y soporte.

## Exclusiones del plan V1

No existen fases Basic E2E, capability Basic/Pro, Pro E2E, transcripción Pro ni
Google Sheets. Backlog no se introduce en estas FL.
