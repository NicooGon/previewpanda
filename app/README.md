# PreviewPanda API

Backend mínimo para demostrar los entornos efímeros de PreviewPanda. Se ejecuta localmente como Express y en AWS Lambda mediante una imagen de contenedor y una Function URL. No tiene base de datos ni autenticación: el objetivo del proyecto es la infraestructura y el ciclo de vida de cada Pull Request.

## Ejecutar localmente

```bash
npm install
npm start
```

La API queda disponible en `http://localhost:8080` y Swagger en `http://localhost:8080/api-docs`.

En AWS, la imagen declara `lambda.handler` mediante `CMD ["lambda.handler"]` en el Dockerfile. Terraform debe crear la Lambda desde la imagen ECR y publicar la Function URL; no es necesario que el workflow configure el handler.

## Rutas

| Ruta | Resultado |
| --- | --- |
| `GET /` | Nombre de la app, PR y commit desplegados. |
| `GET /health` | Responde `ok` con estado 200. |
| `GET /error` | Registra `preview_test_error` y devuelve un error controlado con estado 500. |
| `GET /api-docs` | Interfaz Swagger para probar las rutas. |

## Variables de entorno

- `PORT`: puerto del servidor local; Lambda no necesita abrir un puerto porque invoca `lambda.handler`. Por defecto se usa `8080` para desarrollo local.
- `PR_NUMBER`: número del Pull Request a mostrar.
- `COMMIT_SHA`: commit desplegado a mostrar.
