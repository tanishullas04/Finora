import os
import json
import re
import platform
from dotenv import load_dotenv

# ===========================================================
# DEPLOYMENT NOTE
# MODULE NAME: run_query.py  (v5)
# The public entry points for this module are:
#   query_rag(query)         — blocking
#   query_rag_stream(query)  — streaming generator
#
# Gates applied in order BEFORE vector search:
#   1. is_tax_related_query() — non-tax topics blocked immediately
#   2. is_out_of_scope()      — unindexed tax topics blocked
#                               (has ALWAYS_IN_SCOPE allowlist so
#                                44AD, 80G, TDS etc. are never blocked)
#   3. check_faq()            — FAQ cache hit (< 0.1s)
#   4. vector search + LLM    — only reached for indexed topics
# ===========================================================
from utils.embedder import load_vector_store, embed_text
from utils.router import route_query

load_dotenv()

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EMBED_DIR = os.path.join(PROJECT_ROOT, "embeddings")


# ============================================================
# ALWAYS_IN_SCOPE — confirmed-indexed topics that must NEVER
# be blocked by is_out_of_scope(), even if a pattern in
# OUT_OF_SCOPE_TOPICS would otherwise match.
#
# Rule: if a query matches any pattern here, is_out_of_scope()
# returns False immediately without checking OUT_OF_SCOPE_TOPICS.
# ============================================================
ALWAYS_IN_SCOPE_PATTERNS = [
    # 44AD (businesses) — IS indexed; 44ADA (professionals) is NOT
    r'\bsection\s+44ad\b(?!a)',   # "section 44AD" but not "section 44ADA"
    r'\b44ad\b(?!a)',             # "44AD" but not "44ADA"

    # TDS / tax deduction at source — IS indexed
    r'\btds\b',
    r'tax\s+deduct(?:ion|ed)\s+at\s+source',

    # Advance tax (general rules) — IS indexed
    # Note: "advance tax schedule/instalment" stays out-of-scope
    r'^advance\s+tax$',
    r'advance\s+tax\s+(?:rules?|provisions?|payment(?!\s+schedule))',
    r'what\s+(?:is|are)\s+(?:the\s+)?(?:rules?\s+for\s+)?advance\s+tax',
    r'rules?\s+for\s+advance\s+tax',

    # Section 80G / donations — IS indexed
    r'\b80g\b',
    r'section\s+80g',
    r'\bdonation\s+deduction\b',
    r'\b80gg\b',

    # GST Rule 9A — IS indexed
    r'gst\s+rule\s+9',

    # Presumptive taxation (44AD) — IS indexed
    r'presumptive\s+tax(?:ation)?',

    # TDS provisions / Chapter XIX — IS indexed
    r'\bchapter\s+xix\b',
]

# ============================================================
# ALWAYS_ANSWER_PATTERNS — same confirmed-indexed topics used
# to bypass the topic_in_chunks gate inside answer_with_llm
# and answer_with_llm_stream.  If a query matches here, Gate 5
# (topic presence check) is skipped entirely so that low chunk
# confidence scores never cause a false OUT_OF_SCOPE_DECLINE
# for topics we know are indexed.
# ============================================================
ALWAYS_ANSWER_PATTERNS = [
    r'\btds\b',
    r'tax\s+deduct(?:ion|ed)\s+at\s+source',
    r'\bsection\s+44ad\b(?!a)',
    r'\b44ad\b(?!a)',
    r'advance\s+tax',
    r'\b80g\b',
    r'section\s+80g',
    r'\bdonation\b',
    r'\b80gg\b',
    r'gst\s+rule\s+9',
    r'presumptive\s+tax',
    r'\bchapter\s+xix\b',
]

# ============================================================
# OUT_OF_SCOPE_TOPICS — tax-adjacent topics NOT covered by
# any indexed document. Queries matching these are declined
# immediately, before FAQ and before any LLM call.
#
# Design rules:
#   - Never add topics that are in ALWAYS_IN_SCOPE_PATTERNS.
#   - Use \b word-boundary anchors to avoid partial matches.
#   - Prefer specificity to avoid false positives.
# ============================================================
OUT_OF_SCOPE_TOPICS = [
    # HRA / house rent allowance
    r'\bhra\b',
    r'house\s+rent\s+allowance',
    r'hra\s+exemption',
    r'hra\s+calculat',

    # Salary calculation (TDS on salary IS in FAQ; raw salary calc is NOT)
    r'taxable\s+salary',
    r'how.{0,20}calculat.{0,20}(?:taxable\s+)?salary',
    r'calculat.{0,20}taxable\s+salary',
    r'salary\s+(?:income\s+)?calculat',

    # Freelancer tax rules
    r'\bfreelancers?\b.*\btax\b',
    r'\btax\b.*\bfreelancers?\b',
    r'freelance\s+(?:tax|income)',
    r'tax\s+rules?\s+for\s+freelan',

    # House property income
    r'house\s+property\s+income',
    r'house\s+property.{0,20}tax(?!ation\s+scheme)',  # don't block "presumptive taxation scheme"
    r'income\s+from\s+house\s+property',
    r'how\s+is\s+house\s+property',

    # Basic exemption limit
    r'basic\s+exemption\s+limit',

    # Section 44ADA — professionals presumptive (44AD IS indexed; 44ADA is NOT)
    r'section\s+44ada\b',
    r'\b44ada\b',

    # Advance tax — only procedural subtopics not in index
    r'advance\s+tax\s+(?:payment\s+)?schedule',
    r'advance\s+tax\s+instalment',

    # LTA
    r'\blta\s+exemption\b',
    r'leave\s+travel\s+allowance',

    # GST registration rules/process
    r'gst\s+registration\s+rules?',
    r'gst\s+registration\s+process',
    r'gst\s+registration\s+(?:eligibility|threshold|limit)',
    r'how\s+to\s+register.{0,20}gst',
    r'who\s+(?:needs?|has)\s+to\s+register.{0,20}gst',
    r'what\s+are\s+the\s+gst\s+registration',

    # Assessment year
    r'what\s+is\s+(?:an?\s+)?assessment\s+year',
    r'\bassessment\s+year\b',
]

OUT_OF_SCOPE_DECLINE = (
    "The documents I have don't cover this specific topic. "
    "Please consult a chartered accountant or refer to the Income Tax Act directly."
)


def is_out_of_scope(query: str) -> bool:
    """
    Return True if the query is a known out-of-scope topic.

    ALWAYS_IN_SCOPE_PATTERNS are checked first — if any matches,
    the query is guaranteed in-scope regardless of OUT_OF_SCOPE_TOPICS.
    This prevents 44AD, 80G, TDS, advance tax etc. from being
    accidentally blocked by broader patterns in the blocklist.
    """
    query_lower = query.lower()

    # Step 1 — allowlist: confirmed-indexed topics are never blocked
    if any(re.search(p, query_lower) for p in ALWAYS_IN_SCOPE_PATTERNS):
        return False

    # Step 2 — blocklist: known unindexed topics are declined
    return any(re.search(p, query_lower) for p in OUT_OF_SCOPE_TOPICS)


