# Auditoría integral de limpieza del repositorio — FL-020.6

- Fecha de corte: 2026-10-16.
- Rama observada: `feature/FL-020.6/QA-corrections`.
- Alcance: inventario y recomendación; **no se eliminó, movió ni consolidó
  ningún archivo**.
- Trazas protegidas: `OCR-10`, `VOZ-06`, `SAL-11`, E-03, E-04 y E-08;
  ADR-001/006/007.

## 1. Resumen ejecutivo

La complejidad versionada es pequeña: Git rastrea 303 archivos con
3,288,954 bytes de contenido en el worktree (aprox. 3.14 MiB). El directorio
local ocupa 8.5 GiB porque conserva compilaciones, cachés y dependencias
regenerables. `app/build/` (5.9 GiB), `app/.dart_tool/` (1.7 GiB) y
`backend/node_modules/` (613 MiB) explican la mayor parte.

La limpieza de mayor valor no requiere borrar código ni SDD. Con autorización,
preservando primero el APK canónico Build 8 en almacenamiento privado y
verificando su hash, podrían recuperarse aproximadamente 8.0–8.3 GiB de
artefactos regenerables. El rango depende de cuántos APK/IPA históricos decida
conservar CBQA. No se recomienda tocar migraciones, ADR, assets vigentes,
lockfiles ni código de OCR/Cognito/correo/Unlimited como parte de una limpieza
de disco.

No se encontraron keystores, certificados privados, `.env` ni credenciales
rastreadas. El único match del escaneo textual fue la documentación que nombra
la variable `FOLOO_ANDROID_KEYSTORE_PASSWORD`; no contiene su valor. El
keystore Release permanece fuera del repositorio.

## 2. Método y límites

Se usaron consultas de solo lectura: `du`, `find`, `stat`, `shasum`, `unzip`,
`rg`, `git status`, `git ls-files`, `git check-ignore` y
`git count-objects`. No se ejecutaron `clean`, borrados, movimientos,
instalaciones, builds nuevas, despliegues ni operaciones Git de escritura.

Los tamaños `du` son asignación local aproximada y pueden variar por filesystem.
Los bytes de archivos y APK son exactos al corte. Una ausencia de import
detectada estáticamente es evidencia para revisar, no autorización de borrado;
reflection, generación, entrypoints nativos y scripts pueden crear consumidores
no visibles por una búsqueda simple.

## 3. Métricas actuales

| Ámbito | Medición | Interpretación |
|---|---:|---|
| Proyecto local completo | 8.5 GiB | Incluye todo lo ignorado y regenerable |
| `app/` | 7.8 GiB | Principalmente `build/` y `.dart_tool/` |
| `backend/` | 692 MiB | Principalmente `node_modules/` y `cdk.out/` |
| `docs/` | 292 KiB | Fuente SDD; ahorro irrelevante frente a builds |
| `.git/` | 18 MiB | 3,157 objetos sueltos; sin garbage reportado |
| Contenido rastreado | 3,288,954 bytes | 303 archivos; excluye `.git/` |
| Archivos locales (sin contar `.git/`) | 53,582 | Dominados por dependencias/cachés |
| APK/IPA bajo `app/build/` | 1,510,340,080 bytes | Incluye duplicados y builds diagnósticos |

### Directorios regenerables principales

| Ruta | Tamaño | Estado Git | Recuperación normal |
|---|---:|---|---|
| `app/build/` | 5.9 GiB | Ignorado | Rebuild Flutter/Gradle/Xcode; **antes preservar Build 8** |
| `app/.dart_tool/` | 1.7 GiB | Ignorado | `flutter pub get` y build/test |
| `backend/node_modules/` | 613 MiB | Ignorado | `npm ci` desde `package-lock.json` |
| `app/ios/Pods/` | 138 MiB | Ignorado | `pod install` desde `Podfile.lock` |
| `backend/cdk.out/` | 78 MiB | Ignorado | `npm run cdk -- synth ...` con contexto correcto |
| `app/android/.gradle/` | 30 MiB | Ignorado | Gradle lo recrea |
| `backend/dist/` | 340 KiB | Ignorado | `npm run build` |

