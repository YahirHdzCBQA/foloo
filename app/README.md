# Foloo · aplicación Flutter

Implementación móvil de Foloo V1. El producto vigente es una sola versión; el
selector y gating `AppPlan.basic/pro` que aún aparecen en el código son deuda
heredada y deben retirarse en FL-014, no extenderse.

## Base existente

- Cognito DEV detrás de AuthRepository/AuthService.
- Perfil, eventos, Leads y preferencias por Cognito `sub`.
- Drift/SQLite y medios privados locales.
- Evento/directo, ML Kit, Voice Note, imágenes de referencia y Registros.
- Tema claro/oscuro, ES/EN, contenido/plantillas demo y selector PDF.

## Límites actuales

No existen todavía sync/API/S3, correo productivo, exportación real,
monetización o plataforma cloud. Google Sheets y transcripción automática no
pertenecen a V1. Consulta `../docs/migration/current-implementation-gap-analysis.md`.

## Validación local

Desde este directorio:

```sh
flutter pub get
dart format .
flutter analyze
flutter test
```

No ejecutar `flutter run` en tareas que lo prohíban.
