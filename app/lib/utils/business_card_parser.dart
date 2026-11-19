/// Conservative mapping from recognized card text into existing lead fields.
///
/// Ambiguous values remain empty, and the separate prefill policy prevents a
/// later OCR pass from replacing manual corrections.
library;

/// Structured output produced by the local business-card parser.
class ParsedBusinessCard {
  const ParsedBusinessCard({
    this.name = '',
    this.lastName = '',
    this.role = '',
    this.company = '',
    this.email = '',
    this.phone = '',
    this.note = '',
    this.detectedWebsite = '',
  });

  final String name;
  final String lastName;
  final String role;
  final String company;
  final String email;
  final String phone;
  final String note;

  /// Diagnostic only. OQ-A02 prevents adding this to the lead model.
  final String detectedWebsite;

  int get populatedLeadFieldCount => [
    name,
    lastName,
    role,
    company,
    email,
    phone,
    note,
  ].where((value) => value.isNotEmpty).length;
}

/// Returns whether OCR may prefill a field without overriding user intent.
///
/// OCR-05 makes a manual edit authoritative even when the edited value is empty.
bool shouldApplyExtractedValue({
  required String currentValue,
  required String extractedValue,
  required bool manuallyEdited,
}) =>
    !manuallyEdited &&
    currentValue.trim().isEmpty &&
    extractedValue.trim().isNotEmpty;

