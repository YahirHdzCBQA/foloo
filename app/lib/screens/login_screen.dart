/// Demo authentication gate for the Foloo frontend.
///
/// Includes shared language selection and the isolated development plan
/// selector; real authentication and capabilities belong to the backend.
library;

import 'package:flutter/material.dart';

import '../theme/brand_theme.dart';
import '../models/app_plan.dart';
import '../l10n/l10n.dart';
import '../widgets/language_selector.dart';
import '../widgets/segmented_bubble.dart';

/// Collects demo credentials before entering profile and origin setup.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.onAuthenticated,
    required this.selectedPlan,
    required this.onPlanChanged,
    super.key,
  });

  final VoidCallback onAuthenticated;
  final AppPlan selectedPlan;
  final ValueChanged<AppPlan> onPlanChanged;

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

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onAuthenticated();
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
                              const SizedBox(height: 22),
                              _FieldLabel(context.l10n.demoPlan),
                              const SizedBox(height: 8),
                              SegmentedBubble<AppPlan>(
                                key: const Key('demoPlanSelector'),
                                selected: widget.selectedPlan,
                                onSelected: widget.onPlanChanged,
                                options: const [
                                  SegmentedBubbleOption(
                                    key: Key('planBasic'),
                                    value: AppPlan.basic,
                                    label: 'Basic',
                                    leading: Icon(
                                      Icons.circle_outlined,
                                      size: 14,
                                    ),
                                  ),
                                  SegmentedBubbleOption(
                                    key: Key('planPro'),
                                    value: AppPlan.pro,
                                    label: 'Pro',
                                    leading: Icon(
                                      Icons.auto_awesome_outlined,
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                context.l10n.demoPlanHelp,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: FolooBrand.gray,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
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
                      onPressed: _submit,
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
                  if (!keyboardVisible)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(0, 18, 0, 14),
                      child: Text(
                        'Foloo v1.0.4 · CBQA Solutions',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: FolooBrand.gray,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