### Artefactos de aplicación

| Grupo | Bytes | Observación |
|---|---:|---|
| Build 8 canónico | 133,692,843 | Conservar: nombre FL-020.6 + hash documentado |
| Dos copias genéricas idénticas de Build 8 | 267,385,686 | Mismo SHA-256 que el canónico |
| Builds diagnósticos 2–5 | 545,635,646 | Históricos; decidir archivo corporativo |
| Builds validados 6–7 | 267,025,126 | Evidencia/baseline; decidir retención privada |
| APK Debug | 247,289,927 | Regenerable, no distribuible |
| IPA local | 49,310,852 | Propósito/firma no auditados en esta tarea |

Build 8 existe tres veces con SHA-256
`1906166f2e0861e8bfd216068eb8680276044d18ff8d16ab24f1af70cba76d1d`:

- `app/build/app/outputs/flutter-apk/foloo-dev-1.0.0+8-fl-020.6-unlimited-release.apk`
  (canónico);
- `app/build/app/outputs/flutter-apk/app-release.apk`;
- `app/build/app/outputs/apk/release/app-release.apk`.

El APK es universal. Sus librerías nativas descomprimidas suman
aproximadamente 44.7 MB para arm64-v8a, 36.6 MB para armeabi-v7a y 47.1 MB para
x86_64. Esto explica gran parte de los 127 MiB del archivo, junto con ML Kit,
PDFium, SQLite y Flutter. No es evidencia de dependencias sobrantes: una
distribución por ABI o AAB podría reducir descarga, pero cambia el mecanismo
de entrega y pertenece a una actividad de release, no a limpieza de fuentes.

## 4. Archivos versionados más grandes

| Ruta/grupo | Tamaño aproximado | Evaluación |
|---|---:|---|
| `app/lib/data/local/app_database.g.dart` | 525 KiB | Generado, pero rastreado y requerido por el build actual |
| `app/assets/branding/` | 396 KiB | Seis PNG distintos y referenciados; no hay duplicados por hash |
| `backend/package-lock.json` | 110 KiB | Reproducibilidad de `npm ci`; conservar |
| `app/lib/screens/records_screen.dart` | 85 KiB | Grande por responsabilidad, no archivo muerto |
| `app/lib/screens/lead_capture_screen.dart` | 80 KiB | Flujo central CAP/OCR/VOZ; no limpiar sin refactor dedicado |
| `docs/` completo | 292 KiB | Trazabilidad vigente; tamaño despreciable |

Los seis assets de marca están referenciados por `brand_theme.dart` o
`lead_confirmation_screen.dart`, son únicos por SHA-256 y se empaquetan. Los
iconos y launch assets de tienda todavía se consideran placeholders según
STORE-02B, pero no deben borrarse o sustituirse sin aprobación visual.

## 5. Hallazgos por categoría

### Categoría A — Limpieza segura, después de autorización

