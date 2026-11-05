# Configuración externa: Sign in with Apple y Microsoft (ADR-009)

El User Pool y el App Client móvil continúan fuera del ownership del stack.
FL-022 deja preparada, sin desplegar, la ruta declarativa aceptada para crear
solo el IdP Apple contra el pool importado. El cliente móvil se
actualiza por una operación controlada que preserve su payload completo; no se
declara como un recurso nuevo de CloudFormation. Antes de cualquier cambio:
`aws cognito-idp describe-user-pool` y confirmar que no se recrea el pool.
Ningún secreto se pega en comandos, contextos CDK, documentación ni chats.

## Estado efectivo DEV (auditoría 2026-11-03)

- User Pool `us-east-1_QVm3dWe4O`; App Client móvil público y sin secret.
- El cliente móvil conserva `COGNITO` y `Google`, code grant, scopes
  `openid email profile`, `foloo://callback/` y `foloo://signout/`.
- Google continúa operativo. No existe un Identity Provider Apple.
- El secreto `foloo/dev/cognito/apple-private-key` existe en DEV y sus
  metadatos coinciden; el esquema JSON no se inspeccionó porque esta auditoría
  prohíbe consultar `SecretString`.
- El OIDC `Microsoft` existe, pero no está habilitado en el App Client móvil.
- Los Registration Guards están activos y su allowlist efectiva contiene solo
  `Google`; por tanto rechazarían Apple y Microsoft aunque apareciera un botón.
- No hay identidades Cognito Apple o Microsoft que constituyan evidencia E2E.
- Flutter registra el esquema iOS `foloo`, pero el equipo local no tiene una
  identidad de firma válida instalada. Esto permite validar código/build sin
  firma, no archivar ni subir a TestFlight.

## Sign in with Apple (AUT-22)

1. Apple Developer → Identifiers → **Services ID** (p. ej. `com.foloo.signin`)
   con *Sign in with Apple* habilitado.
   Habilitar también la capacidad en el App ID `com.foloo.foloo` y asociar el
   Services ID con ese App ID primario. El flujo actual usa Cognito Web UI; no
   introduce credenciales Apple dentro del binario.
2. *Return URL*: `https://<dominio-hosted-ui-de-cognito>/oauth2/idpresponse`.
3. Keys → crear clave con *Sign in with Apple* y descargar la `.p8` (una sola
   vez). Anotar Team ID y Key ID.
4. Un operador autorizado almacena la `.p8` mediante transferencia segura en
   el secreto dedicado `foloo/dev/cognito/apple-private-key` de Secrets Manager
   con la clave JSON `privateKey`. El
   ARN completo, no el valor, se entrega como contexto
   `cognitoApplePrivateKeySecretArn`. El despliegue usa una referencia dinámica
   versionless; CloudFormation y el template no persisten la clave resuelta.
   La identidad que ejecute el Change Set necesita `secretsmanager:GetSecretValue`
   limitado a ese secreto. No crear el IdP manualmente si se elige esta ruta:
   un IdP `SignInWithApple` preexistente colisionaría con el `Add` declarativo.

### Alta segura del secreto Apple (runbook ejecutado por el operador)

Esta operación fue realizada por un operador autorizado y no forma parte de
`cdk deploy`; el procedimiento se conserva para rotaciones controladas. La ruta
de la `.p8` se mantiene fuera del repositorio. Para evitar que
el contenido aparezca en el historial o en argumentos de procesos, se usa un
archivo JSON temporal con permisos `0600`; nunca se ejecuta con trazas de shell
(`set -x`) ni se imprime la respuesta completa:

```sh
umask 077
APPLE_SECRET_JSON="$(mktemp /tmp/foloo-apple-secret.XXXXXX.json)"
jq -Rs '{privateKey: .}' "$APPLE_P8_PATH" > "$APPLE_SECRET_JSON"
aws secretsmanager create-secret \
  --name foloo/dev/cognito/apple-private-key \
  --secret-string "file://$APPLE_SECRET_JSON" \
  --profile foloo-dev \
  --region us-east-1 \
  --query ARN \
  --output text
rm -f "$APPLE_SECRET_JSON"
unset APPLE_SECRET_JSON APPLE_P8_PATH
```

