#!/usr/bin/env python3
"""
Large comprehensive test suite with 100+ FAQ and non-FAQ questions
Tests various aspects of the RAG system at scale
"""

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / 'scripts'))

from run_query import query_rag

# Comprehensive test questions: 50 FAQ, 50 Non-FAQ
TEST_QUESTIONS = [
    # === FAQ QUESTIONS (50) ===
    ("What is section 80C?", "FAQ", "income_tax"),
    ("What is section 80D?", "FAQ", "income_tax"),
    ("What is section 80E?", "FAQ", "income_tax"),
    ("What is section 80G?", "FAQ", "income_tax"),
    ("What is section 80U?", "FAQ", "income_tax"),
    ("What is section 80DD?", "FAQ", "income_tax"),
    ("What is section 80DDB?", "FAQ", "income_tax"),
    ("What is TDS?", "FAQ", "income_tax"),
    ("What is ITR?", "FAQ", "income_tax"),
    ("What is Form 16?", "FAQ", "income_tax"),
    ("What is PAN?", "FAQ", "income_tax"),
    ("What is Aadhaar?", "FAQ", "income_tax"),
    ("What is HRA exemption?", "FAQ", "income_tax"),
    ("What is standard deduction?", "FAQ", "income_tax"),
    ("What is LTA?", "FAQ", "income_tax"),
    ("What is ELSS?", "FAQ", "income_tax"),
    ("What is PPF?", "FAQ", "income_tax"),
    ("What is NSC?", "FAQ", "income_tax"),
    ("What is FD interest?", "FAQ", "income_tax"),
    ("What is LTCG?", "FAQ", "capital_gains"),
    ("What is STCG?", "FAQ", "capital_gains"),
    ("What is cost of acquisition?", "FAQ", "capital_gains"),
    ("What is indexation benefit?", "FAQ", "capital_gains"),
    ("What is transfer of property?", "FAQ", "capital_gains"),
    ("What is GST?", "FAQ", "gst"),
    ("What is CGST?", "FAQ", "gst"),
    ("What is SGST?", "FAQ", "gst"),
    ("What is IGST?", "FAQ", "gst"),
    ("What is HSN code?", "FAQ", "gst"),
    ("What is SAC code?", "FAQ", "gst"),
    ("What is GST registration?", "FAQ", "gst"),
    ("What is GSTR-1?", "FAQ", "gst"),
    ("What is GSTR-3B?", "FAQ", "gst"),
    ("What is input credit?", "FAQ", "gst"),
    ("What is reverse charge?", "FAQ", "gst"),
    ("What is advance tax?", "FAQ", "income_tax"),
    ("What is self-assessment tax?", "FAQ", "income_tax"),
    ("What is income tax slab?", "FAQ", "income_tax"),
    ("What is tax bracket?", "FAQ", "income_tax"),
    ("What is surcharge?", "FAQ", "income_tax"),
    ("What is cess?", "FAQ", "income_tax"),
    ("What is rebate?", "FAQ", "income_tax"),
    ("What is assessment?", "FAQ", "income_tax"),
    ("What is audit?", "FAQ", "income_tax"),
    ("What is compliance?", "FAQ", "income_tax"),
    ("What is presumptive income?", "FAQ", "income_tax"),
    ("What is business deduction?", "FAQ", "deductions"),
    ("What is depreciation?", "FAQ", "deductions"),
    ("What is professional fees?", "FAQ", "deductions"),
    ("What is rent deduction?", "FAQ", "deductions"),
    
    # === NON-FAQ QUESTIONS (50) ===
    ("How is HRA income taxed in my case?", "Non-FAQ", "income_tax"),
    ("What is the tax implication of selling my house?", "Non-FAQ", "capital_gains"),
    ("How much capital gains tax do I owe on my mutual fund investments?", "Non-FAQ", "capital_gains"),
    ("I received a bonus. How is this taxed?", "Non-FAQ", "income_tax"),
    ("What are the deductions available for a freelancer?", "Non-FAQ", "deductions"),
    ("How do I calculate my taxable income as a salaried employee?", "Non-FAQ", "income_tax"),
    ("Are there any tax breaks for home loan interest payments?", "Non-FAQ", "deductions"),
    ("How is interest income from FDs taxed?", "Non-FAQ", "income_tax"),
    ("What's the tax treatment of dividend income?", "Non-FAQ", "income_tax"),
    ("Can I claim deduction for medical insurance premiums?", "Non-FAQ", "deductions"),
    ("How do I file GST returns for my business?", "Non-FAQ", "gst"),
    ("What GST rate applies to my product?", "Non-FAQ", "gst"),
    ("Am I eligible for input credit on my GST purchases?", "Non-FAQ", "gst"),
    ("How do I calculate LTCG tax on stock sales?", "Non-FAQ", "capital_gains"),
    ("What happens if I miss the income tax filing deadline?", "Non-FAQ", "compliance"),
    ("How much tax will I save with section 80C investments?", "Non-FAQ", "deductions"),
    ("Is my rental income taxable and how much?", "Non-FAQ", "income_tax"),
    ("What's the tax impact of taking a home loan?", "Non-FAQ", "deductions"),
    ("How do I report cryptocurrency gains in my taxes?", "Non-FAQ", "capital_gains"),
    ("Can I claim losses from one investment against another?", "Non-FAQ", "capital_gains"),
    ("What's the difference between ELSS and PPF for tax saving?", "Non-FAQ", "deductions"),
    ("How is capital appreciation in real estate taxed?", "Non-FAQ", "capital_gains"),
    ("What tax documents do I need to file my ITR?", "Non-FAQ", "compliance"),
    ("How does TDS impact my overall tax liability?", "Non-FAQ", "income_tax"),
    ("Am I required to file ITR if my income is below slab?", "Non-FAQ", "compliance"),
    ("What's the tax treatment of inherited property?", "Non-FAQ", "capital_gains"),
    ("How do I claim deduction for higher education fees?", "Non-FAQ", "deductions"),
    ("What are the consequences of non-compliance with GST?", "Non-FAQ", "gst"),
    ("How much tax will I pay on my business profits?", "Non-FAQ", "income_tax"),
    ("Can I reduce my tax by claiming all possible deductions?", "Non-FAQ", "deductions"),
    ("What's the GST compliance requirement for small businesses?", "Non-FAQ", "gst"),
    ("How do I calculate depreciation on business assets?", "Non-FAQ", "deductions"),
    ("Is life insurance premium eligible for deduction?", "Non-FAQ", "deductions"),
    ("What tax exemptions apply to NRI income?", "Non-FAQ", "income_tax"),
    ("How is bonus received on insurance policies taxed?", "Non-FAQ", "income_tax"),
    ("What's the tax rate for capital gains on jewelry?", "Non-FAQ", "capital_gains"),
    ("Can I claim deduction for professional development expenses?", "Non-FAQ", "deductions"),
    ("How much advance tax should I pay quarterly?", "Non-FAQ", "income_tax"),
    ("What are the GST implications for e-commerce sellers?", "Non-FAQ", "gst"),
    ("How do I structure my finances to minimize taxes?", "Non-FAQ", "compliance"),
    ("What's the tax treatment of employee stock options?", "Non-FAQ", "capital_gains"),
    ("Can I claim home office expenses as deduction?", "Non-FAQ", "deductions"),
    ("How is commission income taxed?", "Non-FAQ", "income_tax"),
    ("What's the penalty for late GST filing?", "Non-FAQ", "gst"),
    ("How do I claim section 80CCD deduction?", "Non-FAQ", "deductions"),
    ("What tax implications come with gift money?", "Non-FAQ", "income_tax"),
    ("How is agricultural income taxed?", "Non-FAQ", "income_tax"),
    ("Can I carry forward losses to next year?", "Non-FAQ", "capital_gains"),
    ("What's the tax treatment of foreign income for Indian residents?", "Non-FAQ", "income_tax"),
]

