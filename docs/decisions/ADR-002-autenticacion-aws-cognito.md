# ADR-002 — Frontera de autenticación con AWS Cognito

- Estado: **Aceptado**
- Fecha: 2026-08-31; actualizada por FL-013B el 2026-09-04 y FL-019.5 el 2026-09-25
- Alcance: Foloo V1 unificado
- Trazas: AUT-01–AUT-17, SYN-03, SYN-09 y E-01

## Contexto

Foloo necesita una identidad estable para restaurar sesión y aislar perfil,
eventos, leads y preferencias locales. FL-013A estableció esa frontera antes de
que existiera AWS DEV. FL-013B recibe un User Pool DEV real, público para la app
móvil y sin Client Secret, y sustituye el adaptador de runtime.

La decisión de producto y arquitectura de FL-013 establece AWS Cognito como el
proveedor real. FL-013A debe permitir continuar el desarrollo local sin
convertir credenciales demo en autenticación de producción.

## Decisión

- La UI consume un único `AuthRepository`, que centraliza los estados
  `initializing`, `authenticated`, `unauthenticated` y `error`.
- `AuthRepository` delega en la abstracción `AuthService`. Login, bootstrap y
  logout no conocen Cognito ni guardan contraseñas.
- FL-013A usa `DevelopmentAuthService`, un adaptador local explícitamente no
  productivo. Emite identificadores `fake-user-*` independientes del correo y
  conserva solo la identidad/sesión temporal; nunca conserva la contraseña.
- FL-013B implementa `CognitoAuthService` con `amplify_flutter` y
  `amplify_auth_cognito` y lo inyecta detrás de la misma frontera. El App Client
  móvil es público y no tiene Client Secret.
- Runtime normal usa Cognito DEV (`us-east-1`, User Pool
  `us-east-1_QVm3dWe4O`, App Client `6jong3atp2crqcsde6g215ant8`). La
  configuración está centralizada y deja PROD sin valores inventados.
- Se permite self sign-up con email/password y confirmación por código. FL-019.5
  añade Google exclusivamente mediante federación/Hosted UI Cognito. El alta
  email/password admite cualquier dirección válida aceptada por Cognito y crea
  una contraseña Foloo independiente del proveedor del buzón. El OAuth de envío
  de ADR-006 nunca se acepta como sesión Foloo.
- Microsoft Sign-In/OIDC queda temporalmente fuera del alcance de esta versión.
  La integración presentó conflictos durante el flujo de federación con
  Microsoft Entra External ID y se retomará en una iteración posterior.
- Para esta versión, los métodos de autenticación soportados son Google Sign-In
  y registro/inicio de sesión mediante correo electrónico y contraseña. Login y
  Crear cuenta no presentan Microsoft, pero se conserva su código reutilizable
  fuera de la ruta disponible.
- La investigación confirmó que Microsoft `/common` publica un issuer
  `{tenantid}` y los tokens reales usan el tenant de origen, mientras Cognito
  rechazó el ID token por issuer. Cambiar endpoints manualmente no altera esa
  validación. No se selecciona ni implementa todavía External ID/B2B, un broker
  intermedio o autenticación Microsoft directa.
- MFA de usuario y passwordless están deshabilitados. Account recovery está
  habilitado en el proveedor, pero la UI de recuperación se difiere.
- La identidad de autenticación (`AuthUser.id`, Cognito `sub`) es distinta
  del perfil comercial Foloo almacenado en Drift.
- Offline y autenticación son estados independientes. Perder conectividad no
  invalida una sesión restaurada.
- Trial y suscripción no se infieren de FakeAuth ni de Cognito; pertenecen al
  backend Foloo futuro bajo `MON-*`.
- Una identidad federada ya confirmada omite el código manual, pero sigue usando
  su Cognito `sub`; tampoco autoriza automáticamente una cuenta sender.

## Alternativas consideradas

- Autenticación directa en widgets: rechazada porque dispersa sesión y obliga a
  rehacer pantallas al integrar Cognito.
- Guardar Access Key, Secret Access Key, Client Secret o tokens en Drift:
  rechazado; Amplify administra la sesión en almacenamiento seguro de plataforma.
- Usar correo como identificador técnico: rechazado; el identificador estable
  será Cognito `sub`.
- Federar Cognito directamente con Microsoft `/common`: rechazado porque
  Cognito exige igualdad del issuer y no implementa la sustitución segura
  `{tenantid}` + validación `tid` requerida por Microsoft para multitenant.
- Aceptar JWT Microsoft en API Gateway o validarlos en cada endpoint: rechazado;
  crearía dos contratos de autorización y ownership.
- Implementar un issuer/exchange propio: rechazado para esta versión por ampliar
  innecesariamente la superficie criptográfica y operativa.
- Implementar ahora Entra External ID/B2B: diferido; requiere una decisión y
  validación posterior separada, no implícita dentro de FL-019.5.
- Detener FL-013 completa: rechazado; ownership y persistencia pueden probarse
  con un adaptador intercambiable.

## Consecuencias

- La sesión y los datos locales pueden probarse con varios usuarios sin AWS.
- FakeAuth permanece exclusivamente para tests y desarrollo controlado; no es
  la fuente de verdad del runtime normal.
- Amplify conserva los tokens fuera de Drift. Logout elimina estado de sesión,
  no perfil, eventos, leads ni medios.
- Las filas heredadas con owner nulo o `fake-user-*` se preservan y no se
  reasignan silenciosamente. Su migración requiere una futura decisión.
- No se agregan secretos, credenciales IAM, backend, Terraform, sincronización
  ni determinación comercial mediante Cognito.
- Microsoft Auth no es una ruta soportada en esta versión. Una futura
  reactivación debe resolver issuer, continuidad de `sub` y migración sin
  reasignar ownership ni fusionar cuentas silenciosamente.

## Configuración externa vigente y evidencia pendiente

- Google está habilitado y validado en el App Client Cognito. La configuración
  OIDC Microsoft existente no constituye una ruta soportada por esta versión y
  no se modifica como parte de esta decisión.
- Managed Login usa Authorization Code Grant, scopes `openid email profile`,
  callback `foloo://callback/` y sign-out `foloo://signout/`. Amplify conserva
  `state`, nonce, PKCE, intercambio del código y almacenamiento seguro.
- El código reusable conserva el nombre externo `Microsoft`; ningún secreto
  OIDC vive en Flutter, Git, logs o SDD.
- Google y email/password conservan login, restore, logout, confirmación y
  ownership por `sub`. Microsoft queda pendiente de una iteración futura.

## Referencias normativas

- AWS Cognito, flujo OIDC: compara `iss` con el issuer configurado antes de
  emitir tokens del User Pool.
  <https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-oidc-flow.html>
- Microsoft, validación multitenant: `/common` publica `{tenantid}` y exige
  sustitución y coherencia exacta `iss`/`tid`.
  <https://learn.microsoft.com/en-us/entra/identity-platform/access-tokens>
- Microsoft Entra External ID/B2B: self-service sign-up admite por defecto
  cuentas Entra y puede incluir Microsoft Account.
  <https://learn.microsoft.com/en-us/entra/external-id/self-service-sign-up-user-flow>
