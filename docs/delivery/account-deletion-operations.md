# STORE-02D — Operación, SLA y restauración

**Trazas:** `AUT-19`, `MON-13`, `INF-15`–`INF-21`, `RNF-09`, `RNF-10`,
`RC-06`, `RC-07`, `RC-10`, E-14 y D-13.

## Contrato operativo

- El reloj comienza en `acceptedAt`; `operationalDeadline` es 15 días naturales
  después. Alertas preventivas: días 10 y 13; incidente crítico: día 15.
- Owner funcional: equipo de TI de CBQA Solutions. Personas y destinos se
  configuran solo al cerrar `PEND-OPS-01`; el tópico SNS nace sin suscriptores.
- Receipt/status es la fuente autoritativa. SES no cambia el workflow ni prueba
  finalización. Logs/alertas usan requestId opaco, tipo y estado; nunca email,
  `sub`, tokens, object keys, payloads o secretos.
- Logs STORE-02 en DEV retienen siete días. La retención productiva se valida
  con Legal/Seguridad antes de `PEND-PROD-01`.

## Runbooks

### Bloqueo Stripe

1. Confirmar `blocked` y checkpoint de suscripción ausente; no tocar barrera,
   receipt ni outbox.
2. Verificar salud de Billing y binding owner-scoped sin registrar referencias.
3. Dejar que el reconciliador redespache con el mismo request/idempotency key.
4. Solo una confirmación fiable de no renovación habilita etapas destructivas.

### Worker, SQS o DLQ

1. Congelar intake si aparecen fallos múltiples; mantener guards/barrera.
2. Revisar métricas worker, edad de cola, DLQ y checkpoints.
3. Corregir causa y reactivar consumo mediante Change Set auditado; no purgar.
4. Entregas duplicadas deben terminar sin repetir efectos ni mover `completed`.

### Próxima a vencer

1. Día 10: asignar caso y dependencia; día 13: escalar al responsable operativo.
2. Día 15: incidente crítico; conservar `blocked`, barrera y soporte code.
3. Nunca cambiar a `completed` sin verificación OAuth/S3/PostgreSQL/Cognito y,
   cuando aplique, cancelación Stripe confirmada.

### Fallo de notificación

1. Revisar errores SES y DLQ sin reenviar manualmente en paralelo.
2. El claim durable deduplica eventos; un lease vencido permite retry acotado.
3. Informar por receipt/status; correo fallido no bloquea ni revierte borrado.

### Restore de backup

1. Mantener API/intake cerrados. Recuperar primero ledger y tombstones vigentes.
2. Restaurar PostgreSQL y ejecutar reconciliador; reaplicar write fence y purga.
3. Validar cero barreras inconsistentes y ausencia de owners eliminados.
4. Abrir tráfico solo con aprobación de TI. Los backups automáticos ordinarios
   expiran a 15 días; snapshots manuales/exportaciones deben inventariarse y
   retirarse mediante un procedimiento autorizado. Un legal hold permanece segregado y sin uso
   para reactivar cuentas.

### Incidente de seguridad

1. Detener intake y aislar credenciales afectadas sin retirar tombstones.
2. Preservar evidencia mínima PII-free y auditar KMS/IAM/CloudTrail.
3. Escalar a TI/Seguridad/Legal; no revelar existencia de cuentas por soporte.
4. La eliminación asistida exige verificación reforzada de acceso/titularidad.

## Pendientes de lanzamiento

- `PEND-PROD-01`: AWS PROD independiente creado y validado.
- `PEND-LEGAL-01`: categorías y plazos legales/fiscales de México validados.
- `PEND-INFRA-02`: retención/restore comprobados sobre recursos productivos.
- `PEND-OPS-01`: responsables individuales y destinos de alertas asignados.

Estos pendientes no bloquean desarrollo local; sí bloquean habilitación pública.
