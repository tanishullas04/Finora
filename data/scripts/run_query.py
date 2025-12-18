import os
import json
import re
import platform
from dotenv import load_dotenv
from utils.embedder import load_vector_store, embed_text
from utils.router import route_query

# Load environment variables from .env file
load_dotenv()

# paths
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EMBED_DIR = os.path.join(PROJECT_ROOT, "embeddings")


def load_index(index_name: str):
    """Load the index.jsonl file and return all vectors"""
    index_path = os.path.join(EMBED_DIR, index_name, "index.jsonl")

    if not os.path.exists(index_path):
        raise FileNotFoundError(f"Index not found: {index_path}")

    entries = []
    with open(index_path, "r") as f:
        for line in f:
            entries.append(json.loads(line))
    return entries


def expand_query(query: str) -> str:
    """Expand query with common tax terminology for better retrieval."""
    # Clean query: remove command-line artifacts
    query = query.strip().lstrip('-e').strip()
    query_lower = query.lower()
    
    # Section number expansion
    section_patterns = [
        (r'\b80c\b', 'section 80c deduction investment savings'),
        (r'\b80d\b', 'section 80d health insurance medical premium'),
        (r'\b80g\b', 'section 80g donation charity'),
        (r'\b80e\b', 'section 80e education loan interest'),
        (r'\b80gg\b', 'section 80gg house rent allowance'),
        (r'\b24\b', 'section 24 house property interest'),
        (r'\bsection (\d+[a-z]*)\b', 'section \\1 income tax act'),
    ]
    
    expanded = query
    for pattern, expansion in section_patterns:
        if re.search(pattern, query_lower):
            expanded = f"{query} {expansion}"
            break
    
    # Add common synonyms for tax terms
    expansions = {
        'deduction': 'deduction exemption relief',
        'rate': 'rate percentage slab',
        'capital gain': 'capital gains ltcg stcg',
        'gst': 'gst goods services tax cgst sgst igst',
    }
    
    for term, expansion in expansions.items():
        if term in query_lower and expansion not in expanded:
            expanded = f"{expanded} {expansion}"
    
    return expanded


def bm25_score(query_terms: list, doc_text: str, avg_doc_length: float, doc_length: int, k1=1.5, b=0.75) -> float:
    """Calculate BM25 keyword relevance score."""
    doc_lower = doc_text.lower()
    score = 0.0
    
    for term in query_terms:
        term_lower = term.lower()
        # Count term frequency in document
        tf = doc_lower.count(term_lower)
        if tf > 0:
            # BM25 formula (simplified without IDF since we're using it as a boost)
            numerator = tf * (k1 + 1)
            denominator = tf + k1 * (1 - b + b * (doc_length / avg_doc_length))
            score += numerator / denominator
    
    return score


def search_vectors(query: str, index_name: str, top_k=5):
    """Hybrid search combining semantic similarity and keyword matching."""
    entries = load_index(index_name)
    
    # Expand query for better retrieval
    expanded_query = expand_query(query)
    if expanded_query != query:
        print(f"[search] Expanded query: '{query}' → '{expanded_query}'")
    
    query_vec = embed_text(expanded_query)
    query_terms = expanded_query.lower().split()
    
    # Calculate average document length for BM25
    avg_doc_length = sum(len(e.get('text', '')) for e in entries) / len(entries) if entries else 1

    # Use cosine similarity for semantic search
    def cosine_similarity(a, b):
        dot = sum(x * y for x, y in zip(a, b))
        norm_a = sum(x * x for x in a) ** 0.5
        norm_b = sum(x * x for x in b) ** 0.5
        return dot / (norm_a * norm_b + 1e-9)

    scored = []
    for e in entries:
        # Semantic similarity score
        semantic_score = cosine_similarity(query_vec, e["embedding"])
        
        # Keyword matching score (BM25)
        doc_text = e.get('text', '')
        doc_length = len(doc_text)
        keyword_score = bm25_score(query_terms, doc_text, avg_doc_length, doc_length)
        
        # Normalize keyword score to 0-1 range (approximate)
        keyword_score_norm = min(keyword_score / 10.0, 1.0)
        
        # Hybrid score: 70% semantic + 30% keyword
        # Keyword matching helps with exact section numbers, technical terms
        hybrid_score = 0.7 * semantic_score + 0.3 * keyword_score_norm
        
        # Boost for exact phrase matches (e.g., "section 80C")
        query_clean = query.lower().strip()
        if len(query_clean) > 5 and query_clean in doc_text.lower():
            hybrid_score *= 1.2  # 20% boost for exact matches
        
        scored.append((hybrid_score, e, semantic_score, keyword_score_norm))

    scored.sort(reverse=True, key=lambda x: x[0])
    
    # Filter by minimum similarity threshold
    min_threshold = 0.30  # Slightly higher threshold for better quality
    filtered = [(s, e) for s, e, sem, kw in scored if s >= min_threshold]
    
    # Dynamic threshold: if too few results, lower threshold
    if len(filtered) < 3 and min_threshold > 0.25:
        min_threshold = 0.25
        filtered = [(s, e) for s, e, sem, kw in scored if s >= min_threshold]
        if filtered:
            print(f"[search] Lowered threshold to {min_threshold} to get more results")
    
    # Debug: show score breakdown for top result
    if filtered and scored:
        top_hybrid, top_chunk, top_sem, top_kw = scored[0]
        print(f"[search] Top result: hybrid={top_hybrid:.3f} (semantic={top_sem:.3f}, keyword={top_kw:.3f})")
    
    return filtered[:top_k]


