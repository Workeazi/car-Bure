import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = 'https://docs.google.com/spreadsheets/d/1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM/export?format=csv&gid=0';
  final response = await http.get(Uri.parse(url));
  final lines = LineSplitter.split(response.body).toList();
  print(lines.last);
}
