# Multi-Container Development Guide

## Prerequisites

- Docker Desktop (or compatible runtime) with Compose V2 enabled
- Kamal CLI for deployment pipelines (`gem install kamal`)

## Boot the Stack

```sh
cp config/env/example.env config/env/dev.env   # if not already created
docker compose up --build
```

Rails (`feedbrainer`) listens on `http://localhost:3001` in development, while the other services stay on host ports documented below. To stop everything, press `Ctrl+C` or run `docker compose down`.

Run Rails tasks directly inside the container, e.g.:

```sh
docker compose run --rm feedbrainer bin/rails db:prepare
```

## Port Matrix

| Service | Container Port | Dev Host Port | Prod Port (Kamal) |
| --- | --- | --- | --- |
| feedbrainer (Rails) | 3000 | 3001 | 3000 |
| skybeam (Elixir) | 4000 | 4101 | 4000 |
| skytorch (FastAPI) | 5000 | 5101 | 5000 |
| skywire (Node) | 6000 | 6101 | 6000 |
| postgres + pgvector | 5432 | 6432 | 5432 |
| redis | 6379 | 7637 | 6379 |

Update `docker-compose.yml` if you need additional services or custom mappings.

## Environment Files

- `config/env/example.env` – template for both local and remote environments
- `config/env/dev.env` – loaded by Docker Compose for every service

See `docs/env.md` for a description of every key and how cross-service URLs are shared.

## Deploying with Kamal

`config/deploy/kamal.yml` defines images and accessories for Rails, Elixir, FastAPI, Node, Postgres, and Redis. Configure your registry credentials (`REGISTRY_USER`, `REGISTRY_PASSWORD`) plus secret env vars (`RAILS_MASTER_KEY`, etc.), then deploy via:

```sh
kamal setup   # first deploy
kamal deploy  # subsequent releases
```

Customize hostnames and roles inside the YAML to match your actual infrastructure.