def is_tax_related_query(query: str) -> bool:
    """Check if the query is related to Indian taxation."""
    query_lower = query.lower()
    
    # Tax-related keywords
    tax_keywords = [
        'tax', 'gst', 'income', 'deduction', 'exemption', 'capital gains',
        'section', 'itr', 'tds', 'assessment', 'rebate', 'allowance',
        'salary', 'business', 'presumptive', 'audit', 'return',
        'cgst', 'sgst', 'igst', 'hsn', 'rate', 'slab', 'bracket',
        'depreciation', 'investment', 'savings', 'cess', 'surcharge',
        'financial year', 'assessment year', 'filing', 'compliance',
        # Section numbers
        '80c', '80d', '80e', '80g', '80gg', '80u', '80dd', '80ddb',
        '44', '24', '54', '111a', '10', '16',
    ]
    
    # Check if any tax keyword is present
    has_tax_keyword = any(keyword in query_lower for keyword in tax_keywords)
    
    # Check for section number patterns (e.g., "section 80C", "80C", "sec 24")
    section_pattern = r'\b(section\s*)?\d+[a-z]*\b'
    has_section = re.search(section_pattern, query_lower)
    
    # If has section number or tax keywords, it's tax-related
    if has_section or has_tax_keyword:
        return True
    
    # If no tax keywords and query is very short (like "what is esther"), likely not tax-related
    if len(query.split()) < 5:
        return False
    
    return True


def classify_query_intent(query: str) -> dict:
    """Classify the user's query intent to adjust response style."""
    query_lower = query.lower()
    
    return {
        'wants_number_only': any(phrase in query_lower for phrase in [
            'number only', 'just number', 'give me a number', 'just the number'
        ]),
        'wants_brief': any(phrase in query_lower for phrase in [
            'one line', 'brief', 'short', 'quick', 'summary', 'in brief'
        ]),
        'wants_detailed': any(phrase in query_lower for phrase in [
            'explain', 'detail', 'elaborate', 'comprehensive', 'in detail'
        ]),
        'is_counting': query_lower.strip().startswith('how many'),
        'wants_list': any(phrase in query_lower for phrase in [
            'list', 'what are', 'which are', 'enumerate'
        ])
    }


def post_process_answer(answer: str, intent: dict, query: str) -> str:
    """Clean up and format the LLM response to prevent hallucinations."""
    has_sources_before = '📚' in answer
    answer = answer.strip()
    
    # Remove repetitive content (common LLM issue)
    lines = answer.split('\n')
    unique_lines = []
    seen = set()
    for line in lines:
        line_clean = line.strip()
        if line_clean and line_clean not in seen:
            unique_lines.append(line)
            seen.add(line_clean)
    
    answer = '\n'.join(unique_lines)
    
    # Check for hallucination indicators FIRST (before other processing)
    # Only block obvious hallucinations
    hallucination_phrases = [
        'as of my knowledge cutoff',
        'i do not have access to',
        'i don\'t have access to',
        'australia',
        'united states',
        'uk tax',
        'european union',
    ]
    
    answer_lower = answer.lower()
    
    # Special case: if answer says "I can't provide" but then provides info anyway, extract the info part
    if "i can't provide" in answer_lower or "i cannot provide" in answer_lower:
        # Check if there's useful content after the disclaimer
        parts = answer.split('?')
        if len(parts) > 1 and len(parts[1].strip()) > 50:
            # There's substantial content after the question, likely useful info
            pass  # Keep the full answer
        else:
            # Check other hallucination phrases
            for phrase in hallucination_phrases:
                if phrase in answer_lower:
                    return "This information is not available in my current tax knowledge base."
    else:
        # Check hallucination phrases normally
        for phrase in hallucination_phrases:
            if phrase in answer_lower:
                return "This information is not available in my current tax knowledge base."
    
    # Check for gibberish/nonsensical text (signs of hallucination)
    nonsense_indicators = ['noob', 'noble amendment noob', 'xyz unclear']
    for indicator in nonsense_indicators:
        if indicator in answer_lower:
            return "This information is not available in my current tax knowledge base."
    
    # If wants number only, extract just the number
    if intent.get('wants_number_only') or (intent.get('is_counting') and 'number' in query.lower()):
        # Check if answer says info not available
        if 'not available' in answer_lower or 'not specified' in answer_lower or 'don\'t have' in answer_lower:
            return "The exact number is not specified in the available documents."
        # Extract only the number
        numbers = re.findall(r'\b\d+\b', answer)
        if numbers:
            return numbers[0]
        else:
            return "The exact number is not specified in the available documents."
    
    # If wants brief/one-line, take only first paragraph BUT keep sources
    if intent.get('wants_brief'):
        # Check if answer has sources at the end
        if '📚 **Sources:**' in answer:
            # Split answer from sources
            parts = answer.split('📚 **Sources:**')
            main_answer = parts[0]
            sources_citation = '📚 **Sources:**' + parts[1]
            # Take first paragraph of answer
            paragraphs = main_answer.split('\n\n')
            brief_answer = paragraphs[0] if paragraphs else main_answer
            # Add sources back
            return brief_answer + '\n\n' + sources_citation
        else:
            paragraphs = answer.split('\n\n')
            return paragraphs[0] if paragraphs else answer
    
    # For detailed questions or list questions, don't truncate
    if intent.get('wants_detailed') or intent.get('wants_list') or 'how many' in query.lower():
        return answer
    
    # Only truncate if answer is extremely long (>1000 chars) for very simple questions
    if len(answer) > 1000 and not any(word in query.lower() for word in ['how', 'what', 'when', 'where', 'why', 'explain', 'describe', 'list']):
        # Take first 3 sentences but preserve sources
        if '📚 **Sources:**' in answer:
            parts = answer.split('📚 **Sources:**')
            main_answer = parts[0]
            sources_citation = '📚 **Sources:**' + parts[1]
            sentences = re.split(r'[.!?]\s+', main_answer)
            if len(sentences) >= 3:
                return '. '.join(sentences[:3]) + '.\n\n' + sources_citation
        else:
            sentences = re.split(r'[.!?]\s+', answer)
            if len(sentences) >= 3:
                return '. '.join(sentences[:3]) + '.'
    
    has_sources_after = '📚' in answer
    if has_sources_before and not has_sources_after:
        print(f"[post_process] WARNING: Sources were lost during processing!")
    
    return answer


