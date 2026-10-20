# STORE-02E-02A — Identidad seudonimizada aislada

- Fecha: 2026-10-20
- Estado: **módulo preparatorio implementado y no conectado**
- Trazas: `AUT-21`, `INF-20`, `RNF-09`, E-14, `AD-T-17`, `AD-T-18`,
  `AD-T-30`
- Decisiones: `ADR-AD-01`–`ADR-AD-03` permanecen candidatas; D-13 abierta

Este incremento implementa únicamente primitivas puras y pruebas. No crea
ledger, recursos AWS, secretos, persistencia, triggers Cognito, endpoints,
guards ni comportamiento de Account Deletion.

## Archivos

- `backend/src/account_deletion/pseudonymous_identity.ts`: canonicalizador,
  contratos de key provider/generador HMAC y servicio de identificación.
- `backend/test/pseudonymous_identity.test.ts`: fixtures sintéticos y cobertura
  de canonicalización, validación, vector público HMAC-SHA-256, determinismo y
  key versions. Las llaves de fixture son patrones de bytes, no secretos.

## Política provisional `foloo-email-v1-provisional`

1. El caller debe proporcionar un atributo Cognito cuya verificación haya sido
   comprobada server-side; la utilidad no prueba ownership del mailbox.
2. Se eliminan espacios exteriores accidentales y se aplica Unicode NFC.
3. Local-part y dominio se convierten a minúsculas para evitar diferencias
   prácticas entre email/password y Google.
4. El dominio se convierte a ASCII mediante IDNA y se validan sus labels.
5. Se rechazan controles, format characters, espacios internos, quoting,
   local-parts con puntos inicial/final/doble, dominios inválidos y longitudes
   superiores a los límites soportados.
6. Los puntos y sufijos `+` se conservan. No hay reglas Gmail/provider, alias
   folding ni consulta DNS.

El lowercasing del local-part es un supuesto provisional: evita bypass por case
entre fuentes actuales, pero Seguridad/Producto debe decidir si acepta la
colisión teórica de mailboxes case-sensitive antes de usarlo en runtime. Un
cambio futuro requiere un policy version nuevo y comparación multiversión; no
se debe reinterpretar silenciosamente un digest existente.

## Frontera HMAC

`PseudonymousEmailIdentifierService` depende de dos puertos genéricos:

- `HmacSha256KeyProvider<KeyHandle>` obtiene el handle correspondiente a una
  versión explícita;
- `HmacSha256Generator<KeyHandle>` genera exactamente 32 bytes de
  HMAC-SHA-256.

El payload incluye domain separation, policy version y key version. El
resultado contiene algoritmo, policy, key version y digest Base64URL. No
contiene el correo y no funciona como owner o autorización.

`NodeHmacSha256Generator` permite pruebas/offline con bytes inyectados. No
obtiene secretos y no está conectado al runtime. El adaptador productivo
propuesto usaría un key handle KMS y `GenerateMac`/`VerifyMac`, sin exportar la
clave; eso requiere aprobación de Seguridad y no se implementa aquí.

## Integración futura, no autorizada

1. KMS: adaptador de key versions a key IDs y generador mediante KMS HMAC.
2. DynamoDB: persistir únicamente digest/version/policy/`blockedUntil`, nunca
   email claro; TTL sería limpieza auxiliar.
3. Cognito: obtener/verificar el atributo en la frontera server-side y usar el
   servicio desde el guard/Pre Sign-up aprobados.
4. Subject tombstone: usar otro namespace/domain tag y política de retención;
   no reutilizar el identificador de correo ni su expiración de 30 días.

## Riesgos y decisiones pendientes

- fuente y evidencia exacta de `email_verified` para email/password y Google;
- lowercasing del local-part y tratamiento de aliases;
- KMS HMAC frente a otra custodia de llave, rotación y permisos;
- comparación multiversión durante rotación;
- retención del subject tombstone y ledger/restore;
- política fail-closed y observabilidad sin PII.

Ninguna ADR se aprueba con este incremento. Trial, PRO, Unlimited QA, Flutter y
el flujo actual permanecen sin cambios.
