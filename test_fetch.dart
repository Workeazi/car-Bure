import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = 'https://workeazi-backend.onrender.com/fetchSheetData?sheetName=Remark';
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body)['data'] as List;
    if (data.isNotEmpty) {
      print('Keys: ${data.last.keys.toList()}');
    }
  }
}
