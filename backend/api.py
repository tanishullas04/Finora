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

# Set environment variable to disable signal-based timeouts in run_query
os.environ['DISABLE_SIGNAL_TIMEOUT'] = '1'

from run_query import query_rag

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

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'Finora AI Tax Advisor',
        'version': '1.0.0'
    })

@app.route('/query', methods=['POST'])
def query():
    """
    Main query endpoint - uses your run_query.py RAG system
    
    Expected JSON body:
    {
        "query": "What is Section 80C?"
    }
    
    Returns:
    {
        "success": true,
        "query": "What is Section 80C?",
        "answer": "Section 80C allows deductions up to ₹1,50,000...",
        "processing_time": 1.23
    }
    """
    try:
        data = request.json
        user_query = data.get('query', '').strip()
        
        if not user_query:
            return jsonify({
                'success': False,
                'error': 'No query provided'
            }), 400
        
        print(f"\n📝 Query received: {user_query}")
        
        start_time = time.time()
        
        # Call your existing RAG system directly
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
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/suggestions', methods=['POST'])
def suggestions():
    """
    Get smart query suggestions based on user context
    
    Expected JSON body:
    {
        "income": 1000000,
        "deductions": 50000
    }
    """
    try:
        data = request.json
        income = data.get('income', 0)
        deductions = data.get('deductions', 0)
        
        suggestions = []
        
        # Income-based suggestions
        if income > 1000000:
            suggestions.append("Should I choose Old Regime or New Regime for high income?")
            suggestions.append("What are the tax rates for income above ₹10 lakhs?")
        
        # Deduction-based suggestions
        if deductions < 150000:
            suggestions.append("How can I maximize my Section 80C deductions?")
            suggestions.append("What investments qualify for Section 80C?")
        
        if deductions < 200000:
            suggestions.append("What is Section 80CCD(1B) and how can I save ₹50,000 more?")
        
        # General suggestions
        suggestions.extend([
            "What are the GST rates for different services?",
            "How is capital gains tax calculated on equity?",
            "What is the difference between STCG and LTCG?",
            "What deductions are available under the new tax regime?",
            "How does presumptive taxation work for businesses?",
        ])
        
        return jsonify({
            'success': True,
            'suggestions': suggestions[:8]  # Return top 8
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/query/stream', methods=['POST'])
def query_stream():
    """
    Streaming query endpoint - returns answer word by word for real-time display
    
    Expected JSON body:
    {
        "query": "What is Section 80C?"
    }
    
    Returns: Server-Sent Events stream with answer chunks
    """
    try:
        data = request.json
        query_text = data.get('query', '')
        
        if not query_text:
            return jsonify({
                'success': False,
                'error': 'Query text is required'
            }), 400
        
        def generate():
            """Generate streaming response"""
            # Get the full answer first (for now, we'll simulate streaming)
            # In production, modify query_rag to support streaming
            answer = query_rag(query_text, top_k=6)
            
            # Stream word by word
            words = answer.split()
            for i, word in enumerate(words):
                chunk_data = {
                    'chunk': word + ' ',
                    'done': i == len(words) - 1
                }
                yield f"data: {json.dumps(chunk_data)}\n\n"
                time.sleep(0.05)  # Small delay for streaming effect
            
            # Send completion signal
            yield f"data: {json.dumps({'done': True, 'complete': True})}\n\n"
        
        return Response(
            stream_with_context(generate()),
            mimetype='text/event-stream',
            headers={
                'Cache-Control': 'no-cache',
                'X-Accel-Buffering': 'no'
            }
        )
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/extract-income', methods=['POST'])
def extract_income():
    """
    Extract income details from uploaded file (PDF or Image)
    
    Expected: multipart form data with 'file' field
    Returns:
    {
        "grossSalary": 1832392,
        "taxableSalary": 1757392,
        "otherIncome": 0,
        "rentalIncome": 0,
        "businessIncome": 0
    }
    """
    if not HAS_OCR:
        return jsonify({
            'error': 'OCR libraries not installed'
        }), 500
    
    try:
        if 'file' not in request.files:
            return jsonify({'error': 'No file provided'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
        
        # Get file extension
        filename = file.filename.lower()
        is_pdf = filename.endswith('.pdf')
        is_image = filename.endswith(('.jpg', '.jpeg', '.png'))
        
        if not (is_pdf or is_image):
            return jsonify({'error': 'Invalid file type. Please upload PDF or image'}), 400
        
        print(f"\n📄 Processing file: {filename}")
        
        # Read file bytes
        file_bytes = file.read()
        
        try:
            # Extract text
            extracted_text = ""
            
            if is_pdf:
                # Try PyPDF2 first (faster for text-based PDFs like Form 16)
                try:
                    pdf_reader = PyPDF2.PdfReader(io.BytesIO(file_bytes))
                    for page_num, page in enumerate(pdf_reader.pages):
                        text = page.extract_text()
                        extracted_text += text + f"\n---PAGE {page_num + 1} END---\n"
                    
                    print(f"✅ Extracted text from PDF using PyPDF2 ({len(extracted_text)} chars)")
                    
                    # If no text extracted, fall back to OCR
                    if len(extracted_text.strip()) < 100:
                        print("⚠️  PDF appears to be scanned, falling back to OCR...")
                        raise Exception("PDF is scanned")
                        
                except Exception as pdf_error:
                    print(f"⚠️  PyPDF2 failed, using OCR: {pdf_error}")
                    # Fallback to OCR for scanned PDFs
                    with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp:
                        tmp.write(file_bytes)
                        tmp_path = tmp.name
                    
                    try:
                        images = pdf2image.convert_from_path(tmp_path)
                        for i, image in enumerate(images[:5]):  # Process first 5 pages
                            text = pytesseract.image_to_string(image)
                            extracted_text += text + f"\n---PAGE {i + 1} END---\n"
                        print(f"✅ Extracted text using OCR ({len(extracted_text)} chars)")
                    finally:
                        if os.path.exists(tmp_path):
                            os.remove(tmp_path)
            else:
                # Extract text from image directly
                with tempfile.NamedTemporaryFile(delete=False) as tmp:
                    tmp.write(file_bytes)
                    tmp_path = tmp.name
                
                try:
                    image = Image.open(tmp_path)
                    extracted_text = pytesseract.image_to_string(image)
                    print(f"✅ Extracted text from image ({len(extracted_text)} chars)")
                finally:
                    if os.path.exists(tmp_path):
                        os.remove(tmp_path)
            
            print(f"\n📝 Extracted text preview (first 500 chars):\n{extracted_text[:500]}\n")
            
            # Parse income details from text
            income_data = _parse_income_data(extracted_text)
            
            print(f"✅ Extracted income data: {income_data}\n")
            
            return jsonify(income_data), 200
        
        except Exception as extract_error:
            print(f"❌ Error during extraction: {str(extract_error)}")
            raise
    
    except Exception as e:
        print(f"❌ Error extracting income: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


def _parse_income_data(text):
    """
    Parse income data from extracted text (optimized for Form 16)
    
    Properly distinguishes between:
    - Gross Salary: Total salary paid (Section 1d in Form 16)
    - Taxable Salary: After deductions (Section 6 in Form 16)
    - Rental Income: House property income (Section 7a in Form 16)
    - Other Income: Other sources (Section 7b in Form 16)
    - Business Income: Business/profession income
    """
    text_lower = text.lower()
    # Remove commas from numbers for easier parsing
    text_normalized = text.replace(',', '')
    text_lower_normalized = text_lower.replace(',', '')
    
    result = {
        'grossSalary': 0,
        'taxableSalary': 0,
        'otherIncome': 0,
        'rentalIncome': 0,
        'businessIncome': 0
    }
    
    print("\n🔍 Parsing income data...")
    print(f"Text length: {len(text)} characters")
    
    def safe_extract_number(match_obj):
        """Safely extract and convert number from regex match"""
        try:
            if match_obj:
                # Get the captured group
                num_str = match_obj.group(1)
                # Remove any non-numeric characters except decimal point
                num_str = re.sub(r'[^\d.]', '', num_str)
                # Remove trailing .00 if present
                num_str = num_str.replace('.00', '').replace('.0', '')
                # Convert to float then int
                if num_str:
                    return int(float(num_str))
        except (ValueError, AttributeError) as e:
            print(f"⚠️  Error converting number: {e}, match: {match_obj.group(0) if match_obj else 'None'}")
        return 0
    
    # ==================== GROSS SALARY ====================
    # Form 16 Section 1(d): "d) Total Rs. 18,32,392.00"
    gross_salary_patterns = [
        r'd\)\s*total\s*rs\.?\s*([\d.]+)',  # Form 16 specific
        r'1\.\s*gross\s*salary.*?d\)\s*total.*?rs\.?\s*([\d.]+)',
        r'gross\s+salary.*?total.*?rs\.?\s*([\d.]+)',
        r'salary\s+as\s+per.*?17\(1\).*?rs\.?\s*([\d.]+)',
        r'salary\s+paid[:\s]*rs\.?\s*([\d.]+)',
    ]
    
    for i, pattern in enumerate(gross_salary_patterns):
        match = re.search(pattern, text_lower_normalized, re.DOTALL | re.IGNORECASE)
        if match:
            result['grossSalary'] = safe_extract_number(match)
            if result['grossSalary'] > 0:
                print(f"✅ Found Gross Salary (pattern {i+1}): ₹{result['grossSalary']:,}")
                break
    
    # ==================== TAXABLE SALARY ====================
    # Form 16 Section 6: "Income chargeable under the head 'Salaries'"
    taxable_patterns = [
        r'6\.\s*income\s+chargeable.*?salaries.*?rs\.?\s*([\d.]+)',  # Form 16 specific
        r'income\s+chargeable.*?head.*?salaries.*?rs\.?\s*([\d.]+)',
        r'income\s+from\s+salaries?[:\s]*rs\.?\s*([\d.]+)',
        r'taxable\s+(?:income\s+)?from\s+salaries?[:\s]*rs\.?\s*([\d.]+)',
        r'taxable\s+salary[:\s]*rs\.?\s*([\d.]+)',
        r'(?:total\s+)?taxable\s+income[:\s]*rs\.?\s*([\d.]+)',
        r'3\.\s*total\s+amount\s+of\s+salary.*?current\s+employer.*?rs\.?\s*([\d.]+)',
    ]
    
    for i, pattern in enumerate(taxable_patterns):
        match = re.search(pattern, text_lower_normalized, re.DOTALL | re.IGNORECASE)
        if match:
            result['taxableSalary'] = safe_extract_number(match)
            if result['taxableSalary'] > 0:
                print(f"✅ Found Taxable Salary (pattern {i+1}): ₹{result['taxableSalary']:,}")
                break
    
    # ==================== RENTAL INCOME ====================
    # Form 16 Section 7(a): "Income from house property"
    rental_patterns = [
        r'7.*?a\).*?house\s+property.*?rs\.?\s*([\d.]+)',  # Form 16 specific
        r'income.*?house\s+property[:\s]*rs\.?\s*([\d.]+)',
        r'rental\s+income[:\s]*rs\.?\s*([\d.]+)',
    ]
    
    for i, pattern in enumerate(rental_patterns):
        match = re.search(pattern, text_lower_normalized, re.DOTALL | re.IGNORECASE)
        if match:
            result['rentalIncome'] = safe_extract_number(match)
            print(f"✅ Found Rental Income (pattern {i+1}): ₹{result['rentalIncome']:,}")
            break
    
    # ==================== OTHER INCOME ====================
    # Form 16 Section 7(b): "Income under the head Other Sources"
    other_patterns = [
        r'7.*?b\).*?other\s+sources.*?rs\.?\s*([\d.]+)',  # Form 16 specific
        r'income.*?other\s+sources[:\s]*rs\.?\s*([\d.]+)',
        r'other\s+(?:taxable\s+)?income[:\s]*rs\.?\s*([\d.]+)',
    ]
    
    for i, pattern in enumerate(other_patterns):
        match = re.search(pattern, text_lower_normalized, re.DOTALL | re.IGNORECASE)
        if match:
            result['otherIncome'] = safe_extract_number(match)
            print(f"✅ Found Other Income (pattern {i+1}): ₹{result['otherIncome']:,}")
            break
    
    # ==================== BUSINESS INCOME ====================
    business_patterns = [
        r'income\s+from\s+(?:business|profession)[:\s]*rs\.?\s*([\d.]+)',
        r'(?:business|professional)\s+income[:\s]*rs\.?\s*([\d.]+)',
        r'profits?\s+and\s+gains?.*?business.*?rs\.?\s*([\d.]+)',
    ]
    
    for i, pattern in enumerate(business_patterns):
        match = re.search(pattern, text_lower_normalized, re.DOTALL | re.IGNORECASE)
        if match:
            result['businessIncome'] = safe_extract_number(match)
            if result['businessIncome'] > 0:
                print(f"✅ Found Business Income (pattern {i+1}): ₹{result['businessIncome']:,}")
                break
    
    # ==================== FALLBACK LOGIC ====================
    # If taxable salary not found but gross salary exists, try to find it
    if result['taxableSalary'] == 0 and result['grossSalary'] > 0:
        print("⚠️  Taxable salary not found, trying fallback...")
        
        # Look for "gross total income" or similar
        fallback_patterns = [
            r'9\.\s*gross\s+total\s+income.*?rs\.?\s*([\d.]+)',
            r'gross\s+total\s+income.*?rs\.?\s*([\d.]+)',
            r'12\.\s*total\s+taxable\s+income.*?rs\.?\s*([\d.]+)',
        ]
        
        for i, pattern in enumerate(fallback_patterns):
            match = re.search(pattern, text_lower_normalized, re.DOTALL | re.IGNORECASE)
            if match:
                fallback_val = safe_extract_number(match)
                # Only use if it's less than gross salary (makes sense)
                if 0 < fallback_val <= result['grossSalary']:
                    result['taxableSalary'] = fallback_val
                    print(f"✅ Found Taxable Salary (fallback pattern {i+1}): ₹{result['taxableSalary']:,}")
                    break
    
    print(f"\n📊 Final parsed data: {result}\n")
    
    return result


if __name__ == '__main__':
    print("\n✅ API Server Ready!")
    print("📍 Health Check: http://localhost:5001/health")
    print("📍 Query Endpoint: http://localhost:5001/query")
    print("📍 Extract Income: http://localhost:5001/api/extract-income")
    print("📍 Streaming Query: http://localhost:5001/query/stream")
    print("📍 Suggestions: http://localhost:5001/suggestions")
    print("\n" + "=" * 60 + "\n")
    
    app.run(
    host='0.0.0.0',
    port=5001,
    debug=True,
    threaded=True,
    use_reloader=False   
)