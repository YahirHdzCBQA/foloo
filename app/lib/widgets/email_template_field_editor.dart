/// Shared inline editor for canonical email-template variables.
///
/// It owns the friendly chip projection and variable picker used by both the
/// global and event-specific template flows (PLT-03, PLT-08).
library;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/foloo_theme.dart';

/// Canonical variables supported by every V1 email template.
const emailTemplateVariables = <String>[
  '{nombre}',
  '{apellido}',
  '{empresa}',
  '{puesto}',
  '{evento}',
  '{lugar}',
  '{contenido}',
  '{nombreVendedor}',
  '{empresaVendedor}',
];

/// Renders and edits one template field without changing its stored tokens.
class EmailTemplateFieldEditor extends StatefulWidget {
  const EmailTemplateFieldEditor({
    required this.fieldName,
    required this.controller,
    required this.textFieldKey,
    required this.onChanged,
    this.minLines = 1,
    this.maxLines = 4,
    this.keyPrefix = '',
    super.key,
  });

  final String fieldName;
  final TextEditingController controller;
  final Key textFieldKey;
  final VoidCallback onChanged;
  final int minLines;
  final int maxLines;
  final String keyPrefix;

  @override
  State<EmailTemplateFieldEditor> createState() =>
      _EmailTemplateFieldEditorState();
}

class _EmailTemplateFieldEditorState extends State<EmailTemplateFieldEditor> {
  final _editor = _FriendlyTemplateEditingController();
  final _focusNode = FocusNode();
  bool _editing = false;

  String get _keyPrefix =>
      widget.keyPrefix.isEmpty ? '' : '${widget.keyPrefix}-';
  bool get _english => Localizations.localeOf(context).languageCode == 'en';

