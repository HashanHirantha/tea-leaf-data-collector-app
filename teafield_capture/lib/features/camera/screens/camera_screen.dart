import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/camera_service.dart';
import '../../../core/services/device_info_service.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/leaf_photo.dart';
import '../../../data/models/leaf_sample.dart';
import '../../../data/repositories/photo_repository.dart';

/// Reusable camera screen that captures an original JPEG for either the
/// upper (adaxial) or lower (abaxial) side of a given [sampleUuid].
class CameraScreen extends StatefulWidget {
  final String sampleUuid;
  final String leafSide;

  const CameraScreen({
    super.key,
    required this.sampleUuid,
    required this.leafSide,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  final PhotoRepository _photoRepo = PhotoRepository();
  final FileStorageService _storage = FileStorageService.instance;

  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isSaving = false;
  String? _errorMessage;
  XFile? _capturedFile;
  FlashMode _flashMode = FlashMode.auto;

  LeafSide get _side => LeafSide.fromDatabaseKey(widget.leafSide);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cameraService.dispose();
    } else if (state == AppLifecycleState.resumed && _capturedFile == null) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      final qualitySetting = await SettingsService.instance.getImageQuality();
      final preset = qualitySetting == 'medium'
          ? ResolutionPreset.medium
          : ResolutionPreset.high;
      await _cameraService.initialize(resolution: preset);
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _flashMode = _cameraService.currentFlashMode;
        });
      }
    } on CameraException catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = e.code == 'CameraAccessDenied' ||
                  e.code == 'CameraAccessDeniedWithoutPrompt'
              ? 'Camera permission was denied. Enable camera access in device settings to photograph leaves.'
              : 'Camera error (${e.code}): ${e.description ?? 'Unavailable'}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Could not open camera: $e';
        });
      }
    }
  }

  Future<void> _takePhoto() async {
    if (_isCapturing || !_cameraService.isInitialized) return;
    setState(() => _isCapturing = true);
    try {
      final file = await _cameraService.takePhoto();
      if (mounted) {
        setState(() {
          _capturedFile = file;
          _isCapturing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
    }
  }

  Future<void> _cycleFlash() async {
    final nextMode = switch (_flashMode) {
      FlashMode.auto => FlashMode.always,
      FlashMode.always => FlashMode.off,
      _ => FlashMode.auto,
    };
    try {
      await _cameraService.setFlashMode(nextMode);
      if (mounted) {
        setState(() => _flashMode = nextMode);
      }
    } catch (_) {
      // Some devices do not support all flash modes.
    }
  }

  Future<void> _acceptCapturedPhoto() async {
    final captured = _capturedFile;
    if (captured == null || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final photoUuid = IdGenerator.generatePhotoUuid();
      final stored = await _storage.saveCapturedPhoto(
        sampleUuid: widget.sampleUuid,
        photoUuid: photoUuid,
        leafSide: _side.databaseKey,
        sourceFile: captured,
      );

      final deviceMeta = await DeviceInfoService.instance.getDeviceMetadata();
      final gpsFix = await LocationService.instance.getCurrentGpsFix();
      final allowSingleSide =
          await SettingsService.instance.getAllowSingleSideComplete();
      final now = AppDateUtils.nowUtcIso();

      final photo = LeafPhoto(
        photoUuid: photoUuid,
        sampleUuid: widget.sampleUuid,
        leafSide: _side.databaseKey,
        filePath: stored.filePath,
        originalFileName: stored.originalFileName,
        sha256: stored.sha256,
        widthPx: stored.widthPx,
        heightPx: stored.heightPx,
        fileSizeBytes: stored.fileSizeBytes,
        capturedAtUtc: now,
        deviceId: deviceMeta.deviceId,
        devicePlatform: deviceMeta.platform,
        deviceManufacturer: deviceMeta.manufacturer,
        deviceModel: deviceMeta.model,
        osVersion: deviceMeta.osVersion,
        appVersion: deviceMeta.appVersion,
        latitude: gpsFix.latitude,
        longitude: gpsFix.longitude,
        gpsAccuracyM: gpsFix.accuracyMeters,
        gpsCapturedAtUtc: gpsFix.capturedAtUtc,
        gpsStatus: gpsFix.status.databaseKey,
        isPrimary: 1,
        photoReviewStatus: 'accepted',
        createdAtUtc: now,
      );

      await _photoRepo.savePhoto(
        photo,
        markPreviousNonPrimary: true,
        allowSingleSideComplete: allowSingleSide,
      );

      if (mounted) {
        context.pop(photo);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save original photo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final captured = _capturedFile;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_side.displayName),
        actions: [
          if (captured == null && _cameraService.isInitialized)
            IconButton(
              tooltip: 'Flash mode',
              icon: Icon(
                switch (_flashMode) {
                  FlashMode.always => Icons.flash_on,
                  FlashMode.off => Icons.flash_off,
                  _ => Icons.flash_auto,
                },
              ),
              onPressed: _cycleFlash,
            ),
          if (captured == null && _cameraService.canSwitchCamera)
            IconButton(
              tooltip: 'Switch camera',
              icon: const Icon(Icons.cameraswitch),
              onPressed: () async {
                final quality =
                    await SettingsService.instance.getImageQuality();
                await _cameraService.switchCamera(
                  resolution: quality == 'medium'
                      ? ResolutionPreset.medium
                      : ResolutionPreset.high,
                );
                if (mounted) setState(() {});
              },
            ),
        ],
      ),
      body: _buildBody(captured),
    );
  }

  Widget _buildBody(XFile? captured) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography, color: Colors.white70, size: 56),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _initCamera,
                child: const Text('Retry Camera'),
              ),
            ],
          ),
        ),
      );
    }

    if (captured != null) {
      return Column(
        children: [
          Expanded(
            child: Image.file(
              File(captured.path),
              fit: BoxFit.contain,
              width: double.infinity,
            ),
          ),
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Check focus, lighting, and that the whole leaf is visible.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          onPressed: _isSaving
                              ? null
                              : () => setState(() => _capturedFile = null),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retake'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _acceptCapturedPhoto,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(_isSaving ? 'Saving...' : 'Accept Photo'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_isInitializing || _cameraService.controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Center(child: CameraPreview(_cameraService.controller!)),
        Positioned(
          top: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Photographing ${_side.displayName}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
        Positioned(
          bottom: 32,
          child: GestureDetector(
            onTap: _isCapturing ? null : _takePhoto,
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                color: _isCapturing ? Colors.grey : Colors.white24,
              ),
              child: Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
