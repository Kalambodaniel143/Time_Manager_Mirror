#!/bin/sh
set -eu

# Le mode est fixé par la cible Docker, pas par le fichier .env.
case "${1:-}" in
  dev|prod) export MIX_ENV="$1" ;;
  *) echo "entrypoint: mode dev ou prod requis" >&2; exit 1 ;;
esac

# Charge runtime.exs et refuse les secrets invalides avant d'attendre la base.
mix run --no-compile --no-start -e ':ok'

echo "entrypoint: attente de PostgreSQL (60 tentatives maximum)"
attempts=0
until {
  if [ "$MIX_ENV" = prod ]; then
    # Même URL que le Repo Phoenix, sans afficher les identifiants.
    pg_isready -q -d "$DATABASE_URL"
  else
    pg_isready -q -h "$PGHOST" -p "$PGPORT" -U "$PGUSER"
  fi
}; do
  attempts=$((attempts + 1))
  if [ "$attempts" -ge 60 ]; then
    echo "entrypoint: PostgreSQL indisponible" >&2
    exit 1
  fi
  sleep 1
done

mix ecto.create --no-compile
mix ecto.migrate --no-compile
# Rôles et administrateur facultatif ; initialisation idempotente.
mix run --no-compile priv/repo/seeds.exs

echo "entrypoint: démarrage Phoenix en $MIX_ENV"
exec mix phx.server --no-compile
