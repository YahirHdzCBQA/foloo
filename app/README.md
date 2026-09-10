# Foloo · aplicación Flutter

Implementación móvil de Foloo V1. El producto vigente es una sola versión y
el runtime no contiene selector ni gating por edición.

## Base existente

- Cognito DEV detrás de AuthRepository/AuthService.
- Perfil, eventos, Leads y preferencias por Cognito `sub`.
- Drift/SQLite y medios privados locales.
- Outbox persistente y sync autenticado contra la API Foloo (`SYN-04`–`SYN-10`).
- Evento/directo, ML Kit, Voice Note, imágenes de referencia y Registros.
- Tema claro/oscuro, ES/EN, contenido/plantillas demo y selector PDF.

## Límites actuales

FL-015 no sube binarios: S3 corresponde a FL-016. Tampoco existen todavía
correo productivo, exportación real ni monetización. Google Sheets y
transcripción automática no pertenecen a V1. Consulta
`../docs/delivery/traceability.md`.

La URL DEV está centralizada en `FolooApiConfiguration.dev` y puede sustituirse
sin cambiar código mediante `--dart-define=FOLOO_API_BASE_URL=https://...`.

## Validación local

Desde este directorio:

```sh
flutter pub get
dart format .
flutter analyze
flutter test
```

No ejecutar `flutter run` en tareas que lo prohíban.
