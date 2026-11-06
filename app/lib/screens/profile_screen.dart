/// Authenticated profile editor for the current Foloo owner.
///
/// It edits the durable local seller profile, keeps the Cognito sign-in email
/// read-only, and surfaces the separate follow-up sender connection (AUT-05,
/// SAL-04). Account deletion remains delegated to the STORE-02D workflow.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/l10n.dart';
import '../data/repositories/local_repositories.dart';
import '../models/app_event.dart';
import '../services/camera_access_service.dart';
import '../services/email_connection_service.dart';
import '../services/image_capture_service.dart';
import '../theme/foloo_theme.dart';
import '../widgets/camera_access_dialog.dart';
import '../widgets/entitlement_scope.dart';
import '../models/entitlement.dart';

/// Edits the current owner's profile without conflating authentication and
/// follow-up sender identities.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.profile,
    required this.accountEmail,
    required this.ownerSub,
    required this.onSave,
    required this.onLogout,
    required this.onDeleteAccount,
    required this.accountDeletionEnabled,
    this.connectionService,
    this.deliveryRepository,
    this.cameraAccessCoordinator,
    this.imageCaptureService,
    super.key,
  });

  final DemoProfile profile;
  final String accountEmail;
  final String ownerSub;
  final Future<DemoProfile?> Function(DemoProfile profile) onSave;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;
  final bool accountDeletionEnabled;
  final EmailConnectionService? connectionService;
  final EmailDeliveryRepository? deliveryRepository;
  final CameraAccessCoordinator? cameraAccessCoordinator;
  final ImageCaptureService? imageCaptureService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _company;
  late final CameraAccessCoordinator _cameraAccess;
  late final ImageCaptureService _imageCapture;
  late DemoProfile _savedProfile;
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoPath;
  EmailConnectionView? _connection;
  bool _connectionBusy = false;
  bool _connectionCheckFailed = false;
  bool _saving = false;
  bool _allowPop = false;

  bool get _dirty =>
      _name.text.trim() != _savedProfile.name ||
      _company.text.trim() != _savedProfile.company ||
      (_selectedPhotoPath != null &&
          _selectedPhotoPath != _savedProfile.photoLocalPath);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _savedProfile = widget.profile;
    _name = TextEditingController(text: widget.profile.name)
      ..addListener(_refreshDirtyState);
    _company = TextEditingController(text: widget.profile.company)
      ..addListener(_refreshDirtyState);
    _cameraAccess = widget.cameraAccessCoordinator ?? CameraAccessCoordinator();
    _imageCapture = widget.imageCaptureService ?? DeviceImageCaptureService();
    unawaited(_loadConnection());
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostImage());
  }

  void _refreshDirtyState() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_cameraAccess.revalidateAfterSettings());
      unawaited(_loadConnection());
    }
  }

  Future<void> _loadConnection() async {
    final service = widget.connectionService;
    if (mounted) setState(() => _connectionBusy = true);
    final cached = await widget.deliveryRepository?.connection(widget.ownerSub);
    EmailConnectionView? connection;
    var checkFailed = false;
    try {
      connection = await service?.status(widget.ownerSub);
      if (connection != null) {
        await widget.deliveryRepository?.saveConnection(
          owner: widget.ownerSub,
          connectionId: connection.id,
          provider: connection.provider,
          senderAddress: connection.senderAddress,
          status: connection.status,
        );
      } else if (cached != null) {
        connection = EmailConnectionView(
          id: cached.connectionId,
          provider: cached.provider,
          senderAddress: cached.senderAddress,
          status: cached.status == 'disconnected'
              ? 'disconnected'
              : 'reconnect_required',
        );
      }
    } on Object {
      checkFailed = true;
      if (cached != null) {
        connection = EmailConnectionView(
          id: cached.connectionId,
          provider: cached.provider,
          senderAddress: cached.senderAddress,
          status: 'reconnect_required',
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _connection = connection;
      _connectionBusy = false;
      _connectionCheckFailed = checkFailed;
    });
  }

  Future<void> _chooseEmailProvider() async {
    final provider = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.profileFollowUpChooseProvider,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              ListTile(
                key: const Key('profileConnectGoogle'),
                leading: const Icon(Icons.mail_outline),
                title: const Text('Google'),
                onTap: () => Navigator.pop(sheetContext, 'google'),
              ),
              ListTile(
                key: const Key('profileConnectMicrosoft'),
                leading: const Icon(Icons.mail_outline),
                title: const Text('Microsoft'),
                onTap: () => Navigator.pop(sheetContext, 'microsoft'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (provider != null && mounted) await _connect(provider);
  }

  Future<void> _confirmDisconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.profileFollowUpDisconnectTitle),
        content: Text(context.l10n.profileFollowUpDisconnectHelp),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const Key('profileConfirmDisconnect'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.emailConnectionDisconnect),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _disconnect();
  }

  Future<void> _connect(String provider) async {
    final service = widget.connectionService;
    if (service == null) return;
    setState(() => _connectionBusy = true);
    try {
      await service.connect(widget.ownerSub, provider);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.emailConnectionUnavailable)),
        );
      }
    } finally {
      if (mounted) setState(() => _connectionBusy = false);
    }
  }

  Future<void> _disconnect() async {
    final service = widget.connectionService;
    if (service == null) return;
    final connection = _connection;
    setState(() => _connectionBusy = true);
    try {
      await service.disconnect(widget.ownerSub);
      if (connection != null) {
        await widget.deliveryRepository?.saveConnection(
          owner: widget.ownerSub,
          connectionId: connection.id,
          provider: connection.provider,
          senderAddress: connection.senderAddress,
          status: 'disconnected',
        );
      }
      await _loadConnection();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.emailConnectionUnavailable)),
        );
      }
    } finally {
      if (mounted) setState(() => _connectionBusy = false);
    }
  }

  Future<void> _showPhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.profileEditPhoto,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              ListTile(
                key: const Key('profileTakePhotoOption'),
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(context.l10n.profileTakePhoto),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                key: const Key('profileGalleryOption'),
                leading: const Icon(Icons.photo_outlined),
                title: Text(context.l10n.profileGallery),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  Future<void> _pickPhoto(ImageSource source) async {
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
      if (!mounted || image == null) return;
      setState(() {
        _selectedPhotoBytes = image.bytes;
        _selectedPhotoPath = image.path;
      });
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
      if (!mounted || image == null) return;
      setState(() {
        _selectedPhotoBytes = image.bytes;
        _selectedPhotoPath = image.path;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(imageCaptureFailureMessage(context, error))),
      );
    }
  }

  Future<bool> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return false;
    setState(() => _saving = true);
    final profile = DemoProfile(
      name: _name.text.trim(),
      company: _company.text.trim(),
      photoLocalPath: _selectedPhotoPath ?? _savedProfile.photoLocalPath,
    );
    final savedProfile = await widget.onSave(profile);
    final saved = savedProfile != null;
    if (!mounted) return saved;
    setState(() {
      _saving = false;
      if (saved) {
        _savedProfile = savedProfile;
        _selectedPhotoPath = null;
        _selectedPhotoBytes = null;
      }
    });
    if (saved) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.profileSaved)));
    }
    return saved;
  }

  Future<void> _requestExit() async {
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    final action = await showDialog<_ExitAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.profileUnsavedTitle),
        actions: [
          TextButton(
            key: const Key('profileKeepEditingButton'),
            onPressed: () => Navigator.pop(context, _ExitAction.keepEditing),
            child: Text(context.l10n.profileKeepEditing),
          ),
          TextButton(
            key: const Key('profileDiscardButton'),
            onPressed: () => Navigator.pop(context, _ExitAction.discard),
            child: Text(context.l10n.profileDiscardChanges),
          ),
          FilledButton(
            key: const Key('profileSaveExitButton'),
            onPressed: () => Navigator.pop(context, _ExitAction.save),
            child: Text(context.l10n.profileSaveAndExit),
          ),
        ],
      ),
    );
    if (!mounted || action == null || action == _ExitAction.keepEditing) return;
    if (action == _ExitAction.save && !await _save()) return;
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  ImageProvider<Object>? get _profileImage {
    if (_selectedPhotoBytes != null) return MemoryImage(_selectedPhotoBytes!);
    final path = _savedProfile.photoLocalPath;
    return path != null && File(path).existsSync()
        ? FileImage(File(path))
        : null;
  }

  String get _initials => _name.text
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _name.dispose();
    _company.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final image = _profileImage;
    final entitlement = EntitlementScope.maybeOf(context);
    return PopScope(
      canPop: _allowPop || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_requestExit());
      },
      child: Scaffold(
        key: const Key('profileEditScreen'),
        backgroundColor: palette.card,
        appBar: AppBar(
          backgroundColor: palette.card,
          surfaceTintColor: Colors.transparent,
          leadingWidth: 72,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: IconButton.filled(
              key: const Key('profileBackButton'),
              onPressed: _requestExit,
              style: IconButton.styleFrom(
                backgroundColor: FolooColors.lime,
                foregroundColor: FolooColors.ink,
              ),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          title: Text(
            context.l10n.profileEditTitle,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (entitlement != null) ...[
                  DecoratedBox(
                    key: const Key('profileEntitlement'),
                    decoration: BoxDecoration(
                      color: palette.paper,
                      borderRadius: BorderRadius.circular(FolooRadii.sm),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entitlement.effectiveStatus ==
                                      SubscriptionStatus.active
                                  ? context.l10n.planPro
                                  : '${context.l10n.planFree} · ${context.l10n.historicalLeadUsage(entitlement.trialLeadsUsed)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                InkWell(
                  key: const Key('profilePhotoButton'),
                  onTap: _showPhotoSource,
                  borderRadius: BorderRadius.circular(FolooRadii.md),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              key: const Key('profileEditAvatar'),
                              radius: 46,
                              backgroundColor: palette.paper,
                              backgroundImage: image,
                              child: image == null
                                  ? Text(
                                      _initials,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                                  : null,
                            ),
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: palette.ink,
                              foregroundColor: palette.card,
                              child: const Icon(
                                Icons.photo_camera_outlined,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.profilePhoto,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                context.l10n.profileEditPhotoHelp,
                                style: TextStyle(color: palette.inkSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _ProfileInput(
                  label: context.l10n.profileFullName,
                  child: TextFormField(
                    key: const Key('profileEditNameField'),
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? context.l10n.nameRequired
                        : null,
                  ),
                ),
                const SizedBox(height: 18),
                _ProfileInput(
                  label: context.l10n.company,
                  child: TextFormField(
                    key: const Key('profileEditCompanyField'),
                    controller: _company,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.organizationName],
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? context.l10n.companyRequired
                        : null,
                  ),
                ),
                const SizedBox(height: 18),
                _ProfileInput(
                  label: context.l10n.profileAccountEmail,
                  child: TextFormField(
                    key: const Key('profileAccountEmailField'),
                    initialValue: widget.accountEmail,
                    readOnly: true,
                    decoration: const InputDecoration(
                      suffixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  context.l10n.profileAccountEmailHelp,
                  style: TextStyle(color: palette.inkSecondary, fontSize: 12),
                ),
                const SizedBox(height: 22),
                Text(
                  context.l10n.profileFollowUpEmail,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 9),
                _FollowUpEmailCard(
                  connection: _connection,
                  busy: _connectionBusy,
                  enabled: widget.connectionService != null,
                  checkFailed: _connectionCheckFailed,
                  onConnect: _chooseEmailProvider,
                  onDisconnect: _confirmDisconnect,
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  key: const Key('profileLogoutButton'),
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout),
                  label: Text(context.l10n.drawerLogout),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    foregroundColor: palette.ink,
                    shape: const StadiumBorder(),
                  ),
                ),
                if (widget.accountDeletionEnabled) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('profileDeleteAccountButton'),
                    onPressed: widget.onDeleteAccount,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(context.l10n.accountDeletionMenu),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: palette.ink,
                      foregroundColor: palette.card,
                      shape: const StadiumBorder(),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    context.l10n.profileDeleteHelp,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.inkSecondary, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: FilledButton(
            key: const Key('profileSaveButton'),
            onPressed: _saving || !_dirty ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              backgroundColor: palette.ink,
              foregroundColor: palette.card,
              disabledBackgroundColor: palette.ink.withValues(alpha: 0.35),
              shape: const StadiumBorder(),
            ),
            child: _saving
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    context.l10n.profileSaveChanges,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

enum _ExitAction { save, discard, keepEditing }

class _ProfileInput extends StatelessWidget {
  const _ProfileInput({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      child,
    ],
  );
}

class _FollowUpEmailCard extends StatelessWidget {
  const _FollowUpEmailCard({
    required this.connection,
    required this.busy,
    required this.enabled,
    required this.checkFailed,
    required this.onConnect,
    required this.onDisconnect,
  });

  final EmailConnectionView? connection;
  final bool busy;
  final bool enabled;
  final bool checkFailed;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final connected = connection?.status == 'connected';
    final disconnected = connection != null && !connected;
    final background = connected
        ? palette.successTint
        : disconnected
        ? palette.pendingTint
        : palette.errorTint;
    final foreground = connected
        ? palette.success
        : disconnected
        ? palette.pending
        : palette.error;
    final title = connected
        ? context.l10n.profileFollowUpConnected
        : disconnected
        ? context.l10n.profileFollowUpDisconnected
        : context.l10n.profileFollowUpUnconfigured;
    final help = disconnected
        ? context.l10n.profileFollowUpDisconnectedHelp
        : context.l10n.profileFollowUpUnconfiguredHelp;
    return Container(
      key: const Key('profileFollowUpEmailCard'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(FolooRadii.md),
        border: Border.all(color: foreground.withValues(alpha: 0.24)),
      ),
      child: busy
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: palette.card,
                      foregroundColor: foreground,
                      child: Icon(
                        connected
                            ? Icons.check_circle_outline
                            : disconnected
                            ? Icons.warning_amber_rounded
                            : Icons.mark_email_unread_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            key: const Key('profileFollowUpEmailStatus'),
                            style: TextStyle(
                              color: foreground,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (connected) ...[
                            const SizedBox(height: 4),
                            Text(
                              connection!.senderAddress,
                              key: const Key('profileFollowUpEmailAddress'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              connection!.provider == 'microsoft'
                                  ? 'Microsoft'
                                  : 'Google',
                              style: TextStyle(
                                color: palette.inkSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 4),
                            Text(
                              checkFailed
                                  ? context.l10n.emailConnectionUnavailable
                                  : help,
                              style: TextStyle(
                                color: palette.inkSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (connected)
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        key: const Key('profileChangeEmailAccount'),
                        onPressed: enabled ? onConnect : null,
                        child: Text(context.l10n.emailChangeAccount),
                      ),
                      TextButton(
                        key: const Key('profileDisconnectEmailAccount'),
                        onPressed: enabled ? onDisconnect : null,
                        child: Text(context.l10n.emailConnectionDisconnect),
                      ),
                    ],
                  )
                else
                  FilledButton(
                    key: const Key('profileConnectEmailAccount'),
                    onPressed: enabled ? onConnect : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: foreground,
                      foregroundColor: palette.card,
                    ),
                    child: Text(context.l10n.profileFollowUpConnect),
                  ),
              ],
            ),
    );
  }
}
