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
- Content/PDF: id, owner, nombre visible, nombre de archivo, peso,
  asignación a eventos o todos, ruta privada, revisión y tombstone. Plantillas,
  preparaciones e intenciones de correo tienen modelo durable; suscripción aún
  no tiene un modelo productivo completo.
- Conexión de correo/follow-up: ADR-006 fija la relación Cognito
  `sub`/workspace → identidad Google/Microsoft autorizada. Plantillas
  Event/Direct por idioma, intención de envío, intento, snapshot de remitente,
  adjuntos y opt-out deben ser owner-scoped. La intención confirmada es distinta
  de la preparación tras guardar Lead y del retry técnico. Un timeout tras
  posible aceptación del proveedor deja Estado por confirmar, no retry ciego.
  El default del vendedor se identifica por owner/origen/idioma y el override
  opcional por owner/evento/idioma; ausencia de override significa herencia,
  no copia. Una preparación sin intención se reutiliza por Lead y queda fuera
  del historial real hasta la confirmación explícita: antes de ella reconcilia
  destinatario y Content con el Lead actual. Asunto y cuerpo guardan por separado
  una representación ordenada de segmentos literales/tokens y su indicador de
  edición manual: esto permite conservar el delta literal de Review y volver a
  renderizar solo tokens canónicos, sin reemplazar coincidencias arbitrarias.
  Esa metadata vive en Drift mientras la preparación está activa y sobrevive
  offline/restart. La intención confirmada referencia el follow-up ya congelado
  y no vuelve a consultar datos mutables para reescribirlo.

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

## Modelo remoto desde FL-014

- `app_user`: identidad técnica por Cognito `sub`; email no es owner.
- `account`: límite comercial personal actual.
- `workspace` + `workspace_member`: límite de datos y membresía owner inicial;
  prepara evolución sin implementar Teams.
- `seller_profile`: perfil Foloo separado de Cognito.
- `event`, `lead`: UUID suministrable por el cliente, `revision`, timestamps y
  `deleted_at`; toda consulta se limita por workspace.
- El tombstone de Evento conserva su fila y las FK de Leads asociados; Registros
  mantiene visibles esos Leads aunque el evento deje de aparecer en Mis eventos.
- `lead_media`: metadata de tarjeta, referencia o Voice Note. Nunca contiene el
  binario. `upload_status` transita `pending → available`; `storage_object_key`
  es una referencia privada derivada por backend y `uploaded_at` solo existe
  después de verificación S3.
- `content_file`: metadata PDF, asociaciones por evento, estado de upload y
  tombstone. La key privada S3 no sale en las respuestas. El Lead congela IDs
  y nombres seleccionados en captura; un borrado posterior no los reescribe.
- `idempotency_record`: conserva el resultado de creaciones reintentables por
  workspace/operación/clave.

PostgreSQL en RDS es el motor cloud aceptado (ADR-003). Los UUID locales se
mantienen como IDs remotos para evitar remapeos durante FL-015. La revisión se
incrementa en cambios y permitirá precondiciones/conflictos futuros; FL-014 no
implementa reconciliación.

`sync_operation` es la outbox local durable de ADR-004. Pertenece a un Cognito
`sub`, conserva una clave idempotente estable y un snapshot JSON pequeño, nunca
tokens ni binarios. Una entidad con operación abierta no es sobrescrita por el
pull completo de FL-015.

S3 guarda binarios bajo workspace/Lead/media UUID o workspace/Content UUID.
La URL firmada es una
capacidad efímera, no identidad ni dato persistente. Drift conserva la copia
privada local y la outbox conserva solo metadata e identidad lógica. La base
cloud guarda metadata/referencias; no hay secretos AWS en Flutter. PDF tiene
límite técnico de 25 000 000 bytes, sin cuota comercial total ni desalojo
automático local. La política de retención y eliminación definitiva remota
sigue pendiente en D-13.
