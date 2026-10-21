# STORE-02E-02B — Ledger y guard aislados

- Fecha: 2026-10-20
- Estado: **incremento preparatorio implementado; inactivo y no desplegado**
- Trazas: `AUT-21`, `INF-18`, `INF-20`, `INF-21`, `RNF-09`, `RNF-10`,
  E-14, `AD-T-17`, `AD-T-18`, `AD-T-24`–`AD-T-26`, `AD-T-30`–`AD-T-32`
- Decisiones: `ADR-AD-01`–`ADR-AD-05` continúan candidatas; D-13 abierta

Este incremento materializa contratos y adaptadores aislados para probar la
separación entre el bloqueo temporal por correo y el tombstone durable por
`sub`. No habilita Account Deletion, no cambia el runtime actual y no crea
recursos AWS.

## Componentes implementados

### Identidad seudonimizada

`pseudonymous_identity.ts` conserva sin cambios la política provisional de
correo `foloo-email-v1-provisional` y agrega
`PseudonymousSubjectIdentifierService` con domain separation
`foloo-cognito-sub-v1`. El `sub` no se normaliza ni se convierte de case: el
caller debe entregar exactamente el claim canónico verificado que Foloo usa
como owner. Correo y subject producen namespaces y digests distintos.

La evidencia de `email_verified` y la autenticidad de `sub` siguen siendo
precondiciones de una frontera server-side futura. El guard aislado no puede
demostrarlas por sí solo.

### Contrato de ledger

`account_deletion_ledger.ts` define:

- `registration blocker`: HMAC de email + `blockedUntil`, autoritativo por
  comparación lógica durante 30 días;
- `subject tombstone`: HMAC de `sub`, estado `pending|deleted`, sin TTL;
- request durable: referencia de idempotencia entre ambos registros;
- aceptación atómica e idempotente y transición atómica a `deleted`.

El día 30 exacto permite registro (`now >= blockedUntil`). El TTL es solo
limpieza del blocker y no participa en la decisión. El tombstone no expira con
el blocker.

### Adaptador DynamoDB

`dynamodb_account_deletion_ledger.ts` implementa el contrato mediante lecturas
consistentes y `TransactWriteItems`:

1. una transacción crea request, tombstone y blocker;
2. conditions impiden reutilizar `deletionId`, subject o email todavía
   bloqueado por otra solicitud;
3. una carrera de la misma solicitud se resuelve como idempotente después de
   releer el request;
4. una transición modifica request y tombstone juntos;
5. no se persisten correos ni subjects en claro.

Errores de almacenamiento no se convierten en permiso. La capa guard devuelve
un error genérico fail-closed, sin copiar PII ni el error interno.

### AccountDeletionGuard

`account_deletion_guard.ts` expone decisiones `active`, `deletion_pending`,
`deleted` y `registration_blocked`. Lee todas las versiones HMAC configuradas y
escribe solo con la versión activa, preparando rotación sin reinterpretar
digests existentes. También crea la barrera de 30 días y marca el tombstone
como eliminado, siempre a través del contrato de ledger.

El router reconoce el namespace STORE-02 mediante un controller fail-closed.
El stack prepara variables e IAM para ledger/HMAC/queue, pero la composición
activa no se construye mientras el flag siga en `false`. No hay guard activo
en `PrincipalResolver`, Cognito ni sincronización, y trial/PRO/Unlimited QA no
cambian.

## Infraestructura preparada pero inactiva

`account_deletion_ledger_infrastructure.ts` se instancia ahora en el template
DEV, pero no ha sido desplegado. Define:

- tabla on-demand con PK seudonimizada;
- cifrado administrado por AWS, PITR, TTL auxiliar, deletion protection y
  `RETAIN`;
- llave KMS HMAC-256 dedicada y permisos `GenerateMac`/`VerifyMac`;
- cola FIFO, DLQ cifrada, cinco reintentos y alarma de mensajes fallidos;
- alarmas de system errors y throttling;
- grants item-scoped sin `Scan` ni borrado de ledger.

El stack incorpora endpoints privados DynamoDB, KMS y SQS, worker en VPC y un
finalizador Cognito fuera de VPC con IAM limitado al User Pool. Todos conservan
`FOLOO_ACCOUNT_DELETION_ENABLED=false`; el worker devuelve fallos parciales y
el finalizador rechaza llamadas si una entrega accidental ocurre. Falta aprobar
destinos de alarma, tags, budgets y la composición destructiva final.

Las dependencias AWS DynamoDB/KMS/SQS/Lambda/SES están justificadas por `INF-18`,
`INF-20` e `INF-21`: ningún cliente existente implementa transacciones y
lecturas consistentes DynamoDB. Agregarla no incorpora el adaptador al bundle
de ninguna Lambda mientras no exista un import desde un entry point.

## Cobertura sintética

