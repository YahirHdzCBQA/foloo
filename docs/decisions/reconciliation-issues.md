# Contradicciones y reconciliación — corte 2026-09-08

| ID | Fuentes | Tratamiento |
|---|---|---|
| `RQ-V1-01` | Alcance/Cambios 2026-09-07 retiran exportación; XLSX 2026-09-08 la reincorpora | Actualización posterior explícita: XLSX/CSV por evento están en V1. |
| `RQ-V1-02` | SDD anterior exigía Google Sheets; fuentes nuevas lo envían a backlog | V1 elimina Sheets, incluida su mención del acuse. |
| `RQ-V1-03` | SDD anterior orientaba OCR estructurado al backend; alcance/XLSX confirman Google ML Kit | ML Kit en dispositivo es V1. |
| `RQ-V1-04` | SDD anterior incluía transcripción Pro; fuentes nuevas la retiran | Voice Note sí; transcripción automática/IA no. |
| `RQ-V1-05` | SDD anterior recomendaba evaluar SES; XLSX exige Google Workspace/DKIM | Contradicción no resuelta: `D-09`. |
| `RQ-V1-06` | Alcance dice detalle editable; código/SDD previo lo dejaron lectura | El requerimiento vigente es editable; medios post-guardado dependen de `D-06`. |
| `RQ-V1-07` | Alcance dice foto de perfil opcional y lista más campos que Drift actual | V1 exige nombre/puesto/empresa/teléfono y foto opcional; código queda parcial. |
| `RQ-V1-08` | XLSX llama “65 pendientes” a trabajo que el repo ya implementó | El estado se corrige solo en auditoría documental; no se modifica el XLSX. |
| `RQ-V1-09` | XLSX fija 30-sep y reloj manual; fecha actual puede cambiar | Es un corte operativo, no promesa automática ni cálculo de runtime. |
