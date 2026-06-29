import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service yang membungkus semua interaksi dengan Firebase Authentication
/// dan Firestore untuk login menggunakan USERNAME (bukan email).
///
/// Firebase Auth secara native hanya bisa login pakai email, jadi kita
/// simpan mapping "username -> email" di koleksi Firestore bernama
/// `usernames`. Alurnya:
///   1. Saat daftar: buat akun Firebase Auth (email asli) + simpan
///      dokumen di koleksi `usernames` dengan id = username.
///   2. Saat login: cari dokumen `usernames/{username}` untuk dapat
///      emailnya, baru email itu dipakai untuk signIn ke Firebase Auth.
///
/// Sesi login otomatis tersimpan oleh Firebase Auth di perangkat, jadi
/// begitu user pernah login sekali, dia tidak perlu login ulang setiap
/// kali membuka aplikasi (lihat [authStateChanges] yang dipakai di
/// `main.dart`).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _usernameCollection = 'usernames';

  /// Stream status login. Akan langsung mengembalikan user yang masih
  /// login walau aplikasi baru dibuka lagi.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  String _normalize(String username) => username.trim().toLowerCase();

  /// Login menggunakan username + password.
  Future<UserCredential> login({
    required String username,
    required String password,
  }) async {
    final usernameKey = _normalize(username);
    if (usernameKey.isEmpty || password.isEmpty) {
      throw AuthServiceException('Username dan password wajib diisi.');
    }

    final doc = await _firestore
        .collection(_usernameCollection)
        .doc(usernameKey)
        .get();

    if (!doc.exists) {
      throw AuthServiceException('Username tidak ditemukan.');
    }

    final email = doc.data()?['email'] as String?;
    if (email == null) {
      throw AuthServiceException('Data akun tidak valid, hubungi admin.');
    }

    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_mapErrorMessage(e));
    }
  }

  /// Daftar akun baru dengan username + email + password.
  /// Email tetap dibutuhkan karena Firebase Auth mewajibkannya, tapi
  /// user akan login pakai username, bukan email.
  Future<UserCredential> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final usernameKey = _normalize(username);
    if (usernameKey.isEmpty || email.trim().isEmpty || password.isEmpty) {
      throw AuthServiceException('Semua field wajib diisi.');
    }

    final existing = await _firestore
        .collection(_usernameCollection)
        .doc(usernameKey)
        .get();
    if (existing.exists) {
      throw AuthServiceException('Username sudah digunakan, pilih yang lain.');
    }

    UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_mapErrorMessage(e));
    }

    try {
      await _firestore.collection(_usernameCollection).doc(usernameKey).set({
        'uid': credential.user!.uid,
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Kalau gagal nulis mapping username, hapus akun auth yang baru
      // dibuat supaya tidak ada akun "nyangkut" tanpa username.
      await credential.user?.delete();
      throw AuthServiceException('Gagal menyimpan username, coba lagi.');
    }

    return credential;
  }

  Future<void> logout() => _auth.signOut();

  String _mapErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Password salah.';
      case 'user-not-found':
        return 'Akun tidak ditemukan.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar.';
      case 'weak-password':
        return 'Password terlalu lemah, minimal 6 karakter.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan, coba lagi nanti.';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet.';
      default:
        return e.message ?? 'Terjadi kesalahan, coba lagi.';
    }
  }
}

/// Exception khusus dengan pesan yang sudah ramah untuk ditampilkan ke user.
class AuthServiceException implements Exception {
  final String message;
  AuthServiceException(this.message);

  @override
  String toString() => message;
}
