# Foloo · aplicación Flutter

Implementación móvil de Foloo V1. El producto vigente es una sola versión y
el runtime no contiene selector ni gating por edición.

## Base existente

- Cognito DEV detrás de AuthRepository/AuthService.
- Perfil, eventos, Leads y preferencias por Cognito `sub`.
- Drift/SQLite y medios privados locales.
- Outbox persistente y sync autenticado contra la API Foloo (`SYN-04`–`SYN-10`).
- Evento/directo, ML Kit, Voice Note, imágenes de referencia y Registros.
- Tema claro/oscuro, ES/EN, Content/PDF durable, plantillas y correo
  Google/Microsoft, edición de Registros y exportación XLSX/CSV por evento.

## Límites actuales

FL-020 aporta el trial histórico de cinco Leads, enforcement offline/server y
paywall informativo. Compra, precio y transiciones producidas por un proveedor
de pago pertenecen a FL-021. Google Sheets y transcripción automática no
pertenecen a V1. Consulta `../docs/delivery/traceability.md`.

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
