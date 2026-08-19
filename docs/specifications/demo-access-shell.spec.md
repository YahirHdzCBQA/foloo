# Demo Access Shell Specification

## Status and Boundary

This specification records a user-approved frontend prototype behavior. It
does not add user authentication or roles to Foloo V1. Production
authentication remains out of scope in `product-spec.md`.

The shell is a local visual gate around the existing lead-capture prototype.
It creates no identity, permission, credential, token, persistence, or backend
contract.

## Related Requirements

- RNF-03: the shell remains inside the single Flutter codebase.
- RNF-04: primary controls use one-hand-friendly placement and touch targets.
- RNF-05: fields have visible labels/focus/error states and remain usable with
  the keyboard open.
- RNF-06: no API keys, service credentials, or provider calls are added to
  Flutter.

No RF or RC is added or changed. In particular, the displayed demo profile
must not be interpreted as RF-11 capture-person configuration.

## Prototype Behavior

1. The app opens on a branded login screen.
2. The login form contains a user/email field and a password field.
3. The user/email value is validated locally as a syntactically plausible
   email and the password must contain at least one non-whitespace character.
4. Any values that pass those checks enter the existing lead-capture screen;
   no credential verification occurs.
5. The password is obscured initially and a visible control toggles its
   visibility.
6. The lead-capture screen exposes a right-side menu with the current capture
   destination and a logout action. It must not expose unimplemented modules.
7. Logout removes the lead-capture widget subtree, discards its in-memory
   draft, and returns to a clean login screen.

## Visual Direction

- Use the supplied Foloo light-mode logo assets on white.
- Use brand ink `#1F1F1F`, lime `#C9FA00`, and gray `#888888` on the login and
  menu integration only.
- Preserve the established lead-capture visual design. The only permitted
  change there is the minimal menu trigger and drawer integration.

## Acceptance Criteria

- Empty or malformed login input presents clear inline errors.
- A valid email and non-empty password open lead capture locally.
- The password visibility control works without clearing the value.
- The menu opens and closes without changing the capture form layout.
- Logout returns to login and a later demo login starts with an empty draft.
- No authentication package, network request, secure storage, or production
  session state is introduced.

## Out of Scope

Real authentication, registration, password recovery, identity persistence,
roles, permissions, token handling, backend integration, and production user
profiles.
