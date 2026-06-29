// File ini biasanya dibuat OTOMATIS dengan menjalankan:
//
//   flutterfire configure
//
// di root project ini (folder yang sejajar dengan pubspec.yaml). Itu cara
// PALING DIREKOMENDASIKAN karena flutterfire akan login ke akun Firebase
// kamu dan mengisi semua nilai di bawah secara otomatis untuk tiap platform.
//
// Untuk sementara, ini cuma PLACEHOLDER agar project tetap bisa dibuka/
// dianalisis. Ganti semua 'TODO_GANTI_...' dengan nilai asli dari:
// Firebase Console -> (pilih project) -> ikon gear -> Project settings
// -> scroll ke bagian "Your apps" -> pilih app yang sesuai platform
//    (atau klik "Add app" kalau belum ada)
// -> salin nilai apiKey, appId, messagingSenderId, projectId, dst.
//
// JANGAN commit file ini (dengan nilai asli) ke repo publik.

// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Pilihan konfigurasi Firebase berdasarkan platform yang sedang berjalan.
///
/// Pakai seperti ini di main.dart:
/// ```dart
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions belum dikonfigurasi untuk Linux. '
          'Jalankan `flutterfire configure` untuk menambahkan platform ini.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions tidak mendukung platform ini.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'TODO_GANTI_API_KEY',
    appId: 'TODO_GANTI_APP_ID',
    messagingSenderId: 'TODO_GANTI_SENDER_ID',
    projectId: 'TODO_GANTI_PROJECT_ID',
    authDomain: 'TODO_GANTI_PROJECT_ID.firebaseapp.com',
    storageBucket: 'TODO_GANTI_PROJECT_ID.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'TODO_GANTI_API_KEY',
    appId: 'TODO_GANTI_APP_ID',
    messagingSenderId: 'TODO_GANTI_SENDER_ID',
    projectId: 'TODO_GANTI_PROJECT_ID',
    storageBucket: 'TODO_GANTI_PROJECT_ID.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'TODO_GANTI_API_KEY',
    appId: 'TODO_GANTI_APP_ID',
    messagingSenderId: 'TODO_GANTI_SENDER_ID',
    projectId: 'TODO_GANTI_PROJECT_ID',
    storageBucket: 'TODO_GANTI_PROJECT_ID.appspot.com',
    iosBundleId: 'com.example.adatamu',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'TODO_GANTI_API_KEY',
    appId: 'TODO_GANTI_APP_ID',
    messagingSenderId: 'TODO_GANTI_SENDER_ID',
    projectId: 'TODO_GANTI_PROJECT_ID',
    storageBucket: 'TODO_GANTI_PROJECT_ID.appspot.com',
    iosBundleId: 'com.example.adatamu',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'TODO_GANTI_API_KEY',
    appId: 'TODO_GANTI_APP_ID',
    messagingSenderId: 'TODO_GANTI_SENDER_ID',
    projectId: 'TODO_GANTI_PROJECT_ID',
    authDomain: 'TODO_GANTI_PROJECT_ID.firebaseapp.com',
    storageBucket: 'TODO_GANTI_PROJECT_ID.appspot.com',
  );
}
