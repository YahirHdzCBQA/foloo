/// Durable token-aware representation of one editable Review field.
///
/// Literal edits remain literal while untouched D-14 variables stay semantic,
/// allowing a pending preparation to rerender safely after Lead changes.
library;

import 'dart:convert';

const _emailTokens = <String>{
  'nombre',
  'apellido',
  'empresa',
  'puesto',
  'evento',
  'lugar',
  'contenido',
  'nombreVendedor',
  'empresaVendedor',
};

final _tokenPattern = RegExp(r'\{([^{}]+)\}');

/// Structured source for a concrete subject or body edited in Review.
class EmailSemanticDocument {
  const EmailSemanticDocument._(this._segments);

  factory EmailSemanticDocument.fromTemplate(String source) {
    final segments = <_SemanticSegment>[];
    var cursor = 0;
    for (final match in _tokenPattern.allMatches(source)) {
      if (match.start > cursor) {
        segments.add(
          _SemanticSegment.literal(source.substring(cursor, match.start)),
        );
      }
      final name = match.group(1)!;
      if (_emailTokens.contains(name)) {
        segments.add(_SemanticSegment.token(name));
      } else {
        segments.add(_SemanticSegment.literal(match.group(0)!));
      }
      cursor = match.end;
    }
    if (cursor < source.length) {
      segments.add(_SemanticSegment.literal(source.substring(cursor)));
    }
    return EmailSemanticDocument._(_mergeLiterals(segments));
  }

  factory EmailSemanticDocument.fromJson(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    final raw = decoded['segments'] as List<dynamic>;
    return EmailSemanticDocument._(
      _mergeLiterals(
        raw.map((item) {
          final value = item as Map<String, dynamic>;
          return switch (value['kind']) {
            'token' => _SemanticSegment.token(value['value'] as String),
            'suppressedToken' => _SemanticSegment.suppressedToken(
              value['value'] as String,
            ),
            _ => _SemanticSegment.literal(value['value'] as String),
          };
        }).toList(),
      ),
    );
  }

  final List<_SemanticSegment> _segments;

  String render(Map<String, String> values) => _effectiveSegments(values)
      .map(
        (segment) => segment.isToken
            ? values[segment.value] ?? ''
            : segment.isSuppressedToken
            ? ''
            : segment.value,
      )
      .join();

  String toJson() => jsonEncode({
    'version': 1,
    'segments': _segments
        .map(
          (segment) => {
            'kind': segment.isToken
                ? 'token'
                : segment.isSuppressedToken
                ? 'suppressedToken'
                : 'literal',
            'value': segment.value,
          },
        )
        .toList(),
  });

