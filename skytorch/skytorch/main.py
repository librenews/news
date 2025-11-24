"""Main FastAPI application entry point."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from skytorch.config import get_settings
from skytorch.routers import health, api

settings = get_settings()

app = FastAPI(
    title="Skytorch API",
    description="FastAPI application for Skytorch",
    version="0.1.0",
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health.router, tags=["health"])
app.include_router(api.router, prefix="/api/v1", tags=["api"])


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "name": "Skytorch",
        "version": "0.1.0",
        "status": "running",
    }

