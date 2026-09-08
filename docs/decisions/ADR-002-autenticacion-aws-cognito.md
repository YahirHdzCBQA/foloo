# ADR-002 — Frontera de autenticación con AWS Cognito

- Estado: **Aceptado**
- Fecha: 2026-08-31; actualizada por FL-013B el 2026-09-04
- Alcance: Foloo V1 unificado
- Trazas: AUT-01–AUT-13, SYN-03, SYN-09 y E-01

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
- Se permite self sign-up únicamente con email/password y confirmación por
  código de email. Reenvío y errores se traducen a errores de dominio ES/EN.
- MFA de usuario y passwordless están deshabilitados. Account recovery está
  habilitado en el proveedor, pero la UI de recuperación se difiere.
- La identidad de autenticación (`AuthUser.id`, Cognito `sub`) es distinta
  del perfil comercial Foloo almacenado en Drift.
- Offline y autenticación son estados independientes. Perder conectividad no
  invalida una sesión restaurada.
- Trial y suscripción no se infieren de FakeAuth ni de Cognito; pertenecen al
  backend Foloo futuro bajo `MON-*`.

## Alternativas consideradas

- Autenticación directa en widgets: rechazada porque dispersa sesión y obliga a
  rehacer pantallas al integrar Cognito.
- Guardar Access Key, Secret Access Key, Client Secret o tokens en Drift:
  rechazado; Amplify administra la sesión en almacenamiento seguro de plataforma.
- Usar correo como identificador técnico: rechazado; el identificador estable
  será Cognito `sub`.
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