def check_faq(query: str) -> str:
    """Check if query matches a common FAQ and return cached answer.
    Now checks BOTH tax_rates_faq.json and faqs.json for comprehensive coverage."""
    try:
        # Load both FAQ sources
        faq_files = [
            os.path.join(PROJECT_ROOT, "faq", "tax_rates_faq.json"),
            os.path.join(PROJECT_ROOT, "faq", "faqs.json")
        ]
        
        all_faqs = {}
        
        # Load tax_rates_faq.json (key-value format)
        if os.path.exists(faq_files[0]):
            with open(faq_files[0], 'r') as f:
                all_faqs.update(json.load(f))
        
        # Load faqs.json (array format) and convert to key-value
        if os.path.exists(faq_files[1]):
            with open(faq_files[1], 'r') as f:
                faqs_list = json.load(f)
                # Convert array to dict with id as key
                for faq_item in faqs_list:
                    all_faqs[faq_item['id']] = {
                        'question': faq_item['question'],
                        'answer': faq_item['answer'],
                        'tags': faq_item.get('tags', []),
                        'category': faq_item.get('category', '')
                    }
        
        print(f"[faq] Loaded {len(all_faqs)} FAQ entries from both sources")
        
        query_lower = query.lower().strip()
        
        # Direct key matching for better FAQ lookup
        # Order matters - more specific patterns first!
        faq_mapping = {
            'freelance income taxed': 'freelance_income_tax',
            'how is freelance income': 'freelance_income_tax',
            'freelance tax': 'freelance_income_tax',
            'when is tax audit required': 'tax_audit_requirement',
            'tax audit required': 'tax_audit_requirement',
            'tax audit mandatory': 'tax_audit_requirement',
            'tds rates for salary': 'tds_rates_salary',
            'tds on salary': 'tds_rates_salary',
            'salary tds': 'tds_rates_salary',
            'deadline for filing income tax': 'itr_filing_deadline',
            'itr filing deadline': 'itr_filing_deadline',
            'when to file itr': 'itr_filing_deadline',
            'due date for itr': 'itr_filing_deadline',
            'gst rate for restaurant': 'gst_rates_restaurants',
            'gst for restaurant': 'gst_rates_restaurants',
            'gst on restaurant': 'gst_rates_restaurants',
            'restaurant gst': 'gst_rates_restaurants',
            'difference between stcg and ltcg': 'stcg_vs_ltcg',
            'stcg vs ltcg': 'stcg_vs_ltcg',
            'capital gains tax rate': 'capital_gains_tax_rates',
            'short term capital gain': 'stcg_rate',
            'long term capital gain': 'ltcg_rate',
            'tax rate for income above 10 lakh': 'tax_rate_above_10_lakhs',
            'income above 10 lakh': 'tax_rate_above_10_lakhs',
            'who can opt for presumptive': 'who_can_opt_presumptive',
            'what is presumptive taxation': 'presumptive_taxation',
            'what are gst rate': 'gst_rates',
            'income tax slab': 'income_tax_slabs',
            'tax slab': 'income_tax_slabs',
            'standard deduction': 'standard_deduction',
            'input tax credit': 'input_tax_credit',
            'section 111a': 'section_111a',
            'section 112a': 'section_112a',
            'section 80c': 'section_80c',
            'section 80e': 'section_80e',
            'section 24': 'section_24',
            'what is gst': 'gst_definition',
            'presumptive': 'presumptive_taxation',
            'gst rate': 'gst_rates',
            'surcharge': 'surcharge',
            'capital gain': 'capital_gains_tax_rates',
            '111a': 'section_111a',
            '112a': 'section_112a',
            '80c': 'section_80c',
            '80e': 'section_80e',
            'stcg': 'stcg_rate',
            'ltcg': 'ltcg_rate',
            'cess': 'cess',
        }
        
        # Check for direct FAQ matches
        for pattern, faq_key in faq_mapping.items():
            if pattern in query_lower:
                if faq_key in all_faqs:
                    print(f"[faq] Matched pattern '{pattern}' → {faq_key}")
                    return all_faqs[faq_key]['answer']
        
        # Also check faqs.json by semantic matching on questions and tags
        best_match = None
        highest_score = 0
        
        for faq_id, faq_data in all_faqs.items():
            if 'question' not in faq_data:
                continue
                
            faq_question = faq_data['question'].lower()
            tags = [tag.lower() for tag in faq_data.get('tags', [])]
            
            # Calculate simple keyword overlap score
            query_words = set(query_lower.split())
            faq_words = set(faq_question.split())
            tag_words = set(' '.join(tags).split())
            
            # Score based on word overlap
            question_overlap = len(query_words & faq_words) / max(len(query_words), 1)
            tag_overlap = len(query_words & tag_words) / max(len(query_words), 1)
            
            score = question_overlap * 0.7 + tag_overlap * 0.3
            
            if score > highest_score and score > 0.4:  # Threshold for match
                highest_score = score
                best_match = faq_data
        
        if best_match:
            print(f"[faq] Semantic match found (score: {highest_score:.2f})")
            return best_match['answer']
        
        return None
    except Exception as e:
        print(f"[faq] Error checking FAQ: {e}")
        return None


