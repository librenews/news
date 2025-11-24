"""Natural Language Processing utilities using spacy and sentence-transformers."""

import os
from typing import Optional

try:
    import spacy
    from sentence_transformers import SentenceTransformer
    HAS_NLP_DEPS = True
except ImportError:
    HAS_NLP_DEPS = False
    spacy = None
    SentenceTransformer = None


# Global model instances (lazy loaded)
_nlp_model: Optional[object] = None
_sentence_model: Optional[object] = None


def get_spacy_model(model_name: str = "en_core_web_sm"):
    """
    Get or load a spacy language model.
    
    Args:
        model_name: Name of the spacy model to load
        
    Returns:
        Loaded spacy model
        
    Raises:
        OSError: If the model is not installed
    """
    global _nlp_model
    
    if not HAS_NLP_DEPS:
        raise ImportError(
            "spacy is not installed. Install it with: pip install spacy"
        )
    
    if _nlp_model is None:
        try:
            _nlp_model = spacy.load(model_name)
        except OSError:
            raise OSError(
                f"spacy model '{model_name}' not found. "
                f"Download it with: python -m spacy download {model_name}"
            )
    
    return _nlp_model


def get_sentence_transformer(model_name: str = "all-MiniLM-L6-v2"):
    """
    Get or load a sentence transformer model.
    
    Args:
        model_name: Name of the sentence transformer model to load
        
    Returns:
        Loaded SentenceTransformer model
    """
    global _sentence_model
    
    if not HAS_NLP_DEPS:
        raise ImportError(
            "sentence-transformers is not installed. "
            "Install it with: pip install sentence-transformers"
        )
    
    if _sentence_model is None:
        _sentence_model = SentenceTransformer(model_name)
    
    return _sentence_model


def initialize_nlp_models(
    spacy_model: str = "en_core_web_sm",
    sentence_model: str = "all-MiniLM-L6-v2"
):
    """
    Initialize both NLP models at startup.
    
    Args:
        spacy_model: Name of the spacy model to load
        sentence_model: Name of the sentence transformer model to load
    """
    try:
        get_spacy_model(spacy_model)
        get_sentence_transformer(sentence_model)
    except (OSError, ImportError) as e:
        # Log warning but don't fail startup
        import logging
        logger = logging.getLogger(__name__)
        logger.warning(f"NLP models not available: {e}")