def evaluate_answer(answer: str, question_type: str) -> tuple:
    """
    Evaluate answer quality.
    Returns (is_excellent, is_good, has_sources, is_rejected)
    """
    is_empty = len(answer.strip()) == 0
    is_short_rejection = 50 < len(answer) < 300 and ("could not find" in answer.lower() or "unfortunately" in answer.lower() or "unclear" in answer.lower())
    is_long_answer = len(answer) > 300
    has_sources = "📚" in answer or "Sources:" in answer
    
    if question_type == "FAQ":
        # FAQ should always have answers
        if is_short_rejection or is_empty:
            return (False, False, False, True)  # Poor - rejected when shouldn't
        if is_long_answer and has_sources:
            return (True, False, has_sources, False)  # Excellent
        if is_long_answer:
            return (False, True, has_sources, False)  # Good - has answer but missing sources
        return (False, False, has_sources, False)  # Fair - short answer
    else:
        # Non-FAQ can be rejected or answered
        if is_short_rejection:
            return (False, False, False, True)  # Good - properly rejected
        if is_long_answer and has_sources:
            return (True, False, has_sources, False)  # Excellent
        if is_long_answer:
            return (False, True, has_sources, False)  # Good - has answer but missing sources
        return (False, False, has_sources, False)  # Fair

