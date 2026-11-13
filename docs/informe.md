# PreviewPanda

## Informe de proyecto

**Proyecto:** PreviewPanda – entornos efímeros por Pull Request  
**Proveedor:** Amazon Web Services (AWS)  
**Repositorio:** `previewpanda`  
**Rama de desarrollo de la aplicación:** `feature/app`  
**Equipo:** `Nicolás González, Felipe Corderi, Agustín García`
**Estado del informe:** borrador en construcción

> Este documento se irá completando durante la integración de infraestructura y CI/CD. Los elementos marcados como **Pendiente** todavía no fueron verificados en AWS.

## 1. Resumen

PreviewPanda crea un entorno de prueba aislado para cada Pull Request. Al abrir o actualizar un PR, GitHub Actions construye la aplicación, publica una imagen en Amazon ECR y ejecuta Terraform para crear una función AWS Lambda con una Function URL pública. La URL se publica como comentario en el PR.

Cuando el PR se cierra o se mergea, otro workflow ejecuta `terraform destroy` sobre el state correspondiente y elimina los recursos temporales. Un proceso nocturno detecta previews huérfanos y elimina aquellos que superen el tiempo definido por el equipo.

El objetivo principal no es desarrollar una aplicación compleja, sino demostrar el ciclo de vida completo de infraestructura temporal: creación, aislamiento, observación, registro de costos y destrucción.

## 2. Requisitos verificables

| # | Requisito | Evidencia esperada | Estado |
|---:|---|---|---|
| 1 | Cada PR tiene su propio entorno y URL | Lambda `pp-pr-<n>` con Function URL propia | Verificado en PR de demostración |
| 2 | El entorno se destruye al cerrar o mergear | `terraform destroy` y limpieza de recursos | Verificado en PR de demostración |
| 3 | Módulo Terraform reutilizable | Variable `env_name` | Implementado |
| 4 | Un state por entorno | S3 key `previews/pr-<n>/terraform.tfstate` | Implementado |
| 5 | Etiqueta `pr=<n>` | Tags en los recursos creados | Implementado |
| 6 | Limpieza nocturna de huérfanos | Workflow que destruye previews con más de 3 días | Pendiente de workflow |
| 7 | Política de concurrencia | Grupo `preview-pr-<n>` probado con pushes sucesivos | Implementado y probado |
| 8 | Registro y costo por entorno | `docs/environments.csv` actualizado por workflows | Plantilla creada |

## 3. Alcance de la aplicación

La aplicación es una API Node.js con Express. Se ejecuta localmente como servidor HTTP y en AWS Lambda mediante una imagen de contenedor.

La misma imagen puede ser utilizada por cada preview. Los valores del Pull Request y del commit se reciben mediante variables de entorno:

- `PR_NUMBER`: número del Pull Request.
- `COMMIT_SHA`: commit de la imagen desplegada.

### Endpoints

| Endpoint | Propósito |
|---|---|
| `GET /` | Devuelve nombre de la aplicación, PR, commit y ruta de Swagger. |
| `GET /health` | Responde `200 ok` para health checks y smoke tests. |
| `GET /error` | Devuelve un `500` controlado para probar logs y alarmas. |
| `GET /api-docs` | Expone la documentación interactiva Swagger. |

La aplicación no incorpora base de datos, autenticación ni lógica de negocio adicional, porque el foco del proyecto es la infraestructura efímera y su automatización.

## 3.1 Pruebas de la aplicación

Las mismas rutas se prueban primero localmente y luego sobre la Function URL creada para el PR.

### `GET /`

Verifica la identidad del entorno desplegado.

```text
GET /
```

Respuesta esperada:

```json
{
  "app": "PreviewPanda",
  "pr": "12",
  "commit": "abc123d",
  "docs": "/api-docs"
}
```

El valor de `pr` debe coincidir con el Pull Request probado y `commit` debe identificar el commit usado para construir la imagen. En local, si no se configuran variables, se muestran los valores `NOT_CONFIGURED`.

### `GET /health`

Verifica que la Lambda y la aplicación respondan correctamente.

```text
GET /health
```

Resultado esperado:

```text
HTTP 200
ok
```

Esta ruta se utiliza como smoke test y como health check de la función.

### `GET /error`

Genera un error controlado para probar observabilidad.

```text
GET /error
```

Resultado esperado:

```json
HTTP 500
{
  "message": "Error de prueba"
}
```

