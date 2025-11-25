"""Main API endpoints."""

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field
from typing import List

from skytorch.nlp import extract_named_entities

router = APIRouter()


class TextRequest(BaseModel):
    """Request model for text input."""
    text: str = Field(..., description="Text to extract named entities from", min_length=1)


class NamedEntity(BaseModel):
    """Model for a named entity."""
    text: str = Field(..., description="The entity text")
    label: str = Field(..., description="The entity type/label (e.g., PERSON, ORG, GPE)")
    start: int = Field(..., description="Character start position in the original text")
    end: int = Field(..., description="Character end position in the original text")


class EntitiesResponse(BaseModel):
    """Response model for named entities."""
    entities: List[NamedEntity] = Field(..., description="List of extracted named entities")
    count: int = Field(..., description="Total number of entities found")


@router.get("/")
async def api_root():
    """API root endpoint."""
    return {
        "message": "Skytorch API",
        "version": "0.1.0",
    }


@router.post("/entities", response_model=EntitiesResponse, status_code=status.HTTP_200_OK)
async def extract_entities(request: TextRequest):
    """
    Extract named entities from text.
    
    Accepts a POST request with text and returns a list of named entities
    (persons, organizations, locations, etc.) found in the text.
    """
    try:
        entities_data = extract_named_entities(request.text)
        entities = [NamedEntity(**entity) for entity in entities_data]
        
        return EntitiesResponse(
            entities=entities,
            count=len(entities)
        )
    except ImportError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"NLP service not available: {str(e)}"
        )
    except OSError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Spacy model not found: {str(e)}"
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error processing text: {str(e)}"
        )

