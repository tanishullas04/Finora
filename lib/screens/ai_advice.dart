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

  bool _loading = false;
  bool _backendHealthy = false;
  List<String> _suggestions = [];
  final List<Map<String, String>> _chatHistory = [];
  StreamSubscription<String>? _streamSub;

  @override
  void initState() {
    super.initState();
    _checkBackendHealth();
    _loadSuggestions();
  }

  Future<void> _checkBackendHealth() async {
    final healthy = await AiService.checkHealth();
    setState(() => _backendHealthy = healthy);

    if (!healthy && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ AI backend is offline. Please start the Python server.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _loadSuggestions() async {
    final income = await _firebaseService.getIncome();
    final deductions = await _firebaseService.getDeductions();

    final suggestions = await AiService.getSmartSuggestions(
      income: income?['totalIncome'] ?? 0,
      deductions: deductions?['totalDeductions'] ?? 0,
    );

    setState(() => _suggestions = suggestions);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _askQuestion(String question) async {
    if (question.trim().isEmpty || _loading) return;

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
    setState(() {
      _loading = true;
      _chatHistory.add({'role': 'user', 'content': question});
      // Add empty assistant bubble that will fill token by token
      _chatHistory.add({'role': 'assistant', 'content': ''});
    });
    _scrollToBottom();

    await _streamSub?.cancel();
    _streamSub = AiService.queryTaxAdviceStream(question).listen(
      (token) {
        if (!mounted) return;
        setState(() {
          final last = _chatHistory.last;
          _chatHistory[_chatHistory.length - 1] = {
            ...last,
            'content': (last['content'] ?? '') + token,
          };
        });
        _scrollToBottom();
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _chatHistory[_chatHistory.length - 1] = {
            'role': 'error',
            'content': '❌ \$e',
          };
          _loading = false;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _loading = false);
        _scrollToBottom();
      },
    );
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Parse markdown-style formatting in the message
  List<TextSpan> _parseMessageText(String content) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*|\*\s(.+?)(?=\n|\*|$)');
    int lastIndex = 0;

    for (final match in pattern.allMatches(content)) {
      // Add text before this match
      if (match.start > lastIndex) {
        final text = content.substring(lastIndex, match.start);
        spans.add(TextSpan(text: text));
      }

      // Check if it's bold text (**text**)
      if (match.group(1) != null) {
        spans.add(
          TextSpan(
            text: match.group(1)!,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        );
      }
      // Check if it's a bullet point (* text)
      else if (match.group(2) != null) {
        spans.add(
          TextSpan(
            text: '• ${match.group(2)!}',
            style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 15),
          ),
        );
      }

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < content.length) {
      spans.add(TextSpan(text: content.substring(lastIndex)));
    }

    return spans.isEmpty ? [TextSpan(text: content)] : spans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "AI Tax Advisor",
          style: TextStyle(color: Colors.white, fontSize: 27),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          // Status banner
          if (!_backendHealthy)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.orange.shade100,
              child: const Text(
                '⚠️ AI backend offline. Start: python backend/api.py',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),

          // Chat History
          Expanded(
            child: _chatHistory.isEmpty
                ? _buildWelcomeScreen()
                : _buildChatHistory(),
          ),

          // Loading indicator
          if (_loading && (_chatHistory.isEmpty || _chatHistory.last['content']!.isEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _WaveDots(),
                  const SizedBox(width: 12),
                  const Text('Finora is thinking…', style: TextStyle(fontSize: 13, color: Colors.black54)),
                ],
              ),
            ),

          // Input field
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.smart_toy, size: 64, color: Colors.indigo),
          const SizedBox(height: 16),
          const Text(
            "AI Tax Advisor",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Powered by your custom RAG system with Indian tax documents. Ask me anything about:",
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
            "Quick Questions:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ..._suggestions
              .take(6)
              .map((suggestion) => _buildSuggestionChip(suggestion)),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String suggestion) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _askQuestion(suggestion),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: Colors.indigo,
              ),
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

  Widget _buildChatHistory() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _chatHistory.length,
      itemBuilder: (context, index) {
        final message = _chatHistory[index];
        final isUser = message['role'] == 'user';
        final isError = message['role'] == 'error';
        final processingTime = message['processing_time'];

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
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
                    children: _parseMessageText(message['content']!),
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                      height: 1.5,
                    ),
                  ),
                ),
                if (processingTime != null && processingTime.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '⚡ ${processingTime}s',
                      style: TextStyle(
                        fontSize: 11,
                        color: isUser ? Colors.white70 : Colors.black45,
                        fontWeight: FontWeight.w400,
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

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              decoration: InputDecoration(
                hintText: "Ask about tax, GST, deductions...",
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
              onSubmitted: _askQuestion,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _askQuestion(_queryController.text),
            icon: const Icon(Icons.send),
            style: IconButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wave dots typing indicator ───────────────────────────────────────────────
class _WaveDots extends StatefulWidget {
  const _WaveDots();
  @override
  State<_WaveDots> createState() => _WaveDotsState();
}

class _WaveDotsState extends State<_WaveDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot is offset by 1/3 of the cycle
            final double offset = (i / 3);
            // Map the animation value to a sine wave, shifted per dot
            final double t = (_ctrl.value + offset) % 1.0;
            final double dy = -6 * (1 - (2 * t - 1).abs()); // triangle wave: peak at t=0.5
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.indigo,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}