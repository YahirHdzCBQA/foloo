# FL-013C — Realineación a Foloo V1 unificado

## Fuentes y precedencia

1. **Alcance MVP — foloo App Móvil**, validado 2026-09-07: autoridad
   funcional principal.
2. **Cambios de alcance — foloo**, 2026-09-07: migración Basic/Pro → versión
   única.
3. **Ruta a producción — foloo**, 2026-09-07: ruta oficial base.
4. **foloo-ruta-a-v1-2026-09-08.xlsx**: actualización operativa posterior;
   modifica explícitamente el alcance cuando así lo declara.
5. SDD/código anterior: evidencia histórica o de implementación.

Los DOCX/XLSX originales no se modificaron.

## Decisiones de Producto incorporadas

- Basic y Pro desaparecen. Existe una sola Foloo V1 con el alcance funcional
  antes asociado al producto amplio, excepto lo retirado expresamente.
- El modelo comercial cambia de features por plan a volumen: cinco Leads gratis
  y suscripción anual para nuevas capturas ilimitadas.
- Datos existentes nunca se borran/ocultan por pago.
- ML Kit local, Voice Note sin transcripción, contenido PDF, plantillas, correo,
  referencia de imágenes y offline total pertenecen a V1.
- Google Sheets, IA/transcripción, QR y dashboards web quedan backlog.
- El XLSX del 8-sep reincorpora XLSX/CSV por evento pese a que los DOCX del
  7-sep los retiraron.

## Contradicciones tratadas

| Tema | Conflicto | Resultado |
|---|---|---|
| Exportación | DOCX 7-sep fuera; XLSX 8-sep dentro | actualización posterior: V1 |
| Google Sheets | SDD anterior obligatorio; XLSX backlog | fuera de V1 |
| OCR | SDD anterior backend; alcance valida ML Kit | ML Kit local V1 |
| Transcripción | delta Pro anterior; nuevo alcance la retira | backlog |
| Detalle | anterior solo lectura; alcance nuevo editable | editable; medios dependen D-06 |
| Email | orientación SES vs requisito Workspace/DKIM | abierto D-09 |
| Estado de 65 | workbook marca todos “Falta”; repo contiene trabajo | auditoría I/P/F, no se edita workbook |

## Material superseded

El paquete vigente antes de FL-013C, incluidas especificaciones Basic/Pro,
arquitectura, ADRs auxiliares, decisiones y plan, se copió sin pérdida a
`../legacy/basic-pro-package-2026-09-04/`. Los archivos 05–07 Pro fueron
retirados del directorio vigente. ADR-001 y ADR-002 siguen aceptados y se
actualizaron solo para nombrar el producto unificado.

Decisiones anteriores de editions, capability gating, upgrade/downgrade,
transcripción Pro y Sheets V1 están superseded. No se reutilizan sus IDs.

## Alcance construido vs pendiente

La auditoría de código en
`current-implementation-gap-analysis.md` cruza los 65 renglones: 14 con
implementación local clara, 22 parciales y 29 faltantes. Esto corrige la lectura
operativa de “Falta” sin declarar producción terminada.

## Backlog oficial

1. Web para configurar contenido/correo.
2. QR.
3. Transcripción/IA de Voice Note.
4. Códigos promocionales/reportes.
5. Dashboard Foloo HQ.
6. Dashboard Foloo Teams.
7. Google Sheets.
8. Integraciones CRM, analítica avanzada, scoring/resúmenes IA y edición de PDF,
   documentados como fuera del producto inmediato en el alcance.

## Infraestructura

Se preservan Flutter, Drift/SQLite, Cognito y ML Kit. La dirección futura es
sync → API Foloo → API Gateway → Lambda Node/TypeScript → base cloud por ADR;
S3 guarda binarios protegidos. No se seleccionó base cloud, proveedor de correo
ni estrategia de pago.

## Trazabilidad histórica

- FL-013A permanece **COMPLETADO** como auth foundation/ownership local.
- FL-013B permanece **COMPLETADO en código, pendiente validación manual de
  dispositivo** para Cognito DEV.
- FL-013C actualiza exclusivamente documentación/arquitectura.
- No se inicia FL-014.
