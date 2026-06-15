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
          'Priority': 'test',
          'Date': 'test',
          'User': 'test'
        },
      }),
    );

    print(response.body);
  } catch (e) {
    print('Network error: $e');
  }
}
