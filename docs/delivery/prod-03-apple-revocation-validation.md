# PROD-03 · Validación previa de revocación Apple

Estado: preparación local. Diseño de integración pendiente de aprobación y
validación externa. Trazas: D-21, D-13, ADR-002/009, AUT-10, AUT-18–AUT-22,
INF-15–INF-21, RNF-09, E-01 y E-14.

## Configuración observada

Flutter inicia Apple con Amplify Hosted UI. Apple devuelve su código a
`/oauth2/idpresponse` de Cognito. Flutter recibe un código Cognito en
`foloo://callback/`. El issuer y el owner de Foloo son el pool y su `sub`.
El IdP Apple mapea solo correo y verificación de correo. La revocación del
cliente Cognito se aplica a tokens Cognito. El paso OAuth de STORE-02D opera
sobre conexiones Gmail/Outlook y el finalizador elimina al usuario Cognito.

### Inventario confirmado · 2026-11-10

Apple Developer fue revisado manualmente por el responsable de CBQA. La
configuración efectiva de Cognito DEV se contrastó mediante
`DescribeUserPool`, `ListIdentityProviders`, `DescribeIdentityProvider`
y `DescribeUserPoolClient` con el perfil `foloo-dev` en `us-east-1`. Se
seleccionaron únicamente campos de configuración públicos.

| Dato | Valor y evidencia |
| --- | --- |
| Equipo y Team ID | CBQA Solutions Mexico, S.C. · `PU238KF2F9`. Coincide con Xcode, CDK DEV y el IdP DEV efectivo. |
| App ID y Bundle ID | `com.foloo.foloo`. Coincide con Xcode. Apple Developer lo confirma como Primary App ID con Sign in with Apple. |
| Services ID | `com.foloo.signin`, asociado al App ID primario. Coincide con CDK DEV y el `client_id` del IdP efectivo. |
| Key ID | `6LK763G44F` · Foloo Apple Sign In. Coincide con CDK DEV y el IdP efectivo. Apple Developer confirma el servicio y su asociación con `PU238KF2F9.com.foloo.foloo`. |
| Pool y dominio DEV | `us-east-1_QVm3dWe4O` · `us-east-1qvm3dwe4o.auth.us-east-1.amazoncognito.com`. Coincide con la configuración local y el dominio registrado en Apple Developer. |
| Return URL Apple DEV | `https://us-east-1qvm3dwe4o.auth.us-east-1.amazoncognito.com/oauth2/idpresponse`. Confirmada por el responsable en Apple Developer y coherente con el dominio efectivo del pool. |
| Cliente móvil DEV | `foloo-mobile-dev` · `6jong3atp2crqcsde6g215ant8`. Admite `COGNITO`, `Google` y `SignInWithApple`. Callbacks efectivos: `foloo://callback/` y `https://d84l1y8p4kdic.cloudfront.net`. Logout: `foloo://signout/`. |
| Otros IdPs DEV | `Microsoft` existe en el pool como OIDC y está fuera de la lista efectiva del cliente móvil. |

La ausencia de Apple documentada en el corte DEV del 3 de noviembre es
histórica. La consulta del 10 de noviembre confirma el IdP y su asociación
al cliente móvil. La lectura no acredita login, guard de registro, cliente
web, vigencia operativa de la clave ni canje E2E. El retorno Apple a Cognito
y el retorno de Cognito a la app son pasos distintos.

### PROD y prueba de canje

- Obtener `UserPoolId`, `MobileAppClientId` y `CognitoDomain` de los
  outputs reales de `FolooIdentity-prod`. Usar pool, cliente móvil,
  dominio, guards y referencia a secreto propios de PROD. El cliente
  móvil conserva su callback `foloo://callback/`. Para Apple, la URL
  registrada será `https://<CognitoDomain de PROD>/oauth2/idpresponse`.
  Agregar el dominio y retorno PROD al Services ID aprobado por CBQA
  mediante un cambio posterior autorizado. Conservar el retorno DEV.
- El stack recibe `prodAppleServicesId`, `prodAppleTeamId` y
  `prodAppleKeyId` al habilitar `prodAppleIdentityProviderEnabled`.
  El Services ID de PROD y su agrupamiento requieren una decisión
  explícita. Separar pools, secretos y callbacks aísla Cognito. Apple
  documenta que las credenciales del usuario pueden compartirse dentro
  de un grupo. Para exigir aislamiento Apple entre entornos, CBQA debe
  aprobar una separación de grupos y validar su compatibilidad con el
  Bundle ID de publicación.
- `com.foloo.signin` es el candidato para comprobar correspondencia con
  DEV usando el mismo cliente Apple. Apple permite varios retornos HTTPS
  por Services ID. Una segunda URL separa la entrega del código, pero
  conserva el mismo cliente Apple y su asociación al App ID primario.
  La prueba queda limitada a una Apple Account de prueba sin usos en
  otras apps o entornos, su identidad Cognito de prueba y un canje sin
  revocación. Esa prueba no certifica el aislamiento de otras
  autorizaciones ni el alcance de una revocación futura.
- Antes de la prueba faltan el dominio y retorno HTTPS exactos del
  receptor aislado, autorización para agregarlos sin retirar el retorno
  DEV, verificación de guards, identidad de prueba y acceso autorizado
  del backend de prueba a un firmante seguro para el `client_secret`.
  El Key ID es un identificador público; no sustituye el acceso al
  firmante. El secreto existente y su acceso no se consultaron.

