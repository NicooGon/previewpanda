# PreviewPanda

## Informe de proyecto

**Proyecto:** PreviewPanda – entornos efímeros por Pull Request  
**Proveedor:** Amazon Web Services (AWS)  
**Repositorio:** `previewpanda`  
**Rama de desarrollo de la aplicación:** `feature/app`  
**Equipo:** `Nicolás González, Felipe Corderi, Agustín García`

## 1. Resumen

PreviewPanda crea un entorno de prueba aislado para cada Pull Request. Al abrir, actualizar o reabrir un PR, GitHub Actions prepara la imagen en Amazon ECR y ejecuta Terraform para desplegar la API en AWS Lambda. El comentario del PR incluye la Function URL y el plan de Terraform.

Cuando el PR se cierra o se mergea, otro workflow ejecuta `terraform destroy` sobre su state y elimina los recursos temporales. Una limpieza nocturna revisa los entornos huérfanos que quedan en S3.

Así, quien revisa el PR puede probar ese commit desde el navegador antes de mergearlo. Una vez cerrado el PR, el entorno deja de estar disponible y queda un registro de su duración y costo estimado.

## 2. Requisitos verificables

| # | Requisito | Implementación en PreviewPanda |
|---:|---|---|
| 1 | Cada PR tiene su propio entorno y URL | Lambda `pp-pr-<n>` con Function URL propia. |
| 2 | El entorno se destruye al cerrar o mergear | `terraform destroy` y limpieza de los recursos temporales asociados al PR. |
| 3 | Módulo Terraform reutilizable | Variable `env_name` para generar los nombres del entorno. |
| 4 | Un state por entorno | Key de S3 con el formato `previews/pr-<n>/terraform.tfstate`. |
| 5 | Etiqueta `pr=<n>` | Tags comunes aplicados a los recursos creados. |
| 6 | Limpieza nocturna de huérfanos | `nightly-cleanup.yml` ejecuta `scripts/cleanup_orphans.py` todos los días a las 03:00 de Uruguay. |
| 7 | Política de concurrencia | Grupo `preview-pr-<n>` para serializar las ejecuciones del mismo PR. |
| 8 | Registro y costo por entorno | Los workflows escriben en el CSV de la rama `registro/environments`. El PR #26 muestra los tres eventos del ciclo. |

## 3. Alcance de la aplicación

La aplicación es una API Node.js con Express. Se ejecuta localmente como servidor HTTP y en AWS Lambda mediante una imagen de contenedor.

Cada preview usa una imagen identificada por el número de PR y el commit. Terraform configura estas variables en Lambda:

- `PR_NUMBER`: número del Pull Request.
- `COMMIT_SHA`: commit de la imagen desplegada.

### Endpoints

| Endpoint | Propósito |
|---|---|
| `GET /` | Devuelve nombre de la aplicación, PR, commit y ruta de Swagger. |
| `GET /health` | Responde `200 ok` para health checks y smoke tests. |
| `GET /error` | Devuelve un `500` controlado para probar logs y alarmas. |
| `GET /api-docs` | Expone la documentación interactiva Swagger. |

### 3.1 Pruebas de la aplicación

Las mismas rutas se prueban primero localmente y luego sobre la Function URL creada para el PR.

#### `GET /`

Verifica la identidad del entorno desplegado.

```text
GET /
```

Ejemplo de respuesta:

```json
{
  "app": "PreviewPanda",
  "pr": "12",
  "commit": "abc123d",
  "docs": "/api-docs"
}
```

La respuesta refleja el Pull Request probado y el commit usado para construir la imagen. En local, si no se configuran variables, se muestran los valores `NOT_CONFIGURED`.

#### `GET /health`

Verifica que la Lambda y la aplicación respondan correctamente.

```text
GET /health
```

Resultado esperado:

```text
HTTP 200
ok
```

Esta ruta sirve para comprobar manualmente que el entorno responde después del despliegue.

#### `GET /error`

Genera un error controlado para probar observabilidad.

```text
GET /error
```

Resultado esperado:

```text
HTTP 500
{
  "message": "Error de prueba"
}
```

El error es intencional. En AWS aparece en los logs de CloudWatch con la marca
`preview_test_error`. La alarma de la demo utiliza un filtro de métrica sobre
esa marca, porque un `HTTP 500` controlado no necesariamente incrementa la
métrica nativa `AWS/Lambda Errors`.

#### `GET /api-docs`

Abre la interfaz Swagger de la API.

```text
GET /api-docs
```

Desde Swagger se pueden ejecutar `/`, `/health` y `/error` sobre el entorno local o sobre la Function URL del PR.

