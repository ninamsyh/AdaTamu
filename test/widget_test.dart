import 'package:flutter/material.dart';
import 'package:adatamu/dashboard_page.dart';

void main() {
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
      home: const LoginPage(),
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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    // TODO: sambungkan ke proses autentikasi sesungguhnya kalau sudah ada backend-nya.
    // Untuk sekarang, begitu tombol Login ditekan, langsung pindah ke halaman Dashboard.
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardPage()));
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
                                  flex: 5,
                                  child: _WelcomePanel(isWide: isWide),
                                ),
                                Expanded(flex: 5, child: _buildLoginForm()),
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
    return Container(
      color: AppColors.teal,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
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
              child: const Icon(Icons.person, size: 56, color: Colors.white70),
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
          ),
          const SizedBox(height: 26),

          // Tombol Login
          SizedBox(
            width: 120,
            child: ElevatedButton(
              onPressed: _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.yellow,
                foregroundColor: AppColors.darkText,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Login',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
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
  final bool obscureText;
  final String? hintText;
  final Widget? suffixIcon;

  const _LoginTextField({
    required this.controller,
    this.obscureText = false,
    this.hintText,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
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
class _WelcomePanel extends StatelessWidget {
  final bool isWide;
  const _WelcomePanel({required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.navy,
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: isWide ? 0 : 32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selamat Datang',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Logo: buku + petir + wordmark, digeser sedikit ke tengah panel
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 70,
                  height: 70,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 70,
                        color: AppColors.teal,
                      ),
                      Icon(Icons.bolt, size: 32, color: AppColors.yellow),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Wordmark "AdaTamu"
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: 'Ada',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: 'Tamu',
                        style: TextStyle(color: AppColors.yellow),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
