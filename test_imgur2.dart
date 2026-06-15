import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final file = File('dummy.jpg');
  final request = http.MultipartRequest('POST', Uri.parse('https://api.imgur.com/3/image'));
  request.headers['Authorization'] = 'Client-ID 546c25a59c58ad7';
  request.files.add(await http.MultipartFile.fromPath('image', file.path));
  
  try {
    final response = await request.send();
    final resBody = await response.stream.bytesToString();
    print('Status: ${response.statusCode}');
    print(resBody);
  } catch (e) {
    print('Error: $e');
  }
}
