from flask import Flask, request, jsonify, Response, stream_with_context
from flask_cors import CORS
import sys
import os
import time
import json
import re
import tempfile

# Add parent directory to path to import from data/scripts
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'data', 'scripts'))

# Disable signal-based timeouts — signals don't work reliably inside Flask threads
os.environ['DISABLE_SIGNAL_TIMEOUT'] = '1'

from run_query import query_rag, query_rag_stream   # ← added query_rag_stream

# Import OCR and PDF libraries
try:
    import pytesseract
    from PIL import Image
    import pdf2image
    import PyPDF2
    import io
    HAS_OCR = True
except ImportError:
    HAS_OCR = False
    print("⚠️  Warning: OCR libraries not installed. Install with: pip install pytesseract pdf2image pillow PyPDF2")

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter

print("=" * 60)
print("🚀 Finora AI Tax Advisor API Starting...")
print("=" * 60)


# ── Health ────────────────────────────────────────────────────────────────────

@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'healthy',
        'service': 'Finora AI Tax Advisor',
        'version': '1.0.0'
    })


# ── Non-streaming query (unchanged) ──────────────────────────────────────────

@app.route('/query', methods=['POST'])
def query():
    """
    Non-streaming query endpoint.

    Request:  { "query": "What is Section 80C?" }
    Response: { "success": true, "query": "...", "answer": "...", "processing_time": 1.23 }
    """
    try:
        data = request.json
        user_query = data.get('query', '').strip()

        if not user_query:
            return jsonify({'success': False, 'error': 'No query provided'}), 400

        print(f"\n📝 Query received: {user_query}")
        start_time = time.time()

        answer = query_rag(user_query, top_k=8)

        processing_time = time.time() - start_time
        print(f"✅ Answer generated in {processing_time:.2f}s")

        return jsonify({
            'success': True,
            'query': user_query,
            'answer': answer,
            'processing_time': round(processing_time, 2)
        })

    except Exception as e:
        print(f"❌ Error: {str(e)}")
        import traceback; traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


# ── Real streaming query ──────────────────────────────────────────────────────

