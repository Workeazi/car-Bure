import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = 'https://workeazi-backend.onrender.com/editRow?sheetName=GC%20Data';
  final response = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'ivNo': 'CSC 10',
      'updates': {'\u20B9 CHARCOAL PER KG/PRICE': '555'},
      'identifierKey': 'Invoice Number',
      'identifierValue': 'CSC 10',
      'originalData': {
        'Invoice Number': 'CSC 10',
        'Party': 'WORKEAZIEE',
        'OVERALL debit qty': '1449'
      }
    }),
  );

  print('Status: ${response.statusCode}');
  print('Body: ${response.body}');
}
