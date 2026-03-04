"""
test_queries_comprehensive.py
Run while api.py is running:
    python3 test_queries_comprehensive.py

Optional flags:
    --faq-only      run only FAQ tests
    --llm-only      run only LLM + not-in-docs tests
    --off-only      run only off-topic tests
    --fast          skip LLM tests (they're slow)
    --verbose       print full answer, not just preview
"""

import requests
import sys

BASE_URL = "http://localhost:5001"
VERBOSE = "--verbose" in sys.argv
FAST = "--fast" in sys.argv

DECLINE_PHRASES = [
    "don't cover",
    "consult a chartered",
    "only answer questions about indian taxation",
    "please ask a question related to",
    "not available in my current",
    "i apologize, but i can only",
]

def is_decline(answer: str) -> bool:
    return any(p in answer.lower() for p in DECLINE_PHRASES)


FAQ_QUESTIONS = [
    # Income tax slabs
    ("what are the income tax slabs",                       "faq", "basic slab query"),
    ("income tax slab rates",                               "faq", "short form"),
    ("tax slab for fy 2025-26",                             "faq", "with year"),
    ("what are the new regime tax slabs",                   "faq", "new regime"),
    ("what is the tax rate for income above 10 lakh",       "faq", "specific slab"),
    # Standard deduction
    ("what is standard deduction",                          "faq", "basic"),
    ("standard deduction for salaried employees",           "faq", "with context"),
    ("how much is the standard deduction",                  "faq", "how much form"),
    # Section 80C
    ("what is section 80c",                                 "faq", "basic"),
    ("80c deduction limit",                                 "faq", "short form"),
    ("what investments qualify for 80c",                    "faq", "investment form"),
    ("section 80c maximum deduction",                       "faq", "limit query"),
    ("what are 80c eligible investments",                   "faq", "eligible items"),
    # Section 80D
    ("what is section 80d",                                 "faq", "basic"),
    ("health insurance deduction 80d",                      "faq", "health insurance form"),
    ("80d deduction limit",                                 "faq", "limit form"),
    # Section 80E
    ("what is section 80e",                                 "faq", "basic"),
    ("education loan interest deduction",                   "faq", "education loan form"),
    ("section 80e deduction",                               "faq", "short form"),
    # Section 24
    ("what is section 24",                                  "faq", "basic"),
    ("home loan interest deduction",                        "faq", "home loan form"),
    ("section 24 house property",                           "faq", "house property"),
    # Capital gains
    ("what is ltcg",                                        "faq", "basic"),
    ("what is stcg",                                        "faq", "basic"),
    ("long term capital gains tax rate",                    "faq", "rate query"),
    ("short term capital gains tax",                        "faq", "rate query"),
    ("difference between stcg and ltcg",                    "faq", "comparison"),
    ("stcg vs ltcg",                                        "faq", "vs form"),
    ("capital gains tax rates",                             "faq", "general rates"),
    ("what is section 111a",                                "faq", "stcg section"),
    ("what is section 112a",                                "faq", "ltcg section"),
    ("111a tax rate",                                       "faq", "short form"),
    ("112a tax rate",                                       "faq", "short form"),
    # GST
    ("what is gst",                                         "faq", "basic"),
    ("what are gst rates",                                  "faq", "rates query"),
    ("gst rate for restaurants",                            "faq", "restaurant"),
    ("what are the gst rates for restaurants",              "faq", "restaurant plural"),
    ("gst on restaurant food",                              "faq", "food form"),
    ("restaurant gst rate",                                 "faq", "rate form"),
    ("gst rules for restaurants",                           "faq", "rules form"),
    ("what is input tax credit",                            "faq", "ITC basic"),
    ("how does input tax credit work",                      "faq", "ITC how"),
    ("what is cgst sgst igst",                              "faq", "components"),
    # TDS
    ("tds on salary",                                       "faq", "basic"),
    ("tds rates for salary",                                "faq", "rates form"),
    ("salary tds deduction",                                "faq", "deduction form"),
    ("how is tds deducted on salary",                       "faq", "how form"),
    ("section 192 tds",                                     "faq", "section form"),
    # ITR filing
    ("itr filing deadline",                                 "faq", "basic"),
    ("when to file income tax return",                      "faq", "when form"),
    ("due date for itr filing",                             "faq", "due date form"),
    ("deadline for filing income tax return",               "faq", "deadline form"),
    ("itr last date",                                       "faq", "last date form"),
    # Presumptive taxation
    ("what is presumptive taxation",                        "faq", "basic"),
    ("who can opt for presumptive taxation",                "faq", "eligibility"),
    ("presumptive tax scheme",                              "faq", "scheme form"),
    ("section 44ad presumptive",                            "faq", "section form"),
    # Surcharge and cess
    ("what is surcharge on income tax",                     "faq", "surcharge"),
    ("what is health and education cess",                   "faq", "cess"),
    ("surcharge rate income tax",                           "faq", "surcharge rate"),
]

