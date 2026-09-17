# ADR-005 — S3 privado y transferencia directa de medios

- Estado: Aceptado
- Fecha: 2026-09-11
- Alcance: FL-016 Lead media; FL-018 Content/PDF Foloo V1
- Trazas: `CAP-08`, `CAP-09`, `VOZ-04`, `VOZ-05`, `SYN-04`–`SYN-10`,
  `INF-02`, `INF-10`, `RNF-05`, `RNF-07`, `RC-02`, `RC-03`, E-09/E-12/E-13

## Contexto

Tarjetas, imágenes de referencia y notas de voz ya son archivos privados
durables del dispositivo y operaciones hijas de un Lead en la outbox FL-015.
Enviar esos binarios por API Gateway/Lambda o guardarlos en PostgreSQL aumenta
costo, memoria y superficie de fallo. La app tampoco puede recibir credenciales
AWS permanentes. D-13 mantiene abierta la política legal de retención/borrado.

## Decisión

- CDK crea un bucket S3 administrado por CloudFormation, privado, con Block
  Public Access, cifrado S3-managed, TLS obligatorio, sin website, versioning ni
  lifecycle. `RETAIN` evita pérdida accidental al eliminar el stack.
- Flutter solicita a la API una autorización PUT de 10 minutos para un solo
  objeto. La key la construye backend desde el workspace resuelto por JWT, el
  Lead y el UUID del medio; el cliente nunca elige owner/key.
- Flutter hace PUT directo y luego confirma por el endpoint idempotente de
  media. Lambda ejecuta HEAD y una lectura acotada para comprobar existencia,
  tamaño, MIME, metadata firmada y firma JPEG/M4A antes de marcar `available`.
- GET de metadata emite GET firmado de 5 minutos solo para objetos disponibles.
  La app puede recuperar una copia a su storage privado en otro dispositivo.
- La identidad lógica, object key e idempotency key permanecen estables. Cada
  retry solicita una URL nueva y nunca borra automáticamente la copia local.
- Lambda usa únicamente `s3:GetObject`/`s3:PutObject` sobre objetos del bucket.
  Un endpoint Gateway S3 mantiene el acceso desde subredes aisladas sin NAT.
- Se aceptan solo los formatos que produce hoy la app: JPEG para tarjeta/
  referencia y M4A para voz. 25 MiB por imagen y 100 MiB por audio son techos
  técnicos antiabuso, no límites UX ni resolución de D-05.

## Consecuencias

La outbox existente sigue siendo la única coordinación y respeta
Evento → Lead → Media. PostgreSQL agrega estado/timestamp pero no binarios ni
URLs temporales. Una falla S3 deja el medio retryable y no degrada un Lead ya
sincronizado. No se adelanta PDF/FL-018, CDN, thumbnails, IA o transcripción.

Retención, borrado legal y limpieza física remota permanecen en D-13;
por ello no se configura lifecycle ni eliminación automática en FL-016.

## Extensión FL-018 — PDF

`CON-05`, `CON-09`, `CON-10` y E-07 reutilizan la transferencia directa: un
Content owner-scoped se crea en PostgreSQL, solicita PUT temporal para su key
determinística, confirma tamaño/MIME/metadata/firma `%PDF-` y publica GET
temporal para otro dispositivo. El límite por PDF es 25 000 000 bytes. La copia
privada local permanece después del upload y no se desaloja automáticamente.
La firma es una comprobación básica de formato, no un análisis antimalware;
FL-018 no añade un escáner ni presenta los PDF como libres de malware.
El borrado de Content es un tombstone sincronizado; no invoca `DeleteObject` ni
borra Events, Leads o sus medios. D-13 sigue decidiendo retención y limpieza
física remota, sin plazo implícito en FL-018.
