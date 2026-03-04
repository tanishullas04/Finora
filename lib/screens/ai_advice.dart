import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/firebase_service.dart';

class AiAdviceScreen extends StatefulWidget {
  const AiAdviceScreen({super.key});
  @override
  State<AiAdviceScreen> createState() => _AiAdviceScreenState();
}

class _AiAdviceScreenState extends State<AiAdviceScreen> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseService _firebaseService = FirebaseService();

  bool _backendHealthy = false;
  List<String> _suggestions = [];

  // Each message: { 'role': 'user'|'assistant'|'error', 'content': '...' }
  // While streaming, the last assistant message grows token by token.
  final List<Map<String, String>> _chatHistory = [];

  // True while we are actively receiving tokens from the stream
  bool _isStreaming = false;

  // Cancels the stream subscription when the user navigates away
  StreamSubscription<String>? _streamSub;

  @override
  void initState() {
    super.initState();
    _checkBackendHealth();
    _loadSuggestions();
  }

  @override
  void dispose() {
    // Cancel any in-flight stream so we don't get setState after dispose
    _streamSub?.cancel();
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Backend health ────────────────────────────────────────────

  Future<void> _checkBackendHealth() async {
    final healthy = await AiService.checkHealth();
    if (!mounted) return;
    setState(() => _backendHealthy = healthy);

    if (!healthy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ AI backend is offline. Please start the Python server.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  // ── Smart suggestions ─────────────────────────────────────────

  Future<void> _loadSuggestions() async {
    final income     = await _firebaseService.getIncome();
    final deductions = await _firebaseService.getDeductions();
    final suggestions = await AiService.getSmartSuggestions(
      income:     (income?['totalIncome']         ?? 0).toDouble(),
      deductions: (deductions?['totalDeductions']  ?? 0).toDouble(),
    );
    if (mounted) setState(() => _suggestions = suggestions);
  }

  // ── Core: ask a question with STREAMING ──────────────────────

  Future<void> _askQuestion(String question) async {
    if (question.trim().isEmpty || _isStreaming) return;

    if (!_backendHealthy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI backend is not available. Please start the server.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _queryController.clear();

    // 1. Add the user bubble
    setState(() {
      _chatHistory.add({'role': 'user', 'content': question});
      // 2. Add an empty assistant bubble that will grow as tokens arrive
      _chatHistory.add({'role': 'assistant', 'content': ''});
      _isStreaming = true;
    });

    _scrollToBottom();

    // 3. Subscribe to the token stream
    _streamSub = AiService.queryTaxAdviceStream(question).listen(
      // onData — called for every token the LLM produces
      (token) {
        if (!mounted) return;
        setState(() {
          // Append the token to the last message (the assistant bubble)
          final last = _chatHistory.last;
          _chatHistory[_chatHistory.length - 1] = {
            'role':    last['role']!,
            'content': last['content']! + token,
          };
        });
        _scrollToBottom();
      },

      // onError — something went wrong with the HTTP connection
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _chatHistory[_chatHistory.length - 1] = {
            'role':    'error',
            'content': '❌ Connection error: $error',
          };
          _isStreaming = false;
        });
      },

      // onDone — stream closed cleanly (backend sent done:true)
      onDone: () {
        if (!mounted) return;
        // If the assistant bubble is still empty after the stream closes,
        // the backend likely declined the query — show a fallback message.
        setState(() {
          final last = _chatHistory.last;
          if (last['content']!.trim().isEmpty) {
            _chatHistory[_chatHistory.length - 1] = {
              'role':    'error',
              'content': '❌ No response received. The backend may have rejected the query.',
            };
          }
          _isStreaming = false;
        });
        _scrollToBottom();
      },

      cancelOnError: true,
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Markdown-style text rendering ────────────────────────────

  List<TextSpan> _parseMessageText(String content) {
    final spans   = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*|\*\s(.+?)(?=\n|\*|$)');
    int lastIndex = 0;

    for (final match in pattern.allMatches(content)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: content.substring(lastIndex, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1)!,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: '• ${match.group(2)!}',
          style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 15),
        ));
      }
      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      spans.add(TextSpan(text: content.substring(lastIndex)));
    }
    return spans.isEmpty ? [TextSpan(text: content)] : spans;
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Tax Advisor',
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
        actions: [
          // Backend status indicator
          IconButton(
            icon: Icon(
              _backendHealthy ? Icons.cloud_done : Icons.cloud_off,
              color: _backendHealthy ? Colors.greenAccent : Colors.redAccent,
            ),
            onPressed: _checkBackendHealth,
            tooltip: _backendHealthy ? 'Backend healthy' : 'Backend offline',
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline banner
          if (!_backendHealthy)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.orange.shade100,
              child: const Text(
                '⚠️ AI backend offline. Run: python backend/api.py',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),

          // Chat area
          Expanded(
            child: _chatHistory.isEmpty
                ? _buildWelcomeScreen()
                : _buildChatHistory(),
          ),

          // Streaming indicator (replaces the old spinner)
          if (_isStreaming)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  _buildTypingDots(),
                  const SizedBox(width: 10),
                  Text(
                    'Finora is thinking…',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          _buildInputField(),
        ],
      ),
    );
  }

  // ── Animated typing dots ──────────────────────────────────────

  Widget _buildTypingDots() {
    return SizedBox(
      width: 36,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (i) => _Dot(delay: i * 200)),
      ),
    );
  }

  // ── Welcome screen ────────────────────────────────────────────

  Widget _buildWelcomeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.smart_toy, size: 64, color: Colors.indigo),
          const SizedBox(height: 16),
          const Text(
            'AI Tax Advisor',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Powered by your custom RAG system with Indian tax documents. Ask me anything about:',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          ...[
            '📊 Income Tax Slabs & Rates',
            '💰 Tax Deductions (80C, 80D, etc.)',
            '🏢 GST Rates & Compliance',
            '📈 Capital Gains Tax',
            '🏦 Presumptive Taxation',
            '📝 Tax Filing Requirements',
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(item, style: const TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Quick Questions:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ..._suggestions.take(6).map(_buildSuggestionChip),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String suggestion) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _askQuestion(suggestion),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 20, color: Colors.indigo),
              const SizedBox(width: 8),
              Expanded(
                child: Text(suggestion, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Chat history ──────────────────────────────────────────────

  Widget _buildChatHistory() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _chatHistory.length,
      itemBuilder: (context, index) {
        final message = _chatHistory[index];
        final isUser  = message['role'] == 'user';
        final isError = message['role'] == 'error';
        final content = message['content'] ?? '';

        // The last assistant message while streaming gets a blinking cursor
        final isStreaming = _isStreaming &&
            index == _chatHistory.length - 1 &&
            !isUser;

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            decoration: BoxDecoration(
              color: isUser
                  ? Colors.indigo
                  : isError
                      ? Colors.red.shade100
                      : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    // Show a blinking cursor at the end while streaming
                    children: [
                      ..._parseMessageText(content),
                      if (isStreaming)
                        const TextSpan(
                          text: '▌',
                          style: TextStyle(
                            color: Colors.indigo,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                    ],
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Input field ───────────────────────────────────────────────

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _queryController,
              // Disable input while streaming so user can't send a second
              // question before the first one finishes
              enabled: !_isStreaming,
              decoration: InputDecoration(
                hintText: _isStreaming
                    ? 'Waiting for response…'
                    : 'Ask about tax, GST, deductions…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: _isStreaming ? null : _askQuestion,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            // Grey out the send button while streaming
            onPressed: _isStreaming
                ? null
                : () => _askQuestion(_queryController.text),
            icon: _isStreaming
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            style: IconButton.styleFrom(
              backgroundColor: _isStreaming ? Colors.grey.shade300 : Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated bouncing dot widget ──────────────────────────────────

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    // Stagger each dot by its delay before starting the loop
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Colors.indigo,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}