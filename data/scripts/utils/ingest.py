import os
from pathlib import Path

from pdf_reader import load_all_pdfs
from chunker import chunk_text
from embedder import save_chunks_to_jsonl, build_embeddings_for_chunks


PROJECT_ROOT = Path(__file__).resolve().parents[2]
RAW_PDFS_DIR = PROJECT_ROOT / "raw_pdfs"
PROCESSED_DIR = PROJECT_ROOT / "processed_text"
EMBEDDINGS_DIR = PROJECT_ROOT / "embeddings"


# Map logical source names → which index they belong to
INDEX_ROUTING = {
    "income_tax_act_2025": "income_tax_index",
    "gst_9_2025": "gst_index",
    "gst_ct_18_2025": "gst_index",
    "gst_hsn_rates": "gst_index",
    "stcg": "capital_gains_index",
    "ltcg": "capital_gains_index",
    "deductions": "deductions_index",
    "presumptive": "presumptive_index",
}


def process_single_source(source_name: str, text: str) -> None:
    """Extract chunks, save them, then embed + index."""
    print(f"\n[ingest] Processing source: {source_name}")

    # 1) Chunk
    chunks = chunk_text(
        text,
        chunk_size=1200,
        chunk_overlap=200,
        source_name=source_name,
    )

    # 2) Save raw chunks
    out_jsonl = PROCESSED_DIR / f"{source_name}_chunks.jsonl"
    save_chunks_to_jsonl(chunks, str(out_jsonl))

    # 3) Find which index to store in
    index_name = INDEX_ROUTING.get(source_name, "custom_index")
    build_embeddings_for_chunks(
        chunks,
        index_dir=str(EMBEDDINGS_DIR),
        index_name=index_name,
        use_fake=False,  # Using real HuggingFace embeddings
    )


def main():
    print(f"[ingest] Project root: {PROJECT_ROOT}")
    print(f"[ingest] Raw PDFs: {RAW_PDFS_DIR}")

    pdf_texts = load_all_pdfs(str(RAW_PDFS_DIR))

    if not pdf_texts:
        print("[ingest] No PDFs found. Check data/raw_pdfs.")
        return

    for source_name, text in pdf_texts.items():
        if not text.strip():
            print(f"[ingest] WARNING: No text extracted from {source_name}, skipping.")
            continue
        process_single_source(source_name, text)

    print("\n[ingest] ✅ Finished processing all PDFs.")


if __name__ == "__main__":
    main()
