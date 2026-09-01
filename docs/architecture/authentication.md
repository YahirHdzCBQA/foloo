# Authentication and Local Ownership

FL-013A establishes the shared Basic/Pro authentication boundary required by
`AUT-01`, `AUT-02`, `AUT-04`–`AUT-08`, `RNF-02`, `RNF-06` and `RNF-18`.
ADR-002 selects AWS Cognito for production but the real adapter remains blocked
until AWS DEV exists.

## Runtime boundary

```text
Login / bootstrap / logout
          ↓
     AuthRepository
          ↓
      AuthService
          ↓
DevelopmentAuthService (FL-013A only)
CognitoAuthService     (FL-013B)
```

`AuthRepository` is the single authentication state source and exposes
initializing, authenticated, unauthenticated and error. Connectivity remains a
separate advisory state; offline never means logged out.

The authentication identity is `AuthUser(id, username)`. Its `id` is the
ownership key and will be Cognito `sub`. It is not an email address and is not
the Foloo profile. Name, company and optional profile imagery are business
profile data owned by that identity in local persistence.

## FL-013A development adapter

`DevelopmentAuthService` is explicitly not production authentication. It does
not call Cognito, validate against a remote directory or retain passwords. It
keeps a local username-to-`fake-user-*` assignment so repeated development
logins resolve the same technical identity, and stores only the active session
identity for bootstrap tests.

The demo plan selector remains independent. Authentication never selects Basic
or Pro.

## Local ownership

Drift schema v2 adds nullable `ownerUserId` to profiles, events and leads.
Repositories require the active user id for every read and mutation. Lead media
inherits ownership through its required lead foreign key. User preferences use
a new `(ownerUserId, key)` composite primary key.

Rows migrated from schema v1 retain `NULL` ownership. They are preserved but no
authenticated user can query them. Assigning historical data is an explicit
pending product migration; FL-013A does not guess.

## FL-013B replacement checklist

When AWS DEV is available:

1. Receive the real AWS Region, Cognito User Pool ID and Cognito App Client ID.
2. Configure a public mobile App Client without Client Secret.
3. Implement `CognitoAuthService` for email/password login, restore session,
   mapped errors and logout.
4. Map Cognito `sub` to `AuthUser.id`; never use email as ownership identity.
5. Inject the Cognito adapter into the existing `AuthRepository`.
6. Verify existing ownership, profile, event, lead, navigation and offline tests
   unchanged, then add Cognito integration tests against AWS DEV.

FL-013B must not add sign-up, forgot password, MFA or social providers unless a
later approved requirement changes the V1 administrative provisioning flow.
