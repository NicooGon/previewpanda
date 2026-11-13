# PreviewPanda

Entornos efímeros de prueba por Pull Request usando GitHub Actions, Terraform y AWS.

## Estructura

- `app/`: API mínima Node.js, imagen Docker y Swagger.
- `infra/`: infraestructura Terraform (pendiente de incorporar).
- `docs/environments.csv`: registro de los eventos de creación y destrucción de entornos.

El despliegue utiliza AWS Lambda con imagen de contenedor y Function URL, un
registro ECR y un bucket S3 para el state remoto.

## Excepciones justificadas de Checkov

El workflow de calidad mantiene Checkov activo, pero excluye algunas reglas
porque no corresponden al alcance definido en el artifact del proyecto:

- `CKV_AWS_258` y `CKV_AWS_301`: la Function URL debe ser pública para que la
  demo pueda acceder al entorno temporal desde el Pull Request.
- `CKV_AWS_338`: el proyecto exige una retención de logs de 7 días, no de un
  año.
- `CKV_AWS_158`, `CKV_AWS_50`, `CKV_AWS_117`, `CKV_AWS_115`, `CKV_AWS_116` y
  `CKV_AWS_272`: KMS, X-Ray, VPC, límite de concurrencia, DLQ y firma de
  código no forman parte de los requisitos obligatorios de este alcance.

Estas excepciones no desactivan Checkov: solamente documentan controles que
deliberadamente no se implementan por decisión de arquitectura y alcance.

## Aplicación

Las instrucciones de ejecución y las rutas están en [app/README.md](app/README.md). 