def answer_with_llm(query: str, context_chunks: list):
    """Generate answer using local Ollama LLM or fallback to Hugging Face."""
    
    # Check FAQ first for common questions
    faq_answer = check_faq(query)
    if faq_answer:
        print("[faq] Found answer in FAQ database")
        return faq_answer
    
    # Pre-filter: Check if question is tax-related before calling LLM
    if not is_tax_related_query(query):
        return "I apologize, but I can only answer questions about Indian taxation. Please ask a question related to income tax, GST, capital gains, deductions, or other Indian tax matters."
    
    # Check if we have relevant context
    if not context_chunks:
        return "I couldn't find relevant information about this in my tax knowledge base. Please try rephrasing your question or ask about a different topic."
    
    # Check chunk quality: warn if chunks are too short (may indicate poor retrieval)
    avg_chunk_length = sum(len(c.get('text', '')) for c in context_chunks) / len(context_chunks)
    if avg_chunk_length < 100:
        print(f"[warning] Retrieved chunks seem short (avg {avg_chunk_length:.0f} chars)")
    
    # Classify query intent
    intent = classify_query_intent(query)
    query_lower = query.lower()
    
    # Build context with source tracking - smarter trimming
    context_with_sources = []
    total_context_chars = 0
    max_context_chars = 10000  # Increased limit (~2500 tokens)
    chunks_included = 0
    
    # Calculate how much space each chunk gets
    space_per_chunk = max_context_chars // min(len(context_chunks), 6)
    
    for i, chunk in enumerate(context_chunks, 1):
        source = chunk.get('metadata', {}).get('source', 'Tax Document')
        text = chunk.get('text', '')
        
        # Trim chunk to fit available space, keeping most relevant content
        if len(text) > space_per_chunk:
            # Keep first 80% of available space (most relevant usually at start)
            trim_length = int(space_per_chunk * 0.8)
            text = text[:trim_length] + "..."
        
        chunk_entry = f"[Source {i}: {source}]\n{text}"
        
        # Check if we can fit this chunk
        if total_context_chars + len(chunk_entry) > max_context_chars:
            # Try to fit a smaller version
            remaining_space = max_context_chars - total_context_chars
            if remaining_space > 500:  # Only add if meaningful space
                text = text[:remaining_space - 100] + "..."
                chunk_entry = f"[Source {i}: {source}]\n{text}"
                context_with_sources.append(chunk_entry)
                total_context_chars += len(chunk_entry)
                chunks_included += 1
            print(f"[context] Used {chunks_included}/{len(context_chunks)} chunks (trimmed to fit)")
            break
            
        context_with_sources.append(chunk_entry)
        total_context_chars += len(chunk_entry)
        chunks_included += 1
    
    context_text = "\n\n".join(context_with_sources)
    print(f"[context] Total context: {total_context_chars} chars (~{total_context_chars//4} tokens)")
    
    # Calculate dynamic token allocation based on query complexity
    def calculate_tokens_needed(query: str, intent: dict, context_length: int) -> int:
        """Dynamically determine tokens based on query complexity"""
        base_tokens = 400  # Increased from 250 for more complete answers
        query_lower = query.lower()
        
        # Simple queries need fewer tokens
        if intent.get('wants_number_only') or intent.get('wants_brief'):
            return 150
        
        # Counting/listing queries need more tokens
        if intent.get('wants_list') or 'how many' in query_lower or 'list all' in query_lower:
            return 1500  # Much more for comprehensive lists
        
        # "How is X taxed" or "How is X calculated" questions need lots of tokens (step-by-step explanations)
        if ('how is' in query_lower or 'how are' in query_lower) and ('tax' in query_lower or 'calculat' in query_lower):
            return 1500  # These need comprehensive step-by-step answers
        
        # Detailed explanations need more tokens
        if intent.get('wants_detailed') or 'explain' in query_lower or 'detail' in query_lower:
            return 1200
        
        # Questions about rates/calculations need moderate tokens
        if 'rate' in query_lower or 'calculate' in query_lower or 'how to' in query_lower:
            return 1000  # Increased from 800
        
        # Adjust based on context length (more context = likely more complex answer)
        context_tokens = context_length // 4  # Rough estimate
        if context_tokens > 2000:
            return 1500  # Large context = complex topic, need MORE room
        elif context_tokens > 1000:
            return 1200  # Increased from 1000
        
        return base_tokens
    
    # Define confidence calculation function first
    def calculate_confidence(context_chunks: list) -> tuple:
        """Calculate confidence based on retrieval scores"""
        if not context_chunks:
            return 0.0, "LOW"
        
        scores = [chunk.get('score', 0) for chunk in context_chunks]
        avg_score = sum(scores) / len(scores) if scores else 0
        
        # Adjusted thresholds based on typical hybrid scores (0.5-0.7 range)
        if avg_score >= 0.60:
            return avg_score, "HIGH"
        elif avg_score >= 0.50:
            return avg_score, "MEDIUM"
        else:
            return avg_score, "LOW"
    
    # Calculate confidence FIRST (needed for token allocation)
    confidence_score, confidence_level = calculate_confidence(context_chunks)
    
    # Calculate required tokens for this query
    base_required = calculate_tokens_needed(query, intent, len(context_text))
    
    # Boost token allocation based on confidence level
    # HIGH confidence = good retrieval, likely needs detailed answer
    if confidence_level == "HIGH":
        required_tokens = min(int(base_required * 1.3), 1800)  # 30% boost for HIGH confidence
    elif confidence_level == "MEDIUM":
        required_tokens = min(int(base_required * 1.2), 1500)  # 20% boost for MEDIUM
    else:
        required_tokens = base_required
    
    print(f"[llm] Allocating {required_tokens} tokens for this query (confidence: {confidence_level})")

    # Adjust instructions based on intent
    if intent['wants_number_only'] or (intent['is_counting'] and 'number' in query_lower):
        response_instruction = "Respond with ONLY a number (nothing else) if the exact number is stated in the context. If the context does NOT contain this specific number, respond EXACTLY with: 'The exact number is not specified in the available documents.'"
    elif intent['wants_brief']:
        response_instruction = "Provide a concise one-line answer using ONLY facts from the context. If the answer is not in the context, say so."
    elif intent['wants_detailed']:
        response_instruction = "Provide a comprehensive answer covering all relevant details from the context. Only include information explicitly stated."
    elif intent['wants_list'] or 'what deductions' in query_lower or 'which deductions' in query_lower:
        response_instruction = "Provide a clear numbered list of all items explicitly mentioned in the context. Do not add items not in the context."
    elif re.search(r'what is (section )?80[a-z]+', query_lower):
        response_instruction = "First state what the section does in one sentence, then list the key points or eligible items if mentioned in the context."
    elif 'how many' in query_lower or 'number of' in query_lower:
        response_instruction = "Provide a comprehensive answer listing all relevant items, categories, or numbers mentioned in the documents. Structure as a numbered or bulleted list with clear categories. Include all details and complete the entire list."
    elif 'rate' in query_lower or 'tds' in query_lower:
        response_instruction = "Extract and state all tax rates or TDS rates mentioned in the documents. Include rate percentages, applicable income ranges, conditions, and any variations based on dates or circumstances. Provide complete rate information."
    elif 'how' in query_lower and 'tax' in query_lower:
        response_instruction = "Explain the taxation mechanism described in the documents. Include applicable sections, rate structure, exemptions, deductions, and calculation method if mentioned. Provide step-by-step guidance if available."
    elif 'deadline' in query_lower or 'due date' in query_lower or ('when' in query_lower and 'file' in query_lower):
        response_instruction = "Extract all deadlines, due dates, and time periods mentioned in the documents. Include specific dates, conditions, and penalties for late compliance if mentioned."
    else:
        response_instruction = "Provide a clear and comprehensive answer (4-6 sentences) using all relevant information from the documents. Include rates, sections, conditions, and practical details. Be thorough and complete your response."

    # Confidence was already calculated earlier (needed for token allocation)
    print(f"[llm] Confidence: {confidence_level} (score: {confidence_score:.2f})")
    
    # Build a more effective prompt that encourages complete answers
    # Only add disclaimers if confidence is LOW
    if confidence_level == "LOW":
        system_prompt = """You are Finora, an Indian tax information assistant.

The retrieved information has limited direct relevance. Be transparent but helpful.

GUIDELINES:
• Acknowledge if information is not directly available
• Provide related information that may help answer the question
• Keep it concise and factual
• Suggest what specific information would be needed for a complete answer

Be honest about limitations."""
    elif confidence_level == "MEDIUM":
        system_prompt = """You are Finora, a knowledgeable Indian tax information assistant.

The retrieved information is moderately relevant. Answer based on what's available.

GUIDELINES:
• Use the information provided, even if not perfectly aligned
• Be direct - avoid excessive disclaimers
• Explain rates, sections, amounts, conditions clearly
• Structure answers with bullet points or numbered lists
• Complete all sentences - never stop mid-thought
• Focus on factual information from the documents

Provide a clear, helpful answer based on the available information."""
    else:  # HIGH confidence
        system_prompt = """You are Finora, an expert Indian tax information assistant.

Provide clear, accurate tax information based on the official documents provided.

GUIDELINES:
• Be direct and confident - the information is from official tax documents
• Structure answers clearly using bullet points or numbered lists
• Include all relevant rates, sections, amounts, conditions, and dates
• Cite specific sections when mentioned (e.g., "Section 80C", "Section 112A")
• For comparisons, show both options with pros/cons
• Complete all thoughts - never stop mid-sentence
• Provide factual information, not personalized advice

Answer comprehensively using the tax information provided."""

    user_prompt = f"""TAX DOCUMENTS:
{context_text}

QUESTION: {query}

TASK: {response_instruction}

Answer the question completely using the information above. Structure your response clearly and include all relevant details."""

    # Try Ollama first (local, fast, free)
    try:
        import ollama
        import signal
        
        # Check if we should disable signal-based timeouts (e.g., when running in Flask)
        # Also disable on Windows where signal.SIGALRM is not available
        use_signal_timeout = (os.environ.get('DISABLE_SIGNAL_TIMEOUT') != '1' and 
                             platform.system() != 'Windows')
        
        # Timeout handler to prevent hanging (Unix/macOS only)
        class TimeoutError(Exception):
            pass
        
        def timeout_handler(signum, frame):
            raise TimeoutError("LLM request timed out")
        
        # Try llama3.2 first (installed and fast), then phi3
        # llama3.2 is better for detailed tax responses
        models_to_try = ['llama3.2', 'phi3']
        max_retries = 2  # Limit retries per model to prevent infinite loops
        
        for model in models_to_try:
            retry_count = 0
            while retry_count < max_retries:
                try:
                    # Set 60 second timeout for LLM calls (reduced from 90s for faster failure)
                    # Signal timeouts only available on Unix/macOS, not Windows
                    if use_signal_timeout:
                        signal.signal(signal.SIGALRM, timeout_handler)
                        signal.alarm(60)
                    
                    response = ollama.chat(
                        model=model,
                        messages=[
                            {'role': 'system', 'content': system_prompt},
                            {'role': 'user', 'content': user_prompt}
                        ],
                        options={
                            'temperature': 0.1,  # Slightly higher for more fluent responses
                            'top_p': 0.95,
                            'top_k': 50,
                            'num_predict': required_tokens,  # Dynamic token allocation
                            'repeat_penalty': 1.15,
                            'num_ctx': 4096,  # Larger context window for more complete answers
                            'stop': [],  # Don't stop early
                        }
                    )
                    
                    # Cancel timeout on success (only if it was set)
                    if use_signal_timeout:
                        signal.alarm(0)
                    
                    answer = response['message']['content']
                    
                    # Validate answer quality
                    if not validate_answer_quality(answer, query, intent, required_tokens, confidence_level):
                        retry_count += 1
                        if retry_count < max_retries:
                            print(f"[llm] Answer quality check failed, retry {retry_count}/{max_retries}...")
                            # Retry with more tokens if answer was too short
                            if len(answer) < 250:
                                required_tokens = min(int(required_tokens * 1.5), 2000)
                            continue
                        else:
                            print(f"[llm] Max retries reached, using best available answer")
                            # Use the answer anyway if we've exhausted retries
                            pass
                    
                    # Add source citations
                    answer_with_sources = add_source_citations(answer, context_chunks)
                    return post_process_answer(answer_with_sources, intent, query)
                    
                except TimeoutError:
                    if use_signal_timeout:
                        signal.alarm(0)  # Cancel timeout
                    print(f"[llm] Model {model} timed out, trying next...")
                    break  # Break inner loop, go to next model
                except Exception as model_error:
                    if use_signal_timeout:
                        signal.alarm(0)  # Cancel timeout
                    print(f"[llm] Model {model} failed: {str(model_error)[:50]}")
                    retry_count += 1
                    if retry_count >= max_retries:
                        break  # Try next model
                    continue  # Retry same model
                
    except Exception as ollama_error:
        print(f"[llm] Ollama unavailable: {ollama_error}")
        pass
    
    # Fallback to Hugging Face if Ollama fails
    if not os.getenv('HF_TOKEN'):
        print("[llm] No HF_TOKEN found - showing retrieved context instead")
        return format_retrieved_context(query, context_chunks)
    
    try:
        from huggingface_hub import InferenceClient
        client = InferenceClient(token=os.getenv('HF_TOKEN'))
        
        # Try multiple models in order of preference
        models = [
            "microsoft/Phi-3-mini-4k-instruct",
            "mistralai/Mistral-7B-Instruct-v0.3",
        ]
        
        # Combine system and user prompt for HF
        combined_prompt = f"{system_prompt}\n\n{user_prompt}"
        
        # Scale HF tokens (HF needs slightly more due to different tokenization)
        hf_tokens = min(int(required_tokens * 1.2), 2000)
        
        for model in models:
            try:
                messages = [{"role": "user", "content": combined_prompt}]
                
                response = client.chat_completion(
                    messages=messages,
                    model=model,
                    max_tokens=hf_tokens,  # Dynamic token allocation
                    temperature=0.1,  # Slightly higher for more fluent responses
                    top_p=0.95
                )
                
                answer = response.choices[0].message.content
                
                # Validate answer quality
                if not validate_answer_quality(answer, query, intent, hf_tokens, confidence_level):
                    print(f"[llm] Answer quality check failed for HF response")
                
                # Add source citations
                answer_with_sources = add_source_citations(answer, context_chunks)
                return post_process_answer(answer_with_sources, intent, query)
                
            except Exception:
                continue
        
        # If all models fail, return formatted context
        print("[llm] All API models unavailable - showing retrieved documents")
        return format_retrieved_context(query, context_chunks)
        
    except Exception:
        print(f"[llm] API error - showing retrieved documents")
        return format_retrieved_context(query, context_chunks)