`APPLE_P8_PATH` debe apuntar al archivo entregado por el canal seguro y no se
incluye en tickets, chats o documentación. El operador conserva solo el ARN
completo devuelto, lo entrega por el canal aprobado y comprueba con
`describe-secret` únicamente nombre, ARN y cifrado, nunca `SecretString`. Si la
creación falla, se elimina igualmente el archivo temporal antes de reintentar.
El secreto no se reutiliza para otros proveedores ni ambientes.
5. Mapear `email` → `email` y `email_verified` → `email_verified`. El segundo
   mapeo es obligatorio para el PostAuthentication Guard: Cognito deja sin
   verificar por defecto un correo federado si no recibe esa evidencia. Apple
   solo manda el nombre en el primer inicio; el correo puede ser un relay
   privado y nunca se usa para vincular cuentas.
6. Sintetizar el IdP con `cognitoAppleIdentityProviderEnabled=true`; sus
   propiedades fijas son Services ID `com.foloo.signin`, scopes `email name` y
   los Team/Key IDs aprobados. `email_verified` se copia del claim Apple y
   nunca se fija artificialmente a `true`.
7. App client móvil: agregar *SignInWithApple* mediante
   `UpdateUserPoolClient`, usando como base un `DescribeUserPoolClient` fresco
   y conservando proveedores, callbacks, logout, scopes, flujos, duraciones y
   revocación. El cliente no pertenece al stack: modelarlo como un
   `AWS::Cognito::UserPoolClient` nuevo crearía otro cliente, no adoptaría el
   existente. Conservar el payload completo anterior como rollback.
8. Auditar un Change Set separado para los guards con
   `cognitoAppleSignInEnabled=true`. Validar login, restore, logout y ownership
   en DEV; solo después compilar el build autorizado con
   `--dart-define=FOLOO_APPLE_SIGNIN=true`.
9. Al borrar la cuenta hay que revocar el token de Apple (D-13).

La rotación de la `.p8` exige actualizar el IdP: cambiar solo el valor del
secreto no obliga a CloudFormation a releer la referencia dinámica. Debe
prepararse un Change Set que modifique el recurso (normalmente junto con el
nuevo Key ID) y verificarse antes de revocar la clave anterior.

### Aislamiento del primer despliegue Apple

Mientras la rama local contenga cambios STORE-02D que aún no coincidan con el
stack, no se usa su template completo para desplegar Apple. El procedimiento
reproducible es:

1. Descargar con `GetTemplate` el template `Original` de `FolooBackend-dev`.
2. Sintetizar localmente FL-022 con el ARN real del secreto, Apple IdP activo y
   los opt-ins de App Client/Registration Guards desactivados.
3. Extraer únicamente `AppleIdentityProvider6271AB3B` del resultado CDK e
   insertarlo en una copia del template desplegado.
4. Comprobar estructuralmente que el template propuesto tiene una alta, cero
   modificaciones y cero bajas; parámetros, outputs y todos los recursos
   anteriores deben permanecer idénticos.
5. Construir una cloud assembly temporal que publique solo ese template y
   ejecutar primero `cdk diff --no-change-set`.
6. Con autorización separada, usar `cdk deploy --method prepare-change-set`
   sobre la assembly temporal. Preparar el Change Set no autoriza ejecutarlo.

La assembly temporal no sustituye la fuente: usa el mismo logical ID, tipo,
propiedades y metadata generados por el CDK actual. Tras reconciliar el baseline
general, un `cdk diff` normal debe reconocer el recurso sin reemplazarlo. Se
detiene el proceso si aparece cualquier cambio adicional, incluido App Client,
guards, RDS, Stripe, STORE-02D o Managed Login Branding.

## Microsoft (AUT-23, Proposed)

