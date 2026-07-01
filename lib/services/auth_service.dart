import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_service.dart';

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

    DocumentSnapshot<Map<String, dynamic>> existing;
    try {
      existing = await _firestore
          .collection(_usernameCollection)
          .doc(usernameKey)
          .get();
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG Firestore read (cek username) error: $e');
      throw AuthServiceException('Gagal memeriksa username, coba lagi.');
    }
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
      // ignore: avoid_print
      print('DEBUG createUserWithEmailAndPassword error: ${e.code} - ${e.message}');
      throw AuthServiceException(_mapErrorMessage(e));
    }

    try {
      await _firestore.collection(_usernameCollection).doc(usernameKey).set({
        'uid': credential.user!.uid,
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Buat juga dokumen profil admin di collection terpisah `admins`.
      // Sengaja dipisah dari `usernames` (yang cuma index login) dan
      // TIDAK PERNAH menyentuh collection `guests`.
      await AdminService.instance.createInitialProfile(
        uid: credential.user!.uid,
        username: usernameKey,
        email: email.trim(),
      );
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG Firestore write error: $e');
      // Kalau gagal nulis mapping username, hapus akun auth yang baru
      // dibuat supaya tidak ada akun "nyangkut" tanpa username.
      await credential.user?.delete();
      throw AuthServiceException('Gagal menyimpan username, coba lagi.');
    }

    return credential;
  }

  Future<void> logout() => _auth.signOut();

  // ===================== PROFIL ADMIN: KEAMANAN =====================
  //
  // Semua operasi sensitif (ganti username, email, password) WAJIB
  // reauthenticate dulu (minta password saat ini). Firebase Auth sendiri
  // menolak operasi ini kalau sesi login sudah "terlalu lama" (error
  // `requires-recent-login`) — reauthenticate di sini memastikan itu
  // tidak pernah terjadi, sekaligus jadi lapisan keamanan tambahan biar
  // orang lain yang kebetulan memegang sesi admin yang masih login tidak
  // bisa asal ganti kredensial tanpa tahu password aslinya.
  Future<void> reauthenticate(String currentPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw AuthServiceException('Sesi tidak valid, silakan login ulang.');
    }
    if (currentPassword.isEmpty) {
      throw AuthServiceException('Password saat ini wajib diisi.');
    }
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    try {
      await user.reauthenticateWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw AuthServiceException('Password saat ini salah.');
      }
      throw AuthServiceException(_mapErrorMessage(e));
    }
  }

  /// Cari dokumen `usernames/{...}` milik uid tertentu (untuk keperluan
  /// ganti username/email, di mana kita perlu tahu username LAMA-nya
  /// dulu sebelum bisa mengganti dokumennya).
  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findUsernameDocByUid(
    String uid,
  ) async {
    final query = await _firestore
        .collection(_usernameCollection)
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first;
  }

  /// Ganti username admin yang sedang login. Password saat ini wajib
  /// diisi (reauthentication) supaya aman.
  Future<void> updateUsername({
    required String newUsername,
    required String currentPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthServiceException('Admin belum login.');
    }
    final newKey = _normalize(newUsername);
    if (newKey.isEmpty) {
      throw AuthServiceException('Username wajib diisi.');
    }

    await reauthenticate(currentPassword);

    final oldDoc = await _findUsernameDocByUid(user.uid);
    if (oldDoc == null) {
      throw AuthServiceException('Data username lama tidak ditemukan.');
    }
    final oldKey = oldDoc.id;
    if (oldKey == newKey) {
      // Tidak ada perubahan, tidak perlu apa-apa.
      return;
    }

    final newDocRef = _firestore.collection(_usernameCollection).doc(newKey);
    final email = oldDoc.data()['email'] as String? ?? user.email ?? '';

    // Pakai transaction supaya "pindah" dari dokumen lama ke dokumen baru
    // ini atomik: tidak mungkin berhenti di tengah jalan dan meninggalkan
    // dua dokumen username yang menunjuk ke akun yang sama.
    await _firestore.runTransaction((tx) async {
      final newSnap = await tx.get(newDocRef);
      if (newSnap.exists) {
        throw AuthServiceException('Username sudah digunakan, pilih yang lain.');
      }
      tx.set(newDocRef, {
        'uid': user.uid,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.delete(oldDoc.reference);
    });

    await AdminService.instance.updateProfile(username: newKey);
  }

  /// Ganti email admin yang sedang login. Password saat ini wajib diisi
  /// (reauthentication).
  ///
  /// CATATAN PENTING: Firebase Auth versi terbaru mewajibkan verifikasi
  /// untuk ganti email (`verifyBeforeUpdateEmail`) — artinya email akun
  /// TIDAK langsung berubah begitu fungsi ini selesai. Firebase akan
  /// mengirim link konfirmasi ke email BARU, dan email akun baru benar-benar
  /// berubah setelah admin mengklik link tersebut. Karena itu, mapping
  /// `usernames`/`admins` di Firestore SENGAJA belum diubah di sini — baru
  /// disinkronkan otomatis lewat [syncEmailIfChanged] setelah link
  /// dikonfirmasi, supaya login (yang bergantung pada mapping username ->
  /// email) tidak pernah rusak di tengah proses.
  Future<void> updateEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthServiceException('Admin belum login.');
    }
    final email = newEmail.trim();
    if (email.isEmpty || !email.contains('@')) {
      throw AuthServiceException('Format email tidak valid.');
    }

    await reauthenticate(currentPassword);

    try {
      await user.verifyBeforeUpdateEmail(email);
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_mapErrorMessage(e));
    }
  }

  /// Panggil ini saat admin membuka halaman Profil (atau dashboard).
  /// Kalau admin sebelumnya sempat ganti email dan SUDAH mengklik link
  /// konfirmasi (sehingga email asli di Firebase Auth sudah berubah),
  /// fungsi ini akan mendeteksi perbedaan itu dan otomatis menyinkronkan
  /// mapping `usernames`/`admins` di Firestore supaya login berikutnya
  /// tetap jalan normal dengan email yang baru.
  Future<void> syncEmailIfChanged() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    try {
      await user.reload();
    } catch (_) {
      return; // Kalau gagal reload (mis. offline), coba lagi lain kali.
    }
    final refreshedUser = _auth.currentUser;
    final currentEmail = refreshedUser?.email;
    if (refreshedUser == null || currentEmail == null) return;

    final usernameDoc = await _findUsernameDocByUid(refreshedUser.uid);
    if (usernameDoc == null) return;

    final storedEmail = usernameDoc.data()['email'] as String?;
    if (storedEmail == currentEmail) return; // sudah sinkron

    await usernameDoc.reference.update({'email': currentEmail});
    // `updateProfile` di AdminService cuma menangani field username/foto,
    // jadi field email di sini langsung ditulis ke collection `admins`.
    await _firestore.collection('admins').doc(refreshedUser.uid).set({
      'email': currentEmail,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

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
      case 'requires-recent-login':
        return 'Sesi login terlalu lama, silakan login ulang dulu.';
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