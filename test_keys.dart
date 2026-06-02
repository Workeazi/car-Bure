import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  // Test main sheet data (CarbonInput)
  final r1 = await http.get(
    Uri.parse('https://workeazi-backend.onrender.com/fetchSheetData?sheetName=CarbonInput'),
  );
  print('fetchSheetData status: ${r1.statusCode}');
  if (r1.statusCode == 200) {
    final data = jsonDecode(r1.body)['data'] as List;
    print('Records count: ${data.length}');
    if (data.isNotEmpty) print('First record keys: ${data[0].keys.toList()}');
  } else {
    print('Error: ${r1.body}');
  }


  // Test user sheet data
  final r2 = await http.get(
    Uri.parse('https://workeazi-backend.onrender.com/fetchSheet2Data'),
  );
  if (r2.statusCode == 200) {
    final data = jsonDecode(r2.body)['data'] as List;
    print('\n--- USER PERMISSIONS ---');
    for (var user in data) {
      final empId = user['Employee ID'] ?? 'Unknown';
      final role = user['Role'] ?? user['Designation'] ?? 'Unknown';
      final permissions = user['Permissions'] ?? 'No permissions set';
      print('User: $empId (Role: $role)\nPermissions: $permissions\n');
    }
  } else {
    print('Error: ${r2.body}');
  }
}
