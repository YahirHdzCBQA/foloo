# TestFlight 1.0.0 Build 7 — configuración candidata

**Estado:** candidato local; no generar ni distribuir hasta cerrar Apple
Developer y E2E. **Trazas:** `AUT-01`, `AUT-02`, `AUT-04`, `AUT-10`–`AUT-12`,
`AUT-18`–`AUT-24`, `MON-21`, `SYN-11`, `SYN-12`, `REL-06`, `RNF-09`.

## Configuración reproducible

`app/config/testflight-dev-build7.json` contiene únicamente valores públicos o
interruptores no sensibles. Fija AWS DEV para TestFlight, mantiene el límite
FREE histórico de cinco Leads, habilita STORE-02D y Apple, y deja Microsoft,
Unlimited QA, pagos/enlace web y diagnósticos OCR apagados.

```bash
cd /Users/cbqa/Downloads/foloo/app
flutter run -d <DEVICE_ID> \
  --dart-define-from-file=config/testflight-dev-build7.json
```

Tras cerrar los gates externos, el comando de generación será:

```bash
cd /Users/cbqa/Downloads/foloo/app
flutter build ipa --release --no-pub \
  --build-name=1.0.0 --build-number=7 --export-method=app-store \
  --dart-define-from-file=config/testflight-dev-build7.json
```

El segundo comando todavía no está autorizado. El número 7 debe comprobarse
en App Store Connect como siguiente build disponible para `1.0.0`.

## Frontera Apple → Cognito → Foloo

La app usa Cognito Managed Login/Hosted UI, no
`ASAuthorizationAppleIDProvider`. Por eso Runner necesita el URL scheme
`foloo`, pero no se añade un entitlement nativo sin una API nativa que lo use.
La cuenta Apple Developer sí debe tener el App ID principal habilitado para
Sign in with Apple y el Services ID asociado.

La auditoría AWS DEV de solo lectura del 2026-11-23 verificó:

- User Pool y App Client públicos coincidentes con Flutter;
- IdP `SignInWithApple` habilitado en el cliente móvil junto con Google;
- OAuth authorization code, scopes `openid email profile` en el cliente y
  `email name` en Apple;
- callback `foloo://callback/` y logout `foloo://signout/`;
- mapeos de Apple hacia username/sub, email y email verificado;
- guards PreSignUp/PostAuthentication activos y allowlist Google/Apple.

La consola Apple debe comprobar manualmente, sin copiar secretos:

1. App ID `com.foloo.foloo`, Team `PU238KF2F9`, Sign in with Apple habilitado
   como App ID principal.
2. Services ID igual al `client_id` público observado en Cognito y asociado al
   App ID anterior.
3. Dominio DEV: `us-east-1qvm3dwe4o.auth.us-east-1.amazoncognito.com`.
4. Return URL DEV:
   `https://us-east-1qvm3dwe4o.auth.us-east-1.amazoncognito.com/oauth2/idpresponse`.
5. Key ID igual al valor público observado en Cognito, key vigente y asociada
   al App ID principal. El `.p8` nunca se copia al repositorio ni al informe.

Después se ejecuta en iPhone: cuenta Apple nueva con compartir email, cuenta
nueva con relay privado, cuenta existente, cancelación, error recuperable,
restore tras reinicio y logout. El owner debe ser Cognito `sub`; nunca se unen
cuentas por email ni se supone que un relay coincide con una preautorización.

## STORE-02D

La configuración candidata expone el flujo ya implementado: reautenticación,
preflight, exportación opcional, advertencia por outbox pendiente, aceptación
irreversible, receipt, cierre de sesión y purga owner-scoped. Las pruebas
destructivas locales usan dobles; cualquier E2E nuevo exige una cuenta sintética
y autorización separada.

## iOS y privacidad

- Bundle ID `com.foloo.foloo`, Team `PU238KF2F9`, signing automático e iOS
  mínimo 15.5 se conservan.
- Cámara, micrófono y fototeca tienen propósito ES/EN alineado con tarjeta,
  referencias, voz y foto de perfil.
- Runner no llama directamente APIs nativas de motivo requerido. Flutter y los
  SDK integrados aportan sus propios `PrivacyInfo.xcprivacy`; no se agrega un
  manifiesto vacío o genérico. El archive autorizado deberá generar y revisar
  el Privacy Report antes de subir.
- App Store Connect debe confirmar build 7, provisioning, App Privacy y que la
  capacidad remota Sign in with Apple está incluida en el perfil efectivo.

