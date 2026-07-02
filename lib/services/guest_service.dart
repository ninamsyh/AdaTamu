import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/guest.dart';
import 'firebase_config.dart';

class GuestService {
  static Future<void> saveGuest(Guest guest, {File? foto}) async {
    final Map<String, dynamic> data = guest.toMap();

    if (foto != null) {
      final String fotoUrl = await _uploadFoto(foto, guest.kodeTamu);
      data['foto'] = fotoUrl;
    }

    final url = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${FirebaseConfig.projectId}'
      '/databases/(default)/documents/${FirebaseConfig.collection}'
      '?documentId=${Uri.encodeComponent(guest.kodeTamu)}'
      '&key=${FirebaseConfig.apiKey}',
    );

    final body = jsonEncode({'fields': _toFirestoreFields(data)});

    http.Response response;
    try {
      response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception(
        'Tidak bisa terhubung ke server. Periksa koneksi internet kamu.\n($e)',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Gagal menyimpan data ke Firestore (${response.statusCode}): '
        '${response.body}',
      );
    }
  }

  static Future<void> markSelesai(String kodeTamu) async {
    final String docName =
        '${FirebaseConfig.projectId}/databases/(default)/documents/'
        '${FirebaseConfig.collection}/${Uri.encodeComponent(kodeTamu)}';

    final url = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$docName'
      '?updateMask.fieldPaths=status'
      '&updateMask.fieldPaths=waktuSelesai'
      '&key=${FirebaseConfig.apiKey}',
    );

    final body = jsonEncode({
      'fields': {
        'status': {'stringValue': 'selesai'},
        'waktuSelesai': {
          'timestampValue': DateTime.now().toUtc().toIso8601String(),
        },
      },
    });

    http.Response response;
    try {
      response = await http
          .patch(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception(
        'Tidak bisa terhubung ke server. Periksa koneksi internet kamu.\n($e)',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Gagal menandai selesai (${response.statusCode}): ${response.body}',
      );
    }
  }

  static Future<String> _uploadFoto(File foto, String kodeTamu) async {
    final String fileName =
        'guests/${kodeTamu}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String encodedName = Uri.encodeComponent(fileName);

    final url = Uri.parse(
      'https://firebasestorage.googleapis.com/v0/b/'
      '${FirebaseConfig.storageBucket}/o'
      '?uploadType=media&name=$encodedName&key=${FirebaseConfig.apiKey}',
    );

    final bytes = await foto.readAsBytes();

    http.Response response;
    try {
      response = await http
          .post(url, headers: {'Content-Type': 'image/jpeg'}, body: bytes)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw Exception('Tidak bisa upload foto.\n($e)');
    }

    if (response.statusCode != 200) {
      throw Exception(
          'Gagal upload foto (${response.statusCode}): ${response.body}');
    }

    final Map<String, dynamic> json = jsonDecode(response.body);
    final String? token = json['downloadTokens'] as String?;
    return 'https://firebasestorage.googleapis.com/v0/b/'
        '${FirebaseConfig.storageBucket}/o/$encodedName?alt=media'
        '${token != null ? '&token=$token' : ''}';
  }

  static Future<int> peekNextUrutanHariIni(DateTime date) async {
    final String counterId = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    final url = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${FirebaseConfig.projectId}'
      '/databases/(default)/documents/counters/$counterId'
      '?key=${FirebaseConfig.apiKey}',
    );

    http.Response response;
    try {
      response = await http.get(url).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception('Tidak bisa terhubung ke server.\n($e)');
    }

    if (response.statusCode == 404) return 1;

    if (response.statusCode != 200) {
      throw Exception(
          'Gagal ambil estimasi nomor urut (${response.statusCode}): '
          '${response.body}');
    }

    final Map<String, dynamic> json = jsonDecode(response.body);
    final Map<String, dynamic>? fields =
        json['fields'] as Map<String, dynamic>?;
    final String? countStr = fields?['count']?['integerValue'] as String?;
    final int currentCount = countStr != null ? int.parse(countStr) : 0;
    return currentCount + 1;
  }

  static Future<int> getNextUrutanHariIni(DateTime date) async {
    final String counterId = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    final url = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${FirebaseConfig.projectId}'
      '/databases/(default)/documents:commit?key=${FirebaseConfig.apiKey}',
    );

    final String docName =
        'projects/${FirebaseConfig.projectId}/databases/(default)/documents/'
        'counters/$counterId';

    final body = jsonEncode({
      'writes': [
        {
          'update': {'name': docName, 'fields': {}},
          'updateMask': {'fieldPaths': []},
          'updateTransforms': [
            {
              'fieldPath': 'count',
              'increment': {'integerValue': '1'},
            },
          ],
        },
      ],
    });

    http.Response response;
    try {
      response = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception('Tidak bisa terhubung ke server.\n($e)');
    }

    if (response.statusCode != 200) {
      throw Exception(
          'Gagal ambil nomor urut (${response.statusCode}): ${response.body}');
    }

    final Map<String, dynamic> json = jsonDecode(response.body);
    final List<dynamic> writeResults = json['writeResults'] as List<dynamic>;
    final Map<String, dynamic> transformResult =
        writeResults[0]['transformResults'][0] as Map<String, dynamic>;
    return int.parse(transformResult['integerValue'] as String);
  }

  static Map<String, dynamic> _toFirestoreFields(Map<String, dynamic> data) {
    final fields = <String, dynamic>{};
    data.forEach((key, value) {
      fields[key] = _toFirestoreValue(value);
    });
    return fields;
  }

  static Map<String, dynamic> _toFirestoreValue(dynamic value) {
    if (value is String) return {'stringValue': value};
    if (value is int) return {'integerValue': value};
    if (value is double) return {'doubleValue': value};
    if (value is bool) return {'booleanValue': value};
    if (value is DateTime) {
      return {'timestampValue': value.toUtc().toIso8601String()};
    }
    if (value is List) {
      return {
        'arrayValue': {
          'values': value.map(_toFirestoreValue).toList(),
        },
      };
    }
    return {'stringValue': value.toString()};
  }
}
