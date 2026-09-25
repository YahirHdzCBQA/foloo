/// Converts reviewed plain-text follow-ups into conservative email HTML.
///
/// Paragraph breaks become one styled `<p>` each, while single line breaks
/// inside a paragraph remain `<br>` for signatures and similar content.
library;

import 'dart:convert';

const _paragraphGap = '1em';

/// Produces HTML with predictable paragraph spacing across common mail clients.
String renderPlainTextEmailHtml(String plainText) {
  final normalized = plainText
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  if (normalized.isEmpty) return '';

  final paragraphs = normalized.split(RegExp(r'\n[ \t]*\n+'));
  return [
    for (var index = 0; index < paragraphs.length; index++)
      '<p style="margin:${index == paragraphs.length - 1 ? '0' : '0 0 $_paragraphGap 0'};">'
          '${const HtmlEscape().convert(paragraphs[index]).replaceAll('\n', '<br>')}'
          '</p>',
  ].join();
}
