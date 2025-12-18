#!/usr/bin/env python3
"""Comprehensive test suite for RAG system with FAQ and non-FAQ questions"""

import sys
sys.path.insert(0, 'scripts')
from run_query import query_rag

# Comprehensive test questions covering various scenarios
test_questions = [
    ("Medical insurance", "What is the tax benefit on medical insurance premiums?"),
    ("ELSS vs PPF", "Which is better for tax saving - ELSS or PPF?"),
    ("PAN Aadhaar", "Is it mandatory to link PAN with Aadhaar?"),
    ("Property sale tax", "What is tax on sale of property?"),
    ("Inherited property", "Is tax payable on inherited property?"),
    ("GST composition", "Who can opt for GST composition scheme?"),
]

print("=" * 100)
print("🧪 COMPREHENSIVE TEST SUITE")
print("=" * 100)
print(f"\nTesting {len(test_questions)} questions\n")

results = {
    'total': 0,
    'excellent': 0,
    'good': 0,
    'fair': 0,
    'poor': 0,
    'with_sources': 0,
    'complete': 0,
    'errors': 0
}

for i, (category, question) in enumerate(test_questions, 1):
    print(f"Test {i}/{len(test_questions)}: {category}")
    
    try:
        answer = query_rag(question, top_k=6)
        
        chars = len(answer)
        has_sources = '📚' in answer
        answer_text = answer.split('\n📚')[0] if has_sources else answer
        complete = answer_text and not answer_text.endswith('**') and answer_text.strip()[-1] in '.!?'
        
        cautious = any(phrase in answer.lower() for phrase in ['i can\'t', 'i cannot', 'i don\'t have'])
        
        if complete and not cautious and chars >= 200:
            quality = "✅ EXCELLENT"
            results['excellent'] += 1
        elif complete and not cautious:
            quality = "✓ GOOD"
            results['good'] += 1
        elif chars >= 150:
            quality = "⚠️ FAIR"
            results['fair'] += 1
        else:
            quality = "❌ POOR"
            results['poor'] += 1
        
        results['total'] += 1
        if has_sources:
            results['with_sources'] += 1
        if complete:
            results['complete'] += 1
        
        print(f"  {quality} | {chars} chars | Sources: {'Yes' if has_sources else 'No'}")
        
    except Exception as e:
        print(f"  ❌ ERROR: {str(e)[:50]}")
        results['errors'] += 1
        results['total'] += 1

print("\n" + "=" * 100)
print("📊 RESULTS")
print("=" * 100)
print(f"✅ Excellent: {results['excellent']}/6")
print(f"✓ Good: {results['good']}/6")
print(f"⚠️ Fair: {results['fair']}/6")
print(f"❌ Poor/Errors: {results['poor'] + results['errors']}/6")
print(f"Complete answers: {results['complete']}/6")
print(f"With sources: {results['with_sources']}/6")

success_rate = (results['excellent'] + results['good']) / results['total'] * 100 if results['total'] > 0 else 0
print(f"\n🎯 SUCCESS RATE: {success_rate:.1f}%")
print("=" * 100)