  /// Projects concrete edits onto the semantic source.
  ///
  /// A token survives only when its rendered range was not modified. Inserts
  /// at token boundaries remain literals; edits inside a token deliberately
  /// become literal because their intended variable semantics are ambiguous.
  EmailSemanticDocument captureEdit({
    required String previousConcrete,
    required String editedConcrete,
    required Map<String, String> values,
  }) {
    final renderedSegments = <_RenderedSegment>[];
    final effectiveSegments = _effectiveSegments(values);
    var offset = 0;
    for (var index = 0; index < effectiveSegments.length; index++) {
      final segment = effectiveSegments[index];
      final rendered = segment.isToken
          ? values[segment.value] ?? ''
          : segment.value;
      final length = rendered.runes.length;
      renderedSegments.add(
        _RenderedSegment(index, segment, offset, offset + length),
      );
      offset += length;
    }
    if (render(values) != previousConcrete) {
      return EmailSemanticDocument._([
        _SemanticSegment.literal(editedConcrete),
      ]);
    }

    final oldRunes = previousConcrete.runes.toList();
    final newRunes = editedConcrete.runes.toList();
    final differences = _myersDiff(oldRunes, newRunes);
    final dirtyTokens = <int>{};
    final insertionPositions = <int>[];
    var oldPosition = 0;
    for (final difference in differences) {
      if (difference.kind == _DiffKind.delete) {
        final end = oldPosition + difference.runes.length;
        for (final segment in renderedSegments) {
          if (segment.segment.isToken &&
              oldPosition < segment.end &&
              end > segment.start) {
            dirtyTokens.add(segment.index);
          }
        }
        oldPosition = end;
      } else if (difference.kind == _DiffKind.insert) {
        insertionPositions.add(oldPosition);
        for (final segment in renderedSegments) {
          if (segment.segment.isToken &&
              oldPosition > segment.start &&
              oldPosition < segment.end) {
            dirtyTokens.add(segment.index);
          }
        }
      } else {
        oldPosition += difference.runes.length;
      }
    }
    final restorableDeletedTokens = <int>{
      for (final segment in renderedSegments)
        if (dirtyTokens.contains(segment.index) &&
            !insertionPositions.any(
              (position) =>
                  position >= segment.start && position <= segment.end,
            ) &&
            _preservesLineAnchors(
              oldRunes: oldRunes,
              newRunes: newRunes,
              tokenStart: segment.start,
              tokenEnd: segment.end,
            ))
          segment.index,
    };

    final result = <_SemanticSegment>[];
    final emittedTokens = <int>{};
    oldPosition = 0;

    void appendLiteral(Iterable<int> runes) {
      if (runes.isEmpty) return;
      result.add(_SemanticSegment.literal(String.fromCharCodes(runes)));
    }

    void emitEmptyTokensAt(int position) {
      for (final segment in renderedSegments) {
        if (segment.segment.isToken &&
            segment.start == position &&
            segment.end == position &&
            !dirtyTokens.contains(segment.index) &&
            emittedTokens.add(segment.index)) {
          result.add(segment.segment);
        }
      }
    }

    _RenderedSegment? segmentAt(int position) {
      for (final segment in renderedSegments) {
        if (position >= segment.start && position < segment.end) return segment;
      }
      return null;
    }

    for (final difference in differences) {
      emitEmptyTokensAt(oldPosition);
      switch (difference.kind) {
        case _DiffKind.insert:
          appendLiteral(difference.runes);
        case _DiffKind.delete:
          final deleteEnd = oldPosition + difference.runes.length;
          for (final segment in renderedSegments) {
            if (restorableDeletedTokens.contains(segment.index) &&
                oldPosition < segment.end &&
                deleteEnd > segment.start &&
                emittedTokens.add(segment.index)) {
              result.add(
                _SemanticSegment.suppressedToken(segment.segment.value),
              );
            }
          }
          oldPosition += difference.runes.length;
        case _DiffKind.equal:
          for (final rune in difference.runes) {
            final rendered = segmentAt(oldPosition);
            if (rendered != null &&
                rendered.segment.isToken &&
                !dirtyTokens.contains(rendered.index)) {
              if (emittedTokens.add(rendered.index)) {
                result.add(rendered.segment);
              }
            } else {
              appendLiteral([rune]);
            }
            oldPosition++;
            emitEmptyTokensAt(oldPosition);
          }
      }
    }
    emitEmptyTokensAt(oldPosition);
    return EmailSemanticDocument._(_mergeLiterals(result));
  }

  /// Restores a deliberately deleted generated token line when a fresh Review
  /// is prepared, without reviving custom replacement prose (PLT-08/SAL-01).
  EmailSemanticDocument restoreGeneratedTokenLine({
    required EmailSemanticDocument generated,
    required String token,
  }) {
    if (_segments.any((segment) => segment.isToken && segment.value == token)) {
      return this;
    }
    final suppressedIndex = _segments.indexWhere(
      (segment) => segment.isSuppressedToken && segment.value == token,
    );
    final generatedIndex = generated._segments.indexWhere(
      (segment) => segment.isToken && segment.value == token,
    );
    if (suppressedIndex < 0 || generatedIndex < 0) return this;

    final line = generated._lineAround(generatedIndex);
    if (line.isEmpty) return this;
    final generatedPrefix = generated._literalPrefixOnLine(generatedIndex);
    final generatedSuffix = generated._literalSuffixOnLine(generatedIndex);
    final previous = suppressedIndex > 0
        ? _segments[suppressedIndex - 1]
        : null;
    final next = suppressedIndex + 1 < _segments.length
        ? _segments[suppressedIndex + 1]
        : null;
    final tokenOnly =
        previous?.isLiteral == true &&
        next?.isLiteral == true &&
        previous!.value.endsWith(generatedPrefix) &&
        next!.value.startsWith(generatedSuffix);
    final result = [..._segments];
    if (tokenOnly) {
      result[suppressedIndex] = generated._segments[generatedIndex];
    } else {
      var displaced = '';
      if (previous?.isLiteral == true) {
        final newline = previous!.value.lastIndexOf('\n');
        displaced = previous.value.substring(newline + 1);
        result[suppressedIndex - 1] = _SemanticSegment.literal(
          previous.value.substring(0, newline + 1),
        );
      }
      result.replaceRange(suppressedIndex, suppressedIndex + 1, [
        ...line,
        if (displaced.isNotEmpty) _SemanticSegment.literal(displaced),
      ]);
    }
    return EmailSemanticDocument._(_mergeLiterals(result));
  }

  String _literalPrefixOnLine(int targetIndex) {
    if (targetIndex == 0 || !_segments[targetIndex - 1].isLiteral) return '';
    final value = _segments[targetIndex - 1].value;
    return value.substring(value.lastIndexOf('\n') + 1);
  }

