# ADR-006 — Follow-up desde la cuenta autorizada del vendedor

- Estado: Aceptado; ampliado por las decisiones de producto `D-14`–`D-20`
  resueltas el 2026-09-18 y por el diseño técnico de ADR-007.
- Fecha: 2026-09-18.
- Alcance: FL-019; `SAL-04`, `SAL-06`, `SAL-08`, E-08.

## Contexto

`D-09` enfrentaba una propuesta anterior de SES con una exigencia posterior de
Google Workspace. Producto aprobó que el follow-up se perciba como continuación
de la conversación del vendedor y salga de su cuenta autorizada, tanto si es
Google como Microsoft. Cognito identifica a la persona en Foloo, pero su email
no demuestra control del buzón externo.

## Decisión

- V1 admite Gmail y Google Workspace con OAuth 2.0 + Gmail API, y Outlook y
  Microsoft 365 con OAuth 2.0 + Microsoft Graph.
- La lógica de follow-up depende de una frontera de proveedor, no de SDKs de
  Google/Microsoft en widgets ni de un `From` suministrado por Flutter.
- Backend vincula la identidad externa autorizada al Cognito `sub`/workspace y
  deriva de ella el remitente efectivo.
- La cuenta Cognito/Foloo y la cuenta externa de envío son identidades distintas
  que pueden usar direcciones diferentes. Después del perfil, Foloo ofrece la
  conexión como onboarding opcional; “Configurar después” no limita captura y
  no equivale a tener OAuth conectado.
- Backend es la autoridad del estado de conexión. Flutter refresca al abrir
  Correo y al volver del navegador y solo recibe provider, dirección enmascarada
  y estado; tocar Google/Microsoft nunca produce por sí mismo `connected`.
- No se emplean SMTP manual, passwords de correo, SES ni una cuenta general
  Foloo para estos follow-ups.
- Tokens y secretos del proveedor permanecen fuera de Flutter, Drift,
  SharedPreferences y Git. ADR-007 gobierna su almacenamiento y el egreso.
- Guardar un Lead continúa siendo local-first aunque OAuth o envío no estén
  disponibles. La intención de correo aprovechará la outbox FL-015 y la
  asociación histórica de Content FL-018 cuando el contrato restante se cierre.

## Consecuencias y límites

- La elección reemplaza la interpretación de Google Workspace como único
  proveedor para follow-ups; cada identidad autorizada debe autenticarse con
  los mecanismos de correo aplicables a su propio dominio/proveedor.
- OAuth de Google/Microsoft es una conexión de correo adicional, no sustituye
  Cognito como identidad Foloo ni introduce Social Login.
- Usuarios con perfil anterior a este paso conservan acceso sin repetir
  onboarding. La marca local owner-scoped registra solo visto/omitido; no es un
  cache autoritativo de OAuth.
- Aceptación por Gmail API o Microsoft Graph no prueba entrega al destinatario
  ni garantiza exactamente una vez tras un timeout ambiguo. `D-18` exige
  Estado por confirmar y prohíbe retry automático en ese caso.
- `D-14`–`D-20` quedaron resueltas por Producto en `PLT-*`, `SAL-*` y E-08;
  esta ADR sigue delimitando proveedor/identidad, no duplica el texto del
  mensaje ni su lifecycle.
- El backend principal corre en subredes aisladas sin NAT. ADR-007 resolvió el
  egreso mediante una frontera Lambda sin VPC, sin acceso a PostgreSQL.

## Alternativas no elegidas para el follow-up V1

- SES o un remitente general Foloo: no representan la cuenta autorizada del
  vendedor aprobada por Producto.
- SMTP manual/passwords: mayor superficie de credenciales y expresamente
  excluidos.
