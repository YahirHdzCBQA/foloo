# Authentication and Local Ownership

FL-013A established the shared Basic/Pro boundary. FL-013B connects the normal
runtime to AWS Cognito for `AUT-01`, `AUT-02`, `AUT-04`–`AUT-13`, `RNF-02`,
`RNF-06` and `RNF-18`. ADR-002 records the provider and configuration decision.

## Runtime boundary

```text
Sign-up / confirmation / login / bootstrap / logout
          ↓
     AuthRepository
          ↓
      AuthService
          ↓
DevelopmentAuthService (tests / controlled development only)
CognitoAuthService     (normal runtime)
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

## FL-013B Cognito adapter

The app configures only the public mobile identifiers supplied for DEV:

- Region `us-east-1`
- User Pool `us-east-1_QVm3dWe4O`
- App Client `6jong3atp2crqcsde6g215ant8`, without Client Secret

`CognitoAuthService` provides self sign-up with email/password, email-code
confirmation/resend, login, restore and logout. AWS exceptions are mapped to
domain failures before reaching UI. `sub` becomes `AuthUser.id`; email remains a
display/login attribute. Amplify owns secure token storage; Drift never stores
tokens.

After authentication the existing profile repository looks up the Foloo profile
by `sub`. Missing required profile fields route to profile setup; complete
profiles route to Home. Account recovery is provider-enabled but UI-deferred.
MFA, passwordless and social login remain outside this boundary.

Deferred password recovery has its own `AccountRecoveryService` capability.
This keeps the current `AuthService` and `AuthRepository` lifecycle stable until
a traced recovery UI is approved; FL-013B does not call the Cognito reset APIs.

Fake/pre-auth rows remain untouched. A future migration needs an approved rule;
authentication never claims or rewrites them automatically.
