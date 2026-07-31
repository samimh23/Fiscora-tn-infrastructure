#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: install-staging.sh <aws-region> <artifact-bucket> <backend-image>" >&2
  exit 2
fi

AWS_REGION="$1"
ARTIFACT_BUCKET="$2"
BACKEND_IMAGE="$3"
APP_DIR="/opt/fiscora"
ECR_HOST="${BACKEND_IMAGE%%/*}"

install -d -m 0750 "$APP_DIR" "$APP_DIR/web"
aws s3 cp "s3://$ARTIFACT_BUCKET/staging/runtime/docker-compose.yml" "$APP_DIR/docker-compose.yml" --region "$AWS_REGION"
aws s3 cp "s3://$ARTIFACT_BUCKET/staging/runtime/Caddyfile" "$APP_DIR/Caddyfile" --region "$AWS_REGION"
aws s3 sync "s3://$ARTIFACT_BUCKET/staging/web/" "$APP_DIR/web/" --delete --region "$AWS_REGION"

if [ ! -f "$APP_DIR/.env" ]; then
  umask 077
  POSTGRES_PASSWORD="$(openssl rand -hex 24)"
  JWT_SIGNING_KEY="$(openssl rand -hex 48)"
  MINIO_ACCESS_KEY="fiscora$(openssl rand -hex 8)"
  MINIO_SECRET_KEY="$(openssl rand -hex 32)"
  {
    printf 'POSTGRES_PASSWORD=%s\n' "$POSTGRES_PASSWORD"
    printf 'JWT_SIGNING_KEY=%s\n' "$JWT_SIGNING_KEY"
    printf 'MINIO_ACCESS_KEY=%s\n' "$MINIO_ACCESS_KEY"
    printf 'MINIO_SECRET_KEY=%s\n' "$MINIO_SECRET_KEY"
  } > "$APP_DIR/.env"
fi

if grep -q '^BACKEND_IMAGE=' "$APP_DIR/.env"; then
  sed -i "s|^BACKEND_IMAGE=.*$|BACKEND_IMAGE=$BACKEND_IMAGE|" "$APP_DIR/.env"
else
  printf 'BACKEND_IMAGE=%s\n' "$BACKEND_IMAGE" >> "$APP_DIR/.env"
fi

aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_HOST"
cd "$APP_DIR"
docker compose pull
docker compose up -d --remove-orphans
docker image prune -f
chown -R ec2-user:ec2-user "$APP_DIR"
chmod 0600 "$APP_DIR/.env"
