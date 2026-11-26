# Revocación Apple · validación y diagnóstico aislado (PROD-03/05)

Estado: inventario DEV histórico y diagnóstico local; sin revocación verificada. Diseño de integración pendiente de aprobación y
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

## Evidencia local de correspondencia

PROD-03 comprobó siete fixtures: caso válido, case exacto, audiencia, owner,
pool, identidad ausente y múltiple. No ejecutó canje ni revocación. PROD-05
amplió la cobertura con firma/JWKS, nonce/state, replay, fallos de transporte
y límites del receptor. La revisión técnica posterior obtuvo 16/16 pruebas
sintéticas; ninguna acredita un permiso Apple real.

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

## Checklist Apple Developer

- [ ] Team y responsable con permisos para Identifiers, Keys y dominios.
- [ ] App ID primario con Sign in with Apple y Bundle ID del candidato.
- [ ] Services ID que usa Cognito, asociación al App ID y mapa de
  agrupamiento de DEV, PROD y otras apps. Distinguirlo del App Client ID
  de Cognito.
- [ ] Key ID, estado y alcance de la clave; custodia y rotación del .p8 por
  canal seguro, con secreto dedicado en PROD. Compartir identificadores y
  referencias aprobadas, sin copiar material privado al repositorio.
- [ ] Dominios/retornos HTTPS autorizados. Distinguir el retorno Cognito
  /oauth2/idpresponse, el posible segundo retorno de prueba y el deep link
  móvil. Confirmar Private Relay y origen de correo si se usa para avisos.
- [ ] Decidir si se registran avisos server-to-server y quién los opera.
- [ ] Inventariar por entorno issuer, UserPoolId, dominio, clientes móvil y
  web, IdP, guards y callbacks. Registrar valores PROD solo desde outputs
  reales aprobados.

**Antes de PROD.** Revisar inventario y agrupamiento en Apple Developer
por un operador autorizado, contrastar manifest/template Cognito,
ejecutar fixtures de identidad de PROD-03 y preparar criterios de prueba
sin secretos. Un entorno aislado autorizado con Apple/Cognito reales
puede validar login, subject y canje con el mismo Services ID antes de
desplegar PROD. El alcance efectivo de revocación no se acredita con
fixtures ni con un canje exitoso.

**Con entorno real.** Validar configuración efectiva de PROD, auth_time
interactivo y acceso móvil/web Apple. Verificar aislamiento del permiso
con evidencia aprobada antes de integrar o probar revocación. Borrado,
revocación, restore y avisos reales requieren autorización independiente.

## PROD-05 · Protocolo de diagnóstico aislado

### Frontera temporal propuesta

**Dominio candidato:** `apple-probe.foloo.io`. **Retorno candidato:**
`https://apple-probe.foloo.io/d21/apple/callback`. Ambos quedan sujetos a
aprobación del operador de foloo.io y verificación de disponibilidad y TLS.
Usar un receptor efímero separado, con un proceso y un intento por ejecución,
sin acceso a datos Foloo ni al runtime de DEV/PROD. El operador arranca el
intento por canal privado. El único endpoint público de prueba recibe el
POST Apple. No existe un endpoint público para iniciar intentos o consultar
resultados.

El operador debe vincular la prueba a una Apple Account dedicada y a su
identidad Cognito de prueba, sin reutilizar usuarios reales. Usar un perfil
autoritativo de Cognito, obtenido por el futuro adaptador autorizado a partir
de sesión verificada y pool/owner allowlisted. Extraer el único
`identities[].userId` con proveedor `SignInWithApple`. El callback no recibe
ni elige el owner, el pool o ese perfil. No usar correo, Private Relay ni
comparaciones insensibles a mayúsculas. Acordar de antemano cómo obtener el
perfil de prueba sin alterar la configuración DEV.

### Contrato y manejo de secretos

- El núcleo recibe owner aprobado, perfil Cognito verificado, reloj y dos
  adaptadores. Devuelve una URL de autorización para entrega privada al
  navegador del operador y una función de callback. Solicita solo código,
  con `form_post` y sin scopes de nombre o correo. State y nonce son
  aleatorios e independientes de 256 bits y quedan en memoria en el proceso
  de ese intento. El state vence a los cinco minutos y se consume antes
  del primer await. Un fallo exige un intento nuevo y código nuevo.
- El host acepta POST en la ruta exacta con TLS, formulario y límite de
  8 KiB aplicado antes de leer el cuerpo. Deshabilitar logs de URL, cuerpos,
  cabeceras sensibles, trazas y caché. Devolver al navegador una página
  neutra con `Cache-Control: no-store`. Entregar al operador solo un
  estado fijo y, al verificar, los booleanos `identityMatches` y
  `credentialReceived`. Nunca mostrar state, nonce, subject o tokens
  en resultados. No registrar la URL de autorización.