# Confirmed answerable from indexed documents
LLM_QUESTIONS = [
    ("what is section 44AD for businesses",                 "llm", "44AD - verified"),
    ("what are the rules for advance tax payment",          "llm", "advance tax - verified"),
    ("explain section 80G donation deduction",              "llm", "80G - verified"),
    ("what are provisions for tax deduction at source",     "llm", "TDS provisions - verified"),
    ("what is gst rule 9a",                                 "llm", "GST rule 9A - verified"),
]

# Tax topics NOT in indexed documents — must decline cleanly
NOT_IN_DOCS_QUESTIONS = [
    ("how is house property income taxed",                  "none", "house property - not indexed"),
    ("what is the tax treatment of dividends",              "none", "dividends - not indexed"),
    ("what is HRA exemption",                               "none", "HRA - not indexed"),
    ("how to calculate taxable salary",                     "none", "salary calc - not indexed"),
    ("what is the basic exemption limit",                   "none", "exemption limit - not indexed"),
    ("what is reverse charge mechanism in gst",             "none", "RCM - not indexed"),
    ("what are the tax rules for freelancers",              "none", "freelancer - not indexed"),
    ("what are the penalties for late itr filing",          "none", "penalties - not indexed"),
    ("how to file itr online step by step",                 "none", "itr procedure - not indexed"),
    ("what is the tax on crypto currency",                  "none", "crypto - not indexed"),
    # Previously in LLM group but confirmed not indexed
("what is section 44ADA for professionals",             "none", "44ADA - not indexed"),
("what is assessment year",                             "none", "AY - not indexed"),
("what are the gst registration rules",                 "none", "GST reg - not indexed"),
# Borderline semantic score — decline is correct behaviour
("how is house property income taxed",                  "none", "house property - borderline"),
("what is HRA exemption",                               "none", "HRA - borderline"),
("how to calculate taxable salary",                     "none", "salary calc - borderline"),
("what are the tax rules for freelancers",              "none", "freelancer - borderline"),
]

# Completely off-topic — must be blocked instantly
OFF_TOPIC_QUESTIONS = [
    ("who won the cricket world cup",                       "none", "sports"),
    ("what is the weather in mumbai",                       "none", "weather"),
    ("recommend me a good restaurant in delhi",             "none", "restaurant rec"),
    ("how to make biryani",                                 "none", "cooking"),
    ("what is the latest iphone model",                     "none", "tech"),
    ("who is the prime minister of india",                  "none", "politics"),
    ("what is machine learning",                            "none", "tech/AI"),
    ("best movies to watch this weekend",                   "none", "entertainment"),
    ("how to lose weight fast",                             "none", "health"),
    ("what is the population of india",                     "none", "geography"),
    ("tell me a joke",                                      "none", "personal"),
    ("write me a poem",                                     "none", "creative"),
    ("how to learn python programming",                     "none", "education"),
    ("what stocks should i buy",                            "none", "investment advice"),
    ("translate hello to french",                           "none", "language"),
    ("what is the distance from delhi to mumbai",           "none", "geography"),
]

ALL_TESTS = FAQ_QUESTIONS + LLM_QUESTIONS + NOT_IN_DOCS_QUESTIONS + OFF_TOPIC_QUESTIONS


def query_api(q: str) -> dict:
    try:
        r = requests.post(f"{BASE_URL}/query", json={"query": q}, timeout=180)
        return r.json()
    except Exception as e:
        return {"success": False, "error": str(e), "processing_time": -1}