**Estado confirmado 2026-11-03:** el proveedor OIDC `Microsoft` ya existe en el
pool (creado 2026-09-23) y usa el Client ID de la aplicación Entra `FolooAuth`,
no el de `FolooApp`. Su issuer coincide exactamente con el documento discovery
del tenant External ID `7001d501-6e21-4688-8839-c15936e89d18`; los endpoints de
authorize, token y JWKS publicados pertenecen al mismo tenant. Cognito tiene
un secreto configurado para ese cliente, pero una consulta AWS solo demuestra
su presencia: la correspondencia y vigencia reales requieren un flujo OAuth o
una verificación autorizada en Entra. El equipo confirmó visualmente la Return
URL exacta de Cognito. Después de que una consulta local expusiera la credencial
anterior, el operador confirmó su rotación en Entra y Cognito y eliminó la
anterior. La auditoría no imprime ni compara el valor nuevo; Microsoft continúa
deshabilitado hasta resolver `email_verified` y completar E2E.

Los scopes efectivos son `openid email profile`; el mapeo contiene
`email <- email` y `username <- sub`. El discovery anuncia `email`, pero no
`email_verified`, y Cognito tampoco lo mapea. El PostAuthentication Guard exige
correo verificado, por lo que habilitar `Microsoft` en el App Client y en la
allowlist hoy rompería el login en vez de validarlo. No se debe fijar
`email_verified=true`, aceptar `email` como prueba ni debilitar el guard.

Ambos App Clients Cognito conservan solo `COGNITO` y `Google`: el móvil usa
`foloo://callback/` / `foloo://signout/`; el web usa sus callbacks HTTPS. Por
tanto Microsoft no está disponible aunque el IdP exista. La declaración de
Entra entregada por el equipo indica que `FolooAuth` admite cuentas Microsoft,
pero el alcance efectivo del user flow y el tipo de cuenta deben validarse en
Entra y con una cuenta sintética; AWS no acredita esa propiedad.

No recrear el proveedor ni cambiar su issuer. La Return URL fue confirmada
visualmente en `FolooAuth`; debe volver a verificarse al rotar la credencial.
Antes de habilitar Microsoft hay que resolver una evidencia de verificación de
correo compatible con el contrato actual.

### Decisión pendiente: verificación de correo Microsoft

La presencia del claim `email` no acredita control del buzón. Tampoco se puede
usar `xms_edov`: Microsoft lo define como verificación del propietario del
**dominio**, no del buzón del usuario. El discovery efectivo no publica
`email_verified`, y las claims opcionales de la plataforma no ofrecen un booleano
equivalente que Cognito pueda mapear con la semántica exigida por el guard.
Cognito, además, considera no verificado por defecto un correo federado mapeado.

Alternativas que requieren aprobación de Seguridad y Producto:

1. **Mantener Microsoft deshabilitado (recomendada ahora).** Conserva el código
   y el IdP, no cambia el contrato de identidad y permite avanzar Apple de forma
   independiente.
2. **Desafío de verificación propiedad de Foloo.** Tras autenticar con Microsoft,
   un flujo restringido enviaría un código al buzón, con nonce durable,
   expiración, rate limit y protección contra replay. Solo tras validarlo un
   servicio privilegiado establecería el atributo estándar `email_verified` y
   exigiría una nueva autenticación. El PostAuthentication Guard actual bloquea
   antes de que la app pueda ejecutar este flujo; por ello se necesita una ruta
   de bootstrap limitada que no otorgue acceso a `/v1/*`, más una revisión de
   abuso, recuperación y linking. No es un cambio de configuración aislado.
3. **Vinculación explícita desde una cuenta Cognito ya verificada.** Exigiría
   reautenticación del usuario y consentimiento antes de
   `AdminLinkProviderForUser`; nunca se vincula por coincidencia de correo. Esta
   opción no cubre altas nuevas y también requiere aprobación.

