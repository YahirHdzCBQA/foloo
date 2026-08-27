# ADR-001 — Persistencia local durable con Drift + SQLite

- Estado: **Aceptado**
- Fecha: 2026-08-26
- Alcance: compartido Basic/Pro
- Trazas: CAP-15, SYN-01, SYN-02, AUT-08, EVT-*, REG-*, VOZ-02,
  RNF-06, RNF-18 y RC-06

## Contexto

Foloo debe guardar primero en el dispositivo, operar sin señal y conservar los
leads después de reiniciar o cerrar sesión. La implementación previa retenía
perfil, eventos y leads únicamente en memoria. Los archivos de tarjeta y nota
de voz también podían permanecer en ubicaciones temporales del picker o del
grabador.

La decisión de producto/técnica de FL-012 selecciona explícitamente Drift sobre
SQLite. D-03 (folio comercial) y D-11 (retención de medios) siguen abiertas.

## Decisión

- Una base Drift/SQLite, con un único esquema para Basic y Pro, guarda datos
  estructurados de perfil local, preferencias, eventos, leads y metadatos de
  medios.
- Cada entidad usa un identificador técnico local estable. El folio comercial
  del lead es nullable y no forma parte de la identidad local.
- Las imágenes y notas de voz se copian a directorios privados de soporte de la
  aplicación. SQLite guarda únicamente ruta, tipo, duración y estado local.
- Guardar un lead copia sus medios y luego inserta lead + referencias dentro de
  una transacción Drift. Si falla la transacción se eliminan las copias nuevas y
  no se muestra el acuse.
- Widgets consumen repositorios; no conocen Drift ni ejecutan SQL.
- `schemaVersion` comienza en 1. Las futuras versiones deberán agregar pasos de
  migración explícitos y pruebas de actualización antes de incrementarlo.
- No se precargan fixtures de producto en la base de producción. Los fixtures
  continúan aislados para previews y pruebas de interfaz.
- Cerrar sesión no borra la base ni los medios (AUT-08).

## Consecuencias y límites

- La aplicación puede reabrir y consultar leads/eventos locales sin red.
- Los estados de sincronización son únicamente locales; este ADR no crea cola,
  reintentos, endpoints ni sincronización real.
- No se aplica borrado automático de medios mientras D-11 siga abierta. Solo se
  limpian copias creadas por una operación que no llegó a confirmarse y
  referencias cuyo archivo ya no existe.
- SQLite y el sandbox privado del sistema operativo **no satisfacen por sí
  solos RC-06 (cifrado local)**. Cifrado, manejo de llaves y aislamiento por
  cuenta quedan pendientes de decisiones específicas; no se agrega una
  dependencia de cifrado de forma implícita.
- Campos Pro son nullable y solo los usa la capacidad Pro; RNF-18 impide que se
  expongan en Basic.

## Alternativas consideradas

Se registran brevemente para trazabilidad, sin reabrir la decisión aceptada:

- `sqflite` directo: mantiene SQLite, pero exige SQL y mapeo manual adicional.
- ObjectBox: motor local alternativo, no seleccionado.
- Isar: motor local alternativo, no seleccionado.
- Hive CE: almacén key/value alternativo, no seleccionado.
- Sembast: base documental en archivo, no seleccionada.

Memoria y archivos JSON tampoco satisfacen las relaciones, consultas,
transacciones y migraciones requeridas por Foloo.
