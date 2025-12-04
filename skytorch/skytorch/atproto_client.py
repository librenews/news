"""AT Protocol (Bluesky) client utilities."""

import os
from typing import Optional

try:
    from atproto import Client
    HAS_ATPROTO = True
except ImportError:
    HAS_ATPROTO = False
    Client = None


# Global client instance (lazy loaded)
_atproto_client: Optional[object] = None


def get_atproto_client(
    handle: Optional[str] = None,
    password: Optional[str] = None,
    force_refresh: bool = False
) -> Optional[object]:
    """
    Get or create an AT Protocol client.
    
    Args:
        handle: Bluesky handle (e.g., 'user.bsky.social')
        password: App password for authentication
        force_refresh: Force re-authentication even if client exists
        
    Returns:
        Authenticated AT Protocol client, or None if credentials not provided
        
    Raises:
        ImportError: If atproto is not installed
    """
    global _atproto_client
    
    if not HAS_ATPROTO:
        raise ImportError(
            "atproto is not installed. Install it with: pip install atproto"
        )
    
    # Use environment variables if not provided
    handle = handle or os.getenv("ATPROTO_HANDLE")
    password = password or os.getenv("ATPROTO_PASSWORD")
    
    if not handle or not password:
        return None
    
    # Force refresh or create new client if needed
    if force_refresh or _atproto_client is None:
        _atproto_client = Client()
        _atproto_client.login(handle, password)
    
    return _atproto_client


def reset_atproto_client():
    """
    Reset the global AT Protocol client, forcing re-authentication on next use.
    Use this when you get InvalidToken errors.
    """
    global _atproto_client
    _atproto_client = None


def initialize_atproto_client():
    """
    Initialize AT Protocol client at startup if credentials are available.
    """
    try:
        client = get_atproto_client()
        if client:
            import logging
            logger = logging.getLogger(__name__)
            logger.info("AT Protocol client initialized successfully")
    except (ImportError, Exception) as e:
        # Log warning but don't fail startup
        import logging
        logger = logging.getLogger(__name__)
        logger.warning(f"AT Protocol client not available: {e}")

