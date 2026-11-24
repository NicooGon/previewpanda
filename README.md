# PreviewPanda

Proyecto de entornos efímeros por Pull Request. Cada PR que se abre levanta su propia API en AWS Lambda con una URL pública para probarla, y se destruye solo cuando el PR se cierra o se mergea. Todo lo maneja GitHub Actions con Terraform.

## Estructura del repo

- `app/`: la API (Node.js + Express), el Dockerfile y Swagger.
- `infra/`: el código de Terraform. `bootstrap/` crea el ECR compartido; `preview/` crea la Lambda, el rol de ejecución, la Function URL y el log group de cada PR.
- `scripts/`: los scripts que usan los workflows (`destruir_entorno.sh`, `registrar_entorno.sh`, `comentario_pr.js`, `cleanup_orphans.py`).
- `.github/workflows/`: `preview.yml` (apply), `destroy-preview.yml` (destroy al cerrar el PR), `destroy.yml` (destroy manual de todos los entornos), `nightly-cleanup.yml` (limpieza automática de huérfanos) y `ci.yml` (Terraform Quality).
- `docs/`: [informe](docs/informe.md), [matriz IAM](docs/iam.md), [FinOps](docs/finops.md), [concurrencia](docs/Concurrencia.md) y [diagramas](docs/diagrams/). El historial completo del CSV queda en la rama `registro/environments`.

El despliegue usa AWS Lambda con imagen de contenedor y Function URL, un repositorio ECR compartido y un bucket S3 para el state remoto.

## Runbook

