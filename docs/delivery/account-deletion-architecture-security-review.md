# STORE-02E-02 — Revisión de arquitectura y seguridad

> Revisión histórica previa a implementación (2026-10-20). El estado técnico y
> la evidencia DEV actuales están en
> [`store-02-account-deletion-closure.md`](store-02-account-deletion-closure.md).
> Las ADR-AD permanecen candidatas y D-13 continúa abierta.

- Fecha de corte: 2026-10-20
- Rama revisada: `feature/STORE-02/account-deletion`
- Estado: **revisión documental completada; ADR no aprobadas; sin implementación**
- Alcance: `ADR-AD-01`–`ADR-AD-05`, `AUT-19`, `AUT-21`, `INF-18`–`INF-21`,
  `RNF-09`, `RNF-10`, `RC-06`–`RC-09`, E-14 y D-13

Esta revisión contrasta las candidatas con el HEAD disponible al corte y con la
infraestructura CDK de ese momento. STORE-02E-02A/02B implementaron después
primitivas, ledger, guard, adaptador y un construct CDK aislados; la evidencia
posterior vive en `account-deletion-pseudonymous-identity.md` y
`account-deletion-ledger-guard.md`. No autoriza DDL, recursos AWS, triggers
Cognito, endpoints, wiring, borrados ni un cierre de D-13.

## 1. Evidencia comprobada en HEAD

| Frontera      | Evidencia actual                                                                                                                     | Consecuencia para Account Deletion                                                                |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| Identidad API | `authenticatedSubject()` acepta exclusivamente access token Cognito y devuelve `sub`                                                 | `sub` sigue siendo owner; la barrera no debe cambiar ownership a email                            |
| Provisión     | `PostgresFolooRepository.resolvePrincipal()` ejecuta directamente `ensure_personal_workspace(subject)`                               | Hoy una petición válida puede recrear user/account/workspace antes de cualquier check             |
| Rutas         | API JWT para `/v1`; callback OAuth de sender es público y resuelve owner desde `email_oauth_states`                                  | El guard de JWT no cubre por sí solo callbacks, replays ni estados ya emitidos                    |
| Cognito       | User Pool y App Client llegan al stack como IDs externos; CDK solo crea el JWT authorizer                                            | No existe trigger, ownership IaC ni permiso de invocación Cognito en este stack                   |
| PostgreSQL    | RDS PostgreSQL 16 privada; backup automático de 1 día, Single-AZ, deletion protection desactivada y `SNAPSHOT` al retirar el recurso | La propuesta de 15 días no está aplicada; snapshots manuales/finales requieren lifecycle separado |
| S3            | Bucket privado, cifrado, no versionado, `RETAIN`; ApiFunction solo posee Get/Put                                                     | No existe borrado físico, inventario de keys ni backup de 15 días de objetos                      |
| Red           | ApiFunction está en subred aislada, sin NAT; existen endpoints de S3, Secrets Manager y Lambda                                       | DynamoDB necesita gateway endpoint; Cognito/KMS no deben asumirse alcanzables desde esa Lambda    |
| Email         | Provider Lambda está fuera de VPC; callback consume state antes del intercambio y no consulta barrera                                | Debe verificarse owner antes de exchange/connect y sin volver reutilizable el state               |
| Trial         | El límite vive en `accounts`; Unlimited DEV evita consumo/bloqueo cuando su flag global está activo                                  | La barrera debe ejecutarse antes y de forma independiente del entitlement y de Unlimited          |
| Migraciones   | Runner ordenado con `schema_migrations`; ejecución manual mediante MigrationFunction                                                 | Las nuevas tablas PostgreSQL no se crean por deploy automático y no resuelven el ledger externo   |
| Cliente local | Drift contiene datos owner-scoped y algunas filas legacy nullable; filesystem usa `foloo_media`                                      | La purga integral sigue en `02E-05`; no debe preceder a la aceptación durable backend             |

## 2. Resultado por ADR candidata

### ADR-AD-01 · Autoridad durable de barrera y ledger

