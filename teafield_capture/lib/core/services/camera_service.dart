import 'package:camera/camera.dart';

/// Manages hardware camera initialization, capture, flash, and disposal.
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _selectedCameraIndex = 0;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get canSwitchCamera => _cameras.length > 1;
  FlashMode get currentFlashMode =>
      _controller?.value.flashMode ?? FlashMode.auto;

  /// Discovers available cameras and initializes the rear camera by default.
  Future<void> initialize({
    ResolutionPreset resolution = ResolutionPreset.high,
    int? cameraIndex,
  }) async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw StateError('No cameras are available on this device.');
    }

    if (cameraIndex != null &&
        cameraIndex >= 0 &&
        cameraIndex < _cameras.length) {
      _selectedCameraIndex = cameraIndex;
    } else {
      final backIndex = _cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      _selectedCameraIndex = backIndex >= 0 ? backIndex : 0;
    }

    await _initController(_cameras[_selectedCameraIndex], resolution);
  }

  Future<void> _initController(
    CameraDescription description,
    ResolutionPreset resolution,
  ) async {
    await _controller?.dispose();
    final nextController = CameraController(
      description,
      resolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = nextController;
    await nextController.initialize();
  }

  /// Cycles to the next camera (for example, back to front) if available.
  Future<void> switchCamera({
    ResolutionPreset resolution = ResolutionPreset.high,
  }) async {
    if (_cameras.length <= 1) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initController(_cameras[_selectedCameraIndex], resolution);
  }

  /// Sets the flash mode if supported by the current camera.
  Future<void> setFlashMode(FlashMode mode) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.setFlashMode(mode);
  }

  /// Captures a still JPEG photograph and returns the temporary [XFile].
  Future<XFile> takePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw StateError('Camera is not initialized.');
    }
    if (controller.value.isTakingPicture) {
      throw StateError('A photo is already being captured.');
    }
    return controller.takePicture();
  }

  /// Releases camera resources.
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