## Prueba local controlada de correspondencia

Ejecutar el bloque con Node desde cualquier directorio. Representa únicamente
la comparación de dos resultados **ya verificados** y el aislamiento del
owner. Los valores son sintéticos. Las comprobaciones criptográficas, el
canje y la revocación quedan fuera de esta prueba.

```bash
node --input-type=module <<'JS'
import assert from 'node:assert/strict';

const pool = 'fixture-pool';
const client = 'fixture-services-id';
const session = { pool, sub: 'owner-a' };
const cognito = {
  pool,
  sub: 'owner-a',
  identities: [
    { providerName: 'SignInWithApple', userId: 'AppleSubjectA' },
  ],
};
const apple = { aud: client, sub: 'AppleSubjectA' };

// Inputs represent verified responses. The real backend must obtain the
// Cognito profile server-side and validate the Apple token before comparison.
function matches(session, cognito, apple) {
  const appleIdentities = cognito.identities.filter(
    ({ providerName }) => providerName === 'SignInWithApple',
  );
  return session.pool === pool && cognito.pool === pool &&
    session.sub === cognito.sub && apple.aud === client &&
    appleIdentities.length === 1 && Boolean(apple.sub) &&
    appleIdentities[0].userId === apple.sub;
}

assert.equal(matches(session, cognito, apple), true);
assert.equal(matches(session, cognito, { ...apple, sub: 'applesubjecta' }), false);
assert.equal(matches(session, cognito, { ...apple, aud: 'other-client' }), false);
assert.equal(matches(session, { ...cognito, sub: 'owner-b' }, apple), false);
assert.equal(matches(session, { ...cognito, pool: 'other-pool' }, apple), false);
assert.equal(matches(session, { ...cognito, identities: [] }, apple), false);
assert.equal(matches(session, {
  ...cognito,
  identities: [...cognito.identities, cognito.identities[0]],
}, apple), false);
console.log('AUT-10/AUT-22: 7 synthetic identity checks passed');
JS
```

## Siguiente prueba externa, sin revocar

Con aprobación separada y una identidad sintética en un entorno aislado:

1. Autenticar por Apple mediante Cognito. Obtener el perfil de ese owner
   desde Cognito con una sesión verificada y localizar el `userId` exacto
   en `identities` para `SignInWithApple`. No derivarlo del nombre de usuario
   ni del correo o Private Relay.
2. Iniciar una autorización directa con el mismo Services ID de Cognito
   y el segundo retorno HTTPS autorizado. Enlazar al owner, entorno y
   preflight mediante state de un solo uso y nonce. Canjear el código
   nuevo en `/auth/token` con el mismo client_id, retorno exacto y
   client_secret firmado por el backend. El código usado por Cognito no
   se reutiliza.
3. Validar firma Apple, issuer, audiencia, expiración y nonce. Comparar
   exactamente el subject Apple con el userId Cognito. Confirmar que se
   recibió un token Apple utilizable por el mismo cliente. Registrar
   solo resultados booleanos y destruir el material de prueba.
4. Confrontar el agrupamiento con la configuración Apple Developer. La
   correspondencia de sujeto y cliente acredita la obtención de una
   credencial para ese usuario y cliente. El alcance efectivo de
   revocación respecto de sesiones previas y otros entornos requiere
   evidencia adicional. No llamar `/auth/revoke` en esta prueba.

## Contrato mínimo propuesto para STORE-02D

- **Flutter y web.** Durante el preflight de una identidad Apple, abrir la
  autorización puntual y recibir una referencia opaca. La sesión Cognito
  interactiva reciente de cinco minutos sigue autorizando la confirmación.
  La vía web debe poder autenticar al mismo owner Apple mediante Cognito.
- **Backend.** Preparar un callback y custodia cifrada temporal con
  caducidad, sin devolver tokens al cliente. Vincular la credencial a la
  solicitud durable al confirmar. El worker registra una etapa Apple
  separada y reintentable antes de eliminar Cognito. Mantiene barrera,
  alcance por owner, orden del borrado y receipt. Si un intento es ambiguo,
  conserva evidencia y permite reintentar la misma etapa sin repetir las
  etapas completadas. Destruye la credencial cuando deja de ser necesaria.
- **CDK.** Preparar permisos acotados para Secrets Manager/KMS y un
  límite de egreso a Apple para el backend autorizado. Declarar solo
  identificadores públicos y referencias a secretos. Conservar pool,
  cliente móvil, callbacks de login y guards. Si el cliente web requiere
  admitir Apple, someter ese cambio a revisión separada.
- **Sin credencial recuperable.** TN3194 indica completar el borrado de
  Foloo y orientar a retirar el permiso en Apple manualmente. Someter a
  D-13 la evidencia, instrucciones y representación en el receipt. Un
  error temporal con token disponible conserva el reintento y escalamiento
  de STORE-02D. El receipt debe reflejar si la revocación Apple se verificó.

Fuentes: [Federación de Cognito](https://docs.aws.amazon.com/cognito/latest/developerguide/federation-endpoints.html),
[identidades federadas](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-identity-federation.html),
[configuración Apple](https://developer.apple.com/documentation/signinwithapple/configuring-your-environment-for-sign-in-with-apple),
[TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple),
[revocación Apple](https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens).
