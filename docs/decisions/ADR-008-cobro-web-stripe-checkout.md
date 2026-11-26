# ADR-008 — Cobro en la web con Stripe Checkout; la app solo informa

- Estado: Aceptado por Producto el 2026-10-21 para la variante A (app
  informativa). La variante B queda **Proposed** y no se implementa.
- Fecha: 2026-10-21.
- Alcance: `MON-04`, `MON-08`, `MON-14`–`MON-20`; resuelve parcialmente `D-01`.

## Contexto

`D-01` pedía elegir entre compra in-app, pago externo en navegador o external
purchase link. Las políticas de Apple (3.1.1, 3.1.3) y Google Play restringen
que una app oriente a un pago externo fuera de las regiones donde hay
programas de enlace externo. Esas reglas cambian por litigio y por región y
deben confirmarse en las guías oficiales antes de cada envío a revisión.

## Decisión

1. **El cobro ocurre fuera de la app**, en una página web de Foloo, con
   **Stripe Checkout** alojado por Stripe. La app no procesa pagos ni recibe
   datos de tarjeta, y no contiene claves de Stripe.
2. **La app es informativa**: cuando la cuenta está en `trial_exhausted` o
   `expired` explica que se alcanzó el límite y que la cuenta se administra en
   la web. No muestra precio, ni la palabra pagar/comprar/upgrade/suscribirse,
   ni botón o enlace al sitio. El texto es solo texto.
   **Enmienda 2026-10-28 (Producto):** la app sí ofrece un botón que abre la
   cuenta en la web de Foloo ("agregar más leads"), sin precio ni palabras de
   cobro. El enlace queda apagado por defecto y solo se habilita por build con
   `FOLOO_WEB_ACCOUNT_LINK=true` para una tienda/región aprobada en `D-01`.
3. **Autoridad**: el backend. El webhook de Stripe, con firma verificada, es lo
   único que puede pasar `accounts.subscription_status` a `active` o
   `expired`. Flutter y la web nunca escriben ese estado (`MON-05`).
4. **Identidad**: la web autentica con el mismo Cognito User Pool; el backend
   deriva la cuenta del `sub` del JWT, nunca del cuerpo (`AUT-10`). La sesión
   de Checkout lleva `client_reference_id = account_id` y metadata del `sub`.
5. **Cancelación y cambio de tarjeta**: Stripe Customer Portal.
6. **Precio y moneda no se inventan** (`D-02`): son un Price ID de Stripe
   suministrado por configuración del entorno. Sin Price ID, el endpoint
   responde `billing_not_configured`.
7. **Idempotencia**: cada evento de Stripe se registra por `event.id` y se
   procesa una sola vez; un reintento no cambia el estado dos veces.

## Variante B (Proposed, no implementada)

Si la revisión de tiendas rechaza la variante A o se decide cobrar dentro de la
app, se evaluará compra nativa (StoreKit / Play Billing, p. ej. mediante
RevenueCat) para las regiones donde sea obligatoria. Requiere nueva decisión de
producto (comisión, precios por tienda, restauración de compras) y un ADR
propio. No se agrega ninguna dependencia de compras ahora.

## Dependencias

- `stripe` (SDK oficial de Node) en el backend: necesaria para construir la
  firma del webhook y las llamadas de Checkout/Portal (`MON-14`–`MON-18`). La
  alternativa, firmar y llamar la API REST a mano, es más riesgosa en un
  límite de seguridad.

## Consecuencias y límites

- Facturación fiscal en México (CFDI) no está resuelta por Stripe; queda como
  pregunta de negocio.
- El estado `expired` por falta de renovación depende de los eventos
  `customer.subscription.updated|deleted` y `invoice.payment_failed`; periodo
  de gracia, reembolsos y términos siguen en `D-03`/`D-04`.
- La aprobación de las tiendas para la variante A no está garantizada.
- Un build sin aprobación explícita conserva el paywall informativo, pero no
  presenta el enlace externo.
- Secretos de Stripe viven en Secrets Manager, nunca en Git ni en Flutter.

## Evidencia técnica histórica de billing (octubre de 2026)

Implementación anterior (entonces denominada FL-021 Billing) y migración
`011_billing_stripe.sql` aplicada aisladamente en DEV el 2026-10-23.
El código es evidencia de capacidad, no permiso para activar Stripe. En el
roadmap vigente pago público y lifecycle corresponden a FL-022; el grant
administrativo FL-021 no depende de este contrato.

- Titularidad server-side por access JWT. Create Customer usa accountId
  idempotente; se relee binding ganador con `stripe_customer_id IS NULL`.
  Checkout/Portal ignoran owner, precio y URLs del cuerpo. Una suscripción
  viva (active/trialing/past_due) evita un segundo Checkout; Portal sin
  customer devuelve 404. Sin configuración se mantiene fallo seguro.
- Webhook verifica firma SDK sobre body crudo antes de conceder acceso.
  `event.id` y mutación comparten transacción; row lock y timestamp evitan
  replay/fuera de orden. Timestamp empatado no revive un expired de la
  misma suscripción. Metadatos owner y Price deben corresponder; solo
  paid/no_payment_required conceden al confirmar Checkout. Unpaid espera
  evento. Customer conocido aún sin vínculo puede requerir 503/retry;
  eventos ajenos o mode=payment no conceden ni crean identidades.
- Active/trialing habilitan; canceled/unpaid/deleted vencen. `past_due` o
  `invoice.payment_failed` aislados no vencen ni prueban fin de reintentos.
  No se aprueban gracia, reembolsos ni reconciliación periódica aquí.
  `billing_events` conserva deduplicación con SELECT/INSERT, no
  UPDATE/DELETE de la app; no sustituye retención contable legal.
- Secretos por nombre exacto o ARN completo, nunca ARN parcial; solo lectura
  scoped; en el corte histórico cache exitoso 5 min y throttling webhook
  10/s, burst 20. El proveedor no accede a PostgreSQL. Conservar la
  dependencia del stage con su ruta; un intento sin ella falló el 2026-10-22.
- D-02 actualizó el precio **de prueba** del corte a anual: USD 89 y
  MXN 1,780 con impuesto incluido para MXN. El antiguo mensual era de
  prueba y queda superado; no usar IDs/URLs históricas en PROD. Evidencia
  local original: 154/154, incluido PostgreSQL descartable, e
  infraestructura con fixtures. Revalidar runtime y políticas al retomar
  FL-022; no activar `BILLING_ENABLED` a partir de este registro.