Se rechazan fijar `email_verified=true`, interpretar `email` o `xms_edov` como
prueba, o desactivar la comprobación del guard. Referencias:
[mapeo de atributos Cognito](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-specifying-attribute-mapping.html)
y [claims opcionales de Microsoft](https://learn.microsoft.com/en-us/entra/identity-platform/optional-claims-reference).

Los pasos siguientes solo aplican si se reconstruye el proveedor tras una
decisión explícita; no describen el proveedor External ID actualmente desplegado.

1. Entra → App registrations → nueva app, *Accounts in any organizational
   directory and personal Microsoft accounts* sólo si se usa un intermediario;
   para el alcance aprobado (cuentas personales) elegir **Personal Microsoft
   accounts only**.
2. Redirect URI (Web): `https://<dominio-hosted-ui>/oauth2/idpresponse`.
3. Cognito → proveedor **OIDC** llamado exactamente `Microsoft` (la app lo
   usa con ese nombre). Issuer fijo del tenant de cuentas personales:
   `https://login.microsoftonline.com/9188040d-6c67-4c5b-b112-36a304b66dad/v2.0`.
   No usar `common`: su `iss` cambia por tenant y Cognito lo rechaza.
4. Scopes `openid email profile`. Validar en Entra que la credencial siga
   vigente y que el redirect sea exactamente
   `https://us-east-1qvm3dwe4o.auth.us-east-1.amazoncognito.com/oauth2/idpresponse`.
5. Agregar `Microsoft` al App Client móvil sin cambiar callbacks, scopes,
   flujos ni proveedores existentes; desplegar los guards con el opt-in CDK
   `cognitoMicrosoftSignInEnabled=true`.
6. Probar en DEV con una cuenta personal antes de activar
   `--dart-define=FOLOO_MICROSOFT_SIGNIN=true`.

## Orden de activación y TestFlight V4

1. Usar exclusivamente el recurso declarativo opt-in aprobado por ADR-009; no
   crear el IdP manualmente. Confirmar el secreto dedicado por canal seguro sin
   poner la `.p8` en comandos, contexto u outputs.
2. Auditar y desplegar Apple aisladamente. Después agregar
   `SignInWithApple` al cliente móvil mediante una actualización completa y
   controlada; el cliente web permanece sin Apple hasta que su UX/callback se
   implemente y pruebe en `foloo-landing`.
3. Preparar un Change Set separado que amplíe solo
   `COGNITO_ALLOWED_FEDERATED_PROVIDERS` con `SignInWithApple`. No acoplar la
   creación del IdP, el App Client y los guards en un despliegue irreversible.
4. Probar Apple con un usuario sintético: cancelación, login,
   `sub` estable, email/relay, reinicio, refresh y logout. Confirmar que Google
   y email/password siguen funcionando y que no se enlazan cuentas por email.
5. Resolver Microsoft `email_verified`; validar en Entra el client secret, el
   redirect y el tipo de cuenta con una identidad sintética. Solo entonces
   agregar `Microsoft` al cliente objetivo y, en otro cambio auditable, a los
   guards. El cliente web requiere además adaptar su UX/BFF: hoy solo implementa
   email/password y Google.
6. Solo tras la evidencia E2E de cada proveedor compilar `1.0.0+4` con su flag
   correspondiente. Si Google aparece en iOS, Apple debe estar configurado y
   habilitado para la entrega aprobada (D-21).
7. Archivar con Team `PU238KF2F9`, verificar el perfil/capacidades y subir a
   TestFlight únicamente con autorización separada.

**What to Test:** iniciar/cancelar Apple y Microsoft; volver a Foloo por
`foloo://callback/`; conservar la sesión tras reiniciar; cerrar sesión y exigir
login; usar relay Apple sin vincular cuentas; cuenta personal Microsoft; error
recuperable ante proveedor indisponible; regresión de Google y correo/contraseña.

Ambos flags son independientes y `false` por defecto. Un build de tiendas no
debe habilitarlos solo porque el código o el proveedor externo existan.

La configuración de Stripe (ADR-008) está en `backend/README.md`.
