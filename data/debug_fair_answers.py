#!/usr/bin/env python3
"""
Debug script to investigate why answers are marked as FAIR instead of EXCELLENT
Tests a sample of questions and shows detailed answer characteristics
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / 'scripts'))

from run_query import query_rag

# Sample questions that showed FAIR classification
FAIR_QUESTIONS = [
    # FAQ questions marked FAIR
    "What is section 80C?",
    "What is TDS?",
    "What is PAN?",
    "What is GST?",
    "What is input credit?",
    "What is business deduction?",
    
    # Non-FAQ questions marked FAIR
    "How much capital gains tax do I owe on my mutual fund investments?",
    "What are the deductions available for a freelancer?",
    "How is interest income from FDs taxed?",
    "What's the tax treatment of dividend income?",
    "Can I claim deduction for medical insurance premiums?",
]

def analyze_answer(answer: str, question: str):
    """Detailed analysis of answer characteristics"""
    print(f"\n{'='*80}")
    print(f"Q: {question}")
    print(f"{'='*80}")
    print(f"Length: {len(answer)} chars")
    print(f"Words: {len(answer.split())}")
    print(f"Has sources (📚): {'Yes' if '📚' in answer else 'No'}")
    print(f"Has Sources text: {'Yes' if 'Sources:' in answer else 'No'}")
    
    # Check for quality indicators
    print(f"\nQuality Indicators:")
    print(f"  Ends with period: {answer.strip()[-1] == '.'}")
    print(f"  Ends with: '{answer.strip()[-20:]}'")
    
    cautious_phrases = ["i can't", "i cannot", "i'm not able", "don't have access"]
    has_cautious = any(p in answer.lower() for p in cautious_phrases)
    print(f"  Has cautious phrases: {has_cautious}")
    
    substantive = ['section ', '₹', '%', 'rs.', 'lakh', 'crore', 'rate', 'limit']
    has_substance = any(s in answer.lower() for s in substantive)
    print(f"  Has substantive content: {has_substance}")
    
    # Show preview
    if len(answer) > 300:
        print(f"\nPreview (first 300 chars):")
        print(f"  {answer[:300]}...")
    else:
        print(f"\nFull Answer:")
        print(f"  {answer}")

def main():
    print("\n" + "="*80)
    print("🔍 DEBUGGING FAIR vs EXCELLENT Classification")
    print("="*80)
    print(f"Testing {len(FAIR_QUESTIONS)} questions that were marked FAIR")
    print("="*80)
    
    for i, question in enumerate(FAIR_QUESTIONS, 1):
        try:
            print(f"\n[{i}/{len(FAIR_QUESTIONS)}]", end="")
            answer = query_rag(question)
            analyze_answer(answer, question)
        except Exception as e:
            print(f"ERROR: {str(e)[:100]}")
    
    print("\n" + "="*80)
    print("✅ ANALYSIS COMPLETE")
    print("="*80 + "\n")

if __name__ == "__main__":
    main()