Si el repo ya está configurado, podés ir directo a [desplegar y validar un preview](#desplegar-y-validar-un-preview). La configuración inicial se hace una sola vez por cuenta y por repositorio.

### Configuración inicial

#### AWS

1. Armá un bucket S3 privado en `us-east-1`, con acceso público bloqueado, cifrado y versionado. Tiene que existir antes de correr cualquier Terraform. El módulo compartido guarda su state en `bootstrap/terraform.tfstate`, y cada preview usa `previews/pr-<n>/terraform.tfstate`. Los dos backends usan `use_lockfile = true`. [Backend S3 de Terraform](https://developer.hashicorp.com/terraform/language/backend/s3)
2. Configurá el proveedor OIDC de GitHub Actions en IAM, con la URL `https://token.actions.githubusercontent.com` y la audiencia `sts.amazonaws.com`. El rol `previewpanda-ci` solo confía en tokens de este repositorio: la trust policy exige `aud = sts.amazonaws.com` y un `sub` que coincida con `repo:NicooGon@131786871/previewpanda@1442299923:*`. Los repositorios creados después del 15/7/2026 emiten el `sub` con el ID del dueño y del repositorio (`repo:OWNER@OWNER-ID/REPO@REPO-ID:...`), así que la trust policy tiene que usar ese formato; con el formato viejo (`repo:OWNER/REPO:...`) AWS rechaza el `AssumeRoleWithWebIdentity`. El `*` acepta cualquier contexto del repositorio; nuestros workflows usan dos: `pull_request` (Preview y Destroy preview) y `ref:refs/heads/main` (Nightly cleanup y Destroy). La política podría acotarse a esos dos; la dejamos con `*` por simplicidad durante el desarrollo, porque solo los integrantes del equipo tienen permiso de escritura en el repositorio. Para los permisos, usá de referencia la [matriz IAM](docs/iam.md) y la [política del rol](docs/previewpanda-ci-policy.json). GitHub Actions trabaja siempre con credenciales temporales, nunca con claves fijas. [Configuración de OIDC en AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)
3. Creá el repositorio ECR compartido con Terraform 1.11 o superior. Con una sesión autorizada en la cuenta, desde la raíz del repo:

   ```bash
   aws sts get-caller-identity
   terraform -chdir=infra/bootstrap init
   terraform -chdir=infra/bootstrap plan -out=tfplan
   terraform -chdir=infra/bootstrap apply tfplan
   ```

   Antes de aplicar, revisá el plan. Si el ECR ya existe, fijate primero que esté administrado por el state de bootstrap. Nosotros reusamos el bucket, el rol y el ECR que ya tenía armado el equipo.
4. Configurá el presupuesto mensual de AWS. Nosotros dejamos uno de USD 10, con alertas al 50 %, 80 % y 100 %. Los supuestos de costo están en [FinOps](docs/finops.md).

Si vas a usar otra cuenta, otro bucket o le cambiás el nombre al repositorio, revisá los valores fijos de los backends, los proveedores, la política IAM y [el script de huérfanos](scripts/cleanup_orphans.py): ese script tiene hardcodeados el bucket, el ECR y el repo de GitHub originales. Si solo cambiás las variables de GitHub, esa limpieza se queda apuntando a la configuración vieja.

#### GitHub

En **Settings → Secrets and variables → Actions → Variables**, cargá estas variables:

| Variable | Valor |
|---|---|
| `AWS_ROLE_ARN` | ARN del rol IAM que asume GitHub Actions por OIDC. |
| `AWS_REGION` | `us-east-1` en nuestro entorno. Tiene que coincidir con la región fija de `infra/preview/providers.tf` y `infra/preview/backend.tf`: si la cambiás, cambiá también esos dos archivos. |
| `TF_STATE_BUCKET` | Nombre del bucket S3 del state. |
| `ECR_REPOSITORY` | `previewpanda`, si usás el nombre que quedó definido en bootstrap. |
| `PREVIEW_COST_USD_PER_HOUR` | Tarifa opcional para el CSV. Si la dejás vacía, el script registra la duración igual, pero sin costo. |

Después:

- Habilitá GitHub Actions en el repo.
- Creá la rama `registro/environments` desde `main`, con el archivo `docs/environments.csv` adentro (solo el encabezado, sin filas).
- Dale permiso de escritura al token de Actions para que pueda pushear a esa rama y comentar en los PR (**Settings → Actions → General → Workflow permissions → Read and write**).
- Dejá `main` protegida como siempre (reglas de branch protection); `registro/environments` no necesita protección, es solo para el CSV.
- Ojo con la seguridad: la Function URL que se crea queda pública. Los PR que vienen de un fork no reciben token OIDC ni permiso de escritura, así que Preview falla en la autenticación y no despliega nada. Para la demo, usá PRs del mismo repositorio. Cualquiera con permiso de escritura en el repo puede desplegar su código en la cuenta de AWS, así que ese permiso queda solo para el equipo.

### Desplegar y validar un preview

1. Abrí un PR hacia `main` y anotá su número. La rama `registro/environments` queda reservada para el CSV, no la uses para otra cosa.
2. En **Actions**, esperá a que termine el workflow [Preview](.github/workflows/preview.yml). Construye o reutiliza la imagen de ECR, genera y aplica el plan de Terraform, e intenta registrar el evento en el CSV antes de comentar. El comentario que deja en el PR trae la Function URL, el commit, la imagen y el plan.
3. Fijate también el check [Terraform Quality](.github/workflows/ci.yml): revisa el formato y la configuración, corre TFLint y deja los hallazgos de Checkov. Es una ejecución separada de la del despliegue.
4. Abrí la Function URL desde el comentario del PR y probá estas rutas:

   | Ruta | Resultado esperado |
   |---|---|
   | `GET /` | El JSON muestra el número de PR y el commit desplegado. |
   | `GET /health` | HTTP 200 con el texto `ok`. |
   | `GET /api-docs` | Carga Swagger y deja probar la API desde ahí. |
   | `GET /error` | HTTP 500 a propósito, y queda registrado `preview_test_error` en CloudWatch Logs. Guardala para la prueba de observabilidad. |

5. Si querés probar una actualización, subí otro commit al mismo PR. Fijate que el comentario muestre el SHA nuevo, y que el historial de `registro/environments` tenga un evento `updated` (al abrir o reabrir es `created`).

### Validar Terraform en la máquina local

Desde la raíz del repo, podés correr las mismas validaciones que el workflow de Quality, sin tocar el backend remoto:

```bash
terraform -chdir=infra/preview fmt -check -recursive
terraform -chdir=infra/preview init -reconfigure -backend=false
terraform -chdir=infra/preview validate
```

El [workflow completo](.github/workflows/ci.yml) además corre TFLint y Checkov. El plan contra AWS de verdad se genera y se aplica en el workflow de Preview.

### Configurar y probar CloudWatch

La Lambda `pp-pr-<n>` escribe en `/aws/lambda/pp-pr-<n>`, con 7 días de retención configurados por Terraform. El dashboard, el filtro y la alarma de la demo los armamos a mano desde la consola, en `us-east-1`. Para nuestra demo, quedaron configurados para el PR #24.

1. En el dashboard, agregá las métricas de Lambda de `pp-pr-<n>`: `Invocations`, `Duration`, `Errors` y `Throttles`.
2. En el grupo de logs del PR, armá un filtro que coincida con `"preview_test_error"` y probalo con una línea real. Que publique `1` por coincidencia en la métrica propia `PreviewTestErrors`, con un namespace que uses igual en el panel y la alarma. Si querés reusar una alarma que ya existe, el filtro tiene que publicar en la misma región, namespace, nombre y dimensiones que esa alarma vigila. [Filtros de métricas de CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/MonitoringLogData.html)
3. Armá una alarma sobre esa métrica: estadística **Suma**, período de **1 minuto**, umbral **mayor o igual a 1**, **1 de 1** puntos de datos. Para esta prueba, tratá los datos faltantes como dentro del límite.
4. Con el filtro ya configurado, invocá `GET /error` desde Swagger o la Function URL. Confirmá el 500, el evento en los logs, un punto nuevo en `PreviewTestErrors` y que la alarma cambie de estado. Dale un rato a CloudWatch para procesar el punto antes de preocuparte.

Si querés mostrar el tablero ya armado, usá el PR de observabilidad mientras ese entorno siga activo. Al cerrarlo, el dashboard y la alarma (que configuramos a mano) quedan igual en CloudWatch, pero la métrica deja de recibir datos nuevos porque se borra el log group. El resultado de la prueba del PR #24 está en el [informe](docs/informe.md#7-observabilidad).

### Cerrar el PR y chequear el destroy

1. Cerrá o mergeá el PR. En **Actions**, fijate que termine [Destroy preview](.github/workflows/destroy-preview.yml). El comentario del PR te dice si la limpieza terminó bien.
2. En AWS, confirmá que la Function URL vieja ya no funcione, y que la Lambda `pp-pr-<n>` y su log group ya no estén. En ECR, chequeá que no queden tags con prefijo `pr-<n>-`. En S3, que no quede un objeto activo en `previews/pr-<n>/terraform.tfstate` (si el bucket tiene versionado, pueden quedar versiones viejas, eso es normal).
3. En `registro/environments`, buscá la fila `destroyed` de ese PR. El registro en el CSV puede fallar por separado del destroy, así que un destroy exitoso no te garantiza que la fila quedó escrita: si falta, revisalo aparte.

### Si algo falla

| Qué pasa | Qué mirar |
|---|---|
| Preview falla en OIDC o antes de llegar a Terraform | Mirá el primer paso que falló: la región, el ARN, la confianza del rol, los permisos de ECR o S3. Corregido eso, reintentá si el PR sigue abierto y ese commit sigue siendo el que querés probar. Si el código cambió, usá el run del commit nuevo. |
| El plan, el apply o el destroy se traban por un lock | Puede haber otra ejecución (Preview, Destroy preview, Destroy o Nightly cleanup) usando el mismo state. Esperá a que termine y reintentá. No toques el state mientras investigás. [Política de concurrencia](docs/Concurrencia.md) |
| El PR se cerró y el destroy falló | Abrí el run y fijate si falló Terraform, el borrado en S3 o la limpieza de ECR. Si la causa es externa (permisos, un lock, un error temporal de AWS), arreglala y reintentá el run de cierre: el PR sigue cerrado, no hace falta reabrirlo. Si el error está en el código, reintentar no sirve, porque el run usa el código del commit del PR; corré [Nightly cleanup](.github/workflows/nightly-cleanup.yml) a mano con `dias_limite=-1`, que usa el código de `main` y solo destruye entornos de PRs cerrados. Si lo que falló fue la limpieza de ECR, el state ya se había borrado: revisá que no queden tags `pr-<n>-` en ECR. |
| La API tira 500 pero la alarma no se mueve | Confirmá que le pegaste a `/error` en la Function URL correcta, que el evento está en el log group de ese PR, y que el filtro y la alarma apuntan a la misma métrica. Fijate si hay un punto nuevo antes de probar de nuevo. |
| Falta una fila en el CSV | Mirá el paso de registro de ese run, y la rama `registro/environments` y sus permisos. Comparalo contra lo que realmente hay en AWS antes de asumir que el despliegue falló. |

### Limpieza nocturna y manual

- [Nightly cleanup](.github/workflows/nightly-cleanup.yml) corre solo a las 06:00 UTC (03:00 de Uruguay). Revisa los states de los previews, con un límite por defecto de 3 días enteros desde la última modificación. También se puede disparar a mano con el parámetro `dias_limite`. Nunca toca un PR que sigue abierto, ni uno cuyo estado no pudo confirmar.
- [Destroy](.github/workflows/destroy.yml) se dispara a mano desde `main` y pide la confirmación `destroy`. Con `solo_listar` activado (el default), solo muestra qué entornos hay y no toca nada. Si lo desactivás, intenta destruir **todos** los previews que tengan state, hasta los de PR que siguen abiertos — reservalo para cuando el equipo decida hacer un cierre general.
- Las dos limpiezas trabajan sobre los states que están activos. Si quedó un tag de ECR sin su state por un fallo a mitad de camino, revisalo directo en ECR y usá el run de cierre de ese PR para terminar la limpieza.

## Por qué excluimos algunas reglas de Checkov

Dejamos Checkov activo, pero con algunas reglas excluidas a propósito porque no entran en lo que pide este proyecto:

- `CKV_AWS_258` y `CKV_AWS_301`: la Function URL tiene que ser pública, sino no se podría probar el entorno desde el Pull Request.
- `CKV_AWS_338`: acá pedimos 7 días de retención de logs, no un año.
- `CKV_AWS_158`, `CKV_AWS_50`, `CKV_AWS_117`, `CKV_AWS_115`, `CKV_AWS_116` y `CKV_AWS_272`: son sobre KMS, X-Ray, VPC, límite de concurrencia, DLQ y firma de código, ninguno obligatorio para este alcance.

Los hallazgos de Checkov quedan en el log del job igual, pero con `soft_fail: true` no hacen fallar el check por sí solos.

## La aplicación

Las instrucciones para correrla y las rutas disponibles están en [app/README.md](app/README.md).