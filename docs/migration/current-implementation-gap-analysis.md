# Current Flutter Implementation Gap Analysis

## Scope and method

The audit covers `app/lib/`, `app/test/`, native permissions/configuration,
themes and assets as of branch `feature/FL-007/specifications-realignment`.
No functional code was changed. Status meanings:

- **ALIGNED**: current behavior materially matches the current requirement.
- **PARTIALLY ALIGNED**: reusable implementation exists but required behavior
  is incomplete or demo-only.
- **OUTDATED**: built for the superseded product and needs replacement.
- **CONFLICT**: behavior violates current authority or edition scope.
- **NOT IMPLEMENTED**: no functional implementation exists.
- **IMPLEMENTED BUT NOW OUT OF SCOPE**: code/UI exists where current Basic says
  it must not appear.

Recommendations are planning labels only: **KEEP**, **ADAPT**, **REMOVE**,
**MOVE TO PRO**, **REQUIRES DECISION**.

## Functional audit

| Area | Status | Evidence in current code | Current gap | Recommendation / trace |
|---|---|---|---|---|
| Login | **PARTIALLY ALIGNED** | Branded user/password form, validation and password visibility | Any valid email/password opens a local gate; no backend auth, session persistence or workspace resolution | **ADAPT** for `AUT-01`–`AUT-03`; architecture depends on auth/backend decision |
| Profile | **NOT IMPLEMENTED** | Hard-coded `DemoEventData` and initials | No first-use profile, photo, persistence or editing | **BUILD** after auth/local persistence; `AUT-04`–`AUT-06` |
| Logout/session safety | **CONFLICT** | Logout clears `_sessionLeads` and deletes session audio | Pending leads must survive logout and reappear for the same user | **ADAPT**; `AUT-07`, `AUT-08`, Article 2; layout also needs `RQ-02` |
| Navigation | **PARTIALLY ALIGNED** | Right drawer, scrim close, Home/Registros/Evento, appearance toggle | Destination must be Mis eventos, counters/profile/plan differ, preference is not persisted, system-back behavior unverified | **KEEP** drawer mechanism; **ADAPT** `NAV-01`–`NAV-07` |
| Capture layout | **PARTIALLY ALIGNED** | Four sections in one scroll with fixed header and dock | Missing step 00 origin/event selector; progress copy is four abbreviated tabs rather than current step/title; CTA says “Guardar y enviar” | **KEEP** scroll/dock structure; **ADAPT** `CAP-01`–`CAP-04`, `CAP-13`, `CAP-14` |
| Origin: event/direct | **NOT IMPLEMENTED** | One hard-coded demo event | No segmented origin, event selector, direct base or persistence between captures | **BUILD** after events; `CAP-01`–`CAP-04` |
| Card camera/gallery | **PARTIALLY ALIGNED** | Rear camera/gallery, preview, replace/remove and 1568 bounds | Copy/states differ; original/link not durable; JPEG contract not independently verified | **ADAPT** `OCR-01`, `OCR-02`, `OCR-07`–`OCR-09` |
| OCR | **CONFLICT** for production | On-device ML Kit plus Flutter heuristics | Current architecture requires Foloo backend structured extraction; rotated/shadow accuracy not proven; wrong failure copy | **KEEP only as historical prototype**; **REPLACE** for `OCR-03`–`OCR-06`, blocked by `D-05` |
| Lead fields | **PARTIALLY ALIGNED** | Six visible editable controls and suitable email/phone keyboards | UI recombines apellido into name; current model requires separate `apellido`; validation lacks required icon+text treatment/scroll to first error | **ADAPT** `CAP-05`–`CAP-08`, `CAP-16` |
| Type/relationship | **CONFLICT** | Partner and Cliente potencial | Basic requires exactly Proveedor/Partner/Cliente with icon, word and check | **ADAPT** `CAP-09`, `CAP-10` |
| Interest | **PARTIALLY ALIGNED** | Low/medium/high with medium default and record rail | Uses non-token status colors and selection effects outside closed design system | **KEEP behavior**, **ADAPT visual** `CAP-11`, `CAP-12` |
| Next step | **IMPLEMENTED BUT NOW OUT OF SCOPE** | Mandatory dropdown and model enum | Not in current Basic model; `D-02` remains blocking confirmation | **REMOVE from Basic after D-02**; do not move to Pro without a current Pro ID |
| Voice recording | **PARTIALLY ALIGNED** | Real local record/stop/timer, permission fallback, playback/delete/rerecord | Temporary files are session-only; waveform is static state art; no durable offline queue/upload; some targets are legacy 44 px | **KEEP service/state**, **ADAPT** `VOZ-01`–`VOZ-06`, `SYN-01`; media policy `D-11`/`RQ-07` |
| Basic transcription boundary | **CONFLICT** | UI says transcription “requires backend and is not available”; TODO describes future transcription | Basic must not offer, imply or reserve transcription | **REMOVE from Basic**; any future implementation **MOVE TO PRO** under `TRA-*` and `DP-05` |
| Local save | **CONFLICT** | In-memory list only; process/logout clears it | Violates durable local-first and no-loss rules | **REPLACE**, after persistence/sync ADR; `CAP-15`, `SYN-01`, `AUT-08`, Article 2 |
| Folio | **OUTDATED** | Hard-coded event prefix plus in-memory sequence | No direct folio, daily/event rules, concurrency or durable idempotency | **REQUIRES DECISION** `D-03` before implementation |
| Confirmation | **CONFLICT** | Demo sheet + lead email + Admin rows; manual return only | Basic must have no email UI, truthful online/offline outcome, visible 3-second auto-return and retained origin | **ADAPT/REMOVE Basic email rows**; `CAP-17`–`CAP-19`; blocked by `D-06` |
| Events | **OUTDATED** | Read-only hard-coded “Evento” card with Admin email | Basic requires create/list/edit/logical delete, active event and counters; Admin email is Pro concern | **REPLACE** with Mis eventos, `EVT-01`–`EVT-11`; decisions `D-03`, `D-10` |
| Records list | **PARTIALLY ALIGNED** | Session list, count/status, interest rail and local audio button | Missing event selector, search, all four type filters, filtered count, durable/offline records | **KEEP card/audio foundations**, **ADAPT** `REG-01`–`REG-05` |
| Connection detail | **NOT IMPLEMENTED** | None | Required read-only contact/media/note/record view | **BUILD** `REG-06`–`REG-08`; editing boundary blocked by `D-04` |
| Export | **NOT IMPLEMENTED** | CSV button only shows unavailable snackbar | XLS default, CSV BOM, offline inclusion and share sheet absent | **BUILD** `REG-09`–`REG-12`; exact columns need `RQ-05` |
| Synchronization | **NOT IMPLEMENTED** | Static “Por subir”, offline header and no-op button | No persistence, connectivity state, queue, retry, idempotency or resume | **BUILD** after persistence/sync ADR and `D-03`/`D-05`; `SYN-01`–`SYN-08` |
| Spreadsheet/files | **NOT IMPLEMENTED** | Demo status/TODO only | No backend, protected media or Basic sheet contract | **BUILD backend/mobile boundary** after `D-05`, `D-10`, `D-11`; `SAL-01`–`SAL-04`, `SAL-11`, `SAL-12` |
| Appearance | **PARTIALLY ALIGNED** | Light/dark `ThemeData` and local toggle | Preference is not persisted; dark style is hard-coded in parallel; token mapping/contrast not proven | **ADAPT** `NAV-04`, `NAV-05`, `RNF-05`, `RNF-09` |
| Basic email absence | **CONFLICT** | Confirmation and Evento display lead/Admin email claims, albeit marked demo | Acceptance requires no control/text/screen offering automatic email | **REMOVE from Basic**; email work **MOVE TO PRO** only |
| Pro capability boundary | **NOT IMPLEMENTED** | No account plan/capability model | Same binary cannot yet separate Basic/Pro | **BUILD later** under `RNF-18`, `EP-10`; contract requires `DP-08` |
| Pro content/templates/email/transcription | **NOT IMPLEMENTED** | Only legacy demo email/transcription text | No valid Pro capability exists; legacy hints are leaks, not partial Pro | **REMOVE leaks now; BUILD as Pro phases only after blockers** |

