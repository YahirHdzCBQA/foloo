# ADR-002 — Frontera de autenticación con AWS Cognito

- Estado: **Aceptado**
- Fecha: 2026-08-31; actualizada por FL-013B el 2026-09-04 y FL-019.5 el 2026-09-24
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
  añade Google y Microsoft exclusivamente mediante federación/Hosted UI
  Cognito; requiere proveedores, dominio y redirect URIs configurados
  externamente. El OAuth de envío de ADR-006 nunca se acepta como sesión Foloo.
- Google se federa directamente. Microsoft `/common` no se configura como OIDC
  directo de Cognito: su discovery publica un issuer `{tenantid}` y los tokens
  reales usan el tenant de origen, mientras Cognito compara `iss` con el issuer
  OIDC configurado. Cambiar solo endpoints no altera esa validación.
- Microsoft Auth usa un tenant recurso controlado de Microsoft Entra External
  ID/B2B con self-service sign-up. Ese servicio administrado autentica cuentas
  personales y cuentas Entra externas, crea su representación Guest y emite un
  token del tenant recurso. Cognito confía únicamente en ese issuer
  tenant-specific estable y sigue emitiendo la sesión canónica Foloo.
- El App Registration de este boundary es confidencial y tenant-specific. Su
  secret rotado vive solo en la configuración externa de Cognito; nunca en
  Flutter, Git, logs ni SDD. El tenant recurso conserva validación de firma,
  audiencia, issuer y políticas; Hosted UI conserva code flow, state, nonce y
  PKCE. No se implementa un token broker propio.
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
- Implementar un issuer/exchange propio: rechazado por ampliar innecesariamente
  la superficie criptográfica y operativa cuando Entra B2B puede normalizar el
  issuer de forma administrada.
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
- El cutover Microsoft requiere comprobar que usuarios Microsoft ya creados en
  Cognito conservan su `sub`. Si el `sub` externo cambia al convertirse en Guest,
  la configuración se detiene: no se reasigna ownership ni se fusionan cuentas
  sin una decisión de migración explícita.

## Configuración externa vigente y evidencia pendiente

- Google y el IdP OIDC `Microsoft` están habilitados en el App Client Cognito.
  Microsoft Entra External ID/B2B y su App Registration están configurados con
  issuer tenant-specific estable; Cognito continúa siendo el único broker e
  issuer aceptado por Foloo.
- Managed Login usa Authorization Code Grant, scopes `openid email profile`,
  callback `foloo://callback/` y sign-out `foloo://signout/`. Amplify conserva
  `state`, nonce, PKCE, intercambio del código y almacenamiento seguro.
- El nombre del IdP Cognito permanece exactamente `Microsoft`. Su secreto OIDC
  vive únicamente en Cognito; Flutter contiene solo identificadores públicos.
- Falta QA físico de la aplicación para login, restore, logout, cambio de cuenta
  y continuidad del `sub`; la configuración externa Microsoft ya no está
  pendiente.

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
