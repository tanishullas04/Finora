#!/usr/bin/env python3
"""
Comprehensive Test Suite for Finora RAG System
Tests 50+ FAQ variations and 30+ non-FAQ queries
"""

import sys
import time
sys.path.insert(0, 'scripts')
from run_query import query_rag

# ==============================================================================
# FAQ TEST QUERIES (50+ variations)
# ==============================================================================

faq_test_queries = [
    # Tax Regime Questions
    ('New vs Old Regime', 'should I choose new tax regime or old tax regime?'),
    ('New Regime Slabs', 'what are the tax slabs in new regime?'),
    ('New Regime Rates 2025', 'income tax rates for FY 2025-26 new regime'),
    ('Rebate 87A', 'what is rebate under section 87A?'),
    ('12 lakh no tax', 'up to what income is tax free in new regime?'),
    
    # Old Regime
    ('Old Regime Slabs', 'what are income tax slabs in old regime?'),
    ('Old vs New comparison', 'difference between old and new tax regime'),
    
    # Section 80C variations
    ('Section 80C', 'what is section 80C?'),
    ('80C deductions', 'what deductions under 80C?'),
    ('80C limit', 'how much can I save under section 80C?'),
    ('80C investments', 'what investments are allowed in 80C?'),
    ('PPF EPF 80C', 'can I claim PPF and EPF in 80C?'),
    
    # Section 80D
    ('Section 80D', 'what is section 80D?'),
    ('Health insurance deduction', 'deduction for health insurance premium'),
    ('80D limit', 'how much deduction under 80D?'),
    ('Medical insurance tax benefit', 'tax benefit on medical insurance'),
    
    # Standard Deduction
    ('Standard deduction', 'what is standard deduction?'),
    ('Standard deduction amount', 'how much is standard deduction in 2025?'),
    ('Salary standard deduction', 'standard deduction for salaried employees'),
    
    # Capital Gains variations
    ('STCG rate', 'what is STCG rate?'),
    ('Short term capital gains', 'what is short term capital gains rate?'),
    ('LTCG rate', 'what is LTCG rate?'),
    ('Long term capital gains', 'long term capital gains tax rate'),
    ('Capital gains tax', 'what are capital gains tax rates?'),
    ('STCG vs LTCG', 'difference between STCG and LTCG'),
    ('Section 111A', 'what is section 111A?'),
    ('Section 112A', 'what is section 112A?'),
    
    # GST Questions
    ('GST rates', 'what are GST rates?'),
    ('GST on restaurants', 'what is GST rate for restaurants?'),
    ('Restaurant GST', 'GST for restaurant services'),
    ('GST definition', 'what is GST?'),
    ('Input tax credit', 'what is input tax credit under GST?'),
    ('ITC claim', 'how to claim input tax credit?'),
    
    # Freelance & Business
    ('Freelance income tax', 'how is freelance income taxed?'),
    ('Presumptive taxation', 'what is presumptive taxation?'),
    ('Who can opt presumptive', 'who can opt for presumptive taxation?'),
    ('Tax audit requirement', 'when is tax audit required?'),
    ('Tax audit mandatory', 'at what turnover is tax audit mandatory?'),
    
    # TDS & Salary
    ('TDS on salary', 'what are TDS rates for salary?'),
    ('Salary TDS rates', 'TDS rates on salary income'),
    
    # ITR Filing
    ('ITR filing deadline', 'what is the deadline for filing ITR?'),
    ('Due date ITR', 'when is the due date to file income tax return?'),
    ('ITR filing date', 'last date to file income tax return'),
    
    # Surcharge & Cess
    ('Surcharge', 'what is surcharge on income tax?'),
    ('Cess', 'what is health and education cess?'),
    
    # Section 24
    ('Section 24', 'what is section 24?'),
    ('Home loan interest', 'deduction for home loan interest'),
    
    # Section 80E
    ('Section 80E', 'what is section 80E?'),
    ('Education loan deduction', 'deduction for education loan interest'),
]

# ==============================================================================
# NON-FAQ TEST QUERIES (30+ complex questions)
# ==============================================================================

