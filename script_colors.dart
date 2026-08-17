import 'dart:io';

void main() {
  var f = File('lib/home_screen.dart');
  var content = f.readAsStringSync();
  
  // Replace const Color(0xFF667EEA) with _appPrimaryColor
  content = content.replaceAll(RegExp(r'const\s+Color\(0xFF667EEA\)'), '_appPrimaryColor');
  
  // Replace Color(0xFF667EEA) with _appPrimaryColor
  content = content.replaceAll('Color(0xFF667EEA)', '_appPrimaryColor');

  // Insert _appPrimaryColor getter in _HomeScreenState
  var stateDecl = 'class _HomeScreenState extends State<HomeScreen> {';
  var getterStr = '\n\n  Color get _appPrimaryColor {\n    return _getSheetToFetch().trim().toUpperCase() == \'STORE _MATERIAL_STOCK _LIST\'\n        ? Colors.green\n        : const Color(0xFF667EEA);\n  }';
  
  content = content.replaceFirst(stateDecl, stateDecl + getterStr);

  f.writeAsStringSync(content);
  print('Replaced colors successfully!');
}
