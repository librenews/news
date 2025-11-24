# Skytorch

FastAPI application for Skytorch.

## Development

This application runs in a Docker container as part of the multi-container stack.

### Local Development (without Docker)

1. Install Poetry:
   ```bash
   curl -sSL https://install.python-poetry.org | python3 -
   ```

2. Install dependencies:
   ```bash
   poetry install
   ```

3. Run the application:
   ```bash
   poetry run uvicorn skytorch.main:app --reload --host 0.0.0.0 --port 5000
   ```

### Docker Development

The application is configured to run via Docker Compose. See the main project README for instructions.

## Dependencies

This application uses:
- **spacy**: Natural language processing library
- **sentence-transformers**: Sentence embeddings and semantic search
- **atproto**: AT Protocol Python SDK for Bluesky/AT Protocol integration

### Spacy Language Models

After installation, you may need to download spacy language models:

```bash
python -m spacy download en_core_web_sm
# or for larger models:
python -m spacy download en_core_web_md
python -m spacy download en_core_web_lg
```

In Docker, you can add this to your Dockerfile or run it as part of the container startup.

## Environment Variables

- `ENVIRONMENT`: Application environment (development, production)
- `POSTGRES_HOST`: PostgreSQL hostname
- `POSTGRES_PORT`: PostgreSQL port
- `POSTGRES_USER`: PostgreSQL username
- `POSTGRES_PASSWORD`: PostgreSQL password
- `POSTGRES_DB`: PostgreSQL database name
- `REDIS_URL`: Redis connection URL
- `FEEDBRAINER_URL`: URL to the Rails feedbrainer service
- `SKYBEAM_URL`: URL to the Elixir skybeam service
- `SKYWIRE_URL`: URL to the Node.js skywire service