**Resultado: MODIFICAR antes de aprobar.** DynamoDB en la misma cuenta y región
es compatible con el patrón serverless actual y evita que un restore de RDS
borre la autoridad. Debe ser autoridad operativa, no solo una copia eventual.

La propuesta debe separar dos registros con vidas distintas:

1. `subject_hash`: tombstone del `sub` eliminado. No expira junto con el correo;
   debe conservarse al menos mientras cualquier backup/snapshot capaz de
   reintroducir ese owner exista. Su plazo final requiere Legal/Seguridad.
2. `registration_hash`: HMAC del correo usado únicamente para impedir un alta
   durante 30 días. `blockedUntil` es la condición autoritativa; TTL solo limpia
   después y nunca prolonga el bloqueo.

Una única expiración de 30 días sería insegura: permitiría un alta nueva, pero
también perdería la evidencia necesaria para filtrar el owner viejo en un
restore posterior. Las escrituras de aceptación deben ser condicionales e
idempotentes. PITR, cifrado, deletion protection, alarmas y runbook de restore
son parte de la decisión, no opcionales de operación.

**AWS/IAM mínimos propuestos:** tabla DynamoDB cifrada, PITR, TTL auxiliar,
gateway endpoint DynamoDB en la VPC; un rol de guard con solo
`GetItem`/`PutItem`/`UpdateItem`/`TransactWriteItems` sobre esa tabla y sin
`Scan`; alarmas/logs sin hashes. La ApiFunction debe invocar solo al guard o
recibir acceso puntual a la tabla, no permisos amplios. Se recomienda un
`AccountDeletionGuardFunction` separado para aislar HMAC/ledger y reutilizarlo
desde API y Cognito.

**Costo operativo, sin estimación monetaria:** requests y almacenamiento
DynamoDB, PITR/on-demand backups, invocaciones Lambda, logs y, según AD-02,
llave/operaciones KMS. El gateway endpoint DynamoDB no añade cargo. Deben
estimarse con volumen real antes de PROD.

**Fallos principales:** indisponibilidad del ledger, timeout entre escritura de
barrera y estado PostgreSQL, hot key/condicional concurrente, restore del
ledger a un punto anterior, TTL atrasado y rotación incompleta de HMAC.

### ADR-AD-02 · Identificador seudonimizado de 30 días

**Resultado: MODIFICAR antes de aprobar.** Se mantiene HMAC-SHA-256 versionado,
pero la especificación debe distinguir la fuente de cada comparación:

- al aceptar deletion, el registro se deriva del atributo `email` ya verificado
  server-side en Cognito;
- en `PreSignUp_SignUp`, Cognito aún no ha verificado el correo presentado. Ese
  valor puede compararse con un bloqueo creado desde un email verificado, pero
  no debe persistirse como identidad ni usarse para vincular cuentas;
- en `PreSignUp_ExternalProvider`, solo se acepta el atributo mapeado por el IdP
  cuando la configuración garantiza la señal correspondiente de verificación.

La canonicalización debe ser única y versionada. Como mínimo: trim definido,
normalización Unicode y dominio normalizado; no se deben inventar reglas de
alias como retirar puntos o `+tag`. El tratamiento de mayúsculas del local-part
requiere decisión de Seguridad/Producto y fixtures con email/password y Google.

**Recomendación:** llave HMAC no exportable en KMS y guard Lambda fuera de VPC,
salvo que Seguridad apruebe explícitamente una clave en Secrets Manager. KMS
requiere `kms:GenerateMac`/`kms:VerifyMac` solo sobre la llave HMAC; no usar la
llave de cifrado de tokens de email. La rotación debe comparar versiones aún
vigentes y tener un procedimiento de rehash, no eliminar la llave anterior
antes de agotar blockers.

**Costo operativo:** llave KMS administrada por cliente y operaciones MAC, o
secret/caché Lambda si se aprobara la alternativa menos aislada. No se almacena
correo en claro ni se usa como primary key.

### ADR-AD-03 · Prevención de identidades Cognito

