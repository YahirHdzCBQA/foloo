# Privacy and Compliance Specification

## Purpose

Constrain lead handling and follow-up to the stated Mexican privacy, access, retention, notice, and opt-out obligations.

## Related Requirements

- RC-01
- RC-02
- RC-03
- RC-04
- RC-05
- RNF-07
- RF-30

## User Behavior

The capture person gives the verbal notice required by RC-05. The lead receives the contact reason, privacy-notice link, and opt-out mechanism. Authorized marketing and sales personnel access sheet/media resources.

## Business Rules

- Comply with the Mexican LFPDPPP.
- Explain that contact occurs because the person provided a card at the named event.
- Include and respect a clear opt-out in the sheet and future sends.
- Legal or Dirección defines the card-photo/audio retention period; those files are deleted when it expires.
- Sheet and audio-folder access is limited to marketing and sales.
- Audio URLs require authenticated access and are not bearer-public links.
- Lead data always travels over HTTPS.

## Data Requirements

Privacy-notice URL, event/contact context, opt-out state and audit-relevant association, media creation/retention timestamps, access policy, and authorized groups. The source model does not define dedicated opt-out or retention fields; conceptual additions await a decision/spec refinement.

## States

Opt-out and retention lifecycle states are not defined. **Proposed:** active/opted-out for communication eligibility and retained/due-for-deletion/deleted for media, subject to Legal and architecture approval.

## Validation

Email content and protected link access must satisfy RC-01, RC-02, and RC-04. Media deletion must apply the approved retention period once defined.

## Failure / Degraded Behavior

Failure of email or secondary integration does not delete or lose a newly captured lead. Failure to enforce privacy/access/opt-out cannot be silently treated as success; exact operational escalation is unresolved.

## Acceptance Criteria

- Lead email identifies the event-based reason, links the company privacy notice, and provides opt-out.
- A recorded opt-out is represented in the sheet and honored in later applicable sends.
- Only marketing/sales-authenticated users can access the sheet and audio resources.
- Media is deleted when the Legal/Dirección-approved period expires.
- The capture workflow documents RC-05 as an operator obligation.

## Out of Scope

Legal interpretation beyond the explicit requirements, a self-invented retention period, and opt-out propagation beyond the scope ultimately approved.
