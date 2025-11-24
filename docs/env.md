# Environment Configuration

All services share a single environment file under `config/env/dev.env`. Copy `config/env/example.env` to create additional variants (e.g., `config/env/dev.env`, `config/env/prod.env`) and adjust secrets as needed.

## Core Keys

| Variable | Description |
| --- | --- |
| `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | Connection settings consumed by Rails, Elixir, and FastAPI applications. |
| `DATABASE_URL` | Convenience URL for Rails ActiveRecord. |
| `REDIS_URL` | Shared Redis endpoint for background jobs and caching. |

## Service-specific Keys

- **Rails (feedbrainer)**: `RAILS_ENV`, `RAILS_MASTER_KEY`, plus all `SKY*` URLs so the app can call other services.
- **Elixir (skybeam)**: `MIX_ENV`, optional `SKYBEAM_PORT` override.
- **FastAPI (skytorch)**: `FASTAPI_ENV`, `SKYTORCH_PORT`.
- **Node (skywire)**: `NODE_ENV`, `SKYWIRE_PORT`.

Update the `SKYBEAM_URL`, `SKYTORCH_URL`, and `SKYWIRE_URL` values if you need to expose different hostnames (e.g., during production deploys behind Kamal). The Docker Compose file automatically loads `config/env/dev.env` for every service so the values stay consistent.

