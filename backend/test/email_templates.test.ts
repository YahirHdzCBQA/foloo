import assert from "node:assert/strict";
import test from "node:test";

import {
  appendFixedEmailFooter,
  contentNamesForEmail,
  defaultEmailTemplate,
  renderEmailPreview,
  validateEmailTemplate,
} from "../src/domain/email_templates.js";

const url = "https://example.org/u/opaque";

for (const language of ["es", "en"] as const) {
  for (const origin of ["event", "direct"] as const) {
    test(`${origin}/${language} default uses structured context without unsubscribe footer`, () => {
      const template = defaultEmailTemplate(origin, language);
      const rendered = renderEmailPreview(
        template,
        {
          nombre: "Ana",
          evento: "Expo Norte",
          lugar: "Café Centro",
          contenido: "Catálogo",
          nombreVendedor: "Sofía",
          empresaVendedor: "Foloo",
        },
        url,
      );
      assert.match(rendered.subject, /Ana/);
      assert.equal(
        template.subject,
        language === "es"
          ? "Damos seguimiento, {nombre}"
          : "Following up, {nombre}",
      );
      assert.match(
        rendered.plainText,
        origin === "event" ? /Expo Norte/ : /Café Centro/,
      );
      assert.match(rendered.plainText, /Catálogo/);
      assert.match(rendered.plainText, /Sofía/);
      assert.doesNotMatch(rendered.html, /unsubscribe|darte de baja|href=/i);
      assert.doesNotMatch(rendered.html, /<img|background|gradient/i);
    });
  }
}

test("rejects unknown and malformed variables, not arbitrary expressions", () => {
  const template = defaultEmailTemplate("event", "es");
  assert.throws(
    () => validateEmailTemplate({ ...template, body: "{dangerous}" }),
    /unsupported_email_variable/,
  );
  assert.throws(
    () => validateEmailTemplate({ ...template, body: "{nombre" }),
    /malformed_email_variable/,
  );
  assert.throws(
    () => validateEmailTemplate({ ...template, subject: "Hello\r\nBcc: x" }),
    /invalid_email_subject/,
  );
});

test("historical missing values never leak unresolved placeholders", () => {
  const template = defaultEmailTemplate("direct", "en");
  const rendered = renderEmailPreview(template, {}, url);
  assert.doesNotMatch(rendered.plainText, /\{[^}]+\}|null|undefined/);
  assert.doesNotMatch(rendered.plainText, /I'm sharing|great meeting you at/);
});

test("content names keep Unicode and use human readable conjunction", () => {
  assert.equal(
    contentNamesForEmail(["Catálogo", "Ficha técnica", "Visión"], "es"),
    "Catálogo, Ficha técnica y Visión",
  );
  assert.equal(contentNamesForEmail(["One", "Two"], "en"), "One and Two");
});

test("HTML escapes Lead data without appending an unsubscribe link", () => {
  const template = defaultEmailTemplate("event", "es");
  const preview = renderEmailPreview(template, { nombre: "<Ana & Co>" }, url);
  assert.match(preview.html, /&lt;Ana &amp; Co&gt;/);
  assert.doesNotMatch(preview.html, /href=/);
});

test("an offline frozen snapshot is preserved without a server footer", () => {
  const preview = appendFixedEmailFooter(
    {
      subject: "Snapshot original",
      plainText: "Cuerpo revisado sin conexión",
      html: "<p>Cuerpo revisado sin conexión</p>",
    },
    "es",
    "Expo Norte",
    url,
  );
  assert.equal(preview.subject, "Snapshot original");
  assert.match(preview.plainText, /^Cuerpo revisado sin conexión/);
  assert.equal(preview.plainText, "Cuerpo revisado sin conexión");
  assert.doesNotMatch(preview.html, /href=/);
});
