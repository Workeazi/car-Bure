import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://docs.google.com/spreadsheets/d/1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM/gviz/tq?tqx=out:json&sheet=Remark';
  final response = await http.get(Uri.parse(url));
  print(response.body);
}
