"""
Simple query router to determine which indices to search.
"""
from typing import List


def route_query(query: str) -> List[str]:
    """
    Route a query to the appropriate indices based on keywords.
    Can return multiple indices to search across.
    
    Args:
        query: The user's query string
        
    Returns:
        A list of index names to search
    """
    query_lower = query.lower()
    indices = []
    
    # Check for capital gains keywords
    capital_gains_keywords = ['capital gain', 'stcg', 'ltcg', 'short term capital', 'long term capital', 
                              'capital asset', 'sale of property', 'sale of shares', 'equity', 'stock sale',
                              '111a', '112a', 'section 111a', 'section 112a']
    if any(keyword in query_lower for keyword in capital_gains_keywords):
        indices.append('capital_gains_index')
    
    # Check for deductions keywords
    deductions_keywords = ['deduction', 'allowance', 'section 80', 'exempt', 'rebate', 'save tax',
                          '80c', '80d', '80e', '80g', '80gg', '80u', '80dd', '80ddb', '80tta', '80ttb',
                          'chapter vi', 'chapter via']
    if any(keyword in query_lower for keyword in deductions_keywords):
        indices.append('deductions_index')
    
    # Check for presumptive taxation keywords
    presumptive_keywords = ['presumptive', 'section 44', 'small business', 'turnover']
    if any(keyword in query_lower for keyword in presumptive_keywords):
        indices.append('presumptive_index')
    
    # Check for GST-related keywords
    gst_keywords = ['gst', 'goods and services tax', 'igst', 'cgst', 'sgst', 'input tax credit', 'hsn']
    if any(keyword in query_lower for keyword in gst_keywords):
        indices.append('gst_index')
    
    # Always include income_tax_index for general context
    if not indices or 'tax' in query_lower:
        indices.append('income_tax_index')
    
    # Remove duplicates while preserving order
    return list(dict.fromkeys(indices))