# Localización Flutter

## Alcance

Esta implementación da trazabilidad a `NAV-09` y `RNF-19` para Basic y Pro.
Los idiomas soportados son español (`es`) e inglés (`en`). La aplicación
usa el idioma del sistema cuando es compatible y español para cualquier
locale no soportado.

La preferencia se conserva durante la sesión en un único estado compartido
por Login y Drawer. La persistencia durable queda fuera de FL-011 hasta que
exista una foundation local aprobada.

## Implementación

- `app/lib/l10n/app_es.arb` contiene el copy base en español.
- `app/lib/l10n/app_en.arb` contiene las traducciones equivalentes en inglés.
- `app/l10n.yaml` configura la generación oficial de Flutter.
- `flutter gen-l10n` regenera `AppLocalizations` y sus implementaciones.
- `AppLanguageScope` expone el mismo estado a ambos selectores compactos.

Para agregar un idioma se crea su ARB con las mismas claves, se agrega el
locale soportado por la generación y se ejecuta `flutter gen-l10n`. Las
pantallas consumen claves semánticas mediante `context.l10n`; no contienen
bifurcaciones de idioma.

## Fronteras

No se localizan nombres propios, marca Foloo, planes Basic/Pro, formatos XLS y
CSV, identificadores de dominio ni tokens contractuales de plantilla como
`{evento}`, `{lugar}` y `{contenido}`. Los enums conservan valores estables y
la capa visual resuelve sus etiquetas localizadas. Cambiar el locale no cambia
capabilities ni reglas de negocio.
