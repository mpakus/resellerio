FROM elixir:1.18.1-otp-27 AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential git curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config ./config

RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile

COPY priv ./priv
COPY lib ./lib
COPY assets ./assets

RUN mix assets.setup
RUN mix assets.deploy
RUN mix compile
RUN mix release

FROM debian:bookworm-slim AS runner

RUN apt-get update && \
    apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV LANG=C.UTF-8
ENV MIX_ENV=prod
ENV PHX_SERVER=true
ENV GEMINI_MODEL_RECOGNITION=gemini-2.5-flash
ENV GEMINI_MODEL_DESCRIPTION=gemini-2.5-flash
ENV GEMINI_MODEL_MARKETPLACE_LISTING=gemini-2.5-flash
ENV GEMINI_MODEL_PRICE_RESEARCH=gemini-2.5-flash
ENV GEMINI_MODEL_RECONCILIATION=gemini-2.5-flash
ENV GEMINI_MODEL_LIFESTYLE_IMAGE=gemini-2.5-flash-image

COPY --from=builder /app/_build/prod/rel/reseller ./

EXPOSE 4000

CMD ["/app/bin/reseller", "start"]
