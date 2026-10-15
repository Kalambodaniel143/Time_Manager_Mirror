FROM elixir:1.17.3-otp-27-alpine AS base

RUN apk add --no-cache build-base postgresql-client
WORKDIR /app
RUN mix local.hex --force && mix local.rebar --force
EXPOSE 4000

FROM base AS development
ENV MIX_ENV=dev
COPY mix.exs mix.lock ./
COPY config ./config
RUN mix deps.get && mix deps.compile
COPY . .
RUN mix compile && chmod +x entrypoint.sh
ENTRYPOINT ["./entrypoint.sh", "dev"]

# Cible par défaut : aucune compilation de développement n'est réutilisée.
FROM base AS production
ENV MIX_ENV=prod
COPY mix.exs mix.lock ./
COPY config ./config
RUN mix deps.get --only prod && mix deps.compile
COPY . .
RUN mix compile && mix phx.digest && chmod +x entrypoint.sh
RUN addgroup -S app && adduser -S -G app app \
    && cp -R /root/.mix /home/app/.mix \
    && chown -R app:app /app /home/app
USER app
ENTRYPOINT ["./entrypoint.sh", "prod"]
