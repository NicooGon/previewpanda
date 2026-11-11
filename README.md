# PreviewPanda

Entornos efímeros de prueba por Pull Request usando GitHub Actions, Terraform y AWS.

## Estructura

- `app/`: API mínima Node.js, imagen Docker y Swagger.
- `infra/`: infraestructura Terraform (pendiente de incorporar).
- `docs/environments.csv`: registro de los eventos de creación y destrucción de entornos.

El despliegue utiliza un servicio de contenedores de AWS, un registro ECR y un bucket S3 para el state remoto. El servicio concreto de ejecución se definirá en `infra/`.

## Aplicación

Las instrucciones de ejecución y las rutas están en [app/README.md](app/README.md).
