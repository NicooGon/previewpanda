# Política de concurrencia

## Objetivo

Evitar que dos operaciones de Terraform trabajen al mismo tiempo sobre el state de un mismo entorno.

Cada PR tiene su propio state (`previews/pr-<n>/terraform.tfstate`), así que PRs distintos pueden ejecutarse en paralelo. La exclusión solo hace falta dentro de un mismo PR.

## Política

```yaml
concurrency:
  group: preview-pr-${{ github.event.pull_request.number }}
  cancel-in-progress: false
```

| Regla | Motivo |
|---|---|
| Un grupo por PR: `preview-pr-<n>` | Serializa las operaciones de un PR sin bloquear a los demás. |
| Mismo grupo en `preview.yml` y `destroy-preview.yml` | Un destroy no puede ejecutarse durante un apply del mismo PR. |
| `cancel-in-progress: false` | Cortar un apply o un destroy puede dejar recursos creados a medias, fuera del state, o un lock sin liberar. |

## Comportamiento de GitHub Actions

En cada grupo puede haber un run en ejecución y uno pendiente. Si llega otro, reemplaza al pendiente, que se cancela. `cancel-in-progress: false` protege al run en ejecución, no al pendiente.

El resultado es que siempre termina ejecutándose el último evento:

| Escenario | Resultado |
|---|---|
| Dos pushes seguidos | El primero termina y el segundo espera su turno. |
| Tres pushes seguidos | El primero termina, el segundo se cancela mientras espera y el tercero se ejecuta. |
| Cierre del PR durante un apply | El apply termina y después se ejecuta el destroy. |
| Push pendiente y cierre del PR | El destroy reemplaza al push pendiente. |
| Cierre y reapertura durante un apply | El preview de la reapertura reemplaza al destroy pendiente y el entorno sigue activo. |
| Dos PRs a la vez | Se ejecutan en paralelo porque tienen grupos y states distintos. |

## Segunda capa: lock del state

El backend S3 usa `use_lockfile = true`. Si dos operaciones llegan al mismo state, por ejemplo una ejecución manual fuera de los workflows, la segunda falla al tomar el lock en lugar de escribir sobre la primera.

## Otros workflows

- `nightly-cleanup.yml`: cada destrucción de un entorno debe usar el grupo `preview-pr-<n>` de ese entorno.
- `deploy.yml` y `destroy.yml`: deben compartir un grupo propio, separado de los previews.

## Pruebas

Las pruebas se hacen con el apply simulado (`sleep 60`) y se repiten con Terraform real.

| Prueba | Resultado esperado | Estado | Evidencia |
|---|---|---|---|
| Dos pushes seguidos | El segundo run queda en cola. | Hecha | <!-- link al run --> |
| Tres pushes seguidos | El run del medio aparece cancelado. | Pendiente | <!-- link al run --> |
| Cierre del PR durante un apply | El destroy espera a que termine el apply. | Pendiente | <!-- link al run --> |
| Dos PRs a la vez | Los dos runs se ejecutan en paralelo. | Pendiente | <!-- link al run --> |