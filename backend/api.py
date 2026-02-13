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
    import pdfplumber  # Better for tables and structured data
    import io
    HAS_OCR = True
except ImportError:
    HAS_OCR = False
    print("⚠️  Warning: OCR libraries not installed. Install with: pip install pytesseract pdf2image pillow PyPDF2 pdfplumber")

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
    """Main query endpoint - uses your run_query.py RAG system"""
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
    """Get smart query suggestions based on user context"""
    try:
        data = request.json
        income = data.get('income', 0)
        deductions = data.get('deductions', 0)
        
        suggestions = []
        
        if income > 1000000:
            suggestions.append("Should I choose Old Regime or New Regime for high income?")
            suggestions.append("What are the tax rates for income above ₹10 lakhs?")
        
        if deductions < 150000:
            suggestions.append("How can I maximize my Section 80C deductions?")
            suggestions.append("What investments qualify for Section 80C?")
        
        if deductions < 200000:
            suggestions.append("What is Section 80CCD(1B) and how can I save ₹50,000 more?")
        
        suggestions.extend([
            "What are the GST rates for different services?",
            "How is capital gains tax calculated on equity?",
            "What is the difference between STCG and LTCG?",
            "What deductions are available under the new tax regime?",
            "How does presumptive taxation work for businesses?",
        ])
        
        return jsonify({
            'success': True,
            'suggestions': suggestions[:8]
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/query/stream', methods=['POST'])
def query_stream():
    """Streaming query endpoint"""
    try:
        data = request.json
        query_text = data.get('query', '')
        
        if not query_text:
            return jsonify({
                'success': False,
                'error': 'Query text is required'
            }), 400
        
        def generate():
            answer = query_rag(query_text, top_k=6)
            words = answer.split()
            for i, word in enumerate(words):
                chunk_data = {
                    'chunk': word + ' ',
                    'done': i == len(words) - 1
                }
                yield f"data: {json.dumps(chunk_data)}\n\n"
                time.sleep(0.05)
            
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
    Extract income details from uploaded file using MULTIPLE methods
    Tries: pdfplumber → PyPDF2 → OCR (in that order)
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
        
        filename = file.filename.lower()
        is_pdf = filename.endswith('.pdf')
        is_image = filename.endswith(('.jpg', '.jpeg', '.png'))
        
        if not (is_pdf or is_image):
            return jsonify({'error': 'Invalid file type. Please upload PDF or image'}), 400
        
        print(f"\n{'='*60}")
        print(f"📄 Processing: {filename}")
        print(f"🖥️  Platform: {sys.platform}")
        print(f"{'='*60}\n")
        
        file_bytes = file.read()
        extracted_text = ""
        
        if is_pdf:
            # METHOD 1: Try pdfplumber (best for structured PDFs like Form 16)
            print("🔹 Method 1: Trying pdfplumber...")
            try:
                import pdfplumber
                with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
                    for page_num, page in enumerate(pdf.pages):
                        text = page.extract_text()
                        if text:
                            extracted_text += text + f"\n---PAGE {page_num + 1} END---\n"
                
                if len(extracted_text.strip()) > 100:
                    print(f"✅ pdfplumber extracted {len(extracted_text)} chars")
                else:
                    print("⚠️  pdfplumber extracted too little text")
                    extracted_text = ""
            except Exception as e:
                print(f"⚠️  pdfplumber failed: {e}")
                extracted_text = ""
            
            # METHOD 2: Try PyPDF2 (if pdfplumber failed)
            if len(extracted_text.strip()) < 100:
                print("🔹 Method 2: Trying PyPDF2...")
                try:
                    pdf_reader = PyPDF2.PdfReader(io.BytesIO(file_bytes))
                    text_parts = []
                    for page_num, page in enumerate(pdf_reader.pages):
                        text = page.extract_text()
                        if text:
                            text_parts.append(text)
                    
                    extracted_text = "\n---PAGE END---\n".join(text_parts)
                    
                    if len(extracted_text.strip()) > 100:
                        print(f"✅ PyPDF2 extracted {len(extracted_text)} chars")
                    else:
                        print("⚠️  PyPDF2 extracted too little text")
                        extracted_text = ""
                except Exception as e:
                    print(f"⚠️  PyPDF2 failed: {e}")
                    extracted_text = ""
            
            # METHOD 3: OCR (if both PDF methods failed)
            if len(extracted_text.strip()) < 100:
                print("🔹 Method 3: Using OCR (PDF appears to be scanned)...")
                try:
                    with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp:
                        tmp.write(file_bytes)
                        tmp_path = tmp.name
                    
                    try:
                        images = pdf2image.convert_from_path(tmp_path)
                        ocr_texts = []
                        for i, image in enumerate(images[:5]):
                            text = pytesseract.image_to_string(image)
                            ocr_texts.append(text)
                        
                        extracted_text = "\n---PAGE END---\n".join(ocr_texts)
                        print(f"✅ OCR extracted {len(extracted_text)} chars")
                    finally:
                        if os.path.exists(tmp_path):
                            os.remove(tmp_path)
                except Exception as e:
                    print(f"❌ OCR failed: {e}")
                    return jsonify({'error': f'All extraction methods failed: {str(e)}'}), 500
        
        else:
            # For images, use OCR directly
            print("🔹 Extracting text from image using OCR...")
            with tempfile.NamedTemporaryFile(delete=False) as tmp:
                tmp.write(file_bytes)
                tmp_path = tmp.name
            
            try:
                image = Image.open(tmp_path)
                extracted_text = pytesseract.image_to_string(image)
                print(f"✅ OCR extracted {len(extracted_text)} chars from image")
            finally:
                if os.path.exists(tmp_path):
                    os.remove(tmp_path)
        
        # Show preview of extracted text
        print(f"\n{'='*60}")
        print("📝 EXTRACTED TEXT PREVIEW (first 1500 chars):")
        print(f"{'='*60}")
        print(extracted_text[:1500])
        print(f"{'='*60}\n")
        
        # Parse income data
        income_data = _parse_income_data(extracted_text)
        
        print(f"\n{'='*60}")
        print("✅ EXTRACTION COMPLETE")
        print(f"{'='*60}")
        print(f"Gross Salary: ₹{income_data['grossSalary']:,}")
        print(f"Taxable Salary: ₹{income_data['taxableSalary']:,}")
        print(f"Rental Income: ₹{income_data['rentalIncome']:,}")
        print(f"Other Income: ₹{income_data['otherIncome']:,}")
        print(f"Business Income: ₹{income_data['businessIncome']:,}")
        print(f"{'='*60}\n")
        
        return jsonify(income_data), 200
    
    except Exception as e:
        print(f"\n❌ ERROR: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


def _parse_income_data(text):
    """
    Parse income data with aggressive pattern matching
    Works on both Windows and macOS
    """
    # Normalize text
    text = text.replace('\r\n', '\n').replace('\r', '\n')
    text = re.sub(r'\s+', ' ', text)  # All whitespace to single space
    text = text.replace(',', '')      # Remove commas
    text_lower = text.lower()
    
    result = {
        'grossSalary': 0,
        'taxableSalary': 0,
        'otherIncome': 0,
        'rentalIncome': 0,
        'businessIncome': 0
    }
    
    print("\n🔍 PARSING INCOME DATA...")
    print(f"Text length: {len(text)} characters\n")
    
    def extract_number(match_obj):
        """Extract number from regex match"""
        try:
            if not match_obj:
                return 0
            num_str = match_obj.group(1)
            num_str = re.sub(r'[^\d.]', '', num_str)
            num_str = num_str.strip('.')
            if num_str and len(num_str) > 0:
                val = int(float(num_str))
                if 0 <= val <= 100000000:  # Sanity check
                    return val
        except:
            pass
        return 0
    
    # Find ALL numbers with "Rs" for debugging
    all_amounts = re.findall(r'(.{30})\s*rs\.?\s*([\d.]+)(.{30})', text_lower, re.IGNORECASE)
    print("💰 ALL AMOUNTS FOUND:")
    for i, (before, amt, after) in enumerate(all_amounts[:25], 1):
        print(f"{i:2d}. ...{before.strip()[-30:]} Rs.{amt} {after.strip()[:30]}...")
    print()
    
    # GROSS SALARY - Multiple aggressive patterns
    print("🔎 Searching for GROSS SALARY...")
    gross_patterns = [
        r'd\s*\)\s*total\s*rs\.?\s*([\d.]+)',
        r'd\s*total\s*rs\.?\s*([\d.]+)',
        r'1\s*gross\s*salary.*?total.*?rs\.?\s*([\d.]+)',
        r'salary\s*as\s*per.*?sec.*?17.*?rs\.?\s*([\d.]+)',
        r'gross\s*salary.*?rs\.?\s*([\d.]+)',
    ]
    
    for i, pattern in enumerate(gross_patterns, 1):
        match = re.search(pattern, text_lower, re.DOTALL)
        if match:
            val = extract_number(match)
            if val > 0:
                result['grossSalary'] = val
                print(f"✅ Found (pattern {i}): ₹{val:,}")
                break
    
    if result['grossSalary'] == 0:
        print("❌ NOT FOUND")
    
    # TAXABLE SALARY - Multiple aggressive patterns
    print("\n🔎 Searching for TAXABLE SALARY...")
    taxable_patterns = [
        r'6\s*\.?\s*income\s*chargeable.*?salaries.*?rs\.?\s*([\d.]+)',
        r'income\s*chargeable.*?salaries.*?rs\.?\s*([\d.]+)',
        r'3\s*\.?\s*total\s*amount.*?salary.*?rs\.?\s*([\d.]+)',
        r'taxable\s*income.*?rs\.?\s*([\d.]+)',
        r'income\s*from\s*salaries.*?rs\.?\s*([\d.]+)',
    ]
    
    for i, pattern in enumerate(taxable_patterns, 1):
        match = re.search(pattern, text_lower, re.DOTALL)
        if match:
            val = extract_number(match)
            if val > 0:
                result['taxableSalary'] = val
                print(f"✅ Found (pattern {i}): ₹{val:,}")
                break
    
    if result['taxableSalary'] == 0:
        print("❌ NOT FOUND")
    
    # RENTAL INCOME
    print("\n🔎 Searching for RENTAL INCOME...")
    rental_patterns = [
        r'7.*?a\s*\).*?house\s*property.*?rs\.?\s*([\d.]+)',
        r'house\s*property.*?rs\.?\s*([\d.]+)',
        r'rental\s*income.*?rs\.?\s*([\d.]+)',
    ]
    
    for i, pattern in enumerate(rental_patterns, 1):
        match = re.search(pattern, text_lower, re.DOTALL)
        if match:
            val = extract_number(match)
            result['rentalIncome'] = val
            print(f"✅ Found (pattern {i}): ₹{val:,}")
            break
    
    if result['rentalIncome'] == 0:
        print("✓ None (₹0)")
    
    # OTHER INCOME
    print("\n🔎 Searching for OTHER INCOME...")
    other_patterns = [
        r'7.*?b\s*\).*?other\s*sources.*?rs\.?\s*([\d.]+)',
        r'other\s*sources.*?rs\.?\s*([\d.]+)',
        r'other\s*income.*?rs\.?\s*([\d.]+)',
    ]
    
    for i, pattern in enumerate(other_patterns, 1):
        match = re.search(pattern, text_lower, re.DOTALL)
        if match:
            val = extract_number(match)
            result['otherIncome'] = val
            print(f"✅ Found (pattern {i}): ₹{val:,}")
            break
    
    if result['otherIncome'] == 0:
        print("✓ None (₹0)")
    
    # BUSINESS INCOME
    print("\n🔎 Searching for BUSINESS INCOME...")
    business_patterns = [
        r'business.*?profession.*?rs\.?\s*([\d.]+)',
        r'business\s*income.*?rs\.?\s*([\d.]+)',
    ]
    
    for i, pattern in enumerate(business_patterns, 1):
        match = re.search(pattern, text_lower, re.DOTALL)
        if match:
            val = extract_number(match)
            if val > 0:
                result['businessIncome'] = val
                print(f"✅ Found (pattern {i}): ₹{val:,}")
                break
    
    if result['businessIncome'] == 0:
        print("✓ None (₹0)")
    
    # FALLBACK: Try to find gross total income for taxable salary
    if result['taxableSalary'] == 0 and result['grossSalary'] > 0:
        print("\n⚠️  FALLBACK: Looking for gross total income...")
        fallback = re.search(r'9\s*\.?\s*gross\s*total\s*income.*?rs\.?\s*([\d.]+)', text_lower, re.DOTALL)
        if not fallback:
            fallback = re.search(r'gross\s*total\s*income.*?rs\.?\s*([\d.]+)', text_lower, re.DOTALL)
        
        if fallback:
            val = extract_number(fallback)
            if 0 < val <= result['grossSalary']:
                result['taxableSalary'] = val
                print(f"✅ Found: ₹{val:,}")
    
    return result


if __name__ == '__main__':
    print("\n✅ API Server Ready!")
    print("📍 Health Check: http://localhost:5001/health")
    print("📍 Query Endpoint: http://localhost:5001/query")
    print("📍 Extract Income: http://localhost:5001/api/extract-income")
    print("📍 Streaming Query: http://localhost:5001/query/stream")
    print("📍 Suggestions: http://localhost:5001/suggestions")
    print("\n" + "=" * 60 + "\n")
    
    app.run(host='0.0.0.0', port=5001, debug=True, threaded=True)