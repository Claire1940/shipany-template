#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/root/Documents/AIProjects/shipany-template"
ENV_FILE="${APP_DIR}/.env.docker"
DATA_DIR="${APP_DIR}/data"
DB_FILE="${DATA_DIR}/local.db"
CONTAINER_NAME="aiwallpaper-best"
IMAGE="ghcr.io/claire1940/shipany-template:main"
DOMAIN="aiwallpaper.best"
ROUTER_NAME="aiwallpaper-best"
SERVICE_NAME="aiwallpaper-best"
SYSTEMD_SERVICE="shipany-template.service"

if [ ! -f "${ENV_FILE}" ]; then
  echo "ERROR: missing env file: ${ENV_FILE}" >&2
  exit 1
fi

if ! docker network inspect traefik-public >/dev/null 2>&1; then
  echo "ERROR: docker network traefik-public does not exist" >&2
  exit 1
fi

mkdir -p "${DATA_DIR}"

if [ -f "${DB_FILE}" ]; then
  BACKUP_FILE="${DB_FILE}.bak-$(date +%Y%m%d%H%M%S)"
  cp -a "${DB_FILE}" "${BACKUP_FILE}"
  echo "SQLite backup created: ${BACKUP_FILE}"
else
  echo "WARNING: SQLite database not found yet: ${DB_FILE}"
fi

TOKEN="$(gh auth token)"
echo "${TOKEN}" | docker login ghcr.io -u Claire1940 --password-stdin >/dev/null

docker pull "${IMAGE}"

if systemctl list-unit-files "${SYSTEMD_SERVICE}" >/dev/null 2>&1; then
  systemctl stop "${SYSTEMD_SERVICE}" || true
fi

chown -R 1001:1001 "${DATA_DIR}"

docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

docker run -d \
  --name "${CONTAINER_NAME}" \
  --network traefik-public \
  --restart unless-stopped \
  --env-file "${ENV_FILE}" \
  -v "${DATA_DIR}:/app/data" \
  --label "traefik.enable=true" \
  --label "traefik.docker.network=traefik-public" \
  --label "traefik.http.routers.${ROUTER_NAME}.rule=Host(\`${DOMAIN}\`) || Host(\`www.${DOMAIN}\`)" \
  --label "traefik.http.routers.${ROUTER_NAME}.entrypoints=web" \
  --label "traefik.http.services.${SERVICE_NAME}.loadbalancer.server.port=3000" \
  "${IMAGE}"

sleep 3

if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  echo "ERROR: container is not running" >&2
  docker logs --tail=100 "${CONTAINER_NAME}" >&2 || true
  exit 1
fi

docker exec "${CONTAINER_NAME}" sh -lc "wget -q -O /dev/null http://127.0.0.1:3000"

echo "Deployment succeeded: ${CONTAINER_NAME} -> ${DOMAIN}"
