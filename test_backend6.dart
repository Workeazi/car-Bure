import 'package:http/http.dart' as http;

void main() async {
  try {
    String url = 'https://workeazi-backend.onrender.com/fetchSheetData';
    final response = await http.get(Uri.parse(url));
    print(response.body.substring(0, 100)); // Just print first 100 chars
  } catch (e) {
    print('Network error: $e');
  }
}