El error es intencional. En AWS aparece en los logs de CloudWatch con la marca
`preview_test_error`. La alarma de la demo utiliza un filtro de métrica sobre
esa marca, porque un `HTTP 500` controlado no necesariamente incrementa la
métrica nativa `AWS/Lambda Errors`.

### `GET /api-docs`

Abre la interfaz Swagger de la API.

```text
GET /api-docs
```

Desde Swagger se pueden ejecutar `/`, `/health` y `/error` sobre el entorno local o sobre la Function URL del PR.

## 4. Arquitectura AWS

La arquitectura definida utiliza:

- **AWS Lambda con imagen de contenedor:** una función por Pull Request.
- **Lambda Function URL:** URL pública propia para cada preview.
- **Amazon ECR:** repositorio compartido para las imágenes Docker.
- **Amazon S3:** state remoto de Terraform.
- **GitHub Actions:** build, publicación de imagen, Terraform y comentarios en PR.
- **GitHub Actions OIDC + IAM:** autenticación sin claves estáticas.
- **Amazon CloudWatch:** logs, dashboard y alarma.

### Valores confirmados

| Dato | Valor |
|---|---|
| Región | `us-east-1` |
| Cuenta AWS | `891762599659` |
| Bucket de state | `previewpanda-tfstate-nico2026` |
| Key del state | `previews/pr-<n>/terraform.tfstate` |
| Etiquetas | `project=previewpanda`, `team=previewpanda`, `env=preview`, `owner=nicolas`, `pr=<n>` |
| Lock del state | `use_lockfile = true` |
| Rol de CI | `previewpanda-ci` |

El repositorio ECR, el bucket S3, el proveedor OIDC, el rol de CI, el presupuesto, el dashboard y la alarma son recursos compartidos. La Lambda, su Function URL, el rol de ejecución, el log group, el state y la imagen etiquetada se consideran recursos asociados a un PR.

## 5. Flujo de creación y destrucción

### Creación o actualización de un PR

1. Un desarrollador abre o actualiza un Pull Request.
2. GitHub Actions obtiene credenciales temporales mediante OIDC.
3. Se construye la imagen Docker de `app/`.
4. La imagen se publica en ECR con un tag como `pr-12-<sha>`.
5. Terraform inicializa el backend con el state del PR.
6. Terraform crea o actualiza la Lambda `pp-pr-<n>`.
7. Se crea la Function URL.
8. El workflow publica o actualiza un comentario con la URL.
9. Se registra el evento en `docs/environments.csv`.

El orden build → push → apply es obligatorio, porque Lambda necesita que la imagen exista en ECR antes de crear o actualizar la función.

### Cierre o merge del PR

1. GitHub Actions detecta el cierre o merge.
2. Se recupera el mismo state `previews/pr-<n>/terraform.tfstate`.
3. Se ejecuta `terraform destroy`.
4. Se elimina la Lambda y los recursos asociados.
5. Se elimina explícitamente el objeto de state de S3.
6. Se limpia la imagen del PR en ECR.
7. Se registra la destrucción y el costo estimado.

## 6. Concurrencia y aislamiento

Cada PR utiliza un state diferente y un grupo de concurrencia propio:

```text
preview-pr-<n>
```

Esto evita que dos ejecuciones del mismo PR modifiquen simultáneamente el mismo state. Los PR diferentes pueden ejecutarse de forma independiente.

La política deberá probarse con dos pushes sucesivos sobre un mismo PR y con dos PR abiertos al mismo tiempo.

## 7. Observabilidad

La aplicación dispone de `/error` para provocar una respuesta HTTP 500 controlada. La prueba prevista es:

1. Invocar `GET /error` en la Function URL.
2. Verificar el registro del error en CloudWatch Logs.
3. Comprobar que la métrica configurada para el error de prueba aumenta.
4. Verificar la alarma de CloudWatch.

El dashboard y la alarma se crearon en CloudWatch para el PR de demostración.
La alarma usa la métrica personalizada `PreviewTestErrors`, que se incrementa
al invocar `/error`. La retención del log group es de 7 días.

En la ejecución de demostración del PR #24 se utilizó la imagen
`pr-24-626cda2`.

Esta configuración manual está verificada en AWS y sirve para la demostración.
Por indicación del docente, el dashboard y la alarma se configuraron
directamente desde la consola de AWS. La evidencia debe mostrar el dashboard,
la alarma en estado de alarma después de invocar `/error` y la retención de
logs de 7 días.