def classify_result(result: dict, expected: str) -> tuple:
    t = result.get("processing_time", 99)
    answer = result.get("answer", result.get("error", ""))
    declined = is_decline(answer)

    if not result.get("success"):
        return f"FAIL  (request error: {result.get('error', '?')[:60]})", "FAIL"

    if expected == "faq":
        if declined:  return f"FAIL  ({t}s — declined instead of answering from FAQ)", "FAIL"
        if t > 3:     return f"WARN  ({t}s — slow, probably hit LLM instead of FAQ cache)", "WARN"
        return f"PASS  ({t}s)", "PASS"

    elif expected == "llm":
        if declined:  return f"WARN  ({t}s — declined, topic may not be in documents)", "WARN"
        return f"PASS  ({t}s)", "PASS"

    elif expected == "none":
        if declined:  return f"PASS  ({t}s — correctly declined)", "PASS"
        return f"WARN  ({t}s — answered when it should have declined)", "WARN"

    return "UNKNOWN", "UNKNOWN"


def run_group(tests: list, label: str, skip: bool = False):
    print(f"\n{'='*65}")
    print(f"  {label}  ({len(tests)} tests)")
    print(f"{'='*65}")

    if skip:
        print("  [SKIPPED] --fast mode")
        return 0, 0, 0

    passed = warned = failed = 0
    slowest = ("", 0)

    for q, expected, note in tests:
        result = query_api(q)
        status, kind = classify_result(result, expected)
        answer = result.get("answer", result.get("error", ""))
        t = result.get("processing_time", 0)

        if kind == "PASS":    passed += 1
        elif kind == "WARN":  warned += 1
        else:                 failed += 1

        if t > slowest[1]: slowest = (q, t)

        icon = {"PASS": "[PASS]", "WARN": "[WARN]", "FAIL": "[FAIL]"}.get(kind, "[????]")
        print(f"\n  {icon} [{note}]")
        print(f"     Q: {q}")
        print(f"     > {status}")
        preview = answer if VERBOSE else answer[:130].replace("\n", " ")
        print(f"     A: {preview}{'...' if not VERBOSE and len(answer) > 130 else ''}")

    print(f"\n  -- Results: {passed} passed  {warned} warned  {failed} failed --")
    if slowest[1] > 2:
        print(f"  Slowest: '{slowest[0]}' ({slowest[1]}s)")

    return passed, warned, failed


if __name__ == "__main__":
    print(f"\nFinora Comprehensive Query Tester")
    print(f"   Target : {BASE_URL}")
    print(f"   Tests  : {len(ALL_TESTS)} total  "
          f"({len(FAQ_QUESTIONS)} faq | {len(LLM_QUESTIONS)} llm | "
          f"{len(NOT_IN_DOCS_QUESTIONS)} not-in-docs | {len(OFF_TOPIC_QUESTIONS)} off-topic)")
    print(f"   Flags  : {'--fast ' if FAST else ''}{'--verbose' if VERBOSE else 'none'}")

    try:
        r = requests.get(f"{BASE_URL}/health", timeout=5)
        print(f"   Server : {'online' if r.ok else 'UNHEALTHY'}\n")
    except Exception:
        print("   Server : NOT REACHABLE -- is api.py running?")
        exit(1)

    run_faq = "--llm-only" not in sys.argv and "--off-only" not in sys.argv
    run_llm = "--faq-only" not in sys.argv and "--off-only" not in sys.argv
    run_off = "--faq-only" not in sys.argv and "--llm-only" not in sys.argv

    tp = tw = tf = 0

    if run_faq:
        p, w, f = run_group(FAQ_QUESTIONS,
                            "FAQ QUESTIONS -- must answer from cache in <2s, no LLM")
        tp+=p; tw+=w; tf+=f

    if run_llm:
        p, w, f = run_group(LLM_QUESTIONS,
                            "LLM QUESTIONS -- must answer from indexed documents",
                            skip=FAST)
        tp+=p; tw+=w; tf+=f

        p, w, f = run_group(NOT_IN_DOCS_QUESTIONS,
                            "TAX TOPICS NOT IN DOCS -- must decline cleanly and quickly",
                            skip=FAST)
        tp+=p; tw+=w; tf+=f

    if run_off:
        p, w, f = run_group(OFF_TOPIC_QUESTIONS,
                            "OFF-TOPIC -- must be blocked immediately")
        tp+=p; tw+=w; tf+=f

    grand_total = tp + tw + tf
    pct = round(tp / grand_total * 100) if grand_total else 0

    print(f"\n{'='*65}")
    print(f"  FINAL SCORE: {tp}/{grand_total} passed  ({pct}%)")
    print(f"  {tp} passed  |  {tw} warned  |  {tf} failed")
    print(f"{'='*65}\n")

    if   tf > 0: print("  SOME TESTS FAILED -- check output above\n")
    elif tw > 0: print("  Some warnings -- review above\n")
    else:        print("  ALL TESTS PASSED!\n")