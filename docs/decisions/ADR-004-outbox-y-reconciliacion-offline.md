# ADR-004 — Outbox persistente y reconciliación offline-first

- Estado: **Aceptado**
- Fecha: 2026-09-09
- Alcance: FL-015, motor de sincronización móvil Foloo V1
- Trazas: `SYN-04`–`SYN-10`, `RNF-07` y E-09

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
  perfil, eventos, leads y metadata de medios para respetar dependencias.
- Timeout, transporte, 408, 429 y 5xx son reintentables con backoff exponencial
  acotado a una hora; `Retry-After` puede ampliar el plazo. Errores 4xx restantes
  quedan fallidos hasta reintento manual y nunca eliminan el dato local.
- La sesión se consulta al ejecutar. Sin token vigente o si el `sub` no coincide,
  no se consume la cola. Tokens y binarios nunca entran en SQLite.
- El pull usa los listados completos disponibles. Solo aplica un objeto remoto
  cuando esa entidad no tiene una operación local abierta; no borra filas locales
  ausentes del listado remoto. Los UUID locales son también IDs cloud.
- Metadata remota de medios solo confirma filas locales existentes. Crear una
  fila de media sin archivo sería engañoso antes de FL-016.

## Límites conocidos

FL-014 no ofrece PUT/DELETE para eventos ni leads. FL-015 sincroniza las
creaciones que el contrato actual soporta y registra como pendiente contractual
la sincronización cloud de ediciones/borrados, sin inventar endpoints. Tampoco
hay cursor/delta sync ni precondición de revisión; por eso el pull conserva toda
entidad dirty en lugar de resolverla por last-write-wins.

Filas históricas creadas por prototipos con identificadores que no cumplen UUID
se preservan localmente y no se adjudican una identidad cloud nueva de manera
silenciosa. Su migración necesita una regla explícita; las nuevas capturas y
eventos generan UUID compatibles con el contrato FL-014.

FL-016 incorporará transferencia binaria S3. Este ADR no autoriza background
execution permanente, correo, contenidos PDF, pagos ni tareas posteriores.
