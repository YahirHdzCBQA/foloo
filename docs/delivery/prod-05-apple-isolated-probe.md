# PROD-05 · Prueba aislada Apple/Cognito

Estado: núcleo local con fixtures. Ningún dominio, receptor, permiso ni
secreto se ha habilitado. Trazas D-21, D-13, ADR-002/009, AUT-10, AUT-18–22,
INF-15–21, E-01 y E-14. Inventario confirmado en el
[runbook D-21](prod-03-apple-revocation-validation.md).

## Frontera temporal propuesta

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

## Contrato y manejo de secretos

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

## Procedimiento y GO / NO-GO

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

## Uso posterior en STORE-02D

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