  @override
  void dispose() {
    _editor.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _friendlyToken(String token) => switch (token) {
    '{nombre}' => _english ? 'Contact name' : 'Nombre del contacto',
    '{apellido}' => _english ? 'Last name' : 'Apellido',
    '{empresa}' => _english ? 'Contact company' : 'Empresa del contacto',
    '{puesto}' => _english ? 'Role' : 'Puesto',
    '{evento}' => _english ? 'Event' : 'Evento',
    '{lugar}' => _english ? 'Place' : 'Lugar',
    '{contenido}' => _english ? 'Content' : 'Contenido',
    '{nombreVendedor}' => _english ? 'Your name' : 'Tu nombre',
    '{empresaVendedor}' => _english ? 'Your company' : 'Tu empresa',
    _ => token,
  };

  String _tokenSource(String token) => switch (token) {
    '{nombre}' || '{apellido}' || '{empresa}' || '{puesto}' =>
      _english ? 'From the captured lead' : 'Se toma del lead capturado',
    '{evento}' =>
      _english ? 'From the active event' : 'Se toma del evento activo',
    '{lugar}' => _english ? 'From the direct lead' : 'Se toma del lead directo',
    '{contenido}' =>
      _english ? 'From selected PDFs' : 'Se toma del contenido elegido',
    _ => _english ? 'From your profile' : 'Se toma de tu perfil',
  };

  void _startEditing() {
    _editor.loadCanonical(widget.controller.text, {
      for (final token in emailTemplateVariables) token: _friendlyToken(token),
    });
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _editor.selection = TextSelection.collapsed(offset: _editor.text.length);
    });
  }

  void _insert(String token) {
    _editor.insertToken(token);
    widget.controller.text = _editor.canonicalText;
    widget.onChanged();
    _focusNode.requestFocus();
    setState(() {});
  }

  Future<void> _chooseVariable({
    String? replacing,
    int? replacementStart,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showEmailTemplateVariablePicker(
      context,
      current: replacing,
      keyPrefix: widget.keyPrefix,
      labelFor: _friendlyToken,
      sourceFor: _tokenSource,
    );
    if (selected == null || !mounted) return;
    if (replacing == null) {
      _insert(selected);
      return;
    }
    final start = replacementStart ?? widget.controller.text.indexOf(replacing);
    if (start < 0 ||
        start + replacing.length > widget.controller.text.length ||
        widget.controller.text.substring(start, start + replacing.length) !=
            replacing) {
      return;
    }
    widget.controller.text = widget.controller.text.replaceRange(
      start,
      start + replacing.length,
      selected,
    );
    widget.controller.selection = TextSelection.collapsed(
      offset: start + selected.length,
    );
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    return Container(
      padding: _editing
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(FolooRadii.md),
        border: _editing ? Border.all(color: palette.ink, width: 2) : null,
      ),
      child: _editing
          ? Stack(
              children: [
                TextField(
                  key: widget.textFieldKey,
                  controller: _editor,
                  focusNode: _focusNode,
                  minLines: widget.minLines,
                  maxLines: widget.maxLines,
                  onChanged: (_) {
                    widget.controller.text = _editor.canonicalText;
                    widget.onChanged();
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(14, 14, 52, 14),
                  ),
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: IconButton.filled(
                    key: Key(
                      '${_keyPrefix}templateLightning-${widget.fieldName}',
                    ),
                    tooltip: _english ? 'Insert data' : 'Insertar dato',
                    onPressed: _chooseVariable,
                    style: IconButton.styleFrom(
                      fixedSize: const Size.square(42),
                      backgroundColor: FolooColors.ink,
                      foregroundColor: FolooColors.lime,
                    ),
                    icon: const Icon(Icons.bolt, size: 22),
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _friendlyDocument()),
                Material(
                  color: palette.card,
                  shape: const CircleBorder(),
                  child: IconButton(
                    key: Key('${_keyPrefix}templateEdit-${widget.fieldName}'),
                    tooltip: context.l10n.edit,
                    onPressed: _startEditing,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _friendlyDocument() {
    final text = widget.controller.text;
    final matches = RegExp(r'\{[^}]+\}').allMatches(text).toList();
    final palette = FolooPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textStyle = DefaultTextStyle.of(context).style.copyWith(
      color: palette.ink,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.45,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
      decorationThickness: 0,
    );
    final children = <InlineSpan>[];
    var offset = 0;
    for (final match in matches) {
      if (match.start > offset) {
        children.add(TextSpan(text: text.substring(offset, match.start)));
      }
      final token = match.group(0)!;
      final remainder = text.substring(match.end);
      final punctuation =
          RegExp(r'^[,.;:!?…]+').firstMatch(remainder)?.group(0) ?? '';
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key(
                    '${_keyPrefix}friendlyToken-${widget.fieldName}-$token-${match.start}',
                  ),
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _chooseVariable(
                    replacing: token,
                    replacementStart: match.start,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: dark
                          ? FolooColors.lime.withValues(alpha: .20)
                          : FolooColors.lime.withValues(alpha: .25),
                      border: Border.all(color: palette.lineStrong),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _friendlyToken(token),
                      style: textStyle.copyWith(
                        color: palette.ink,
                        fontSize: 12,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              if (punctuation.isNotEmpty) Text(punctuation, style: textStyle),
            ],
          ),
        ),
      );
      offset = match.end + punctuation.length;
    }
    if (offset < text.length) {
      children.add(TextSpan(text: text.substring(offset)));
    }
    return Text.rich(
      TextSpan(style: textStyle, children: children),
      key: Key('${_keyPrefix}friendlyDocument-${widget.fieldName}'),
    );
  }
}

/// Presents the common ES/EN template-variable selector.
Future<String?> showEmailTemplateVariablePicker(
  BuildContext context, {
  required String? current,
  required String keyPrefix,
  required String Function(String) labelFor,
  required String Function(String) sourceFor,
}) {
  final english = Localizations.localeOf(context).languageCode == 'en';
  final prefix = keyPrefix.isEmpty ? '' : '$keyPrefix-';
  var pending = current;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .42),
    builder: (sheetContext) => FractionallySizedBox(
      key: Key('${prefix}templateVariableSheet'),
      heightFactor: .78,
      child: Material(
        color: FolooPalette.of(sheetContext).card,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) => SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        english ? 'Insert data' : 'Insertar dato',
                        style: Theme.of(sheetContext).textTheme.headlineSmall,
                      ),
                      Text(
                        english
                            ? 'It fills automatically from the lead, event, or your profile. It is not edited here.'
                            : 'Se llena solo con la información del lead, el evento o tu perfil. No se edita aquí.',
                        style: TextStyle(
                          color: FolooPalette.of(sheetContext).inkSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    key: Key('${prefix}templateVariableList'),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      for (
                        var index = 0;
                        index < emailTemplateVariables.length;
                        index++
                      ) ...[
                        if (index == 0 || index == 4 || index == 7)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 8, 2, 7),
                            child: Text(
                              index == 0
                                  ? (english
                                        ? 'From the contact'
                                        : 'Del contacto')
                                  : index == 4
                                  ? (english
                                        ? 'From the record'
                                        : 'Del registro')
                                  : (english ? 'Yours' : 'Tuyos'),
                              style: TextStyle(
                                color: FolooPalette.of(sheetContext)
                                    .inkSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        _VariableChoice(
                          choiceKey: Key(
                            '${prefix}templateVariableChoice-${emailTemplateVariables[index]}',
                          ),
                          token: emailTemplateVariables[index],
                          label: labelFor(emailTemplateVariables[index]),
                          source: sourceFor(emailTemplateVariables[index]),
                          selected: pending == emailTemplateVariables[index],
                          onTap: () => setSheetState(
                            () => pending = emailTemplateVariables[index],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          key: Key('${prefix}cancelTemplateVariable'),
                          onPressed: () => Navigator.pop(sheetContext),
                          style: FilledButton.styleFrom(
                            backgroundColor: FolooPalette.of(sheetContext)
                                .paper,
                            foregroundColor: FolooPalette.of(sheetContext).ink,
                          ),
                          child: Text(sheetContext.l10n.cancel),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          key: Key('${prefix}insertTemplateVariable'),
                          onPressed: pending == null
                              ? null
                              : () => Navigator.pop(sheetContext, pending),
                          child: Text(english ? 'Insert' : 'Insertar'),
                        ),
                      ),
                    ],
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

class _VariableChoice extends StatelessWidget {
  const _VariableChoice({
    required this.choiceKey,
    required this.token,
    required this.label,
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final Key choiceKey;
  final String token;
  final String label;
  final String source;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? FolooColors.lime.withValues(alpha: .28)
            : palette.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolooRadii.md),
          side: selected
              ? BorderSide(color: palette.ink, width: 2)
              : BorderSide.none,
        ),
        child: ListTile(
          key: choiceKey,
          onTap: onTap,
          leading: Icon(
            token == '{evento}'
                ? Icons.calendar_today_outlined
                : token.contains('empresa')
                ? Icons.business_outlined
                : Icons.verified_outlined,
          ),
          title: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(source),
          trailing: selected ? const Icon(Icons.check_circle) : null,
        ),
      ),
    );
  }
}

class _FriendlyTemplateEditingController extends TextEditingController {
  static const _marker = '\u2063';
  Map<String, String> _tokenToLabel = const {};
  Map<String, String> _labelToToken = const {};

  void loadCanonical(String source, Map<String, String> labels) {
    _tokenToLabel = labels;
    _labelToToken = {
      for (final entry in labels.entries) entry.value: entry.key,
    };
    final projected = source.replaceAllMapped(RegExp(r'\{[^}]+\}'), (match) {
      final token = match.group(0)!;
      final label = labels[token];
      return label == null ? token : '$_marker$label$_marker';
    });
    value = TextEditingValue(
      text: projected,
      selection: TextSelection.collapsed(offset: projected.length),
    );
  }

  String get canonicalText {
    var result = text;
    for (final entry in _labelToToken.entries) {
      result = result.replaceAll('$_marker${entry.key}$_marker', entry.value);
    }
    return result.replaceAll(_marker, '');
  }

  void insertToken(String token) {
    final label = _tokenToLabel[token] ?? token;
    final insertion = label == token ? token : '$_marker$label$_marker';
    final current = selection.isValid
        ? selection
        : TextSelection.collapsed(offset: text.length);
    value = TextEditingValue(
      text: text.replaceRange(current.start, current.end, insertion),
      selection: TextSelection.collapsed(
        offset: current.start + insertion.length,
      ),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final clean = (style ?? const TextStyle()).copyWith(
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
      decorationThickness: 0,
      fontWeight: FontWeight.w400,
    );
    final spans = <InlineSpan>[];
    var offset = 0;
    while (offset < text.length) {
      final start = text.indexOf(_marker, offset);
      if (start < 0) {
        spans.add(TextSpan(text: text.substring(offset), style: clean));
        break;
      }
      if (start > offset) {
        spans.add(TextSpan(text: text.substring(offset, start), style: clean));
      }
      final end = text.indexOf(_marker, start + 1);
      if (end < 0) break;
      spans.add(
        TextSpan(
          text: text.substring(start + 1, end),
          style: clean.copyWith(
            color: FolooPalette.of(context).ink,
            backgroundColor: FolooColors.lime.withValues(alpha: .25),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      offset = end + 1;
    }
    return TextSpan(style: clean, children: spans);
  }
}
