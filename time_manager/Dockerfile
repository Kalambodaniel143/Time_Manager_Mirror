FROM elixir:1.17.3-otp-27-alpine

# postgresql-client provides pg_isready, used by entrypoint.sh to wait for the db
RUN apk add --no-cache build-base postgresql-client

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=dev

COPY mix.exs mix.lock ./
RUN mix deps.get
RUN mix deps.compile

COPY . .
RUN mix compile

RUN chmod +x entrypoint.sh

EXPOSE 4000

ENTRYPOINT ["./entrypoint.sh"]