| Ruta | Tamaño/ahorro | Estado Git | Función y evidencia | Riesgo | Acción / recuperación |
|---|---:|---|---|---|---|
| Dos `app-release.apk` genéricos de Build 8 | 267,385,686 B | Ignorados | Hash idéntico al APK nombrado | Bajo si el canónico y hash se preservan | Eliminar solo las dos copias; recuperar reconstruyendo Build 8, aunque no necesariamente byte a byte |
| `app/build/` excepto artefactos aprobados | Hasta 5.9 GiB | Ignorado | Intermedios Gradle/Xcode, test cache y outputs | Alto si se borra Build 8 sin archivarlo | Copiar primero artefactos aprobados a storage privado, verificar hash y después limpiar intermedios |
| `app/.dart_tool/` | 1.7 GiB | Ignorado | Caché Dart/Flutter, incluidos `.dill` grandes | Bajo; siguiente build será más lento | Regenerar con `flutter pub get`, analyze/test/build |
| `backend/node_modules/` | 613 MiB | Ignorado | Dependencias instaladas | Bajo con lockfile disponible | Regenerar con `npm ci` usando Node 22 |
| `app/ios/Pods/` y `.symlinks/` | 138 MiB + | Ignorados | Dependencias CocoaPods | Bajo/medio por tooling local | Regenerar desde `Podfile.lock`; validar build iOS |
| `backend/cdk.out/` | 78 MiB | Ignorado | Synth/assets CDK acumulados | Bajo; no es estado cloud | Regenerar mediante synth con contexto del ambiente; diff antes de deploy |
| `app/android/.gradle/`, `app/android/build/` | 30 MiB + | Ignorados | Caché/output Android | Bajo | Gradle/Flutter los recrea |
| `backend/dist/` | 340 KiB | Ignorado | JavaScript compilado | Bajo | `npm run build` |
| `.DS_Store`, `.idea/`, `*.iml` ignorados | Pequeño | Ignorados | Metadata local | Bajo | Herramientas/OS los recrean |

No se debe ejecutar una eliminación global de `app/build/` hasta que Build 8
se encuentre en una ubicación privada aprobada y su hash haya sido comprobado.

### Categoría B — Limpieza condicionada

| Ruta/elemento | Tamaño | Estado Git | Evidencia | Riesgo | Recomendación |
|---|---:|---|---|---|---|
| APK Builds 2–5 | 545,635,646 B | Ignorados | Evidencia de diagnóstico STORE-03C–03E; hashes distintos | Pérdida de binario histórico no reproducible byte a byte | Archivar o autorizar descarte después de confirmar que docs/logs bastan |
| APK Builds 6–7 | 267,025,126 B | Ignorados | Baselines físicamente validados | Pierde referencia de rollback/análisis; Android no permite downgrade normal | Retención corporativa definida; luego retirar copias locales si se aprueba |
| `app/build/ios/ipa/foloo.ipa` | 49,310,852 B | Ignorado | No se verificó versión, firma ni utilidad actual | Podría ser evidencia/distribución iOS | Identificar propietario/build antes de archivar o eliminar |
| `backend/migration-result.json` | 4 KiB | Ignorado | Salida operacional local | Puede ser única evidencia de una ejecución | Confirmar que la evidencia 008 esté registrada sin PII/secretos; luego descartar si se autoriza |
| `app/lib/widgets/app_screen_header.dart` | ~3 KiB | Rastreado | Cero imports/consumidores; `ModuleHeader` es el componente usado | Búsqueda estática puede omitir carga no convencional | Retirar en cambio separado y ejecutar analyze, tests de navegación y build |
| `cupertino_icons` en `pubspec.yaml` | Fuente 257,628 B dentro del APK | Rastreado | Cero imports `CupertinoIcons`; font empaquetada | Podría existir uso dinámico no detectado | Quitar dependencia en cambio separado y comparar APK/UI iOS/Android |
| Comentarios `DEMO`/`TODO(PRODUCTION)` obsoletos | Sin ahorro material | Rastreado | OCR dice futura extracción backend aunque `OCR-02` exige ML Kit local; l10n dice no persistido aunque Drift ya guarda idioma | Confunde mantenimiento | Corregir comentarios, no comportamiento, en una tarea documental/técnica aislada |
| Evidencia STORE-03B–03F dentro de un solo documento | 29 KiB | Rastreado | Trazabilidad real, pero header previo estaba desactualizado | Consolidar mal puede borrar contexto de una corrección Release | Mantener por ahora; considerar resumen + Git history solo con aprobación |
| Fila duplicada `VOZ-*` en traceability | <1 KiB | Rastreado | Dos filas parcialmente superpuestas | Riesgo bajo, pero consolidar es limpieza documental | Fusionar después de aprobar alcance de limpieza |

### Categoría C — Conservar

