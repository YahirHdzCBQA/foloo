# Localización de Foloo V1

Español (`es`) e inglés (`en`) son idiomas de primera clase en app, plantillas,
correo, exportación visible y materiales de tienda (`NAV-05`, `NAV-06`,
`RNF-06`).

Flutter usa ARB y `AppLanguageScope`. Login y Drawer comparten el mismo estado;
el idioma compatible del sistema se usa inicialmente y español es fallback.
La preferencia debe persistir localmente por `sub`.

No se traducen marca, nombres propios, enums persistidos, extensiones XLSX/CSV
ni tokens de plantilla como `{evento}`, `{lugar}`, `{contenido}` y
`{capturadoPor}`. La capa visual resuelve etiquetas localizadas.

La antigua mención a planes/capabilities se elimina: cambiar idioma no cambia
ninguna capacidad. Toda cadena demo pendiente debe auditarse antes de REL-01 y
los archivos exportados deben conservar acentos (`REL-08`).
