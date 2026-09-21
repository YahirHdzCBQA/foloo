/// Lead-scoped review step between durable capture and explicit email intent.
///
/// Recipient and frozen attachments remain immutable; the seller may adjust
/// only this concrete subject/message without mutating global templates.
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
    super.key,
  });

  final SessionLead record;
  final EmailReviewDraft draft;
  final Future<EmailReviewOutcome> Function(EmailReviewDraft draft) onConfirm;
  final VoidCallback onConnectionRequired;
  final VoidCallback onCaptureAnother;

  @override
  State<EmailReviewScreen> createState() => _EmailReviewScreenState();
}

class _EmailReviewScreenState extends State<EmailReviewScreen> {
  late final TextEditingController _subject;
  late final TextEditingController _message;
  final _subjectFocus = FocusNode();
  final _messageFocus = FocusNode();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _subject = TextEditingController(text: widget.draft.subject);
    _message = TextEditingController(text: widget.draft.message);
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    _subjectFocus.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final subject = _subject.text.trim();
    final message = _message.text.trim();
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

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardVisible = keyboardInset > 0;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('emailReviewBack'),
          onPressed: () => Navigator.pop(context),
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
                _field(
                  key: const Key('emailReviewSubject'),
                  controller: _subject,
                  focusNode: _subjectFocus,
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                  onEditingComplete: () => _messageFocus.requestFocus(),
                ),
                const SizedBox(height: 22),
                _label(context.l10n.emailReviewMessage),
                _field(
                  key: const Key('emailReviewMessage'),
                  controller: _message,
                  focusNode: _messageFocus,
                  minLines: 9,
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
                  : const Text('foloo'),
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

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required FocusNode focusNode,
    int? minLines,
    int? maxLines,
    TextInputAction? textInputAction,
    VoidCallback? onEditingComplete,
  }) => TextField(
    key: key,
    controller: controller,
    focusNode: focusNode,
    minLines: minLines,
    maxLines: maxLines,
    textInputAction: textInputAction,
    onEditingComplete: onEditingComplete,
    onTapOutside: (_) => focusNode.unfocus(),
    decoration: const InputDecoration(border: InputBorder.none),
  );
}
