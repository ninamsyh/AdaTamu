import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'dashboard_page.dart';
import 'firebase_options.dart';
import 'register_page.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdaTamuApp());
}

class AdaTamuApp extends StatelessWidget {
  const AdaTamuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AdaTamu Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Georgia', useMaterial3: true),
      home: const AuthGate(),
    );
  }
}

/// Palet warna sesuai desain
class AppColors {
  static const teal = Color(0xFF13A2B4); // panel kanan / aksen
  static const navy = Color(0xFF0B4C56); // panel kiri (gelap)
  static const yellow = Color(0xFFF6E84B); // tombol login
  static const darkText = Color(0xFF0B2B30);
}

/// Notifikasi kecil yang melayang (bukan bar penuh lebar layar) supaya
/// tampilannya lebih rapi dan konsisten dengan palet warna aplikasi.
/// Dipakai bersama di halaman Login & Daftar.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = true,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.darkText,
      elevation: 6,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: (isError ? const Color(0xFFFF6B6B) : AppColors.yellow)
              .withOpacity(0.4),
        ),
      ),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? const Color(0xFFFF6B6B) : AppColors.yellow,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Gerbang autentikasi: dengar status login Firebase Auth lewat
/// [authStateChanges]. Firebase Auth menyimpan sesi login di perangkat,
/// jadi kalau user sudah pernah login sebelumnya, dia akan langsung
/// diarahkan ke Dashboard tanpa perlu mengisi form login lagi.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.navy,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const DashboardPage();
        }
        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  // FocusNode khusus password: dipakai untuk memaksa field ini ke-reset
  // dan bisa diketik lagi setelah login gagal (lihat catatan di
  // _handleLogin). Beberapa browser (terutama Chrome, setelah login
  // gagal 2x) suka "mengunci" fokus di field password karena warning
  // bawaan browser (mis. "password ini pernah bocor") — refocus manual
  // ini yang memastikan field tetap bisa diedit user.
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text;
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.login(
        identifier: username,
        password: password,
      );
      // Tidak perlu Navigator di sini: AuthGate otomatis menampilkan
      // DashboardPage begitu authStateChanges mendeteksi user login.
    } on AuthServiceException catch (e) {
      _showError(e.message);
      _resetPasswordFieldForRetry();
    } catch (e) {
      _showError('Gagal login, coba lagi.');
      _resetPasswordFieldForRetry();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Kosongkan password & paksa fokus balik ke field-nya supaya user
  /// selalu bisa langsung ngetik ulang begitu login gagal — tanpa ini,
  /// di beberapa browser field-nya kadang jadi tidak responsif setelah
  /// gagal 2x berturut-turut.
  void _resetPasswordFieldForRetry() {
    if (!mounted) return;
    _passwordController.clear();
    // Beri jeda 1 frame supaya build selesai dulu sebelum minta fokus,
    // biar tidak bentrok dengan SnackBar yang baru muncul.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_passwordFocusNode);
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    showAppSnackBar(context, message, isError: true);
  }

  void _goToRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegisterPage()));
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetController = TextEditingController();
    bool isSending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              final email = resetController.text.trim();
              if (email.isEmpty) return;
              setDialogState(() => isSending = true);
              try {
                await AuthService.instance.sendPasswordReset(email);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                _showInfo(
                  'Link reset password sudah dikirim ke email kamu. '
                  'Buka email tersebut untuk membuat password baru.',
                );
              } on AuthServiceException catch (e) {
                setDialogState(() => isSending = false);
                _showError(e.message);
              } catch (e) {
                setDialogState(() => isSending = false);
                _showError('Gagal mengirim reset password, coba lagi.');
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.navy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Lupa Password',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Masukkan email akun kamu. Kami akan mengirim link '
                    'untuk membuat password baru.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  _LoginTextField(
                    controller: resetController,
                    hintText: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      size: 18,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSending ? null : submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.yellow,
                    foregroundColor: AppColors.darkText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.darkText,
                          ),
                        )
                      : const Text(
                          'Kirim',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    showAppSnackBar(context, message, isError: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.teal, AppColors.navy],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLoginCard(),
                    const SizedBox(height: 24),

                    // Link ke halaman Daftar
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          const Text(
                            'Belum punya akun? ',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          GestureDetector(
                            onTap: _isLoading ? null : _goToRegister,
                            child: const Text(
                              'Daftar',
                              style: TextStyle(
                                color: AppColors.yellow,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
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
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo AdaTamu di atas kartu, menggantikan foto profil/judul teks
            Center(
              child: SizedBox(
                height: 150,
                child: Image.asset(
                  'lib/assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 28),

            const _FieldLabel('Username atau Email'),
            const SizedBox(height: 6),
            _LoginTextField(
              controller: _usernameController,
              hintText: '',
              prefixIcon: const Icon(
                Icons.person_outline,
                size: 20,
                color: AppColors.navy,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Username atau email wajib diisi'
                  : null,
            ),
            const SizedBox(height: 18),

            const _FieldLabel('Password'),
            const SizedBox(height: 6),
            _LoginTextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: _obscurePassword,
              disableBrowserAutofill: true,
              prefixIcon: const Icon(
                Icons.lock_outline,
                size: 20,
                color: AppColors.navy,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                  color: Colors.grey,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
            ),
            const SizedBox(height: 6),

            // Lupa password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _showForgotPasswordDialog,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Lupa Password?',
                  style: TextStyle(color: AppColors.yellow, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tombol Login
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.darkText,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.darkText,
                        ),
                      )
                    : const Text(
                        'Masuk',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label kecil di atas setiap field
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Text field putih bulat sesuai desain. Dipakai di dalam Form, jadi
/// mendukung validator (border + teks error berwarna merah), sama
/// seperti field di halaman Daftar.
class _LoginTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool obscureText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  // Kalau true, matikan autocorrect/suggestion & autofill hints supaya
  // browser (terutama Chrome) tidak "ikut campur" (mis. munculin warning
  // password bocor) yang bisa bikin field jadi susah diketik ulang.
  final bool disableBrowserAutofill;

  const _LoginTextField({
    required this.controller,
    this.focusNode,
    this.obscureText = false,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
    this.disableBrowserAutofill = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      autocorrect: !disableBrowserAutofill,
      enableSuggestions: !disableBrowserAutofill,
      autofillHints: disableBrowserAutofill ? null : const [],
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Colors.red, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Colors.red, width: 1.4),
        ),
        errorStyle: const TextStyle(color: Colors.red, fontSize: 11),
      ),
    );
  }
}
