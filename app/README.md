# PreviewPanda API

Backend mínimo para demostrar los entornos efímeros de PreviewPanda. No tiene base de datos ni autenticación: el objetivo del proyecto es la infraestructura y el ciclo de vida de cada Pull Request.

## Ejecutar localmente

```bash
npm install
npm start
```

La API queda disponible en `http://localhost:8080` y Swagger en `http://localhost:8080/api-docs`.

## Rutas

| Ruta | Resultado |
| --- | --- |
| `GET /` | Nombre de la app, PR y commit desplegados. |
| `GET /health` | Responde `ok` con estado 200. |
| `GET /error` | Genera un error controlado con estado 500. |
| `GET /api-docs` | Interfaz Swagger para probar las rutas. |

## Variables de entorno

- `PORT`: puerto del servidor; Cloud Run lo proporciona automáticamente.
- `PR_NUMBER`: número del Pull Request a mostrar.
- `COMMIT_SHA`: commit desplegado a mostrar.
