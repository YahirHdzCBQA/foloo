/// Optional, owner-scoped sending-account step shown after seller profile setup.
///
/// Cognito remains the Foloo account identity. This screen only reads the
/// backend-authoritative Google/Microsoft sending connection (SAL-08/SAL-09).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/email_connection_service.dart';
import '../theme/brand_theme.dart';
import '../theme/foloo_theme.dart';

/// Lets a new user connect a sender or explicitly defer that optional setup.
class EmailOnboardingScreen extends StatefulWidget {
  const EmailOnboardingScreen({
    required this.ownerSub,
    required this.onComplete,
    this.connectionService,
    super.key,
  });

  final String ownerSub;
  final EmailConnectionService? connectionService;
  final Future<void> Function(bool skipped) onComplete;

  @override
  State<EmailOnboardingScreen> createState() => _EmailOnboardingScreenState();
}

class _EmailOnboardingScreenState extends State<EmailOnboardingScreen>
    with WidgetsBindingObserver {
  EmailConnectionView? _connection;
  bool _busy = false;
  bool _launchedAuthorization = false;
  bool _statusUnavailable = false;
  int _requestGeneration = 0;

  bool get _connected => _connection?.status == 'connected';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(covariant EmailOnboardingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerSub != widget.ownerSub ||
        oldWidget.connectionService != widget.connectionService) {
      _connection = null;
      unawaited(_refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final service = widget.connectionService;
    if (service == null) return;
    final generation = ++_requestGeneration;
    if (mounted) setState(() => _busy = true);
    try {
      final connection = await service.status(widget.ownerSub);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _connection = connection;
        _statusUnavailable = false;
      });
    } on Object {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _connection = null;
        _statusUnavailable = true;
      });
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _connect(String provider) async {
    final service = widget.connectionService;
    if (service == null || _busy) return;
    setState(() {
      _busy = true;
      _statusUnavailable = false;
    });
    try {
      final launched = await service.connect(widget.ownerSub, provider);
      if (mounted) setState(() => _launchedAuthorization = launched);
    } on Object {
      if (mounted) setState(() => _statusUnavailable = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _requestGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    return Scaffold(
      key: const Key('emailOnboardingScreen'),
      backgroundColor: palette.card,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 52,
              ),
              child: IntrinsicHeight(
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
                    const SizedBox(height: 34),
                    Text(
                      context.l10n.emailOnboardingTitle,
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.emailOnboardingHelp,
                      style: TextStyle(
                        color: palette.inkSecondary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (_connected)
                      _ConnectedAccountCard(connection: _connection!)
                    else ...[
                      OutlinedButton.icon(
                        key: const Key('emailOnboardingGoogleButton'),
                        onPressed: _busy ? null : () => _connect('google'),
                        icon: const Icon(Icons.alternate_email),
                        label: Text(context.l10n.emailOnboardingGoogle),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('emailOnboardingMicrosoftButton'),
                        onPressed: _busy ? null : () => _connect('microsoft'),
                        icon: const Icon(Icons.business_outlined),
                        label: Text(context.l10n.emailOnboardingMicrosoft),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: palette.paper,
                          borderRadius: BorderRadius.circular(FolooRadii.md),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              color: palette.inkSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                context.l10n.emailOnboardingPrivacy,
                                style: TextStyle(color: palette.inkSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_busy) ...[
                      const SizedBox(height: 18),
                      const Center(child: CircularProgressIndicator()),
                    ],
                    if (_launchedAuthorization && !_connected) ...[
                      const SizedBox(height: 18),
                      Text(
                        context.l10n.emailOnboardingWaiting,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.inkSecondary),
                      ),
                    ],
                    if (_statusUnavailable) ...[
                      const SizedBox(height: 14),
                      Text(
                        context.l10n.emailConnectionUnavailable,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.inkSecondary),
                      ),
                    ],
                    const Spacer(),
                    if (_connected)
                      FilledButton(
                        key: const Key('emailOnboardingContinueButton'),
                        onPressed: _busy
                            ? null
                            : () => widget.onComplete(false),
                        child: Text(context.l10n.emailOnboardingContinue),
                      )
                    else
                      TextButton(
                        key: const Key('emailOnboardingSkipButton'),
                        onPressed: _busy ? null : () => widget.onComplete(true),
                        child: Text(context.l10n.emailOnboardingLater),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectedAccountCard extends StatelessWidget {
  const _ConnectedAccountCard({required this.connection});

  final EmailConnectionView connection;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final provider = connection.provider == 'microsoft'
        ? 'Microsoft'
        : 'Google';
    return Container(
      key: const Key('emailOnboardingConnectedAccount'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(FolooRadii.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(connection.senderAddress),
                const SizedBox(height: 2),
                Text(
                  context.l10n.emailConnectionConnected,
                  style: TextStyle(color: palette.inkSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
