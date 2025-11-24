# Skywire

Node.js application for Skywire.

## Development

This application runs in a Docker container as part of the multi-container stack.

### Local Development (without Docker)

1. Install dependencies:
   ```bash
   npm install
   ```

2. Run the application:
   ```bash
   npm run dev
   ```

The application will be available at `http://localhost:6000`.

### Docker Development

The application is configured to run via Docker Compose. See the main project README for instructions.

The application will be available at `http://localhost:6101` in development.

## Environment Variables

- `NODE_ENV`: Node environment (development, production)
- `PORT`: Server port (default: 6000)
- `HOST`: Server host (default: 0.0.0.0)

## Health Endpoints

- `GET /health` - Health check
- `GET /health/ready` - Readiness check
- `GET /health/live` - Liveness check