- `exchange(fields)` recibe client_id, redirect_uri, grant_type y code.
  El adaptador futuro firma un client_secret efímero ES256 con Team ID
  `PU238KF2F9`, Key ID `6LK763G44F`, sub `com.foloo.signin`,
  aud `https://appleid.apple.com` e iat/exp. El firmante utiliza material
  ya autorizado en un límite seguro y entrega solo el JWT al proceso
  de canje. La clave privada queda fuera del receptor y del repositorio.
  El adaptador hace un único POST a `https://appleid.apple.com/auth/token`
  con TLS, timeout, límites de respuesta y sin redirecciones ni reintento
  automático. Devuelve el JSON directamente al núcleo, en memoria.
- `resolveKey(kid)` busca exclusivamente en el JWKS de Sign in with Apple
  obtenido por TLS desde `https://appleid.apple.com/auth/keys`, con
  timeout, límites y sin redirecciones. El núcleo acepta RS256 y verifica
  firma, issuer, audiencia, expiración, nonce y subject. El host debe
  confirmar compatibilidad con las claves Apple efectivas antes de ejecutar
  el canje. Un algoritmo inesperado falla cerrado.
- El núcleo no persiste respuestas y devuelve solo el resultado reducido.
  Evitar dumps y swap en el receptor si el operador los controla. Cerrar el
  proceso después del intento para descartar el material efímero.
  El resultado `credentialReceived` significa que Apple devolvió un
  access/refresh token en el canje. No prueba que pueda revocar sesiones
  anteriores ni que el permiso esté aislado de otros entornos.

El transporte local admite un firmante inyectado y se probó con un fetch
simulado. Quedan por conectar el host HTTPS, el firmante y la lectura
autorizada de Cognito. El núcleo por sí solo no abre puertos, lee secretos
o realiza llamadas de red.

### Procedimiento y GO / NO-GO

1. Ejecutar `node --test backend/scripts/apple-identity-probe/probe.test.mjs`.
   Los fixtures generan claves efímeras y simulan canje y JWKS.
2. **GO para autorizar una prueba real** solo tras confirmar propietario del
   dominio/TLS, proceso efímero, identidad de prueba y binding Cognito,
   autorización del firmante, controles del receptor y limpieza. El operador
   Apple Developer debe revisar el agrupamiento, conservar el Services ID
   y retorno DEV y agregar únicamente el dominio y retorno candidato como
   entradas adicionales. No se requiere crear o revocar claves para este plan.
3. **NO-GO** si falta cualquier aprobación, se necesita un usuario real,
   no se puede atribuir el perfil al owner aprobado o el cambio exige
   reemplazar el retorno DEV. Tampoco proceder si el receptor retiene
   cuerpos o el firmante requiere entregar la clave al proceso.
4. En la ventana autorizada, iniciar un intento, autorizar con la cuenta
   de prueba, procesar el POST y canjear exactamente una vez. El criterio
   de aceptación es `verified` con ambos booleanos verdaderos. Un error,
   mismatch o ausencia de credencial detiene la prueba. Conservar solo
   fecha, entorno, resultado y versión del procedimiento. La ejecución
   termina aquí, antes de cualquier llamada a `/auth/revoke`.
5. **Limpieza.** Cerrar el receptor y eliminar proceso, estado temporal y
   permisos del firmante. Retirar únicamente el retorno y dominio agregados,
   si el operador lo autorizó, y comprobar que el retorno DEV continúa.
   Retirar hosting/DNS temporal autorizado. Mantener la cuenta de prueba
   segregada. Cualquier retirada del permiso Apple o eliminación de cuenta
   queda fuera de esta prueba y requiere autorización propia.

### Uso posterior en STORE-02D

Un PASS permite diseñar la obtención puntual de credencial antes de la
confirmación. No sustituye una evaluación del alcance del permiso Apple.
Tras aprobación de D-13 y del diseño, vincular una credencial cifrada al
owner y a la solicitud durable y agregar un checkpoint Apple antes de
finalizar Cognito. La reautenticación Cognito interactiva de cinco minutos
sigue siendo obligatoria. La confirmación irreversible, barrera, worker,
reintentos y receipt conservan su contrato. Distinguir credencial ausente
y retirada manual de un fallo transitorio reintentable y de una revocación
verificada. Móvil y web deben llegar al mismo proceso. Google, correo/
contraseña y los senders Gmail/Outlook conservan sus rutas y credenciales.

Fuentes: [autorización Apple](https://developer.apple.com/documentation/signinwithapplerestapi/request-an-authorization-to-the-sign-in-with-apple-server),
[canje](https://developer.apple.com/documentation/signinwithapplerestapi/generate-and-validate-tokens),
[configuración web](https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web).