**Resultado: MODIFICAR y condicionar a ownership IaC de Cognito.** AWS Cognito
invoca Pre Sign-up inmediatamente antes de crear usuarios locales y en el
primer acceso de un proveedor federado; por tanto cubre email/password y Google.
Sin embargo, dos capas no bastan para todos los estados:

1. `PreSignUp_SignUp` y `PreSignUp_ExternalProvider` consultan
   `registration_hash` y rechazan mientras `now < blockedUntil` con mensaje no
   enumerativo.
2. Pre Authentication o una deshabilitación/global sign-out inmediata evita
   nuevos tokens si la eliminación Cognito final todavía no concluyó.
3. El guard backend por `subject_hash` rechaza tokens antiguos, callbacks y
   cualquier bypass aun si Cognito sigue disponible.

El stack actual **no administra el User Pool**. Antes de programar triggers,
Infra debe decidir si lo incorpora de forma segura a IaC o mantiene un runbook
auditado que preserve toda la LambdaConfig existente. Crear la Lambda en CDK no
la conecta automáticamente. Además se requiere resource policy
`lambda:InvokeFunction` limitada al User Pool y validación de `userPoolId`,
`clientId` y trigger source dentro del handler.

La revisión posterior confirma que `AWS::Cognito::UserPool` admite importación
manual de CloudFormation, pero no drift detection. Un import exige declarar el
pool completo con `DeletionPolicy`/`UpdateReplacePolicy: Retain`, partir de un
stack sin cambios pendientes y ejecutar una operación de importación aislada:
no puede mezclarse con altas, bajas o actualizaciones. La plantilla debe
reproducir exactamente `DescribeUserPool`, incluida schema, username/alias,
políticas, recuperación, correo, MFA, protección contra borrado y toda la
`LambdaConfig`; los App Clients, IdP, dominio y branding continúan como recursos
separados. Una omisión o normalización incorrecta puede cambiar autenticación,
mensajería o triggers, y algunas propiedades de identidad son inmutables.

**Dictamen de ownership:** técnicamente viable, pero no apto para el siguiente
Change Set de activación. Primero se requiere una operación exclusiva de import
auditada, respaldo del template/payload efectivo, comparación propiedad por
propiedad y autorización de Infra. El rollback seguro es conservar el recurso y
retirarlo del stack solo mediante el proceso de retain/import correspondiente;
nunca reemplazar el pool ni recrear usuarios. Como alternativa DEV, un
`UpdateUserPool` puntual puede conectar triggers, pero debe construirse desde
la configuración efectiva completa y tener payload inverso probado, porque la
API restablece a defaults parámetros omitidos. Esa alternativa no ofrece
ownership ni drift de CloudFormation y requiere autorización separada.

El trigger debe fallar cerrado cuando no pueda comprobar un blocker, con
timeouts breves, alarma y copy genérico. Esto puede degradar temporalmente
nuevos registros, pero no crea un bloqueo permanente: `blockedUntil` se evalúa
en código aunque TTL no haya eliminado el item. Google existente no debe
vincularse por email. Microsoft Sign-In permanece fuera de alcance.

**Costo operativo:** invocaciones/logs Lambda, lecturas DynamoDB y MAC; no hay
precio nuevo atribuible al trigger que pueda fijarse sin volumen y plan Cognito.

### ADR-AD-04 · Barrera antes de `ensure_personal_workspace`

**Resultado: APROBAR CON MODIFICACIONES obligatorias.** La frontera es viable,
pero no debe limitarse a envolver el método actual:

- el router/API aplica el guard por `sub` antes de cualquier application call;
- `resolvePrincipal()` conserva una comprobación defensiva antes de ejecutar
  `ensure_personal_workspace`;
- callbacks OAuth consultan el owner del state antes de `exchange_code` y
  `connect`; el state no debe consumirse de forma que permita un retry inseguro;
- replays, pulls, presigned URLs y futuros workers usan la misma puerta;
- `account_deletion_pending` se incorpora al envelope estable sin filtrar
  email, hash, estado interno ni existencia previa.

