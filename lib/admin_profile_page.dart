import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'main.dart';
import 'services/admin_service.dart';
import 'services/auth_service.dart';

/// Halaman "Profil Admin" — ditampilkan di bawah menu "Data Pelanggan"
/// di sidebar. Di sini admin bisa:
///   - Ganti foto profil
///   - Ganti username
///   - Ganti email
///   - Ganti password
///
/// SEMUA perubahan data sensitif (username/email/password) wajib minta
/// password saat ini dulu (reauthentication) lewat dialog konfirmasi —
/// lihat `_promptCurrentPassword`.
class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    // Untuk akun lama yang didaftarkan sebelum fitur ini ada, dokumen
    // profilnya belum pernah dibuat — backfill dulu supaya halaman ini
    // tidak menampilkan "Profil admin tidak ditemukan.".
    AdminService.instance.ensureProfileExists();
    // Kalau admin sebelumnya ganti email dan sudah klik link konfirmasi,
    // ini akan menyinkronkan mapping login secara otomatis begitu
    // halaman profil dibuka.
    AuthService.instance.syncEmailIfChanged();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (file == null) return;

      setState(() => _uploadingPhoto = true);
      final Uint8List bytes = await file.readAsBytes();
      await AdminService.instance.uploadProfilePhoto(bytes);
      _showSnack('Foto profil berhasil diperbarui.');
    } on AdminServiceException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('Gagal mengunggah foto, coba lagi.', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  /// Dialog kecil untuk minta password saat ini sebelum melakukan
  /// operasi sensitif. Mengembalikan password yang diketik user, atau
  /// null kalau dibatalkan.
  Future<String?> _promptCurrentPassword({required String title}) {
    final controller = TextEditingController();
    bool obscure = true;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            obscureText: obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Password saat ini',
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setDialogState(() => obscure = !obscure),
              ),
            ),
            onSubmitted: (_) => Navigator.of(context).pop(controller.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Konfirmasi'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleEditUsername(String currentUsername) async {
    final controller = TextEditingController(text: currentUsername);
    final newUsername = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ganti Username'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Username baru'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
    if (newUsername == null || newUsername.isEmpty) return;
    if (newUsername == currentUsername) return;

    final password = await _promptCurrentPassword(
      title: 'Konfirmasi ganti username',
    );
    if (password == null || password.isEmpty) return;

    try {
      await AuthService.instance.updateUsername(
        newUsername: newUsername,
        currentPassword: password,
      );
      _showSnack('Username berhasil diganti menjadi "$newUsername".');
    } on AuthServiceException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('Gagal mengganti username, coba lagi.', isError: true);
    }
  }

  Future<void> _handleEditEmail(String currentEmail) async {
    final controller = TextEditingController(text: currentEmail);
    final newEmail = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ganti Email'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email baru'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
    if (newEmail == null || newEmail.isEmpty) return;
    if (newEmail == currentEmail) return;

    final password = await _promptCurrentPassword(
      title: 'Konfirmasi ganti email',
    );
    if (password == null || password.isEmpty) return;

    try {
      await AuthService.instance.updateEmail(
        newEmail: newEmail,
        currentPassword: password,
      );
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cek Email Baru'),
          content: Text(
            'Link konfirmasi sudah dikirim ke $newEmail. Buka email tersebut '
            'dan klik link-nya untuk menyelesaikan penggantian email. '
            'Login tetap memakai username & password yang sama seperti '
            'biasa; sistem akan menyinkronkan otomatis setelah link '
            'dikonfirmasi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
    } on AuthServiceException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('Gagal mengganti email, coba lagi.', isError: true);
    }
  }

  Future<void> _handleChangePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ganti Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Password saat ini',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureCurrent
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () => setDialogState(
                      () => obscureCurrent = !obscureCurrent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'Password baru (min. 6 karakter)',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureNew ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setDialogState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Ulangi password baru',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () => setDialogState(
                      () => obscureConfirm = !obscureConfirm,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (newController.text.length < 6) {
                  _showSnack('Password baru minimal 6 karakter.', isError: true);
                  return;
                }
                if (newController.text != confirmController.text) {
                  _showSnack('Konfirmasi password tidak cocok.', isError: true);
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    try {
      await AdminService.instance.updatePassword(
        currentPassword: currentController.text,
        newPassword: newController.text,
      );
      _showSnack('Password berhasil diganti.');
    } on AdminServiceException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('Gagal mengganti password, coba lagi.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminProfile?>(
      stream: AdminService.instance.streamCurrentProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final profile = snapshot.data;
        if (profile == null) {
          // Sesaat sebelum `ensureProfileExists()` selesai membuat
          // dokumen profil (khusus akun lama), stream ini bisa sempat
          // mengembalikan null. Tampilkan loading, bukan pesan error,
          // karena StreamBuilder otomatis rebuild begitu dokumennya jadi.
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: const Color(0xFFD9D9D9),
                            backgroundImage: profile.fotoProfilUrl != null
                                ? NetworkImage(profile.fotoProfilUrl!)
                                : null,
                            child: profile.fotoProfilUrl == null
                                ? const Icon(
                                    Icons.person,
                                    size: 52,
                                    color: Colors.white70,
                                  )
                                : null,
                          ),
                          Material(
                            color: AppColors.teal,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _uploadingPhoto
                                  ? null
                                  : _pickAndUploadPhoto,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: _uploadingPhoto
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile.username,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                      Text(
                        profile.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _ProfileInfoTile(
                  icon: Icons.person_outline,
                  label: 'Username',
                  value: profile.username,
                  onEdit: () => _handleEditUsername(profile.username),
                ),
                const SizedBox(height: 12),
                _ProfileInfoTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: profile.email,
                  onEdit: () => _handleEditEmail(profile.email),
                ),
                const SizedBox(height: 12),
                _ProfileInfoTile(
                  icon: Icons.lock_outline,
                  label: 'Password',
                  value: '••••••••',
                  editLabel: 'Ganti',
                  onEdit: _handleChangePassword,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String editLabel;
  final VoidCallback onEdit;

  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
    this.editLabel = 'Edit',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.teal),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            child: Text(editLabel),
          ),
        ],
      ),
    );
  }
}