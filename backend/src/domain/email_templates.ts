/** Pure FL-019 template contract: allowed variables, defaults and safe preview. */

export type EmailLanguage = "es" | "en";
export type EmailOrigin = "event" | "direct";

export const emailVariables = [
  "nombre",
  "apellido",
  "empresa",
  "puesto",
  "evento",
  "lugar",
  "contenido",
  "nombreVendedor",
  "empresaVendedor",
] as const;

export type EmailVariable = (typeof emailVariables)[number];
export type EmailValues = Partial<Record<EmailVariable, string>>;

export interface EmailTemplate {
  origin: EmailOrigin;
  language: EmailLanguage;
  subject: string;
  body: string;
  signature: string;
}

export interface EventEmailTemplate extends Omit<EmailTemplate, "origin"> {
  eventId: string;
}

export function validateEventEmailTemplate(template: EventEmailTemplate): void {
  validateEmailTemplate({ ...template, origin: "event" });
}

export interface EmailPreview {
  subject: string;
  plainText: string;
  html: string;
}

const knownVariables = new Set<string>(emailVariables);
const tokenPattern = /\{([^{}]+)\}/g;

/** Rejects arbitrary expressions, unknown tokens and malformed braces. */
export function validateEmailTemplate(template: EmailTemplate): void {
  for (const part of [template.subject, template.body, template.signature]) {
    const tokens = [...part.matchAll(tokenPattern)];
    for (const token of tokens) {
      if (!knownVariables.has(token[1]!)) {
        throw new Error("unsupported_email_variable");
      }
    }
    const withoutTokens = part.replace(tokenPattern, "");
    if (/[{}]/.test(withoutTokens)) {
      throw new Error("malformed_email_variable");
    }
  }
  if (/[\r\n]/.test(template.subject)) {
    throw new Error("invalid_email_subject");
  }
}

export function defaultEmailTemplate(
  origin: EmailOrigin,
  language: EmailLanguage,
): EmailTemplate {
  const context = origin === "event" ? "{evento}" : "{lugar}";
  if (language === "es") {
    return {
      origin,
      language,
      subject: "Damos seguimiento, {nombre}",
      body: [
        "Hola {nombre},",
        "",
        `Fue un gusto conocerte en ${context} y poder platicar contigo.`,
        "",
        "Te comparto {contenido}, como seguimiento a nuestra conversación.",
        "",
        "Quedo pendiente y espero que podamos seguir en contacto.",
      ].join("\n"),
      signature: "Saludos,\n{nombreVendedor}\n{empresaVendedor}",
    };
  }
  return {
    origin,
    language,
    subject: "Following up, {nombre}",
    body: [
      "Hi {nombre},",
      "",
      `It was great meeting you at ${context} and having the opportunity to talk.`,
      "",
      "I'm sharing {contenido} as a follow-up to our conversation.",
      "",
      "Feel free to reach out if you have any questions. I hope we can stay in touch.",
    ].join("\n"),
    signature: "Best,\n{nombreVendedor}\n{empresaVendedor}",
  };
}

/** Uses frozen Lead content names rather than current library state. */
export function contentNamesForEmail(
  names: readonly string[],
  language: EmailLanguage,
): string {
  const safe = names.map((name) => name.trim()).filter(Boolean);
  if (safe.length < 2) return safe[0] ?? "";
  const connector = language === "es" ? " y " : " and ";
  if (safe.length === 2) return safe.join(connector);
  return `${safe.slice(0, -1).join(", ")}${connector}${safe.at(-1)}`;
}

function escapedHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => {
    switch (character) {
      case "&":
        return "&amp;";
      case "<":
        return "&lt;";
      case ">":
        return "&gt;";
      case '"':
        return "&quot;";
      default:
        return "&#39;";
    }
  });
}

/** Converts reviewed plain text to stable, compact HTML for email clients. */
export function plainTextToEmailHtml(message: string): string {
  const normalized = message.replace(/\r\n?/g, "\n").trim();
  if (!normalized) return "";
  const paragraphs = normalized.split(/\n[ \t]*\n+/);
  return paragraphs
    .map((paragraph, index) => {
      const margin = index === paragraphs.length - 1 ? "0" : "0 0 1em 0";
      return `<p style="margin:${margin};">${escapedHtml(paragraph).replace(/\n/g, "<br>")}</p>`;
    })
    .join("");
}

