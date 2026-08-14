# Conceptual Domain Model

This model transcribes Section 5 of the business requirements. It is not a SQL schema, Dart model, or final JSON schema.

## Lead

| Field | Conceptual type / allowed values | Required | Origin | Validation and notes |
| --- | --- | --- | --- | --- |
| `folio` | text | Yes | generated | Human-readable; example `EXP-260812-001`; idempotency key. Derivation rules remain open. |
| `fecha` | ISO date-time | Yes | automatic | Recorded automatically per lead. |
| `evento` | text | Yes | settings | Entered once per event. |
| `capturadoPor` | text | Yes | settings | Entered once per event. |
| `nombre` | text | Yes | extraction or manual | Must not be empty. |
| `puesto` | text | No | extraction or manual | No additional validation defined. |
| `empresa` | text | Yes | extraction or manual | Must not be empty. |
| `correo` | email | Conditionally | extraction or manual | At least one of email/phone; validate email format before sending. |
| `telefono` | text | Conditionally | extraction or manual | At least one of phone/email; format rules are not defined. |
| `tipo` | `Partner` \| `Cliente potencial` | Yes | selection | Mandatory choice. |
| `interes` | `Alto` \| `Medio` \| `Bajo` | Yes | selection | Default is `Medio`. |
| `siguientePaso` | catalog | Yes | selection | `enviar información`, `agendar llamada`, `cotizar`, `solo seguimiento`. |
| `nota` | long text | No | voice or written | Editable transcription or manually written note. |
| `audioSegundos` | number | No | automatic | Duration; limits are not defined. |
| `audioUrl` | link | No | upload | Must resolve through authenticated access for authorized marketing/sales users. |
| `tarjetaUrl` | link | No | upload | Original-card retention is RF-07 (`Debería`); access/retention are constrained by RC-03/RC-04. |
| `estadoCorreoLead` | `enviado` \| `en cola` \| `fallido` | Yes | system | Status of lead email. |
| `estadoCorreoMarketing` | `enviado` \| `en cola` \| `fallido` | Yes | system | Status of marketing email. |

## Record-wide Invariants

- `nombre` and `empresa` are required.
- At least one of `correo` and `telefono` is required.
- `correo`, when present for sending, has valid email format.
- `tipo`, `interes`, and `siguientePaso` use only the defined catalogs.
- Automated extraction never replaces a value already corrected manually.
- The lead is persisted locally before network delivery.
- Reuse of `folio` must not create a duplicate destination row.

## Related Concepts Not Yet Fields

- RF-03 requests optional website extraction, but Section 5 and the expected extraction response omit a website field.
- RC-02 requires opt-out to be recorded in the sheet and respected, but Section 5 has no opt-out field.
- RC-03 requires media retention/deletion, but no retention metadata appears in Section 5.
- RF-19/RF-22 require visible synchronization status, but no synchronization-status field appears in Section 5.

These are specification gaps, not permission to extend the model silently. They are tracked in `../decisions/open-questions.md`.
