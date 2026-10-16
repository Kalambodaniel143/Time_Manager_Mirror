#!/usr/bin/env bash
# Déclenchement explicite seulement ; Docker doit déjà être installé.
set -euo pipefail
[[ "${1:-}" == "--approved" ]] || { echo "Déploiement non autorisé : option --approved requise." >&2; exit 1; }
cd ~
command -v docker >/dev/null
chmod 600 .env
docker compose config --quiet
docker compose pull
docker compose up -d --remove-orphans
