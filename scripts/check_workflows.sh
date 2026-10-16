#!/usr/bin/env bash
# Isolated CI checks. Never targets the production Compose file or its volumes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Clé éphémère : aucun secret de test fixe n'est stocké dans le dépôt.
if [[ -z "${JWT_SECRET:-}" ]]; then
  JWT_SECRET="$(openssl rand -base64 48 | tr -d '\n')"
  export JWT_SECRET
fi

if docker compose version >/dev/null 2>&1; then
  compose=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  compose=(docker-compose)
else
  echo 'Docker Compose is required to run containerized checks.' >&2
  exit 1
fi
compose+=(-p gotham-workflow-tests -f docker-compose.test.yml)
case "${1:-}" in
  backend|frontend) ;;
  *) echo 'Usage: bash scripts/check_workflows.sh backend|frontend' >&2; exit 2 ;;
esac
trap '"${compose[@]}" down -v --remove-orphans >/dev/null 2>&1 || true' EXIT
if [[ "$1" == backend ]]; then
  "${compose[@]}" up --build --abort-on-container-exit --exit-code-from backend-tests backend-tests
else
  "${compose[@]}" build frontend-tests
  "${compose[@]}" run --rm frontend-tests
fi
