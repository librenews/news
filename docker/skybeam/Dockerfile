# syntax=docker/dockerfile:1.7

ARG ELIXIR_VERSION=1.16

FROM elixir:${ELIXIR_VERSION} AS base

ENV APP_HOME=/app/skybeam \
    MIX_ENV=prod \
    LANG=C.UTF-8

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential \
      git \
      curl \
      libssl-dev \
      inotify-tools \
      nodejs \
      npm && \
    npm install --global yarn && \
    rm -rf /var/lib/apt/lists/*

WORKDIR ${APP_HOME}

RUN mix local.hex --force && \
    mix local.rebar --force

FROM base AS deps
COPY skybeam/mix.exs ./
COPY skybeam/mix.lock* ./
COPY skybeam/config ./config
RUN mix deps.get

FROM deps AS build
COPY skybeam ${APP_HOME}
RUN mix assets.deploy || true
RUN mix compile

FROM build AS dev
ENV MIX_ENV=dev
# Create entrypoint script to ensure deps are installed
RUN echo '#!/bin/sh\nmix deps.get\nmix phx.server' > /entrypoint.sh && \
    chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]

FROM build AS release
RUN MIX_ENV=prod mix release

FROM debian:bookworm-slim AS production
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      libssl3 \
      libstdc++6 && \
    rm -rf /var/lib/apt/lists/*
ENV APP_HOME=/opt/skybeam \
    HOME=/opt/skybeam \
    MIX_ENV=prod
WORKDIR ${APP_HOME}
COPY --from=release /app/skybeam/_build/prod/rel/ /app_release
CMD ["/app_release/skybeam/bin/skybeam", "start"]

