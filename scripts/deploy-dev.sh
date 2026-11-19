#!/usr/bin/env bash
set -euo pipefail
# Installed as /usr/local/bin/deploy-fera-dev (root-owned) on Antiserver.
exec 9>/run/lock/fera-dev-deploy.lock
flock -n 9 || { echo 'Another DEV deployment is running.' >&2; exit 1; }
REPO=/home/antiserver/fera-metalurgica
cd "$REPO"
sudo -u antiserver git fetch origin develop
sudo -u antiserver git checkout develop
sudo -u antiserver git pull --ff-only origin develop
sudo -u antiserver git log -1 --oneline
compose=(docker compose -f compose.server.yaml)
"${compose[@]}" up -d --wait db
# Keep private backups outside the repository and Docker volume.
install -d -m 700 /var/backups/fera-dev
backup=$(mktemp /var/backups/fera-dev/pre-migration-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX.dump)
chmod 600 "$backup"
"${compose[@]}" exec -T db sh -c 'exec pg_dump -Fc -U "$POSTGRES_USER" -d "$POSTGRES_DB"' > "$backup"
"${compose[@]}" exec -T db pg_restore --list < "$backup" >/dev/null
printf 'Database backup verified: %s\n' "$backup"
python3 scripts/migrate.py --compose-file compose.server.yaml
# set -e prevents publication if backup or migrations failed.
"${compose[@]}" up -d --build --wait
curl --fail --silent --show-error --retry 5 --retry-delay 2 --retry-connrefused http://127.0.0.1:8080/api/health
printf '\nDEPLOY DEV CONCLUIDO\n'
