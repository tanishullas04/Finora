"""
Query router — determines which indices to search based on keywords.
"""
from typing import List


def route_query(query: str) -> List[str]:
    query_lower = query.lower()
    indices = []

    # ── Capital gains ─────────────────────────────────────────────
    capital_gains_keywords = [
        'capital gain', 'stcg', 'ltcg', 'short term capital', 'long term capital',
        'capital asset', 'sale of property', 'sale of shares', 'equity', 'stock sale',
        '111a', '112a', 'section 111a', 'section 112a',
    ]
    if any(kw in query_lower for kw in capital_gains_keywords):
        indices.append('capital_gains_index')

    # ── Deductions ────────────────────────────────────────────────
    deductions_keywords = [
        'deduction', 'allowance', 'section 80', 'exempt', 'rebate', 'save tax',
        '80c', '80d', '80e', '80g', '80gg', '80u', '80dd', '80ddb', '80tta', '80ttb',
        'chapter vi', 'chapter via',
        # HRA and home loan content lives in deductions_index
        'hra', 'house rent allowance', 'rent exemption',
        'home loan', 'housing loan', 'section 24',
    ]
    if any(kw in query_lower for kw in deductions_keywords):
        indices.append('deductions_index')

    # ── Presumptive taxation ──────────────────────────────────────
    presumptive_keywords = [
        'presumptive', 'section 44', '44ad', '44ae', '44ada',
        'small business', 'turnover',
        'professional income', 'business income',
    ]
    if any(kw in query_lower for kw in presumptive_keywords):
        indices.append('presumptive_index')

    # ── GST ───────────────────────────────────────────────────────
    gst_keywords = [
        'gst', 'goods and services tax', 'igst', 'cgst', 'sgst',
        'input tax credit', 'hsn', 'itc',
        'gst registration', 'reverse charge', 'rcm',
    ]
    if any(kw in query_lower for kw in gst_keywords):
        indices.append('gst_index')

    # ── Income tax (general + specific topics in this index) ──────
    income_tax_keywords = [
        'income tax', 'itr', 'filing', 'return',
        'house property', 'annual value', 'let out', 'self occupied',
        'salary', 'perquisite', 'taxable income',
        'assessment year', 'previous year', 'financial year',
        'tds', 'tax deducted at source', 'advance tax',
        'freelancer', 'free lancer', 'self employed',
        'surcharge', 'cess',
    ]
    if any(kw in query_lower for kw in income_tax_keywords):
        indices.append('income_tax_index')

    # ── Fallback ──────────────────────────────────────────────────
    if not indices:
        indices.append('income_tax_index')

    return list(dict.fromkeys(indices))