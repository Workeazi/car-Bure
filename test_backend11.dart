import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    String url = 'https://workeazi-backend.onrender.com/fetchKilnData?sheetName=Kiln%20A';
    final response = await http.get(Uri.parse(url));
    final data = jsonDecode(response.body)['data'] as List;
    print(data.last);
  } catch (e) {
    print('Network error: $e');
  }
}
