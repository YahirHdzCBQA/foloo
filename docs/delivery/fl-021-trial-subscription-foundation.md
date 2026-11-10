# FL-021 · Trial & Subscription Foundation

## Alcance y trazas

Implementa `MON-01`–`MON-12`, `MON-21`–`MON-22` y E-11. FREE y PRO tienen
las mismas capacidades; el único cambio es si una cuenta puede crear más de
cinco Leads históricos. Stripe, checkout y activación por pago pertenecen a
FL-022 y no se activan con esta entrega.

La preautorización aprobada puede existir antes de Cognito como selector HMAC
KMS del correo canónico. `PostAuthentication` encola únicamente el `sub`; un
worker privado vuelve a resolver en Cognito la identidad habilitada y el correo
verificado antes de consumir el selector y conceder PRO transaccionalmente. No
se persisten correos en claro, no se vinculan identidades y un relay Apple
distinto no coincide.

## Componentes

- La migración `012_trial_subscription_foundation.sql` añade fuentes de
  entitlement, grants administrativos auditables y un evento durable único
  para el quinto Lead.
- La migración aditiva `013_fl021_entitlement_preauthorizations.sql` añade
  preautorizaciones, origen `manual|preauthorization`, auditoría de
  consumo/excepción e invalidación restringida por la barrera STORE-02D.
- La migración aditiva
  `014_fl021_account_deletion_preauthorization_invalidation.sql` amplía esa
  invalidación a selectores activos y consumidos. STORE-02D resuelve primero
  el mismo `sub` en Cognito, exige correo verificado y deriva con KMS cada
  versión vigente/retenida; Cognito, KMS o PostgreSQL indisponibles bloquean el
  checkpoint de borrado de forma reintentable y sin registrar correo o HMAC.
- `AdministrativeEntitlementService` resuelve primero una identidad Cognito
  verificada. Grant y revocación serializan la cuenta, son idempotentes y
  preservan `trial_leads_used` y el estado FREE exacto anterior. Solo
  `trial`/`trial_exhausted` sin vínculos Stripe admiten grant; `legacy_active`,
  Stripe e inconsistencias fallan cerrados.
- La migración crea el rol NOLOGIN `foloo_entitlement_admin`, retira a
  `foloo_app` todo acceso a grants/auditoría y deja en eventos 5/5 únicamente
  `SELECT`/`INSERT`/`UPDATE`. El operador conecta con el login dedicado
  `foloo_entitlement_operator`, respaldado por un secreto independiente, cambia
  a ese rol estrecho con `SET LOCAL ROLE` y obtiene su actor desde AWS STS. No
  recibe credenciales de administración RDS ni las usadas por la API.
- STORE-02D exige cancelación solo para `entitlement_source=stripe` con customer
  y subscription coherentes. PRO administrativo no invoca Stripe.
- `PostgresFolooRepository.createLead` genera el hito dentro de la misma
  transacción e idempotency key que acepta el quinto Lead.
- `TrialMilestoneNotificationWorker` usa claim transaccional, clave estable y
  retry. Su modo predeterminado es `disabled`; no se integra con SES ni incluye
  CTA mientras Producto no apruebe contenido, URL y comunicaciones.
- Flutter muestra FREE/PRO en Mi perfil y Drawer. El modal 5/5 aparece solo
  cuando el backend confirma el hito; una captura offline espera al sync.

El inventario aprobado de direcciones no se guarda en código. Un operador
suministra una dirección por operación privada; `preauthorize` persiste solo su
HMAC aun si Cognito todavía no contiene la cuenta. `grant` continúa exigiendo
un `sub` habilitado, confirmado y verificado. Ninguna operación imprime correo,
`sub` o selector.

El comando privado recibe `DB_ENTITLEMENT_OPERATOR_SECRET_ARN`, `DB_HOST`,
`DB_NAME`, `COGNITO_USER_POOL_ID`, `AWS_REGION`,
`ENTITLEMENT_PREAUTHORIZATION_HMAC_KEY_ARN`, `FOLOO_ENTITLEMENT_EMAIL`,
`FOLOO_ADMIN_REASON` y `FOLOO_ENTITLEMENT_ACTION`. No acepta actor libre ni
`DATABASE_URL`: requiere `sts:GetCallerIdentity`, lectura del secreto
operativo y `cognito-idp:ListUsers` limitado al pool aprobado. Identidades
nativas confirmadas y padres federados verificados de Google/Apple son válidos;
Microsoft y proveedores desconocidos fallan cerrados.

## Despliegue pendiente de autorización

1. Probar 013 y 014 en PostgreSQL 16 descartable, respaldar y verificar
   PostgreSQL y ejecutarlas en orden después de 012. El runner mantiene
   un advisory lock, `lock_timeout=5s` y registra DDL+migración en una única
   transacción. No hay downgrade destructivo automático.
2. Desplegar API/backend manteniendo la notificación promocional en
   `disabled` y sin cambiar Unlimited QA.
3. Desplegar Flutter y comprobar etiquetas, captura 1–5, bloqueo del sexto,
   conservación del borrador y aparición 5/5 tras sync.
4. Desplegar primero la superficie administrativa con rol dedicado, MFA y
   CloudTrail; cargar las preautorizaciones una por una y comprobar que no se
   creen grants. Después desplegar SQS/KMS/worker pasivos y activar por separado
   enqueue y consumo.
5. Solo en una entrega posterior, integrar el mailer y cambiar el modo después
   de aprobar plantilla y destino. El evento pendiente permite procesar hitos
   existentes sin repetirlos.

## Rollback y recuperación

- App/backend pueden volver a la versión anterior sin borrar las tablas
  aditivas. La migración no se revierte con `DROP`; se hace rollback de código
  y reconciliación forward-only.
- Desplegar 014 antes que el worker actualizado. Mientras el runtime anterior
  siga activo, 014 conserva la función de 013; el runtime nuevo utiliza solo la
  función versionada que invalida activos y consumidos.
- Deshabilitar el worker detiene entregas sin afectar Leads ni eventos.
- Revocar un grant administrativo restaura FREE usando el contador histórico;
  restaura exactamente `trial` o `trial_exhausted`, no borra datos ni devuelve
  cupos. Entitlements heredados o Stripe nunca se sobrescriben.
- Si el quinto Lead fue aceptado pero el proveedor falla, el evento queda
  `failed` y reintentable. Nunca se revierte el Lead.

## Pendientes que bloquean activación externa

- Aprobar el rol/entorno operativo que podrá ejecutar el comando de grants.
- Contenido final ES/EN, requisitos de comunicación y URL válida del CTA.
- Adaptador SES con deduplicación verificable y observabilidad. El worker y la
  plantilla local no equivalen a entrega real.
- Migración y QA remotos requieren autorización separada.
