# Autenticación y ownership local

FL-013A creó la frontera y ownership; FL-013B conectó Cognito DEV. Ambos avances
se conservan para Foloo V1 unificado.

```text
UI → AuthRepository → AuthService
                       ├─ CognitoAuthService (runtime normal)
                       └─ DevelopmentAuthService (tests/desarrollo controlado)
```

## Cognito DEV

- Región: `us-east-1`
- User Pool: `us-east-1_QVm3dWe4O`
- App Client público: `6jong3atp2crqcsde6g215ant8`, sin Client Secret
- Sign-in y self sign-up: email + password
- Confirmación: código por email
- MFA usuario/passwordless/social: deshabilitados
- Account recovery: habilitado en proveedor; UI diferida

Amplify conserva tokens en almacenamiento seguro; Drift nunca los guarda.
AWS exceptions se traducen a fallos de dominio ES/EN.

## Separación identidad/perfil

`AuthUser.id` es Cognito `sub`. Email es login/display, no primary key.
Nombre, puesto, empresa, teléfono y foto son perfil Foloo. El perfil y todas
las entidades del producto se consultan por `sub`.

El esquema Drift v2 conserva ownership nullable. Filas v1 sin owner y
`fake-user-*` permanecen intactas e invisibles para otros usuarios hasta que
exista una migración aprobada.

## Sesión y conectividad

AuthState incluye initializing/authenticated/unauthenticated/error.
ConnectivityState es independiente: perder red no ejecuta logout. Logout real
cierra Cognito y limpia sesión sensible, pero no borra perfil, eventos, Leads o
medios.

Cognito no decide trial, suscripción o capacidades. Esa autoridad pertenece al
backend Foloo futuro (`MON-*`).
