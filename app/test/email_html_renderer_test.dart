import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/models/email_template.dart';
import 'package:foloo/services/email_html_renderer.dart';

void main() {
  test('paragraph gaps do not combine blank br tags with p margins', () {
    const message =
        'Hola Juan,\n\nPrimer párrafo.\n\nSegundo párrafo.\n\nSaludos,\nYahir';

    final html = renderPlainTextEmailHtml(message);

    expect(html, isNot(contains('</p><br>')));
    expect(html, isNot(contains('<br><br>')));
    expect(
      html,
      '<p style="margin:0 0 1em 0;">Hola Juan,</p>'
      '<p style="margin:0 0 1em 0;">Primer párrafo.</p>'
      '<p style="margin:0 0 1em 0;">Segundo párrafo.</p>'
      '<p style="margin:0;">Saludos,<br>Yahir</p>',
    );
  });

  test('all base variants use the same compact escaped structure', () {
    for (final language in ['es', 'en']) {
      for (final origin in ['event', 'direct']) {
        final template = FolooEmailDefaults.forContext(origin, language);
        final html = renderPlainTextEmailHtml(
          '${template.body}\n\n${template.signature}',
        );

        expect(html, isNot(contains('</p><br>')));
        expect(html, isNot(contains('<br><br>')));
        expect(html, contains('<p style="margin:0 0 1em 0;">'));
        expect(html, contains('<p style="margin:0;">'));
      }
    }
  });

  test('HTML escaping and CRLF normalization preserve visible text', () {
    expect(
      renderPlainTextEmailHtml('Hola <Juan>\r\nEquipo & Ventas'),
      '<p style="margin:0;">Hola &lt;Juan&gt;<br>Equipo &amp; Ventas</p>',
    );
  });
}
