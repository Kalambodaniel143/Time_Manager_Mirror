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

echo "entrypoint: starting Phoenix"
exec mix phx.server
