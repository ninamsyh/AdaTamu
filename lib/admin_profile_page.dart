import 'package:flutter/material.dart';

import 'main.dart';
import 'services/admin_service.dart';
import 'services/auth_service.dart';

/// Halaman "Profil Admin" — ditampilkan di bawah menu "Data Pelanggan"
/// di sidebar. Di sini admin bisa:
///   - Ganti username
///   - Ganti email
///   - Ganti password
///
/// Tampilan dibuat ringkas/kompak (mirip layar HP), tanpa foto profil,
/// hanya berisi form edit data admin.
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
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _saving = false;
  String? _loadedUsername;
  String? _loadedEmail;

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

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    showAppSnackBar(context, message, isError: isError);
  }

  /// Sinkronkan controller dengan data terbaru dari stream, tapi hanya
  /// sekali saat pertama kali data datang (atau setelah berhasil simpan)
  /// supaya tidak menimpa apa yang sedang diketik admin.
  void _syncControllersIfNeeded(AdminProfile profile) {
    if (_loadedUsername == null) {
      _usernameController.text = profile.username;
      _loadedUsername = profile.username;
    }
    if (_loadedEmail == null) {
      _emailController.text = profile.email;
      _loadedEmail = profile.email;
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

  /// Tombol "Simpan" utama di halaman: menyimpan perubahan username
  /// dan/atau email sekaligus (kalau ada yang diubah dari nilai semula).
  /// Password tetap punya alur terpisah lewat `_handleChangePassword`
  /// karena butuh 3 input (password lama, baru, ulangi baru).
  Future<void> _handleSave() async {
    final newUsername = _usernameController.text.trim();
    final newEmail = _emailController.text.trim();

    if (newUsername.isEmpty) {
      _showSnack('Username tidak boleh kosong.', isError: true);
      return;
    }
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      _showSnack('Format email tidak valid.', isError: true);
      return;
    }

    final usernameChanged = newUsername != _loadedUsername;
    final emailChanged = newEmail != _loadedEmail;

    if (!usernameChanged && !emailChanged) {
      _showSnack('Tidak ada perubahan untuk disimpan.');
      return;
    }

    final password = await _promptCurrentPassword(
      title: 'Konfirmasi simpan perubahan',
    );
    if (password == null || password.isEmpty) return;

    setState(() => _saving = true);
    try {
      if (usernameChanged) {
        await AuthService.instance.updateUsername(
          newUsername: newUsername,
          currentPassword: password,
        );
        _loadedUsername = newUsername;
      }
      if (emailChanged) {
        await AuthService.instance.updateEmail(
          newEmail: newEmail,
          currentPassword: password,
        );
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cek Email Baru'),
              content: Text(
                'Link konfirmasi sudah dikirim ke $newEmail. Buka email '
                'tersebut dan klik link-nya untuk menyelesaikan penggantian '
                'email. Login tetap memakai username & password yang sama '
                'seperti biasa; sistem akan menyinkronkan otomatis setelah '
                'link dikonfirmasi.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Mengerti'),
                ),
              ],
            ),
          );
        }
      } else {
        _showSnack('Perubahan berhasil disimpan.');
      }
    } on AuthServiceException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('Gagal menyimpan perubahan, coba lagi.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
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
                      obscureCurrent ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setDialogState(() => obscureCurrent = !obscureCurrent),
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
                      obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setDialogState(() => obscureConfirm = !obscureConfirm),
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
                  _showSnack(
                    'Password baru minimal 6 karakter.',
                    isError: true,
                  );
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

        _syncControllersIfNeeded(profile);

        // Responsive: di layar sempit (HP) tampilan tetap ringkas &
        // sempit seperti semula. Di layar lebar (tablet/laptop/web)
        // kartu ikut melebar secara proporsional (dengan batas atas
        // supaya tidak jadi kepanjangan/kosong), padding & font sedikit
        // membesar, dan field Username+Email disusun berdampingan
        // supaya ruang layar besar tidak terasa kosong.
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // Sama seperti breakpoint yang dipakai di halaman lain
            // (mis. kartu statistik di Beranda) supaya konsisten.
            final isWide = width >= 600;

            final cardMaxWidth = isWide ? 640.0 : 340.0;
            final cardPadding = isWide ? 24.0 : 16.0;
            final titleSize = isWide ? 20.0 : 16.0;
            final labelSize = isWide ? 12.0 : 11.0;
            final fieldFontSize = isWide ? 14.0 : 13.0;
            final fieldVerticalPadding = isWide ? 14.0 : 10.0;
            final iconSize = isWide ? 20.0 : 18.0;
            final fieldSpacing = isWide ? 20.0 : 12.0;

            Widget fieldLabel(String text) => Text(
              text,
              style: TextStyle(fontSize: labelSize, color: Colors.black54),
            );

            InputDecoration fieldDecoration(IconData icon) => InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: fieldVerticalPadding,
              ),
              prefixIcon: Icon(icon, size: iconSize),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            );

            final usernameField = SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  fieldLabel('Username'),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _usernameController,
                    style: TextStyle(fontSize: fieldFontSize),
                    decoration: fieldDecoration(Icons.person_outline),
                  ),
                ],
              ),
            );

            final emailField = SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  fieldLabel('Email'),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(fontSize: fieldFontSize),
                    decoration: fieldDecoration(Icons.email_outlined),
                  ),
                ],
              ),
            );

            // Di layar lebar, Username & Email berdampingan (hemat
            // ruang vertikal & memanfaatkan lebar layar). Di layar
            // sempit, tetap ditumpuk seperti semula.
            final usernameEmailRow = isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: usernameField),
                      const SizedBox(width: 16),
                      Expanded(child: emailField),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      usernameField,
                      SizedBox(height: fieldSpacing),
                      emailField,
                    ],
                  );

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 24 : 16,
                vertical: 20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: cardMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Profil Admin',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: EdgeInsets.all(cardPadding),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            usernameEmailRow,
                            SizedBox(height: fieldSpacing),
                            fieldLabel('Password'),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  size: iconSize,
                                  color: Colors.black45,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '••••••••',
                                    style: TextStyle(
                                      fontSize: fieldFontSize,
                                      color: AppColors.darkText,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _handleChangePassword,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Ganti',
                                    style: TextStyle(
                                      fontSize: isWide ? 13 : 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Di layar lebar tombol Simpan tidak perlu
                            // melebar penuh (kelihatan aneh untuk sebuah
                            // form pendek) — dibatasi & rata kanan. Di
                            // layar sempit tetap melebar penuh seperti
                            // semula.
                            Align(
                              alignment: isWide
                                  ? Alignment.centerRight
                                  : Alignment.center,
                              child: SizedBox(
                                width: isWide ? 180 : double.infinity,
                                height: isWide ? 46 : 40,
                                child: ElevatedButton(
                                  onPressed: _saving ? null : _handleSave,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.teal,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: _saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'Simpan',
                                          style: TextStyle(
                                            fontSize: isWide ? 14 : 13,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