Los log groups temporales deberán conservarse durante 7 días.

## 8. Seguridad e IAM

GitHub Actions se autenticará en AWS mediante OIDC. No se deben guardar access keys ni secret keys de AWS en GitHub.

El rol `previewpanda-ci` existe actualmente, pero sus permisos todavía deben reducirse desde administración amplia a permisos mínimos antes de la fecha definida por el equipo.

La matriz IAM definitiva deberá documentar:

- Identidad.
- Permiso.
- Recurso.
- Motivo del permiso.
- Evidencia de que no se concedieron permisos innecesarios.

## 9. FinOps

La estimación inicial del proyecto es de aproximadamente **USD 0–2 por mes**, siempre que los previews se destruyan correctamente y no se mantengan recursos costosos encendidos. El detalle de supuestos y evidencias está en [docs/finops.md](finops.md).

Las medidas principales de ahorro son:

- Lambda bajo demanda.
- Una sola región: `us-east-1`.
- Imágenes pequeñas en ECR.
- Limpieza de imágenes asociadas a PRs cerrados.
- Destrucción automática del entorno.
- Limpieza nocturna de huérfanos.
- Retención de logs limitada a 7 días.

Cost Explorer mostró un costo observado de USD 0,00 para la ventana
12/11/2026–13/11/2026 en los servicios consultados. Ese dato corresponde a la
cuenta y no permite atribuir un importe exacto al PR #24. Además, está activo
el presupuesto mensual `previewpanda-presupuesto` por USD 10,00, con tres
destinatarios verificados y tres alertas asociadas por destinatario. La pestaña
de alertas confirma los umbrales 50 % (USD 5,00), 80 % (USD 8,00) y
100 % (USD 10,00), todos sin superar. La proyección productiva se mantiene
como estimación del alcance.

## 10. Registro de entornos

El archivo [environments.csv](environments.csv) contiene la plantilla con estos campos:

```text
pr_number,environment,event,occurred_at,image_tag,url,lifetime_hours,estimated_cost_usd,notes
```

Los workflows todavía conservan el punto de integración para agregar una fila al
crear y otra al destruir cada entorno. El archivo no debe rellenarse con URL o
costos inventados: las filas finales deben salir de ejecuciones reales.

## 11. Diagramas

El informe utilizará dos diagramas:

1. **Diagrama de secuencia:** muestra apertura/actualización/cierre del PR y la interacción entre GitHub, Actions, ECR, Terraform, Lambda y S3.
2. **Diagrama de despliegue:** muestra los límites entre GitHub, AWS, ECR, S3, Lambda, Function URL y CloudWatch.

Los archivos PlantUML son [secuencia.puml](secuencia.puml),
[secuencia-quality.puml](secuencia-quality.puml) y
[despliegue.puml](despliegue.puml).

## 12. Estado actual y trabajo pendiente

### Completado en la aplicación

- API Express funcional.
- Swagger funcional.
- Handler compatible con Lambda.
- Dockerfile basado en la imagen oficial AWS Lambda Node.js 22.
- Imagen local construida correctamente.
- Prueba del handler `/health` dentro de la imagen.

### Pendiente de integración (WIP)

- Automatización final del CSV en los workflows.
- Job nocturno de huérfanos.
- Evidencias finales de la demo.
- Archivos PlantUML de los diagramas de secuencia y despliegue.

## 13. Evidencias para la entrega (TO-DO)

La demostración final deberá conservar evidencia de:

- PR abierto con comentario de Function URL.
- API accesible mediante la URL.
- Swagger accesible.
- Ejecución de `/health`.
- Error controlado y alarma 5xx.
- PR cerrado o mergeado.
- Recursos destruidos.
- State eliminado.
- Registro actualizado en `environments.csv`.
- Ausencia de recursos y costos sobrantes.

## 14. Conclusión

PreviewPanda implementa un patrón de entornos efímeros orientado a Pull Requests. La aplicación es pequeña a propósito: permite concentrar la evaluación en Terraform, aislamiento de states, CI/CD, autenticación federada, observabilidad y control de costos.

La aplicación, la imagen, la infraestructura principal y los workflows de
preview ya están integrados. El trabajo restante se concentra en cerrar el
registro de entornos, el job nocturno, los diagramas, las evidencias y la
documentación final.
