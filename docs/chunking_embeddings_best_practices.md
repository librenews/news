
# Best Practices for Chunking, Embedding & Relational Modeling

## 1. Chunking Strategy

### Goals of Chunking
- Preserve semantic coherence.
- Maintain chunk sizes appropriate for embedding models (typically 200–600 tokens).
- Ensure overlap to avoid semantic boundary loss.

### Recommended Method
1. Extract clean text (no scripts, boilerplate, nav).
2. Segment by semantic boundaries: paragraphs → sentences → sliding windows.
3. Use hybrid chunking:
   - Paragraph-level primary chunks.
   - If paragraphs are too long, split into ~300-token windows with 10–15% overlap.

### Why Overlap?
Overlap prevents losing context between chunks — especially in news where important facts span paragraphs.

### Metadata to Capture Per Chunk
- `chunk_id` (UUID)
- `article_id` (FK)
- `source_url`
- `chunk_index`
- `token_count`
- `embedding_vector` (vector/array)
- `checksum` (SHA-256 of text)

---

## 2. Embedding Best Practices

### Recommended Embedding Models
- **OpenAI text-embedding-3-large** for high-accuracy semantic search.
- Smaller models (e.g., text-embedding-3-small) for cost-sensitive bulk workloads.

### Storage & Retrieval
- Store embeddings in a vector-enabled column (Postgres + `pgvector`).
- Store dimensionality and embedding model version.

### Re-Embedding Strategy
Use an `embedding_version` column.  
Re-embed when:
- Text changes  
- Embedding model changes  
- Vector drift is observed  

---

## 3. Relational Database Modeling

### `articles`
```
id (PK)
url
title
author
published_at
raw_text
cleaned_text
checksum
```

### `article_chunks`
```
id (PK)
article_id (FK → articles.id)
chunk_index
text
embedding_vector (vector)
embedding_version
token_count
```

### Index Suggestions
- Vector index: `ivfflat` or `hnsw`
- Composite index: `(article_id, chunk_index)`

---

## 4. Named Entity Storage

### `entities`
```
id (PK)
name
type (PERSON, ORG, PLACE, EVENT)
normalized_name
external_reference (Wikidata QID, optional)
```

### `article_entities`
```
id (PK)
article_id (FK)
entity_id (FK)
frequency
sentence_positions (array)
confidence_score
```

### `entity_embeddings` (optional)
```
entity_id (FK)
embedding_vector
model_version
```

---

## 5. Full Pipeline Overview

1. Crawl or fetch article.  
2. Clean text (boilerplate + HTML removal).  
3. Chunk into semantic windows.  
4. Generate embeddings for each chunk.  
5. Store:
   - article  
   - chunks + embeddings  
   - named entities + relationships  
6. (Optional) Create entity-level embeddings for knowledge-graph reasoning.

---

## Summary

This document outlines:
- Best chunking practices  
- Embedding strategies  
- Proper relational modeling for articles, chunks, and entities  
- Integration of knowledge-graph-friendly structures  

Perfect for large-scale news, social content, or research-oriented embedding pipelines.
