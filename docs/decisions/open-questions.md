# Open Questions

Questions here are unresolved. They are not decisions or permission to assume behavior.

## Source: Business Requirements

1. **Final data destination:** Google Sheets is sufficient for V1, but is the next destination HubSpot or Salesforce, and should `tipo`/`interes` already align to that CRM? Direct CRM integration remains out of V1.
2. **Backend scope:** should one server-side service own extraction, transcription, Sheets, files, and email, or should those responsibilities be separated? The server boundary itself is already required.
3. **Expected volume:** how many leads per event and how many concurrent capture people must be supported, particularly for email-provider sizing (RNF-08)?
4. **Sending account:** which domain/mailbox sends lead email, and who is the visible sender (RF-28)?
5. **Opt-out scope:** does opt-out apply only to Foloo/this sheet or propagate to other marketing lists (RC-02)?

## Source: Architecture Analysis

| ID | Question | Why it must be resolved | Related requirements |
| --- | --- | --- | --- |
| OQ-A01 | What does configurable `destino de datos` allow in V1 when Google Sheets is the specified V1 destination? | Avoids implying unsupported CRM/destinations. | RF-24, RF-33 |
| OQ-A02 | Does `sitio web` become a lead/Sheet field, and should it appear in the extraction contract? | RF-03 requests it, while the example JSON and Section 5 omit it. | RF-03, RF-24 |
| OQ-A03 | Which field(s) record opt-out, synchronization status, and retention metadata, and where do they appear in the fixed Sheets column order? | These behaviors are required but absent from Section 5. | RF-19, RF-22, RC-02, RC-03, RF-24 |
| OQ-A04 | How is `EXP` derived, when does `NNN` reset, and how is folio uniqueness preserved with multiple offline devices? | Folio format is shown, but generation/concurrency semantics are missing. | RF-12, RF-21 |
| OQ-A05 | Are both email-state fields required at initial local save, and what values do they receive before an email can be queued? | Section 5 makes them required, but permitted values describe delivery processing only. | RF-18, RF-27, RF-31 |
| OQ-A06 | Where does marketing view per-email statuses? | Visibility is required, but the mobile list or another interface is not specified. | RF-22, RF-31 |
| OQ-A07 | Does exported CSV use exactly the Section 5 field order, and does it include later-required operational fields? | RF-23 defines encoding, not columns. | RF-23, RF-24 |
| OQ-A08 | What is the approved retention period, and what happens to lead links after media deletion? | Legal/Dirección must decide before automatic deletion is implementable. | RC-03 |
| OQ-A09 | What authentication mechanism protects Sheets/media when V1 user authentication and roles are out of scope? | RC-04 requires authenticated restricted access, while app auth is backlog. | RC-04 |
| OQ-A10 | What retry/status behavior applies when Sheets or file storage fails after backend acceptance? | Email retry is explicit; other secondary integrations are not equally specified. | RF-18, RF-20, RF-24, RF-26, RF-30 |
| OQ-A11 | What constitutes “same result” for 30-second transcription across iOS and Android? | A measurable comparison threshold/test fixture is not defined. | RF-14, acceptance criterion 7 |
| OQ-A12 | Which privacy-notice URL/content and operational evidence are required before the first event? | Compliance content cannot be invented by implementation. | RC-01, RC-05 |
| OQ-A13 | What happens to the required lead email when a valid lead has phone but no email? | Section 5 permits phone-only leads, while RF-27 requires an email to every lead and the success metric expects cards to have email sent. | RF-27, Section 5 validation, success metric |
| OQ-A14 | Is `apellido` a separate extraction/domain/Sheet field, or only a presentation split of `nombre`? | The approved mockup separates Nombre and Apellido, while RF-03, Section 5, and the conceptual model define only `nombre`. | RF-03, RF-05, RF-24 |
| OQ-A15 | Does V1 include a `solución de interés` multi-select catalog, and where is it stored/exported? | The mockup shows Scanley IMS, CBQA General, and Vision AI, but no requirement or conceptual field defines this behavior. | RF-24, Section 5 model |
| OQ-A16 | Where does the editable, persistent RF-33/RF-34 event configuration live when the approved Evento mockup is explicitly read-only? | The visual consultation view cannot replace the required settings workflow without losing specified behavior. | RF-33, RF-34 |
| OQ-A17 | Does confirmation return automatically after three seconds, or only when the user selects `Capturar otro ahora`? | The PDF describes an automatic return, while the requested navigation flow and current specification describe an explicit capture-another action without defining a timeout. | Core user flow, RNF-05 |
| OQ-A18 | Which recording container/codec, maximum duration, and local retention policy are approved for production voice notes? | RF-13/RF-15 require local recording controls, but the source requirements do not define these media constraints. The current AAC/M4A session file is a proposed implementation detail, not a backend contract. | RF-13, RF-15, RF-16, RC-03 |

## Decisions to Capture Later as ADRs

- Local persistence technology and schema.
- Synchronization/reconciliation protocol and state model.
- Backend service boundaries, framework, hosting, and API contracts.
- Vision, speech-to-text, file-storage, and transactional-email providers.
- Credential/secret management and authenticated media access.
- Email capacity plan based on approved volume.
- Retention automation after Legal/Dirección approves a period.
Qué tal, Ángel! Oye, estoy configurando Foloo para poder correrlo en un iPhone físico y Xcode me está bloqueando la firma porque aparece pendiente una actualización del Apple Program License Agreement. Me indica específicamente que tú, como Account Holder, necesitas aceptar el acuerdo más reciente. ¿Me ayudas aceptándolo cuando puedas? En cuanto quede, Xcode ya debería poder generar el provisioning profile y dejarme correr la app en el iPhone.