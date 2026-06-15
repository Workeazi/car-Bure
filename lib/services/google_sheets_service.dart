import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleSheetsService {
  static String spreadsheetId = '1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM';

  // For production, replace this with your deployed backend URL.
  static const String baseUrl = 'https://workeazi-backend.onrender.com';

  // Returns null on success, error message on failure
  static Future<String?> editRow({
    required String ivNo, // kept for backward compatibility if not provided
    required Map<String, String> updates,
    String? sheetName,
    String? identifierKey,
    String? identifierValue,
    Map<String, String>? originalData,
  }) async {
    try {
      String url = '$baseUrl/editRow';
      if (sheetName != null && sheetName.trim().isNotEmpty) {
        url += '?sheetName=${Uri.encodeComponent(sheetName.trim())}';
      }
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ivNo': ivNo,
          'updates': updates,
          'identifierKey': identifierKey,
          'identifierValue': identifierValue,
          'originalData': originalData,
        }),
      );

      if (response.statusCode == 200) {
        return null;
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        return 'Backend error: $error';
      }
    } catch (e) {
      return 'Network error: $e';
    }
  }

  // Returns null on success, error message on failure
  static Future<String?> clearRowToNil({
    required String ivNo,
    required List<String> permittedColumns,
    String? sheetName,
    String? identifierKey,
    String? identifierValue,
  }) async {
    try {
      String url = '$baseUrl/clearRowToNil';
      if (sheetName != null && sheetName.trim().isNotEmpty) {
        url += '?sheetName=${Uri.encodeComponent(sheetName.trim())}';
      }
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ivNo': ivNo,
          'permittedColumns': permittedColumns,
          'identifierKey': identifierKey,
          'identifierValue': identifierValue,
        }),
      );

      if (response.statusCode == 200) {
        return null;
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        return 'Backend error: $error';
      }
    } catch (e) {
      return 'Network error: $e';
    }
  }

  // Returns null on success, error message on failure
  static Future<String?> addRow({
    required Map<String, String> rowData,
    String? sheetName,
  }) async {
    try {
      String url = '$baseUrl/addRow';
      if (sheetName != null && sheetName.trim().isNotEmpty) {
        url += '?sheetName=${Uri.encodeComponent(sheetName.trim())}';
      }
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'rowData': rowData,
        }),
      );

      if (response.statusCode == 200) {
        return null;
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        return 'Backend error: $error';
      }
    } catch (e) {
      return 'Network error: $e';
    }
  }

  /// Fetches data from the main sheet (gid=0).
  /// If [sheetName] is provided, fetches that specific sheet instead.
  static Future<List<Map<String, String>>?> fetchSheetData({String? sheetName}) async {
    try {
      String url = '$baseUrl/fetchSheetData';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      if (sheetName != null && sheetName.trim().isNotEmpty) {
        url += '?sheetName=${Uri.encodeComponent(sheetName.trim())}&_t=$timestamp';
      } else {
        url += '?_t=$timestamp';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'] as List;
        return data.map((e) => Map<String, String>.from(e)).toList();
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        throw Exception('Backend returned ${response.statusCode}: $error');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      return null;
    }
  }

  /// Fetches data from the Kiln sheet (or any sheet by name via [sheetName]).
  static Future<List<Map<String, String>>?> fetchKilnData({String sheetName = 'Kiln A'}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = '$baseUrl/fetchKilnData?sheetName=${Uri.encodeComponent(sheetName)}&_t=$timestamp';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'] as List;
        return data.map((e) => Map<String, String>.from(e)).toList();
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        throw Exception('Backend returned ${response.statusCode}: $error');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      return null;
    }
  }

  /// Deletes a row from the main sheet identified by [ivNo].
  static Future<String?> deleteRow({required String ivNo}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/deleteRow'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ivNo': ivNo}),
      );
      if (response.statusCode == 200) {
        return null;
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        return 'Backend error: $error';
      }
    } catch (e) {
      return 'Network error: $e';
    }
  }

  static Future<List<Map<String, String>>?> fetchSheet2Data() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$baseUrl/fetchSheet2Data?_t=$timestamp'),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'] as List;
        return data.map((e) => Map<String, String>.from(e)).toList();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> updateSheet2Row({
    required String employeeId,
    required Map<String, String> updates,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/updateSheet2Row'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'employeeId': employeeId,
          'updates': updates,
        }),
      );

      if (response.statusCode == 200) {
        return null;
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        return 'Backend error: $error';
      }
    } catch (e) {
      return 'Network error: $e';
    }
  }
}