/// Applies cautious card-specific heuristics to ML Kit text lines.
class BusinessCardParser {
  static final RegExp _emailPattern = RegExp(
    r'[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}',
    caseSensitive: false,
  );
  static final RegExp _phonePattern = RegExp(
    r'(?<![\w@])\+?\d[\d\s().\-]{5,}\d(?![\w@])',
  );
  static final RegExp _websitePattern = RegExp(
    r'(?:(?:https?://|www\.)[^\s]+|(?:[a-z0-9\-]+\.)+(?:com|mx|org|net|io|co)(?:/[^\s]*)?)',
    caseSensitive: false,
  );
  static final RegExp _rolePattern = RegExp(
    r'\b(?:gerente|director(?:a)?|coordinador(?:a)?|ejecutiv[oa]|ingenier[oa]|consultor(?:a)?|presidente|fundador(?:a)?|ventas|marketing|calidad|manager|owner|ceo|cto|cfo)\b',
    caseSensitive: false,
  );
  static final RegExp _companyPattern = RegExp(
    r'\b(?:grupo|corporativo|empresa|soluciones|solutions|industrias?|asociaci[oó]n|consultor[ií]a|laboratorios?|l[aá]cteo|s\.?\s*a\.?\s*(?:de\s*c\.?\s*v\.?)?|llc|inc\.?)\b',
    caseSensitive: false,
  );
  static final RegExp _labelPattern = RegExp(
    r'^(?:tel(?:[eé]fono)?|m[oó]vil|cel(?:ular)?|email|correo(?:\s+electr[oó]nico)?|web|sitio|notas?)\s*[:\-]?\s*',
    caseSensitive: false,
  );
  static final RegExp _phoneLabelPattern = RegExp(
    r'^(?:tel(?:[eé]fono)?|m[oó]vil|cel(?:ular)?)\s*[:\-]?\s*(.*)$',
    caseSensitive: false,
  );
  static final RegExp _emailLabelPattern = RegExp(
    r'^(?:email|correo(?:\s+electr[oó]nico)?)\s*[:\-]?\s*(.*)$',
    caseSensitive: false,
  );
  static final RegExp _noteLabelPattern = RegExp(
    r'^notas?\s*[:\-]?\s*(.*)$',
    caseSensitive: false,
  );
  static final RegExp _nameLinePattern = RegExp(
    r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ'’.-]+(?:\s+[A-Za-zÁÉÍÓÚÜÑáéíóúüñ'’.-]+){1,4}$",
  );

  const BusinessCardParser();

  ParsedBusinessCard parse(Iterable<String> inputLines) {
    final lines = inputLines
        .map(_normalizeContactSpacing)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    var email = '';
    var phone = '';
    var note = '';
    var website = '';
    final structuralLabels = <int>{};
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final next = index + 1 < lines.length ? lines[index + 1] : '';
      final phoneLabel = _phoneLabelPattern.firstMatch(line);
      final emailLabel = _emailLabelPattern.firstMatch(line);
      final noteLabel = _noteLabelPattern.firstMatch(line);
      if (phoneLabel != null || emailLabel != null || noteLabel != null) {
        structuralLabels.add(index);
      }
      final labeledPhone = phoneLabel?.group(1)?.trim();
      final labeledEmail = emailLabel?.group(1)?.trim();
      final labeledNote = noteLabel?.group(1)?.trim();
      final phoneSource = labeledPhone?.isNotEmpty == true
          ? labeledPhone!
          : next;
      final emailSource = labeledEmail?.isNotEmpty == true
          ? labeledEmail!
          : next;
      final noteSource = labeledNote?.isNotEmpty == true ? labeledNote! : next;
      if (phone.isEmpty && phoneLabel != null) {
        phone = _validPhone(phoneSource);
      }
      if (email.isEmpty &&
          emailLabel != null &&
          !_looksTruncated(emailSource)) {
        email = _emailPattern.firstMatch(emailSource)?.group(0) ?? '';
      }
      if (note.isEmpty && noteLabel != null && noteSource.isNotEmpty) {
        note = noteSource;
      }
      email = email.isEmpty
          ? (_looksTruncated(line)
                ? ''
                : _emailPattern.firstMatch(line)?.group(0) ?? '')
          : email;
      website = website.isEmpty && !_emailPattern.hasMatch(line)
          ? _websitePattern.firstMatch(line)?.group(0) ?? ''
          : website;
      if (phone.isEmpty) {
        phone = _validPhone(line);
      }
    }

    final textLines = <String>[];
    for (var index = 0; index < lines.length; index++) {
      if (structuralLabels.contains(index)) continue;
      final previousWasLabel =
          index > 0 && structuralLabels.contains(index - 1);
      if (previousWasLabel) continue;
      final original = lines[index];
      var line = original
          .replaceAll(_emailPattern, ' ')
          .replaceAll(_phonePattern, ' ')
          .replaceAll(_websitePattern, ' ');
      line = _normalizeWhitespace(line.replaceFirst(_labelPattern, ''));
      if (line.isNotEmpty && !_isOnlyPunctuation(line)) textLines.add(line);
    }

    final role = textLines.where(_looksLikeRole).firstOrNull ?? '';
    var company = textLines.where(_looksLikeCompany).firstOrNull ?? '';
    final nameLine = textLines.where((line) {
      return line != role &&
          line != company &&
          _nameLinePattern.hasMatch(line) &&
          !_looksLikeRole(line) &&
          !_looksLikeCompany(line);
    }).firstOrNull;

    var name = '';
    var lastName = '';
    if (nameLine != null) {
      final parts = nameLine.split(' ');
      name = parts.first;
      lastName = parts.skip(1).join(' ');
    }
    if (company.isEmpty && nameLine != null) {
      final following = textLines.skip(textLines.indexOf(nameLine) + 1);
      company = following.where(_looksLikeUppercaseCompany).firstOrNull ?? '';
    }

    return ParsedBusinessCard(
      name: name,
      lastName: lastName,
      role: role,
      company: company,
      email: email,
      phone: phone,
      note: note,
      detectedWebsite: website,
    );
  }

  bool _looksLikeRole(String line) => _rolePattern.hasMatch(line);

  bool _looksLikeCompany(String line) => _companyPattern.hasMatch(line);

  bool _looksLikeUppercaseCompany(String line) =>
      line.length >= 3 &&
      line == line.toUpperCase() &&
      RegExp(r'[A-ZÁÉÍÓÚÜÑ]').hasMatch(line) &&
      !_looksLikeRole(line);

  static String _validPhone(String value) {
    for (final match in _phonePattern.allMatches(value)) {
      final candidate = _normalizeWhitespace(match.group(0) ?? '');
      final digitCount = candidate.replaceAll(RegExp(r'\D'), '').length;
      if (digitCount >= 7 && digitCount <= 15) return candidate;
    }
    return '';
  }

  static bool _looksTruncated(String value) =>
      value.contains('…') || value.contains('...');

  static String _normalizeWhitespace(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String _normalizeContactSpacing(String value) {
    var normalized = _normalizeWhitespace(value);
    // ML Kit can introduce spaces around email punctuation when characters
    // are small. Only compact a line that contains an @ to avoid changing
    // person/company punctuation.
    if (normalized.contains('@')) {
      normalized = normalized
          .replaceAll(RegExp(r'\s*@\s*'), '@')
          .replaceAll(RegExp(r'\s*\.\s*'), '.');
    }
    if (RegExp(
      r'^(?:tel(?:[eé]fono)?|m[oó]vil|cel(?:ular)?)\b',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      normalized = normalized.replaceAll(RegExp(r'[oO]'), '0');
    }
    return normalized;
  }

  static bool _isOnlyPunctuation(String value) =>
      !RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9]').hasMatch(value);
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
