# Finora AI Backend Integration

Your `run_query.py` RAG system is now integrated with the Flutter app! 

## Setup Instructions

### 1. Install Python Dependencies
```bash
pip3 install -r backend/requirements.txt
```

### 2. Start the Backend Server

**Option A: Using the startup script (recommended)**
```bash
./start_backend.sh
```

**Option B: Manually**
```bash
python3 backend/api.py
```

The server will start at `http://localhost:5000`

### 3. Run the Flutter App
```bash
flutter run
```

## How It Works

1. **Backend (`backend/api.py`)**: Flask API wrapper around your existing `run_query.py`
2. **AI Service (`lib/services/ai_service.dart`)**: Flutter service that communicates with the backend
3. **AI Advice Screen (`lib/screens/ai_advice.dart`)**: Chat interface powered by your RAG system

## API Endpoints

- `GET /health` - Health check
- `POST /query` - Query the RAG system
  ```json
  {
    "query": "What is Section 80C?"
  }
  ```
- `POST /suggestions` - Get smart suggestions based on user context

## Features

✅ Chat interface with your RAG system  
✅ Real-time health monitoring  
✅ Smart query suggestions  
✅ Processing time display  
✅ Error handling with fallbacks  
✅ Works with your existing embeddings and PDFs  

## Important Notes

- Your `data/scripts/run_query.py` remains **unchanged**
- The backend imports and uses `query_rag()` directly
- All existing functionality (hybrid search, FAQ cache, LLM fallbacks) works as-is
- Make sure your embeddings are built (in `data/embeddings/`)
- PDFs should be in `data/pdfs/`

## Troubleshooting

**Backend won't start?**
- Make sure you're in the project root directory
- Check Python dependencies are installed
- Verify your `data/scripts/run_query.py` has all required imports

**Flutter can't connect?**
- Check backend is running at `http://localhost:5000`
- For Android emulator, change URL to `http://10.0.2.2:5000`
- Check firewall settings

**No answers from AI?**
- Verify embeddings are built
- Check PDFs are in `data/pdfs/`
- Look at backend logs for errors
