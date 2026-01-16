#!/bin/bash

# Finora AI Backend Startup Script

echo "=================================="
echo "🚀 Starting Finora AI Backend"
echo "=================================="

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3."
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "backend/api.py" ]; then
    echo "❌ Please run this script from the finora project root directory"
    exit 1
fi

# Activate the data folder's virtual environment
echo "📦 Activating virtual environment..."
source data/.venv/bin/activate

# Start the API server
echo "✅ Starting Flask API server..."
echo "📍 API will be available at: http://localhost:5001"
echo "=================================="
echo ""

cd backend && python3 api.py