- día 29 bloqueado; día 30 exacto y día 31 permitidos;
- estados pending/deleted y restauración simulada de datos operativos viejos;
- solicitudes repetidas y concurrentes;
- conflicto de email activo;
- fallos DynamoDB/HMAC fail-closed sin PII;
- lectura multiversión durante rotación HMAC;
- escritura/lectura/transición DynamoDB e idempotencia tras carrera;
- cifrado/PITR/TTL/deletion protection/alarmas/IAM mínimo en synth;
- composición inactiva en el stack e independencia de trial/Unlimited;
- cifrado KMS del destinatario SES y purga tras confirmación final;
- migración 009 con barrera anterior a provisioning y restore sintético.

Todas las identidades y llaves de prueba son sintéticas.

## Riesgos y aprobaciones pendientes

- Seguridad: canonicalización provisional del local-part, evidencia exacta de
  `email_verified`, confianza del claim `sub`, custodia/rotación KMS HMAC,
  límites de versiones y threat model fail-closed.
- Infra/Operación: propiedad IaC, endpoint DynamoDB, alarm routing, PITR,
  restore/reconciliación, SLO y coste con volumen real.
- Legal: retención final del tombstone y del ledger; D-13 continúa abierta.
- Arquitectura: decidir si el guard vive en Lambda separada o en una frontera
  compartida y aprobar AD-01–AD-05 modificadas.
- Runtime: el wiring API/OAuth/sync/worker está preparado detrás de flag; el
  trigger PreSignUp no está adjunto porque email/password no aporta evidencia
  verificada en ese punto. Falta aprobación para activarlo.

## Próximo incremento recomendado

Antes de conectar cualquier flujo, aprobar las ADR modificadas y ejecutar una
revisión de Seguridad/Infra del modelo de tabla, KMS HMAC, fail-closed y
restore. Después, un incremento aislado puede implementar los adaptadores KMS
y el handler de guard con fixtures locales, todavía sin asociarlo a Cognito ni
al router. La conexión a runtime debe recibir autorización separada.

## Vertical funcional local preparado en STORE-02

Sobre los contratos aislados anteriores se preparó una vertical comprobable
con datos sintéticos, todavía **inactiva**:

- workflow reanudable con preflight, reautenticación reciente, aceptación
  irreversible, barrera durable, estados, reintentos y verificación final;
- controllers para las rutas del contrato OpenAPI y controller fail-closed que
  responde `503` mientras el feature permanece apagado;
- ejecutor por etapas `OAuth -> S3 -> PostgreSQL -> Cognito`, con checkpoints;
- adaptadores no conectados para inventariar/borrar exclusivamente el grafo
  personal del owner en PostgreSQL y las llaves exactas inventariadas en S3;
- correos ES/EN de recepción y finalización mediante un puerto simulado;
- interfaz Flutter ES/EN, preflight, advertencia de outbox, consentimiento
  irreversible y purga local selectiva por owner;
- interfaz de suscripción que bloquea una cuenta PRO cuando Stripe no está
  disponible, en vez de simular una cancelación exitosa.

No se creó migración PostgreSQL: la persistencia durable del proceso pertenece
al ledger externo propuesto y el adaptador PostgreSQL usa el esquema vigente.
El store del workflow es únicamente in-memory para pruebas y no es apto para
Lambda. La ruta pública `foloo.io/delete-account` conserva el contrato del mismo
backend, pero no se implementó una segunda web ni se modificó la landing porque
su repositorio/operación no forma parte de este checkout.

### Barreras de activación en AWS DEV

`FOLOO_ACCOUNT_DELETION_ENABLED` vale `false` por defecto y CDK lo fija en
`false`. La Lambda rechaza el arranque si alguien intenta cambiarlo a `true`
antes de sustituir la composición deshabilitada. El drawer Flutter también
permanece oculto con `FOLOO_ACCOUNT_DELETION_ENABLED=false`.

Antes de una prueba destructiva con una identidad QA sintética se requieren,
como mínimo:

1. aprobación de Seguridad para canonicalización, ventana de reautenticación,
   custodia/rotación KMS HMAC y política de recibos;
2. aprobación e instanciación CDK del ledger DynamoDB, endpoint VPC, alarmas e
   IAM mínimo;
3. desplegar los stores durables, worker/DLQ y migración 009 todavía inactivos;
4. aprobar KMS/canonicalización y revisar consultas owner-scoped PostgreSQL/S3;
5. verificar `foloo.io` en SES, salida de sandbox y `hello@foloo.io`;
6. aprobar attachment Cognito PreSignUp y el tratamiento de email/password;
7. adaptador Stripe real para cuentas PRO, o una política aprobada que bloquee
   explícitamente esas solicitudes;
8. revisión de `cdk synth`/`cdk diff`, despliegue inicial con ambos flags
   apagados, smoke tests no destructivos y autorización separada para habilitar
   exclusivamente AWS DEV.

D-13 y ADR-AD-01–ADR-AD-05 permanecen abiertas. Ningún componente nuevo está
autorizado para datos reales ni modifica Trial, PRO o Unlimited QA.