| Ruta/elemento | Motivo |
|---|---|
| Build 8 canónico y hash | Artefacto QA Android solicitado y validado; debe salir de `build/` antes de limpiar ese árbol |
| `backend/migrations/001…008_*.sql` | Historia de esquema y despliegue; 008 es dependencia activa de email sender identity |
| `docs/product/`, `docs/decisions/`, ADR y escenarios | Fuente de verdad/trazabilidad; no hay copias Basic/Pro operacionales |
| `app/assets/branding/` | Todos los archivos tienen consumidores y hashes distintos |
| App icons y launch assets iOS/Android | Necesarios para compilar, aunque Producto todavía deba aprobar reemplazos finales |
| `app_database.g.dart` y localizaciones generadas rastreadas | El repositorio actual las consume y las versiona; cambiar política requiere CI reproducible |
| `pubspec.lock`, `Podfile.lock`, `package-lock.json`, Gradle wrapper properties | Reproducibilidad y compatibilidad de dependencias |
| Reglas R8 `ComponentRegistrar` y flags diagnósticos desactivados por defecto | Evidencia de STORE-03F y mecanismo controlado de diagnóstico; eliminarlos puede reabrir OCR Release |
| Código histórico unsubscribe y sus pruebas defensivas | Las migraciones/filas se conservan por contrato; tests prueban que las rutas ya no están activas |
| Logging social sanitizado y limitado a `kDebugMode` | No entra activo en Release y sigue cubriendo Google/diagnóstico federado sin exponer tokens |
| Todas las dependencias backend declaradas | Cada dependencia runtime tiene imports directos en `src/`, `infra/` o scripts |
| Configuración Cognito, AWS DEV y Unlimited | Activa y necesaria para QA; no forma parte de una limpieza de archivos |
| Keystore Release externo | Es esencial para actualizar la app y no debe moverse, copiarse o inspeccionarse en esta limpieza |

### Categoría D — Riesgo o investigación pendiente

| Elemento | Hecho verificado | Incertidumbre / decisión requerida |
|---|---|---|
| APK universal con tres ABI | Las librerías nativas son el mayor contenido del APK | Decidir en una FL de distribución si usar AAB/splits; no retirar ABI del build universal actual |
| Assets web-worker de Amplify en APK | Mapas/WASM/JS de los paquetes suman varios MB sin ser código Foloo | Revisar upstream/versión; no excluir manualmente assets del SDK de Auth |
| `.git/` con objetos sueltos | 17.63 MiB, sin garbage reportado | `git gc` puede compactar, pero el ahorro es marginal y es una operación Git fuera de este alcance |
| Tamaño de pantallas monolíticas | `records_screen.dart` y `lead_capture_screen.dart` son grandes | Refactor puede mejorar mantenimiento, pero no debe disfrazarse como limpieza de espacio |
| Entry points nativos/generados ignorados | Gradle wrapper, GeneratedPluginRegistrant y metadata local son regenerables | Confirmar flujo de onboarding de un checkout limpio antes de cambiar reglas o borrarlos |

## 6. Dependencias y referencias

- Todas las dependencias Flutter runtime, salvo `cupertino_icons`, tienen
  imports directos en `app/lib/` o cobertura de tests.
- Las dependencias AWS SDK, `pg` y `zod` tienen consumidores directos.
- `app_screen_header.dart` es el único archivo Dart mantenido, aparte de
  `main.dart`, sin import detectado; `main.dart` es el entrypoint y se conserva.
- `infra/app.ts`, `scripts/migrate.ts` y `migration_lambda.ts` aparecen sin
  import por ser entrypoints ejecutables/empaquetados; no son archivos muertos.
- Los seis PNG de marca son distintos y usados.
- Los enlaces Markdown relativos auditados existen; no se detectaron links
  relativos rotos antes de esta actualización.
- Los directorios generados y APK están cubiertos por `.gitignore`; no hay
  necesidad demostrada de modificarlo ahora.

