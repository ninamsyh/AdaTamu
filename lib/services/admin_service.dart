import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Model data profil admin, dipetakan dari dokumen di collection `admins`.
class AdminProfile {
  final String uid;
  final String username;
  final String email;
  final String? fotoProfilUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminProfile({
    required this.uid,
    required this.username,
    required this.email,
    this.fotoProfilUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AdminProfile(
      uid: doc.id,
      username: (data['username'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      fotoProfilUrl: data['fotoProfilUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Service khusus untuk mengelola profil admin di Firestore + Storage.
///
/// PENTING: collection ini (`admins`) SENGAJA dipisah total dari
/// collection `guests` (data tamu) supaya tidak tercampur. Password
/// TIDAK pernah disimpan di sini — itu murni tanggung jawab Firebase
/// Authentication (lihat `AuthService`). Collection ini hanya menyimpan
/// data profil: username, email, dan foto profil.
class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String collectionName = 'admins';

  CollectionReference<Map<String, dynamic>> get _admins =>
      _firestore.collection(collectionName);

  /// Dipanggil sekali setelah registrasi akun admin berhasil (setelah
  /// `AuthService.register`). Membuat dokumen profil awal di `admins/{uid}`.
  /// Menggunakan `set(..., SetOptions(merge: true))` supaya aman dipanggil
  /// ulang tanpa menimpa field yang sudah ada.
  Future<void> createInitialProfile({
    required String uid,
    required String username,
    required String email,
    String? fotoProfilUrl,
  }) async {
    await _admins.doc(uid).set({
      'username': username.trim(),
      'email': email.trim(),
      'fotoProfilUrl': fotoProfilUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Ambil profil admin yang sedang login sekali saja.
  Future<AdminProfile?> getCurrentProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _admins.doc(uid).get();
    if (!doc.exists) return null;
    return AdminProfile.fromDoc(doc);
  }

  /// Backfill dokumen `admins/{uid}` untuk akun yang didaftarkan SEBELUM
  /// fitur Profil Admin ini ada (dulu `createInitialProfile` hanya
  /// dipanggil saat proses register baru, jadi akun lama belum punya
  /// dokumen profil sama sekali). Dipanggil otomatis saat halaman Profil
  /// Admin dibuka — kalau dokumennya sudah ada, fungsi ini tidak
  /// melakukan apa-apa.
  Future<void> ensureProfileExists() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _admins.doc(user.uid).get();
    if (doc.exists) return; // sudah ada, tidak perlu backfill

    // Cari username dari collection `usernames` (yang jadi index login),
    // karena field ini tidak tersimpan di objek User bawaan Firebase Auth.
    String username;
    try {
      final query = await _firestore
          .collection('usernames')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();
      username = query.docs.isNotEmpty
          ? query.docs.first.id
          : (user.email?.split('@').first ?? 'admin');
    } catch (_) {
      username = user.email?.split('@').first ?? 'admin';
    }

    await createInitialProfile(
      uid: user.uid,
      username: username,
      email: user.email ?? '',
    );
  }

  /// Stream realtime profil admin yang sedang login — cocok dipakai
  /// dengan StreamBuilder di halaman profil/dashboard.
  Stream<AdminProfile?> streamCurrentProfile() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _admins
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? AdminProfile.fromDoc(doc) : null);
  }

  /// Update username dan/atau foto profil admin yang sedang login.
  /// Tidak menyentuh password / email di sini — untuk itu pakai method
  /// khusus di bawah (dan `AuthService.updateEmail`) supaya lewat
  /// Firebase Auth, bukan Firestore.
  Future<void> updateProfile({String? username, String? fotoProfilUrl}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw AdminServiceException('Admin belum login.');
    }
    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (username != null) data['username'] = username.trim();
    if (fotoProfilUrl != null) data['fotoProfilUrl'] = fotoProfilUrl;

    await _admins.doc(uid).set(data, SetOptions(merge: true));
  }

  /// Upload foto profil baru ke Firebase Storage
  /// (`admin_profile_photos/{uid}/profile.jpg`) lalu simpan URL hasilnya
  /// ke dokumen profil admin. File lama otomatis TERTIMPA (nama file
  /// selalu sama) supaya storage tidak menumpuk foto lama yang sudah
  /// tidak dipakai.
  Future<String> uploadProfilePhoto(
    Uint8List bytes, {
    String contentType = 'image/jpeg',
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw AdminServiceException('Admin belum login.');
    }
    if (bytes.isEmpty) {
      throw AdminServiceException('File foto tidak valid.');
    }

    final ref = _storage
        .ref()
        .child('admin_profile_photos')
        .child(uid)
        .child('profile.jpg');

    try {
      await ref.putData(bytes, SettableMetadata(contentType: contentType));
      final url = await ref.getDownloadURL();
      await updateProfile(fotoProfilUrl: url);
      return url;
    } on FirebaseException catch (e) {
      throw AdminServiceException(e.message ?? 'Gagal mengunggah foto profil.');
    }
  }

  /// Ganti password admin yang sedang login. `currentPassword` wajib
  /// diisi supaya sistem reauthenticate dulu sebelum ganti password —
  /// ini mencegah error `requires-recent-login` DAN jadi lapisan
  /// keamanan tambahan (orang lain yang kebetulan memegang sesi admin
  /// yang masih login tidak bisa asal ganti password tanpa tahu
  /// password lama).
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw AdminServiceException('Admin belum login.');
    }
    if (newPassword.length < 6) {
      throw AdminServiceException('Password baru minimal 6 karakter.');
    }

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw AdminServiceException('Password saat ini salah.');
      }
      if (e.code == 'requires-recent-login') {
        throw AdminServiceException(
          'Sesi login terlalu lama, silakan login ulang dulu sebelum ganti password.',
        );
      }
      if (e.code == 'weak-password') {
        throw AdminServiceException('Password baru terlalu lemah.');
      }
      throw AdminServiceException(e.message ?? 'Gagal mengganti password.');
    }
  }
}

class AdminServiceException implements Exception {
  final String message;
  AdminServiceException(this.message);

  @override
  String toString() => message;
}
