@echo off
REM Windows batch script to start Finora backend API
REM This script sets up the environment and starts the Flask server

echo.
echo ============================================================
echo        FINORA BACKEND API - STARTING (Windows)
echo ============================================================
echo.

REM Check if virtual environment exists
if not exist "data\.venv\Scripts\activate.bat" (
    echo [ERROR] Virtual environment not found!
    echo Please run: python -m venv data\.venv
    echo Then: data\.venv\Scripts\pip install -r data\requirements.txt
    pause
    exit /b 1
)

REM Activate virtual environment
call data\.venv\Scripts\activate.bat

REM Check if required packages are installed
python -c "import flask" 2>nul
if errorlevel 1 (
    echo [ERROR] Flask not installed! Installing dependencies...
    pip install -r data\requirements.txt
)

REM Set Flask environment variables
set FLASK_APP=data\backend\api.py
set FLASK_ENV=development
set FLASK_DEBUG=0
set DISABLE_SIGNAL_TIMEOUT=1

echo [setup] Python virtual environment activated
echo [setup] Starting Flask API server...
echo.

REM Start the Flask app
python data\backend\api.py

REM Pause to see any error messages
pause
