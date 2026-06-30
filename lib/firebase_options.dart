// File ini berisi kredensial Firebase asli untuk project "adatamu-bd8c1".
// Diisi manual berdasarkan Project settings -> Your apps di Firebase Console.
//
// Catatan: nilai untuk Android/iOS/macOS di bawah masih disalin dari
// konfigurasi Web sebagai sementara supaya project tetap bisa di-build.
// Kalau nanti mau jalankan di Android/iOS asli, sebaiknya isi ulang
// bagian itu dengan appId masing-masing platform (lihat google-services.json
// untuk Android, atau GoogleService-Info.plist untuk iOS), karena appId
// platform native BEDA dari appId web.

// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
          'DefaultFirebaseOptions belum dikonfigurasi untuk Linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions tidak mendukung platform ini.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDNG_cqV-T25IUA64_3ME9xur1vvSlGr3g',
    authDomain: 'adatamu-bd8c1.firebaseapp.com',
    projectId: 'adatamu-bd8c1',
    storageBucket: 'adatamu-bd8c1.firebasestorage.app',
    messagingSenderId: '151667984588',
    appId: '1:151667984588:web:4f368a5bed1fb8a3149a69',
  );

  // Sementara pakai config web yang sama. Ganti appId di bawah dengan
  // appId Android asli (lihat Project settings -> Android app) kalau
  // mau jalankan di emulator/HP Android.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDNG_cqV-T25IUA64_3ME9xur1vvSlGr3g',
    appId: '1:151667984588:android:5c18c0b6eafd1055149a69',
    messagingSenderId: '151667984588',
    projectId: 'adatamu-bd8c1',
    storageBucket: 'adatamu-bd8c1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDNG_cqV-T25IUA64_3ME9xur1vvSlGr3g',
    appId: '1:151667984588:web:4f368a5bed1fb8a3149a69',
    messagingSenderId: '151667984588',
    projectId: 'adatamu-bd8c1',
    storageBucket: 'adatamu-bd8c1.firebasestorage.app',
    iosBundleId: 'com.example.adatamu',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDNG_cqV-T25IUA64_3ME9xur1vvSlGr3g',
    appId: '1:151667984588:web:4f368a5bed1fb8a3149a69',
    messagingSenderId: '151667984588',
    projectId: 'adatamu-bd8c1',
    storageBucket: 'adatamu-bd8c1.firebasestorage.app',
    iosBundleId: 'com.example.adatamu',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDNG_cqV-T25IUA64_3ME9xur1vvSlGr3g',
    authDomain: 'adatamu-bd8c1.firebaseapp.com',
    projectId: 'adatamu-bd8c1',
    storageBucket: 'adatamu-bd8c1.firebasestorage.app',
    messagingSenderId: '151667984588',
    appId: '1:151667984588:web:4f368a5bed1fb8a3149a69',
  );
}
