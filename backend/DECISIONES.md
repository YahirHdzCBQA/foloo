# FL-021 — Billing servidor (2026-10-21)

- Autoridad: ADR-008 variante A, AUT-10, MON-04–MON-20 y E-11. ADR-008 ya
  justifica `stripe`; SDK oficial verifica firmas y crea Checkout/Portal sin
  implementar manualmente el protocolo. Solo backend cambia en esta entrega.
- D-01 conserva texto bloqueante anterior en open-decisions/roadmap; se sigue
  ADR-008 aceptado y el encargo explícito para esta rama. D-02 queda en Price ID
  suministrado; D-03/D-04 no se convierten en una política inventada de gracia.
- `active`/`trialing` conceden active; `canceled`/`unpaid` y deleted vencen.
  `past_due` por sí solo conserva estado. `invoice.payment_failed` se registra
  sin vencer: ni un primer fallo ni `next_payment_attempt=null` prueban que se
  agotaron reintentos con Automations. Se requiere configurar Stripe para pasar
  a unpaid/canceled al agotarlos; dejar past_due indefinidamente no está
  soportado como señal final. No se agregan días de gracia ni reembolsos.
  Fuente: [Stripe Smart Retries](https://docs.stripe.com/billing/revenue-recovery/smart-retries).
- Checkout completed verifica que metadata.sub corresponde al owner de
  client_reference_id existente y que metadata.origin=foloo-app (lo pone solo
  el proveedor interno), o que el único line item tiene STRIPE_PRICE_ID.
  Solo paid/no_payment_required conceden active; unpaid vincula IDs y espera
  customer.subscription.updated. No se crean identidades desde webhooks.
  El periodo proviene del snapshot de suscripción (items.data en API nueva).
- Checkout con trial restante se permite desde web: MON-19 dice que no es
  necesario, no que esté prohibido. Active responde 409 con instrucción de Portal.
- No se agrega GET status: workspace ya entrega subscriptionStatus. Los cuerpos
  de Checkout/Portal se ignoran incluso si contienen identidad/precio/URLs.
- E-11 se complementa con los casos de aceptación del encargo en tests billing:
  firma/base64, aislamiento JWT, activo/503, duplicados concurrentes, rollback,
  expiración sin tocar Leads, proveedor y permisos/rutas de infraestructura.
- No se implementa compra nativa, UI web, cancelación/reembolsos propios ni
  reconciliación periódica. billing_event_at ordena por event.created de Stripe:
  cada UPDATE exige timestamp no anterior. Un empate no revive expired para
  la misma suscripción; un snapshot posterior sí puede reflejar recuperación.
  La fila se bloquea durante clasificación/aplicación y event.id comparte commit.
- Una suscripción de customer conocido aún sin vínculo, o identificada por
  metadata.accountId antes de persistir customer, revierte event.id y responde 503. Suscripciones desconocidas/ajenas/reemplazadas y mode=payment se registran
  con 200 sin cambiar estado. No se confunde un UPDATE viejo con un vínculo pendiente.
- El proveedor crea customer con idempotencyKey=accountId. La API guarda el ID
  con UPDATE ... stripe_customer_id IS NULL y relee el ganador antes de Checkout.
  El proveedor pagina subscriptions y rechaza active/trialing/past_due con 409
  hacia Portal, incluso con estado local atrasado. La Lambda pública no accede
  a PostgreSQL ni recibe permisos nuevos de base de datos.
- Secrets Manager recibe nombres exactos (defaults foloo/dev/stripe-api-key y
  foloo/dev/stripe-webhook-signing); el lector también admite ARN completo, nunca
  se construyen ARN parciales para lectura. Cache exitoso por contenedor: 5 min.
  Sin stripe-signature se devuelve 400 antes de leer secretos. Throttle operativo
  de webhook: 10 solicitudes/s, burst 20; Stripe puede reintentar 429.
- Billing se habilita por defecto y synth exige Price ID, URLs y nombres de
  secretos. BILLING_ENABLED=false lo desactiva explícitamente sin quitar recursos
  ni cambiar logical IDs; no se inyecta configuración billing a las Lambdas.
- Migración 009 aún no liberada: se edita in situ y billing_events recibe solo
  SELECT/INSERT. Se revocan UPDATE/DELETE heredados de los default privileges de
  migración 001; cambiar solo el GRANT no bastaba. No se pueden modificar ni borrar recibos.

## Evidencia local de la revisión

- Lecturas: product-spec MON-15–MON-19/AUT-10, E-11, open-decisions,
  architecture/overview, traceability, roadmap y ADR-008. Los casos nuevos en
  backend/test extienden E-11 según el encargo. Se usó la implementación FL-021
  existente; no se tocó documentación ni código fuera de backend.
- Pruebas de webhook con firma SDK por HTTP local y PostgreSQL 15 temporal real
  (migración 009, rol foloo_app, carreras, rollback, orden y grants), además
  del fake transaccional. Para repetir la prueba PostgreSQL, proporcionar
  BILLING_TEST_DATABASE_URL de una base local descartable con permiso de crear
  esquema/rol; crea un esquema aislado y lo conserva, sin borrar datos.
- No se hicieron llamadas a Stripe ni AWS, commits, despliegues o cambios cloud.
- npm ci/audit reporta una vulnerabilidad alta transitiva en brace-expansion;
  no se cambia el lockfile para resolver dependencias fuera de este encargo.
- Resultado final: npm ci, format:check (tras prettier de archivos tocados),
  lint, typecheck, 154/154 tests sin skips y build correctos. La suite completa
  se ejecutó con BILLING_TEST_DATABASE_URL hacia PostgreSQL 15 local temporal.
- `npx cdk synth -c environment=dev` falla explícitamente sin las cuatro
  variables de precio/URLs; `BILLING_ENABLED=false npx cdk synth -c environment=dev`
  pasa. No se inventaron valores operativos. Las pruebas de infraestructura
  también sintetizan billing habilitado con valores de fixture.
- Template previo guardado antes de editar (`/tmp/foloo-before.template.json`)
  frente al synth final: 64/64 logical IDs y tipos conservados, cero recursos
  agregados/eliminados. RDS/VPC/EC2/S3 idénticos. Cambian código/configuración de
  Lambdas, políticas de secretos y RouteSettings del stage existente. Esta
  comparación es local contra la implementación recibida, no contra AWS.

## 2026-10-22 · Rebase sobre STORE-02 y despliegue en DEV

- La migración de billing pasa a `011_billing_stripe.sql` (STORE-02 ocupa 009/010).
- IDs renumerados por choque con STORE-02: billing `MON-14`–`MON-20`. Apple/Microsoft (`AUT-22`–`AUT-24`, ADR-009) salen de este PR a uno propio (2026-10-23).
- `POST /v1/billing/webhook` se agregó a las rutas públicas del guard de clientes de API: Stripe no manda JWT; la firma la valida el router.
- El stage depende de la ruta del webhook; sin eso, CloudFormation falló al aplicar el throttling (2026-10-22).
- Valores por defecto en DEV (las variables de entorno los sobrescriben): Price de prueba de 99 USD/mes `price_1UTTLKCp0Un1sf9uyTk4w9NN` ("Foloo Pro (prueba)"), retornos a `https://foloo.io/dashboard?billing=success|cancel` y portal a `/dashboard`. Es un supuesto: falta la página web real de planes.
- 2026-10-23: la 011 se aplicó sola en DEV con `{"action":"apply","only":"011_billing_stripe.sql"}`. La 010 de STORE-02 sigue pendiente para su propio procedimiento (backup y autorización); es independiente de la 011 y puede aplicarse después.
