# Mantenimiento y limpieza técnica del repositorio

Fecha: 2026-10-16  
Rama auditada: `feature/FL-020.6/QA-corrections`

## Alcance y fuentes

Esta pasada parte de `repository-cleanup-audit-fl0206.md` y aplica únicamente
eliminaciones con desuso verificable. Se revisaron las fuentes SDD canónicas en
el orden definido por `AGENTS.md`, incluidos los escenarios E-03, E-04 y E-08,
los ADR-001/006/007 y las decisiones abiertas D-05, D-06 y D-11. FL-020.6
permanece cerrada y no se modifica el roadmap funcional.

## Elementos eliminados — Seguro

| Elemento | Evidencia | Cambio |
|---|---|---|
| `app/lib/widgets/app_screen_header.dart` | Las búsquedas por nombre de clase, nombre de archivo e imports no encontraron consumidores en `lib`, tests ni plataformas. Las pantallas vigentes usan `ModuleHeader`. | Archivo eliminado. |
| Dependencia directa `cupertino_icons` | No existen imports de `package:cupertino_icons` ni referencias a `CupertinoIcons`; solo aparecía en `pubspec.yaml`, `pubspec.lock` y la auditoría. | Dependencia y entrada del lockfile retiradas mediante `flutter pub get`. |

La validación del grafo con `flutter pub deps --style=compact` confirma que
`cupertino_icons` ya no forma parte de las dependencias directas o transitivas.
`cupertino_ui` permanece como dependencia transitiva independiente de `pdfrx`
y no fue alterada.

## Mantenimiento documental sin cambio de comportamiento

- Se retiraron comentarios que describían el OCR local vigente como prototipo
  temporal o como candidato obligatorio a migrar al backend. Eso contradecía
  OCR-02, OCR-03 y OCR-04, que definen el reconocimiento y prefill actuales.
- Se retiró un `TODO(PRODUCTION)` obsoleto sobre persistencia de idioma: la
  preferencia ya se guarda owner-scoped en Drift.
- Se actualizó la descripción del paquete y dos comentarios de dependencias
  desde trazas históricas `RF-*` a OCR-01/CAP-08 y VOZ-01/VOZ-06.
- Se consolidaron dos filas duplicadas `VOZ-*` de `traceability.md`, conservando
  toda su evidencia y las decisiones D-05/D-06/D-11.

## Elementos conservados

| Clasificación | Elemento | Motivo |
|---|---|---|
| Conservar | `ModuleHeader` y headers específicos | Tienen consumidores activos en pantallas y cobertura de navegación. |
| Conservar | `session_lead.dart` y fixtures demo | Tienen consumidores en tests y en `app_drawer.dart`; retirarlos cambiaría comportamiento. |
| Conservar | Logger social de autenticación | Solo opera bajo `kDebugMode` y sanitiza datos; sirve para diagnóstico sin alterar producción. |
| Conservar | Diagnóstico OCR y reglas R8/ML Kit | Están apagados por defecto o son necesarios para el OCR Release validado. |
| Conservar | Pruebas defensivas de unsubscribe y compatibilidad histórica | Protegen comportamiento retirado frente a regresiones. |
| Conservar | Entry points backend `infra/app.ts`, `scripts/migrate.ts` y `migration_lambda.ts` | Su invocación es externa al grafo de imports; no son código muerto. |
| Condicionado | Duplicidades funcionales mayores entre pantallas/servicios | Requerirían refactor y QA visual/funcional; quedan fuera de una limpieza segura. |
| Pendiente | Marcadores de producción ligados a estados de envío y decisiones abiertas | No hay evidencia suficiente para retirarlos sin cerrar las decisiones aplicables. |

También se conservaron todos los elementos protegidos: migraciones SQL,
configuración AWS DEV, Cognito, correo, Unlimited QA, assets de marca,
localizaciones, ADR/SDD, artefactos históricos, firma y certificados.

## Archivos de esta limpieza

- Eliminado: `app/lib/widgets/app_screen_header.dart`.
- Modificados: `app/pubspec.yaml`, `app/pubspec.lock`,
  `app/lib/services/card_text_recognition_service.dart`,
  `app/lib/utils/business_card_parser.dart`, `app/lib/l10n/l10n.dart` y
  `docs/delivery/traceability.md`.
- Creado: `docs/delivery/repository-maintenance-cleanup.md`.

El repositorio ya contenía cambios documentales locales del cierre de
FL-020.6; no se revierten ni se atribuyen a esta limpieza.

## Validaciones

Se validó cada conjunto aislado antes de avanzar:

1. Tras retirar `AppScreenHeader`: `flutter analyze` sin issues y 292 tests
   aprobados.
2. Tras retirar `cupertino_icons`: `flutter pub get` correcto, lockfile con una
   única dependencia eliminada, `flutter analyze` sin issues y 292 tests
   aprobados.
3. Tras corregir comentarios y trazabilidad: `dart format .` sobre 134 archivos
   (0 cambios), `flutter analyze` sin issues y 292 tests aprobados.
4. `flutter pub deps --style=compact`: grafo resuelto y sin
   `cupertino_icons`.
5. Búsqueda final sin referencias ejecutables a los elementos retirados,
   verificación de enlaces Markdown locales sin faltantes y
   `git diff --check` correcto.

No se modificó backend, por lo que no correspondió ejecutar su typecheck o
tests. No se generaron builds ni se desplegó infraestructura.

## Riesgos y recomendaciones

- No se reconstruyó un APK/IPA por restricción expresa; la ausencia de uso está
  probada estáticamente y por la suite, pero una comparación binaria queda para
  un ciclo normal de build, no para esta limpieza.
- Cualquier consolidación adicional de widgets o servicios debe tratarse como
  refactor separado, con trazabilidad y QA visual en Android/iOS.
- Los elementos condicionados o pendientes deben conservarse hasta obtener
  evidencia adicional; no deben borrarse por heurísticas de imports solamente.
