import 'dart:io';
import 'package:flutter/material.dart';
import '../models/guest.dart';
import '../services/cloudinary_service.dart';
import '../services/guest_service.dart';
import '../theme/app_theme.dart';
import '../utils/guest_code.dart';
import '../widgets/animated_pill_button.dart';
import '../widgets/guest_dropdown_field.dart';
import '../widgets/guest_navbar.dart';
import '../widgets/guest_text_field.dart';
import '../widgets/photo_picker_field.dart';
import 'guest_success_page.dart';

class GuestFormPage3 extends StatefulWidget {
  final String nama;
  final String jenisKelamin;
  final String alamat;
  final String nomorHandphone;
  final String kodeTamu;
  final String? initialKeperluan;
  final String initialKeperluanLainnya;
  final String initialKeterangan;
  final List<String> initialFotoPaths;

  const GuestFormPage3({
    super.key,
    required this.nama,
    required this.jenisKelamin,
    required this.alamat,
    required this.nomorHandphone,
    required this.kodeTamu,
    this.initialKeperluan,
    this.initialKeperluanLainnya = '',
    this.initialKeterangan = '',
    this.initialFotoPaths = const [],
  });

  @override
  State<GuestFormPage3> createState() => _GuestFormPage3State();
}

class _GuestFormPage3State extends State<GuestFormPage3> {
  final _formKey = GlobalKey<FormState>();
  final _keteranganController = TextEditingController();
  final _keperluanLainnyaController = TextEditingController();
  final _photoFieldKey = GlobalKey<PhotoPickerFieldState>();
  Key _lainnyaFieldKey = UniqueKey();

  String? _keperluan;
  List<File> _fotos = [];
  bool _isSaving = false;
  bool _keperluanError = false;

  static const List<String> _keperluanOptions = [
    'KWH Meter',
    'Pembayaran Tagihan',
    'Perubahan Daya Listrik',
    'Masalah Administrasi',
    'Lainnya',
  ];

  bool get _isLainnya => _keperluan == 'Lainnya';

  @override
  void initState() {
    super.initState();
    _keperluan = widget.initialKeperluan;
    _keperluanLainnyaController.text = widget.initialKeperluanLainnya;
    _keteranganController.text = widget.initialKeterangan;
    if (widget.initialFotoPaths.isNotEmpty) {
      _fotos = widget.initialFotoPaths.map((p) => File(p)).toList();
    }
  }

  @override
  void dispose() {
    _keteranganController.dispose();
    _keperluanLainnyaController.dispose();
    super.dispose();
  }

  Future<void> _saveGuest() async {
    final bool isFormValid = _formKey.currentState!.validate();

    if (_keperluan == null) {
      setState(() => _keperluanError = true);
    }

    final bool isPhotoValid =
        _photoFieldKey.currentState?.validate() ?? _fotos.isNotEmpty;

    if (!isFormValid || _keperluan == null || !isPhotoValid) return;

    setState(() => _isSaving = true);

    final String keperluanFinal =
        _isLainnya ? _keperluanLainnyaController.text.trim() : _keperluan!;

    try {
      final List<String> fotoUrls = await Future.wait(
        _fotos.map((foto) => CloudinaryService.uploadImage(foto)),
      );
      final int urutanFinal =
          await GuestService.getNextUrutanHariIni(DateTime.now());
      final String kodeTamuFinal =
          GuestCode.generate(DateTime.now(), urutanFinal);

      final guest = Guest(
        nama: widget.nama,
        jenisKelamin: widget.jenisKelamin,
        alamat: widget.alamat,
        nomorHandphone: widget.nomorHandphone,
        keperluan: keperluanFinal,
        keteranganTambahan: _keteranganController.text.trim(),
        kodeTamu: kodeTamuFinal,
        fotoUrls: fotoUrls,
      );

      await GuestService.saveGuest(guest);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => GuestSuccessPage(kodeTamu: kodeTamuFinal)),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan data: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSaving) return;
        Navigator.of(context).pop({
          'keperluan': _keperluan,
          'keperluanLainnya': _keperluanLainnyaController.text,
          'keterangan': _keteranganController.text,
          'fotoPaths': _fotos.map((f) => f.path).toList(),
        });
      },
      child: Scaffold(
        backgroundColor: AppColors.formBackground,
        body: Column(
          children: [
            GuestNavbar(kodeTamu: widget.kodeTamu),
            Expanded(
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        GuestDropdownField(
                          label: 'Keperluan',
                          value: _keperluan,
                          options: _keperluanOptions,
                          onChanged: (value) {
                            setState(() {
                              _keperluan = value;
                              _keperluanError = false;
                              // Reset field lainnya + paksa rebuild validator
                              if (!_isLainnya) {
                                _keperluanLainnyaController.clear();
                              }
                              _lainnyaFieldKey = UniqueKey();
                            });
                          },
                        ),
                        if (_keperluanError)
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 4, left: 12, right: 12),
                            child: Text(
                              'Keperluan tidak boleh kosong',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) =>
                              SizeTransition(
                            sizeFactor: animation,
                            axisAlignment: -1,
                            child: FadeTransition(
                                opacity: animation, child: child),
                          ),
                          child: _isLainnya
                              ? Padding(
                                  key: _lainnyaFieldKey,
                                  padding: const EdgeInsets.only(top: 16),
                                  child: GuestTextField(
                                    label: 'Tuliskan Keperluan Anda',
                                    controller: _keperluanLainnyaController,
                                    hintText: 'Masukkan keperluan anda',
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Keperluan tidak boleh kosong';
                                      }
                                      return null;
                                    },
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('no_lainnya')),
                        ),
                        const SizedBox(height: 24),
                        GuestTextField(
                          label: 'Keterangan Tambahan',
                          controller: _keteranganController,
                          hintText: 'Tuliskan keterangan tambahan (opsional)',
                          maxLines: 5,
                        ),
                        const SizedBox(height: 24),
                        PhotoPickerField(
                          key: _photoFieldKey,
                          value: _fotos,
                          onChanged: (files) {
                            setState(() => _fotos = files);
                          },
                        ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedPillButton(
                                label: 'Kembali',
                                backgroundColor: const Color(0xFFBDBDBD),
                                compact: true,
                                onPressed: _isSaving
                                    ? null
                                    : () => Navigator.of(context).pop({
                                          'keperluan': _keperluan,
                                          'keperluanLainnya':
                                              _keperluanLainnyaController.text,
                                          'keterangan':
                                              _keteranganController.text,
                                          'fotoPaths': _fotos
                                              .map((f) => f.path)
                                              .toList(),
                                        }),
                              ),
                              const SizedBox(width: 12),
                              AnimatedPillButton(
                                label: 'Simpan',
                                compact: true,
                                isLoading: _isSaving,
                                onPressed: _isSaving ? null : _saveGuest,
                              ),
                            ],
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
      ),
    );
  }
}
