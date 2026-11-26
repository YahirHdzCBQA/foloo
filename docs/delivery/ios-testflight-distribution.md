# Distribución iOS · TestFlight y preparación de App Store

**Última evidencia registrada (2026-11-23):** IPA 1.0.0 (7) generado y
validado localmente para QA privado AWS DEV; sin evidencia de carga,
aprobación ni distribución.
**Trazas:** `AUT-01`, `AUT-02`, `AUT-04`, `AUT-10`–`AUT-12`,
`AUT-18`–`AUT-24`, `MON-21`, `SYN-11`, `SYN-12`, `REL-06`, `RNF-09`.

## Compilación y exportación privada contra AWS DEV

Para cada entrega, usar el archivo de defines homologado para ese corte y
un número disponible. El archivo `app/config/testflight-dev-build7.json`,
conservado para reproducir Build 7, contiene únicamente valores públicos o
interruptores no sensibles. Fija AWS DEV para TestFlight, mantiene el límite
FREE histórico de cinco Leads, habilita STORE-02D y Apple, y deja Microsoft,
Unlimited QA, pagos/enlace web y diagnósticos OCR apagados.

```bash
cd /Users/cbqa/Downloads/foloo/app
flutter run -d <DEVICE_ID> \
  --dart-define-from-file=config/testflight-dev-build7.json
```

Comando efectivamente utilizado el 2026-11-23:

```bash
cd /Users/cbqa/Downloads/foloo/app
flutter build ipa --release \
  --build-name=1.0.0 --build-number=7 --export-method=app-store \
  --dart-define-from-file=config/testflight-dev-build7.json
```

El operador confirmó el número 7 disponible antes de compilar. Para otro corte,
confirmar disponibilidad y autorización independientes. Este comando escribe
en las rutas de salida habituales; preservar los artefactos antes de repetirlo.

## Firma, exportación y alcance de QA

- Archive Xcode 27 / SDK iPhoneOS 27.0: `app/build/ios/archive/Runner.xcarchive`
  (158.4 s). Exportación App Store Connect: `app/build/ios/ipa/foloo.ipa`
  (33 s; 49,562,928 bytes).
- SHA-256 IPA: `23d2bb7847b092cc3708242dce9eb62d62031e9a376408df75cc30f9b1d8ea33`.
- Firma automática. Xcode reusó el perfil App Store de Foloo y exportó con
  **Cloud Managed Apple Distribution**; `codesign --deep --strict` aprobó.
  `security find-identity` solo enumeró Apple Development local. Ese listado
  no identifica la firma gestionada por Xcode y no basta para bloquear un
  archive/export autorizado. Si falla un build posterior, inspeccionar
  primero el error real y `DistributionSummary.plist`; no crear certificados
  ni regenerar perfiles sin autorización. El éxito anterior no garantiza
  disponibilidad futura de la firma.
- El operador confirmó Apple Sign-In y QA-30 en iPhone. La suite previa dio
  413 PASS / 1 SKIP intencional, más 1 PASS de contrato con los defines.
  Esto no acredita por separado relay, restauración, cancelación, logout ni
  una prueba destructiva de eliminación con el IPA 7.
- ML Kit mostró advertencias no bloqueantes de Swift Package Manager y arm64
  en simuladores; no impidieron archive/export para dispositivo.

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

Checklist de configuración Apple Developer homologada por el operador, para
revalidación si cambian los recursos, sin copiar secretos:

1. App ID `com.foloo.foloo`, Team `PU238KF2F9`, Sign in with Apple habilitado
   como App ID principal.
2. Services ID igual al `client_id` público observado en Cognito y asociado al
   App ID anterior.
3. Dominio DEV: `us-east-1qvm3dwe4o.auth.us-east-1.amazoncognito.com`.
4. Return URL DEV:
   `https://us-east-1qvm3dwe4o.auth.us-east-1.amazoncognito.com/oauth2/idpresponse`.
5. Key ID igual al valor público observado en Cognito, key vigente y asociada
   al App ID principal. El `.p8` nunca se copia al repositorio ni al informe.

Para cobertura ampliada, registrar evidencia individual en iPhone: cuenta
nueva con compartir email, relay privado, cuenta existente, cancelación,
error recuperable, reinicio y logout. El owner sigue siendo Cognito `sub`;
un relay no une cuentas ni se supone equivalente a un correo preautorizado.

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
- El IPA contiene 18 manifiestos `PrivacyInfo.xcprivacy`. La CLI no produjo
  un Privacy Report consolidado; revisarlo en Xcode cuando esté disponible
  antes de usar esta evidencia para App Privacy. No se agrega un manifiesto
  vacío ni se sustituye el gate de publicación.
- La carga manual mediante Transporter no forma parte de la exportación. No hay
  evidencia de procesamiento, aceptación ni distribución en App Store Connect.

## Entrega y resolución de problemas

1. Confirmar versión/número, Team y App ID, configuración del entorno y
   autorización para compilar. Preservar IPA/archives anteriores; las rutas
   habituales se sobrescriben. Sustituir el número y el archivo de defines solo
   por valores homologados para ese corte. No usar este flujo DEV para PROD.
2. Validar firma e IPA con Xcode y `codesign --verify --deep --strict` sobre
   la app extraída. Confirmar versión, bundle, Team, perfil, entorno y hash del
   IPA. Para diagnóstico consultar `DistributionSummary.plist` y el error
   real del export; firma de desarrollo del archive no equivale a firma final.
   Revisar acceso de Xcode al Team/firma gestionada antes de cambiar llaveros.
3. Con autorización separada, seleccionar el IPA validado en Transporter.
   Confirmar procesamiento del build exacto y grupo autorizado en App Store
   Connect antes de distribuir. TestFlight no es aprobación para App Store.
4. Verificar en dispositivos soportados: sesión e aislamiento, OCR y permisos,
   evento/directo, offline/reinicio/sync, registros, exportación y seguimiento
   Gmail/Outlook. Un E2E destructivo de STORE-02D requiere identidad sintética
   y autorización propia. Para release público usar el
   [runbook PROD](prod-environment-readiness.md) y los
   [gates de tiendas](roadmap.md#gates-de-publicación-de-tiendas).

## Historial mínimo de builds

- **5 / FL-023 (2026-11-11):** Build privado DEV; conserva
  [script histórico](../../app/scripts/build-testflight-build5.sh) con
  Unlimited QA explícito. No usarlo para un build con límite FREE homologado.
  La preparación local reportó Flutter 357/357, backend focalizado 41/41 y
  análisis limpio. Builds 5 y 6 exportaron con firma automática App Store
  Connect y, según el operador, se cargaron mediante Transporter. El IPA 6
  acredita Apple Distribution aunque su archive intermedio estaba sin firma.
- **7 / FL-025:** evidencia reproducible arriba; no consta carga ni distribución.
  No se verificó retrospectivamente la disponibilidad de grupos anteriores.
