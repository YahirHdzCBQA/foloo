/// Sign in with Apple button shared by Login and Create account (AUT-22).
///
/// Follows Apple's HIG: black on light themes, white on dark themes.
library;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({
    required this.onPressed,
    this.minimumHeight = 54,
    super.key,
  });

  final VoidCallback? onPressed;
  final double minimumHeight;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.apple),
      label: Text(context.l10n.continueWithApple),
      style: FilledButton.styleFrom(
        backgroundColor: dark ? Colors.white : Colors.black,
        foregroundColor: dark ? Colors.black : Colors.white,
        minimumSize: Size.fromHeight(minimumHeight),
        shape: const StadiumBorder(),
      ),
    );
  }
}
