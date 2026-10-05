#!/bin/sh
set -e

if [ ! -f /app/.env ]; then
  echo "entrypoint: .env not found, stopping container"
  exit 1
fi

echo "entrypoint: waiting for database at ${PGHOST}:${PGPORT}..."
until pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" > /dev/null 2>&1; do
  sleep 1
done
echo "entrypoint: database is up"

mix ecto.create
mix ecto.migrate
# Roles and the first administrator (ADMIN_EMAIL / ADMIN_PASSWORD); idempotent.
mix run priv/repo/seeds.exs

echo "entrypoint: starting Phoenix"
exec mix phx.server