### 3.2 Terraform Quality

Cuando se abre, actualiza o reabre un PR, el workflow `Terraform Quality` revisa el formato, valida la configuración y ejecuta TFLint en `infra/preview`. Inicializa Terraform con `-backend=false`, por lo que estos controles se ejecutan sin credenciales de AWS ni acceso al state de S3. Checkov escanea `infra/` y sus hallazgos quedan en el log del job mediante `soft_fail: true`. El workflow Preview ejecuta el plan contra AWS y lo publica como parte del comentario del PR.

## 4. Arquitectura AWS

Elegimos Lambda porque la API recibe poco tráfico y se invoca bajo demanda. La Function URL le da al revisor acceso directo al preview sin agregar otro servicio para exponer la API.

- **AWS Lambda con imagen de contenedor:** una función por Pull Request.
- **Lambda Function URL:** URL pública propia para cada preview.
- **Amazon ECR:** repositorio compartido para las imágenes Docker.
- **Amazon S3:** state remoto de Terraform.
- **GitHub Actions:** build, publicación de imagen, Terraform y comentarios en PR.
- **GitHub Actions OIDC + IAM:** autenticación sin claves estáticas.
- **Amazon CloudWatch:** logs, dashboard y alarma.

### Valores

| Dato | Valor |
|---|---|
| Región | `us-east-1` |
| Cuenta AWS | `891762599659` |
| Bucket de state | `previewpanda-tfstate-nico2026` |
| Key del state | `previews/pr-<n>/terraform.tfstate` |
| Etiquetas | `project=previewpanda`, `team=previewpanda`, `env=preview`, `owner=nicolas`, `pr=<n>` |
| Lock del state | `use_lockfile = true` |
| Rol de CI | `previewpanda-ci` |

Los previews comparten el repositorio ECR, el bucket S3, el proveedor OIDC y el rol de CI. Cada PR tiene su Lambda, su Function URL pública, su rol de ejecución, su grupo de logs, su state y sus imágenes. El dashboard y la alarma del PR #24 se configuraron en la consola para la prueba de observabilidad.

## 5. Flujo de creación y destrucción

### Apertura, actualización o reapertura de un PR

1. Un desarrollador abre, actualiza o reabre un Pull Request.
2. GitHub Actions obtiene credenciales temporales mediante OIDC.
3. El workflow busca en ECR el tag `pr-<n>-<sha7>`.
4. Si el tag no existe, construye y publica la imagen de `app/`.
5. Terraform inicializa el backend con el state del PR.
6. Terraform genera el plan y lo guarda en `tfplan`.
7. El workflow aplica ese mismo plan y obtiene la Function URL de la Lambda `pp-pr-<n>`.
8. El workflow registra `created` o `updated` en el CSV de la rama `registro/environments`.
9. El workflow publica o actualiza el comentario del PR con la URL, el commit, el tag de la imagen y el detalle del plan. Si falla el despliegue, el comentario indica el fallo y enlaza a la ejecución.

La imagen tiene que estar en ECR antes de aplicar el plan. Si el tag ya existe, el workflow reutiliza esa imagen.

### Cierre o merge del PR

1. GitHub Actions detecta el cierre o merge.
2. El workflow llama a `scripts/destruir_entorno.sh`, que inicializa Terraform con el mismo state `previews/pr-<n>/terraform.tfstate`.
3. Se ejecuta `terraform destroy`.
4. Se elimina la Lambda y los recursos asociados.
5. El workflow elimina el objeto activo del state en S3.
6. El workflow elimina las imágenes etiquetadas para el PR en ECR.
7. El workflow registra la destrucción y la duración del entorno en la rama `registro/environments`. Con una tarifa configurada, también registra el costo estimado.
8. El workflow actualiza el comentario del PR con el resultado de la limpieza.

### Limpieza nocturna y destrucción manual

El workflow `nightly-cleanup.yml` revisa los states de S3 todos los días a las 06:00 UTC (03:00 de Uruguay). El script conserva los entornos con un PR abierto o cuyo estado no puede confirmar. Para los PR cerrados, mergeados o identificados como inexistentes, compara los días enteros desde la última modificación del state con `DIAS_LIMITE`, que vale 3 por defecto. Si supera ese límite, intenta destruir el entorno.

El workflow manual `destroy.yml` se ejecuta desde `main`. Por defecto lista todos los entornos de preview. Con el modo de listado desactivado y la confirmación `destroy`, llama al mismo script de destrucción que usa el workflow de cierre de PR.

## 6. Concurrencia y aislamiento

Cada PR utiliza un state diferente y un grupo de concurrencia propio:

