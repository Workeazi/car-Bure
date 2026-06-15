import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final rowData = {
    'Priority': 'Medium',
    'Employee ID': '111110',
    'Department': 'staff',
    'Problem_text': 'test',
    'Problem_Images': 'No Image',
  };

  try {
    String url = 'https://workeazi-backend.onrender.com/addRow?sheetName=Remark';
    
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'rowData': rowData,
      }),
    );

    if (response.statusCode == 200) {
      print('Success');
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
      print('Backend error: $error');
    }
  } catch (e) {
    print('Network error: $e');
  }
}
