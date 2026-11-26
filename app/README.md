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

FREE conserva cinco capturas históricas; FL-021 habilita captura ilimitada por
entitlement PRO administrativo, sin cambiar las demás capacidades. Los pagos
públicos quedan para FL-022. Google Sheets y transcripción automática siguen
fuera de V1. Véase la [trazabilidad](../docs/delivery/traceability.md).

Para QA iOS privado, usar la [configuración homologada de Build 7](../docs/delivery/ios-testflight-distribution.md).
Un Release DEV requiere opt-in explícito; un Release público requiere
[configuración PROD independiente](../docs/delivery/prod-environment-readiness.md).

## Validación local

Desde este directorio:

```sh
flutter pub get
dart format .
flutter analyze
flutter test
```

No ejecutar `flutter run` en tareas que lo prohíban.
