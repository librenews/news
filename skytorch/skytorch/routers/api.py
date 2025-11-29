"""Main API endpoints."""

from fastapi import APIRouter, HTTPException, status, Query
from pydantic import BaseModel, Field
from typing import List, Optional

from skytorch.nlp import extract_named_entities, generate_embedding
from skytorch.atproto_client import get_atproto_client

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


class EmbeddingRequest(BaseModel):
    """Request model for embedding generation."""
    text: str = Field(..., description="Text to generate embedding for", min_length=1)
    model_name: str = Field(default="all-MiniLM-L6-v2", description="Sentence transformer model name")


class EmbeddingResponse(BaseModel):
    """Response model for embeddings."""
    embedding: List[float] = Field(..., description="Embedding vector as list of floats")
    model_version: str = Field(..., description="Model name/version used")


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


@router.post("/embeddings", response_model=EmbeddingResponse, status_code=status.HTTP_200_OK)
async def generate_embeddings(request: EmbeddingRequest):
    """
    Generate embedding vector for text.
    
    Accepts a POST request with text and returns an embedding vector
    using sentence-transformers.
    """
    try:
        embedding = generate_embedding(request.text, request.model_name)
        
        return EmbeddingResponse(
            embedding=embedding,
            model_version=request.model_name
        )
    except ImportError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Embedding service not available: {str(e)}"
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error generating embedding: {str(e)}"
        )


class FollowProfile(BaseModel):
    """Model for a follow profile."""
    did: str = Field(..., description="Decentralized Identifier")
    handle: Optional[str] = Field(None, description="User handle")
    display_name: Optional[str] = Field(None, description="Display name")
    avatar: Optional[str] = Field(None, description="Avatar URL")


class FollowsResponse(BaseModel):
    """Response model for follows."""
    follows: List[FollowProfile] = Field(..., description="List of profiles the user follows")
    count: int = Field(..., description="Total number of follows")
    cursor: Optional[str] = Field(None, description="Cursor for pagination")


class FollowersResponse(BaseModel):
    """Response model for followers."""
    followers: List[FollowProfile] = Field(..., description="List of profiles that follow the user")
    count: int = Field(..., description="Total number of followers")
    cursor: Optional[str] = Field(None, description="Cursor for pagination")


@router.get("/follows", response_model=FollowsResponse, status_code=status.HTTP_200_OK)
async def get_follows(
    did: str = Query(..., description="Decentralized Identifier to get follows for"),
    limit: int = Query(100, ge=1, le=100, description="Maximum number of results to return"),
    cursor: Optional[str] = Query(None, description="Cursor for pagination")
):
    """
    Get the list of profiles that a user follows.
    
    Returns an array of profiles (DIDs) that the specified user follows.
    """
    try:
        client = get_atproto_client()
        if not client:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="AT Protocol client not available. Check ATPROTO_HANDLE and ATPROTO_PASSWORD environment variables."
            )
        
        # Use the atproto client's get_follows method
        # According to atproto.blue docs, these are direct methods on the client
        result = client.get_follows(actor=did, limit=limit, cursor=cursor)
        
        # Extract profile information
        # atproto returns profiles with camelCase attributes
        follows = []
        for profile in result.follows:
            # Handle both camelCase and snake_case attribute names
            display_name = getattr(profile, 'displayName', None) or getattr(profile, 'display_name', None)
            avatar_url = None
            avatar_attr = getattr(profile, 'avatar', None)
            if avatar_attr:
                avatar_url = getattr(avatar_attr, 'ref', {}).get('$link') if hasattr(avatar_attr, 'ref') else str(avatar_attr)
            
            follows.append(FollowProfile(
                did=profile.did,
                handle=getattr(profile, 'handle', None),
                display_name=display_name,
                avatar=avatar_url
            ))
        
        return FollowsResponse(
            follows=follows,
            count=len(follows),
            cursor=getattr(result, 'cursor', None)
        )
    except ImportError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"AT Protocol library not available: {str(e)}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching follows: {str(e)}"
        )


@router.get("/followers", response_model=FollowersResponse, status_code=status.HTTP_200_OK)
async def get_followers(
    did: str = Query(..., description="Decentralized Identifier to get followers for"),
    limit: int = Query(100, ge=1, le=100, description="Maximum number of results to return"),
    cursor: Optional[str] = Query(None, description="Cursor for pagination")
):
    """
    Get the list of profiles that follow a user.
    
    Returns an array of profiles (DIDs) that follow the specified user.
    """
    try:
        client = get_atproto_client()
        if not client:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="AT Protocol client not available. Check ATPROTO_HANDLE and ATPROTO_PASSWORD environment variables."
            )
        
        # Use the atproto client's get_followers method
        # According to atproto.blue docs, these are direct methods on the client
        result = client.get_followers(actor=did, limit=limit, cursor=cursor)
        
        # Extract profile information
        # atproto returns profiles with camelCase attributes
        followers = []
        for profile in result.followers:
            # Handle both camelCase and snake_case attribute names
            display_name = getattr(profile, 'displayName', None) or getattr(profile, 'display_name', None)
            avatar_url = None
            avatar_attr = getattr(profile, 'avatar', None)
            if avatar_attr:
                avatar_url = getattr(avatar_attr, 'ref', {}).get('$link') if hasattr(avatar_attr, 'ref') else str(avatar_attr)
            
            followers.append(FollowProfile(
                did=profile.did,
                handle=getattr(profile, 'handle', None),
                display_name=display_name,
                avatar=avatar_url
            ))
        
        return FollowersResponse(
            followers=followers,
            count=len(followers),
            cursor=getattr(result, 'cursor', None)
        )
    except ImportError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"AT Protocol library not available: {str(e)}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching followers: {str(e)}"
        )

