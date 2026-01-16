import os
import json
from typing import List, Dict, Optional

EMBED_DIM = 384  # sentence-transformers/all-MiniLM-L6-v2 dimension

# Initialize the embedding model once (lazy loading)
_embedding_model = None

def get_embedding_model():
    """Lazy load the sentence transformer model."""
    global _embedding_model
    if _embedding_model is None:
        from sentence_transformers import SentenceTransformer
        print("[embedder] Loading embedding model (first time only)...")
        _embedding_model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')
        print("[embedder] Model loaded successfully")
    return _embedding_model


def embed_text(text: str, use_fake: bool = False) -> List[float]:
    """
    Embed a single text string using local sentence-transformers.
    
    Args:
        text: The text to embed
        use_fake: If True, return fake embeddings for testing
        
    Returns:
        A list of floats representing the embedding vector
    """
    if use_fake:
        return [0.0] * EMBED_DIM
    
    try:
        model = get_embedding_model()
        embedding = model.encode(text, convert_to_numpy=True)
        return embedding.tolist()
    except Exception as e:
        print(f"[embedder] Warning: Failed to generate embedding: {e}")
        print("[embedder] Falling back to fake embeddings")
        return [0.0] * EMBED_DIM


def load_vector_store(index_path: str) -> List[Dict]:
    """
    Load vectors from a JSONL index file.
    
    Args:
        index_path: Path to the index.jsonl file
        
    Returns:
        List of dictionaries containing id, text, metadata, and embedding
    """
    if not os.path.exists(index_path):
        raise FileNotFoundError(f"Index not found: {index_path}")
    
    entries = []
    with open(index_path, "r", encoding="utf-8") as f:
        for line in f:
            entries.append(json.loads(line))
    return entries


def save_chunks_to_jsonl(chunks: List[Dict], out_path: str) -> None:
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        for ch in chunks:
            f.write(json.dumps(ch, ensure_ascii=False) + "\n")
    print(f"[embedder] Saved {len(chunks)} chunks → {out_path}")


def fake_embed(texts: List[str]) -> List[List[float]]:
    """
    TEMP: Fake embeddings so you can test the pipeline
    without hitting a real embedding API.
    Replace with real model call later.
    """
    return [[0.0] * EMBED_DIM for _ in texts]


def build_embeddings_for_chunks(
    chunks: List[Dict],
    index_dir: str,
    index_name: str,
    use_fake: bool = False,
    model: Optional[str] = None,
) -> None:
    """
    Create embeddings for each chunk and save to a simple JSONL index.
    Uses Hugging Face for real embeddings by default.
    """
    os.makedirs(os.path.join(index_dir, index_name), exist_ok=True)
    index_path = os.path.join(index_dir, index_name, "index.jsonl")

    print(f"[embedder] Generating embeddings for {len(chunks)} chunks...")
    
    vectors = []
    for i, chunk in enumerate(chunks):
        if (i + 1) % 10 == 0:
            print(f"[embedder] Progress: {i + 1}/{len(chunks)} chunks embedded")
        vec = embed_text(chunk["text"], use_fake=use_fake)
        vectors.append(vec)

    with open(index_path, "w", encoding="utf-8") as f:
        for chunk, vec in zip(chunks, vectors):
            rec = {
                "id": chunk["id"],
                "text": chunk["text"],
                "metadata": chunk["metadata"],
                "embedding": vec,
            }
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")

    print(
        f"[embedder] Stored {len(chunks)} vectors to embeddings/{index_name}/index.jsonl"
    )
