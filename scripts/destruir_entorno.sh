#!/usr/bin/env bash
# Destruye un entorno de preview: recursos, state en S3 e imágenes <env_name>-* en ECR.
# El state y las imágenes se borran solo si el destroy termina bien.
#
# Uso: destruir_entorno.sh <env_name>
# Entorno: TF_STATE_BUCKET, ECR_REPOSITORY
set -euo pipefail

ENV_NAME="$1"
KEY="previews/${ENV_NAME}/terraform.tfstate"
TF_DIR="$(dirname "$0")/../infra/preview"

terraform -chdir="$TF_DIR" init -input=false -reconfigure \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=${KEY}"

terraform -chdir="$TF_DIR" destroy -auto-approve -input=false -lock-timeout=5m \
  -var "env_name=${ENV_NAME}"

aws s3 rm "s3://${TF_STATE_BUCKET}/${KEY}"

tags=$(aws ecr list-images --repository-name "$ECR_REPOSITORY" \
         --filter tagStatus=TAGGED \
         --query "imageIds[?starts_with(imageTag, '${ENV_NAME}-')].imageTag" \
         --output text)

if [ -z "$tags" ] || [ "$tags" = "None" ]; then
  echo "No hay imágenes ${ENV_NAME}-* en ECR"
else
  ids=()
  for t in $tags; do ids+=("imageTag=$t"); done
  failures=$(aws ecr batch-delete-image --repository-name "$ECR_REPOSITORY" \
               --image-ids "${ids[@]}" --query 'length(failures)' --output text)
  if [ "$failures" != "0" ]; then
    echo "No se pudieron borrar $failures imágenes de ${ENV_NAME}"
    exit 1
  fi
fi

echo "${ENV_NAME} destruido"
