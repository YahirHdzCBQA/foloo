# ADR-007 — Frontera OAuth, egreso e idempotencia de correo

- Estado: Aceptado e implementado localmente para FL-019; pendiente de
  configuración externa, deploy y validación física.
- Fecha: 2026-09-18
- Trazas: `PLT-*`, `SAL-01`–`SAL-09`, E-08, ADR-003/004/005/006.

## Contexto

La API existente comparte Lambda con PostgreSQL en subredes aisladas sin NAT.
Google OAuth/Gmail y Microsoft OAuth/Graph necesitan HTTPS público. Mover esa
Lambda a una subnet pública no le da Internet y exponer RDS contradice ADR-003.
Además, una respuesta perdida tras aceptación por proveedor no se puede tratar
como retry seguro aun si Foloo deduplica la operación API.

## Decisión técnica

1. Mantener la Lambda de API y PostgreSQL privados. Separar las llamadas a
   proveedores en una Lambda sin VPC que no recibe credenciales de base de datos
   ni acceso a tablas. La Lambda privada invoca esa frontera mediante un VPC
   interface endpoint de Lambda con IAM restringido. El callback público de
   OAuth llega a una ruta no autenticada del mismo frontend HTTP pero con
   estado de un solo uso vinculado server-side a `sub`/workspace, expiración,
   PKCE y redirect allowlist; no se toma ownership desde parámetros de Flutter.
2. Mantener secretos de aplicación en AWS Secrets Manager. Guardar credenciales
   renovables por vendedor cifradas con AWS KMS en PostgreSQL, asociadas a
   workspace, provider e identidad externa. Solo la frontera de proveedor
   puede descifrarlas; la API privada registra/reemplaza ciphertext y nunca
   entrega tokens a Flutter. No crear versiones de Secrets Manager en cada
   refresh.
   El endpoint autenticado de estado devuelve únicamente provider, dirección
   enmascarada y estado. Flutter lo vuelve a consultar al abrir Correo y al
   reanudar desde el navegador; una marca local de onboarding nunca acredita
   conexión OAuth.
3. Una intención explícita usa UUID/idempotency key única y snapshot de
   destinatario, identidad remitente, template y adjuntos. Al iniciar una
   llamada potencialmente aceptable, persistir intento `sending`. Si se
   pierde la respuesta después de iniciar la llamada, pasar a
   `confirmation_required`; prohibir retry automático. Solo fallos
   inequívocamente previos a la petición, 429/5xx explícitos y auth renovable
   pueden reintentarse con la misma intención. Un reenvío manual usa UUID nuevo.
   La preparación local no entra a la outbox hasta que el vendedor confirma la
   pantalla “Revisar”; así una edición concreta nunca compite con una versión
   temprana ya creada en servidor.
4. La aceptación de Gmail/Graph se registra como `sent` con ID/fecha del
   proveedor cuando exista, pero no se presenta como entrega final al buzón.
   Graph `sendMail` responde `202` sin body; ese contrato es aceptación válida,
   no una respuesta perdida ni un motivo para `confirmation_required`.
   Historial conserva la identidad efectiva original aun al cambiar cuenta.
5. La baja usa token opaco de alta entropía, almacenado como hash y vinculado a
   workspace/destinatario; el endpoint público es idempotente, no revela
   IDs internos y bloquea futuros envíos de ese scope. El token no se expone a
   logs. El enlace es de duración prolongada para que correos históricos
   mantengan una vía de baja; la rotación/revocación sigue siendo posible.
6. Con el scope delegado Microsoft `Mail.Send` aprobado no se pide
   `Mail.ReadWrite`. El flujo documentado por Microsoft para adjuntos Graph de
   3 MB o más usa upload session sobre un draft y requiere `Mail.ReadWrite`;
   por tanto FL-019 no debe intentar adjuntarlos con ese scope ni elevar
   permisos en silencio. Debe activar la elección de D-19 de omitir para esa
   intención o cancelar. En Google se valida el límite efectivo del mensaje
   antes de `gmail.send`, incluido overhead MIME; nunca convertir a Drive o
   enlace público en silencio.

## Alternativas y consecuencias

- NAT Gateway para la Lambda privada: más sencillo en red, pero introduce
  costo fijo y abre egreso a toda la API; se descarta en DEV de bajo costo.
- Confiar en `Idempotency-Key` hasta el proveedor: rechazado porque Gmail y
  Graph no prometen exactly-once para `send` tras timeout ambiguo.
- Secrets Manager por refresh: rechazado por churn de versiones/costo/cuotas.
- La frontera separada añade un endpoint de PrivateLink y una Lambda, con
  costo fijo menor que NAT Gateway pero no nulo. El despliegue debe verificar
  cuotas/costos reales de la cuenta. El API/DB siguen privados y el S3 de
  Content no se publica.
- La dirección postal y responsable legal exactos quedan como pendiente de
  compliance; no se inventan en código ni se usan para el mecanismo técnico
  de opt-out.

Referencias técnicas: [Lambda VPC sin Internet en subnet pública](https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc-internet.html),
[adjuntos grandes de Graph](https://learn.microsoft.com/en-us/graph/outlook-large-attachments),
[scope de upload session Graph](https://learn.microsoft.com/en-us/graph/api/attachment-createuploadsession?view=graph-rest-1.0),
[límite de adjuntos Gmail](https://support.google.com/mail/answer/6584?hl=en-uk).
