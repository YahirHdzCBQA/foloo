# FL-021 · Trial & Subscription Foundation

## Alcance y trazas

Implementa `MON-01`–`MON-12`, `MON-21`–`MON-22` y E-11. FREE y PRO tienen
las mismas capacidades; el único cambio es si una cuenta puede crear más de
cinco Leads históricos. Stripe, checkout y activación por pago pertenecen a
FL-022 y no se activan con esta entrega.

## Componentes

- La migración `012_trial_subscription_foundation.sql` añade fuentes de
  entitlement, grants administrativos auditables y un evento durable único
  para el quinto Lead.
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

La lista de siete identidades aprobadas no se guarda en código. La octava no se
crea ni se presupone. Un operador futuro suministra una identidad por operación
y `npm run entitlement:admin` la vincula a un `sub` habilitado, confirmado y
verificado. El comando no imprime correo ni `sub`.

El comando privado recibe `DB_ADMIN_SECRET_ARN`, `DB_HOST`, `DB_NAME`,
`COGNITO_USER_POOL_ID`, `AWS_REGION`, `FOLOO_ENTITLEMENT_EMAIL`,
`FOLOO_ADMIN_REASON` y `FOLOO_ENTITLEMENT_ACTION`. No acepta actor libre ni
`DATABASE_URL`: requiere `sts:GetCallerIdentity`, lectura del secreto
administrativo y `cognito-idp:ListUsers` limitado al pool aprobado. Identidades
nativas confirmadas y padres federados verificados de Google/Apple son válidos;
Microsoft y proveedores desconocidos fallan cerrados.

## Despliegue pendiente de autorización

1. Probar 012 en PostgreSQL 16 descartable, respaldar y verificar PostgreSQL y
   ejecutar primero la migración 012 en el entorno aprobado. El runner mantiene
   un advisory lock, `lock_timeout=5s` y registra DDL+migración en una única
   transacción. No hay downgrade destructivo automático.
2. Desplegar API/backend manteniendo la notificación promocional en
   `disabled` y sin cambiar Unlimited QA.
3. Desplegar Flutter y comprobar etiquetas, captura 1–5, bloqueo del sexto,
   conservación del borrador y aparición 5/5 tras sync.
4. Ejecutar la superficie administrativa solo desde el entorno operativo
   privado con permisos mínimos Cognito y acceso PostgreSQL. Auditar actor,
   motivo, cuenta y resultado. No se precargan las siete cuentas.
5. Solo en una entrega posterior, integrar el mailer y cambiar el modo después
   de aprobar plantilla y destino. El evento pendiente permite procesar hitos
   existentes sin repetirlos.

## Rollback y recuperación

- App/backend pueden volver a la versión anterior sin borrar las tablas
  aditivas. La migración no se revierte con `DROP`; se hace rollback de código
  y reconciliación forward-only.
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
