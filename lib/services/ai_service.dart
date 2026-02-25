import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  // Change this based on your setup:
  // - Local development: 'http://localhost:5001'
  // - Android emulator: 'http://10.0.2.2:5001'
  // - iOS simulator: 'http://localhost:5001'
  // - Production: your deployed backend URL
  static const String baseUrl = 'http://localhost:5001';

  /// Query the tax advisor AI using your run_query.py RAG system
  static Future<Map<String, dynamic>> queryTaxAdvice(String question) async {
    try {
      print('[AI Service] Querying: $question');
      
      final response = await http.post(
        Uri.parse('$baseUrl/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': question}),
      ).timeout(
        const Duration(seconds: 150),
        onTimeout: () {
          throw Exception('Request timed out. The AI is taking too long to respond.');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[AI Service] Success: ${data['processing_time']}s');
        return data;
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('[AI Service] Error: $e');
      return {
        'success': false,
        'error': 'Connection error: $e',
      };
    }
  }

  /// Get smart query suggestions based on user's financial data
  static Future<List<String>> getSmartSuggestions({
    required double income,
    required double deductions,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/suggestions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'income': income,
          'deductions': deductions,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<String>.from(data['suggestions']);
        }
      }
    } catch (e) {
      print('[AI Service] Error getting suggestions: $e');
    }

    // Fallback suggestions if API fails
    return [
      "What are the tax rates for different income slabs?",
      "How can I maximize my tax deductions?",
      "What is the difference between old and new tax regime?",
      "What are the GST rates?",
      "How is capital gains tax calculated?",
    ];
  }

  /// Check if the backend is healthy
  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
