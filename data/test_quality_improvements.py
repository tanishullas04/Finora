#!/usr/bin/env python3
"""Test the quality improvements on previously problematic queries"""

import sys
sys.path.insert(0, 'scripts')
from run_query import query_rag

# Queries that previously had issues
problematic_queries = [
    ('Medical insurance tax benefit', 'tax benefit on medical insurance', 'Was: 143 chars, overly cautious'),
    ('ELSS vs PPF', 'which is better for tax saving - ELSS or PPF?', 'Was: 75 chars, too brief'),
    ('PAN Aadhaar linking', 'is it mandatory to link PAN with Aadhaar?', 'Was: 172 chars, incomplete'),
    ('Property sale tax', 'what is tax on sale of property?', 'Was: 165 chars, cut off'),
    ('Inherited property tax', 'is tax payable on inherited property?', 'Was: 178 chars, incomplete'),
    ('GST composition scheme', 'who can opt for GST composition scheme?', 'Was: 265 chars, could be better'),
]

print("=" * 100)
print("🔧 TESTING QUALITY IMPROVEMENTS")
print("=" * 100)
print()

results = []

for i, (label, query, previous_issue) in enumerate(problematic_queries, 1):
    print(f"\n{'='*100}")
    print(f"Test {i}/{len(problematic_queries)}: {label}")
    print(f"Previous issue: {previous_issue}")
    print('='*100)
    print(f"Q: {query}")
    print('-'*100)
    
    answer = query_rag(query, top_k=6)
    
    chars = len(answer)
    words = len(answer.split())
    has_sources = '📚' in answer
    
    # Check completeness on answer text only (before sources)
    answer_text = answer.split('\n📚')[0] if has_sources else answer
    complete = answer_text and not answer_text.endswith('**') and answer_text.strip()[-1] in '.!?'
    
    # Quality assessment - focus on completeness & directness, not just length
    cautious_phrases = ['i can\'t provide', 'i cannot provide', 'i\'m not able to']
    is_cautious = any(phrase in answer.lower() for phrase in cautious_phrases)
    
    if complete and not is_cautious:
        quality = "✅ EXCELLENT"  # Complete, direct answer (any length)
    elif complete and is_cautious:
        quality = "✓ GOOD"  # Complete but with disclaimers
    elif chars >= 150 and not is_cautious:
        quality = "⚠️ FAIR"  # Decent length but incomplete
    else:
        quality = "❌ POOR"  # Too short or overly cautious
    
    results.append({
        'label': label,
        'chars': chars,
        'words': words,
        'complete': complete,
        'has_sources': has_sources,
        'quality': quality
    })
    
    print(f"\n{quality}")
    print(f"Length: {chars} chars ({words} words)")
    print(f"Complete: {'Yes' if complete else 'No'}")
    print(f"Sources: {'Yes' if has_sources else 'No'}")
    print(f"\nAnswer preview (first 400 chars):")
    print(answer[:400] + "..." if len(answer) > 400 else answer)

# Summary
print("\n" + "=" * 100)
print("📊 IMPROVEMENT SUMMARY")
print("=" * 100)

excellent = sum(1 for r in results if '✅' in r['quality'])
good = sum(1 for r in results if '✓' in r['quality'])
fair = sum(1 for r in results if '⚠️' in r['quality'])
poor = sum(1 for r in results if '❌' in r['quality'])

print(f"\nQuality Distribution:")
print(f"  ✅ Excellent (complete & direct): {excellent}/{len(results)}")
print(f"  ✓ Good (complete but cautious): {good}/{len(results)}")
print(f"  ⚠️ Fair (incomplete but decent): {fair}/{len(results)}")
print(f"  ❌ Poor (too short/cautious): {poor}/{len(results)}")

avg_length = sum(r['chars'] for r in results) / len(results)
complete_count = sum(1 for r in results if r['complete'])
sources_count = sum(1 for r in results if r['has_sources'])

print(f"\nOverall Metrics:")
print(f"  Average length: {avg_length:.0f} chars")
print(f"  Complete answers: {complete_count}/{len(results)} ({complete_count*100//len(results)}%)")
print(f"  With sources: {sources_count}/{len(results)} ({sources_count*100//len(results)}%)")

improvement_rate = (excellent + good) * 100 // len(results)
print(f"\n🎯 SUCCESS RATE: {improvement_rate}% (excellent + good)")

print("\n" + "=" * 100)
print("✅ TEST COMPLETE!")
print("=" * 100)
