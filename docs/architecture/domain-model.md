# Current Conceptual Domain Model

This is a navigation aid for the authoritative entity definitions in
`../specifications/current/01-especificacion.md` §3 and the Pro delta in
`05-especificacion-pro.md` §2. It is not a database, Dart or API schema.

## Edition boundary

- Basic owns `Usuario`, `Evento` and `Lead`.
- Pro inherits those entities and adds `Archivo de contenido`, `Plantilla de
  correo`, and the documented Lead/Evento fields.
- The server-provided account capability controls which Pro fields and modules
  are active. Basic must not expose placeholder Pro fields.

## Basic Usuario

`id`, `usuario`, `nombre`, `empresa` and `plan` are required; `fotoUrl` is
optional. `plan` is supplied by the server. Authentication and profile data
persist as required by `AUT-02`, `AUT-04` and `AUT-05`.

## Basic Evento

`id`, generated `codigo`, `nombre`, `fechaInicio`, `fechaFin`, `activo` and
logical-deletion flag `eliminado` are required; `hojaUrl` is optional. Exactly
one event is active. Deleting is logical and never deletes the spreadsheet or
lead data (`EVT-02`, `EVT-08`, `RC-07`).

## Basic Lead column contract

The following order is authoritative for the Basic spreadsheet:

| Order | Field | Required/constraint |
|---:|---|---|
| 1 | `folio` | required; human-readable idempotency key; generation blocked by `D-03` |
| 2 | `fecha` | required ISO 8601 timestamp |
| 3 | `origen` | required: `evento` or `directo` |
| 4 | `evento` | required only for event origin |
| 5 | `capturadoPor` | required from profile |
| 6 | `nombre` | required |
| 7 | `apellido` | optional |
| 8 | `puesto` | optional |
| 9 | `empresa` | required |
| 10 | `correo` | required if telephone is absent; validate format when present |
| 11 | `telefono` | required if email is absent |
| 12 | `tipo` | required: `Cliente`, `Partner`, or `Proveedor`; no default |
| 13 | `interes` | required: `Alto`, `Medio`, or `Bajo`; default `Medio` |
| 14 | `nota` | optional written note |
| 15 | `audioSegundos` | optional automatic duration |
| 16 | `audioUrl` | optional protected uploaded link |
| 17 | `tarjetaUrl` | optional uploaded link |
| 18 | `estadoSync` | required: `local`, `pendiente`, or `enHoja` |

`siguientePaso`, transcription and email states are not Basic fields. Audio,
photo and notes are optional; absence never blocks a valid lead.

## Pro delta

Pro adds to Lead: required conditional `lugar` for direct leads, optional
`transcripcion`, frozen `adjuntos`, `estadoTranscripcion`,
`estadoCorreoLead`, and `estadoCorreoMarketing`. The Pro specification says
five columns are appended while listing six lead changes; this internal
counting conflict must be clarified before finalizing the spreadsheet schema.
No existing Basic column may move.

Pro adds `archivos` to Evento and introduces:

- `Archivo de contenido`: identity, display/original names, PDF metadata,
  server URL, optional cache path, all-events switch or event IDs, uploader and
  creation time.
- `Plantilla de correo`: exactly one event and one direct template per account,
  with subject/body and audit metadata. Ownership remains blocked by `DP-03`.

## Invariants and unresolved contracts

- A lead is durably stored locally before any network attempt.
- A repeated folio must not create duplicate rows, emails or attachments.
- User corrections always win over extraction.
- Provider calls and credentials stay behind the Foloo backend.
- Media access is authenticated and retention is governed by `RC-03`/`D-11`.
- Final local schema, folio concurrency, sync reconciliation, file-cache
  limits, deletion enforcement and Pro capability downgrade require decisions
  or ADRs. Do not infer them from the Flutter prototype.
