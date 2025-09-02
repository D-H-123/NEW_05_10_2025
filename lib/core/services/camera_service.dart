import 'dart:io';
import 'dart:ui' show Offset;
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  Future<void> init() async {
    _cameras = await availableCameras();
    _controller = CameraController(
      _cameras!.first, // rear camera
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();

    // Improve capture quality and stability for OCR
    try {
      await _controller!.setFocusMode(FocusMode.auto);
    } catch (_) {}
    try {
      await _controller!.setExposureMode(ExposureMode.auto);
    } catch (_) {}
    // Center focus point if supported (guarded; some platforms don't expose a flag)
    try {
      await _controller!.setFocusPoint(const Offset(0.5, 0.5));
    } catch (_) {}
  }

  CameraController? get controller => _controller;

  Future<File> takePicture() async {
    if (!_controller!.value.isInitialized) {
      throw Exception("Camera not initialized");
    }
    final picture = await _controller!.takePicture();
    final directory = await getTemporaryDirectory();
    final path =
        "${directory.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.jpg";
    return File(picture.path)..copySync(path);
  }

  void dispose() {
    _controller?.dispose();
  }
}
