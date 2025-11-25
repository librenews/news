
ARG ELIXIR_VERSION=1.16

FROM elixir:${ELIXIR_VERSION} AS build

WORKDIR /app

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential \
      git \
      nodejs \
      npm && \
    rm -rf /var/lib/apt/lists/*

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build environment
ENV MIX_ENV=prod

# Copy mix files
COPY skybeam/mix.exs skybeam/mix.lock* ./

# Install dependencies (get first, then compile separately to avoid Hex/SSL issues)
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy application code
COPY skybeam/lib/ ./lib/
COPY skybeam/config/ ./config/
COPY skybeam/assets/ ./assets/
COPY skybeam/priv/ ./priv/

# Compile application and build assets
RUN mix assets.deploy || true
RUN mix compile

# Create release
RUN mix release

FROM build AS dev
ENV MIX_ENV=dev
# Install dev dependencies
RUN mix deps.get
CMD ["sh", "-c", "mix phx.server"]

# Runtime stage
FROM debian:bookworm-slim AS production

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      openssl \
      libncurses6 \
      ca-certificates \
      curl && \
    rm -rf /var/lib/apt/lists/*

# Copy release from build stage
COPY --from=build /app/_build/prod/rel/skybeam /app

# Create non-root user
RUN groupadd -g 1000 app && \
    useradd -u 1000 -g app -s /bin/bash -m app && \
    chown -R app:app /app

USER app

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD pgrep -f "beam" > /dev/null || exit 1

# Run the release
ENTRYPOINT ["/app/bin/skybeam"]
CMD ["start"]

