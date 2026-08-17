import 'dart:io';

void main() {
  var f = File('lib/home_screen.dart');
  var lines = f.readAsLinesSync();
  
  lines[2036 - 1] = lines[2036 - 1].replaceFirst('const Text', 'Text');
  lines[2534 - 1] = lines[2534 - 1].replaceFirst('const TextStyle', 'TextStyle');
  
  // Need to find the last error which is around line 4044
  for (int i = 4035; i <= 4050; i++) {
    if (lines[i].contains('const TextStyle')) {
      lines[i] = lines[i].replaceFirst('const TextStyle', 'TextStyle');
      break;
    }
  }

  f.writeAsStringSync('${lines.join('\n')}\n');
  print('Fixed remaining consts!');
}
