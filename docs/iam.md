# Matriz IAM - PreviewPanda

Identidades y permisos usados por el proyecto, con su justificacion. Principio de minimo privilegio

## Identidades

| Identidad | Tipo | Permiso | Recurso | Justificacion |
|---|---|---|---|---|
| `previewpanda-ci` | Rol de IAM (OIDC desde GitHub Actions) | `AdministratorAccess` (**provisorio**) | Toda la cuenta | Creado para destrabar al equipo mientras se escribe el modulo de Terraform.  |
| `pp-<env_name>-lambda-exec` | Rol de IAM (asumido por el servicio Lambda) | `AWSLambdaBasicExecutionRole` (politica administrada de AWS) | Su propio grupo de logs en CloudWatch (`/aws/lambda/pp-<env_name>`) | La funcion solo necesita poder escribir sus logs de ejecucion.  |
| `nicolas`, `felipe`, `agustin` | Usuarios de IAM (miembros del equipo) | `AdministratorAccess` | Toda la cuenta | Cuenta de aprendizaje/laboratorio compartida para el equipo. |