  String _literalSuffixOnLine(int targetIndex) {
    if (targetIndex + 1 >= _segments.length ||
        !_segments[targetIndex + 1].isLiteral) {
      return '';
    }
    final value = _segments[targetIndex + 1].value;
    final newline = value.indexOf('\n');
    return newline < 0 ? value : value.substring(0, newline);
  }

  List<_SemanticSegment> _lineAround(int targetIndex) {
    final before = <_SemanticSegment>[];
    for (var index = targetIndex - 1; index >= 0; index--) {
      final segment = _segments[index];
      if (!segment.isLiteral) {
        before.insert(0, segment);
        continue;
      }
      final newline = segment.value.lastIndexOf('\n');
      final fragment = newline < 0
          ? segment.value
          : segment.value.substring(newline + 1);
      if (fragment.isNotEmpty) {
        before.insert(0, _SemanticSegment.literal(fragment));
      }
      if (newline >= 0) break;
    }
    final after = <_SemanticSegment>[];
    for (var index = targetIndex + 1; index < _segments.length; index++) {
      final segment = _segments[index];
      if (!segment.isLiteral) {
        after.add(segment);
        continue;
      }
      final newline = segment.value.indexOf('\n');
      if (newline < 0) {
        after.add(segment);
      } else {
        after.add(
          _SemanticSegment.literal(segment.value.substring(0, newline + 1)),
        );
        break;
      }
    }
    return [...before, _segments[targetIndex], ...after];
  }

  /// Omits the generated Content sentence for an empty selection while
  /// retaining a zero-width semantic token at that exact location.
  ///
  /// Keeping the effective segments aligned with [render] is essential: a
  /// later manual edit must not shift or corrupt the signature, and adding
  /// Content again must be able to restore the generated sentence.
  List<_SemanticSegment> _effectiveSegments(Map<String, String> values) {
    if ((values['contenido'] ?? '').isNotEmpty) return _segments;
    final contentIndex = _segments.indexWhere(
      (segment) => segment.isToken && segment.value == 'contenido',
    );
    if (contentIndex < 0) return _segments;

    final rendered = <int>[];
    var contentOffset = 0;
    for (var index = 0; index < _segments.length; index++) {
      final segment = _segments[index];
      if (index == contentIndex) contentOffset = rendered.length;
      rendered.addAll(
        (segment.isToken ? values[segment.value] ?? '' : segment.value).runes,
      );
    }
    const newline = 0x0A;
    var removeStart = contentOffset;
    while (removeStart > 0 && rendered[removeStart - 1] != newline) {
      removeStart--;
    }
    var removeEnd = contentOffset;
    while (removeEnd < rendered.length && rendered[removeEnd] != newline) {
      removeEnd++;
    }
    if (removeEnd < rendered.length) removeEnd++;

    final result = <_SemanticSegment>[];
    var segmentStart = 0;
    for (var index = 0; index < _segments.length; index++) {
      final segment = _segments[index];
      final concrete = segment.isToken
          ? values[segment.value] ?? ''
          : segment.value;
      final runes = concrete.runes.toList();
      final segmentEnd = segmentStart + runes.length;
      if (index == contentIndex) {
        result.add(segment);
      } else if (segmentEnd <= removeStart || segmentStart >= removeEnd) {
        result.add(segment);
      } else if (!segment.isToken) {
        if (segmentStart < removeStart) {
          result.add(
            _SemanticSegment.literal(
              String.fromCharCodes(runes.take(removeStart - segmentStart)),
            ),
          );
        }
        if (segmentEnd > removeEnd) {
          result.add(
            _SemanticSegment.literal(
              String.fromCharCodes(runes.skip(removeEnd - segmentStart)),
            ),
          );
        }
      }
      segmentStart = segmentEnd;
    }
    return _mergeLiterals(result);
  }
}

bool _preservesLineAnchors({
  required List<int> oldRunes,
  required List<int> newRunes,
  required int tokenStart,
  required int tokenEnd,
}) {
  const newline = 0x0A;
  var lineStart = tokenStart;
  while (lineStart > 0 && oldRunes[lineStart - 1] != newline) {
    lineStart--;
  }
  var lineEnd = tokenEnd;
  while (lineEnd < oldRunes.length && oldRunes[lineEnd] != newline) {
    lineEnd++;
  }
  if (lineEnd < oldRunes.length) lineEnd++;
  if (lineStart == 0 || lineEnd >= oldRunes.length) return false;
  final prefixStart = lineStart > 16 ? lineStart - 16 : 0;
  final suffixEnd = lineEnd + 16 < oldRunes.length
      ? lineEnd + 16
      : oldRunes.length;
  final prefix = oldRunes.sublist(prefixStart, lineStart);
  final suffix = oldRunes.sublist(lineEnd, suffixEnd);
  final prefixAt = _indexOfRunes(newRunes, prefix);
  final suffixAt = _indexOfRunes(newRunes, suffix);
  return prefixAt >= 0 && suffixAt >= prefixAt + prefix.length;
}

