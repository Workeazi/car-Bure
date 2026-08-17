import 'dart:io';

void main() {
  var file = File('lib/home_screen.dart');
  var content = file.readAsStringSync();

  // 1. Fix recursive getter
  content = content.replaceFirst(
'''
  Color get _appSecondaryColor {
    return _getSheetToFetch().trim().toUpperCase() == 'STORE _MATERIAL_STOCK _LIST'
        ? Colors.teal.shade300
        : _appSecondaryColor;
  }
''',
'''
  Color get _appSecondaryColor {
    return _getSheetToFetch().trim().toUpperCase() == 'STORE _MATERIAL_STOCK _LIST'
        ? Colors.teal.shade300
        : const Color(0xFF8B5CF6);
  }
'''
  );
  // Also try replacing without the exact spacing in case it doesn't match:
  content = content.replaceAll('? Colors.teal.shade300\n        : _appSecondaryColor;', '? Colors.teal.shade300\n        : const Color(0xFF8B5CF6);');

  // 2. Add parameters to AnimatedGradientBackground
  content = content.replaceFirst(
    'class AnimatedGradientBackground extends StatefulWidget {',
    'class AnimatedGradientBackground extends StatefulWidget {\n  final Color primaryColor;\n  final Color secondaryColor;\n'
  );
  
  content = content.replaceFirst(
    'const AnimatedGradientBackground({super.key});',
    'const AnimatedGradientBackground({super.key, required this.primaryColor, required this.secondaryColor});'
  );

  // 3. Pass parameters from HomeScreen
  content = content.replaceFirst(
    'const AnimatedGradientBackground(),',
    'AnimatedGradientBackground(primaryColor: _appPrimaryColor, secondaryColor: _appSecondaryColor),'
  );

  // 4. Update the usage inside _AnimatedGradientBackgroundState
  // We need to replace any remaining `_appSecondaryColor` with `widget.secondaryColor` in the background widget.
  // And if there are any `_appPrimaryColor`, with `widget.primaryColor`.
  content = content.replaceAll(
    'color: _appSecondaryColor.withValues(alpha: 0.15),',
    'color: widget.secondaryColor.withValues(alpha: 0.15),'
  );
  
  // It's possible I replaced a hardcoded _appPrimaryColor inside AnimatedGradientBackground too!
  content = content.replaceAll(
    'color: _appPrimaryColor.withValues(alpha: 0.1),',
    'color: widget.primaryColor.withValues(alpha: 0.1),'
  );

  file.writeAsStringSync(content);
  print('Fixed background params and getter recursion!');
}
