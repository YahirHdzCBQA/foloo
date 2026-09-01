# Foloo Basic · frontend Flutter

Este directorio contiene la implementación navegable de Foloo Basic alineada
con `docs/specifications/current/` y con el mockup HTML oficial de agosto de
2026.

## Alcance implementado

- Frontera `AuthRepository`/`AuthService`, sesión de desarrollo restaurable y
  configuración inicial de perfil por usuario. FakeAuth no es autenticación de
  producción; Cognito se integra en FL-013B.
- Selección de origen: evento activo o lead directo.
- Captura continua de cuatro secciones con foto, datos editables, los tipos
  Proveedor/Partner/Cliente, interés, nota escrita y Voice Note local.
- Confirmación Basic, regreso automático y captura consecutiva.
- Registros de la sesión con filtros, detalle de solo lectura y reproducción de
  Voice Note.
- Mis eventos con alta, edición, eliminación lógica y ownership local.
- Drawer derecho, cambio local claro/oscuro y cierre de sesión.
- Diálogos visuales de exportación y acción visual de sincronización.

No hay backend, Cognito real, sincronización, entrega a Sheets ni exportación
productiva. Drift/SQLite persiste perfil, preferencias, eventos, leads y media
local con aislamiento por usuario. Basic no expone transcripción, contenido,
plantillas ni correo.

## Dependencias de dispositivo

- `image_picker`: cámara y galería.
- `google_mlkit_text_recognition`: lectura local heredada exclusivamente para
  la demostración; no representa la arquitectura productiva `OCR-03/OCR-04`.
- `record`: grabación local.
- `audioplayers`: reproducción local de Voice Note.

El formato AAC/M4A sigue siendo un detalle provisional. Límites, retención y
persistencia productiva continúan bloqueados por `D-11`/`RC-03`.

## Ejecutar localmente

```sh
cd app
flutter pub get
flutter run -d <device-id>
```

Para validar sin abrir un dispositivo:

```sh
flutter analyze
flutter test
```
