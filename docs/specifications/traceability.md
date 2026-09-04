# Current Requirements Traceability

This index routes current identifiers to their authoritative specification and
acceptance scenarios. It describes specification coverage, not implementation
completion. `04-matriz-de-capacidades.md` always governs edition membership.

## Basic and shared families

| Current IDs | Area | Authoritative definition | Acceptance coverage | Decision dependencies |
|---|---|---|---|---|
| `AUT-01`–`AUT-09` | Login, profile and session | `current/01-especificacion.md` §6.1 | `E-01`, `E-11` | `D-09` |
| `EVT-01`–`EVT-13` | Event CRUD, active event and date grouping | §6.2 | `E-01`, `E-10` | `D-03`, `D-10` |
| `CAP-01`–`CAP-04` | Event/direct origin | §6.3 | `E-02` | `D-03`, `D-10` |
| `OCR-01`–`OCR-09` | Card capture and extraction | §6.4 | `E-03` | `D-05` |
| `CAP-05`–`CAP-08` | Lead data and validation | §6.5 | `E-03`, `E-04`, `E-06` | none explicit |
| `CAP-09`–`CAP-12` | Type and interest | §6.6 | `E-04`, `E-08` | `D-07` non-blocking |
| `VOZ-01`–`VOZ-07` | Basic voice and written note | §6.7 | `E-05` | `D-01`, `D-11` |
| `CAP-13`–`CAP-19` | Save and acknowledgement | §6.8 | `E-06` | `D-03`, `D-06` |
| `SYN-01`–`SYN-08` | Local persistence and sync | §6.9 | `E-07` | `D-03`, `D-05` |
| `SAL-01`–`SAL-04`, `SAL-11`–`SAL-12` | Basic sheet/file output | §6.10 | `E-06`, `E-07`, `E-12` | `D-03`, `D-05`, `D-10`, `D-11` |
| `REG-01`–`REG-12` | Records, detail and export | §6.11 | `E-08`, `E-09` | `D-04` |
| `NAV-01`–`NAV-07` | Navigation and appearance | §6.12 | `E-11`, `E-13` | none explicit |
| `RNF-01`–`RNF-13` | Basic non-functional requirements | §7 | `E-03`, `E-05`, `E-06`, `E-07`, `E-11`–`E-13` | `D-03`, `D-05`, `D-12`; `RNF-10` reserved |
| `RC-01`–`RC-07` | Basic privacy/compliance | §8 | `E-05`, `E-10`, `E-12` | `D-01`, `D-11`, `D-14` |

## Pro-only delta families

| Current IDs | Area | Authoritative definition | Acceptance coverage | Decision dependencies |
|---|---|---|---|---|
| `CON-01`–`CON-16` | Content library and attachments | `current/05-especificacion-pro.md` §4 | `EP-01`–`EP-03`, `EP-08`, `EP-09` | `DP-01`, `DP-02`, `DP-09`–`DP-11` |
| `SAL-05`–`SAL-10`, `SAL-13`–`SAL-15` | Automated email | §5 | `EP-03`, `EP-04`, `EP-06`, `EP-11` | `D-08`, `DP-02`–`DP-04`, `DP-12` |
| `PLT-01`–`PLT-10` | Email templates | §6 | `EP-04`, `EP-07`, `EP-11` | `DP-03` |
| `TRA-01`–`TRA-08` | Server-side transcription | §7 | `EP-05` | `DP-05`, `DP-06`; `TRA-08` explicitly blocked |
| `CAP-20`–`CAP-23` | Pro direct lead, acknowledgement and contact-reference images | §8 | `EP-03A`, `EP-06`, `EP-07` | `D-11`, `DP-07` |
| `REG-13` | Pro reference images in read-only detail | §8 | `EP-03A` | `D-04`, `D-11` |
| `NAV-08` | Pro menu destinations | §8 | `EP-10` | `DP-08` |
| `SYN-10`–`SYN-11` | Independent file/lead queues | §8 | `EP-08` | `DP-01`, `DP-12` |
| `RNF-14`–`RNF-18` | Pro non-functional delta | §9 | `EP-09`, `EP-10`, `EP-11` | `DP-02`, `DP-05`, `DP-08`, `DP-11`, `DP-12` |
| `RC-08`–`RC-12`; Pro variants of `RC-01`/`RC-02` | Pro compliance delta | §10 | `EP-03A`, `EP-04`, `EP-05`, `EP-11` | `D-11`, `DP-03`, `DP-12` |

## Demonstrable legacy crosswalk

Legacy IDs are historical context only. A blank or qualified mapping means the
new package intentionally changed or split the behavior.

| Legacy ID | Current ID(s) | Migration status |
|---|---|---|
| `RF-01`–`RF-07` | `OCR-01`–`OCR-08` | Clarified and expanded; `OCR-09` is new. |
| `RF-08` | `CAP-09`, `CAP-10` | Changed from two types to three. |
| `RF-09` | `CAP-11`, `CAP-12` | Preserved and expanded into record priority rail. |
| `RF-10` | none pending `D-02` | Removed from the current Basic model; do not implement. |
| `RF-11` | `AUT-05`, capture metadata in §3.2 | Split between profile and lead model. |
| `RF-12` | `CAP-17`, `D-03` | Preserved with unresolved concurrency semantics. |
| `RF-13` | `VOZ-01` | Preserved. |
| `RF-14` | `VOZ-07` (excluded Basic), `TRA-01`–`TRA-08` (Pro) | Moved to Pro and redefined as asynchronous server work. |
| `RF-15` | `VOZ-02`, `REG-05`, `REG-06` | Playback preserved and expanded into records/detail. |
| `RF-16` | `VOZ-03`, `SAL-03` | Preserved. |
| `RF-17` | `VOZ-05`, `VOZ-06` | Clarified as independent written fallback. |
| `RF-18`–`RF-21` | `CAP-15`, `SYN-01`–`SYN-08` | Expanded local-first lifecycle. |
| `RF-22` | `REG-01`–`REG-08` | Expanded with search, filters and read-only detail. |
| `RF-23` | `REG-09`–`REG-12` | Expanded from CSV to XLS/CSV and offline sharing. |
| `RF-24`–`RF-26` | `SAL-01`–`SAL-04`, `SAL-11`, `SAL-12` | Preserved with new Basic column contract. |
| `RF-27`–`RF-32` | `SAL-05`–`SAL-10`, `SAL-13`–`SAL-15`, `PLT-*` | Removed from Basic; Pro-only. |
| `RF-33`, `RF-34` | `AUT-02`, `AUT-04`–`AUT-06`, `EVT-*`, `NAV-04` | Replaced by explicit profile, events and persisted preferences. |
| legacy `RNF-01`–`RNF-08` | current `RNF-01`–`RNF-09`, `RNF-11`–`RNF-13`; Pro `RNF-15` | IDs are not numerically equivalent as a set; use the current text. |
| legacy `RC-01`–`RC-05` | current `RC-01`–`RC-07`; Pro `RC-08`–`RC-11` | Expanded and edition-specific; Basic privacy delivery remains blocked by `D-14`. |

No equivalence should be inferred beyond this table. Historical detail remains
under `docs/legacy/` and in the original PDF.
