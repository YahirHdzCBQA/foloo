# Modelo conceptual vigente — Foloo V1

Navega las entidades de `../product/product-spec.md`; no es
un esquema SQL/API definitivo.

## Ownership

Cognito `sub` → Perfil Foloo → Eventos/Leads/Preferencias. Medios derivan
ownership por su Lead o archivo. Email nunca sustituye el identificador estable.

## Entidades locales actuales

- Perfil: hoy Drift guarda nombre/empresa; V1 agrega puesto/teléfono y foto.
- Evento: id, owner, código, nombre, inicio/fin, activo, eliminado, contenido.
- Lead: id técnico, owner, folio opcional, timestamp, origen/evento/lugar,
  contacto, tipo/interés, nota, estados y medios.
- LeadMedia: tarjeta, Voice Note o imagen de referencia, ruta privada local.
- Preferencia: clave/valor por owner.
- Contenido/plantilla/suscripción: aún no tienen modelo productivo durable
  completo; las clases demo no son contrato.

## Invariantes

- Persistir Lead y medios localmente antes de red.
- Un Lead pertenece a un solo `sub`.
- Evento/directo son mutuamente exclusivos; directo exige lugar.
- Tipo es Cliente/Partner/Proveedor; interés es Bajo/Medio/Alto.
- Voz, nota, tarjeta e imágenes de referencia son opcionales; máximo tres
  referencias.
- Adjuntos PDF enviados quedan congelados en la historia del Lead.
- Correcciones no cambian owner ni eliminan medios sin una acción aprobada.
- Pago inactivo no cambia visibilidad o propiedad de datos previos.
- Identidad/idempotencia remota no se infiere del folio comercial.

## Modelo remoto futuro

API/Lambda debe representar cuenta, perfil, evento, lead, media, archivo,
plantilla, trabajo de correo y suscripción. Debe admitir evolución futura a
organizaciones/vendedores sin incorporar Teams a V1. El motor cloud está
abierto (`D-12`).

S3 guardará binarios con acceso autenticado y política de retención. La base
cloud guardará metadata/referencias, no secretos en Flutter.
