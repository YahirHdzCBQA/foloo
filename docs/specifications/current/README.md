# Foloo V1 — paquete de especificación vigente

Este directorio define una sola versión funcional de Foloo. Desde la decisión
de Producto del 7 de septiembre de 2026 ya no existen Basic, Pro, capacidades
por plan ni una ruta de upgrade entre ediciones.

## Precedencia

1. `00-constitucion.md`
2. `01-especificacion.md`
3. `02-escenarios-de-aceptacion.md`
4. `04-matriz-de-capacidades.md`
5. `03-decisiones-abiertas.md`

Las fuentes de realineación son el alcance validado y los cambios del
2026-09-07, la ruta a producción del mismo día y el tablero operativo del
2026-09-08. Este último restituye explícitamente XLSX/CSV por evento y mantiene
Google Sheets fuera de V1. El registro completo está en
`../../migration/specification-realignment.md`.

## Convención de identificadores

| Familia | Área |
|---|---|
| `AUT-*` | Cognito, perfil y sesión |
| `EVT-*` | Eventos y selección activa |
| `CAP-*` | Origen y captura del lead |
| `OCR-*` | Foto y lectura ML Kit |
| `VOZ-*` | Nota de voz y nota escrita |
| `SYN-*` | Persistencia local y sincronización |
| `REG-*` | Registros, detalle y exportación |
| `CON-*` | Biblioteca PDF y adjuntos |
| `PLT-*` | Plantillas de correo |
| `SAL-*` | Envío de correo y estados |
| `NAV-*` | Navegación, tema e idioma |
| `MON-*` | Trial, paywall y suscripción |
| `INF-*` | Plataforma y servicios futuros |
| `RNF-*` | Requisitos no funcionales |
| `RC-*` | Privacidad y cumplimiento |
| `REL-*` | Preparación y salida a producción |
