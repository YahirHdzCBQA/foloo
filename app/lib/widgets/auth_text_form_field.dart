/// Shared text input for Foloo authentication and first-profile flows.
///
/// It owns the visual states of these forms and uses Flutter's adaptive text
/// toolbar to avoid the iOS native context-menu race between adjacent fields.
library;

import 'package:flutter/material.dart';

import '../theme/brand_theme.dart';
import '../theme/foloo_theme.dart';

/// Builds a field-local toolbar without the competing native iOS menu
/// controllers that can overlap during rapid selection/focus changes.
Widget folooAuthContextMenuBuilder(
  BuildContext context,
  EditableTextState editableTextState,
) => AdaptiveTextSelectionToolbar.editableText(
  editableTextState: editableTextState,
);

/// The shared text field used by Login, Create account and initial Profile.
class AuthTextFormField extends StatelessWidget {
  const AuthTextFormField({
    required this.fieldKey,
    required this.controller,
    this.focusNode,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
    this.onEditingComplete,
    super.key,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onEditingComplete;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final radius = BorderRadius.circular(17);
    final normalBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: palette.line, width: 1),
    );
    return TextFormField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      obscureText: obscureText,
      style: TextStyle(color: palette.ink, fontSize: 16, height: 1.25),
      cursorColor: palette.ink,
      contextMenuBuilder: folooAuthContextMenuBuilder,
      decoration: InputDecoration(
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2C2C2C)
            : FolooBrand.fieldFill,
        border: normalBorder,
        enabledBorder: normalBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: palette.ink, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: palette.error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: palette.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        suffixIcon: suffixIcon,
      ),
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      onEditingComplete: onEditingComplete,
    );
  }
}
