import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiService {
  // ─────────────────────────────────────────────────────────────
  // BASE URL — auto-selected based on platform:
  //
  //   Android emulator  → 10.0.2.2  (maps to host machine localhost)
  //   iOS simulator     → 127.0.0.1
  //   Physical device   → set YOUR_MACHINE_IP to your LAN IP
  //                       e.g. '192.168.1.42'
  //                       Find it with: ipconfig (Windows) / ifconfig (Mac)
  // ─────────────────────────────────────────────────────────────
  static const String _physicalDeviceIp = 'YOUR_MACHINE_IP'; // ← change this
  static const int _port = 5001;

  static String get baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:$_port';
    if (Platform.isAndroid) {
      return _isEmulator()
          ? 'http://10.0.2.2:$_port'      // emulator → host machine
          : 'http://$_physicalDeviceIp:$_port'; // physical device → LAN IP
    }
    return 'http://127.0.0.1:$_port'; // iOS / macOS / desktop
  }

  // Best-effort emulator detection
  static bool _isEmulator() {
    try {
      return Platform.environment.containsKey('ANDROID_EMULATOR_HOST') ||
          Platform.environment['HOME'] == '/root';
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // STREAMING query → yields tokens one at a time via a Stream
  // ─────────────────────────────────────────────────────────────
  static Stream<String> queryTaxAdviceStream(String question) async* {
    final uri = Uri.parse('$baseUrl/query/stream');
    debugPrint('[AI] Streaming from: $uri');

    final client = http.Client();
    try {
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'text/event-stream'
        ..headers['Cache-Control'] = 'no-cache'
        ..body = jsonEncode({'query': question});

      final response = await client.send(request).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception(
            'Timed out connecting to $uri\n'
            'Is the Python server running?'),
      );

      if (response.statusCode != 200) {
        yield '[ERROR] Server returned ${response.statusCode}';
        return;
      }

      debugPrint('[AI] Stream connected ✓');
      final StringBuffer buf = StringBuffer();

      await for (final chunk in response.stream) {
        buf.write(utf8.decode(chunk, allowMalformed: true));
        final parts = buf.toString().split('\n\n');

        for (int i = 0; i < parts.length - 1; i++) {
          final event = parts[i].trim();
          if (!event.startsWith('data: ')) continue;
          try {
            final decoded = jsonDecode(event.substring(6)) as Map<String, dynamic>;
            if (decoded['done'] == true) return;
            if (decoded.containsKey('error')) {
              yield '[ERROR] ${decoded['error']}';
              return;
            }
            final token = decoded['chunk'] as String? ?? '';
            if (token.isNotEmpty) yield token;
          } catch (_) {}
        }
        buf.clear();
        buf.write(parts.last);
      }
    } on SocketException catch (e) {
      yield '❌ Cannot connect to backend at $baseUrl\n\n'
          'Error: ${e.message}\n\n'
          'Check:\n'
          '• Python server is running (python backend/api.py)\n'
          '• If on a physical device, set _physicalDeviceIp in ai_service.dart\n'
          '• Your phone and PC are on the same WiFi';
    } catch (e) {
      yield '[ERROR] $e';
    } finally {
      client.close();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Non-streaming fallback
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> queryTaxAdvice(String question) async {
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/query'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'query': question}))
          .timeout(const Duration(seconds: 150));
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {'success': false, 'error': 'Server error: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Smart suggestions
  // ─────────────────────────────────────────────────────────────
  static Future<List<String>> getSmartSuggestions({
    required double income,
    required double deductions,
  }) async {
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/suggestions'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'income': income, 'deductions': deductions}))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return List<String>.from(data['suggestions']);
      }
    } catch (e) {
      debugPrint('[AI] Suggestions error: $e');
    }
    return [
      "What are the tax rates for different income slabs?",
      "How can I maximize my tax deductions?",
      "What is the difference between old and new tax regime?",
      "What are the GST rates?",
      "How is capital gains tax calculated?",
    ];
  }

  // ─────────────────────────────────────────────────────────────
  // Health check — logs the exact URL being tested
  // ─────────────────────────────────────────────────────────────
  static Future<bool> checkHealth() async {
    final url = '$baseUrl/health';
    debugPrint('[AI] Health check → $url');
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      debugPrint('[AI] Health status: ${response.statusCode}');
      return response.statusCode == 200;
    } on SocketException catch (e) {
      debugPrint('[AI] SocketException: ${e.message} | URL: $url');
      if (!kIsWeb && Platform.isAndroid) {
        debugPrint('[AI] If on a physical device, set _physicalDeviceIp in ai_service.dart');
      }
      return false;
    } catch (e) {
      debugPrint('[AI] Health check failed: $e');
      return false;
    }
  }
}