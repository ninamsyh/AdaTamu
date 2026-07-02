import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import 'desktop_camera_capture_page.dart';

class PhotoPickerField extends StatefulWidget {
  final List<File> value;
  final ValueChanged<List<File>> onChanged;
  final int maxPhotos;

  const PhotoPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.maxPhotos = 3,
  });

  @override
  State<PhotoPickerField> createState() => PhotoPickerFieldState();
}

class PhotoPickerFieldState extends State<PhotoPickerField> {
  String? _errorText;
  final ImagePicker _picker = ImagePicker();

  bool get _isFull => widget.value.length >= widget.maxPhotos;

  bool validate() {
    if (widget.value.isEmpty) {
      setState(() => _errorText = 'Wajib ambil minimal 1 gambar');
      return false;
    }
    setState(() => _errorText = null);
    return true;
  }

  void _clearError() {
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
  }

  /// Mengganti foto pertama (dipakai selagi baru ada 0-1 foto, lewat kotak besar).
  void _replaceFirst(File file) {
    _clearError();
    widget.onChanged([file, ...widget.value.skip(1)]);
  }

  /// Menambah foto baru ke daftar (dipakai lewat tombol "Tambah foto" atau tile tambah).
  void _addPhoto(File file) {
    if (_isFull) return;
    _clearError();
    widget.onChanged([...widget.value, file]);
  }

  void _removePhoto(int index) {
    final updated = [...widget.value]..removeAt(index);
    widget.onChanged(updated);
  }

  bool get _useDesktopDialog =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  List<Widget> _sourceOptions(BuildContext popupContext) {
    return [
      ListTile(
        leading: const Icon(
          Icons.photo_camera_rounded,
          color: AppColors.inputBorderFocused,
        ),
        title: Text('Kamera',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 14,
            )),
        onTap: () => Navigator.of(popupContext).pop(ImageSource.camera),
      ),
      ListTile(
        leading: const Icon(
          Icons.photo_library_rounded,
          color: AppColors.inputBorderFocused,
        ),
        title: Text('Galeri',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 14,
            )),
        onTap: () => Navigator.of(popupContext).pop(ImageSource.gallery),
      ),
    ];
  }

  Future<ImageSource?> _showDesktopDialog() {
    return showDialog<ImageSource>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ambil Foto Tamu',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.labelText,
                  ),
                ),
                const SizedBox(height: 8),
                ..._sourceOptions(dialogContext),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<ImageSource?> _showMobileSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Text(
                  'Ambil Foto Tamu',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.labelText,
                  ),
                ),
                const SizedBox(height: 8),
                ..._sourceOptions(sheetContext),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Membuka pemilihan sumber (kamera/galeri) dan mengembalikan File hasil
  /// pilihan, tanpa mengubah state apa pun. Pemanggil yang menentukan file
  /// ini dipakai untuk mengganti atau menambah foto.
  Future<File?> _pickImageFile() async {
    final ImageSource? source =
        await (_useDesktopDialog ? _showDesktopDialog() : _showMobileSheet());

    if (source == null || !mounted) return null;

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return null;

    if (source == ImageSource.camera && _useDesktopDialog) {
      final XFile? photo = await showDialog<XFile>(
        context: context,
        barrierColor: Colors.black87,
        builder: (_) => const DesktopCameraCapturePage(),
      );
      if (photo == null || !mounted) return null;
      return File(photo.path);
    }

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (picked == null) return null;
      return File(picked.path);
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil foto: $e')),
      );
      return null;
    }
  }

  Future<void> _onTapBigTile() async {
    final file = await _pickImageFile();
    if (file == null) return;
    _replaceFirst(file);
  }

  Future<void> _onTapAdd() async {
    if (_isFull) return;
    final file = await _pickImageFile();
    if (file == null) return;
    _addPhoto(file);
  }

  Widget _buildBigTile() {
    final bool hasPhoto = widget.value.isNotEmpty;
    final bool hasError = _errorText != null;

    return GestureDetector(
      onTap: _onTapBigTile,
      child: Container(
        width: double.infinity,
        height: hasPhoto ? 200 : 140,
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasError ? Colors.red : Colors.transparent,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasPhoto
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(widget.value.first, fit: BoxFit.cover),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_a_photo_rounded,
                    size: 32,
                    color: Colors.black38,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ketuk untuk ambil foto',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 13,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildThumbnail(int index) {
    final file = widget.value[index];
    return Container(
      width: 96,
      height: 96,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(file, fit: BoxFit.cover),
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: () => _removePhoto(index),
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTile() {
    return GestureDetector(
      onTap: _onTapAdd,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_rounded,
              size: 26,
              color: Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < widget.value.length; i++) _buildThumbnail(i),
          if (!_isFull) _buildAddTile(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = _errorText != null;
    // Kotak besar dipakai selagi foto masih 0 atau 1. Begitu ada 2+ foto,
    // tampilan pindah ke baris thumbnail kecil supaya semua foto kelihatan.
    final bool showBigTile = widget.value.length <= 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Ambil gambar', style: AppTextStyles.fieldLabel),
        const SizedBox(height: 10),
        showBigTile ? _buildBigTile() : _buildThumbnailRow(),
        if (showBigTile && widget.value.length == 1 && !_isFull)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextButton.icon(
              onPressed: _onTapAdd,
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
              label: Text(
                'Tambah foto lain',
                style: TextStyle(fontFamily: AppTextStyles.fontFamily),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.inputBorderFocused,
              ),
            ),
          ),
        SizedBox(
          height: 26,
          width: double.infinity,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12, right: 12),
                  child: Text(
                    _errorText!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      color: Colors.red,
                      fontSize: 13,
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}
