import 'dart:io';

void main() {
  var file = File('lib/home_screen.dart');
  var content = file.readAsStringSync();

  // Replace secondary color usages
  content = content.replaceAll(
    'const Color(0xFF8B5CF6)', 
    '_appSecondaryColor'
  );
  content = content.replaceAll(
    'Color(0xFF8B5CF6)', 
    '_appSecondaryColor'
  );

  // Replace Issue Items button color
  content = content.replaceAll(
    'backgroundColor: const Color(0xFF3B82F6),',
    'backgroundColor: _appPrimaryColor,'
  );
  
  // Replace Issue Items floating action button background color in case it was missed
  content = content.replaceAll(
    'backgroundColor: Color(0xFF3B82F6),',
    'backgroundColor: _appPrimaryColor,'
  );

  file.writeAsStringSync(content);
  print('Replaced secondary colors and Issue Items button color!');
}
