# Configuración externa: Sign in with Apple y Microsoft (ADR-009)

Nada de esto vive en Git ni en CDK. Cognito se referencia, no se crea. Antes de
cualquier cambio: `aws cognito-idp describe-user-pool` y confirmar que no se
recrea el pool. Ningún secreto se pega en comandos ni en chats.

## Sign in with Apple (AUT-22)

1. Apple Developer → Identifiers → **Services ID** (p. ej. `com.foloo.signin`)
   con *Sign in with Apple* habilitado.
2. *Return URL*: `https://<dominio-hosted-ui-de-cognito>/oauth2/idpresponse`.
3. Keys → crear clave con *Sign in with Apple* y descargar la `.p8` (una sola
   vez). Anotar Team ID y Key ID.
4. Cognito → User pool → *Sign-in experience* → Federated identity providers →
   **Apple**: Services ID, Team ID, Key ID y contenido de la `.p8`. Scopes
   `email name`.
5. Mapear atributos: `email` → email. Apple solo manda nombre/correo en el
   primer inicio; correo puede ser un relay privado.
6. App client: habilitar el proveedor *SignInWithApple* y mantener los
   callback/sign-out URLs que ya usa la app.
7. Validar guards, login, restore, logout y ownership en DEV; solo después
   compilar el build autorizado con `--dart-define=FOLOO_APPLE_SIGNIN=true`.
8. Al borrar la cuenta hay que revocar el token de Apple (D-13).

## Microsoft (AUT-23, Proposed)

**Estado 2026-10-23:** el proveedor OIDC `Microsoft` ya existe en el pool
(creado 2026-09-23) con un tenant de Entra External ID
(`https://7001d501-…ciamlogin.com/…/v2.0`), scopes `openid email profile`. No
recrearlo ni cambiar su issuer; los pasos de abajo sólo aplican si se arma de
cero. Falta confirmar que el app client móvil lo tenga habilitado y probarlo.

1. Entra → App registrations → nueva app, *Accounts in any organizational
   directory and personal Microsoft accounts* sólo si se usa un intermediario;
   para el alcance aprobado (cuentas personales) elegir **Personal Microsoft
   accounts only**.
2. Redirect URI (Web): `https://<dominio-hosted-ui>/oauth2/idpresponse`.
3. Cognito → proveedor **OIDC** llamado exactamente `Microsoft` (la app lo
   usa con ese nombre). Issuer fijo del tenant de cuentas personales:
   `https://login.microsoftonline.com/9188040d-6c67-4c5b-b112-36a304b66dad/v2.0`.
   No usar `common`: su `iss` cambia por tenant y Cognito lo rechaza.
4. Scopes `openid email profile`. Probar en DEV con una cuenta personal antes de
   activar `--dart-define=FOLOO_MICROSOFT_SIGNIN=true`.

Ambos flags son independientes y `false` por defecto. Un build de tiendas no
debe habilitarlos solo porque el código o el proveedor externo existan.

La configuración de Stripe (ADR-008) está en `backend/README.md`.
