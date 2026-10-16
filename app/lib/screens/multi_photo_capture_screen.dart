/// Focused V1 camera session for collecting contact-reference images.
///
/// It stages up to three photos and returns them to CaptureLead only after the
/// seller confirms, keeping the platform image picker behind its service boundary.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/l10n.dart';
import '../services/camera_access_service.dart';
import '../services/contact_image_picker_service.dart';
import '../theme/foloo_theme.dart';
import '../widgets/camera_access_dialog.dart';

/// Captures the remaining CAP-23 photos without returning to the lead form.
class MultiPhotoCaptureScreen extends StatefulWidget {
  const MultiPhotoCaptureScreen({
    required this.initialImages,
    required this.picker,
    this.maximumImages = 3,
    this.cameraAccessCoordinator,
    super.key,
  });

  final List<PickedContactImage> initialImages;
  final ContactImagePickerService picker;
  final int maximumImages;
  final CameraAccessCoordinator? cameraAccessCoordinator;

  @override
  State<MultiPhotoCaptureScreen> createState() =>
      _MultiPhotoCaptureScreenState();
}

class _MultiPhotoCaptureScreenState extends State<MultiPhotoCaptureScreen>
    with WidgetsBindingObserver {
  late final List<PickedContactImage> _images;
  late final CameraAccessCoordinator _cameraAccess;
  bool _openingCamera = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraAccess = widget.cameraAccessCoordinator ?? CameraAccessCoordinator();
    _images = List.of(widget.initialImages.take(widget.maximumImages));
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverOrCapture());
  }

  Future<void> _recoverOrCapture() async {
    final picker = widget.picker;
    if (picker is RecoverableContactImagePickerService) {
      try {
        final recovered = await (picker as RecoverableContactImagePickerService)
            .retrieveLostImage();
        if (mounted &&
            recovered != null &&
            _images.length < widget.maximumImages &&
            !_images.any((image) => image.path == recovered.path)) {
          setState(() => _images.add(recovered));
          return;
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(imageCaptureFailureMessage(context, error))),
          );
        }
        return;
      }
    }
    await _capture();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_cameraAccess.revalidateAfterSettings());
    }
  }

  Future<void> _capture() async {
    if (_openingCamera || _images.length >= widget.maximumImages) return;
    if (!await ensureCameraAccess(context, _cameraAccess) || !mounted) return;
    setState(() => _openingCamera = true);
    try {
      final image = await widget.picker.pick(ImageSource.camera);
      if (!mounted || image == null || _images.length >= widget.maximumImages) {
        return;
      }
      setState(() => _images.add(image));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(imageCaptureFailureMessage(context, error))),
      );
    } finally {
      if (mounted) setState(() => _openingCamera = false);
    }
  }

  void _finish() =>
      Navigator.pop(context, List<PickedContactImage>.of(_images));

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final latest = _images.isEmpty ? null : _images.last;
    return Scaffold(
      key: const Key('multiPhotoCaptureScreen'),
      backgroundColor: palette.card,
      appBar: AppBar(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          key: const Key('cancelMultiPhotoSession'),
          tooltip: context.l10n.cancel,
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: Text(context.l10n.referencePhotoSessionTitle),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: palette.paper,
                    borderRadius: BorderRadius.circular(FolooRadii.lg),
                  ),
                  child: latest == null
                      ? Center(
                          child: _openingCamera
                              ? CircularProgressIndicator(color: palette.ink)
                              : Icon(
                                  Icons.photo_camera_outlined,
                                  size: 46,
                                  color: palette.inkSecondary,
                                ),
                        )
                      : Image.memory(
                          Uint8List.fromList(latest.bytes),
                          key: const Key('multiPhotoLatestPreview'),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.l10n.selectedOfTotal(
                  _images.length,
                  widget.maximumImages,
                ),
                key: const Key('multiPhotoCount'),
                style: TextStyle(
                  color: palette.inkSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                key: const Key('multiPhotoIndicators'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.maximumImages, (index) {
                  final captured = index < _images.length;
                  return Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: captured ? palette.ink : palette.paper,
                    ),
                    child: Icon(
                      captured ? Icons.photo : Icons.photo_outlined,
                      size: 18,
                      color: captured ? palette.card : palette.inkSecondary,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    key: const Key('captureAnotherReferencePhoto'),
                    tooltip: context.l10n.takeAnotherPhoto,
                    onPressed:
                        _openingCamera || _images.length >= widget.maximumImages
                        ? null
                        : _capture,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(56, 56),
                      backgroundColor: palette.ink,
                      foregroundColor: palette.card,
                      disabledBackgroundColor: palette.paper,
                      disabledForegroundColor: palette.inkSecondary,
                    ),
                    icon: const Icon(Icons.photo_camera_outlined),
                  ),
                  const SizedBox(width: 24),
                  IconButton.filled(
                    key: const Key('finishMultiPhotoSession'),
                    tooltip: context.l10n.finishPhotos,
                    onPressed: _openingCamera ? null : _finish,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(56, 56),
                      backgroundColor: FolooColors.lime,
                      foregroundColor: FolooColors.ink,
                    ),
                    icon: const Icon(Icons.check),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
