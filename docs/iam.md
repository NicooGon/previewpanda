# Matriz IAM - PreviewPanda

Identidades y permisos usados por el proyecto, con su justificacion. Principio de minimo privilegio

## Identidades

| Identidad | Tipo | Permiso | Recurso | Justificacion |
|---|---|---|---|---|
| `previewpanda-ci` | Rol de IAM (OIDC desde GitHub Actions) | `previewpanda-ci-minimal` (ver [previewpanda-ci-policy.json](previewpanda-ci-policy.json)) | Bucket del state; roles, funciones y grupos de logs con nombre `pp-*`; repositorio ECR `previewpanda` | No puede tocar nada fuera de los recursos `pp-*` y el repositorio `previewpanda`. |
| `pp-<env_name>-lambda-exec` | Rol de IAM (asumido por el servicio Lambda) | `AWSLambdaBasicExecutionRole` (politica administrada de AWS) | Su propio grupo de logs en CloudWatch (`/aws/lambda/pp-<env_name>`) | La funcion solo necesita poder escribir sus logs de ejecucion.  |
| `nicolas`, `felipe`, `agustin` | Usuarios de IAM (miembros del equipo) | `AdministratorAccess` | Toda la cuenta | Cuenta de aprendizaje/laboratorio compartida para el equipo. |