def validate_answer_quality(answer: str, query: str, intent: dict, allocated_tokens: int, confidence: str) -> bool:
    """
    Validate if answer is complete and useful based on query needs, not just length.
    Returns True if answer passes quality checks, False if should regenerate.
    """
    query_lower = query.lower()
    answer_lower = answer.lower()
    
    # Check 1: Overly cautious without useful content (priority check)
    cautious_phrases = [
        "i can't provide",
        "i cannot provide", 
        "i'm not able to",
        "i don't have access"
    ]
    
    if any(phrase in answer_lower for phrase in cautious_phrases):
        # If answer is ONLY disclaimers/warnings with no actual info, it's bad
        # Check if there's substantive content (numbers, specific terms, examples)
        substantive_indicators = [
            'section ', '₹', '%', 'rs.', 'lakh', 'crore',
            'according to', 'under ', 'deduction', 'exemption',
            'rate', 'limit', 'threshold', 'year', 'months'
        ]
        has_substance = any(indicator in answer_lower for indicator in substantive_indicators)
        
        # Only fail if LOW confidence AND no substance
        # For MEDIUM/HIGH, allow cautious phrases if there's actual content
        if not has_substance and confidence == "LOW":
            print(f"[quality] FAIL: Overly cautious without substantive information")
            return False
        elif not has_substance:
            # MEDIUM/HIGH confidence but no substance - warn but don't retry
            print(f"[quality] WARN: Cautious phrasing but has {confidence} confidence")
    
    # Check 2: Cut off mid-sentence (actually incomplete)
    if answer and len(answer) > 50:
        last_char = answer.strip()[-1]
        answer_end = answer.strip()[-50:]  # Check last 50 chars
        
        # Check for common incomplete patterns
        incomplete_patterns = [
            '...',  # Truncated
            'wi...',  # Mid-word truncation
            'of p',  # Incomplete phrase
            'the computation',  # Unfinished computation explanation
        ]
        
        if any(pattern in answer_end.lower() for pattern in incomplete_patterns):
            print(f"[quality] FAIL: Answer appears truncated (ends: '{answer_end[-30:]}')")
            return False
        
        if last_char not in '.!?':
            # Check if truly incomplete (ends with connector words or prepositions)
            last_words = answer.strip().split()[-3:]  # Check last 3 words
            incomplete_endings = ['the', 'a', 'an', 'is', 'are', 'was', 'were', 'and', 'or', 'but', 'for', 'with', 'under', 'to', 'of', 'in', 'on', 'at', 'by', 'from']
            if any(word.lower() in incomplete_endings for word in last_words):
                print(f"[quality] FAIL: Incomplete sentence (ends with: '{' '.join(last_words)}')")
                return False
    
    # Check 3: For comparison queries, ensure both items mentioned
    comparison_keywords = [' vs ', ' versus ', 'difference between', 'compare', 'better']
    if any(kw in query_lower for kw in comparison_keywords):
        # Extract comparison items (e.g., "ELSS vs PPF" -> ["ELSS", "PPF"])
        words = query.upper().split()
        if ' VS ' in query.upper() or ' VERSUS ' in query.upper():
            # Both items should appear in answer
            comparison_items = [w for w in words if len(w) > 2 and w not in ['VS', 'VERSUS', 'THE', 'AND', 'OR']]
            if len(comparison_items) >= 2:
                items_in_answer = sum(1 for item in comparison_items[:2] if item in answer.upper())
                if items_in_answer < 2:
                    print(f"[quality] FAIL: Comparison query but only mentions {items_in_answer}/2 items")
                    return False
    
    # Check 4: Severe token/output mismatch (allocated lots but got almost nothing)
    # This catches cases where LLM failed but didn't error
    if allocated_tokens >= 1000 and len(answer) < 150:
        # Unless it's a simple yes/no or number-only query
        if not intent.get('wants_brief') and not intent.get('wants_number_only'):
            print(f"[quality] FAIL: Allocated {allocated_tokens} tokens but only got {len(answer)} chars")
            return False
    
    # Check 5: Answer is just "Based on..." or "According to..." without actual answer
    filler_starts = ['based on the provided', 'according to the text', 'the provided information']
    if any(answer_lower.startswith(filler) for filler in filler_starts):
        # If it starts with filler but has no substance after, fail
        if len(answer) < 100:
            print(f"[quality] FAIL: Starts with filler phrase but no actual content")
            return False
    
    print(f"[quality] PASS: {len(answer)} chars, {len(answer.split())} words")
    return True


