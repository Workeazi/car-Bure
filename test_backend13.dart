import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    String url = 'https://workeazi-backend.onrender.com/addRow?sheetName=Remark';
    
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'rowData': {
          'Priority': 'Low',
          'Employee ID': '12312',
          'Department': 'Admin',
          'Problem_text': 'Working',
          'Problem_Images': 'lkasnfkans'
        },
      }),
    );

    print('Response: ${response.body}');
  } catch (e) {
    print('Network error: $e');
  }
}
