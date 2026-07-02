import 'package:flutter/material.dart';
import '../services/guest_service.dart';
import '../theme/app_theme.dart';
import '../utils/guest_code.dart';
import '../widgets/animated_pill_button.dart';
import '../widgets/guest_dropdown_field.dart';
import '../widgets/guest_navbar.dart';
import '../widgets/guest_text_field.dart';
import 'guest_form_page3.dart';

class GuestFormPage2 extends StatefulWidget {
  const GuestFormPage2({super.key});

  @override
  State<GuestFormPage2> createState() => _GuestFormPage2State();
}

class _GuestFormPage2State extends State<GuestFormPage2> {
  final _formKey = GlobalKey<FormState>();
  final _jenisKelaminFieldKey = GlobalKey<GuestDropdownFieldState>();

  final _namaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _hpController = TextEditingController();
  String? _jenisKelamin;

  String? _keperluan;
  String _keperluanLainnya = '';
  String _keterangan = '';
  List<String> _fotoPaths = [];

  static const List<String> _jenisKelaminOptions = ['Laki-Laki', 'Perempuan'];
  String? _kodeTamu;
  String? _kodeTamuError;

  @override
  void initState() {
    super.initState();
    _loadKodeTamu();
  }

  Future<void> _loadKodeTamu() async {
    try {
      final int urutan =
          await GuestService.peekNextUrutanHariIni(DateTime.now());
      if (!mounted) return;
      setState(() {
        _kodeTamu = GuestCode.generate(DateTime.now(), urutan);
        _kodeTamuError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _kodeTamuError = e.toString());
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _alamatController.dispose();
    _hpController.dispose();
    super.dispose();
  }

  Future<void> _goToNextPage() async {
    final bool isFormValid = _formKey.currentState!.validate();
    final bool isJenisKelaminValid =
        _jenisKelaminFieldKey.currentState?.validate() ?? true;

    if (!isFormValid || !isJenisKelaminValid) return;

    if (_kodeTamu == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Kode tamu belum siap, mohon tunggu sebentar lalu coba lagi.'),
        ),
      );
      if (_kodeTamuError != null) _loadKodeTamu();
      return;
    }

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => GuestFormPage3(
          nama: _namaController.text.trim(),
          jenisKelamin: _jenisKelamin!,
          alamat: _alamatController.text.trim(),
          nomorHandphone: _hpController.text.trim(),
          kodeTamu: _kodeTamu!,
          initialKeperluan: _keperluan,
          initialKeperluanLainnya: _keperluanLainnya,
          initialKeterangan: _keterangan,
          initialFotoPaths: _fotoPaths,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _keperluan = result['keperluan'] as String?;
        _keperluanLainnya = result['keperluanLainnya'] as String? ?? '';
        _keterangan = result['keterangan'] as String? ?? '';
        _fotoPaths =
            (result['fotoPaths'] as List?)?.cast<String>() ?? <String>[];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_kodeTamu == null) {
      return Scaffold(
        backgroundColor: AppColors.formBackground,
        body: SafeArea(
          child: Center(
            child: _kodeTamuError != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 36),
                        const SizedBox(height: 12),
                        Text(
                          'Gagal menyiapkan kode tamu.\n$_kodeTamuError',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        AnimatedPillButton(
                          label: 'Coba Lagi',
                          compact: true,
                          onPressed: _loadKodeTamu,
                        ),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.formBackground,
      body: Column(
        children: [
          GuestNavbar(kodeTamu: _kodeTamu!),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      GuestTextField(
                        label: 'Nama Lengkap',
                        controller: _namaController,
                        hintText: 'Masukkan nama lengkap',
                        validator: (value) {
                          final String trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) return 'Nama tidak boleh kosong';
                          if (trimmed.length < 2)
                            return 'Nama minimal 2 karakter';
                          if (trimmed.length > 60)
                            return 'Nama maksimal 60 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      GuestDropdownField(
                        key: _jenisKelaminFieldKey,
                        label: 'Jenis Kelamin',
                        value: _jenisKelamin,
                        options: _jenisKelaminOptions,
                        onChanged: (value) =>
                            setState(() => _jenisKelamin = value),
                      ),
                      const SizedBox(height: 24),
                      GuestTextField(
                        label: 'Alamat Lengkap',
                        controller: _alamatController,
                        hintText: 'Masukkan alamat lengkap',
                        validator: (value) {
                          final String trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty)
                            return 'Alamat tidak boleh kosong';
                          final List<String> words = trimmed
                              .split(RegExp(r'\s+'))
                              .where((w) => w.isNotEmpty)
                              .toList();
                          if (words.length < 2)
                            return 'Alamat minimal terdiri dari 2 kata';
                          if (trimmed.length < 10)
                            return 'Alamat terlalu singkat, tuliskan lebih lengkap';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      GuestTextField(
                        label: 'Nomor Handphone',
                        controller: _hpController,
                        hintText: 'Masukkan nomor handphone',
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nomor handphone tidak boleh kosong';
                          }
                          if (!RegExp(r'^[0-9+\-\s]{8,15}$')
                              .hasMatch(value.trim())) {
                            return 'Nomor handphone tidak valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedPillButton(
                          label: 'Berikutnya',
                          onPressed: _goToNextPage,
                          compact: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
