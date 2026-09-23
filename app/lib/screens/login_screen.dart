/// Authentication gate for the Foloo frontend.
///
/// Includes shared language selection. Credential handling is delegated to
/// AuthRepository and is independent from product capabilities.
library;

import 'package:flutter/material.dart';

import '../auth/auth_failure_localization.dart';
import '../auth/auth_models.dart';
import '../theme/brand_theme.dart';
import '../l10n/l10n.dart';
import '../widgets/language_selector.dart';

typedef LoginRequested = Future<bool> Function(
  String username,
  String password,
);
typedef SocialLoginRequested = Future<bool> Function(AuthProvider provider);

/// Collects account credentials before entering profile and origin setup.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.onAuthenticated,
    required this.onCreateAccount,
    this.onSocialAuthenticated,
    this.authenticating = false,
    this.failure,
    this.accountConfirmed = false,
    super.key,
  });

  final LoginRequested onAuthenticated;
  final VoidCallback onCreateAccount;
  final SocialLoginRequested? onSocialAuthenticated;
  final bool authenticating;
  final AuthFailureCode? failure;
  final bool accountConfirmed;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    return value == null || value.trim().isEmpty
        ? context.l10n.loginUserRequired
        : null;
  }

  String? _validatePassword(String? value) {
    return value == null || value.trim().isEmpty
        ? context.l10n.loginPasswordRequired
        : null;
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.onAuthenticated(_email.text.trim(), _password.text);
  }

  InputDecoration _decoration(BuildContext context, {Widget? suffixIcon}) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final border = OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(17)),
      borderSide: BorderSide(color: ink.withValues(alpha: 0.5), width: 1.4),
    );
    return InputDecoration(
      filled: true,
      fillColor: theme.brightness == Brightness.dark
          ? const Color(0xFF2C2C2C)
          : FolooBrand.fieldFill,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(17)),
        borderSide: BorderSide(color: ink, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(17)),
        borderSide: BorderSide(color: FolooBrand.danger, width: 1.4),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(17)),
        borderSide: BorderSide(color: FolooBrand.danger, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardVisible = keyboardInset > 0;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      SizedBox(height: constraints.maxHeight < 650 ? 38 : 92),
                      Semantics(
                        label: 'Foloo, meet, capture, foloo',
                        image: true,
                        child: Image.asset(
                          FolooBrand.logoFor(theme.brightness, tagline: true),
                          key: const Key('loginLogo'),
                          width: 235,
                          fit: BoxFit.contain,
                        ),
                      ),
                      SizedBox(height: constraints.maxHeight < 650 ? 34 : 62),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _FieldLabel(context.l10n.loginUser),
                              const SizedBox(height: 10),
                              TextFormField(
                                key: const Key('loginEmailField'),
                                controller: _email,
                                decoration: _decoration(context),
                                keyboardType: TextInputType.emailAddress,
                                textCapitalization: TextCapitalization.none,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                validator: _validateEmail,
                              ),
                              const SizedBox(height: 26),
                              _FieldLabel(context.l10n.loginPassword),
                              const SizedBox(height: 10),
                              TextFormField(
                                key: const Key('loginPasswordField'),
                                controller: _password,
                                obscureText: _obscurePassword,
                                decoration: _decoration(
                                  context,
                                  suffixIcon: IconButton(
                                    key: const Key('passwordVisibilityButton'),
                                    tooltip: _obscurePassword
                                        ? context.l10n.loginShowPassword
                                        : context.l10n.loginHidePassword,
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: FolooBrand.gray,
                                    ),
                                  ),
                                ),
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                validator: _validatePassword,
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              if (widget.failure != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  localizedAuthFailure(
                                    context.l10n,
                                    widget.failure,
                                  ),
                                  key: const Key('authenticationError'),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (widget.accountConfirmed) ...[
                                const SizedBox(height: 10),
                                Text(
                                  context.l10n.accountConfirmed,
                                  key: const Key('accountConfirmedMessage'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(context.l10n.orContinueWith),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SocialButton(
                              key: const Key('loginGoogleButton'),
                              icon: Icons.alternate_email,
                              label: context.l10n.continueWithGoogle,
                              onPressed:
                                  widget.authenticating ||
                                      widget.onSocialAuthenticated == null
                                  ? null
                                  : () => widget.onSocialAuthenticated!(
                                      AuthProvider.google,
                                    ),
                            ),
                            const SizedBox(height: 12),
                            _SocialButton(
                              key: const Key('loginMicrosoftButton'),
                              icon: Icons.business_outlined,
                              label: context.l10n.continueWithMicrosoft,
                              onPressed:
                                  widget.authenticating ||
                                      widget.onSocialAuthenticated == null
                                  ? null
                                  : () => widget.onSocialAuthenticated!(
                                      AuthProvider.microsoft,
                                    ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Text(context.l10n.noAccountQuestion),
                                OutlinedButton.icon(
                                  key: const Key('openSignUpButton'),
                                  onPressed: widget.authenticating
                                      ? null
                                      : widget.onCreateAccount,
                                  icon: const Icon(
                                    Icons.person_add_alt_1_outlined,
                                  ),
                                  label: Text(context.l10n.createAccount),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.center,
                        child: LanguageSelector(),
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.transparent,
            border: Border(top: BorderSide(color: Color(0xFFD5D5D5))),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                28,
                16,
                28,
                keyboardVisible ? 12 : 0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('loginButton'),
                      onPressed: widget.authenticating ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(58),
                        backgroundColor: FolooBrand.lime,
                        foregroundColor: FolooBrand.ink,
                        shape: const StadiumBorder(
                          side: BorderSide(color: FolooBrand.ink, width: 1.3),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(context.l10n.loginEnter),
                          const SizedBox(width: 14),
                          const Icon(Icons.arrow_forward, size: 22),
                        ],
                      ),
                    ),
                  ),
                  if (!keyboardVisible) const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      minimumSize: const Size.fromHeight(54),
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
      shape: const StadiumBorder(),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: FolooBrand.gray,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: .2,
      ),
    );
  }
}
