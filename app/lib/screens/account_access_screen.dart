/// Foloo-styled self sign-up and email confirmation screens (AUT-10/AUT-11).
library;

import 'package:flutter/material.dart';

import '../auth/auth_failure_localization.dart';
import '../auth/auth_models.dart';
import '../l10n/l10n.dart';
import '../theme/brand_theme.dart';
import '../widgets/language_selector.dart';

typedef SignUpRequested = Future<void> Function(String email, String password);
typedef ConfirmationRequested = Future<void> Function(String code);
typedef ResendCodeRequested = Future<bool> Function();

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({
    required this.onSubmit,
    required this.onBack,
    required this.busy,
    this.failure,
    super.key,
  });

  final SignUpRequested onSubmit;
  final VoidCallback onBack;
  final bool busy;
  final AuthFailureCode? failure;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.onSubmit(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
    title: context.l10n.createAccountTitle,
    help: context.l10n.createAccountHelp,
    primaryLabel: context.l10n.createAccount,
    primaryKey: const Key('signUpButton'),
    onPrimary: widget.busy ? null : _submit,
    onBack: widget.onBack,
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(context.l10n.loginUser),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('signUpEmailField'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.newUsername],
            textInputAction: TextInputAction.next,
            decoration: _fieldDecoration(context),
            validator: (value) =>
                value == null || value.trim().isEmpty || !value.contains('@')
                ? context.l10n.loginUserRequired
                : null,
          ),
          const SizedBox(height: 20),
          _label(context.l10n.loginPassword),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('signUpPasswordField'),
            controller: _password,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: _fieldDecoration(
              context,
              suffixIcon: IconButton(
                tooltip: _obscure
                    ? context.l10n.loginShowPassword
                    : context.l10n.loginHidePassword,
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) => value == null || value.isEmpty
                ? context.l10n.loginPasswordRequired
                : null,
          ),
          if (widget.failure != null) ...[
            const SizedBox(height: 12),
            _error(context, widget.failure),
          ],
        ],
      ),
    ),
  );
}

class ConfirmSignUpScreen extends StatefulWidget {
  const ConfirmSignUpScreen({
    required this.email,
    required this.onSubmit,
    required this.onResend,
    required this.onBack,
    required this.busy,
    this.failure,
    super.key,
  });

  final String email;
  final ConfirmationRequested onSubmit;
  final ResendCodeRequested onResend;
  final VoidCallback onBack;
  final bool busy;
  final AuthFailureCode? failure;

  @override
  State<ConfirmSignUpScreen> createState() => _ConfirmSignUpScreenState();
}

class _ConfirmSignUpScreenState extends State<ConfirmSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _resent = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.onSubmit(_code.text);
  }

  Future<void> _resend() async {
    final sent = await widget.onResend();
    if (mounted) setState(() => _resent = sent);
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
    title: context.l10n.confirmAccountTitle,
    help: '${context.l10n.confirmAccountHelp}\n${widget.email}',
    primaryLabel: context.l10n.confirmAccount,
    primaryKey: const Key('confirmSignUpButton'),
    onPrimary: widget.busy ? null : _submit,
    onBack: widget.onBack,
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(context.l10n.confirmationCode),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('confirmationCodeField'),
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            textInputAction: TextInputAction.done,
            decoration: _fieldDecoration(context),
            validator: (value) => value == null || value.trim().isEmpty
                ? context.l10n.confirmationCodeRequired
                : null,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (widget.failure != null) ...[
            const SizedBox(height: 12),
            _error(context, widget.failure),
          ],
          if (_resent) ...[
            const SizedBox(height: 12),
            Text(
              context.l10n.confirmationCodeResent,
              key: const Key('codeResentMessage'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 16),
          TextButton(
            key: const Key('resendCodeButton'),
            onPressed: widget.busy ? null : _resend,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            child: Text(context.l10n.resendCode),
          ),
        ],
      ),
    ),
  );
}

class _AuthFrame extends StatelessWidget {
  const _AuthFrame({
    required this.title,
    required this.help,
    required this.primaryLabel,
    required this.primaryKey,
    required this.onPrimary,
    required this.onBack,
    required this.child,
  });

  final String title;
  final String help;
  final String primaryLabel;
  final Key primaryKey;
  final VoidCallback? onPrimary;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    key: const Key('authBackButton'),
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Spacer(),
                  const LanguageSelector(),
                ],
              ),
              const SizedBox(height: 28),
              Image.asset(
                FolooBrand.logoFor(theme.brightness),
                height: 28,
                alignment: Alignment.centerLeft,
              ),
              const SizedBox(height: 34),
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(help, style: const TextStyle(color: FolooBrand.gray)),
              const SizedBox(height: 34),
              child,
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
          child: FilledButton(
            key: primaryKey,
            onPressed: onPrimary,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: FolooBrand.lime,
              foregroundColor: FolooBrand.ink,
            ),
            child: Text(primaryLabel),
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(BuildContext context, {Widget? suffixIcon}) {
  final ink = Theme.of(context).colorScheme.onSurface;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(17),
    borderSide: BorderSide(color: ink.withValues(alpha: .5), width: 1.4),
  );
  return InputDecoration(
    filled: true,
    fillColor: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2C2C2C)
        : FolooBrand.fieldFill,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: ink, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
    suffixIcon: suffixIcon,
  );
}

Widget _label(String value) => Text(
  value,
  style: const TextStyle(
    color: FolooBrand.gray,
    fontSize: 11,
    fontWeight: FontWeight.w800,
  ),
);

Widget _error(BuildContext context, AuthFailureCode? failure) => Text(
  localizedAuthFailure(context.l10n, failure),
  key: const Key('authenticationError'),
  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
);
