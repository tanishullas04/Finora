from typing import List, Dict


def chunk_text(
    text: str,
    chunk_size: int = 1200,
    chunk_overlap: int = 200,
    source_name: str = "",
) -> List[Dict]:
    """
    Split long text into overlapping chunks.
    Returns list of:
    {
        "id": "<source_name_i>",
        "text": "...",
        "metadata": {...}
    }
    """
    words = text.split()
    chunks: List[Dict] = []
    start = 0
    idx = 0

    while start < len(words):
        end = start + chunk_size
        chunk_words = words[start:end]
        chunk_text_str = " ".join(chunk_words)

        chunks.append(
            {
                "id": f"{source_name}_{idx}",
                "text": chunk_text_str,
                "metadata": {
                    "source": source_name,
                    "chunk_index": idx,
                },
            }
        )
        idx += 1
        start = max(end - chunk_overlap, end)

    return chunks