non_faq_queries = [
    # Income Calculation & Taxation
    ('Business income calculation', 'how is business income calculated and taxed in India?'),
    ('Rental income taxation', 'how is rental income calculated and taxed?'),
    ('Agricultural income', 'is agricultural income taxable in India?'),
    ('Dividend taxation', 'how are dividends taxed in India?'),
    ('Income from other sources', 'what income comes under income from other sources?'),
    ('Professional income', 'how is professional income taxed?'),
    
    # Loss & Set-off
    ('Loss carry forward', 'can I carry forward losses to next year?'),
    ('Set-off business loss', 'can I set off business loss against salary?'),
    ('House property loss', 'how to set off house property loss?'),
    ('Capital loss set-off', 'can capital loss be set off against other income?'),
    
    # HRA & Exemptions
    ('HRA calculation', 'how to calculate HRA exemption?'),
    ('HRA exemption conditions', 'what are the conditions for HRA exemption?'),
    ('LTA exemption', 'what is LTA and how is it exempted?'),
    
    # Advance Tax & TDS
    ('Advance tax payment', 'when do I need to pay advance tax?'),
    ('Advance tax due dates', 'what are advance tax installment dates?'),
    ('TDS refund process', 'how to get refund of excess TDS?'),
    ('Form 26AS', 'what is Form 26AS and how to download it?'),
    
    # GST Detailed
    ('GST registration mandatory', 'when is GST registration mandatory?'),
    ('GST returns monthly', 'what GST returns need to be filed monthly?'),
    ('GST composition scheme', 'who can opt for GST composition scheme?'),
    ('GSTR-1 filing', 'what is GSTR-1 and when to file it?'),
    ('Reverse charge mechanism', 'what is reverse charge mechanism in GST?'),
    
    # Investment & Savings
    ('Tax saving investments', 'what are the best tax saving investment options?'),
    ('NPS tax benefit', 'what is the tax benefit on NPS contribution?'),
    ('ELSS vs PPF', 'which is better for tax saving - ELSS or PPF?'),
    
    # PAN & Compliance
    ('PAN Aadhaar linking', 'is it mandatory to link PAN with Aadhaar?'),
    ('Consequences no ITR', 'what happens if I do not file income tax return?'),
    ('Revised return', 'can I file revised income tax return?'),
    
    # Property & Capital Assets
    ('Property sale tax', 'what is tax on sale of property?'),
    ('Exemption on property sale', 'how to save tax on property sale under section 54?'),
    ('Inherited property tax', 'is tax payable on inherited property?'),
]

# ==============================================================================
# TEST EXECUTION
# ==============================================================================

def run_test(label, query, is_faq=True):
    """Run a single test query and return results"""
    start_time = time.time()
    
    try:
        answer = query_rag(query, top_k=6)
        elapsed = time.time() - start_time
        
        # Analyze answer
        chars = len(answer)
        words = len(answer.split())
        has_sources = '📚' in answer or 'Source' in answer
        is_complete = answer and not answer.endswith('**') and not answer.endswith('It is')
        
        # Determine if FAQ hit by checking for FAQ marker in logs or fast response
        # More accurate: check if answer came from FAQ database
        is_faq_hit = elapsed < 2.0 or '[faq] Found answer in FAQ database' in str(answer)
        
        status = "✅" if is_complete else "⚠️"
        speed = "⚡ FAST" if elapsed < 5 else "🐌 SLOW" if elapsed > 30 else "✓ OK"
        
        return {
            'label': label,
            'query': query,
            'answer_length': chars,
            'words': words,
            'time': elapsed,
            'complete': is_complete,
            'has_sources': has_sources,
            'is_faq_hit': is_faq_hit,
            'status': status,
            'speed': speed,
            'answer_preview': answer[:200] if len(answer) > 200 else answer
        }
    except Exception as e:
        return {
            'label': label,
            'query': query,
            'error': str(e),
            'status': '❌',
            'time': time.time() - start_time
        }

print("=" * 100)
print("🧪 COMPREHENSIVE FINORA RAG SYSTEM TEST")
print("=" * 100)
print()

# ==============================================================================
# RUN FAQ TESTS
# ==============================================================================

print("\n" + "=" * 100)
print("📋 PART 1: FAQ TESTS (50+ variations)")
print("=" * 100)

faq_results = []
faq_hits = 0
faq_failures = 0

