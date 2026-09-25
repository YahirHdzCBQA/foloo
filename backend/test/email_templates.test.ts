import assert from "node:assert/strict";
import test from "node:test";

import {
  appendFixedEmailFooter,
  contentNamesForEmail,
  defaultEmailTemplate,
  renderEmailPreview,
  validateEmailTemplate,
  withoutLegacyUnsubscribeFooter,
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
      assert.doesNotMatch(rendered.html, /<br><br>|<\/p><br>/i);
      assert.match(rendered.html, /<p style="margin:0 0 1em 0;">/);
      assert.match(rendered.html, /<p style="margin:0;">/);
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

for (const legacy of [
  {
    language: "es",
    intro: "Recibiste este correo como seguimiento a nuestro encuentro.",
    action:
      "Si prefieres no recibir más comunicaciones, puedes darte de baja aquí.",
  },
  {
    language: "en",
    intro: "You received this email as a follow-up to our meeting.",
    action:
      "If you prefer not to receive further messages, you can unsubscribe here.",
  },
] as const) {
  test(`removes a frozen ${legacy.language} legacy footer without altering the message`, () => {
    const unsubscribeUrl =
      "https://api.example/v1/email/unsubscribe?token=opaque";
    const preview = withoutLegacyUnsubscribeFooter({
      subject: "Original subject",
      plainText: [
        "Message body",
        "",
        "Seller signature",
        "",
        legacy.intro,
        legacy.action,
        unsubscribeUrl,
      ].join("\n"),
      html: [
        "<p>Message body</p>",
        "<p>Seller signature</p>",
        `<p>${legacy.intro}<br>${legacy.action}<a href="${unsubscribeUrl}">link</a>.</p>`,
      ].join(""),
    });

    assert.equal(preview.plainText, "Message body\n\nSeller signature");
    assert.equal(preview.html, "<p>Message body</p><p>Seller signature</p>");
    assert.doesNotMatch(
      preview.plainText,
      /unsubscribe|darte de baja|\/v1\/email\/unsubscribe/i,
    );
    assert.doesNotMatch(
      preview.html,
      /unsubscribe|darte de baja|\/v1\/email\/unsubscribe/i,
    );
  });
}
