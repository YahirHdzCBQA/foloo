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
