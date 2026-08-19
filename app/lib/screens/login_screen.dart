import 'package:flutter/material.dart';

import '../theme/brand_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.onAuthenticated, super.key});

  final VoidCallback onAuthenticated;

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
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Escribe tu usuario o correo';
    final isValid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    return isValid ? null : 'Escribe un correo válido';
  }

  String? _validatePassword(String? value) {
    return value == null || value.trim().isEmpty
        ? 'Escribe tu contraseña'
        : null;
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onAuthenticated();
  }

  InputDecoration _decoration({Widget? suffixIcon}) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(17)),
      borderSide: BorderSide(color: FolooBrand.gray, width: 1.4),
    );
    return InputDecoration(
      filled: true,
      fillColor: FolooBrand.fieldFill,
      border: border,
      enabledBorder: border,
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(17)),
        borderSide: BorderSide(color: FolooBrand.ink, width: 2),
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
    return Scaffold(
      backgroundColor: Colors.white,
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
                          FolooBrand.logoWithTagline,
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
                              const _FieldLabel('USUARIO / CORREO'),
                              const SizedBox(height: 10),
                              TextFormField(
                                key: const Key('loginEmailField'),
                                controller: _email,
                                decoration: _decoration(),
                                keyboardType: TextInputType.emailAddress,
                                textCapitalization: TextCapitalization.none,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                validator: _validateEmail,
                              ),
                              const SizedBox(height: 26),
                              const _FieldLabel('CONTRASEÑA'),
                              const SizedBox(height: 10),
                              TextFormField(
                                key: const Key('loginPasswordField'),
                                controller: _password,
                                obscureText: _obscurePassword,
                                decoration: _decoration(
                                  suffixIcon: IconButton(
                                    key: const Key('passwordVisibilityButton'),
                                    tooltip: _obscurePassword
                                        ? 'Mostrar contraseña'
                                        : 'Ocultar contraseña',
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
                            ],
                          ),
                        ),
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
            color: Colors.white,
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
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Entrar'),
                          SizedBox(width: 14),
                          Icon(Icons.arrow_forward, size: 22),
                        ],
                      ),
                    ),
                  ),
                  if (!keyboardVisible)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(0, 18, 0, 14),
                      child: Text(
                        'FOLOO v1.0.0 · CBQA SOLUTIONS',
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
        letterSpacing: 1.4,
      ),
    );
  }
}