La aceptación escribe primero la barrera externa. Después marca la cuenta en
PostgreSQL como `deletion_pending`; si la segunda operación falla, se mantiene
el bloqueo seguro y se reconcilia, nunca se elimina la barrera. Como DynamoDB y
PostgreSQL no comparten transacción, hace falta una state machine/idempotency
key y un reconciliador.

Para cerrar la carrera con operaciones iniciadas antes de la aceptación, las
mutaciones deben comprobar el estado de cuenta dentro de su transacción y el
worker debe esperar una ventana de quiescencia antes de borrar. Aceptar deletion
es el punto que bloquea operaciones nuevas; no se debe prometer que una request
ya en vuelo desaparece sin una política explícita.

**Conflictos evitados:** el guard corre antes del trial y del flag Unlimited,
por lo que ninguno puede saltarlo. No modifica `sub` como owner ni concede PRO.

**Costo operativo:** una invocación/consulta de guard por operación protegida,
latencia de red interna, métricas y logs. El caché positivo no es aceptable para
mutaciones porque abriría una ventana después de aceptar deletion; cualquier
caché negativo exige TTL y threat model explícitos.

### ADR-AD-05 · Restore sin resurrección y backups

**Resultado: MODIFICAR antes de aprobar.** El patrón traffic gate +
reconciliación es viable, pero el estado actual no satisface 15 días:

- CDK configura solo 1 día de automated backups de RDS;
- `RemovalPolicy.SNAPSHOT` puede producir snapshots sin expiración automática;
- snapshots manuales también necesitan inventario/lifecycle;
- S3 no tiene versionado ni política de backup de 15 días;
- Cognito y el ledger tienen ciclos de recuperación distintos.

RDS admite 15 días y un restore crea otra instancia. El runbook recomendado es:

1. cerrar ingreso y pausar callbacks/workers;
2. restaurar a una instancia nueva, nunca abrirla directamente al tráfico;
3. mantener el ledger actual como autoridad (no restaurarlo al mismo punto que
   RDS);
4. comparar cada `cognito_subject` restaurado mediante el guard/HMAC y purgar o
   poner en cuarentena owners con tombstone;
5. reaplicar `deletion_pending`, validar conteos/fixtures y obtener aprobación
   dual;
6. cambiar tráfico solo después de evidencia y conservar rollback controlado.

Un restore DynamoDB también crea una tabla nueva y no restaura TTL, PITR,
streams, tags, alarmas ni deletion protection. Nunca debe reemplazar el ledger
activo sin merge/reconciliación. `blockedUntil` evita que un registro de correo
ya expirado en una copia restaurada extienda los 30 días.

Legal/Infra deben definir qué significa “backup ordinario 15 días”: RDS, S3,
snapshots finales/manuales y exports. Si el plazo pretende cubrir todos los
datos, la configuración actual de S3 no lo implementa. Los costes variables son
retención/restore RDS, backup S3 si se incorpora, PITR DynamoDB y pruebas
periódicas; deben calcularse con inventario/tamaño real.

Fuentes AWS consultadas: [Pre Sign-up y federación](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-pre-sign-up.html),
[retención RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithAutomatedBackups.BackupRetention.html),
[TTL DynamoDB](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TTL.html),
[restore PITR DynamoDB](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/PointInTimeRecovery.Tutorial.html)
y [gateway endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html).

## 3. Arquitectura recomendada

```text
Cognito PreSignUp ───────────────┐
                                 v
API/Callback -> Guard Lambda -> KMS HMAC -> DynamoDB ledger
                   |                 |
                   | allow           | subject tombstone + 30-day blocker
                   v                 |
            PrincipalResolver        |
                   v                 |
      PostgreSQL operational fence <-┘
                   |
             deletion workflow
          DB / S3 / OAuth / Cognito
```

El guard Lambda es una recomendación concreta, todavía no una ADR aceptada. Su
API interna debe ser cerrada y tipada (`checkSubject`, `checkRegistration`,
`acceptBarrier`, `reconcile`), sin devolver hashes. La ApiFunction ya dispone de
un endpoint privado Lambda; puede recibir únicamente `lambda:InvokeFunction`
sobre este guard. El trigger Cognito invoca el mismo artefacto mediante permiso
resource-based. El guard accede a DynamoDB/KMS con privilegio mínimo.

