/// First-use seller profile setup for the current frontend session.
///
/// Captures optional imagery plus the identity attached to leads; durable
/// profile persistence remains part of AUT-04/AUT-05 product work.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_event.dart';
import '../services/camera_access_service.dart';
import '../services/image_capture_service.dart';
import '../theme/brand_theme.dart';
import '../theme/foloo_theme.dart';
import '../l10n/l10n.dart';
import '../widgets/auth_text_form_field.dart';
import '../widgets/camera_access_dialog.dart';

/// Collects the minimum seller identity required before lead capture.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    required this.onContinue,
    this.initialProfile = DemoProfile.empty,
    this.cameraAccessCoordinator,
    this.imageCaptureService,
    super.key,
  });

  final ValueChanged<DemoProfile> onContinue;
  final DemoProfile initialProfile;
  final CameraAccessCoordinator? cameraAccessCoordinator;
  final ImageCaptureService? imageCaptureService;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _company;
  final _nameFocus = FocusNode();
  final _companyFocus = FocusNode();
  late final CameraAccessCoordinator _cameraAccess;
  late final ImageCaptureService _imageCapture;
  Uint8List? _profileBytes;
  String? _profileSourcePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraAccess = widget.cameraAccessCoordinator ?? CameraAccessCoordinator();
    _imageCapture = widget.imageCaptureService ?? DeviceImageCaptureService();
    _name = TextEditingController(text: widget.initialProfile.name);
    _company = TextEditingController(text: widget.initialProfile.company);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostImage());
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    if (source == ImageSource.camera &&
        !await ensureCameraAccess(context, _cameraAccess)) {
      return;
    }
    try {
      final image = await _imageCapture.pick(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );
      if (image == null) return;
      if (mounted) {
        setState(() {
          _profileBytes = image.bytes;
          _profileSourcePath = image.path;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(imageCaptureFailureMessage(context, error))),
      );
    }
  }

  Future<void> _recoverLostImage() async {
    try {
      final image = await _imageCapture.retrieveLostImage();
      if (!mounted || image == null || image.path == _profileSourcePath) return;
      setState(() {
        _profileBytes = image.bytes;
        _profileSourcePath = image.path;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(imageCaptureFailureMessage(context, error))),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_cameraAccess.revalidateAfterSettings());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _name.dispose();
    _company.dispose();
    _nameFocus.dispose();
    _companyFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onContinue(
      DemoProfile(
        name: _name.text.trim(),
        company: _company.text.trim(),
        photoLocalPath:
            _profileSourcePath ?? widget.initialProfile.photoLocalPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: palette.card,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Image.asset(
                      FolooBrand.logoFor(Theme.of(context).brightness),
                      width: 56,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    context.l10n.profileTitle,
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.profileHelp,
                    style: TextStyle(color: palette.inkSecondary, fontSize: 15),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: palette.paper,
                        backgroundImage: _profileBytes == null
                            ? null
                            : MemoryImage(_profileBytes!),
                        child: _profileBytes == null
                            ? Icon(
                                Icons.person_outline,
                                key: const Key('profilePlaceholderIcon'),
                                color: palette.inkSecondary,
                                size: 29,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.profilePhoto,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Row(
                              children: [
                                IconButton.filled(
                                  key: const Key('profileCameraButton'),
                                  tooltip: context.l10n.profileTakePhoto,
                                  onPressed: () =>
                                      _pickProfileImage(ImageSource.camera),
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                    backgroundColor: palette.ink,
                                    foregroundColor: palette.card,
                                  ),
                                  icon: const Icon(
                                    Icons.photo_camera_outlined,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton.filled(
                                  key: const Key('profileGalleryButton'),
                                  tooltip: context.l10n.profileGallery,
                                  onPressed: () =>
                                      _pickProfileImage(ImageSource.gallery),
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                    backgroundColor: palette.paper,
                                    foregroundColor: palette.inkSecondary,
                                  ),
                                  icon: const Icon(
                                    Icons.photo_outlined,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  _ProfileField(
                    label: context.l10n.profileFullName,
                    child: AuthTextFormField(
                      fieldKey: const Key('profileNameField'),
                      controller: _name,
                      focusNode: _nameFocus,
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                      onEditingComplete: _companyFocus.requestFocus,
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? context.l10n.nameRequired
                          : null,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ProfileField(
                    label: context.l10n.company,
                    child: AuthTextFormField(
                      fieldKey: const Key('profileCompanyField'),
                      controller: _company,
                      focusNode: _companyFocus,
                      autofillHints: const [AutofillHints.organizationName],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? context.l10n.companyRequired
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
        padding: EdgeInsets.only(bottom: keyboard),
        child: SafeArea(
          top: false,
          child: Container(
            color: palette.card,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: FilledButton(
              key: const Key('profileContinueButton'),
              onPressed: _submit,
              child: Text(context.l10n.continueAction),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 7),
      child,
    ],
  );
}
