import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://docs.google.com/spreadsheets/d/1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM/export?format=csv&gid=706677096';
  final response = await http.get(Uri.parse(url));
  print(response.body);
  print('Length: ${response.body.length}');
  print('First chars: ${response.body.codeUnits.take(10).toList()}');
}
