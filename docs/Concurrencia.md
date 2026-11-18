# Política de concurrencia

## Objetivo

Evitar que dos operaciones de Terraform trabajen al mismo tiempo sobre el state de un mismo entorno.

Cada PR tiene su propio state (`previews/pr-<n>/terraform.tfstate`) en el bucket S3, así que los PRs distintos se ejecutan en paralelo sin riesgo. La exclusión solo hace falta dentro de un mismo PR.

## Primera capa: grupos de concurrencia de GitHub Actions

`preview.yml` y `destroy-preview.yml` declaran el mismo grupo:

```yaml
concurrency:
  group: preview-pr-${{ github.event.pull_request.number }}
  cancel-in-progress: false
```

| Regla | Motivo |
|---|---|
| Un grupo por PR: `preview-pr-<n>` | Serializa las operaciones de un PR sin bloquear a los demás. |
| Mismo grupo en `preview.yml` y `destroy-preview.yml` | Un destroy no empieza mientras corre un apply del mismo PR. |
| `cancel-in-progress: false` | Cortar un apply o un destroy a la mitad puede dejar recursos fuera del state o un lock sin liberar. |

### Comportamiento dentro de un grupo

GitHub Actions admite un run en ejecución y uno pendiente por grupo. Si llega otro, reemplaza al pendiente, que queda cancelado. `cancel-in-progress: false` protege al run en ejecución, no al pendiente. El resultado es que siempre se ejecuta el último evento:

| Escenario | Resultado |
|---|---|
| Dos pushes seguidos | El primero termina y el segundo espera su turno. |
| Tres pushes seguidos | El primero termina, el segundo se cancela mientras espera y el tercero se ejecuta. |
| Cierre del PR durante un apply | El apply termina y después se ejecuta el destroy. |
| Push pendiente y cierre del PR | El destroy reemplaza al push pendiente. |
| Cierre y reapertura durante un apply | El preview de la reapertura reemplaza al destroy pendiente y el entorno sigue activo. |
| Dos PRs a la vez | Se ejecutan en paralelo: grupos y states distintos. |

## Segunda capa: lock del state

El backend S3 usa `use_lockfile = true`, y `apply` y `destroy` se ejecutan con `-lock-timeout=5m`. Si una operación que no pasa por los grupos (el job nocturno o un `terraform` manual) toma el mismo state, la segunda espera hasta 5 minutos a que se libere el lock y, si no se libera, falla sin escribir.

## Otros workflows

| Workflow | Grupo | Relación con los previews |
|---|---|---|
| `ci.yml` | Ninguno | Hace `init -backend=false`: no lee ni escribe states. |
| `nightly-cleanup.yml` | `nightly-cleanup` | Un solo job recorre todos los states, así que no puede usar el grupo de cada PR. Solo destruye PRs cerrados hace más de 3 días; si coincide con una reapertura, el lock del state hace esperar a uno de los dos. |
| `deploy.yml` y `destroy.yml` | `production` (compartido) | Usan el state del entorno principal, separado de `previews/`. |

## Registro de entornos

Todos los PRs escriben sus filas de `docs/environments.csv` en la misma rama (`registro/environments`), así que dos PRs pueden intentar hacer push a la vez. `scripts/registrar_entorno.sh` reintenta hasta 5 veces: si el push es rechazado, vuelve a traer la rama, agrega la fila sobre la versión nueva y empuja otra vez.
