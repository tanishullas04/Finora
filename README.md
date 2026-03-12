# Finora — AI-Powered Indian Tax Advisor

Finora is a cross-platform mobile application that helps Indian taxpayers manage their finances and get intelligent tax guidance. It combines a Flutter frontend with a Python RAG (Retrieval-Augmented Generation) backend to deliver real-time, document-grounded answers to Indian tax questions.

---

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Architecture Overview](#architecture-overview)
- [RAG & AI Pipeline](#rag--ai-pipeline)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Firebase Setup](#firebase-setup)
  - [Running the Backend](#running-the-backend)
  - [Running the Flutter App](#running-the-flutter-app)
- [API Reference](#api-reference)
- [Screens](#screens)
- [Tax Computation Logic](#tax-computation-logic)
- [Known Limitations](#known-limitations)

---

## Features

- **AI Tax Advisor** — Ask any Indian tax question and get real-time, streamed answers grounded in actual tax documents
- **Income Tax Calculator** — Supports salary, rental, business, and other income sources
- **Old vs New Regime Comparison** — Animated comparison with slab-by-slab breakdown and recommendation
- **Deductions Tracker** — Section 80C, 80D, 80CCD, Section 24
- **Capital Gains Calculator** — STCG, LTCG (real estate, stocks, mutual funds)
- **GST Calculator** — GST computation and tracking
- **PDF Export** — Full tax summary exportable as a PDF
- **Form 16 OCR** — Upload a Form 16 PDF and have salary data extracted automatically
- **Profile Management** — PAN, DOB, filing status, residential status, tax regime preference
- **Income & Deductions Pie Chart** — Visual breakdown of your financial data

---

## Tech Stack

### Frontend
| Technology | Purpose |
|---|---|
| Flutter (Dart) | Cross-platform mobile app (Android & iOS) |
| Firebase Auth | User authentication |
| Cloud Firestore | User data, income, deductions, tax records |
| `http` package | REST API + SSE streaming communication |
| `pdf` + `printing` | PDF export of tax summary |
| `file_picker` | Form 16 upload |
| `lottie` | Animations |

### Backend
| Technology | Purpose |
|---|---|
| Python 3.x | Backend language |
| Flask | REST API framework |
| Ollama (phi3 / llama3) | Local LLM for answer generation |
| FAISS | Vector storage for semantic search |
| Sentence Transformers | Text embeddings |
| BM25 | Keyword-based retrieval |
| pytesseract + pdf2image | OCR for Form 16 extraction |
| PyPDF2 | PDF text parsing |

### Infrastructure
| Technology | Purpose |
|---|---|
| Firebase / Firestore | Database and authentication |
| Ollama | Local LLM inference (no cloud API needed) |
| FAISS flat index files | Vector storage (no separate DB server) |

---

## Project Structure

```
Finora-main/
├── lib/
│   ├── main.dart                  # App entry, routes, theme
│   ├── firebase_options.dart      # Firebase configuration
│   ├── theme/
│   │   └── app_colors.dart        # Colour palette
│   ├── services/
│   │   ├── firebase_service.dart  # Firestore read/write
│   │   ├── ai_service.dart        # RAG backend communication + SSE streaming
│   │   └── ocr_service.dart       # Form 16 OCR parsing
│   └── screens/
│       ├── splash.dart            # Splash screen
│       ├── login.dart             # Login
│       ├── register.dart          # Registration
│       ├── home.dart              # Dashboard
│       ├── income.dart            # Income entry + Form 16 upload
│       ├── deductions.dart        # Deductions entry
│       ├── capital_gains.dart     # Capital gains entry
│       ├── gst_calculator.dart    # GST computation
│       ├── regime_compare.dart    # Old vs New regime comparison
│       ├── summary.dart           # Full tax summary + pie chart + PDF export
│       ├── profile_edit.dart      # User profile management
│       ├── ai_advice.dart         # AI Tax Advisor chat screen
│       ├── recommendations.dart   # Tax saving recommendations
│       └── tax_glossary.dart      # Tax terms reference
├── backend/
│   ├── api.py                     # Flask API server
│   └── requirements.txt           # Python dependencies
├── data/
│   ├── raw_pdfs/                  # Source tax documents (Income Tax Act, GST notifications, etc.)
│   ├── processed_text/            # Chunked text extracted from PDFs
│   ├── embeddings/                # FAISS index files (one per tax domain)
│   │   ├── income_tax_index/
│   │   ├── gst_index/
│   │   ├── capital_gains_index/
│   │   ├── deductions_index/
│   │   ├── presumptive_index/
│   │   └── custom_index/
│   ├── faq/                       # Pre-cached FAQ answers
│   ├── scripts/                   # RAG pipeline scripts
│   └── capital_gains_config.json  # Capital gains tax configuration
├── assets/
│   ├── finora.svg                 # App logo
│   └── lottie/                    # Animation files
├── start_backend.sh               # macOS/Linux backend launcher
├── start_backend.bat              # Windows backend launcher
└── pubspec.yaml                   # Flutter dependencies
```

---

## Architecture Overview

```
┌─────────────────────────────────────────┐
│              Flutter App                │
│                                         │
│  Auth → Firebase Auth                   │
│  Data → Cloud Firestore                 │
│  AI   → Flask Backend (SSE stream)      │
└────────────────┬────────────────────────┘
                 │ HTTP / SSE
                 ▼
┌─────────────────────────────────────────┐
│           Flask Backend (api.py)        │
│                                         │
│  /health        → status check          │
│  /query         → blocking response     │
│  /query/stream  → SSE token stream      │
│  /suggestions   → smart suggestions     │
│  /api/extract-income → Form 16 OCR      │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│           RAG Pipeline                  │
│                                         │
│  4-layer gating → Query Router          │
│  FAISS search + BM25 → Context          │
│  Ollama (phi3/llama3) → Answer          │
└─────────────────────────────────────────┘
```

---

## RAG & AI Pipeline

The AI Tax Advisor uses a custom Retrieval-Augmented Generation pipeline. Rather than relying on a general-purpose LLM's training data, it retrieves relevant passages from actual Indian tax documents and uses the LLM only for language generation.

### Step 1 — 4-Layer Query Gating

Every question passes through 4 filters before reaching the retrieval system:

1. **Tax relevance check** — Rejects unrelated questions (e.g. "What's the weather?")
2. **Scope check** — Rejects out-of-scope queries (e.g. US tax questions)
3. **FAQ cache** — Common questions return instantly from a pre-built cache without hitting the LLM
4. **Confidence check** — Low-confidence or ambiguous queries are flagged

### Step 2 — Query Routing

The system classifies the question and routes it to the most relevant FAISS index:

| Domain | Index | Source Documents |
|---|---|---|
| Income Tax | `income_tax_index` | Income Tax Act 2025 |
| GST | `gst_index` | GST notifications, rate schedules |
| Capital Gains | `capital_gains_index` | STCG/LTCG circulars |
| Deductions | `deductions_index` | 80C/80D/allowances circular |
| Presumptive Tax | `presumptive_index` | 44AD/44ADA guidance |

### Step 3 — Hybrid Search

Two search strategies run in parallel and their results are merged:

- **FAISS (cosine similarity)** — Finds semantically similar passages. "Tax saving" matches "deduction" even without the exact word.
- **BM25 (keyword search)** — Finds exact term matches. "Section 80C" reliably finds documents containing "Section 80C".

Combining both catches what either approach alone would miss.

### Step 4 — Context Assembly

Top retrieved chunks are assembled into a structured prompt:

```
System: You are an expert Indian tax advisor. Answer using only the context provided.

Context:
[Retrieved chunk 1]
[Retrieved chunk 2]
[Retrieved chunk 3]

Question: <user's question>

Answer:
```

### Step 5 — LLM Generation (Ollama)

The prompt is sent to Ollama running locally. The model (phi3 or llama3) generates the answer token by token.

### Step 6 — SSE Streaming to Flutter

Each token is immediately sent to Flutter as a Server-Sent Event:

```
data: {"chunk": "Under", "done": false}
data: {"chunk": " Section", "done": false}
data: {"chunk": " 112A,", "done": false}
...
data: {"done": true}
```

Flutter appends each token to the chat bubble in real time, giving a word-by-word appearance like ChatGPT — instead of waiting 30–150 seconds for the full response.

---

## Getting Started

### Prerequisites

**Flutter**
- Flutter SDK 3.x or higher
- Dart SDK ^3.9.0
- Android Studio / Xcode for device emulation

**Python Backend**
- Python 3.9+
- [Ollama](https://ollama.ai) installed and running
- Ollama model pulled: `ollama pull phi3` or `ollama pull llama3`
- Tesseract OCR installed (for Form 16 extraction)
  - macOS: `brew install tesseract`
  - Ubuntu: `sudo apt install tesseract-ocr`
  - Windows: [Tesseract installer](https://github.com/UB-Mannheim/tesseract/wiki)

---

### Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication** (Email/Password)
3. Enable **Cloud Firestore**
4. Run `flutterfire configure` to generate `lib/firebase_options.dart`
5. Download `google-services.json` → place in `android/app/`
6. Download `GoogleService-Info.plist` → place in `ios/Runner/`

---

### Running the Backend

```bash
# 1. Install Python dependencies
cd backend
pip install -r requirements.txt

# 2. Make sure Ollama is running with a model
ollama serve
ollama pull phi3

# 3. Start the Flask server
# macOS / Linux:
bash start_backend.sh

# Windows:
start_backend.bat

# Or directly:
python backend/api.py
```

The server starts on `http://localhost:5001`. Verify with:
```bash
curl http://localhost:5001/health
```

---

### Running the Flutter App

```bash
# Install dependencies
flutter pub get

# Run on emulator or device
flutter run
```

**Physical device setup:** If running on a physical Android device, update `_physicalDeviceIp` in `lib/services/ai_service.dart` to your machine's local IP address (find it with `ipconfig` on Windows or `ifconfig` on Mac/Linux).

```dart
static const String _physicalDeviceIp = '192.168.1.42'; // ← your LAN IP
```

**Platform IP routing:**

| Platform | IP used |
|---|---|
| Android Emulator | `10.0.2.2` (maps to host machine) |
| iOS Simulator | `127.0.0.1` |
| Physical device | `_physicalDeviceIp` (your LAN IP) |

---

## API Reference

All endpoints are served at `http://localhost:5001`.

### `GET /health`
Returns server status.

```json
{ "status": "healthy", "service": "Finora AI Tax Advisor", "version": "1.0.0" }
```

---

### `POST /query`
Blocking query — waits for the full answer before responding.

**Request:**
```json
{ "query": "What is Section 80C?" }
```

**Response:**
```json
{
  "success": true,
  "query": "What is Section 80C?",
  "answer": "Section 80C allows deductions up to ₹1.5 lakh...",
  "processing_time": 12.4
}
```

---

### `POST /query/stream`
Streaming query — returns tokens via Server-Sent Events as they are generated.

**Request:**
```json
{ "query": "How is LTCG on stocks taxed?" }
```

**Response (SSE stream):**
```
data: {"chunk": "Long", "done": false}
data: {"chunk": "-term", "done": false}
data: {"chunk": " capital", "done": false}
...
data: {"done": true}
```

---

### `POST /suggestions`
Returns smart question suggestions based on the user's income and deductions.

**Request:**
```json
{ "income": 1200000, "deductions": 150000 }
```

**Response:**
```json
{
  "success": true,
  "suggestions": [
    "What deductions can I claim beyond 80C?",
    "Should I choose old or new tax regime?",
    ...
  ]
}
```

---

### `POST /api/extract-income`
Accepts a Form 16 PDF and extracts income fields using OCR.

**Request:** `multipart/form-data` with a `file` field containing the PDF.

**Response:**
```json
{
  "success": true,
  "data": {
    "taxableSalary": 1050000,
    "grossSalary": 1200000,
    "otherIncome": 0
  }
}
```

---

## Screens

| Screen | Route | Description |
|---|---|---|
| Splash | `/` | Animated entry screen |
| Login | `/login` | Email/password login |
| Register | `/register` | New account creation |
| Home | `/home` | Dashboard with navigation |
| Income | `/income` | Income entry + Form 16 OCR upload |
| Deductions | `/deductions` | Section 80C, 80D, 80CCD, Section 24 |
| Capital Gains | `/capital_gains` | STCG, LTCG by asset type |
| GST | `/gst_calculator` | GST computation |
| Regime Compare | `/regime_compare` | Old vs New regime with animated bars + slab breakdown |
| Summary | `/summary` | Full summary with pie chart + PDF export |
| Profile | `/profile` | Personal and tax profile management |
| AI Advisor | `/ai_advice` | Real-time streaming AI chat |
| Recommendations | `/recommendations` | Personalised tax saving tips |
| Tax Glossary | `/understanding_tax` | Reference for tax terms |

---

## Tax Computation Logic

### Old Regime (FY 2024-25)
Standard deduction of ₹50,000 + all user deductions applied before slabs.

| Taxable Income | Rate |
|---|---|
| Up to ₹2.5L | 0% |
| ₹2.5L – ₹5L | 5% |
| ₹5L – ₹10L | 20% |
| Above ₹10L | 30% |

Rebate u/s 87A: Full tax rebate if taxable income ≤ ₹5L.

### New Regime (FY 2024-25)
Standard deduction of ₹50,000 applied. No other deductions allowed.

| Taxable Income | Rate |
|---|---|
| Up to ₹3L | 0% |
| ₹3L – ₹6L | 5% |
| ₹6L – ₹9L | 10% |
| ₹9L – ₹12L | 15% |
| ₹12L – ₹15L | 20% |
| Above ₹15L | 30% |

Rebate u/s 87A: Full tax rebate if taxable income ≤ ₹7L.

### LTCG Tax
| Asset | Rate | Exemption |
|---|---|---|
| Stocks | 10% | First ₹1L exempt |
| Mutual Funds | 10% | None |
| Real Estate | 20% | With indexation |
| Other | 20% | None |

All figures have 4% Health & Education Cess applied.

---

## Known Limitations

- The backend must run on the **same machine** as Ollama — no cloud LLM is used
- Physical devices require the LAN IP to be manually set in `ai_service.dart`
- OCR accuracy depends on Form 16 scan quality
- FAISS indices must be rebuilt if new source documents are added
- The LLM response time depends on local machine hardware (GPU speeds this up significantly)

---

## License

This project is for educational and personal use. Tax calculations are estimates — always consult a qualified CA for official tax advice.