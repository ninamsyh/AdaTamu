import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../theme/app_theme.dart';

class DesktopCameraCapturePage extends StatefulWidget {
  const DesktopCameraCapturePage({super.key});

  @override
  State<DesktopCameraCapturePage> createState() =>
      _DesktopCameraCapturePageState();
}

class _DesktopCameraCapturePageState extends State<DesktopCameraCapturePage> {
  CameraController? _controller;
  Future<void>? _initFuture;
  String? _errorMessage;
  bool _isCapturing = false;
  bool get _needsRotationFix => Platform.isWindows;

  @override
  void initState() {
    super.initState();
    _initFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage =
            'Tidak ada webcam yang terdeteksi di perangkat ini.');
        return;
      }

      final controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      setState(() => _errorMessage = _friendlyErrorMessage(e));
    }
  }

  String _friendlyErrorMessage(Object e) {
    final String raw = e.toString().toLowerCase();

    if (raw.contains('permission') ||
        raw.contains('denied') ||
        raw.contains('access')) {
      return 'Akses webcam ditolak.\n\n'
          'Aktifkan dulu di Windows: Settings > Privacy & security > '
          'Camera, lalu nyalakan "Let apps access your camera".';
    }
    if (raw.contains('cameraexception') || raw.contains('notreadable')) {
      return 'Webcam sedang dipakai aplikasi lain (mis. Zoom/Teams).\n'
          'Tutup aplikasi itu dulu, lalu coba lagi.';
    }
    return 'Gagal mengakses webcam. Pastikan webcam terpasang & tidak '
        'sedang dipakai aplikasi lain, lalu coba lagi.';
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_isCapturing) return;

    setState(() => _isCapturing = true);
    try {
      final XFile file = await controller.takePicture();
      final XFile finalFile =
          _needsRotationFix ? await _fixRotation(file) : file;
      if (!mounted) return;
      Navigator.of(context).pop(finalFile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil foto. Coba lagi.')),
      );
      setState(() => _isCapturing = false);
    }
  }

  Future<XFile> _fixRotation(XFile original) async {
    try {
      final bytes = await original.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return original;

      final flipped = img.flipVertical(decoded);
      final encoded = img.encodeJpg(flipped, quality: 85);
      final fixedPath =
          '${original.path.substring(0, original.path.lastIndexOf('.'))}_fixed.jpg';
      final fixedFile = await File(fixedPath).writeAsBytes(encoded);
      return XFile(fixedFile.path);
    } catch (_) {
      return original;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 860,
          height: 600,
          child: FutureBuilder<void>(
            future: _initFuture,
            builder: (context, snapshot) {
              if (_errorMessage != null) {
                return _buildMessage(_errorMessage!, showClose: true);
              }
              if (snapshot.connectionState != ConnectionState.done ||
                  _controller == null ||
                  !_controller!.value.isInitialized) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final controller = _controller!;
              final Size previewSize =
                  controller.value.previewSize ?? const Size(640, 480);

              Widget cameraLayer = FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: previewSize.width,
                  height: previewSize.height,
                  child: CameraPreview(controller),
                ),
              );

              if (_needsRotationFix) {
                cameraLayer = Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationX(math.pi),
                  child: cameraLayer,
                );
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRect(child: cameraLayer),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _CloseButton(
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20,
                    child: Center(
                      child: _ShutterButton(
                        isLoading: _isCapturing,
                        onTap: _capture,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(String message, {bool showClose = false}) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_rounded,
              color: Colors.white54, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          if (showClose) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Tutup',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  color: AppColors.inputBorderFocused,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _ShutterButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isLoading ? null : onTap,
        child: Container(
          width: 64,
          height: 64,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLoading ? Colors.white38 : Colors.white,
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black54,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
