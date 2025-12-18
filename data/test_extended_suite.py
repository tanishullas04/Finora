#!/usr/bin/env python3
"""Extended comprehensive test suite with 50+ FAQ and non-FAQ questions"""

import sys
sys.path.insert(0, 'scripts')
from run_query import query_rag

# Extended test questions - covering all tax topics
test_questions = [
    # FAQ Questions (pre-curated answers)
    ("FAQ - 80C Limit", "What is the maximum deduction under section 80C?", "faq"),
    ("FAQ - Tax Regime", "What is the difference between old and new tax regime?", "faq"),
    ("FAQ - GST Registration", "What is the GST registration threshold?", "faq"),
    ("FAQ - ITR Filing", "What is the last date to file income tax return?", "faq"),
    ("FAQ - Tax Audit", "When is tax audit required?", "faq"),
    ("FAQ - STCG Rate", "What is the tax rate on short term capital gains?", "faq"),
    ("FAQ - 80CCD NPS", "What is the deduction limit for NPS contribution?", "faq"),
    ("FAQ - HRA Exemption", "How is HRA exemption calculated?", "faq"),
    ("FAQ - GST ITC", "What is input tax credit in GST?", "faq"),
    ("FAQ - TDS", "What is tax deducted at source?", "faq"),
    
    # Non-FAQ Income Tax Questions (detailed)
    ("Income Tax - Salary", "How is salary income taxed in India?", "non-faq"),
    ("Income Tax - Deductions", "What is the tax benefit on medical insurance premiums under 80D?", "non-faq"),
    ("Income Tax - House Property", "What deductions are available for house property?", "non-faq"),
    ("Income Tax - Business", "What are the tax implications for self-employed individuals?", "non-faq"),
    ("Income Tax - Interest", "How is interest income taxed?", "non-faq"),
    ("Income Tax - Dividend", "What is the tax treatment of dividend income?", "non-faq"),
    ("Income Tax - Rental", "How is rental income from property taxed?", "non-faq"),
    ("Income Tax - Profession", "How is income from profession taxed?", "non-faq"),
    
    # Non-FAQ Capital Gains Questions
    ("LTCG - Property", "What is the tax on sale of property held for 3 years?", "non-faq"),
    ("STCG - Shares", "How is short term capital gain on shares taxed?", "non-faq"),
    ("LTCG - Indexation", "What is indexation benefit in calculating long term capital gains?", "non-faq"),
    ("Inherited Property", "Is tax payable on inherited property?", "non-faq"),
    ("Gift Tax", "What is the tax treatment of gifts received?", "non-faq"),
    ("LTCG - Equity", "What is the tax rate on long term capital gains on equity shares?", "non-faq"),
    
    # Non-FAQ GST Questions
    ("GST - Composition", "Who can opt for GST composition scheme and what are the benefits?", "non-faq"),
    ("GST - Returns", "What GST returns need to be filed and when?", "non-faq"),
    ("GST - ITC Blocked", "Which items have blocked input tax credit under GST?", "non-faq"),
    ("GST - E-commerce", "How is GST applicable on e-commerce transactions?", "non-faq"),
    ("GST - Reverse Charge", "What is reverse charge mechanism under GST?", "non-faq"),
    ("GST - Cross Border", "How is GST applicable on goods purchased from outside India?", "non-faq"),
    ("GST - Services", "What are the GST rates for different services?", "non-faq"),
    
    # Non-FAQ Deduction Questions
    ("80C - Investments", "Which investments are eligible under section 80C?", "non-faq"),
    ("80D - Health", "What is the deduction limit for health insurance under 80D?", "non-faq"),
    ("80E - Education", "What is the deduction for education loan interest under 80E?", "non-faq"),
    ("80G - Charity", "How do I claim deduction for charitable donations under 80G?", "non-faq"),
    ("ELSS vs PPF", "Which is better for tax saving - ELSS mutual funds or PPF?", "non-faq"),
    ("80CCD(1B)", "What is the additional NPS deduction under section 80CCD(1B)?", "non-faq"),
    
    # Non-FAQ Compliance Questions
    ("PAN - Aadhaar", "Is it mandatory to link PAN with Aadhaar?", "non-faq"),
    ("PAN - NEFT", "Is PAN mandatory for NEFT transfers?", "non-faq"),
    ("TDS - Salary", "How is TDS calculated on salary?", "non-faq"),
    ("Advance Tax", "Who needs to pay advance tax and how is it calculated?", "non-faq"),
    ("Tax Loss", "How do I adjust losses from one financial year to another?", "non-faq"),
    ("Presumptive Income", "Who is eligible for presumptive taxation?", "non-faq"),
    ("Form 16", "What information is included in Form 16?", "non-faq"),
    
    # Edge Cases and Complex Queries
    ("Complex - Multiple Income", "How is tax calculated when I have multiple sources of income?", "non-faq"),
    ("Complex - Loss Adjustment", "Can I claim losses from business against other income?", "non-faq"),
    ("Complex - Regime Change", "What happens if I switch from old to new tax regime mid-year?", "non-faq"),
    ("Complex - Surcharge", "When is surcharge applicable and how is it calculated?", "non-faq"),
    ("Complex - Cess", "What is health and education cess and when is it applicable?", "non-faq"),
    
    # Off-topic queries (should be rejected)
    ("Off-topic - Greeting", "How are you doing?", "off-topic"),
    ("Off-topic - Weather", "What is the weather like today?", "off-topic"),
    ("Off-topic - Sports", "Who won the cricket match?", "off-topic"),
    ("Off-topic - Random", "Tell me a joke", "off-topic"),
]

