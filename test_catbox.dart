import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final file = File('dummy.jpg');
  final request = http.MultipartRequest('POST', Uri.parse('https://catbox.moe/user/api.php'));
  request.fields['reqtype'] = 'fileupload';
  request.files.add(await http.MultipartFile.fromPath('fileToUpload', file.path));
  
  try {
    final response = await request.send();
    final resBody = await response.stream.bytesToString();
    print('Status: ${response.statusCode}');
    print(resBody);
  } catch (e) {
    print('Error: $e');
  }
}