## Visual-system audit

The cited mockup HTML and `_ds/foloo-design-system/` assets were not present in
the supplied package, so this is a textual Constitution audit rather than a
pixel comparison.

| Rule | Current state | Status / action |
|---|---|---|
| Four base colors, derived tokens only | Theme hard-codes paper, line, success, warning, error, pending and separate dark values without a token derivation source | **CONFLICT** — establish canonical tokens before screen work |
| One lime element per screen; light primary action is ink | Global elevated buttons use lime and screens add lime selections/statuses | **CONFLICT** — refactor semantic roles |
| Nexa/Poppins/DM Sans local assets | Theme uses Arial; brand font roles are absent | **NOT IMPLEMENTED** — blocked by font assets/license `D-12` |
| Radius scale and flat surfaces | Many radii are close but ad hoc; selected controls add hard offset shadows | **PARTIALLY ALIGNED** — centralize exact scale; remove unapproved effects |
| 48 dp touch minimum | Several themes/components declare 44 px minima; status pills are 38 px but may be non-interactive | **CONFLICT** for interactive 44 px controls — raise to 48 dp |
| Fixed 56 dp primary dock | Capture and other screens use fixed bottom actions around 56 px | **ALIGNED foundation**, verify exact content box |
| Destructive actions outside lower third | Logout is anchored at drawer bottom | **CONFLICT/REQUIRES DECISION** `RQ-02` |
| Motion 100/150/200, hard max 250; reduced = 1 ms | Durations 160/180 exist and reduced mode uses zero | **PARTIALLY ALIGNED** — replace with shared tokens and specified 1 ms mapping |
| Sentence case; ALL CAPS eyebrow only | Many buttons, statuses, section titles and copy are uppercase | **CONFLICT** — copy audit across all screens |
| No emoji/unicode icons | Evento badge includes `🔒` | **CONFLICT** — use line icon plus text |
| State uses icon + word + color | Several status rows comply; errors and selected type do not consistently include an icon/check | **PARTIALLY ALIGNED** — componentize `RNF-13` states |
| Accessible focus/contrast | Material semantics exist in places; focus halo, WCAG evidence and all icon labels are incomplete | **PARTIALLY ALIGNED** — add tokenized focus and accessibility tests |
| Vertical only | No orientation lock is evident in Dart/native audit | **NOT IMPLEMENTED/UNVERIFIED** — `RNF-04` |
| Spanish/English first class | Only hard-coded Spanish strings; no localization structure | **NOT IMPLEMENTED** relative to Constitution Article 8 |

## Existing feature disposition through FL-006

| Existing increment | Disposition |
|---|---|
| FL-001 SDD foundation | **ADAPT** — preserved under legacy; current package now governs. |
| Initial lead capture | **ADAPT** — keep continuous-scroll mechanics and controllers, replace model/catalog/copy/origin/save semantics. |
| FL-003 login/navigation | **ADAPT** — keep visual/form/drawer foundations; replace demo authentication and destinations. |
| FL-004 records/event | **ADAPT records**, **REMOVE/REPLACE Evento** with current Mis eventos; remove Basic email concepts. |
| FL-005 ML Kit | **KEEP only as prototype evidence**, then replace with server extraction for production. |
| FL-006 Voice Note | **KEEP/ADAPT** local recorder/player; make durable and remove Basic transcription implication. |

## Overall distance

The prototype is useful UI scaffolding, not a near-complete Basic build. The
strongest reusable pieces are the continuous capture layout, image acquisition,
editable controls, local Voice Note lifecycle, drawer mechanics, session record
cards and widget tests. The largest missing foundations are durable local
persistence, authentication/profile, event/origin domain, sync/idempotency,
server OCR/Sheets/files, current Basic model, detail/export and the closed
design system. Pro should not begin until Basic and the capability boundary are
stable.
