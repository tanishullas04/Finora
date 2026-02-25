import os
from typing import Dict, List

import pdfplumber


def extract_text_from_pdf(pdf_path: str) -> str:
    """Extract raw text from a PDF file using pdfplumber."""
    text_parts: List[str] = []
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            page_text = page.extract_text() or ""
            text_parts.append(page_text)
    return "\n".join(text_parts)


def load_all_pdfs(raw_pdfs_dir: str) -> Dict[str, str]:
    """
    Load all PDFs in a folder and return a mapping:
    {
        "income_tax_act_2025": "<full text>",
        "gst_9_2025": "<full text>",
        ...
    }
    The keys are logical names used later in routing.
    """
    mapping: Dict[str, str] = {}

    filename_map = {
        "Income_Tax_Act_2025.pdf": "income_tax_act_2025",
        "gst_notification_9_2025_rates.pdf": "gst_9_2025",
        "gst-ct-18-2025.pdf": "gst_ct_18_2025",
        "hscodewiselistwithgstrates.pdf": "gst_hsn_rates",
        "14- stcg.pdf": "stcg",
        "15- ltcg.pdf": "ltcg",
        "80.deductions-or-allowances-allowed-to-salaried-employee.pdf": "deductions",
        "presumptive-taxation-english.pdf": "presumptive",
    }

    for fname in os.listdir(raw_pdfs_dir):
        if not fname.lower().endswith(".pdf"):
            continue
        fpath = os.path.join(raw_pdfs_dir, fname)
        key = filename_map.get(fname, os.path.splitext(fname)[0])
        print(f"[pdf_reader] Extracting {fname} → key='{key}'")
        text = extract_text_from_pdf(fpath)
        mapping[key] = text

    return mapping
