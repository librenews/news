# syntax=docker/dockerfile:1.7

ARG RUBY_VERSION=3.2.2
FROM ruby:${RUBY_VERSION}-slim AS base

ENV APP_HOME=/app \
    BUNDLE_PATH=/bundle \
    BUNDLE_BIN=/bundle/bin \
    BUNDLE_WITHOUT=development:test \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      git \
      libpq-dev \
      nodejs \
      npm \
      curl && \
    npm install --global yarn && \
    rm -rf /var/lib/apt/lists/*

WORKDIR ${APP_HOME}
ENV PATH="${BUNDLE_BIN}:${PATH}"

FROM base AS deps
COPY feedbrainer/Gemfile ./feedbrainer/
COPY feedbrainer/Gemfile.lock* ./feedbrainer/
WORKDIR ${APP_HOME}/feedbrainer
RUN bundle install --jobs 4

FROM deps AS dev
ENV RAILS_ENV=development \
    NODE_ENV=development \
    BUNDLE_WITHOUT=""
RUN gem install bundler -v '~> 2.5'
COPY feedbrainer ${APP_HOME}/feedbrainer
WORKDIR ${APP_HOME}/feedbrainer
RUN bundle install
CMD ["bin/dev"]

FROM deps AS build
ENV RAILS_ENV=production \
    NODE_ENV=production
COPY feedbrainer ${APP_HOME}/feedbrainer
WORKDIR ${APP_HOME}/feedbrainer
RUN bundle exec rails assets:precompile

FROM ruby:${RUBY_VERSION}-slim AS production
ENV APP_HOME=/app/feedbrainer \
    RAILS_ENV=production \
    NODE_ENV=production \
    BUNDLE_PATH=/bundle \
    BUNDLE_BIN=/bundle/bin \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      libpq5 \
      curl && \
    rm -rf /var/lib/apt/lists/*
WORKDIR ${APP_HOME}
COPY --from=deps /bundle /bundle
COPY --from=build /app/feedbrainer ${APP_HOME}
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]