for i, (label, query) in enumerate(faq_test_queries, 1):
    print(f"\n[{i}/{len(faq_test_queries)}] Testing: {label}")
    result = run_test(label, query, is_faq=True)
    faq_results.append(result)
    
    if result.get('is_faq_hit'):
        faq_hits += 1
        print(f"   {result['status']} FAQ HIT | {result['speed']} | {result['time']:.1f}s | {result['answer_length']} chars")
    elif 'error' not in result:
        print(f"   {result['status']} LLM GEN | {result['speed']} | {result['time']:.1f}s | {result['answer_length']} chars")
    else:
        faq_failures += 1
        print(f"   ❌ ERROR: {result['error'][:50]}")

# ==============================================================================
# RUN NON-FAQ TESTS
# ==============================================================================

print("\n" + "=" * 100)
print("🔬 PART 2: NON-FAQ TESTS (30+ complex queries)")
print("=" * 100)

non_faq_results = []
non_faq_success = 0
non_faq_failures = 0

for i, (label, query) in enumerate(non_faq_queries, 1):
    print(f"\n[{i}/{len(non_faq_queries)}] Testing: {label}")
    result = run_test(label, query, is_faq=False)
    non_faq_results.append(result)
    
    if 'error' not in result:
        # Success = complete answer, regardless of length (short can be good!)
        if result['complete']:
            non_faq_success += 1
            quality_label = "✅ GOOD" if result['answer_length'] >= 200 else "✅ CONCISE"
            print(f"   {quality_label} | {result['speed']} | {result['time']:.1f}s | {result['answer_length']} chars | Sources: {'Yes' if result['has_sources'] else 'No'}")
        else:
            print(f"   ⚠️ INCOMPLETE | {result['speed']} | {result['time']:.1f}s | {result['answer_length']} chars")
    else:
        non_faq_failures += 1
        print(f"   ❌ ERROR: {result['error'][:50]}")

# ==============================================================================
# GENERATE SUMMARY REPORT
# ==============================================================================

print("\n" + "=" * 100)
print("📊 TEST RESULTS SUMMARY")
print("=" * 100)

total_tests = len(faq_results) + len(non_faq_results)
total_time = sum(r.get('time', 0) for r in faq_results + non_faq_results)

print(f"\n🔢 OVERALL STATISTICS")
print(f"   Total queries tested: {total_tests}")
print(f"   Total test time: {total_time:.1f}s ({total_time/60:.1f} minutes)")
print(f"   Average response time: {total_time/total_tests:.1f}s")

print(f"\n📋 FAQ TESTS ({len(faq_results)} queries)")
print(f"   FAQ hits (instant): {faq_hits}/{len(faq_results)} ({faq_hits*100//len(faq_results)}%)")
print(f"   LLM generation: {len(faq_results) - faq_hits - faq_failures}")
print(f"   Failures: {faq_failures}")
print(f"   Success rate: {(len(faq_results) - faq_failures)*100//len(faq_results)}%")

print(f"\n🔬 NON-FAQ TESTS ({len(non_faq_results)} queries)")
print(f"   Successful answers: {non_faq_success}/{len(non_faq_results)} ({non_faq_success*100//len(non_faq_results)}%)")
print(f"   Incomplete answers: {len(non_faq_results) - non_faq_success - non_faq_failures}")
print(f"   Failures: {non_faq_failures}")
print(f"   Success rate: {(len(non_faq_results) - non_faq_failures)*100//len(non_faq_results)}%")

# Timing analysis
fast_queries = sum(1 for r in faq_results + non_faq_results if r.get('time', 100) < 5)
slow_queries = sum(1 for r in faq_results + non_faq_results if r.get('time', 0) > 30)

print(f"\n⚡ PERFORMANCE")
print(f"   Fast responses (<5s): {fast_queries}/{total_tests} ({fast_queries*100//total_tests}%)")
print(f"   Slow responses (>30s): {slow_queries}/{total_tests} ({slow_queries*100//total_tests}%)")

# Source attribution
with_sources = sum(1 for r in non_faq_results if r.get('has_sources', False))
print(f"\n📚 SOURCE ATTRIBUTION")
print(f"   Answers with sources: {with_sources}/{len(non_faq_results)} ({with_sources*100//len(non_faq_results)}%)")

print("\n" + "=" * 100)
print("✅ TEST COMPLETE!")
print("=" * 100)
