import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final file = File('test_image.png');
  await file.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 252, 207, 240, 31, 0, 4, 136, 1, 39, 13, 241, 175, 18, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]);
  
  final request = http.MultipartRequest('POST', Uri.parse('https://catbox.moe/user/api.php'));
  request.fields['reqtype'] = 'fileupload';
  request.files.add(await http.MultipartFile.fromPath('fileToUpload', file.path));
  
  final response = await request.send();
  print('Status code: ${response.statusCode}');
  if (response.statusCode == 200) {
    print('Response: ${await response.stream.bytesToString()}');
  } else {
    print('Failed: ${await response.stream.bytesToString()}');
  }
}
