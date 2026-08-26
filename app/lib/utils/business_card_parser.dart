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
    this.detectedWebsite = '',
  });

  final String name;
  final String lastName;
  final String role;
  final String company;
  final String email;
  final String phone;

  /// Diagnostic only. OQ-A02 prevents adding this to the lead model.
  final String detectedWebsite;

  int get populatedLeadFieldCount => [
    name,
    lastName,
    role,
    company,
    email,
    phone,
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

// TODO(PRODUCTION): Replace local parsing with server-side OCR-03 extraction.
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
    r'^(?:tel(?:[eé]fono)?|m[oó]vil|cel(?:ular)?|email|correo|web|sitio)\s*[:\-]?\s*',
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
    var website = '';
    for (final line in lines) {
      email = email.isEmpty
          ? _emailPattern.firstMatch(line)?.group(0) ?? ''
          : email;
      website = website.isEmpty && !_emailPattern.hasMatch(line)
          ? _websitePattern.firstMatch(line)?.group(0) ?? ''
          : website;
      if (phone.isEmpty) {
        for (final match in _phonePattern.allMatches(line)) {
          final candidate = _normalizeWhitespace(match.group(0) ?? '');
          final digitCount = candidate.replaceAll(RegExp(r'\D'), '').length;
          if (digitCount >= 7 && digitCount <= 15) {
            phone = candidate;
            break;
          }
        }
      }
    }

    final textLines = <String>[];
    for (final original in lines) {
      var line = original
          .replaceAll(_emailPattern, ' ')
          .replaceAll(_phonePattern, ' ')
          .replaceAll(_websitePattern, ' ');
      line = _normalizeWhitespace(line.replaceFirst(_labelPattern, ''));
      if (line.isNotEmpty && !_isOnlyPunctuation(line)) textLines.add(line);
    }

    final role = textLines.where(_looksLikeRole).firstOrNull ?? '';
    final company = textLines.where(_looksLikeCompany).firstOrNull ?? '';
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

    return ParsedBusinessCard(
      name: name,
      lastName: lastName,
      role: role,
      company: company,
      email: email,
      phone: phone,
      detectedWebsite: website,
    );
  }

  bool _looksLikeRole(String line) => _rolePattern.hasMatch(line);

  bool _looksLikeCompany(String line) => _companyPattern.hasMatch(line);

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
