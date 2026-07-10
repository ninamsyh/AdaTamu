import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'cloudinary_config.dart';

class CloudinaryService {
  static Future<String> uploadImage(File file) async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload',
    );

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
    } catch (e) {
      throw Exception(
        'Tidak bisa upload foto. Periksa koneksi internet kamu.\n($e)',
      );
    }

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        'Gagal upload foto ke Cloudinary (${response.statusCode}): '
        '${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final secureUrl = data['secure_url'] as String?;
    if (secureUrl == null) {
      throw Exception('Respons Cloudinary tidak berisi secure_url.');
    }
    return secureUrl;
  }
}