```text
preview-pr-<n>
```

Esto evita que dos ejecuciones del mismo PR modifiquen simultáneamente el mismo state. Los PR diferentes pueden ejecutarse de forma independiente.

Preview y Destroy preview comparten ese grupo. El diagrama de concurrencia muestra el caso de dos pushes seguidos al mismo PR y cómo el segundo espera mientras corre el primero. La limpieza nocturna y el destroy manual usan grupos propios porque recorren varios entornos. El bloqueo de S3 también protege el state cuando dos operaciones de Terraform coinciden. Los casos de concurrencia están en [Concurrencia.md](Concurrencia.md).

## 7. Observabilidad

Configuramos el dashboard y la alarma desde la consola de AWS para el PR #24, con la imagen `pr-24-626cda2`. Para probar la alarma llamamos a `GET /error` desde la Function URL. La API responde con HTTP 500 y escribe `preview_test_error` en CloudWatch Logs. Un filtro cuenta esas entradas en la métrica personalizada `PreviewTestErrors`.

En la captura se ven cinco errores de prueba, la alarma `previewpanda-pr-24-error` activada y el panel con las métricas de Lambda `Duration`, `Errors`, `Invocations` y `Throttles`. Terraform configura la retención de los grupos de logs en siete días.

![Dashboard y alarma de CloudWatch](images/dashboard-alarma-aws.png)

## 8. Seguridad e IAM

GitHub Actions se autentica en AWS mediante OIDC. El repositorio no guarda access keys ni secret keys de AWS.

El rol `previewpanda-ci` utiliza la política mínima documentada en [docs/previewpanda-ci-policy.json](previewpanda-ci-policy.json).

La [matriz IAM](iam.md) detalla qué identidades usa el proyecto, qué recursos puede tocar cada una y para qué necesita esos permisos.

## 9. FinOps

La estimación inicial del proyecto es de aproximadamente **USD 0–2 por mes**, siempre que los previews se destruyan correctamente y no se mantengan recursos costosos encendidos. El detalle de supuestos y evidencias está en [docs/finops.md](finops.md).

Las medidas principales de ahorro son:

- Lambda bajo demanda.
- Una sola región: `us-east-1`.
- Limpieza de imágenes asociadas a PRs cerrados.
- Destrucción automática del entorno.
- Limpieza programada de entornos huérfanos.
- Retención de logs limitada a 7 días.

Cost Explorer mostró un costo observado de USD 0,00 para la ventana
12/11/2026–13/11/2026 en los servicios consultados. Ese dato corresponde a la
cuenta y no permite atribuir un importe exacto al PR #24. Además, está activo
el presupuesto mensual `previewpanda-presupuesto` por USD 10,00, con tres
destinatarios verificados y tres alertas asociadas por destinatario. La pestaña
de alertas confirma los umbrales 50 % (USD 5,00), 80 % (USD 8,00) y
100 % (USD 10,00), todos sin superar en la captura del presupuesto. El rango de USD 0–2 corresponde al alcance de la demo.

## 10. Registro de entornos

Los workflows de Preview y Destroy preview llaman a `scripts/registrar_entorno.sh` para agregar filas a [environments.csv](environments.csv). El historial se guarda en la rama `registro/environments`.

- El workflow de preview registra `created` al abrir o reabrir un PR y `updated`
  en cada push posterior. La fila incluye el tag de ECR, la Function URL, el
  commit y el enlace a la ejecución de GitHub Actions.
- El workflow de destroy registra `destroyed` después de completar la
  destrucción, borrar el state y eliminar las imágenes del PR. El script usa el último `created` para calcular la duración. Si falta esa fila, toma la fecha de apertura del PR. Con `PREVIEW_COST_USD_PER_HOUR` configurada multiplica las horas por la tarifa. Si falta la tarifa, deja el costo vacío.
- Si otro proceso actualiza la rama al mismo tiempo, el script reintenta el push. Los workflows permiten que el paso de registro falle sin cambiar el resultado del despliegue o la destrucción.

Las URL, las fechas y los tags se toman de ejecuciones reales; la columna
`estimated_cost_usd` representa una estimación basada en la duración del entorno.

### Ejemplo real: PR #26

El siguiente registro muestra la creación, actualización y destrucción del
entorno asociado al PR #26:

