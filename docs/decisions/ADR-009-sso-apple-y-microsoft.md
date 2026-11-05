# ADR-009 — Sign in with Apple y retoma de Microsoft Sign-In vía Cognito

- Estado: Aceptado por Producto el 2026-10-21 (resuelve `D-21`), con enmienda
  operativa Apple aceptada el 2026-11-03; la configuración de Microsoft queda
  **Proposed** hasta validar correo verificado y E2E en DEV.
- Fecha: 2026-10-21.
- Alcance: `AUT-01`, `AUT-04`, `AUT-17`, `AUT-22`–`AUT-24`.

## Contexto

Apple 4.8 exige ofrecer una alternativa equivalente cuando la app autentica con
Google. Microsoft Sign-In quedó fuera por un conflicto de issuer entre Cognito
y Microsoft Entra (ADR-006 / `AUT-17`).

## Decisión

1. **Sign in with Apple** se agrega como proveedor federado de Cognito, igual
   que Google. La implementación se conserva, pero su botón permanece detrás
   de `FOLOO_APPLE_SIGNIN=false` hasta validar Apple Developer, Cognito y los
   guards de registro. Una vez aprobada la configuración, el build iOS debe
   habilitarlo mientras ofrezca Google; Android puede habilitarlo si el
   proveedor está configurado. Cognito sigue siendo el único issuer; el `sub`
   sigue siendo el owner. No se unen cuentas por email.
2. Apple puede ocultar el correo (relay). Foloo no depende del email como
   identidad; solo lo muestra. Al borrar la cuenta se debe revocar el token de
   Apple (se enlaza con `D-13`).
3. **Microsoft Sign-In se retoma** como proveedor OIDC de Cognito. El conflicto
   de issuer proviene del endpoint multi-tenant `common`, cuyo `iss` incluye el
   tenant del usuario y no coincide con el issuer fijo que Cognito valida. Se
   propone usar un issuer fijo: el tenant de cuentas personales
   (`consumers`), que coincide con el alcance ya aprobado para el sender en
   ADR-006. Cuentas de trabajo/escuela requieren otra solución (un tenant
   concreto por cliente o un intermediario que normalice el issuer) y quedan
   fuera hasta decidirlo. Actualización 2026-10-23: el pool DEV ya tiene un
   proveedor OIDC `Microsoft` (creado 2026-09-23) con issuer de un tenant de
   Entra External ID; se valida ése antes de crear otro (ver `sso-setup.md`).
4. La conexión de correo (OAuth sender, `SAL-*`) sigue siendo independiente del
   inicio de sesión (`AUT-15`).
5. El IdP Apple se administra declarativamente en el stack existente mediante
   `AWS::Cognito::UserPoolIdentityProvider`, referenciando el User Pool externo
   sin importarlo. La clave `.p8` vive exclusivamente en un secreto DEV de
   Secrets Manager y llega a CloudFormation como referencia dinámica al campo
   JSON `privateKey`; ni el valor ni el archivo entran a Git, contexto CDK,
   outputs o logs. El App Client móvil sigue fuera del stack y requiere una
   actualización completa, separada y auditada. El IdP Microsoft continúa como
   recurso externo preexistente. El runbook está en `docs/delivery/sso-setup.md`.

## Enmienda operativa Apple (aceptada, 2026-11-03)

La preparación local de FL-022 demuestra que CloudFormation puede administrar
exclusivamente el IdP Apple sobre el User Pool importado usando una referencia
dinámica a un secreto dedicado. El pool y el App Client móvil seguirían fuera
del stack. Se adopta esta ruta para evitar divergencia manual: no se debe crear
el IdP desde la consola ni combinar su alta con cambios de App Clients o
Registration Guards. Microsoft continúa como recurso externo preexistente y no
debe recrearse.

## Consecuencias y límites

- Tener Services ID, clave `.p8` y secreto no constituye evidencia de login
  Apple: falta crear el IdP mediante un Change Set aislado y ejecutar E2E.
- Los flags de Apple y Microsoft permanecen desactivados por defecto; conservar
  el código no constituye disponibilidad pública ni verificación E2E.
- No se despliega nada en Cognito sin `describe-user-pool` previo y sin
  confirmar que el cambio no recrea el pool.
