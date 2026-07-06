import 'package:flutter/material.dart';

import 'main.dart';
import 'services/auth_service.dart';

/// Halaman daftar akun baru. Dibutuhkan karena sistem login pakai
/// username: Firebase Console sendiri hanya bisa membuat user lewat
/// email, jadi user baru harus didaftarkan lewat halaman ini supaya
/// mapping username -> email ikut tersimpan di Firestore.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.register(
        username: _usernameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
      // Setelah daftar, Firebase otomatis menganggap user sudah login.
      // Tutup halaman ini supaya AuthGate di belakangnya menampilkan
      // Dashboard (karena authStateChanges sudah berubah jadi "login").
      if (mounted) Navigator.of(context).pop();
    } on AuthServiceException catch (e) {
      _showError(e.message);
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('DEBUG register_page catch(e): $e');
      // ignore: avoid_print
      print('DEBUG stackTrace: $stackTrace');
      _showError('Gagal mendaftar, coba lagi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showAppSnackBar(context, message, isError: true);
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
                    _buildRegisterCard(),
                    const SizedBox(height: 24),

                    // Link kembali ke halaman Login
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          const Text(
                            'Sudah punya akun? ',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          GestureDetector(
                            onTap: _isLoading
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text(
                              'Masuk',
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

  Widget _buildRegisterCard() {
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
            const Text(
              'Daftar Akun',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 28),

            _RegisterField(
              controller: _usernameController,
              hintText: 'Username',
              prefixIcon: Icons.person_outline,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Username wajib diisi'
                  : null,
            ),
            const SizedBox(height: 16),

            _RegisterField(
              controller: _emailController,
              hintText: 'Alamat Email',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Email wajib diisi';
                }
                if (!v.contains('@')) return 'Format email tidak valid';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _RegisterField(
              controller: _passwordController,
              hintText: 'Password',
              prefixIcon: Icons.lock_outline,
              obscureText: _obscurePassword,
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
                  (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
            ),
            const SizedBox(height: 16),

            _RegisterField(
              controller: _confirmPasswordController,
              hintText: 'Konfirmasi Password',
              prefixIcon: Icons.lock_outline,
              obscureText: _obscureConfirmPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  size: 18,
                  color: Colors.grey,
                ),
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Konfirmasi password wajib diisi';
                }
                if (v != _passwordController.text) {
                  return 'Password tidak sama';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
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
                        'Daftar',
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

/// Text field putih bulat sesuai desain kartu, dipakai khusus di
/// halaman Daftar (mendukung validator karena berada di dalam Form).
class _RegisterField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _RegisterField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(prefixIcon, size: 20, color: AppColors.navy),
        suffixIcon: suffixIcon,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
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
