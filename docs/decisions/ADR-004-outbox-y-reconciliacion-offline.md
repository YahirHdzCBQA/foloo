# ADR-004 — Outbox persistente y reconciliación offline-first

- Estado: **Aceptado**
- Fecha: 2026-09-09
- Alcance: FL-015/FL-017, motor de sincronización móvil Foloo V1
- Trazas: `SYN-04`–`SYN-10`, `REG-07`, `RNF-07`, E-06 y E-09

## Contexto

Drift ya confirma el guardado local antes de cualquier red y FL-014 ofrece
creaciones idempotentes con UUID local. Faltaba decidir cómo sobrevivir cortes,
reintentos, cambio de usuario y reconciliación sin que una respuesta perdida
duplique datos o que un pull destruya trabajo local pendiente.

## Decisión

- Cada mutación soportada guarda entidad y operación outbox en una misma
  transacción Drift. La operación conserva `operationId`, `ownerSub`, entidad,
  acción, snapshot JSON sin binarios, clave de idempotencia, intentos y próximo
  intento.
- Un retry reutiliza siempre la misma clave. El procesamiento es serial y ordena
  perfil, eventos, leads y metadata de medios. Además verifica dependencias:
  un Lead de evento espera a que cierre la creación del evento y una metadata
  de medio espera a que cierre la creación del Lead.
- Timeout, transporte, 408, 429 y 5xx son reintentables con backoff exponencial
  acotado a una hora; `Retry-After` puede ampliar el plazo. Un trigger automático
  ordinario respeta ese plazo; recuperar conectividad o pedir sincronización
  manual fuerza un intento inmediato de lo reintentable sin cambiar su clave de
  idempotencia. Errores 4xx restantes son fallos permanentes de contrato, no se
  reintentan ciegamente y nunca eliminan el dato local.
- Si iOS anuncia conectividad antes de que la ruta sea realmente utilizable, el
  fallo de transporte programa un único timer al siguiente backoff; no necesita
  una segunda señal del sistema ni polling continuo.
- La sesión se consulta al ejecutar. Sin token vigente o si el `sub` no coincide,
  no se consume la cola. Tokens y binarios nunca entran en SQLite.
- El pull usa los listados completos disponibles. Solo aplica un objeto remoto
  cuando esa entidad no tiene una operación local abierta; no borra filas locales
  ausentes del listado remoto. Los UUID locales son también IDs cloud.
- La presencia remota del mismo UUID confirma una creación cuya respuesta pudo
  perderse: cierra esa operación sin sobrescribir los campos locales. El estado
  visible conserva por separado la creación del Lead y el trabajo de medios.
- Metadata remota de medios solo confirma filas locales existentes. Crear una
  fila de media sin archivo sería engañoso antes de FL-016.
- FL-017 agrega `PUT /v1/leads/{leadId}` con el número `revision` esperado.
  Una edición se guarda primero junto con su outbox; un `revision_conflict` no
  reemplaza ni duplica el Lead, queda visible como conflicto y conserva el
  snapshot local. Solo una sincronización manual explícita consulta la revisión
  remota, rearma esa misma operación/clave y vuelve a intentar el cambio local.
- La estabilización de FL-017 integra también `PUT`/`DELETE /v1/events/{id}`
  con revisión optimista, misma outbox e idempotencia. DELETE coloca un
  tombstone remoto (`deleted_at`) y conserva FK, Leads y medios. Un tombstone
  local no se revierte por un pull; una operación local abierta prevalece sobre
  la instantánea remota. `GET /v1/events` incluye tombstones para que otro
  dispositivo pueda crear primero el padre local y luego aplicar Leads
  históricos sin violar la FK; la UI los excluye de Mis eventos. El borrado de
  un evento espera a las creaciones de Leads asociadas que todavía estén en cola.
- El contrato JSON expone `revision` como entero seguro. El cliente acepta
  temporalmente también la cadena decimal de `bigint` producida por el backend
  desplegado anteriormente, para recuperar operaciones en conflicto existentes.

## Límites conocidos

No hay DELETE para leads. Tampoco hay cursor/delta
sync. El PUT de Lead se limita a los campos estructurados de `REG-07`; los
medios y campos de identidad permanecen inmutables.

Filas históricas creadas por prototipos con identificadores que no cumplen UUID
se preservan localmente y no se adjudican una identidad cloud nueva de manera
silenciosa. Su migración necesita una regla explícita; las nuevas capturas y
eventos generan UUID compatibles con el contrato FL-014.

FL-016 incorporará transferencia binaria S3. Este ADR no autoriza background
execution permanente, correo, contenidos PDF, pagos ni tareas posteriores.
