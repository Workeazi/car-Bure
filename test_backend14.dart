import 'package:http/http.dart' as http;

void main() async {
  try {
    String url = 'https://workeazi-backend.onrender.com/addRow';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: '{"rowData": null}',
    );
    print(response.body);
  } catch (e) {
    print('Network error: $e');
  }
}