def topic_in_chunks(query: str, chunks: list, confidence_level: str = "MEDIUM") -> bool:
    """
    Return False if no retrieved chunk contains a meaningful number
    of query-specific terms — indicating the retrieval is off-topic.

    Stop-words exclude generic tax vocab present in almost every chunk
    (income, business, rate…) since those are not discriminative.
    """
    stop_words = {
        'what', 'is', 'are', 'the', 'for', 'how', 'does', 'do',
        'in', 'of', 'to', 'a', 'an', 'and', 'or', 'with', 'on',
        'under', 'can', 'be', 'it', 'by', 'from', 'that', 'this',
        'which', 'when', 'where', 'who', 'will', 'was', 'were',
        # Generic tax vocab — not discriminative
        'tax', 'taxes', 'taxed', 'taxation', 'taxable',
        'india', 'indian',
        'income', 'profit', 'business', 'person', 'amount',
        'section', 'act', 'rule', 'provision', 'chapter',
        'rate', 'rates', 'payment', 'paid', 'payable',
        'year', 'financial', 'fiscal', 'annual',
    }
    query_terms = [
        w for w in query.lower().split()
        if len(w) > 4 and w not in stop_words
    ]

    if not query_terms:
        return True  # Can't determine — allow through

    combined = " ".join(c.get('text', '').lower() for c in chunks)
    matches = sum(1 for t in query_terms if t in combined)

    required = max(1, len(query_terms) // 2) if confidence_level == "MEDIUM" else max(1, len(query_terms) // 3)

    hit = matches >= required
    if not hit:
        print(f"[topic_check] FAIL — {matches}/{len(query_terms)} specific terms found "
              f"(need {required}, level={confidence_level}): {query_terms}")
    return hit


def load_index(index_name: str):
    index_path = os.path.join(EMBED_DIR, index_name, "index.jsonl")
    if not os.path.exists(index_path):
        raise FileNotFoundError(f"Index not found: {index_path}")

    entries = []
    with open(index_path, "rb") as f:
        raw = f.read()
    text = raw.decode("utf-8", errors="replace")
    for line in text.splitlines():
        if line.strip():
            try:
                entries.append(json.loads(line))
            except Exception as e:
                print("[warning] Skipping bad JSON line:", e)

    print(f"[index] Loaded {len(entries)} entries")
    return entries


def expand_query(query: str) -> str:
    """Expand query with common tax terminology for better retrieval."""
    query = query.strip().lstrip('-e').strip()
    query_lower = query.lower()

    section_patterns = [
        (r'\b80c\b',              'section 80c deduction investment savings'),
        (r'\b80d\b',              'section 80d health insurance medical premium'),
        (r'\b80g\b',              'section 80g donation charity'),
        (r'\b80e\b',              'section 80e education loan interest'),
        (r'\b80gg\b',             'section 80gg house rent allowance'),
        (r'\b24\b',               'section 24 house property interest'),
        (r'\bsection (\d+[a-z]*)\b', 'section \\1 income tax act'),
    ]
    expanded = query
    for pattern, expansion in section_patterns:
        if re.search(pattern, query_lower):
            expanded = f"{query} {expansion}"
            break

    expansions = {
        'deduction':    'deduction exemption relief',
        'rate':         'rate percentage slab',
        'capital gain': 'capital gains ltcg stcg',
        'gst':          'gst goods services tax cgst sgst igst',
    }
    for term, expansion in expansions.items():
        if term in query_lower and expansion not in expanded:
            expanded = f"{expanded} {expansion}"

    return expanded


def bm25_score(query_terms, doc_text, avg_doc_length, doc_length, k1=1.5, b=0.75):
    doc_lower = doc_text.lower()
    score = 0.0
    for term in query_terms:
        tf = doc_lower.count(term.lower())
        if tf > 0:
            num = tf * (k1 + 1)
            den = tf + k1 * (1 - b + b * (doc_length / avg_doc_length))
            score += num / den
    return score


def search_vectors(query: str, index_name: str, top_k=5):
    """Hybrid search combining semantic similarity and BM25 keyword matching."""
    entries = load_index(index_name)

    expanded_query = expand_query(query)
    if expanded_query != query:
        print(f"[search] Expanded: '{query}' → '{expanded_query}'")

    query_vec   = embed_text(expanded_query)
    query_terms = expanded_query.lower().split()
    avg_doc_len = sum(len(e.get('text', '')) for e in entries) / len(entries) if entries else 1

    def cosine(a, b):
        dot    = sum(x * y for x, y in zip(a, b))
        norm_a = sum(x * x for x in a) ** 0.5
        norm_b = sum(x * x for x in b) ** 0.5
        return dot / (norm_a * norm_b + 1e-9)

    scored = []
    for e in entries:
        sem  = cosine(query_vec, e["embedding"])
        txt  = e.get('text', '')
        kw   = min(bm25_score(query_terms, txt, avg_doc_len, len(txt)) / 10.0, 1.0)
        hyb  = 0.7 * sem + 0.3 * kw
        if len(query.lower().strip()) > 5 and query.lower().strip() in txt.lower():
            hyb *= 1.2
        scored.append((hyb, e, sem, kw))

    scored.sort(reverse=True, key=lambda x: x[0])

    # ── Known-indexed topic pre-check ──
    # For confirmed-indexed topics, always keep top-3 regardless of score
    # so the semantic-threshold bypass below can fire correctly.
    q_low    = query.lower()
    is_known = any(re.search(p, q_low) for p in ALWAYS_ANSWER_PATTERNS)

    if is_known:
        filtered = [(s, e) for s, e, sem, kw in scored[:3]]
        print(f"[search] Known-indexed topic — bypassing hybrid pre-filter, keeping top-3")
    else:
        threshold = 0.45
        filtered  = [(s, e) for s, e, sem, kw in scored if s >= threshold]
        if len(filtered) < 2:
            threshold = 0.38
            filtered  = [(s, e) for s, e, sem, kw in scored if s >= threshold]
            if filtered:
                print(f"[search] Lowered threshold to {threshold}")

    if scored:
        top_hyb, _, top_sem, top_kw = scored[0]
        print(f"[search] Top result: hybrid={top_hyb:.3f} (semantic={top_sem:.3f}, keyword={top_kw:.3f})")

    # ── Semantic threshold gate ──
    # Raised from 0.52 → 0.60 to block adjacent-but-off-topic matches.
    # Known-indexed topics bypass this gate entirely.
    if filtered and not is_known:
        best_sem = max(sem for _, _, sem, _ in scored[:len(filtered)])
        sem_threshold = 0.60 if len(entries) >= 50 else 0.45
        if best_sem < sem_threshold:
            print(f"[search] Semantic score too low ({best_sem:.3f} < {sem_threshold}) — skipping LLM")
            return []
    elif filtered and is_known:
        best_sem = max(sem for _, _, sem, _ in scored[:len(filtered)])
        print(f"[search] Known-indexed topic — skipping threshold gate (semantic={best_sem:.3f})")

    return filtered[:top_k]


def is_tax_related_query(query: str) -> bool:
    """Check if the query is related to Indian taxation."""
    query_lower = query.lower()

    tax_keywords = [
        'tax', 'gst', 'income', 'deduction', 'exemption', 'capital gains',
        'section', 'itr', 'tds', 'assessment', 'rebate', 'allowance',
        'salary', 'business', 'presumptive', 'audit', 'return',
        'cgst', 'sgst', 'igst', 'hsn', 'rate', 'slab', 'bracket',
        'depreciation', 'investment', 'savings', 'cess', 'surcharge',
        'financial year', 'assessment year', 'filing', 'compliance',
        'pan', 'aadhaar', 'tds', 'itr', 'form 16', 'form16',
        'hra', 'lta', 'medical', 'insurance', 'premium',
        'fd', 'fixed deposit', 'ppf', 'elss', 'nsc', 'mutual fund',
        'ltcg', 'stcg', 'dividend', 'interest',
        'section 80c', 'section 80d', 'section 80e', 'section 80g',
        'presumptive', 'advance tax', 'self-assessment',
        'carried forward', 'loss', 'profit',
        '80c', '80d', '80e', '80g', '80gg', '80u', '80dd', '80ddb',
        '44', '24', '54', '111a', '10', '16', '112a',
    ]

    non_tax_keywords = [
        r'\bweather\b', r'\bclimate\b', r'\btemperature\b', r'\brain\b',
        r'\bsnow\b', r'\bwind\b', r'\bstorm\b', r'\bhurricane\b', r'\bearthquake\b',
        r'\btsunami\b', r'\bflood\b', r'\bdrought\b', r'\bforest\b',
        r'\bocean\b', r'\briver\b', r'\bmountain\b', r'\bvalley\b',
        r'\bdesert\b', r'\bwildlife\b', r'\banimal\b',
        r'\bcricket\b', r'\bsports\b', r'\bfootball\b', r'\bbasketball\b',
        r'\btennis\b', r'\bvolleyball\b', r'\bbadminton\b', r'\bhockey\b',
        r'\bsoccer\b', r'\brugby\b', r'\bgolf\b', r'\bbaseball\b',
        r'\bboxing\b', r'\bwrestling\b', r'\bswimming\b', r'\bchess\b',
        r'\bpoker\b', r'\bgame\b', r'\bgaming\b', r'\besports\b',
        r'\bolympiad\b', r'\btournament\b', r'\bleague\b', r'\bmatch\b',
        r'\bmovie\b', r'\bfilm\b', r'\bcinema\b', r'\bactor\b',
        r'\bactress\b', r'\bdirector\b', r'\bcomedy\b', r'\bdrama\b',
        r'\bthriller\b', r'\bhorror\b', r'\baction\b', r'\bromance\b',
        r'\banime\b', r'\bcartoon\b', r'\bseries\b', r'\bepisode\b',
        r'\bnetflix\b', r'\byoutube\b', r'\bstreaming\b',
        r'\bmusic\b', r'\bsong\b', r'\bsinger\b', r'\bband\b',
        r'\bconcert\b', r'\balbum\b', r'\btrack\b', r'\bpodcast\b',
        r'\bradio\b', r'\baudio\b', r'\bbook\b', r'\bnovel\b',
        r'\bauthor\b', r'\bliterature\b', r'\bwriter\b', r'\bpoetry\b',
        r'\bverse\b', r'\bjoke\b', r'\bfunny\b', r'\bhumor\b',
        r'\blaugh\b', r'\bprank\b', r'\bviral\b', r'\bmeme\b', r'\btrending\b',
        r'\bcooking\b', r'\brecipe\b', r'\bcuisine\b', r'\bdish\b',
        r'\bmeal\b', r'\bbreakfast\b', r'\blunch\b', r'\bdinner\b',
        r'\bsnack\b', r'\bdessert\b', r'\bcake\b', r'\bcookie\b',
        r'\bpizza\b', r'\bburger\b', r'\bpasta\b', r'\brice\b',
        r'\bbread\b', r'\bcoffee\b', r'\btea\b', r'\bwine\b',
        r'\bbeer\b', r'\bjuice\b', r'\bsmoothie\b', r'\bbakery\b',
        r'\bcafe\b', r'\bkitchen\b',
        r'\btravel\b', r'\bvacation\b', r'\bholiday\b', r'\bhotel\b',
        r'\bmotel\b', r'\bhostel\b', r'\bresort\b', r'\bflight\b',
        r'\bairplane\b', r'\bairport\b', r'\btrain\b', r'\brailway\b',
        r'\bbus\b', r'\bcar\b', r'\bbike\b', r'\bmotorcycle\b',
        r'\bvehicle\b', r'\btaxi\b', r'\buber\b', r'\btourism\b',
        r'\bdestination\b', r'\bbeach\b', r'\bcruise\b',
        r'\bpassport\b', r'\btour\b', r'\bitinerary\b',
        r'\belection\b', r'\bpolitics\b', r'\bpolitical\b', r'\bgovernment\b',
        r'\bminister\b', r'\bparliament\b', r'\bcongress\b', r'\bsenate\b',
        r'\bvote\b', r'\bcampaign\b', r'\bparty\b', r'\bdemocracy\b',
        r'\bpresident\b', r'\bprime\s+minister\b', r'\bleader\b',
        r'\bpolice\b', r'\bcourt\b', r'\bjudge\b', r'\bverdict\b',
        r'\btrial\b', r'\bnews\b', r'\bheadlines\b', r'\blatest\b',
        r'\bnewspaper\b', r'\bjournalist\b', r'\breport\b', r'\bscandal\b',
        r'\bcapital\b(?!\s+gains)', r'\bcountry\b', r'\bcity\b',
        r'\btown\b', r'\bvillage\b', r'\bstate\b', r'\bprovince\b',
        r'\bregion\b', r'\bdistrict\b', r'\bmap\b', r'\bgeography\b',
        r'\blocation\b', r'\baddress\b', r'\bstreet\b', r'\broad\b',
        r'\bbuilding\b', r'\barchitecture\b', r'\blandmark\b',
        r'\bjapan\b', r'\bchina\b', r'\busa\b', r'\buk\b', r'\bcanada\b',
        r'\bfrancia\b', r'\bgermany\b', r'\brussia\b', r'\baustria\b',
        r'\bmexico\b', r'\bbrazil\b', r'\baustralian\b',
        r'\bafrica\b', r'\beurope\b', r'\basia\b', r'\bamericas\b',
        r'\bphysics\b', r'\bchemistry\b', r'\bbiology\b', r'\bastronomy\b',
        r'\bspace\b', r'\bmoon\b', r'\bplanet\b', r'\bstar\b',
        r'\bgalaxy\b', r'\brocket\b', r'\bsatellite\b', r'\bnasa\b',
        r'\bscience\b', r'\bexperiment\b', r'\bresearch\b', r'\bdiscovery\b',
        r'\bsoftware\b', r'\bprogramming\b', r'\bcoding\b', r'\bapp\b',
        r'\bcomputer\b', r'\bphone\b', r'\bgadget\b', r'\brobot\b',
        r'\bai\b', r'\bmachine\s+learning\b', r'\bdata\s+science\b',
        r'\binternet\b', r'\bwifi\b', r'\bnetwork\b', r'\bcybersecurity\b',
        r'\bhacking\b', r'\bvirus\b', r'\bmalware\b',
        r'\bhospital\b', r'\bdisease\b', r'\bdoctor\b',
        r'\bsurgery\b', r'\bvaccine\b', r'\bcovid\b',
        r'\btreatment\b', r'\bsymptom\b', r'\bcure\b', r'\bfitness\b',
        r'\bexercise\b', r'\bgym\b', r'\byoga\b', r'\bdiet\b',
        r'\bnutrition\b', r'\bweight\b', r'\bmental\s+health\b',
        r'\bpsychology\b', r'\btherapy\b', r'\bcounseling\b',
        r'\bdepression\b', r'\banxiety\b', r'\bmedication\b',
        r'\bdrug\b', r'\bpharmaceutical\b', r'\bhealthcare\b',
        r'\blove\b', r'\bmarriage\b', r'\bdating\b', r'\brelationship\b',
        r'\bbreakup\b', r'\bdivorce\b', r'\bfriend\b', r'\bfamily\b',
        r'\bparent\b', r'\bchild\b', r'\bbaby\b', r'\bwedding\b',
        r'\bgift\b', r'\bpersonality\b', r'\bhobby\b',
        r'\binterest\b', r'\btalent\b', r'\bskill\b',
        r'\bcareer\b', r'\bjob\s+search\b', r'\binterview\b',
        r'\bresume\b', r'\bpromotion\b',
        r'\bschool\b', r'\bcollege\b', r'\buniversity\b', r'\bstudent\b',
        r'\bteacher\b', r'\bprofessor\b', r'\bexam\b', r'\btest\b',
        r'\bgrade\b', r'\bhomework\b', r'\bassignment\b', r'\bcourse\b',
        r'\bclass\b', r'\blearning\b', r'\bstudy\b',
        r'\btraining\b', r'\bcertification\b', r'\bdegree\b',
        r'\bdiploma\b', r'\bscholarship\b', r'\badmission\b',
    ]

    tax_context_overrides = [
        'capital gain', 'capital gains',
        'health insurance', 'health and education cess',
        'education loan', 'education cess',
        'restaurant gst', 'gst on restaurant', 'gst for restaurant',
        'gst rate', 'insurance premium', 'medical insurance',
        '80d', '80e', '80c', 'section 80', 'section 24',
        'cess', 'deduction', 'tds', 'itr', 'income tax',
        'home loan', 'loan interest', 'insurance deduction',
        'restaurant food', 'gst on', 'tax rate', 'tax slab',
    ]

    if any(re.search(p, query_lower) for p in non_tax_keywords):
        if any(override in query_lower for override in tax_context_overrides):
            pass
        else:
            return False

    has_tax_kw  = any(kw in query_lower for kw in tax_keywords)
    has_section = re.search(r'\b(section\s*)?\d+[a-z]*\b', query_lower)

    if has_section or has_tax_kw:
        return True
    if len(query.split()) < 5:
        return False
    return True


def classify_query_intent(query: str) -> dict:
    q = query.lower()
    return {
        'wants_number_only': any(p in q for p in ['number only', 'just number', 'give me a number', 'just the number']),
        'wants_brief':       any(p in q for p in ['one line', 'brief', 'short', 'quick', 'summary', 'in brief']),
        'wants_detailed':    any(p in q for p in ['explain', 'detail', 'elaborate', 'comprehensive', 'in detail']),
        'is_counting':       q.strip().startswith('how many'),
        'wants_list':        any(p in q for p in ['list', 'what are', 'which are', 'enumerate']),
    }


def post_process_answer(answer: str, intent: dict, query: str) -> str:
    has_sources_before = '📚' in answer
    answer = answer.strip()

    # Deduplicate lines
    unique, seen = [], set()
    for line in answer.split('\n'):
        lc = line.strip()
        if lc and lc not in seen:
            unique.append(line)
            seen.add(lc)
    answer = '\n'.join(unique)

    hallucination_phrases = [
        'as of my knowledge cutoff', "i do not have access to",
        "i don't have access to", 'australia', 'united states',
        'uk tax', 'european union',
    ]
    answer_lower = answer.lower()

    if "i can't provide" in answer_lower or "i cannot provide" in answer_lower:
        parts = answer.split('?')
        if not (len(parts) > 1 and len(parts[1].strip()) > 50):
            for ph in hallucination_phrases:
                if ph in answer_lower:
                    return "This information is not available in my current tax knowledge base."
    else:
        for ph in hallucination_phrases:
            if ph in answer_lower:
                return "This information is not available in my current tax knowledge base."

    for ind in ['noob', 'noble amendment noob', 'xyz unclear']:
        if ind in answer_lower:
            return "This information is not available in my current tax knowledge base."

    if intent.get('wants_number_only') or (intent.get('is_counting') and 'number' in query.lower()):
        if any(p in answer_lower for p in ['not available', 'not specified', "don't have"]):
            return "The exact number is not specified in the available documents."
        nums = re.findall(r'\b\d+\b', answer)
        return nums[0] if nums else "The exact number is not specified in the available documents."

    if intent.get('wants_brief'):
        if '📚 **Sources:**' in answer:
            parts = answer.split('📚 **Sources:**')
            brief = (parts[0].split('\n\n')[0] if parts[0].split('\n\n') else parts[0])
            return brief + '\n\n📚 **Sources:**' + parts[1]
        return answer.split('\n\n')[0]

    if intent.get('wants_detailed') or intent.get('wants_list') or 'how many' in query.lower():
        return answer

    if len(answer) > 1000 and not any(w in query.lower() for w in ['how', 'what', 'when', 'where', 'why', 'explain', 'describe', 'list']):
        if '📚 **Sources:**' in answer:
            parts   = answer.split('📚 **Sources:**')
            sents   = re.split(r'[.!?]\s+', parts[0])
            trimmed = '. '.join(sents[:3]) + '.' if len(sents) >= 3 else parts[0]
            return trimmed + '\n\n📚 **Sources:**' + parts[1]
        sents = re.split(r'[.!?]\s+', answer)
        return '. '.join(sents[:3]) + '.' if len(sents) >= 3 else answer

    if has_sources_before and '📚' not in answer:
        print("[post_process] WARNING: Sources were lost during processing!")
    return answer


def check_faq(query: str) -> str:
    """
    Check FAQ cache. Out-of-scope queries are rejected before lookup
    so cached answers for HRA, salary, freelancer etc. never fire.
    """
    if is_out_of_scope(query):
        print("[faq] Query is out-of-scope — skipping FAQ lookup")
        return None

    try:
        faq_files = [
            os.path.join(PROJECT_ROOT, "faq", "tax_rates_faq.json"),
            os.path.join(PROJECT_ROOT, "faq", "faqs.json"),
        ]
        all_faqs = {}
        if os.path.exists(faq_files[0]):
            with open(faq_files[0]) as f:
                all_faqs.update(json.load(f))
        if os.path.exists(faq_files[1]):
            with open(faq_files[1]) as f:
                for item in json.load(f):
                    all_faqs[item['id']] = {
                        'question': item['question'],
                        'answer':   item['answer'],
                        'tags':     item.get('tags', []),
                        'category': item.get('category', ''),
                    }

        print(f"[faq] Loaded {len(all_faqs)} FAQ entries")
        q = query.lower().strip()

        faq_mapping = {
            # ── Freelancer (blocked by is_out_of_scope, kept for completeness) ──
            'freelance income taxed':       'freelance_income_tax',
            'how is freelance income':      'freelance_income_tax',
            'freelance tax':                'freelance_income_tax',
            # ── Tax audit ──
            'when is tax audit required':   'tax_audit_requirement',
            'tax audit required':           'tax_audit_requirement',
            'tax audit mandatory':          'tax_audit_requirement',
            # ── TDS on salary ──
            'tds rates for salary':         'tds_rates_salary',
            'tds on salary':                'tds_rates_salary',
            'section 192 tds':              'tds_rates_salary',
            'section 192':                  'tds_rates_salary',
            '192 tds':                      'tds_rates_salary',
            'salary tds':                   'tds_rates_salary',
            'tds salary':                   'tds_rates_salary',
            # ── ITR deadlines ──
            'deadline for filing income tax': 'itr_filing_deadline',
            'itr filing deadline':          'itr_filing_deadline',
            'when to file itr':             'itr_filing_deadline',
            'due date for itr':             'itr_filing_deadline',
            'itr last date':                'itr_filing_deadline',
            'last date itr':                'itr_filing_deadline',
            'income tax return deadline':   'itr_filing_deadline',
            'when to file income tax':      'itr_filing_deadline',
            'file income tax return':       'itr_filing_deadline',
            # ── GST restaurants ──
            'gst rate for restaurant':      'gst_rates_restaurants',
            'gst rates for restaurant':     'gst_rates_restaurants',
            'gst for restaurant':           'gst_rates_restaurants',
            'gst on restaurant':            'gst_rates_restaurants',
            'gst rules for restaurant':     'gst_rates_restaurants',
            'restaurant gst':               'gst_rates_restaurants',
            'restaurant gst rate':          'gst_rates_restaurants',
            'gst on restaurant food':       'gst_rates_restaurants',
            'restaurant food gst':          'gst_rates_restaurants',
            'gst restaurant food':          'gst_rates_restaurants',
            'gst restaurant':               'gst_rates_restaurants',
            'gst on food':                  'gst_rates_restaurants',
            # ── Capital gains ──
            'difference between stcg and ltcg': 'stcg_vs_ltcg',
            'stcg vs ltcg':                 'stcg_vs_ltcg',
            'capital gains tax rate':       'capital_gains_tax_rates',
            'short term capital gain':      'stcg_rate',
            'long term capital gain':       'ltcg_rate',
            # ── Slabs / income thresholds ──
            'tax rate for income above 10 lakh': 'tax_rate_above_10_lakhs',
            'income above 10 lakh':         'tax_rate_above_10_lakhs',
            'income tax slab':              'income_tax_slabs',
            'tax slab':                     'income_tax_slabs',
            # ── Presumptive / 44AD ──
            'who can opt for presumptive':  'who_can_opt_presumptive',
            'what is presumptive taxation': 'presumptive_taxation',
            'presumptive':                  'presumptive_taxation',
            'section 44ad presumptive':     'presumptive_taxation',
            'section 44ad':                 'presumptive_taxation',   # ← FIX: direct 44AD hit
            'what is section 44ad':         'presumptive_taxation',   # ← FIX
            '44ad for businesses':          'presumptive_taxation',   # ← FIX
            '44ad':                         'presumptive_taxation',   # ← FIX
            # ── GST general ──
            'what are gst rate':            'gst_rates',
            'what is gst':                  'gst_definition',
            'gst rate':                     'gst_rates',
            'cgst sgst igst':               'gst_definition',
            'cgst sgst':                    'gst_definition',
            'input tax credit':             'input_tax_credit',
            # ── Deductions ──
            'standard deduction':           'standard_deduction',
            'section 111a':                 'section_111a',
            'section 112a':                 'section_112a',
            '111a':                         'section_111a',
            '112a':                         'section_112a',
            'section 80c':                  'section_80c',
            '80c':                          'section_80c',
            'section 80d':                  'section_80d',
            'section 80d limit':            'section_80d',
            'section 80d deduction':        'section_80d',
            '80d deduction limit':          'section_80d',
            '80d limit':                    'section_80d',
            'health insurance deduction':   'section_80d',
            'health insurance 80d':         'section_80d',
            '80d health':                   'section_80d',
            '80d':                          'section_80d',
            'section 80e':                  'section_80e',
            '80e':                          'section_80e',
            'education loan deduction':     'section_80e',
            'education loan interest':      'section_80e',
            'section 80g':                  'section_80g',
            '80g':                          'section_80g',
            'donation deduction':           'section_80g',
            '80gg':                         'section_80gg',
            'section 24':                   'section_24',
            'home loan deduction':          'section_24',
            'home loan interest':           'section_24',
            'house loan interest':          'section_24',
            # ── Cess / surcharge ──
            'surcharge':                    'surcharge',
            'cess':                         'cess',
            'health and education cess':    'cess',
            'education cess':               'cess',
            'health cess':                  'cess',
            # ── STCG / LTCG ──
            'stcg':                         'stcg_rate',
            'ltcg':                         'ltcg_rate',
            # ── Capital gains rates ──
            'capital gain':                 'capital_gains_tax_rates',
        }

        for pattern, faq_key in faq_mapping.items():
            if pattern in q:
                if faq_key in all_faqs:
                    print(f"[faq] Matched '{pattern}' → {faq_key}")
                    return all_faqs[faq_key]['answer']

        # Fuzzy fallback
        best, best_score = None, 0
        for faq_id, faq_data in all_faqs.items():
            if 'question' not in faq_data:
                continue
            fq   = faq_data['question'].lower()
            tags = [t.lower() for t in faq_data.get('tags', [])]
            qw   = set(q.split())
            fqw  = set(fq.split())
            tw   = set(' '.join(tags).split())
            score = (len(qw & fqw) / max(len(qw), 1)) * 0.7 + (len(qw & tw) / max(len(qw), 1)) * 0.3
            if score > best_score and score > 0.5:
                best_score, best = score, faq_data

        if best:
            print(f"[faq] Fuzzy match (score: {best_score:.2f})")
            return best['answer']

        return None
    except Exception as e:
        print(f"[faq] Error: {e}")
        return None


def enforce_answer_length(answer: str, confidence_level: str, intent: dict) -> str:
    if confidence_level == "HIGH":
        return answer
    mult = 2 if (intent.get('wants_detailed') or intent.get('wants_list')) else 1
    cap  = {"LOW": 400 * mult, "MEDIUM": 800 * mult}.get(confidence_level, len(answer))
    if len(answer) <= cap:
        return answer
    trunc    = answer[:cap]
    last_end = max(trunc.rfind('. '), trunc.rfind('.\n'), trunc.rfind('! '), trunc.rfind('? '))
    return trunc[:last_end + 1].rstrip() if last_end > cap // 2 else trunc.rstrip()


def _is_not_found_response(answer: str) -> bool:
    indicators = [
        "no explicit", "not explicitly", "not directly stated",
        "not specifically address", "not mentioned in",
        "doesn't specifically", "does not specifically",
        "no such tax status", "not explainable", "not described",
        "cannot be explained", "no information", "not available in",
        "taken away from the context", "some additional information needed",
        "tax rules for free lancers as mentioned",
    ]
    if len(answer) > 300:
        return any(ind in answer.lower() for ind in indicators)
    return False


def answer_with_llm(query: str, context_chunks: list):
    """Generate answer using Ollama LLM or HuggingFace fallback."""

    # Gate 1 — off-topic
    if not is_tax_related_query(query):
        return ("I apologize, but I can only answer questions about Indian taxation. "
                "Please ask a question related to income tax, GST, capital gains, "
                "deductions, or other Indian tax matters.")

    # Gate 2 — out-of-scope (with ALWAYS_IN_SCOPE allowlist built in)
    if is_out_of_scope(query):
        print(f"[scope] Blocked: '{query}'")
        return OUT_OF_SCOPE_DECLINE

    # Gate 3 — FAQ cache
    faq_answer = check_faq(query)
    if faq_answer:
        print("[faq] Cache hit")
        return faq_answer

    # Gate 4 — no chunks
    if not context_chunks:
        return OUT_OF_SCOPE_DECLINE

    avg_len = sum(len(c.get('text', '')) for c in context_chunks) / len(context_chunks)
    if avg_len < 100:
        print(f"[warning] Chunks seem short (avg {avg_len:.0f} chars)")

    intent      = classify_query_intent(query)
    query_lower = query.lower()

    # ── Confidence ──
    def calc_confidence(chunks):
        scores = [c.get('score', 0) for c in chunks]
        avg    = sum(scores) / len(scores) if scores else 0
        if avg >= 0.65: return avg, "HIGH"
        if avg >= 0.55: return avg, "MEDIUM"
        return avg, "LOW"

    confidence_score, confidence_level = calc_confidence(context_chunks)
    print(f"[llm] Confidence: {confidence_level} ({confidence_score:.2f})")

    # Gate 5 — topic presence check (LOW/MEDIUM only)
    # Known-indexed topics bypass this gate entirely to prevent false declines
    # when chunk scores are low despite the topic being genuinely indexed.
    is_known_topic = any(re.search(p, query_lower) for p in ALWAYS_ANSWER_PATTERNS)
    if is_known_topic:
        print(f"[scope] Known-indexed topic — skipping topic_in_chunks gate")
    elif confidence_level in ("LOW", "MEDIUM") and not topic_in_chunks(query, context_chunks, confidence_level):
        print("[scope] Topic absent from chunks — declining")
        return OUT_OF_SCOPE_DECLINE

    # ── Context ──
    ctx_limits   = {"HIGH": 10000, "MEDIUM": 4000, "LOW": 1500}
    chunk_limits = {"HIGH": len(context_chunks), "MEDIUM": 3, "LOW": 2}
    max_ctx      = ctx_limits[confidence_level]
    active       = context_chunks[:chunk_limits[confidence_level]]
    spc          = max_ctx // min(len(active), 6)

    ctx_parts, total_chars, n_chunks = [], 0, 0
    for i, chunk in enumerate(active, 1):
        src  = chunk.get('metadata', {}).get('source', 'Tax Document')
        text = chunk.get('text', '')
        if len(text) > spc:
            text = text[:int(spc * 0.8)] + "..."
        entry = f"[Source {i}: {src}]\n{text}"
        if total_chars + len(entry) > max_ctx:
            rem = max_ctx - total_chars
            if rem > 500:
                entry = f"[Source {i}: {src}]\n{text[:rem - 100]}..."
                ctx_parts.append(entry); total_chars += len(entry); n_chunks += 1
            print(f"[context] Used {n_chunks}/{len(context_chunks)} chunks")
            break
        ctx_parts.append(entry); total_chars += len(entry); n_chunks += 1

    context_text = "\n\n".join(ctx_parts)
    print(f"[context] {total_chars} chars (~{total_chars//4} tokens)")

    # ── Token allocation ──
    def tokens_needed(q, intent, ctx_len):
        ql = q.lower()
        if intent.get('wants_number_only') or intent.get('wants_brief'): return 150
        if intent.get('wants_list') or 'how many' in ql or 'list all' in ql: return 1500
        if ('how is' in ql or 'how are' in ql) and ('tax' in ql or 'calculat' in ql): return 1500
        if intent.get('wants_detailed') or 'explain' in ql or 'detail' in ql: return 1200
        if 'rate' in ql or 'calculate' in ql or 'how to' in ql: return 1000
        ctx_tok = ctx_len // 4
        return 1500 if ctx_tok > 2000 else 1200 if ctx_tok > 1000 else 400

    base = tokens_needed(query, intent, len(context_text))
    caps = {"HIGH": 1800, "MEDIUM": 600, "LOW": 300}
    mult = {"HIGH": 1.3, "MEDIUM": 1.0, "LOW": 1.0}
    required_tokens = min(int(base * mult[confidence_level]), caps[confidence_level])
    print(f"[llm] Tokens: {required_tokens} ({confidence_level})")

    # ── Response instruction ──
    ql = query_lower
    if intent['wants_number_only'] or (intent['is_counting'] and 'number' in ql):
        ri = "Respond with ONLY a number if stated in context, else: 'The exact number is not specified in the available documents.'"
    elif intent['wants_brief']:
        ri = "One concise sentence using ONLY context facts. If not in context, say so."
    elif intent['wants_detailed']:
        ri = "Comprehensive answer from context only. Include all explicitly stated details."
    elif intent['wants_list'] or 'what deductions' in ql or 'which deductions' in ql:
        ri = "Numbered list of items explicitly in context. Do not add items not in context."
    elif re.search(r'what is (section )?80[a-z]+', ql):
        ri = "One sentence on what the section does, then list key points from context."
    elif 'how many' in ql or 'number of' in ql:
        ri = "List all relevant numbers/items from documents as a numbered list."
    elif 'rate' in ql or 'tds' in ql:
        ri = "Extract all rates from documents. Include percentages, ranges, conditions."
    elif 'how' in ql and 'tax' in ql:
        ri = "Explain the taxation mechanism from documents. Include sections, rates, exemptions."
    elif 'deadline' in ql or 'due date' in ql or ('when' in ql and 'file' in ql):
        ri = "Extract all deadlines and dates. Include conditions and penalties."
    else:
        ri = "Clear 4-6 sentence answer using all relevant context. Include rates, sections, conditions."

    # ── Hard decline instruction ──
    decline_instr = (
        "If you are not 100% certain the answer is explicitly in the TAX DOCUMENTS above, "
        "respond with EXACTLY this sentence and nothing else: "
        "\"The documents I have don't cover this specific topic. "
        "Please consult a chartered accountant or refer to the Income Tax Act directly.\""
    )

    if confidence_level == "LOW":
        system_prompt = (
            "You are Finora, an Indian tax information assistant.\n\n"
            "The documents provided do NOT directly cover the user's question.\n\n"
            "STRICT RULES:\n"
            "• ONLY use facts explicitly stated in the TAX DOCUMENTS below.\n"
            "• Do NOT add general knowledge, common practices, or outside information.\n"
            "• Do NOT use phrases like 'typically', 'generally', 'in many jurisdictions'.\n"
            f"• {decline_instr}\n"
            "• Do not speculate or fill gaps."
        )
    elif confidence_level == "MEDIUM":
        system_prompt = (
            "You are Finora, an Indian tax information assistant.\n\n"
            "The documents partially cover this topic.\n\n"
            "STRICT RULES:\n"
            "• ONLY use facts explicitly written in the TAX DOCUMENTS below.\n"
            "• No general knowledge. No 'typically'. No 'usually'.\n"
            "• If a specific detail is missing, say 'The documents don't specify this.'\n"
            "• 3-5 sentences maximum.\n"
            "• Never output 'TAKEN AWAY FROM THE CONTEXT'.\n"
            f"• {decline_instr}"
        )
    else:
        system_prompt = (
            "You are Finora, an expert Indian tax information assistant.\n\n"
            "The documents directly cover this topic.\n\n"
            "STRICT RULES:\n"
            "• ONLY use facts from the TAX DOCUMENTS below.\n"
            "• Cite specific sections (e.g. 'Section 80C') when mentioned.\n"
            "• Use bullet points or numbered steps where appropriate.\n"
            "• Complete every sentence. Never stop mid-thought.\n"
            "• Do not add information from outside the documents."
        )

    user_prompt = (
        f"TAX DOCUMENTS:\n{context_text}\n\n"
        f"QUESTION: {query}\n\n"
        f"TASK: {ri}\n\n"
        "Answer completely using only the information above."
    )

    # ── LLM call ──
    try:
        import ollama, signal

        use_timeout = (os.environ.get('DISABLE_SIGNAL_TIMEOUT') != '1' and
                       platform.system() != 'Windows')

        class _Timeout(Exception): pass
        def _handler(s, f): raise _Timeout()

        for model in ['phi3', 'llama3']:
            retries = 0
            while retries < 2:
                try:
                    if use_timeout:
                        signal.signal(signal.SIGALRM, _handler)
                        signal.alarm(60)

                    resp   = ollama.chat(
                        model=model,
                        messages=[
                            {'role': 'system', 'content': system_prompt},
                            {'role': 'user',   'content': user_prompt},
                        ],
                        options={
                            'temperature':    0.1,
                            'top_p':          0.95,
                            'top_k':          50,
                            'num_predict':    required_tokens,
                            'repeat_penalty': 1.15,
                            'num_ctx':        2048,
                            'stop':           [],
                        }
                    )
                    if use_timeout: signal.alarm(0)

                    answer = resp['message']['content']

                    if not validate_answer_quality(answer, query, intent, required_tokens, confidence_level):
                        retries += 1
                        if retries < 2:
                            print(f"[llm] Quality fail, retry {retries}/2…")
                            if len(answer) < 250:
                                required_tokens = min(int(required_tokens * 1.5), 2000)
                            continue
                        print("[llm] Max retries — using best answer")

                    if _is_not_found_response(answer):
                        print("[llm] Model signalled not-found")
                        return OUT_OF_SCOPE_DECLINE

                    answer = enforce_answer_length(answer, confidence_level, intent)
                    return post_process_answer(add_source_citations(answer, context_chunks), intent, query)

                except _Timeout:
                    if use_timeout: signal.alarm(0)
                    print(f"[llm] {model} timed out")
                    break
                except Exception as err:
                    if use_timeout: signal.alarm(0)
                    print(f"[llm] {model} error: {str(err)[:60]}")
                    retries += 1
                    if retries >= 2: break

    except Exception as e:
        print(f"[llm] Ollama unavailable: {e}")

    if not os.getenv('HF_TOKEN'):
        return format_retrieved_context(query, context_chunks)

    try:
        from huggingface_hub import InferenceClient
        client = InferenceClient(token=os.getenv('HF_TOKEN'))
        for model in ["microsoft/Phi-3-mini-4k-instruct", "mistralai/Mistral-7B-Instruct-v0.3"]:
            try:
                resp   = client.chat_completion(
                    messages=[{"role": "user", "content": f"{system_prompt}\n\n{user_prompt}"}],
                    model=model,
                    max_tokens=min(int(required_tokens * 1.2), 2000),
                    temperature=0.1, top_p=0.95,
                )
                answer = resp.choices[0].message.content
                return post_process_answer(add_source_citations(answer, context_chunks), intent, query)
            except Exception:
                continue
    except Exception:
        pass

    return format_retrieved_context(query, context_chunks)


def validate_answer_quality(answer, query, intent, allocated_tokens, confidence):
    ql, al = query.lower(), answer.lower()

    cautious = ["i can't provide", "i cannot provide", "i'm not able to", "i don't have access"]
    if any(p in al for p in cautious):
        substance = ['section ', '₹', '%', 'rs.', 'lakh', 'crore',
                     'according to', 'under ', 'deduction', 'exemption',
                     'rate', 'limit', 'threshold', 'year', 'months']
        if not any(s in al for s in substance):
            print(f"[quality] FAIL: cautious with no substance (confidence={confidence})")
            return False

    if answer and len(answer) > 50:
        tail = answer.strip()[-50:]
        if any(p in tail.lower() for p in ['...', 'wi...', 'of p', 'the computation']):
            print(f"[quality] FAIL: truncated end")
            return False
        if answer.strip()[-1] not in '.!?':
            last_words = answer.strip().split()[-3:]
            incomplete = {'the','a','an','is','are','was','were','and','or','but',
                          'for','with','under','to','of','in','on','at','by','from'}
            if any(w.lower() in incomplete for w in last_words):
                print(f"[quality] FAIL: incomplete sentence: '{' '.join(last_words)}'")
                return False

    if any(kw in ql for kw in [' vs ', ' versus ', 'difference between', 'compare']):
        if ' VS ' in query.upper() or ' VERSUS ' in query.upper():
            words = [w for w in query.upper().split() if len(w) > 2 and w not in {'VS','VERSUS','THE','AND','OR'}]
            if len(words) >= 2 and sum(1 for w in words[:2] if w in answer.upper()) < 2:
                print("[quality] FAIL: comparison items missing from answer")
                return False

    if allocated_tokens >= 1000 and len(answer) < 150:
        if not intent.get('wants_brief') and not intent.get('wants_number_only'):
            print(f"[quality] FAIL: {len(answer)} chars for {allocated_tokens} token budget")
            return False

    if any(answer.lower().startswith(p) for p in ['based on the provided', 'according to the text', 'the provided information']):
        if len(answer) < 100:
            print("[quality] FAIL: filler start, no content")
            return False

    print(f"[quality] PASS: {len(answer)} chars, {len(answer.split())} words")
    return True


def add_source_citations(answer: str, context_chunks: list) -> str:
    if not context_chunks:
        return answer
    sources, seen = [], set()
    for chunk in context_chunks:
        src = (chunk.get('metadata', {}) if isinstance(chunk, dict) else {}).get('source', '')
        if src and src not in seen:
            sources.append(src); seen.add(src)
        if len(sources) >= 3:
            break
    if sources:
        print(f"[sources] {sources}")
        return answer + "\n\n📚 **Sources:** " + ", ".join(sources)
    return answer


def format_retrieved_context(query: str, context_chunks: list) -> str:
    result = f"📚 **Found {len(context_chunks)} relevant sections about: {query}**\n\n"
    for i, chunk in enumerate(context_chunks, 1):
        src     = chunk.get('metadata', {}).get('source', 'Unknown')
        preview = chunk.get('text', '').replace('\n', ' ').strip()[:300]
        result += f"**{i}. Source: {src}**\n{preview}{'...' if len(chunk.get('text','')) > 300 else ''}\n\n"
    result += "\n💡 *Note: Install a local LLM or configure HF API for AI-generated answers*"
    return result


def query_rag(query: str, top_k=8):
    """Main blocking entry point."""

    # Gate 0 — non-tax topics blocked before vector search
    if not is_tax_related_query(query):
        return ("I apologize, but I can only answer questions about Indian taxation. "
                "Please ask a question related to income tax, GST, capital gains, "
                "deductions, or other Indian tax matters.")

    # Gate 1 — known out-of-scope tax topics blocked before vector search
    if is_out_of_scope(query):
        print(f"[scope] query_rag blocked: '{query}'")
        return OUT_OF_SCOPE_DECLINE

    indices = route_query(query)
    print(f"[router] → {', '.join(indices)}")

    all_matches = []
    for idx in indices:
        try:
            all_matches.extend(search_vectors(query, idx, top_k=top_k))
        except FileNotFoundError:
            print(f"[warning] Index {idx} not found, skipping")

    all_matches.sort(reverse=True, key=lambda x: x[0])
    top = all_matches[:top_k]

    if top:
        print(f"[search] Top scores: {[f'{m[0]:.3f}' for m in top[:3]]}")

    chunks = [{'text': m[1].get('text',''), 'metadata': m[1].get('metadata',{}), 'score': m[0]} for m in top]
    print(f"[search] {len(chunks)} chunks from {len(indices)} indices")

    return answer_with_llm(query, chunks)


def answer_with_llm_stream(query: str, context_chunks: list):
    """Streaming version — yields tokens."""

    if not is_tax_related_query(query):
        yield ("I apologize, but I can only answer questions about Indian taxation. "
               "Please ask a question related to income tax, GST, capital gains, "
               "deductions, or other Indian tax matters.")
        return

    if is_out_of_scope(query):
        print(f"[scope] stream blocked: '{query}'")
        yield OUT_OF_SCOPE_DECLINE
        return

    faq_answer = check_faq(query)
    if faq_answer:
        print("[faq] Cache hit (stream)")
        yield faq_answer
        return

    if not context_chunks:
        yield OUT_OF_SCOPE_DECLINE
        return

    intent = classify_query_intent(query)

    def _conf(chunks):
        scores = [c.get('score', 0) for c in chunks]
        avg    = sum(scores) / len(scores) if scores else 0
        if avg >= 0.65: return avg, "HIGH"
        if avg >= 0.55: return avg, "MEDIUM"
        return avg, "LOW"

    def _tokens(q, intent, ctx_len):
        ql = q.lower()
        if intent.get('wants_number_only') or intent.get('wants_brief'): return 150
        if intent.get('wants_list') or 'how many' in ql or 'list all' in ql: return 1500
        if ('how is' in ql or 'how are' in ql) and ('tax' in ql or 'calculat' in ql): return 1500
        if intent.get('wants_detailed') or 'explain' in ql or 'detail' in ql: return 1200
        if 'rate' in ql or 'calculate' in ql or 'how to' in ql: return 1000
        ctx_tok = ctx_len // 4
        return 1500 if ctx_tok > 2000 else 1200 if ctx_tok > 1000 else 400

    confidence_score, confidence_level = _conf(context_chunks)

    # Gate 5 — topic presence check (LOW/MEDIUM only)
    # Known-indexed topics bypass this gate entirely to prevent false declines
    # when chunk scores are low despite the topic being genuinely indexed.
    query_lower    = query.lower()
    is_known_topic = any(re.search(p, query_lower) for p in ALWAYS_ANSWER_PATTERNS)
    if is_known_topic:
        print(f"[scope] stream: known-indexed topic — skipping topic_in_chunks gate")
    elif confidence_level in ("LOW", "MEDIUM") and not topic_in_chunks(query, context_chunks, confidence_level):
        print("[scope] stream: topic absent from chunks")
        yield OUT_OF_SCOPE_DECLINE
        return

    ctx_limits   = {"HIGH": 10000, "MEDIUM": 4000, "LOW": 1500}
    chunk_limits = {"HIGH": len(context_chunks), "MEDIUM": 3, "LOW": 2}
    max_ctx      = ctx_limits[confidence_level]
    active       = context_chunks[:chunk_limits[confidence_level]]
    spc          = max_ctx // min(len(active), 6)

    ctx_parts, total = [], 0
    for i, chunk in enumerate(active, 1):
        src  = chunk.get('metadata', {}).get('source', 'Tax Document')
        text = chunk.get('text', '')
        if len(text) > spc:
            text = text[:int(spc * 0.8)] + "..."
        entry = f"[Source {i}: {src}]\n{text}"
        if total + len(entry) > max_ctx:
            rem = max_ctx - total
            if rem > 500:
                ctx_parts.append(f"[Source {i}: {src}]\n{text[:rem-100]}...")
            break
        ctx_parts.append(entry); total += len(entry)

    context_text  = "\n\n".join(ctx_parts)
    base_tokens   = _tokens(query, intent, len(context_text))
    caps          = {"HIGH": 1800, "MEDIUM": 600, "LOW": 300}
    mults         = {"HIGH": 1.3, "MEDIUM": 1.0, "LOW": 1.0}
    req_tokens    = min(int(base_tokens * mults[confidence_level]), caps[confidence_level])

    print(f"[stream] {confidence_level} ({confidence_score:.2f}), tokens={req_tokens}")

    decline_instr = (
        "If you are not 100% certain the answer is explicitly in the TAX DOCUMENTS above, "
        "respond with EXACTLY: \"The documents I have don't cover this specific topic. "
        "Please consult a chartered accountant or refer to the Income Tax Act directly.\""
    )

    if confidence_level == "LOW":
        sys_prompt = (
            "You are Finora, an Indian tax information assistant.\n"
            f"STRICT: ONLY use facts from the TAX DOCUMENTS. {decline_instr}\n"
            "Do NOT speculate or use general knowledge."
        )
    elif confidence_level == "MEDIUM":
        sys_prompt = (
            "You are Finora, an Indian tax information assistant.\n"
            f"STRICT: ONLY facts from TAX DOCUMENTS. No general knowledge. No 'typically'.\n"
            f"3-5 sentences max. {decline_instr}"
        )
    else:
        sys_prompt = (
            "You are Finora, an expert Indian tax information assistant.\n"
            "ONLY use TAX DOCUMENTS. Cite sections. Complete every sentence."
        )

    user_prompt = f"TAX DOCUMENTS:\n{context_text}\n\nQUESTION: {query}\n\nAnswer using only the documents above."

    try:
        import ollama
        for model in ['phi3', 'llama3']:
            try:
                print(f"[stream] → {model}")
                stream = ollama.chat(
                    model=model,
                    messages=[
                        {'role': 'system', 'content': sys_prompt},
                        {'role': 'user',   'content': user_prompt},
                    ],
                    options={
                        'temperature': 0.1, 'top_p': 0.95,
                        'num_predict': req_tokens, 'repeat_penalty': 1.15, 'num_ctx': 2048,
                    },
                    stream=True,
                )
                for chunk in stream:
                    yield chunk['message']['content']

                sources, seen = [], set()
                for c in context_chunks:
                    src = c.get('metadata', {}).get('source', '')
                    if src and src not in seen:
                        sources.append(src); seen.add(src)
                    if len(sources) >= 3: break
                if sources:
                    yield "\n\n📚 **Sources:** " + ", ".join(sources)
                return
            except Exception as e:
                print(f"[stream] {model} failed: {str(e)[:80]}")
                continue
    except Exception as e:
        print(f"[stream] Ollama unavailable: {e}")

    yield format_retrieved_context(query, context_chunks)


def query_rag_stream(query: str, top_k: int = 8):
    """Streaming entry point."""

    if not is_tax_related_query(query):
        yield ("I apologize, but I can only answer questions about Indian taxation. "
               "Please ask a question related to income tax, GST, capital gains, "
               "deductions, or other Indian tax matters.")
        return

    if is_out_of_scope(query):
        print(f"[scope] query_rag_stream blocked: '{query}'")
        yield OUT_OF_SCOPE_DECLINE
        return

    indices = route_query(query)
    print(f"[router] stream → {', '.join(indices)}")

    all_matches = []
    for idx in indices:
        try:
            all_matches.extend(search_vectors(query, idx, top_k=top_k))
        except FileNotFoundError:
            print(f"[warning] Index {idx} not found")

    all_matches.sort(reverse=True, key=lambda x: x[0])
    top = all_matches[:top_k]

    if top:
        print(f"[search] Top scores: {[f'{m[0]:.3f}' for m in top[:3]]}")

    chunks = [{'text': m[1].get('text',''), 'metadata': m[1].get('metadata',{}), 'score': m[0]} for m in top]
    print(f"[search] {len(chunks)} chunks from {len(indices)} indices")

    yield from answer_with_llm_stream(query, chunks)


# ── CLI ──
if __name__ == "__main__":
    print("Finora RAG Query Engine (v5)\n")
    while True:
        q = input("Ask Finora → ").strip()
        if q.lower() in {"exit", "quit"}:
            break
        try:
            print("\n---- Answer ----")
            print(query_rag(q))
            print("----------------\n")
        except Exception as e:
            print(f"[error] {e}")