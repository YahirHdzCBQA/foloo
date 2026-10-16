/// Testable image-picker boundary with typed failures and Android recovery.
///
/// Camera permission is intentionally handled by CameraAccessCoordinator;
/// gallery selection remains independent and never requests CAMERA access.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum ImageCaptureFailureKind {
  permissionDenied,
  cameraUnavailable,
  fileUnavailable,
  platform,
}

class ImageCaptureFailure implements Exception {
  const ImageCaptureFailure(this.kind);
  final ImageCaptureFailureKind kind;
}

class CapturedImage {
  CapturedImage({required this.path, required List<int> bytes})
    : bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

  final String path;
  final Uint8List bytes;
}

abstract interface class ImageCaptureService {
  Future<CapturedImage?> pick({
    required ImageSource source,
    double maxWidth,
    double maxHeight,
    int imageQuality,
    CameraDevice preferredCameraDevice,
  });

  Future<CapturedImage?> retrieveLostImage();
}

/// Device implementation used by card, reference and profile capture.
class DeviceImageCaptureService implements ImageCaptureService {
  DeviceImageCaptureService({
    ImagePicker? picker,
    bool? supportsLostDataRecovery,
  }) : _picker = picker ?? ImagePicker(),
       _supportsLostDataRecovery =
           supportsLostDataRecovery ?? Platform.isAndroid;

  final ImagePicker _picker;
  final bool _supportsLostDataRecovery;
  bool _retrievingLostData = false;

  ImageCaptureFailure _failure(Object error) {
    if (error is PlatformException) {
      if (error.code.contains('access_denied') ||
          error.code.contains('permission')) {
        return const ImageCaptureFailure(
          ImageCaptureFailureKind.permissionDenied,
        );
      }
      if (error.code.contains('no_available_camera')) {
        return const ImageCaptureFailure(
          ImageCaptureFailureKind.cameraUnavailable,
        );
      }
      if (error.code.contains('invalid_image') ||
          error.code.contains('photo_access')) {
        return const ImageCaptureFailure(
          ImageCaptureFailureKind.fileUnavailable,
        );
      }
    }
    return const ImageCaptureFailure(ImageCaptureFailureKind.platform);
  }

  Future<CapturedImage> _read(XFile image) async {
    try {
      return CapturedImage(path: image.path, bytes: await image.readAsBytes());
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<CapturedImage?> pick({
    required ImageSource source,
    double maxWidth = 1568,
    double maxHeight = 1568,
    int imageQuality = 85,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
        preferredCameraDevice: preferredCameraDevice,
      );
      return image == null ? null : await _read(image);
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<CapturedImage?> retrieveLostImage() async {
    // image_picker lost-data recovery is an Android activity-restart contract.
    // Calling it during iOS screen initialization can surface a platform error
    // even though the seller has not started an image operation.
    if (!_supportsLostDataRecovery) return null;
    if (_retrievingLostData) return null;
    _retrievingLostData = true;
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) return null;
      if (response.exception != null) throw _failure(response.exception!);
      final files = response.files;
      if (files == null || files.isEmpty) return null;
      return await _read(files.first);
    } catch (error) {
      if (error is ImageCaptureFailure) rethrow;
      throw _failure(error);
    } finally {
      _retrievingLostData = false;
    }
  }
}