### Regla de 30 días validada

| Momento/canal                           | Resultado requerido                                                                                      |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Cuenta eliminada, token viejo           | `subject_hash` bloquea API aunque Unlimited esté activo                                                  |
| Email/password antes del día 30         | Pre Sign-up compara candidato y rechaza genéricamente                                                    |
| Google antes del día 30                 | primer acceso federado compara atributo mapeado y rechaza; no crea/linkea perfil                         |
| Ledger/TTL retrasado después del día 30 | `blockedUntil <= now` permite el alta aunque el item siga presente                                       |
| Alta después del día 30                 | Cognito emite `sub` nuevo; backend crea account/workspace nuevos; no restaura datos/PRO                  |
| Restore posterior                       | tombstone del `sub` viejo sigue filtrando sus datos; blocker de email expirado no afecta la cuenta nueva |
| Error del ledger                        | no se crea identidad ni workspace; alarma/retry evita convertirlo en bloqueo permanente silencioso       |

La concesión o no de un trial nuevo después de 30 días permanece pendiente de
FL-021. La barrera no consulta ni modifica `trial_leads_used`.

## 4. IAM mínimo por componente

| Componente                   | Permisos nuevos propuestos                                                     | Prohibiciones explícitas                              |
| ---------------------------- | ------------------------------------------------------------------------------ | ----------------------------------------------------- |
| Guard Lambda                 | operaciones item-scoped DynamoDB; `kms:GenerateMac`/`VerifyMac`; logs          | sin Scan/export, sin RDS/S3, sin borrar Cognito       |
| ApiFunction                  | `lambda:InvokeFunction` solo Guard; DB actual                                  | sin DynamoDB/KMS directo si se adopta guard aislado   |
| Cognito                      | resource policy para invocar Guard desde User Pool exacto                      | ningún wildcard de principal/source ARN               |
| Deletion orchestrator futuro | invocar workers exactos y escribir estado/request                              | sin credenciales DB/S3/Cognito directas               |
| DB worker futuro             | Secrets scoped + conexión DB                                                   | sin S3/Cognito/KMS email                              |
| S3 worker futuro             | List/Get/Delete solo prefijo derivado server-side del owner                    | sin bucket wildcard ajeno ni key recibida del cliente |
| Cognito finalizer futuro     | AdminDisableUser, AdminUserGlobalSignOut y AdminDeleteUser en User Pool exacto | sin crear/linkear usuarios                            |
| Restore reconciler           | lectura ledger y acceso DB restaurada temporal                                 | sin abrir tráfico ni mutar ledger autoritativo        |

Los permisos destructivos pertenecen a `02E-04`, no al primer incremento de
`02E-02`.

## 5. Plan verificable de STORE-02E-02

| Paso | Cambio futuro (no ejecutado)                                                           | Prueba/gate                                                                              | Reversión segura                                            |
| ---- | -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| 0    | Aprobar threat model, AD-01–05 modificadas, fuente/canonicalización y scope de backups | actas Seguridad/Infra/Legal; D-13 sigue abierta hasta completar sus puntos               | no iniciar código                                           |
| 1    | Implementar canonicalizador/HMAC y modelo ledger como librería pura                    | vectores ES/EN/Unicode/case; ninguna PII en logs/snapshots                               | retirar módulo sin impacto runtime                          |
| 2    | Añadir DynamoDB/KMS/Guard/endpoint como recursos inactivos, sin triggers ni rutas      | CDK synth/diff, IAM assertions, PITR/deletion protection/alarms                          | rollback de recursos vacíos según retention aprobada        |
| 3    | Probar Guard directamente con cuentas sintéticas y tiempos controlados                 | concurrencia, conditional writes, día 29/30/31, TTL atrasado, rotación                   | deshabilitar invocador; conservar evidencia sintética       |
| 4    | Añadir estado PostgreSQL `deletion_pending` y migración aditiva, sin borrado           | migration contract, rerun, locks, registros existentes                                   | código compatible hacia atrás; no drop/rollback destructivo |
| 5    | Integrar guard previo a resolver y callbacks detrás de flag interno DEV default off    | todas las rutas, callback antes de exchange, token viejo, fallo ledger, Unlimited on/off | flag off restaura tráfico; no elimina ledger                |
| 6    | Incorporar Pre Sign-up/Pre Authentication solo tras resolver ownership Cognito         | email/password, Google, IdP attrs, generic error, timeout/fail-closed                    | desacoplar trigger preservando backend guard                |
| 7    | Ejecutar simulación de restore a recursos nuevos con traffic gate                      | owner viejo ausente, owner nuevo intacto, blocker expirado no bloquea                    | abandonar recursos restaurados; producción no cambia        |
| 8    | Promover barrera en DEV y observar; **sin endpoint de eliminación real**               | métricas, alarmas, latencia, falsos positivos, runbook                                   | disable flag/trigger; no borrar usuarios/datos              |

