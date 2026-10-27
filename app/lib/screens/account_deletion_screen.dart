/// Irreversible Account Deletion flow for settings/profile (AUT-18–AUT-21).
///
/// The screen is reachable only through the disabled-by-default STORE-02 flag;
/// tests inject a synthetic service until the secured backend is activated.
library;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../l10n/l10n.dart';
import '../services/account_deletion_service.dart';
import '../theme/foloo_theme.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({
    required this.ownerSub,
    required this.service,
    required this.onExport,
    required this.onSynchronize,
    required this.pendingSyncCount,
    required this.onReauthenticate,
    required this.onAccepted,
    this.prepareImmediately = false,
    super.key,
  });

  final String ownerSub;
  final AccountDeletionService service;
  final Future<void> Function() onExport;
  final Future<void> Function() onSynchronize;
  final Future<int> Function() pendingSyncCount;
  final Future<void> Function() onReauthenticate;
  final Future<void> Function(AccountDeletionAccepted accepted) onAccepted;
  final bool prepareImmediately;

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  AccountDeletionPreflight? _preflight;
  bool _busy = false;
  bool _irreversible = false;
  bool _discardUnsynced = false;
  bool _cancelRenewal = false;
  String? _error;
  String? _confirmationIdempotencyKey;

  @override
  void initState() {
    super.initState();
    if (widget.prepareImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
    }
  }

  Future<void> _prepare() async {
    final locale = Localizations.localeOf(context).languageCode == 'en'
        ? 'en'
        : 'es';
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await widget.service.hasRecentAuthentication(widget.ownerSub)) {
        throw const AccountDeletionServiceException(
          'reauthentication_required',
        );
      }
      final result = await widget.service.createPreflight(
        ownerSub: widget.ownerSub,
        locale: locale,
        requestedExport: false,
        idempotencyKey: const Uuid().v4(),
      );
      final localPending = await widget.pendingSyncCount();
      if (mounted) {
        _confirmationIdempotencyKey ??= const Uuid().v4();
        setState(
          () => _preflight = AccountDeletionPreflight(
            requestId: result.requestId,
            pendingSyncCount: localPending > result.pendingSyncCount
                ? localPending
                : result.pendingSyncCount,
            exportAvailable: result.exportAvailable,
            subscriptionCancellationRequired:
                result.subscriptionCancellationRequired,
          ),
        );
      }
    } on AccountDeletionServiceException catch (error) {
      if (mounted) setState(() => _error = error.code);
    } catch (_) {
      if (mounted) setState(() => _error = 'network');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final preflight = _preflight;
    final idempotencyKey = _confirmationIdempotencyKey;
    if (preflight == null || idempotencyKey == null || !_irreversible) return;
    if (preflight.pendingSyncCount > 0 && !_discardUnsynced) return;
    if (preflight.subscriptionCancellationRequired && !_cancelRenewal) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final accepted = await widget.service.confirm(
        ownerSub: widget.ownerSub,
        requestId: preflight.requestId,
        discardUnsyncedAccepted: _discardUnsynced,
        cancelRenewalAccepted: _cancelRenewal,
        idempotencyKey: idempotencyKey,
      );
      await widget.onAccepted(accepted);
    } on AccountDeletionServiceException catch (error) {
      if (mounted) setState(() => _error = error.code);
    } catch (_) {
      if (mounted) setState(() => _error = 'network');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preflight = _preflight;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountDeletionTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              Icons.delete_forever_outlined,
              size: 52,
              color: FolooPalette.of(context).error,
            ),
            const SizedBox(height: 20),
            Text(
              l10n.accountDeletionWarning,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            Text(l10n.accountDeletionConsequences),
            const SizedBox(height: 12),
            Text(l10n.accountDeletionNewAccountNotice),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const Key('accountDeletionExport'),
              onPressed: _busy ? null : widget.onExport,
              icon: const Icon(Icons.download_outlined),
              label: Text(l10n.accountDeletionExport),
            ),
            if (preflight == null) ...[
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('accountDeletionPrepare'),
                onPressed: _busy ? null : _prepare,
                child: Text(l10n.continueAction),
              ),
            ] else ...[
              if (preflight.pendingSyncCount > 0) ...[
                const SizedBox(height: 20),
                Text(
                  l10n.accountDeletionPendingSync(preflight.pendingSyncCount),
                ),
                TextButton.icon(
                  key: const Key('accountDeletionSync'),
                  onPressed: _busy ? null : widget.onSynchronize,
                  icon: const Icon(Icons.sync),
                  label: Text(l10n.accountDeletionSyncFirst),
                ),
                CheckboxListTile(
                  key: const Key('accountDeletionDiscardUnsynced'),
                  value: _discardUnsynced,
                  onChanged: _busy
                      ? null
                      : (value) =>
                            setState(() => _discardUnsynced = value ?? false),
                  title: Text(l10n.accountDeletionDiscardUnsynced),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              if (preflight.subscriptionCancellationRequired)
                CheckboxListTile(
                  key: const Key('accountDeletionCancelRenewal'),
                  value: _cancelRenewal,
                  onChanged: _busy
                      ? null
                      : (value) =>
                            setState(() => _cancelRenewal = value ?? false),
                  title: Text(l10n.accountDeletionCancelRenewal),
                  contentPadding: EdgeInsets.zero,
                ),
              CheckboxListTile(
                key: const Key('accountDeletionIrreversible'),
                value: _irreversible,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _irreversible = value ?? false),
                title: Text(l10n.accountDeletionIrreversible),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('accountDeletionConfirm'),
                onPressed: _canConfirm && !_busy ? _confirm : null,
                style: FilledButton.styleFrom(
                  backgroundColor: FolooPalette.of(context).error,
                ),
                child: Text(l10n.accountDeletionConfirm),
              ),
            ],
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _requiresReauthentication
                      ? l10n.accountDeletionReauthenticate
                      : l10n.accountDeletionError,
                  key: const Key('accountDeletionError'),
                  style: TextStyle(color: FolooPalette.of(context).error),
                ),
              ),
            if (_requiresReauthentication)
              TextButton(
                key: const Key('accountDeletionReauthenticate'),
                onPressed: _busy ? null : widget.onReauthenticate,
                child: Text(l10n.accountDeletionSignInAgain),
              ),
          ],
        ),
      ),
    );
  }

  bool get _canConfirm {
    final preflight = _preflight;
    if (preflight == null || !_irreversible) return false;
    if (preflight.pendingSyncCount > 0 && !_discardUnsynced) return false;
    if (preflight.subscriptionCancellationRequired && !_cancelRenewal) {
      return false;
    }
    return true;
  }

  bool get _requiresReauthentication =>
      _error == 'reauthentication_required' ||
      _error == 'unauthenticated' ||
      _error == 'session';
}
