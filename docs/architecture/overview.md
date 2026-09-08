# Arquitectura de alto nivel — Foloo V1

## Estado actual aceptado

- Flutter para iOS/Android.
- Drift + SQLite para datos estructurados locales (ADR-001).
- Directorio privado de aplicación para medios locales.
- AWS Cognito DEV mediante Amplify para identidad/sesión (ADR-002).
- Google ML Kit en dispositivo para OCR de tarjetas.
- Un solo producto: no existe una frontera Basic/Pro.

### Autenticación y ownership

`UI → AuthRepository → AuthService → CognitoAuthService`; FakeAuth queda solo
para tests/desarrollo controlado. Cognito DEV usa región `us-east-1`, User Pool
`us-east-1_QVm3dWe4O` y App Client público
`6jong3atp2crqcsde6g215ant8` sin Client Secret. Self sign-up es email/password,
con código por email; MFA de usuario, passwordless y social login están fuera.
El `sub` es ownership estable. Perfil Foloo no es un atributo Cognito.

### Idioma y apariencia

Flutter ARB mantiene ES/EN con un estado compartido por Login y Drawer; español
es fallback. Nombres propios, enums persistidos y tokens de plantilla no se
traducen. Claro/oscuro remapea tokens y preferencias por usuario.

## Dirección V1, todavía no implementada

```text
Flutter
  ↓
Drift / SQLite
  ↓
Offline Sync
  ↓
Foloo API
  ↓
API Gateway
  ↓
AWS Lambda (Node.js + TypeScript)
  ↓
Persistencia cloud por decidir
```

S3 es la dirección para tarjeta, imágenes de referencia, Voice Note y PDF.
Seleccionar base cloud, sincronización, API, S3 o correo requiere ADR/decisiones
propias; este documento no los declara implementados.

## Responsabilidades móviles

- Cognito session bootstrap y perfil Foloo separado.
- Repositorios locales aislados por Cognito `sub`.
- Evento/directo, CRUD/selección/agrupación por fecha real.
- Captura, ML Kit, clasificación, voz, texto e imágenes.
- Escritura durable local antes de red.
- Consulta/edición local, contenido/plantillas y exportación por evento.
- Estado de conectividad separado de AuthState y disponibilidad del backend.
- Caché futura de suscripción sin conceder autoridad de pago al cliente.

## Responsabilidades del backend futuro

- Autoridad del trial y suscripción, webhooks y reconciliación.
- API idempotente, ownership/tenancy y persistencia cloud.
- Storage S3 protegido, retención y URLs no públicas.
- Sync reanudable de Leads y medios con colas independientes.
- Plantillas server-side, sustitución, adjuntos y correo.
- SPF/DKIM/DMARC, rebotes, bajas y reputación.
- Entregar estado remoto verificable a la app.

No forman parte de V1 Google Sheets, Transcribe/IA, QR, Teams o HQ dashboard.

## Flujo conceptual

1. Cognito restaura `sub`; Foloo carga su perfil/datos locales.
2. El usuario conserva o elige evento/origen.
3. ML Kit local ayuda a completar la tarjeta; captura manual siempre funciona.
4. Guardar confirma Drift y medios privados.
5. El contador remoto autoriza la nueva captura o conserva el borrador y abre
   paywall al sexto Lead.
6. La futura sync envía operaciones idempotentes y medios por colas separadas.
7. El backend prepara correo y adjuntos; los estados regresan al dispositivo.
8. Vencimiento limita solo nuevas capturas y nunca oculta datos existentes.

## Decisiones pendientes

Ver `../product/open-decisions.md`: pago/tiendas,
precio/vencimiento/reembolso, Voice Note, edición post-guardado, export,
límites PDF, correo, Teams, mockups, base cloud y retención.
