# STORE-02D — Registro posterior a revisión CBQA y agenda de validación

- Estado: acuerdos de Producto/CBQA comunicados; validaciones y autorización
  formal pendientes
- Contrato base: [`account-deletion-contract.md`](account-deletion-contract.md)
- Decisión abierta: `D-13`
- Fecha de reunión: no registrada en la evidencia disponible
- Participantes: no registrados en la evidencia disponible
- Responsable de minuta: pendiente de designar
- Evidencia incorporada al repositorio: comunicación de Producto del 2026-10-20

## Objetivo

Conservar los acuerdos comunicados sin presentarlos como aprobación legal,
técnica u operativa integral. Esta agenda sirve para cerrar las validaciones,
asignar responsables y obtener autorización expresa antes de implementar
STORE-02E. Un acuerdo funcional no sustituye la evidencia del área validadora.

Los tres relojes no deben confundirse: Producto definió un máximo operativo de
15 días para eliminación; la retención ordinaria de backups por 15 días es una
propuesta; y la reautenticación de cinco minutos es otra propuesta. La cuenta
anterior nunca se recupera; después de 30 días puede crearse una cuenta nueva
con el mismo correo, sin datos ni beneficios previos.

## Registro de decisiones y acciones pendientes

| ID | Acuerdo o propuesta comunicada | Estado actual | Pregunta/acción de cierre | Responsable | Fecha/evidencia |
|---|---|---|---|---|---|
| `DEC-AD-01` | Borrar datos personales/operativos; retener solo categorías administrativas, contables o legales realmente exigidas | Acuerdo Producto/CBQA | Legal/Contabilidad: enumerar categoría, base, región y plazo; descartar retención indefinida por defecto | Pendiente | Comunicación 2026-10-20; validación pendiente |
| `DEC-AD-02` | Backups ordinarios por 15 días y restore con protección anti-resurrección | Propuesta | Infra/Seguridad: confirmar viabilidad, accesos, ledger y runbook; Legal: separar legal hold | Pendiente | Comunicación 2026-10-20; validación pendiente |
| `DEC-AD-03` | Solo registros mínimos seudonimizados con propósito y plazo válidos | Acuerdo Producto/CBQA | Legal/Seguridad: definir campos, HMAC, finalidad, acceso y expiración | Pendiente | Comunicación 2026-10-20; diseño pendiente |
| `DEC-AD-04` | Máximo operativo de 15 días; iniciar y completar cuanto antes | Regla de Producto | Operación/Legal: validar viabilidad por región, escalamiento y canal de confirmación | Pendiente | Comunicación 2026-10-20; no es aún SLA publicable |
| `DEC-AD-05` | Irreversible tras aceptación; nuevo registro con el mismo correo después de 30 días como cuenta nueva | Regla Producto/CBQA | Seguridad/Legal: aprobar enforcement mínimo, federados, normalización y PII; confirmar excepciones | Pendiente | Comunicación 2026-10-20; mecanismo pendiente |
| `DEC-AD-06` | Ofrecer sync y permitir continuar con advertencia irreversible y consentimiento explícito | Acuerdo Producto/CBQA | Producto/Legal: aprobar copy; QA: cubrir outbox online/offline | Pendiente | Comunicación 2026-10-20 |
| `DEC-AD-07` | Retry, registro de fallos y escalamiento | Acuerdo Producto/CBQA | Designar owner operativo; fijar límites, alertas, runbook y paso a `blocked` | **No designado** | Comunicación 2026-10-20 |
| `DEC-AD-08` | Purga local selectiva por owner; cifrado se revisa aparte | Acuerdo Producto/CBQA | Seguridad/Legal: revisar protección; QA: multi-owner y archivos | Pendiente | Comunicación 2026-10-20 |
| `DEC-AD-09` | Reautenticación server-side con ventana máxima propuesta de cinco minutos | Propuesta | Seguridad: validar señal Cognito, reloj, password/Google y fallback | Pendiente | Comunicación 2026-10-20; validación pendiente |
| `DEC-AD-10` | Suscripciones/pagos previstos en `foloo.io`; advertir PRO, cancelar renovación, comprobar resultado, enviar correo y conservar resolución de fallos | Dirección Producto/CBQA | FL-021/Payments/Legal: proveedor, API, reembolsos, periodos pagados y políticas Apple/Google | Pendiente | Comunicación 2026-10-20; no implementado |
| `DEC-AD-11` | Exportación previa voluntaria, nunca requisito | Acuerdo Producto/CBQA | Legal: confirmar portabilidad; Producto: copy | Pendiente | Comunicación 2026-10-20 |
| `DEC-AD-12` | `foloo.io` como punto principal; ruta candidata `foloo.io/delete-account`; mismo backend app/web | Dirección Producto/CBQA | TI: hosting, TLS, publicación, owner, monitoreo y soporte; Legal: contenido | Pendiente | Comunicación 2026-10-20; URL no publicada |
| `DEC-AD-13` | Mantener abierta la definición de roles sobre datos de terceros | Decisión Legal/operativa pendiente | Legal: controlador/encargado por mercado y proceso; CBQA: designar owner | **No designado** | Comunicación 2026-10-20 |
| `DEC-AD-14` | Producto multirregión; no asumir México como único mercado | Dirección Producto/CBQA | Dirección/Producto/Legal: países, idiomas, edad mínima y controles | Pendiente | Comunicación 2026-10-20 |

## Validaciones por área

| Área | Confirmaciones necesarias | Responsable nominal | Fecha compromiso | Evidencia/enlace |
|---|---|---|---|---|
| Legal/Contabilidad | Retenciones AD-01/02/03, terceros AD-13, portabilidad, regiones y menores | Pendiente | Pendiente | Pendiente |
| Seguridad | Barrier de 30 días, HMAC/PII, reautenticación, receipts y revocación | Pendiente | Pendiente | Pendiente |
| Infra/TI | Backup/restore, `foloo.io/delete-account`, hosting, monitoreo y soporte | Pendiente | Pendiente | Pendiente |
| Operación | Owner de incidentes, retry/escalamiento y techo de 15 días | Pendiente | Pendiente | Pendiente |
| Payments/FL-021 | Proveedor, cancelación, pagos/reembolsos y políticas de tiendas | Pendiente | Pendiente | Pendiente |
| Producto/Dirección | Países, idiomas, menores, copy final y autorización de implementación | Pendiente | Pendiente | Pendiente |

## Cierre requerido antes de STORE-02E

- [ ] Validaciones especializadas documentadas con responsable y fecha.
- [ ] Owner operativo de incidentes y solicitudes de terceros designado.
- [ ] Criterios promovidos a IDs y escenarios SDD canónicos.
- [ ] Copy ES/EN y promesas públicas aprobados por región.
- [ ] Autorización expresa, acotada por subtarea, para implementar STORE-02E.

### Resultado al corte

- Acuerdos funcionales comunicados: `DEC-AD-01`–`DEC-AD-14`, con el grado de
  certeza indicado en la tabla.
- Decisiones/validaciones todavía abiertas: retenciones concretas, backups,
  registro mínimo, enforcement de 30 días, reautenticación, operación,
  suscripciones, roles sobre terceros, mercados/idiomas/menores y publicación
  web.
- Trabajo seguro sin autorización funcional: trazas, threat model, diagramas,
  casos de prueba, borradores OpenAPI/copy y evaluación técnica no desplegada.
- Autorización para implementar STORE-02E: **no registrada**.
- `D-13`: **abierta**.
