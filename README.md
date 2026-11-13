# PreviewPanda

Entornos efímeros de prueba por Pull Request usando GitHub Actions, Terraform y AWS.

## Estructura

- `app/`: API mínima Node.js, imagen Docker y Swagger.
- `infra/`: infraestructura Terraform para ECR, Lambda, Function URL, state y logs.
- `docs/environments.csv`: registro de los eventos de creación y destrucción de entornos.

El despliegue utiliza AWS Lambda con imagen de contenedor y Function URL, un
registro ECR y un bucket S3 para el state remoto.

## Flujo de un Pull Request

1. GitHub Actions se autentica en AWS mediante OIDC.
2. Se construye la imagen de `app/` y se publica en ECR con un tag del PR y
   commit.
3. Terraform usa un state independiente bajo `previews/pr-<n>/`.
4. Se crea la Lambda `pp-pr-<n>` con su Function URL.
5. El workflow comenta o actualiza la URL en el Pull Request.
6. Al cerrar o mergear el PR, se destruyen los recursos, el state y las
   imágenes del entorno.

## Calidad y observabilidad

El workflow `Terraform Quality` ejecuta `fmt`, `validate`, TFLint y Checkov.
Las excepciones de Checkov están justificadas más abajo porque la demo necesita
una Function URL pública y una retención de logs de 7 días.

En CloudWatch se utiliza un dashboard por entorno de demostración con las
métricas de Lambda y una métrica personalizada `PreviewTestErrors`. Esta última
se obtiene del registro `preview_test_error` que produce `GET /error`. El
dashboard y la alarma están verificados manualmente en AWS para la demo; si la
evaluación exige que también sean recursos IaC, deben declararse además con
Terraform en `infra/`.

El procedimiento de costos y las evidencias esperadas están en
[docs/finops.md](docs/finops.md), y el informe general está en
[docs/informe.md](docs/informe.md).

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
