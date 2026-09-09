# 02 · Escenarios de aceptación — Foloo V1

Cada escenario cubre el producto unificado. No existe una variante por edición.

## E-01 · Alta, confirmación, sesión y perfil

**Trazas:** `AUT-01`–`AUT-13`, `SYN-09`.

- Dado un email nuevo, al registrarse con contraseña, entonces Cognito envía un
  código y la app solicita confirmación sin pedir datos de perfil.
- Código inválido/vencido, reenvío, usuario confirmado, red y error inesperado
  se expresan en ES/EN sin texto AWS crudo.
- Login válido restaura el `sub`; perfil incompleto abre Tu perfil y perfil
  completo abre Inicio.
- Cerrar/reabrir restaura sesión válida. Logout vuelve a Login y conserva datos.
- Dos `sub` no ven perfil, eventos, leads o preferencias del otro; filas
  históricas no se reclaman.

## E-02 · Eventos, origen y fecha real

**Trazas:** `EVT-01`–`EVT-12`.

- Crear evento permite elegir inicio/fin y lo deja activo.
- La lista muestra activo una vez, futuros por inicio ascendente y pasados por
  fin descendente usando la fecha local real.
- Sin selección manual válida, el evento futuro más próximo queda activo y se
  reevalúa al cambiar de día; una selección manual válida no se sobrescribe.
- Editar fechas/nombre persiste. Conteos reflejan los Leads locales.
- Evento y Lead directo alternan; directo exige Lugar y ambos contextos
  persisten entre capturas.

## E-03 · Tarjeta, OCR y captura manual

**Trazas:** `CAP-01`–`CAP-06`, `OCR-01`–`OCR-09`.

- Cámara o galería ejecutan ML Kit local y precargan solo valores reconocidos.
- Correcciones manuales no se sobrescriben sin acción explícita.
- Tarjeta ilegible deja todos los campos manuales disponibles.
- Foto puede reprocesarse, reemplazarse o quitarse antes de guardar.
- La captura conserva cuatro pasos en un scroll, progreso superior y CTA fijo.
- Guardar con faltantes desplaza al primero y lo identifica sin perder datos.

## E-04 · Voz, texto e imágenes de referencia

**Trazas:** `CAP-07`, `CAP-08`, `VOZ-01`–`VOZ-08`.

- Grabar muestra onda/tiempo, detener no usa micrófono y después permite
  reproducir, borrar o regrabar.
- Permiso denegado mantiene nota escrita; voz y texto son opcionales.
- Una sesión de cámara acepta una, dos o tres imágenes y finaliza con ✓; si ya
  existen dos solo agrega una. Galería respeta el mismo máximo.
- Guardar y reabrir conserva voz e imágenes. V1 no muestra transcripción.

## E-05 · Guardado local y acuse

**Trazas:** `CAP-09`–`CAP-12`, `SYN-01`.

- Al guardar, Lead y medios existen en Drift/storage privado antes de cualquier
  intento remoto.
- Si la escritura local falla, no se muestra éxito y el formulario permanece.
- El acuse informa únicamente estados reales, permite volver ahora y vuelve
  automáticamente conservando origen/evento.
- El intento de guardar el sexto Lead conserva el borrador y abre paywall.

## E-06 · Registros y detalle editable

**Trazas:** `REG-01`–`REG-08`.

- “Todos los eventos” muestra todos; elegir uno filtra y actualiza conteos sin
  cambiar el evento activo.
- Búsqueda, tipo y orden funcionan offline sobre Drift.
- El renglón comunica interés, voz y sync con icono/palabra.
- El detalle reproduce voz, abre tarjeta/referencias completas y muestra
  fecha/hora, origen y capturó.
- Corregir un campo aprobado persiste sin cambiar owner, evento o medios.

## E-07 · Contenido PDF y asignación

**Trazas:** `CON-01`–`CON-10`, `EVT-11`.

- Biblioteca vacía muestra el estado aprobado y Subir PDF abre archivos.
- Solo PDF avanza a nombre visible y selección buscable de eventos.
- Todos los eventos domina sin borrar selecciones individuales.
- Editar asignación y eliminar requieren resultado persistente/confirmado.
- Crear evento permite seleccionar contenido existente o iniciar PDF.
- Adjuntos elegidos quedan congelados por Lead y un PDF atascado no bloquea
  Leads.