## 7. Documentación

No existen documentos Basic/Pro ni versiones `old`, `backup` o `final-2` en el
árbol operacional. Los 18 documentos actuales tienen responsabilidades
distintas: producto, aceptación, decisiones, arquitectura, ADR, roadmap,
trazabilidad y readiness. STORE-02/03 contienen evidencia extensa, pero su
tamaño total es pequeño y la consolidación podría perder auditabilidad.

Durante el cierre FL-020.6 se sincronizaron roadmap, trazabilidad, escenarios,
product spec, arquitectura y distribución Android. No se eliminó historia.

## 8. Ahorro potencial

- Limpieza de cachés/dependencias regenerables, preservando artefactos:
  aproximadamente 7.5 GiB.
- Retirar además duplicados genéricos de Build 8: +255 MiB aproximados.
- Tras decidir retención de builds 2–7, Debug e IPA: hasta ~1.04 GiB
  adicionales.
- Quitar `cupertino_icons`, si la validación lo aprueba: ~252 KiB sin comprimir
  dentro del APK; el impacto real comprimido debe medirse con dos builds.
- Eliminar `app_screen_header.dart`: ahorro irrelevante en disco/APK; el valor
  es reducir código muerto.

El máximo teórico no es la recomendación. La propuesta prudente conserva Build
8 y cualquier baseline que CBQA decida archivar.

## 9. Propuesta por fases

1. **Custodia de artefactos.** Copiar Build 8 a almacenamiento corporativo
   privado, registrar propietario/retención y verificar SHA-256. Decidir si
   Builds 6–7 e IPA también se archivan. No incluir keystore ni contraseñas.
2. **Limpieza local regenerable.** Tras autorización concreta, retirar cachés,
   intermedios, dependencias instaladas y outputs no preservados. No cambiar
   fuentes ni lockfiles.
3. **Validar checkout reproducible.** Reinstalar desde lockfiles y ejecutar
   analyze/tests/builds/synth sin deploy. Esto prueba que no existía una
   dependencia oculta de archivos locales.
4. **Código/dependencias.** En un cambio independiente, evaluar
   `app_screen_header.dart` y `cupertino_icons`, con comparación de APK y QA
   visual.
5. **Deuda documental/comentarios.** Corregir marcadores obsoletos y, solo con
   aprobación, consolidar filas/reportes sin eliminar ADR, migraciones o
   evidencia necesaria.

## 10. Validación y recuperación

Después de una limpieza autorizada:

1. comprobar hashes y disponibilidad privada de Build 8;
2. `flutter pub get`, `flutter analyze` y `flutter test`;
3. generar un Release de verificación con la firma existente solo si se autoriza,
   sin exponer secretos, y comparar package/certificado/permisos;
4. `npm ci`, `npm run typecheck`, `npm test` y `npm run build`;
5. ejecutar CDK synth/diff de solo lectura con el contexto DEV correcto, sin
   deploy;
6. validar OCR, cámara, referencias, micrófono, Cognito, correo y Unlimited QA
   si se modificaron dependencias, R8 o configuración;
7. ante fallo, restaurar fuentes desde Git y artefactos desde el storage privado;
   regenerar cachés desde lockfiles. Un APK borrado sin copia no se considera
   recuperable byte a byte mediante un rebuild.

## 11. Decisiones que requieren autorización

- Ubicación y política de retención del APK Build 8 y builds anteriores.
- Eliminación de APK/IPA diagnósticos o validados.
- Ejecución de cualquier limpieza de `build/`, cachés, Pods, node_modules o
  CDK output.
- Retirada de `app_screen_header.dart` o `cupertino_icons`.
- Consolidación adicional de documentación histórica STORE-03.
- Cualquier cambio de ABI, AAB, SDK Amplify, ML Kit, R8 o flujo de distribución.

Hasta recibir esas decisiones, el estado recomendado es conservar el árbol
tal como está. Esta auditoría no autoriza limpieza automática.
