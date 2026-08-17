import 'dart:io';

void main() {
  var errorLines = [851, 879, 946, 1024, 1040, 1058, 1115, 1368, 1372, 1385, 1389, 1403, 1407, 1418, 1421, 1513, 1566, 1731, 1812, 1834, 1887, 1958, 1963, 1977, 2040, 2483, 2537, 3035, 3542, 4044];
  
  var f = File('lib/home_screen.dart');
  var lines = f.readAsLinesSync();
  
  for (var lineNum in errorLines) {
    var i = lineNum - 1; // 0-indexed
    
    // Check current line and up to 2 lines above for 'const '
    bool fixed = false;
    for (var j = i; j >= i - 2 && j >= 0; j--) {
      if (lines[j].contains('const ')) {
        lines[j] = lines[j].replaceFirst('const ', '');
        fixed = true;
        break;
      }
    }
    if (!fixed) {
      print('Could not fix line $lineNum');
    }
  }
  
  f.writeAsStringSync('${lines.join('\n')}\n');
  print('Fixed const errors successfully!');
}
