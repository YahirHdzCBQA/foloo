# Reconciliation Issues Requiring Clarification

These issues were found while incorporating the official Basic/Pro package.
They are not approved decisions and do not modify the source package. Work on
the affected branch must follow Constitution/matrix precedence and pause where
the unresolved detail changes implementation.

| ID | Question | Impact | Authority meanwhile |
|---|---|---|---|
| `RQ-01` | Does Pro append five or six Lead columns? The delta lists six changed fields while twice stating five. | Pro sheet schema and Basic-to-Pro migration | Do not finalize Pro schema; preserve Basic order (`SAL-12`). |
| `RQ-02` | How can logout be “at the bottom” (`AUT-07`) without placing a destructive action in the lower third (Article 7)? | Drawer layout and ergonomic acceptance | Constitution wins; request Design clarification. |
| `RQ-03` | Are there 12 or 13 Basic acceptance criteria? Basic enumerates 13; Pro references 12. | Acceptance reporting/numbering | Retain all 13 Basic criteria. |
| `RQ-04` | Is Marketing approval in `D-01` still pending despite the matrix’s definitive edition split? | Sign-off and `RC-03` implications | No Basic transcription; Pro only under `TRA-*`; do not mark `D-01` resolved. |
| `RQ-05` | What exact export columns are included in XLS/CSV? | `REG-09`–`REG-12` artifact contract | Do not infer that export equals the sheet column set. |
| `RQ-06` | What does Pro do for a valid phone-only lead when automatic lead email is required? | `SAL-05`, validation and status | Do not invent recipient/failure behavior. |
| `RQ-07` | What production audio container, codec and maximum duration are approved? | `VOZ-*`, upload and cross-platform acceptance | Existing AAC/M4A remains prototype-only. |
| `RQ-08` | Where are the cited Basic/Pro mockup HTML files and `_ds/foloo-design-system/` token sources? | Pixel/token-level UI acceptance | Use Constitution textual rules only; do not invent missing tokens. |
