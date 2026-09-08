# 00 · Constitución de Foloo V1

Vigente desde 2026-09-08. Estas reglas no se negocian por conveniencia técnica,
estado de red, pago o comportamiento heredado del prototipo.

## Artículo 1 — El contexto de uso manda

Foloo se usa de pie, con una mano, bajo presión y con conectividad irregular.
El flujo principal vive en orientación vertical, conserva contexto y permite
capturar un lead en menos de 60 segundos.

## Artículo 2 — El lead nunca se pierde ni se oculta

Guardar confirma primero una escritura durable local y después intenta red.
Cerrar sesión, perder señal, fallar un correo o vencer una suscripción no borra
ni oculta perfiles, eventos, leads o medios ya capturados.

## Artículo 3 — Ninguna credencial de servicio vive en el teléfono

El cliente móvil no contiene secretos IAM, Client Secret, credenciales de
correo, storage ni pagos. Amplify administra tokens de Cognito en el mecanismo
seguro de plataforma; Drift no almacena tokens.

## Artículo 4 — Offline es un estado normal

La aplicación conserva captura y consulta local sin red. Las colas y estados
pendientes se comunican con icono y palabra. Offline no significa logout ni
confirma que el backend esté caído.

## Artículo 5 — El estado nunca depende solo del color

Interés, sincronización, error, selección y pago se expresan con texto o icono
además del color, con contraste válido en claro y oscuro.

## Artículo 6 — El sistema visual es cerrado

Se reutilizan tokens, componentes y assets aprobados. Lima se reserva para CTA,
selección activa o detalle de marca; no se inventan estilos por pantalla.

## Artículo 7 — Ergonomía de una mano

Acción principal fija de 56 dp; objetivos táctiles de al menos 44 dp; acciones
destructivas separadas y protegidas; listas, buscadores y selectores evitan
desplazamiento horizontal innecesario.

## Artículo 8 — Una sola Foloo V1, ES/EN

Todos los usuarios reciben las mismas capacidades V1. Español e inglés son de
primera clase. No existen pantallas o controles Basic/Pro. El idioma no cambia
datos, permisos ni reglas de negocio.

## Artículo 9 — El pago limita creación, no propiedad

El trial permite cinco leads guardados por cuenta. El intento de guardar el
sexto se conserva intacto mientras se presenta el paywall. Una cuenta no activa
puede consultar, editar, exportar y operar datos previos; solo se bloquea crear
nuevos leads. Quien ya pagó no se bloquea solo por perder red.

## Artículo 10 — Datos personales desde el dispositivo

Tarjetas, contacto, voz e imágenes de referencia son datos personales desde su
persistencia local. Deben tener acceso, cifrado, retención y eliminación
definidos antes de producción.

## Artículo 11 — Lo no escrito se decide

No se infieren proveedores, límites, precios, políticas de tiendas, contratos
de API o estados de pago. Una contradicción sin actualización fechada se
registra como decisión abierta.
