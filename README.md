# PreviewPanda

Entornos efímeros de prueba por Pull Request usando GitHub Actions, Terraform y Google Cloud Run.

## Estructura

- `app/`: API mínima Node.js, imagen Docker y Swagger.
- `infra/`: infraestructura Terraform (pendiente de incorporar).
- `docs/environments.csv`: registro de los eventos de creación y destrucción de entornos.

## Aplicación

Las instrucciones de ejecución y las rutas están en [app/README.md](app/README.md).