class _SemanticSegment {
  const _SemanticSegment.literal(this.value) : kind = _SegmentKind.literal;
  const _SemanticSegment.token(this.value) : kind = _SegmentKind.token;
  const _SemanticSegment.suppressedToken(this.value)
    : kind = _SegmentKind.suppressedToken;

  final _SegmentKind kind;
  final String value;
  bool get isToken => kind == _SegmentKind.token;
  bool get isSuppressedToken => kind == _SegmentKind.suppressedToken;
  bool get isLiteral => kind == _SegmentKind.literal;
}

enum _SegmentKind { literal, token, suppressedToken }

class _RenderedSegment {
  const _RenderedSegment(this.index, this.segment, this.start, this.end);

  final int index;
  final _SemanticSegment segment;
  final int start;
  final int end;
}

List<_SemanticSegment> _mergeLiterals(List<_SemanticSegment> source) {
  final result = <_SemanticSegment>[];
  for (final segment in source) {
    if (segment.isLiteral && segment.value.isEmpty) continue;
    if (segment.isLiteral && result.isNotEmpty && result.last.isLiteral) {
      final previous = result.removeLast();
      result.add(_SemanticSegment.literal(previous.value + segment.value));
    } else {
      result.add(segment);
    }
  }
  return List.unmodifiable(result);
}

enum _DiffKind { equal, insert, delete }

class _Diff {
  const _Diff(this.kind, this.runes);

  final _DiffKind kind;
  final List<int> runes;
}

List<_Diff> _myersDiff(List<int> before, List<int> after) {
  final embeddedAt = _indexOfRunes(after, before);
  if (embeddedAt >= 0) {
    return [
      if (embeddedAt > 0) _Diff(_DiffKind.insert, after.sublist(0, embeddedAt)),
      _Diff(_DiffKind.equal, before),
      if (embeddedAt + before.length < after.length)
        _Diff(_DiffKind.insert, after.sublist(embeddedAt + before.length)),
    ];
  }
  final maximum = before.length + after.length;
  var frontier = <int, int>{1: 0};
  final trace = <Map<int, int>>[];
  for (var distance = 0; distance <= maximum; distance++) {
    trace.add(Map<int, int>.from(frontier));
    for (var diagonal = -distance; diagonal <= distance; diagonal += 2) {
      var x =
          diagonal == -distance ||
              (diagonal != distance &&
                  (frontier[diagonal - 1] ?? -1) <
                      (frontier[diagonal + 1] ?? -1))
          ? frontier[diagonal + 1] ?? 0
          : (frontier[diagonal - 1] ?? 0) + 1;
      var y = x - diagonal;
      while (x < before.length && y < after.length && before[x] == after[y]) {
        x++;
        y++;
      }
      frontier[diagonal] = x;
      if (x >= before.length && y >= after.length) {
        return _backtrack(trace, before, after);
      }
    }
  }
  return const [];
}

int _indexOfRunes(List<int> source, List<int> pattern) {
  if (pattern.isEmpty) return 0;
  if (pattern.length > source.length) return -1;
  for (var start = 0; start <= source.length - pattern.length; start++) {
    var matches = true;
    for (var offset = 0; offset < pattern.length; offset++) {
      if (source[start + offset] != pattern[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) return start;
  }
  return -1;
}

List<_Diff> _backtrack(
  List<Map<int, int>> trace,
  List<int> before,
  List<int> after,
) {
  var x = before.length;
  var y = after.length;
  final reversed = <_Diff>[];
  for (var distance = trace.length - 1; distance >= 0; distance--) {
    final frontier = trace[distance];
    final diagonal = x - y;
    final previousDiagonal =
        diagonal == -distance ||
            (diagonal != distance &&
                (frontier[diagonal - 1] ?? -1) < (frontier[diagonal + 1] ?? -1))
        ? diagonal + 1
        : diagonal - 1;
    final previousX = frontier[previousDiagonal] ?? 0;
    final previousY = previousX - previousDiagonal;
    while (x > previousX && y > previousY) {
      reversed.add(_Diff(_DiffKind.equal, [before[x - 1]]));
      x--;
      y--;
    }
    if (distance == 0) break;
    if (x == previousX) {
      reversed.add(_Diff(_DiffKind.insert, [after[y - 1]]));
      y--;
    } else {
      reversed.add(_Diff(_DiffKind.delete, [before[x - 1]]));
      x--;
    }
  }
  final ordered = reversed.reversed.toList();
  final merged = <_Diff>[];
  for (final difference in ordered) {
    if (merged.isNotEmpty && merged.last.kind == difference.kind) {
      final previous = merged.removeLast();
      merged.add(
        _Diff(previous.kind, [...previous.runes, ...difference.runes]),
      );
    } else {
      merged.add(difference);
    }
  }
  return merged;
}
