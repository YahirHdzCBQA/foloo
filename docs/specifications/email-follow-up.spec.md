# Email Follow-up Specification

## Purpose

Send the required follow-up to the lead and operational notice to marketing without making email delivery a condition for preserving the lead.

## Related Requirements

- RF-27
- RF-28
- RF-29
- RF-30
- RF-31
- RF-32
- RNF-08
- RC-01
- RC-02
- RC-05
- Acceptance criteria 5 and 6

## User Behavior

Submitting a lead initiates two backend-managed emails. Marketing can see each email's delivery state. Templates can be changed without modifying application code.

## Business Rules

- One email goes to the lead and one to the configured marketing address.
- Lead subject: follow-up plus event name. Body: first-name greeting, event context, promise to send agreed information, capture-person signature, privacy-notice link, contact reason, and clear opt-out.
- Lead-template variables: `nombre`, `evento`, `capturadoPor`, `empresa`, `siguientePaso`.
- The visible sender uses the company's sender identity, not an anonymous generic account.
- Marketing subject: `[Tipo] Nombre · Empresa`. Body: all lead fields, highlighted note, and audio link.
- Email failure never prevents record storage; failed mail enters retry handling.
- Templates are editable outside code, either in configuration or the email service.
- Opt-out must be respected in the sheet and subsequent sends. Scope beyond this system is open.
- The capture person verbally advises the lead that a follow-up email will be sent.
- Expected event volume must be checked against provider limits before the event.

## Data Requirements

Recipient addresses, configured marketing address, sender identity/domain, template variables/content, privacy URL, opt-out state, and independent lead/marketing email statuses.

## States

Each email state is exactly `enviado`, `en cola`, or `fallido` in the business data model. Retry attempt metadata is not specified.

## Validation

Lead email requires a valid email address. Required content must be present. A stored opt-out must prevent later applicable sends, though exact enforcement timing and scope remain open. The business data model permits a phone-only lead, so behavior for the otherwise-required lead email is unresolved (OQ-A13).

## Failure / Degraded Behavior

Save the lead regardless of mail outcome. Queue failed mail for retry and expose its state. Provider capacity shortfall must be identified before an event.

## Acceptance Criteria

- The lead receives mail within two minutes with correct visible sender, privacy notice, and opt-out (global criterion 5).
- Marketing receives all fields, the note, and a playable authorized audio link (global criterion 6).
- Failure of either email leaves the lead stored and the mail retryable.

## Out of Scope

Choosing an email provider and automatically propagating opt-out to external marketing lists until scope is decided.
