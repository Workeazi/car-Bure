import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    var res3 = await http.get(Uri.parse('https://workeazi-backend.onrender.com/fetchSheetData?sheetName=GC%20Data'));
    Map<String, dynamic> body3 = jsonDecode(res3.body);
    List<dynamic> data = body3['data'];
    print('Row0: "${data[0]["\u20B9 CHARCOAL PER KG/PRICE"]}"');
    print('Row1: "${data[1]["\u20B9 CHARCOAL PER KG/PRICE"]}"');
  } catch (e) {
    print('error: $e');
  }
}
