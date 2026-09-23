/// Lead-scoped review step between durable capture and explicit email intent.
///
/// Recipient and attachments reflect the current Lead until explicit confirm;
/// the seller may adjust this concrete subject/message without mutating global
/// templates. Confirmation is the immutable send-intent boundary (SAL-01).
library;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/email_review.dart';
import '../models/session_lead.dart';
import '../theme/foloo_theme.dart';
import 'lead_confirmation_screen.dart';

/// Reviews and explicitly confirms the follow-up for the just-saved Lead.
class EmailReviewScreen extends StatefulWidget {
  const EmailReviewScreen({
    required this.record,
    required this.draft,
    required this.onConfirm,
    required this.onConnectionRequired,
    required this.onCaptureAnother,
    this.onDraftSaved,
    super.key,
  });

  final SessionLead record;
  final EmailReviewDraft draft;
  final Future<EmailReviewOutcome> Function(EmailReviewDraft draft) onConfirm;
  final VoidCallback onConnectionRequired;
  final VoidCallback onCaptureAnother;
  final Future<void> Function(EmailReviewDraft draft)? onDraftSaved;

  @override
  State<EmailReviewScreen> createState() => _EmailReviewScreenState();
}

class _EmailReviewScreenState extends State<EmailReviewScreen> {
  late final TextEditingController _subject;
  late final TextEditingController _message;
  late final TextEditingController _signature;
  final _subjectFocus = FocusNode();
  final _messageFocus = FocusNode();
  final _signatureFocus = FocusNode();
  bool _editingSubject = false;
  bool _editingMessage = false;
  bool _editingSignature = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _subject = TextEditingController(text: widget.draft.subject);
    final parts = _splitMessage(widget.draft.message);
    _message = TextEditingController(text: parts.$1);
    _signature = TextEditingController(text: parts.$2);
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    _signature.dispose();
    _subjectFocus.dispose();
    _messageFocus.dispose();
    _signatureFocus.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final subject = _subject.text.trim();
    final message = _combinedMessage;
    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.emailReviewRequired)));
      return;
    }
    setState(() => _submitting = true);
    late final EmailReviewOutcome outcome;
    try {
      outcome = await widget.onConfirm(
        widget.draft.copyWith(subject: subject, message: message),
      );
    } catch (_) {
      outcome = EmailReviewOutcome.error;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    if (outcome == EmailReviewOutcome.connectionRequired) {
      final connect = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.emailConnectionRequiredTitle),
          content: Text(context.l10n.emailConnectionRequiredBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.emailConnectAction),
            ),
          ],
        ),
      );
      if (connect == true && mounted) {
        Navigator.of(context).pop();
        widget.onConnectionRequired();
      }
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LeadConfirmationScreen(
          record: widget.record,
          emailOutcome: outcome,
          attachmentNames: widget.draft.attachmentNames,
          onCaptureAnother: widget.onCaptureAnother,
        ),
      ),
    );
  }

  Future<void> _back() async {
    final subject = _subject.text.trim();
    final message = _combinedMessage;
    final save = widget.onDraftSaved;
    if (save != null) {
      await save(widget.draft.copyWith(subject: subject, message: message));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardVisible = keyboardInset > 0;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('emailReviewBack'),
          onPressed: _back,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.emailReviewTitle),
            Text(
              widget.draft.leadName,
              style: TextStyle(
                color: palette.inkSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: GestureDetector(
        key: const Key('emailReviewDismissKeyboard'),
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            key: const Key('emailReviewScroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(context.l10n.emailReviewTo),
                _readOnly(
                  '${widget.draft.leadName} ·\n${widget.draft.recipientAddress}',
                ),
                const SizedBox(height: 22),
                _label(context.l10n.subject),
                _editableCard(
                  key: const Key('emailReviewSubject'),
                  editKey: const Key('emailReviewSubjectEdit'),
                  controller: _subject,
                  focusNode: _subjectFocus,
                  editing: _editingSubject,
                  onEdit: () => _enableEditing(_ReviewField.subject),
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                  onEditingComplete: () => _messageFocus.requestFocus(),
                ),
                const SizedBox(height: 22),
                _label(context.l10n.emailReviewMessage),
                _editableCard(
                  key: const Key('emailReviewMessage'),
                  editKey: const Key('emailReviewMessageEdit'),
                  controller: _message,
                  focusNode: _messageFocus,
                  editing: _editingMessage,
                  onEdit: () => _enableEditing(_ReviewField.message),
                  minLines: 9,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 22),
                _label(context.l10n.emailReviewSignature),
                _editableCard(
                  key: const Key('emailReviewSignature'),
                  editKey: const Key('emailReviewSignatureEdit'),
                  controller: _signature,
                  focusNode: _signatureFocus,
                  editing: _editingSignature,
                  onEdit: () => _enableEditing(_ReviewField.signature),
                  minLines: 3,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 22),
                Text(
                  context.l10n.emailAttachmentCount(
                    widget.draft.attachmentNames.length,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final name in widget.draft.attachmentNames)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(name),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 10, 20, keyboardVisible ? 8 : 14),
            color: Theme.of(context).colorScheme.surface,
            child: FilledButton(
              key: const Key('confirmFollowUpButton'),
              onPressed: _submitting ? null : _confirm,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('foloo'),
                        SizedBox.shrink(key: Key('emailReviewAdvanceIcon')),
                        Icon(Icons.arrow_forward, size: 0),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
  );

  Widget _readOnly(String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: FolooPalette.of(context).sunken,
      borderRadius: BorderRadius.circular(FolooRadii.md),
    ),
    child: Text(value),
  );

  String get _combinedMessage {
    final body = _message.text.trim();
    final signature = _signature.text.trim();
    return signature.isEmpty ? body : '$body\n\n$signature';
  }

  static (String, String) _splitMessage(String value) {
    final matches = <int>[
      value.lastIndexOf('\n\nSaludos,'),
      value.lastIndexOf('\n\nRegards,'),
      value.lastIndexOf('\n\nBest regards,'),
    ].where((index) => index >= 0).toList();
    if (matches.isEmpty) return (value.trim(), '');
    final split = matches.reduce((a, b) => a > b ? a : b);
    return (
      value.substring(0, split).trim(),
      value.substring(split + 2).trim(),
    );
  }

  void _enableEditing(_ReviewField field) {
    setState(() {
      _editingSubject = field == _ReviewField.subject;
      _editingMessage = field == _ReviewField.message;
      _editingSignature = field == _ReviewField.signature;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (field) {
        case _ReviewField.subject:
          _subjectFocus.requestFocus();
        case _ReviewField.message:
          _messageFocus.requestFocus();
        case _ReviewField.signature:
          _signatureFocus.requestFocus();
      }
    });
  }

  Widget _editableCard({
    required Key key,
    required Key editKey,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool editing,
    required VoidCallback onEdit,
    int? minLines,
    int? maxLines,
    TextInputAction? textInputAction,
    VoidCallback? onEditingComplete,
  }) => Container(
    decoration: BoxDecoration(
      color: FolooPalette.of(context).sunken,
      borderRadius: BorderRadius.circular(FolooRadii.md),
      border: editing
          ? Border.all(color: FolooPalette.of(context).ink, width: 2)
          : null,
    ),
    child: Stack(
      children: [
        TextField(
          key: key,
          controller: controller,
          focusNode: focusNode,
          readOnly: !editing,
          showCursor: editing,
          enableInteractiveSelection: editing,
          minLines: minLines,
          maxLines: maxLines,
          textInputAction: textInputAction,
          onEditingComplete: onEditingComplete,
          onTapOutside: (_) => focusNode.unfocus(),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.fromLTRB(16, 16, 54, 16),
          ),
        ),
        if (!editing)
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filled(
              key: editKey,
              tooltip: context.l10n.edit,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
          ),
      ],
    ),
  );
}

enum _ReviewField { subject, message, signature }