/** Defensively resolves approved variables in one historical template part. */
export function renderEmailPart(part: string, values: EmailValues): string {
  return part.replace(tokenPattern, (_, key: EmailVariable) => {
    const value = values[key]?.trim() ?? "";
    return value === "null" || value === "undefined" ? "" : value;
  });
}

const legacyUnsubscribePath = "/v1/email/unsubscribe?";
const legacyFooterIntro =
  /^(Recibiste este correo como seguimiento|You received this email as a follow-up)/u;
const legacyFooterAction =
  /^(Si prefieres no recibir más comunicaciones|If you prefer not to receive further messages)/u;

/** Removes only the retired, server-generated footer from historical snapshots. */
export function withoutLegacyUnsubscribeFooter(
  preview: EmailPreview,
): EmailPreview {
  const lines = preview.plainText.trimEnd().split("\n");
  const tailStart = Math.max(0, lines.length - 5);
  const tail = lines.slice(tailStart);
  const hasLegacyLink = tail.some((line) =>
    line.includes(legacyUnsubscribePath),
  );
  if (hasLegacyLink) {
    const firstFooterLine = tail.findIndex(
      (line) =>
        legacyFooterIntro.test(line.trim()) ||
        legacyFooterAction.test(line.trim()),
    );
    lines.splice(
      tailStart + (firstFooterLine < 0 ? tail.length - 1 : firstFooterLine),
    );
  }
  const lowerHtml = preview.html.toLocaleLowerCase("en-US");
  const lastParagraphStart = lowerHtml.lastIndexOf("<p");
  const lastParagraph =
    lastParagraphStart < 0 ? "" : preview.html.slice(lastParagraphStart);
  const html = lastParagraph.includes(legacyUnsubscribePath)
    ? preview.html.slice(0, lastParagraphStart).trimEnd()
    : preview.html;
  return {
    subject: preview.subject.replace(/[\r\n]+/g, " ").trim(),
    plainText: lines.join("\n").trim(),
    html,
  };
}

/** Legacy helper retained for source compatibility; FL-019.5 adds no footer. */
export function appendFixedEmailFooter(
  preview: EmailPreview,
  _language: EmailLanguage,
  _context: string,
  _unsubscribeUrl: string,
): EmailPreview {
  return withoutLegacyUnsubscribeFooter({
    subject: preview.subject.replace(/[\r\n]+/g, " ").trim(),
    plainText: preview.plainText.trim(),
    html: preview.html,
  });
}

/** Renders the approved message without an unsubscribe footer (FL-019.5). */
export function renderEmailPreview(
  template: EmailTemplate,
  values: EmailValues,
  _legacyUnsubscribeUrl?: string,
): EmailPreview {
  validateEmailTemplate(template);
  const context =
    template.origin === "event" ? values.evento?.trim() : values.lugar?.trim();
  const subject = renderEmailPart(template.subject, values)
    .replace(/[\r\n]+/g, " ")
    .replace(/,\s*$/, "")
    .trim();
  let body = renderEmailPart(template.body, values);
  if (!context) {
    body = body
      .split("\n")
      .filter((line) =>
        template.language === "es"
          ? !line.startsWith("Fue un gusto conocerte en ")
          : !line.startsWith("It was great meeting you at "),
      )
      .join("\n");
  }
  if (!values.contenido?.trim()) {
    body = body
      .split("\n")
      .filter((line) =>
        template.language === "es"
          ? !line.startsWith("Te comparto ")
          : !line.startsWith("I'm sharing "),
      )
      .join("\n");
  }
  const signature = renderEmailPart(template.signature, values);
  const message = `${body.trim()}\n\n${signature.trim()}`.trim();
  const plainText = message;
  const htmlMessage = plainTextToEmailHtml(message);
  return { subject, plainText, html: htmlMessage };
}
