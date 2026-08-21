# Foloo V1 Product Specification

## Product Purpose

Foloo prevents business cards collected at in-person events from being lost, registered late, or left without follow-up. It turns each card into a traceable lead and supports same-day contact.

## Primary User

Commercial staff capturing leads while physically working at an event. V1 has no user authentication or roles.

## Usage Context

The user may be standing, holding a card, and operating a phone with one hand. Venue connectivity may be poor or absent. A complete lead must be capturable in under 60 seconds, and lack of connectivity must never cause lead loss.

## V1 Goals

- Capture card data by camera or gallery, with correction and manual fallback.
- Classify the lead and capture written or spoken conversation context.
- Save locally before any network operation, then synchronize without duplicates.
- Maintain an event lead list and export it as an Excel-compatible CSV.
- Write each lead to Google Sheets and send the two required follow-up emails.
- Protect personal data and preserve traceability through a readable folio.

## Success Metrics

- At the next event, 100% of received cards are captured and have email sent within 24 hours. The stated baseline is approximately 40%, reaching marketing one or two weeks later.
- A complete lead is registered from app opening through acknowledgement in under 60 seconds on a real phone.

## In Scope

1. Camera/gallery business-card capture and automatic field extraction.
2. Partner or potential-customer classification, interest, and next step.
3. Voice note with transcription and written note.
4. Automatic Google Sheets output.
5. One email to the lead and one to marketing per lead.
6. Offline operation with a synchronization queue.
7. CSV/Excel export.
8. Event-level settings and an event lead list with statuses.
9. Privacy, opt-out, retention, and access-control obligations in RC-01 through RC-05.

## Out of Scope

- Event-badge QR scanning.
- Direct HubSpot or Salesforce integration.
- Event or salesperson metrics dashboards.
- Production user authentication and roles. A local, non-authenticating
  prototype access shell may be used for visual and navigation validation; it
  is not a V1 authentication capability and must not store credentials, issue
  tokens, or make network requests.
- App Store and Play Store publication; V1 only requires internal distribution.

## Core User Flow

1. Configure event settings once per event.
2. Photograph or select a card, run automatic extraction, and correct fields if needed.
3. Select Partner or Cliente potencial, interest, and next step.
4. Add a voice note for server transcription or a written note.
5. Save and send; Foloo stores locally first and presents an acknowledgement with folio.
6. Capture another lead while background delivery and retry continue as connectivity permits.

## Product Principles

- **Fast capture:** complete registration in under 60 seconds and do not retype printed card data when extraction succeeds.
- **Offline first:** all non-remote functions remain usable without connectivity.
- **Never lose a lead:** persist locally before network delivery; secondary integration failures cannot discard the record.
- **One-handed operation:** primary controls remain thumb-reachable and meet the specified minimum target size.
- **Manual fallback:** card extraction and transcription failures degrade to editable manual input.
- **User corrections win:** automated extraction never overwrites a field corrected manually.
- **Server-held secrets:** provider access and credentials never reside in Flutter.
- **Traceable delivery:** folio, synchronization status, and email statuses make processing observable.

## Requirement Scope

This product specification summarizes RF-01 through RF-34, RNF-01 through RNF-08, and RC-01 through RC-05. Domain specifications provide the testable detail.
