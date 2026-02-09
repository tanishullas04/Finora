import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class OCRService {
  static const String backendUrl = 'http://localhost:5001';
  static const int timeoutSeconds = 30;

  Future<Map<String, dynamic>?> extractIncomeFromFile(
    Uint8List fileBytes,
    String fileName,
  ) async {
    try {
      print('OCRService: Starting file extraction...');
      print(
          'OCRService: Sending ${fileBytes.length} bytes to $backendUrl/api/extract-income');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendUrl/api/extract-income'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );

      print(
          'OCRService: Waiting for response (timeout: ${timeoutSeconds}s)...');

      final response = await request.send().timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          throw TimeoutException(
              'Backend did not respond within ${timeoutSeconds}s. Is the backend running on port 5001?');
        },
      );

      print('OCRService: Backend response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        print('OCRService: Response body: $responseData');

        final jsonData = jsonDecode(responseData);

        // 🔥 IMPORTANT: Normalize data to match new structure
        final normalizedData = {
          "grossSalary": _toDouble(jsonData["grossSalary"]),
          "taxableSalary": _toDouble(
              jsonData["taxableSalary"] ?? jsonData["salary"]),
          "otherIncome": _toDouble(jsonData["otherIncome"]),
          "rentalIncome": _toDouble(jsonData["rentalIncome"]),
          "businessIncome": _toDouble(jsonData["businessIncome"]),
        };

        print('OCRService: Normalized data: $normalizedData');

        return normalizedData;
      } else {
        final error = await response.stream.bytesToString();
        throw Exception(
            'Backend error (${response.statusCode}): $error');
      }
    } on TimeoutException {
      rethrow;
    } catch (e) {
      print('OCRService: Exception: $e');
      rethrow;
    }
  }

  // 🔹 Helper to safely convert values
  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0;
  }
}