Módulos futuros previstos: `backend/infra/foloo_backend_stack.ts`, nueva
frontera `backend/src/account_deletion/`, `authenticated_identity.ts`,
`router.ts`, `lambda.ts`, `postgres_repository.ts`, `email_application.ts`, una
migración aditiva posterior a `008`, tests de infraestructura/seguridad/
migración/callback/restore y runbooks. Flutter, workers destructivos y web no
pertenecen a este incremento.

## 6. Pruebas mínimas antes de habilitar

- Unitarias: canonicalización versionada, HMAC sin PII, expiración exacta,
  rotación y error estable.
- Infra: tabla cifrada/PITR/deletion protection, endpoint DynamoDB, IAM sin
  wildcards y Cognito source ARN/account.
- Concurrencia: confirmaciones dobles, request frente a aceptación, fallo entre
  ledger y PostgreSQL y reconciliación idempotente.
- Auth: email/password y Google antes/después del día 30, usuario Cognito
  parcialmente eliminado, token antiguo y Google sin atributo verificable.
- Backend: ninguna ruta llama `ensure_personal_workspace` si el guard deniega;
  callback no intercambia código ni conecta; Unlimited no altera el resultado.
- Restore: RDS a instancia nueva, ledger vigente, owner viejo purgado, alta
  posterior con nuevo `sub` y cero datos/entitlement heredado.
- Resiliencia: TTL atrasado, KMS/Dynamo timeout, clave en rotación, alarmas y
  logs sin email/sub/hash/token.

No se autorizan pruebas destructivas con cuentas reales. La ejecución en DEV
requiere fixtures sintéticos y aprobación por corrida.

## 7. Riesgos y aprobaciones pendientes

| Owner         | Decisión bloqueante                                                                                                                     |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Seguridad     | HMAC/canonicalización/fuentes de email; KMS; retención del tombstone de subject; fail-closed; trigger validation; threat model          |
| Infra         | ownership/configuración del User Pool; DynamoDB/PITR/alarms; RDS 15 días; snapshots manuales/finales; S3 backup; RTO/RPO; restore drill |
| Legal/Privacy | alcance exacto de backups ordinarios; retención de hashes/receipts; legal holds; datos de terceros y regiones                           |
| Producto      | copy genérico de bloqueo; comportamiento temporal ante caída; trial nuevo después de 30 días (con FL-021)                               |
| Operación     | owner de alertas, retry budgets, escalamiento, dual approval para restore y plazo de soporte                                            |

## 8. Recomendación ejecutiva

- `ADR-AD-04`: aprobar solo con las modificaciones de callback, fence DB,
  reconciliación y carrera documentadas.
- `ADR-AD-01`, `02`, `03` y `05`: devolver para incorporar los cambios de esta
  revisión; no rechazarlas porque el patrón es compatible con Foloo.
- Implementar primero componentes inertes y pruebas del guard; no habilitar
  eliminación, Pre Sign-up ni bloqueo global hasta validar la cadena completa.
- Mantener `ADR-AD-06`, D-13, STORE-02E-03 y todo borrado real bloqueados.
