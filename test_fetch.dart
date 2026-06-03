import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final response = await http.get(Uri.parse('https://workeazi-backend.onrender.com/fetchSheet2Data?_t=$timestamp'));
  print(response.statusCode);
  print(response.body);
}