```csv
pr_number,environment,event,occurred_at,image_tag,url,lifetime_hours,estimated_cost_usd,notes
26,pr-26,created,2026-11-18T03:31:38Z,pr-26-2f13196,https://y2nwlmzzxkd27ewnbkjbs6ntnm0bngqj.lambda-url.us-east-1.on.aws/,,,commit=2f13196 run=https://github.com/NicooGon/previewpanda/actions/runs/44230884299
26,pr-26,updated,2026-11-18T03:34:42Z,pr-26-b176149,https://y2nwlmzzxkd27ewnbkjbs6ntnm0bngqj.lambda-url.us-east-1.on.aws/,,,commit=b176149 run=https://github.com/NicooGon/previewpanda/actions/runs/44231284597
26,pr-26,destroyed,2026-11-18T03:35:42Z,pr-26-b176149,,0.07,0.000007,mergeado run=https://github.com/NicooGon/previewpanda/actions/runs/44231473760
```

El entorno mantuvo la misma URL al pasar de la imagen `pr-26-2f13196` a `pr-26-b176149`. Tras el merge, el registro muestra una vida de 4 minutos y 4 segundos (`0.07` horas redondeadas) y un costo estimado de USD `0.000007`. Cada fila conserva el enlace a su ejecución de GitHub Actions en `notes`.

## 11. Diagramas

Los siete diagramas en PlantUML muestran desde la arquitectura en AWS hasta los pasos que ejecuta GitHub Actions, con un diagrama de secuencia propio para cada workflow.

### 11.1 Diagrama de despliegue AWS

Muestra qué queda en GitHub y qué se ejecuta en AWS, cómo el revisor llega a la API y cómo los logs del PR #24 alimentan la métrica y la alarma.

Archivo fuente: [diagrama-despliegue.puml](diagrams/diagrama-despliegue.puml).

![Diagrama 1 - Despliegue AWS](diagrams/diagrama1.png)

### 11.2 Diagrama de actividad de limpieza de huérfanos

Muestra las decisiones que toma el script cuando lo invoca el workflow nocturno. El criterio combina el estado del PR y los días enteros desde la última modificación del state.

Archivo fuente: [diagrama-estados-huerfanos.puml](diagrams/diagrama-estados-huerfanos.puml).

![Diagrama 2 - Limpieza de huérfanos](diagrams/diagrama2.png)

### 11.3 Diagrama de secuencia de concurrencia

Muestra cómo dos pushes sucesivos del mismo PR se serializan mediante el grupo
`preview-pr-<n>` para evitar que dos ejecuciones modifiquen el mismo state al
mismo tiempo.

Archivo fuente: [diagrama-secuencia-concurrencia.puml](diagrams/diagrama-secuencia-concurrencia.puml).

![Diagrama 3 - Concurrencia](diagrams/diagrama3.png)

### 11.4 Diagrama de secuencia del workflow Terraform Quality

Muestra cómo GitHub Actions prepara el runner, revisa Terraform y publica el resultado del job `quality`.

Archivo fuente: [diagrama-secuencia-quality.puml](diagrams/diagrama-secuencia-quality.puml).

![Diagrama 4 - Terraform Quality](diagrams/diagrama4.png)

### 11.5 Diagrama de secuencia de preview.yml (apply)

Sigue el workflow `preview.yml`: assume role por OIDC, build & push condicional de la imagen, `terraform apply`, registro en el CSV y comentario con la URL en el PR.

Archivo fuente: [diagrama-apply.puml](diagrams/diagrama-apply.puml).

![Diagrama 5 - Apply](diagrams/diagrama5.png)

### 11.6 Diagrama de secuencia de destroy-preview.yml (destroy)

Sigue el workflow `destroy-preview.yml` al cerrar o mergear el PR: `terraform destroy`, limpieza del state en S3, borrado de la imagen en ECR y registro de la destrucción en el CSV, incluyendo el caso en que Terraform falla.

Archivo fuente: [diagrama-destroy.puml](diagrams/diagrama-destroy.puml).

![Diagrama 6 - Destroy](diagrams/diagrama6.png)

### 11.7 Diagrama de secuencia de destroy.yml (destroy manual)

Sigue el workflow manual `destroy.yml` (`workflow_dispatch`): valida que se ejecute desde `main` y con la confirmación explícita, lista los entornos activos en S3 y, si no es solo listar, recorre cada uno destruyéndolo, dejando seguir el loop aunque alguno falle.

Archivo fuente: [diagrama-destroy-manual.puml](diagrams/diagrama-destroy-manual.puml).

![Diagrama 7 - Destroy manual](diagrams/diagrama7.png)

## 12. Resultado de las pruebas

En el PR #24 probamos la API desplegada y activamos la alarma de CloudWatch con `/error`. En el PR #26 el CSV dejó registro del despliegue, el cambio de imagen después de un push y el destroy tras el merge. El procedimiento para repetir el ciclo está en el [README](../README.md).