print("=" * 120)
print("🧪 EXTENDED COMPREHENSIVE TEST SUITE - 50+ QUESTIONS")
print("=" * 120)
print(f"\nTesting {len(test_questions)} questions across all categories\n")

results = {
    'total': 0,
    'excellent': 0,
    'good': 0,
    'fair': 0,
    'poor': 0,
    'with_sources': 0,
    'complete': 0,
    'errors': 0,
    'faq': 0,
    'non_faq': 0,
    'off_topic_correct': 0,
    'by_category': {},
    'issues': []
}

for i, (category, question, expected_type) in enumerate(test_questions, 1):
    print(f"[{i:2d}/{len(test_questions)}] {category:<30} ... ", end='', flush=True)
    
    try:
        answer = query_rag(question, top_k=6)
        
        # Analysis
        chars = len(answer)
        has_sources = '📚' in answer
        is_rejected = "I apologize, but I can only answer" in answer or "I couldn't find relevant" in answer
        answer_text = answer.split('\n📚')[0] if has_sources else answer
        complete = answer_text and not answer_text.endswith('**') and answer_text.strip()[-1] in '.!?'
        cautious = any(phrase in answer.lower() for phrase in ['i can\'t', 'i cannot', 'i don\'t have'])
        
        # Quality assessment
        if expected_type == "off-topic":
            if is_rejected:
                quality = "✅ CORRECT REJECTION"
                results['off_topic_correct'] += 1
            else:
                quality = "❌ SHOULD BE REJECTED"
                results['issues'].append(f"{category}: Off-topic query not rejected")
        else:
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
                results['issues'].append(f"{category}: Poor quality ({chars} chars)")
        
        results['total'] += 1
        if has_sources and expected_type != "off-topic":
            results['with_sources'] += 1
        if complete and expected_type != "off-topic":
            results['complete'] += 1
        
        if expected_type == "faq":
            results['faq'] += 1
        elif expected_type == "non-faq":
            results['non_faq'] += 1
        
        # Track by category
        category_base = category.split(' - ')[0]
        if category_base not in results['by_category']:
            results['by_category'][category_base] = {'total': 0, 'excellent': 0, 'good': 0, 'fair': 0, 'poor': 0}
        results['by_category'][category_base]['total'] += 1
        if 'EXCELLENT' in quality:
            results['by_category'][category_base]['excellent'] += 1
        elif 'GOOD' in quality or 'CORRECT' in quality:
            results['by_category'][category_base]['good'] += 1
        elif 'FAIR' in quality:
            results['by_category'][category_base]['fair'] += 1
        else:
            results['by_category'][category_base]['poor'] += 1
        
        print(quality)
        
    except Exception as e:
        print(f"❌ ERROR: {str(e)[:40]}")
        results['errors'] += 1
        results['total'] += 1
        results['issues'].append(f"{category}: Exception - {str(e)[:50]}")

# Print detailed summary
print("\n" + "=" * 120)
print("📊 DETAILED RESULTS SUMMARY")
print("=" * 120)

print(f"\nOverall Statistics:")
print(f"  Total Questions: {results['total']}")
print(f"  ✅ Excellent: {results['excellent']}/{results['total']} ({results['excellent']/results['total']*100:.1f}%)")
print(f"  ✓ Good: {results['good']}/{results['total']} ({results['good']/results['total']*100:.1f}%)")
print(f"  ⚠️ Fair: {results['fair']}/{results['total']} ({results['fair']/results['total']*100:.1f}%)")
print(f"  ❌ Poor/Errors: {results['poor'] + results['errors']}/{results['total']} ({(results['poor'] + results['errors'])/results['total']*100:.1f}%)")

print(f"\nQuery Type Distribution:")
print(f"  FAQ Questions: {results['faq']}")
print(f"  Non-FAQ Questions: {results['non_faq']}")
print(f"  Off-Topic Questions: {len(test_questions) - results['faq'] - results['non_faq']}")

print(f"\nOff-Topic Handling:")
print(f"  Correctly Rejected: {results['off_topic_correct']}/{len([q for q in test_questions if q[2] == 'off-topic'])}")

print(f"\nAnswer Quality:")
print(f"  Complete Answers: {results['complete']}/{results['non_faq']} non-FAQ ({results['complete']/results['non_faq']*100:.1f}%)")
print(f"  With Sources: {results['with_sources']}/{results['non_faq']} non-FAQ ({results['with_sources']/results['non_faq']*100:.1f}%)")

print(f"\nBy Category:")
for category, stats in sorted(results['by_category'].items()):
    success = (stats['excellent'] + stats['good']) / stats['total'] * 100
    print(f"  {category:<20} {stats['excellent']}/{stats['total']} excellent, {stats['good']}/{stats['total']} good ({success:.0f}% success)")

success_rate = (results['excellent'] + results['good']) / results['total'] * 100 if results['total'] > 0 else 0
print(f"\n🎯 OVERALL SUCCESS RATE: {success_rate:.1f}%")

if results['issues']:
    print(f"\n⚠️ ISSUES FOUND ({len(results['issues'])}):")
    for issue in results['issues'][:15]:
        print(f"  • {issue}")
    if len(results['issues']) > 15:
        print(f"  ... and {len(results['issues']) - 15} more")
else:
    print(f"\n✅ NO CRITICAL ISSUES FOUND!")

print("\n" + "=" * 120)
print("✅ TEST COMPLETE!")
print("=" * 120)