def add_source_citations(answer: str, context_chunks: list) -> str:
    """Add source citations to the answer for credibility and verification."""
    if not context_chunks:
        print("[sources] No chunks provided")
        return answer
    
    # Extract unique sources from top chunks
    sources = []
    seen_sources = set()
    
    for i, chunk in enumerate(context_chunks[:3]):  # Top 3 most relevant sources
        # Handle both dict with 'metadata' and raw text chunks
        if isinstance(chunk, dict):
            metadata = chunk.get('metadata', {})
            if isinstance(metadata, dict):
                source = metadata.get('source', 'Tax Document')
            else:
                source = 'Tax Document'
        else:
            source = 'Tax Document'
        
        # Clean up source name and add if meaningful
        if source and source != 'Tax Document' and source not in seen_sources:
            sources.append(source)
            seen_sources.add(source)
    
    # Always add sources if we have meaningful ones
    if sources:
        print(f"[sources] Adding {len(sources)} sources: {sources}")
        citation = "\n\n📚 **Sources:** " + ", ".join(sources)
        return answer + citation
    else:
        print(f"[sources] No meaningful sources found from {len(context_chunks[:3])} chunks")
    
    # Return answer unchanged if no sources found
    return answer
    
    return answer


def format_retrieved_context(query: str, context_chunks: list) -> str:
    """Format the retrieved context in a readable way when LLM is unavailable."""
    result = f"📚 **Found {len(context_chunks)} relevant sections about: {query}**\n\n"
    
    for i, chunk in enumerate(context_chunks, 1):
        source = chunk.get('metadata', {}).get('source', 'Unknown')
        text = chunk.get('text', '')
        # Clean up the text
        text = text.replace('\n', ' ').strip()
        # Take first 300 chars
        preview = text[:300] + "..." if len(text) > 300 else text
        result += f"**{i}. Source: {source}**\n{preview}\n\n"
    
    result += "\n💡 *Note: Install a local LLM or configure HF API for AI-generated answers*"
    return result


