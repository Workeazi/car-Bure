import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://docs.google.com/spreadsheets/d/1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM/gviz/tq?tqx=out:csv&gid=751895921';
  final response = await http.get(Uri.parse(url));
  
  print('Sheet2 Data:');
  print(response.body);
}
