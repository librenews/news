# Skybeam

Phoenix/Elixir application for Skybeam.

## Development

This application runs in a Docker container as part of the multi-container stack.

### Local Development (without Docker)

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

### Docker Development

The application is configured to run via Docker Compose. See the main project README for instructions.

The application will be available at `http://localhost:4101` in development.

## Environment Variables

- `MIX_ENV`: Elixir environment (dev, prod)
- `DATABASE_URL`: PostgreSQL connection URL
- `POSTGRES_HOST`: PostgreSQL hostname
- `POSTGRES_PORT`: PostgreSQL port
- `POSTGRES_USER`: PostgreSQL username
- `POSTGRES_PASSWORD`: PostgreSQL password
- `POSTGRES_DB`: PostgreSQL database name

## Health Endpoints

- `GET /health` - Health check
- `GET /health/ready` - Readiness check
- `GET /health/live` - Liveness check

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
