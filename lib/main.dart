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
      title: 'AdaTamu Login',
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
            backgroundColor: Color(0xFFF2F2F2),
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
    final username = _usernameController.text;
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.login(username: username, password: password);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _goToRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegisterPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Breakpoint: di bawah 700px lebar -> layout vertikal (mobile/portrait)
            // di atas 700px -> layout horizontal seperti desain (tablet/desktop/landscape)
            final isWide = constraints.maxWidth >= 700;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  // Membatasi lebar maksimum kartu agar tidak melebar berlebihan
                  // di layar besar (desktop/tablet), tapi tetap fleksibel di layar kecil.
                  constraints: const BoxConstraints(
                    maxWidth: 900,
                    minHeight: 0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isWide
                        ? IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _WelcomePanel(isWide: isWide),
                                ),
                                Expanded(flex: 4, child: _buildLoginForm()),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _WelcomePanel(isWide: isWide),
                              _buildLoginForm(),
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    // Dibungkus SingleChildScrollView supaya kalau tinggi konten sedikit
    // melebihi tinggi panel kiri (mis. card avatar lebih tinggi dari
    // "Selamat Datang" + logo), form ini scroll alih-alih overflow.
    return Container(
      color: AppColors.teal,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar bulat
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: Color(0xFFD9D9D9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  size: 56,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(height: 28),

            const _FieldLabel('Username'),
            const SizedBox(height: 6),
            _LoginTextField(controller: _usernameController, hintText: ''),
            const SizedBox(height: 18),

            const _FieldLabel('Password'),
            const SizedBox(height: 6),
            _LoginTextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: _obscurePassword,
              disableBrowserAutofill: true,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                  color: Colors.grey,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 26),

            // Tombol Login
            Center(
              child: SizedBox(
                width: 120,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.yellow,
                    foregroundColor: AppColors.darkText,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
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
                          'Login',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Link ke halaman Daftar
            Center(
              child: TextButton(
                onPressed: _isLoading ? null : _goToRegister,
                child: const Text(
                  'Belum punya akun? Daftar',
                  style: TextStyle(color: Colors.white, fontSize: 12),
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

/// Text field putih bulat sesuai desain
class _LoginTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool obscureText;
  final String? hintText;
  final Widget? suffixIcon;
  // Kalau true, matikan autocorrect/suggestion & autofill hints supaya
  // browser (terutama Chrome) tidak "ikut campur" (mis. munculin warning
  // password bocor) yang bisa bikin field jadi susah diketik ulang.
  final bool disableBrowserAutofill;

  const _LoginTextField({
    required this.controller,
    this.focusNode,
    this.obscureText = false,
    this.hintText,
    this.suffixIcon,
    this.disableBrowserAutofill = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      autocorrect: !disableBrowserAutofill,
      enableSuggestions: !disableBrowserAutofill,
      autofillHints: disableBrowserAutofill ? null : const [],
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
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
      ),
    );
  }
}

/// Panel kiri: "Selamat Datang" + logo AdaTamu
/// Panel kiri: "Selamat Datang" + logo AdaTamu
class _WelcomePanel extends StatelessWidget {
  final bool isWide;
  const _WelcomePanel({required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.navy,
      padding: EdgeInsets.symmetric(horizontal: 36, vertical: isWide ? 48 : 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Selamat Datang',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: FractionallySizedBox(
                widthFactor: 0.92,
                child: Image.asset(
                  'lib/assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
