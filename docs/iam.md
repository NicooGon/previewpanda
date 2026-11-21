# Matriz IAM - PreviewPanda

Identidades y permisos usados por el proyecto, con su justificacion. Principio de minimo privilegio

## Identidades

| Identidad | Tipo | Permiso | Recurso | Justificacion |
|---|---|---|---|---|
| `previewpanda-ci` | Rol de IAM (OIDC desde GitHub Actions) | `previewpanda-ci-minimal` (ver [previewpanda-ci-policy.json](previewpanda-ci-policy.json)) | Bucket del state; roles, funciones y grupos de logs con nombre `pp-*`; repositorio ECR `previewpanda` | No puede tocar nada fuera de los recursos `pp-*` y el repositorio `previewpanda`. |
| `pp-<env_name>-lambda-exec` | Rol de IAM (asumido por el servicio Lambda) | `AWSLambdaBasicExecutionRole` (politica administrada de AWS) | Su propio grupo de logs en CloudWatch (`/aws/lambda/pp-<env_name>`) | La funcion solo necesita poder escribir sus logs de ejecucion.  |
| `nicolas`, `felipe`, `agustin` | Usuarios de IAM (miembros del equipo) | `AdministratorAccess` | Toda la cuenta | Cuenta de aprendizaje/laboratorio compartida para el equipo. |

## Riesgos aceptados

### `public_invoke_access` sin restringir a la Function URL

El permiso `aws_lambda_permission.public_invoke_access` (`infra/preview/main.tf`) le da `lambda:InvokeFunction` a `principal = "*"`, sin condicion que lo limite a que la invocacion venga de la Function URL. En la practica esto significa que alguien con credenciales validas de AWS y el ARN de la funcion podria invocarla directo, sin pasar por la URL publica.

La forma correcta de cerrarlo es agregar la condicion `lambda:InvokedViaFunctionUrl`, que en Terraform es el argumento `invoked_via_function_url` de `aws_lambda_permission`. Lo verificamos: ese argumento no existe en la version `~> 5.0` que tenemos fijada (confirmado contra el provider 5.100.0), se agrego en una version posterior. Actualizar el provider justo antes de la defensa nos parecio mas riesgoso que dejarlo documentado como pendiente.

**Correccion pendiente:** subir el provider de AWS, agregar `invoked_via_function_url = true` a `public_invoke_access` en `infra/preview/main.tf`, y confirmar con `terraform plan` que el bump de version no rompe nada mas.

