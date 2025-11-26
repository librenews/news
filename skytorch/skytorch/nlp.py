"""Natural Language Processing utilities using spacy and sentence-transformers."""

import os
from typing import Optional, List

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


def extract_named_entities(text: str, model_name: str = "en_core_web_sm"):
    """
    Extract named entities from text using Spacy.
    
    Args:
        text: Input text to extract entities from
        model_name: Name of the spacy model to use
        
    Returns:
        List of dictionaries with keys: text, label, start, end
        
    Raises:
        ImportError: If spacy is not installed
        OSError: If the spacy model is not found
        ValueError: If text is empty or invalid
    """
    if not text or not text.strip():
        raise ValueError("Text cannot be empty")
    
    if not HAS_NLP_DEPS:
        raise ImportError(
            "spacy is not installed. Install it with: pip install spacy"
        )
    
    # Get the spacy model
    nlp = get_spacy_model(model_name)
    
    # Process the text
    doc = nlp(text)
    
    # Extract entities
    entities = []
    for ent in doc.ents:
        entities.append({
            "text": ent.text,
            "label": ent.label_,
            "start": ent.start_char,
            "end": ent.end_char,
        })
    
    return entities


def generate_embedding(text: str, model_name: str = "all-MiniLM-L6-v2") -> List[float]:
    """
    Generate embedding vector for text using sentence-transformers.
    
    Args:
        text: Input text to generate embedding for
        model_name: Name of the sentence transformer model to use
        
    Returns:
        List of floats representing the embedding vector
        
    Raises:
        ImportError: If sentence-transformers is not installed
        ValueError: If text is empty or invalid
    """
    if not text or not text.strip():
        raise ValueError("Text cannot be empty")
    
    if not HAS_NLP_DEPS:
        raise ImportError(
            "sentence-transformers is not installed. "
            "Install it with: pip install sentence-transformers"
        )
    
    # Get the sentence transformer model
    model = get_sentence_transformer(model_name)
    
    # Generate embedding
    embedding = model.encode(text, normalize_embeddings=True)
    
    # Convert numpy array to list of floats
    return embedding.tolist()


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

