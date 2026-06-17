import 'package:http/http.dart' as http;

void main() async {
  try {
    String url = 'https://workeazi-backend.onrender.com/fetchSheetData?sheetName=Remark%20';
    final response = await http.get(Uri.parse(url));
    print(response.body);
  } catch (e) {
    print('Network error: $e');
  }
}
