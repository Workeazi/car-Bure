import 'dart:convert';

void main() {
  String widgetPermissions = '''[{"sheet":"CarbonInput","Permissions":["Grade","IV No","CHARCOAL Kg","Bag Weight"]},{"sheet":"Kiln B","Permissions":["Grade","CTC"]},{"sheet":"Kiln A","Permissions":["Yield","O Qty","Grade"]}]''';
  String currentSheet = 'carboninput';

  List<String> columns = [];
  try {
    String safePermsJson = widgetPermissions.replaceAll('“', '"').replaceAll('”', '"');
    if (safePermsJson.trim().startsWith('[')) {
      final List<dynamic> parsedPerms = jsonDecode(safePermsJson);
      for (var item in parsedPerms) {
        if (item is Map) {
           String sheetName = (item['sheet'] ?? '').toString().trim().toLowerCase();
           print("Found sheet: " + sheetName + ", checking against " + currentSheet);
           if (sheetName == currentSheet || sheetName == 'all') {
              final fields = item['Permissions'] ?? item['fields'] ?? item['permissions'];
              print("Fields: " + fields.toString());
              if (fields is List) {
                columns = fields.map((e) => e.toString().trim()).toList();
              }
              break;
           }
        }
      }
    } else {
      columns = widgetPermissions.split(',').map((e) => e.trim()).toList();
    }
  } catch (e) {
    print("Perms JSON Parse Error: " + e.toString());
    columns = widgetPermissions.split(',').map((e) => e.trim()).toList();
  }

  print("Columns: " + columns.toString());
}
