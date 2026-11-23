#!/usr/bin/env bash
# Executed on the EC2 host by GitHub Actions over SSH.
#   deploy.sh ghcr.io/owner/image:tag
set -euo pipefail
IMAGE="${1:?image required}"
NAME=web
ENV_FILE=/opt/app/app.env

docker pull "$IMAGE"
OLD_IMAGE=$(docker inspect --format '{{.Config.Image}}' "$NAME" 2>/dev/null || true)
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" --restart unless-stopped \
  --env-file "$ENV_FILE" -p 127.0.0.1:8000:8000 "$IMAGE"

for _ in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:8000/health >/dev/null; then
    echo "Deployed $IMAGE"; docker image prune -f >/dev/null; exit 0
  fi
  sleep 2
done

echo "New version unhealthy; restoring ${OLD_IMAGE:-none}" >&2
docker rm -f "$NAME" || true
[[ -n "$OLD_IMAGE" ]] && docker run -d --name "$NAME" --restart unless-stopped \
  --env-file "$ENV_FILE" -p 127.0.0.1:8000:8000 "$OLD_IMAGE"
exit 1
