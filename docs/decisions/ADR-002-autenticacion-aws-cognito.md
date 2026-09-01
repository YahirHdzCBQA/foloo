# ADR-002 — Frontera de autenticación con AWS Cognito

- Estado: **Aceptado**
- Fecha: 2026-08-31
- Alcance: compartido Basic/Pro
- Trazas: AUT-01, AUT-02, AUT-04–AUT-08, RNF-02, RNF-06, RNF-18 y E-01

## Contexto

Foloo necesita una identidad estable para restaurar sesión y aislar perfil,
eventos, leads y preferencias locales. La cuenta AWS y el ambiente DEV todavía
no existen, por lo que no están disponibles Region, User Pool ID ni App Client
ID. La integración real no puede configurarse sin inventar infraestructura o
credenciales.

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
- FL-013B implementará `CognitoAuthService` y lo inyectará detrás de la misma
  frontera. El App Client móvil será público y no tendrá Client Secret.
- La identidad de autenticación (`AuthUser.id`, futuro Cognito `sub`) es distinta
  del perfil comercial Foloo almacenado en Drift.
- Offline y autenticación son estados independientes. Perder conectividad no
  invalida una sesión restaurada.
- El plan/capabilities no se infiere de FakeAuth ni de Cognito; sigue separado
  hasta el contrato previsto por RNF-18/FL-020.

## Alternativas consideradas

- Autenticación directa en widgets: rechazada porque dispersa sesión y obliga a
  rehacer pantallas al integrar Cognito.
- Instalar/configurar Cognito con identificadores ficticios: rechazada porque no
  existe AWS DEV y violaría RNF-06.
- Usar correo como identificador técnico: rechazado; el identificador estable
  será Cognito `sub`.
- Detener FL-013 completa: rechazado; ownership y persistencia pueden probarse
  con un adaptador intercambiable.

## Consecuencias

- La sesión y los datos locales pueden probarse con varios usuarios sin AWS.
- FakeAuth no valida credenciales contra un directorio real y no es apto para
  producción; su presencia debe impedir considerar FL-013 completa.
- FL-013B requiere AWS Region, Cognito User Pool ID y Cognito App Client ID.
  Sustituirá solo el adaptador y verificará restore session, login, errores y
  logout reales.
- No se agregan SDKs AWS, secretos, backend, Terraform ni sincronización en
  FL-013A.