def query_rag(query: str, top_k=8):  # Increased from 5 to 8 for better coverage
    """Main entry for querying the RAG system."""
    
    # Step 1: Route query → which indices
    indices = route_query(query)

    print(f"[router] Query routed to indices → {', '.join(indices)}")

    # Step 2: Get top matches from all relevant indices
    all_matches = []
    for index_name in indices:
        try:
            matches = search_vectors(query, index_name, top_k=top_k)
            all_matches.extend(matches)
        except FileNotFoundError:
            print(f"[warning] Index {index_name} not found, skipping")
    
    # Sort all matches by score and take top_k
    all_matches.sort(reverse=True, key=lambda x: x[0])
    top_matches = all_matches[:top_k]
    
    # Log similarity scores for debugging
    if top_matches:
        print(f"[search] Top similarity scores: {[f'{m[0]:.3f}' for m in top_matches[:3]]}")
    
    # Keep both chunks and their scores for confidence calculation
    chunks = [{'text': m[1].get('text', ''), 'metadata': m[1].get('metadata', {}), 'score': m[0]} for m in top_matches]
    print(f"[search] Retrieved {len(chunks)} chunks from {len(indices)} indices")

    # Step 3: Generate LLM answer using retrieved context
    answer = answer_with_llm(query, chunks)

    return answer


# CLI
if __name__ == "__main__":
    print("Finora RAG Query Engine\n")

    while True:
        q = input("Ask Finora → ").strip()
        if q.lower() in ["exit", "quit"]:
            break

        try:
            reply = query_rag(q)
            print("\n---- Answer ----")
            print(reply)
            print("\n----------------\n")

        except Exception as e:
            print(f"[error] {e}")
