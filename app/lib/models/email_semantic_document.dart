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
          return value['kind'] == 'token'
              ? _SemanticSegment.token(value['value'] as String)
              : _SemanticSegment.literal(value['value'] as String);
        }).toList(),
      ),
    );
  }

  final List<_SemanticSegment> _segments;

  String render(Map<String, String> values) => _segments
      .map(
        (segment) =>
            segment.isToken ? values[segment.value] ?? '' : segment.value,
      )
      .join();

  String toJson() => jsonEncode({
    'version': 1,
    'segments': _segments
        .map(
          (segment) => {
            'kind': segment.isToken ? 'token' : 'literal',
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
    var offset = 0;
    for (var index = 0; index < _segments.length; index++) {
      final segment = _segments[index];
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
}

class _SemanticSegment {
  const _SemanticSegment.literal(this.value) : isToken = false;
  const _SemanticSegment.token(this.value) : isToken = true;

  final bool isToken;
  final String value;
}

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
    if (!segment.isToken && segment.value.isEmpty) continue;
    if (!segment.isToken && result.isNotEmpty && !result.last.isToken) {
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
