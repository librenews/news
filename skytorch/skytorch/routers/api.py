"""Main API endpoints."""

from fastapi import APIRouter

router = APIRouter()


@router.get("/")
async def api_root():
    """API root endpoint."""
    return {
        "message": "Skytorch API",
        "version": "0.1.0",
    }

