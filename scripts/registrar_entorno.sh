#!/usr/bin/env bash
# Agrega una fila a docs/environments.csv en la rama registro/environments.
#
# Uso: registrar_entorno.sh <created|updated|destroyed> [image_tag] [url] [notes]
# Entorno:
#   PR_NUMBER      número del PR (obligatoria)
#   ENV_NAME       nombre del entorno, pr-<n> (obligatoria)
#   PR_CREATED_AT  inicio de respaldo para lifetime_hours si no hay fila created (destroyed)
#   COST_PER_HOUR  tarifa USD/h; vacía → costo vacío y nota sin_tarifa (destroyed)
set -euo pipefail

EVENT="$1"
IMAGE_TAG="${2:-}"
URL="${3:-}"
NOTES="${4:-}"

BRANCH="registro/environments"
CSV="docs/environments.csv"
WT="${RUNNER_TEMP:-/tmp}/registro"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

git config --global user.name "github-actions[bot]"
git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"

git fetch --depth=1 origin "+${BRANCH}:refs/remotes/origin/${BRANCH}"
git worktree add --detach "$WT" "origin/${BRANCH}"
cd "$WT"

# Arma la fila a partir del CSV actual de la rama.
build_row() {
  local tag="$IMAGE_TAG" notes="$NOTES" hours="" cost=""

  if [ "$EVENT" = "destroyed" ]; then
    local start
    start=$(awk -F, -v pr="$PR_NUMBER" '$1==pr && $3=="created" {t=$4} END {print t}' "$CSV")
    if [ -z "$start" ]; then
      start="$PR_CREATED_AT"
      notes="${notes} inicio=pull_request.created_at"
    fi
    tag=$(awk -F, -v pr="$PR_NUMBER" '$1==pr && $5!="" {t=$5} END {print t}' "$CSV")

    local secs=$(( $(date -u -d "$NOW" +%s) - $(date -u -d "$start" +%s) ))
    hours=$(awk -v s="$secs" 'BEGIN {printf "%.2f", s/3600}')
    if [ -n "${COST_PER_HOUR:-}" ]; then
      cost=$(awk -v s="$secs" -v r="$COST_PER_HOUR" 'BEGIN {printf "%.6f", s/3600*r}')
    else
      notes="${notes} sin_tarifa"
    fi
  fi

  echo "${PR_NUMBER},${ENV_NAME},${EVENT},${NOW},${tag},${URL},${hours},${cost},${notes# }"
}

# Hasta 5 intentos: otro workflow puede haber empujado a la rama entre fetch y push.
for i in 1 2 3 4 5; do
  build_row >> "$CSV"
  git add "$CSV"
  git commit -q -m "registro: pr-${PR_NUMBER} ${EVENT}"
  if git push -q origin "HEAD:${BRANCH}"; then
    echo "Fila registrada: $(tail -n 1 "$CSV")"
    exit 0
  fi
  echo "Push rechazado (intento $i), reintentando"
  sleep $(( i * 2 ))
  git fetch --depth=1 origin "+${BRANCH}:refs/remotes/origin/${BRANCH}"
  git reset -q --hard "origin/${BRANCH}"
done

echo "No se pudo registrar la fila después de 5 intentos"
exit 1
