# ADR-AD — Candidatas de arquitectura para Account Deletion

- Estado: **Propuestas; ninguna aceptada**
- Fecha: 2026-10-20
- Alcance: preparación de STORE-02E-02/03
- Trazas: `AUT-19`, `AUT-21`, `INF-18`–`INF-21`, `RNF-09`, `RNF-10`,
  E-14 y `D-13`

Este registro agrupa seis decisiones que deben convertirse en ADR numeradas y
aceptadas por separado antes de implementar las ramas afectadas. No modifica
ADR-001–007, no selecciona servicios AWS y no autoriza migraciones, triggers,
IAM, endpoints o pruebas destructivas.

La revisión de viabilidad contra HEAD está en
[`../delivery/account-deletion-architecture-security-review.md`](../delivery/account-deletion-architecture-security-review.md).
Su resultado no acepta estas ADR: recomienda **modificar** AD-01, AD-02, AD-03
y AD-05, y aceptar AD-04 únicamente con condiciones adicionales. En particular,
separa el blocker de correo de 30 días del tombstone durable del `sub` anterior.

## `ADR-AD-01` · Autoridad durable de barrera y ledger

**Problema.** PostgreSQL contiene los datos a borrar y puede restaurarse desde
un snapshot anterior; por tanto no puede ser la única autoridad que impida
resurrección.

| Alternativa | Ventaja | Riesgo |
|---|---|---|
| Tabla PostgreSQL | Menor infraestructura y transacción local | Restore anterior pierde barreras; conflicto con borrado de cuenta |
| Export/checkpoint de ledger | Puede separarse del restore principal | Reconciliación compleja, ventana de inconsistencia y operación manual |
| Store durable externo, por ejemplo DynamoDB | Ciclo de restore independiente, condicionales atómicas y TTL auxiliar | Nueva infraestructura, IAM, costo, disponibilidad y operación |

**Recomendación para aprobación:** store externo cifrado, con escritura
condicional, PITR/backup, `expiresAt` evaluado por la aplicación y sin PII en
claro. DynamoDB es candidato, no decisión. Infra y Seguridad deben definir
RTO/RPO, fail-closed, alarmas, retención y recuperación.

## `ADR-AD-02` · Identificador seudonimizado del bloqueo de 30 días

| Alternativa | Ventaja | Riesgo |
|---|---|---|
| Email normalizado en claro | Comparación simple | PII innecesaria, mayor impacto de exposición y borrado difícil |
| Hash sin clave | No guarda texto claro | Vulnerable a enumeración/diccionario de emails |
| HMAC versionado sobre email verificado | Resiste enumeración sin clave y admite rotación | Exige canonicalización, gestión de llave y comparación multiversión |

**Recomendación para aprobación:** `HMAC-SHA-256(keyVersion,
canonicalVerifiedEmail)` más `subject_hash` separado; nunca email como owner o
primary key. Seguridad debe aprobar fuente de atributo verificado,
canonicalización Unicode/case/aliases, KMS HMAC frente a clave en Secrets
Manager, rotación, acceso y plazo del registro.

## `ADR-AD-03` · Prevención de nuevas identidades Cognito

| Alternativa | Ventaja | Riesgo |
|---|---|---|
| Guard solo en API | No cambia Cognito | Cognito crea antes la identidad; mala UX y eventos externos ya ocurrieron |
| Pre Sign-up trigger solamente | Bloquea email/password y federados antes de crear | No protege tokens antiguos, callbacks ni bypass de una ruta backend |
| Pre Sign-up + guard backend | Defensa en profundidad y cubre alta/operación | Dos integraciones y política de disponibilidad coherente |

**Recomendación para aprobación:** dos capas: trigger para `SignUp` y
`ExternalProvider`, más guard backend para toda sesión/request. Nunca vincular
cuentas por email ni revelar motivo/historial. Seguridad/Infra deben aprobar
fail-closed, timeout, mensajes, observabilidad y recuperación.

## `ADR-AD-04` · Barrera anterior a `ensure_personal_workspace`

| Alternativa | Ventaja | Riesgo |
|---|---|---|
| Checks por handler | Migración incremental | Es fácil olvidar rutas/callbacks y provisionar antes del check |
| Middleware después de resolver principal | Centralizado | `ensure_personal_workspace` ya pudo recrear cuenta/workspace |
| Resolver principal envuelto por guard previo | Invariante único para clientes nuevos y antiguos | Requiere adaptar rutas públicas y evitar TOCTOU entre ledger/DB |

**Recomendación para aprobación:** frontera central previa a resolución o
provisión, compartida por API, callbacks y replays; la confirmación crea barrier
antes de responder. La implementación debe definir consistencia/locks y códigos
de error estables sin convertir un fallo de dependencia en reprovisión.

## `ADR-AD-05` · Restore sin resurrección

| Alternativa | Ventaja | Riesgo |
|---|---|---|
| Restaurar RDS y abrir tráfico | Menor tiempo aparente | Puede revivir cuentas eliminadas; descartada |
| Restaurar y ejecutar script manual desde tickets | Menos infraestructura | Evidencia incompleta, error humano y carrera al abrir tráfico |
| Traffic gate + reconciliación desde ledger externo | Invariante verificable y automatizable | Aumenta RTO y requiere runbook/pruebas periódicas |

**Recomendación para aprobación:** mantener tráfico cerrado, restaurar RDS,
reconciliar barreras/requests desde la autoridad externa, verificar cuentas
eliminadas y solo entonces habilitar tráfico. Infra/Legal deben separar backup
ordinario, legal hold y evidencia mínima; 15 días sigue propuesta de
`DEC-AD-02`.

## `ADR-AD-06` · Evidencia de reautenticación reciente

| Alternativa | Ventaja | Riesgo |
|---|---|---|
| Confiar en token válido o refresh silencioso | Sin UX adicional | No demuestra interacción reciente; insuficiente |
| Verificar `auth_time` de una sesión forzada | Señal estándar Cognito | Debe comprobarse email/password y Google; Hosted UI puede reutilizar sesión |
| Challenge backend propio ligado a login reciente | Control fino y nonce de una sola vez | Mayor superficie, lifecycle y riesgo de duplicar autenticación |

**Recomendación para aprobación:** spike no destructivo que fuerce una
interacción Cognito compatible con email/password y Google y valide server-side
`auth_time` más nonce deletion-bound de vida corta. No aceptar passwords,
timestamps o booleanos del cliente. Seguridad decide mecanismo, fallback,
skew/replay y la propuesta de cinco minutos de `DEC-AD-09`.

## Orden de decisión requerido

1. Aprobar conjuntamente `ADR-AD-01`, `02`, `03`, `04` y `05`; forman una sola
   propiedad anti-resurrección y no deben implementarse aisladamente.
2. Aprobar `ADR-AD-06` antes de programar confirmación API o UI.
3. Numerar cada ADR según la convención del repositorio únicamente al recibir
   aprobación explícita; actualizar después README, trazabilidad y threat model.

Hasta entonces STORE-02E-02 permanece bloqueada para código. Solo se permiten
revisión documental y spikes no destructivos expresamente autorizados.