def run_tests():
    """Run all tests and collect results"""
    print("\n" + "="*80)
    print("🚀 LARGE COMPREHENSIVE TEST SUITE - Starting")
    print("="*80)
    print(f"Total Questions: {len(TEST_QUESTIONS)}")
    print(f"Test Distribution: 50 FAQ, 50 Non-FAQ")
    print("="*80 + "\n")
    
    results = {
        "excellent": 0,
        "good": 0,
        "fair": 0,
        "poor": 0,
        "by_type": {"FAQ": {"excellent": 0, "good": 0, "fair": 0, "poor": 0, "rejected": 0},
                    "Non-FAQ": {"excellent": 0, "good": 0, "fair": 0, "poor": 0, "rejected": 0}},
        "by_category": {},
        "total_with_sources": 0,
        "answers": []
    }
    
    start_time = time.time()
    
    for idx, (question, q_type, category) in enumerate(TEST_QUESTIONS, 1):
        try:
            print(f"[{idx:3d}/100] Testing {q_type:8} | {category:15} | {question[:60]:<60}", end=" ")
            
            answer = query_rag(question)
            is_excellent, is_good, has_sources, is_rejected = evaluate_answer(answer, q_type)
            
            # Categorize
            if is_excellent:
                results["excellent"] += 1
                results["by_type"][q_type]["excellent"] += 1
                status = "✅ EXCELLENT"
            elif is_good:
                results["good"] += 1
                results["by_type"][q_type]["good"] += 1
                status = "✓ GOOD"
            elif is_rejected:
                results["poor"] += 1
                results["by_type"][q_type]["rejected"] += 1
                status = "⚠️ REJECTED"
            else:
                results["fair"] += 1
                results["by_type"][q_type]["fair"] += 1
                status = "~ FAIR"
            
            if has_sources:
                results["total_with_sources"] += 1
            
            # Track by category
            if category not in results["by_category"]:
                results["by_category"][category] = {"excellent": 0, "good": 0, "fair": 0, "poor": 0}
            
            if is_excellent:
                results["by_category"][category]["excellent"] += 1
            elif is_good:
                results["by_category"][category]["good"] += 1
            elif is_rejected:
                results["by_category"][category]["poor"] += 1
            else:
                results["by_category"][category]["fair"] += 1
            
            results["answers"].append({
                "question": question,
                "type": q_type,
                "category": category,
                "length": len(answer),
                "has_sources": has_sources,
                "status": status
            })
            
            print(status)
            
        except Exception as e:
            print(f"❌ ERROR: {str(e)[:40]}")
            results["poor"] += 1
            results["by_type"][q_type]["poor"] += 1
    
    elapsed_time = time.time() - start_time
    
    # Print summary
    print("\n" + "="*80)
    print("📊 TEST RESULTS SUMMARY")
    print("="*80)
    
    total = results["excellent"] + results["good"] + results["fair"] + results["poor"]
    success_rate = ((results["excellent"] + results["good"]) / total * 100) if total > 0 else 0
    
    print(f"\n📈 Overall Statistics:")
    print(f"  Total Questions: {total}")
    print(f"  ✅ Excellent: {results['excellent']}/{total} ({results['excellent']/total*100:.1f}%)")
    print(f"  ✓ Good:      {results['good']}/{total} ({results['good']/total*100:.1f}%)")
    print(f"  ~ Fair:      {results['fair']}/{total} ({results['fair']/total*100:.1f}%)")
    print(f"  ❌ Poor:      {results['poor']}/{total} ({results['poor']/total*100:.1f}%)")
    print(f"\n  🎯 Overall Success Rate: {success_rate:.1f}%")
    print(f"  📚 With Sources: {results['total_with_sources']}/{total} ({results['total_with_sources']/total*100:.1f}%)")
    print(f"  ⏱️ Time Elapsed: {elapsed_time:.1f} seconds ({elapsed_time/total:.2f}s per question)")
    
    print(f"\n📋 By Question Type:")
    for q_type in ["FAQ", "Non-FAQ"]:
        stats = results["by_type"][q_type]
        type_total = sum(stats.values())
        type_success = ((stats["excellent"] + stats["good"]) / type_total * 100) if type_total > 0 else 0
        print(f"\n  {q_type}:")
        print(f"    ✅ Excellent: {stats['excellent']}/{type_total}")
        print(f"    ✓ Good:      {stats['good']}/{type_total}")
        print(f"    ~ Fair:      {stats['fair']}/{type_total}")
        print(f"    ❌ Poor/Rejected: {stats['poor'] + stats.get('rejected', 0)}/{type_total}")
        print(f"    Success Rate: {type_success:.1f}%")
    
    print(f"\n🏷️ By Category:")
    for category, stats in sorted(results["by_category"].items()):
        cat_total = sum(stats.values())
        cat_success = ((stats["excellent"] + stats["good"]) / cat_total * 100) if cat_total > 0 else 0
        print(f"  {category:20} | E:{stats['excellent']} G:{stats['good']} F:{stats['fair']} P:{stats['poor']} | {cat_success:.0f}%")
    
    print("\n" + "="*80)
    print("✅ TEST COMPLETE!")
    print("="*80 + "\n")
    
    return results

if __name__ == "__main__":
    results = run_tests()