@app.route('/query/stream', methods=['POST'])
def query_stream():
    """
    True streaming query endpoint using Server-Sent Events (SSE).

    Tokens are forwarded to the client as they come out of Ollama —
    no waiting for the full answer to be generated first.

    Request:  { "query": "What is Section 80C?" }

    Response stream (text/event-stream):
        data: {"chunk": "Section", "done": false}
        data: {"chunk": " 80C", "done": false}
        ...
        data: {"chunk": ".", "done": false}
        data: {"done": true}

    Client-side (Flutter / JavaScript) should:
        1. Listen to the SSE stream.
        2. Append each `chunk` value to the displayed text.
        3. Stop when `done == true`.

    Error response (non-streaming, HTTP 400/500):
        { "success": false, "error": "..." }
    """
    try:
        data = request.json
        query_text = data.get('query', '').strip()

        if not query_text:
            return jsonify({'success': False, 'error': 'No query provided'}), 400

        print(f"\n📡 Stream query received: {query_text}")

        def generate():
            try:
                for token in query_rag_stream(query_text, top_k=8):
                    # Each token is a small string (one or a few words)
                    payload = json.dumps({'chunk': token, 'done': False})
                    yield f"data: {payload}\n\n"

                # Signal completion
                yield f"data: {json.dumps({'done': True})}\n\n"

            except Exception as gen_err:
                # Surface errors inside the stream so clients can handle them
                error_payload = json.dumps({'error': str(gen_err), 'done': True})
                yield f"data: {error_payload}\n\n"

        return Response(
            stream_with_context(generate()),
            mimetype='text/event-stream',
            headers={
                'Cache-Control':    'no-cache',
                'X-Accel-Buffering': 'no',   # disable nginx buffering if behind a proxy
            }
        )

    except Exception as e:
        print(f"❌ Stream setup error: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ── Suggestions ───────────────────────────────────────────────────────────────

@app.route('/suggestions', methods=['POST'])
def suggestions():
    """
    Get smart query suggestions based on user's income / deduction context.

    Request:  { "income": 1000000, "deductions": 50000 }
    Response: { "success": true, "suggestions": [...] }
    """
    try:
        data = request.json
        income = data.get('income', 0)
        deductions = data.get('deductions', 0)

        result = []

        if income > 1000000:
            result.append("Should I choose Old Regime or New Regime for high income?")
            result.append("What are the tax rates for income above ₹10 lakhs?")

        if deductions < 150000:
            result.append("How can I maximize my Section 80C deductions?")
            result.append("What investments qualify for Section 80C?")

        if deductions < 200000:
            result.append("What is Section 80CCD(1B) and how can I save ₹50,000 more?")

        result.extend([
            "What are the GST rates for different services?",
            "How is capital gains tax calculated on equity?",
            "What is the difference between STCG and LTCG?",
            "What deductions are available under the new tax regime?",
            "How does presumptive taxation work for businesses?",
        ])

        return jsonify({'success': True, 'suggestions': result[:8]})

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


# ── Income extraction from Form 16 / images ───────────────────────────────────

@app.route('/api/extract-income', methods=['POST'])
def extract_income():
    """
    Extract income details from an uploaded PDF or image (e.g. Form 16).

    Request:  multipart/form-data with 'file' field (PDF / JPG / PNG)
    Response: { "grossSalary": 1832392, "taxableSalary": 1757392,
                "otherIncome": 0, "rentalIncome": 0, "businessIncome": 0,
                "partBMissing": false }

    If only Part A is present (no Part B / Annexure), taxableSalary will be 0
    and partBMissing will be true — the Flutter UI should show a warning.
    """
    if not HAS_OCR:
        return jsonify({'error': 'OCR libraries not installed'}), 500

    try:
        if 'file' not in request.files:
            return jsonify({'error': 'No file provided'}), 400

        file = request.files['file']
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400

        filename = file.filename.lower()
        is_pdf   = filename.endswith('.pdf')
        is_image = filename.endswith(('.jpg', '.jpeg', '.png'))

        if not (is_pdf or is_image):
            return jsonify({'error': 'Invalid file type. Please upload PDF or image'}), 400

        print(f"\n📄 Processing file: {filename}")
        file_bytes = file.read()

        extracted_text = ""

        if is_pdf:
            try:
                pdf_reader = PyPDF2.PdfReader(io.BytesIO(file_bytes))
                for page_num, page in enumerate(pdf_reader.pages):
                    extracted_text += page.extract_text() + f"\n---PAGE {page_num + 1} END---\n"
                print(f"✅ PyPDF2 extracted {len(extracted_text)} chars")

                if len(extracted_text.strip()) < 100:
                    raise Exception("PDF appears to be scanned, switching to OCR")

            except Exception as pdf_err:
                print(f"⚠️  PyPDF2 failed ({pdf_err}), using OCR...")
                with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp:
                    tmp.write(file_bytes)
                    tmp_path = tmp.name
                try:
                    images = pdf2image.convert_from_path(tmp_path)
                    for i, image in enumerate(images[:5]):
                        extracted_text += pytesseract.image_to_string(image) + f"\n---PAGE {i + 1} END---\n"
                    print(f"✅ OCR extracted {len(extracted_text)} chars")
                finally:
                    if os.path.exists(tmp_path):
                        os.remove(tmp_path)
        else:
            with tempfile.NamedTemporaryFile(delete=False) as tmp:
                tmp.write(file_bytes)
                tmp_path = tmp.name
            try:
                extracted_text = pytesseract.image_to_string(Image.open(tmp_path))
                print(f"✅ Image OCR extracted {len(extracted_text)} chars")
            finally:
                if os.path.exists(tmp_path):
                    os.remove(tmp_path)

        print(f"\n📝 Text preview:\n{extracted_text[:500]}\n")
        income_data = _parse_income_data(extracted_text)
        print(f"✅ Parsed income: {income_data}\n")
        return jsonify(income_data), 200

    except Exception as e:
        print(f"❌ Error extracting income: {str(e)}")
        import traceback; traceback.print_exc()
        return jsonify({'error': str(e)}), 500


def _has_part_b(text_lower):
    """
    Returns True if the text contains Part B (Annexure) of Form 16.
    Part B is identified by the presence of section 6 (income chargeable
    under salaries) or the 'part b' / 'annexure' heading.
    """
    indicators = [
        r'part\s*b',
        r'annexure',
        r'income\s+chargeable\s+under\s+the\s+head\s+.salaries',
        r'6\.\s*income\s+chargeable',
        r'details\s+of\s+salary\s+paid',
    ]
    for pat in indicators:
        if re.search(pat, text_lower, re.IGNORECASE):
            return True
    return False


def _parse_income_data(text):
    """
    Parse income figures from Form 16 text.
    Returns dict with grossSalary, taxableSalary, otherIncome,
    rentalIncome, businessIncome (all integers, default 0),
    and partBMissing (bool) — True when only Part A was found.
    """
    text_lower = text.lower()
    text_norm  = text.replace(',', '')
    text_lower_norm = text_lower.replace(',', '')

    result = {
        'grossSalary':    0,
        'taxableSalary':  0,
        'otherIncome':    0,
        'rentalIncome':   0,
        'businessIncome': 0,
        'partBMissing':   False,
    }

    # FIX 1: min_value guard — rejects stray single/double digit matches
    # (e.g. page numbers, section numbers) that are not real income values.
    def safe_int(match, min_value=100):
        try:
            if match:
                s = re.sub(r'[^\d.]', '', match.group(1))
                s = s.replace('.00', '').replace('.0', '')
                val = int(float(s)) if s else 0
                return val if val >= min_value else 0
        except Exception:
            pass
        return 0

    # ── Gross salary — Form 16 Part B section 1(d) or Part A quarterly total ──
    #
    # Part A quarterly summary table looks like:
    #   Quarter | Receipt No | Amount paid/credited | Tax deducted | Tax deposited
    #   Total (Rs.)          3440592.53             728555.00      728555.00
    #
    # The three numbers on the Total row appear in order: paid, deducted, deposited.
    # We want the FIRST (largest) number — amount paid/credited — not the TDS total.
    # Strategy: capture all three numbers on the Total row and take the largest,
    # since gross salary is always greater than TDS deducted.

    for pat in [
        # Part B: section 1(d) total
        r'd\)\s*total\s*rs\.?\s*([\d.]+)',
        r'gross\s+salary.*?total.*?rs\.?\s*([\d.]+)',
        r'salary\s+as\s+per.*?17\(1\).*?rs\.?\s*([\d.]+)',
    ]:
        m = re.search(pat, text_lower_norm, re.DOTALL | re.IGNORECASE)
        if m:
            result['grossSalary'] = safe_int(m)
            if result['grossSalary']:
                print(f"✅ Gross Salary (Part B): ₹{result['grossSalary']:,}")
                break

    # Part A fallback: find the Total row in the quarterly summary and take
    # the largest number (amount paid/credited > tax deducted = tax deposited)
    if result['grossSalary'] == 0:
        m = re.search(r'total\s*\(rs\.\)\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)',
                      text_lower_norm, re.IGNORECASE)
        if m:
            candidates = [safe_int(type('', (), {'group': lambda self, i, m=m: m.group(i)})(), min_value=100)
                          for _ in [1]]  # placeholder, use manual approach below
            # Extract all three values and pick the largest (= amount paid/credited)
            vals = []
            for i in (1, 2, 3):
                try:
                    s = re.sub(r'[^\d.]', '', m.group(i)).replace('.00', '').replace('.0', '')
                    vals.append(int(float(s)) if s else 0)
                except Exception:
                    vals.append(0)
            gross = max(vals)
            if gross >= 100:
                result['grossSalary'] = gross
                print(f"✅ Gross Salary (Part A quarterly total): ₹{result['grossSalary']:,}")

    # ── Detect whether Part B is present ──────────────────────────────────────
    if not _has_part_b(text_lower):
        print("⚠️  Part B (Annexure) not found — only gross salary will be returned")
        result['partBMissing'] = True
        print(f"\n📊 Final parsed data: {result}\n")
        return result  # Return early; no point parsing fields that don't exist

    # ── Taxable salary — Form 16 Part B section 6 ────────────────────────────
    for pat in [
        r'6\.\s*income\s+chargeable.*?salaries.*?rs\.?\s*([\d.]+)',
        r'income\s+chargeable.*?head.*?salaries.*?rs\.?\s*([\d.]+)',
        r'taxable\s+salary[:\s]*rs\.?\s*([\d.]+)',
    ]:
        m = re.search(pat, text_lower_norm, re.DOTALL | re.IGNORECASE)
        if m:
            result['taxableSalary'] = safe_int(m)
            if result['taxableSalary']:
                print(f"✅ Taxable Salary: ₹{result['taxableSalary']:,}")
                break

    # ── Rental income — Form 16 Part B section 7(a) ──────────────────────────
    for pat in [
        r'7.*?a\).*?house\s+property.*?rs\.?\s*([\d.]+)',
        r'income.*?house\s+property[:\s]*rs\.?\s*([\d.]+)',
        r'rental\s+income[:\s]*rs\.?\s*([\d.]+)',
    ]:
        m = re.search(pat, text_lower_norm, re.DOTALL | re.IGNORECASE)
        if m:
            result['rentalIncome'] = safe_int(m)
            if result['rentalIncome']:
                print(f"✅ Rental Income: ₹{result['rentalIncome']:,}")
                break

    # FIX 2: Tighter other income patterns — must match the full field label
    # to avoid picking up stray numbers (page refs, section numbers, etc.)
    for pat in [
        r'\(b\)\s*income\s+under\s+the\s+head\s+other\s+sources\s+rs\.?\s*([\d.]+)',
        r'7\s*\.\s*(?:add\s*:)?\s*any\s+other\s+income.*?\(b\).*?other\s+sources.*?rs\.?\s*([\d.]+)',
    ]:
        m = re.search(pat, text_lower_norm, re.DOTALL | re.IGNORECASE)
        if m:
            result['otherIncome'] = safe_int(m)
            if result['otherIncome']:
                print(f"✅ Other Income: ₹{result['otherIncome']:,}")
                break

    # ── Business income ───────────────────────────────────────────────────────
    for pat in [
        r'income\s+from\s+(?:business|profession)[:\s]*rs\.?\s*([\d.]+)',
        r'profits?\s+and\s+gains?.*?business.*?rs\.?\s*([\d.]+)',
    ]:
        m = re.search(pat, text_lower_norm, re.DOTALL | re.IGNORECASE)
        if m:
            result['businessIncome'] = safe_int(m)
            if result['businessIncome']:
                print(f"✅ Business Income: ₹{result['businessIncome']:,}")
                break

    # ── Fallback: use gross total income (section 9) as taxable salary ────────
    if result['taxableSalary'] == 0 and result['grossSalary'] > 0:
        for pat in [
            r'9\.\s*gross\s+total\s+income.*?rs\.?\s*([\d.]+)',
            r'gross\s+total\s+income.*?rs\.?\s*([\d.]+)',
        ]:
            m = re.search(pat, text_lower_norm, re.DOTALL | re.IGNORECASE)
            if m:
                val = safe_int(m)
                if 0 < val <= result['grossSalary']:
                    result['taxableSalary'] = val
                    print(f"✅ Taxable Salary (fallback): ₹{result['taxableSalary']:,}")
                    break

    print(f"\n📊 Final parsed data: {result}\n")
    return result


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == '__main__':
    print("\n✅ API Server Ready!")
    print("📍 Health Check:    http://localhost:5001/health")
    print("📍 Query:           http://localhost:5001/query")
    print("📍 Stream Query:    http://localhost:5001/query/stream")
    print("📍 Extract Income:  http://localhost:5001/api/extract-income")
    print("📍 Suggestions:     http://localhost:5001/suggestions")
    print("\n" + "=" * 60 + "\n")

    app.run(
        host='0.0.0.0',
        port=5001,
        debug=True,
        threaded=True,
        use_reloader=False,
    )