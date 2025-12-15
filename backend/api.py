from flask import Flask, request, jsonify, Response, stream_with_context
from flask_cors import CORS
import sys
import os
import time
import json

# Add parent directory to path to import from data/scripts
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'data', 'scripts'))

# Set environment variable to disable signal-based timeouts in run_query
os.environ['DISABLE_SIGNAL_TIMEOUT'] = '1'

from run_query import query_rag

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


if __name__ == '__main__':
    print("\n✅ API Server Ready!")
    print("📍 Health Check: http://localhost:5001/health")
    print("📍 Query Endpoint: http://localhost:5001/query")
    print("📍 Streaming Query: http://localhost:5001/query/stream")
    print("📍 Suggestions: http://localhost:5001/suggestions")
    print("\n" + "=" * 60 + "\n")
    
    app.run(host='0.0.0.0', port=5001, debug=True, threaded=True)