## E-08 · Plantillas y correo

**Trazas:** `PLT-01`–`PLT-07`, `SAL-01`–`SAL-07`, `RC-01`.

- Evento/directo usan plantillas distintas y variables correctas, incluido
  evento o lugar y capturó.
- Variable inválida bloquea guardar; pie legal/baja no se puede borrar.
- Guardar Lead crea trabajo de correo server-side con adjuntos congelados.
- Offline o fallo deja cola visible sin revertir el Lead.
- Estados, rebotes y baja se reconcilian; no existen credenciales de correo en
  la app.
- El proveedor no puede aceptarse hasta resolver `D-09`.

## E-09 · Offline total y sincronización

**Trazas:** `SYN-02`–`SYN-10`, `INF-01`, `INF-02`.

- En modo avión se consultan/cambian datos locales, se capturan Leads, se
  preparan PDF/plantillas y se encolan salidas.
- ConnectivityState cambia sin alterar AuthState.
- Al recuperar señal, colas reanudables avanzan sin duplicados; un archivo
  grande no detiene Leads.
- Fallo repetido conserva dato, motivo y reintento manual.

## E-10 · Exportación por evento

**Trazas:** `REG-09`–`REG-13`, `REL-08`.

- Exportar abre XLSX/CSV con XLSX inicial.
- Elegir evento produce datos locales de ese evento, incluidos pendientes.
- CSV abre con acentos por BOM UTF-8; ambos formatos preservan ES/EN.
- El archivo se comparte por la hoja del sistema.
- Columnas no se implementan hasta resolver `D-07`.

## E-11 · Trial y suscripción

**Trazas:** `MON-01`–`MON-08`, Constitución Art. 9.

- Leads 1–5 se guardan; el sexto conserva borrador y abre paywall.
- Reinstalar no reinicia contador server-side.
- Webhook/autoridad remota activa captura ilimitada y la caché permite operar
  offline a una persona ya suscrita.
- Vencimiento bloquea solo nuevas capturas; datos previos siguen visibles,
  editables y exportables.
- La construcción queda bloqueada por `D-01`–`D-04`.

## E-12 · Shell, idioma, seguridad y salida

**Trazas:** `NAV-01`–`NAV-07`, `RNF-01`–`RNF-08`, `RC-01`–`RC-05`,
`REL-01`–`REL-08`.

- Drawer derecho, logo Inicio, tema e idioma operan con un solo producto, sin
  textos, insignias o destinos Basic/Pro.
- ES↔EN y claro↔oscuro actualizan todas las superficies con contraste y estado
  no dependiente solo de color.
- El binario no expone secretos; medios requieren acceso autorizado.
- Matriz iOS/Android, pruebas reales offline/OCR/pago, legales, tiendas y beta
  satisfacen cada REL antes de declarar V1 lista.

## E-13 · Fundación backend y aislamiento cloud

**Trazas:** `AUT-10`, `SYN-06`, `SYN-10`, `INF-01`, `INF-03`, `INF-05`–`INF-14`, `RC-03`.

- Una solicitud sin JWT Cognito válido no llega a una ruta `/v1` protegida; la
  Lambda rechaza además cualquier evento sin `sub` verificado.
- En la primera solicitud autenticada se obtiene la cuenta/workspace personal
  del `sub`; solicitudes posteriores recuperan la misma identidad técnica.
- El usuario A no puede leer o mutar eventos, leads o metadata del workspace B,
  aunque envíe sus UUID en path/body. Owner, workspace, `sub` y email del body
  nunca deciden autorización.
- UUID creados offline se conservan al crear recursos. Repetir la misma
  creación con igual clave/payload retorna el mismo resultado; reutilizar la
  clave con otro payload responde conflicto.
- Payload inválido recibe 400; ausencia de identidad 401; falta de acceso 403;
  recurso ajeno/no visible 404; conflicto de versión/idempotencia 409. La
  respuesta contiene código, mensaje seguro y requestId.
- RDS queda en subred privada, sin dirección pública, y su puerto 5432 solo
  admite el Security Group de Lambda. DEV no crea NAT ni RDS Proxy.
- Guardar local en Drift continúa sin depender de esta API; FL-014 no activa
  sincronización ni subida de binarios.
