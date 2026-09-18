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
      subject: "Un gusto conocerte, {nombre}",
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
    subject: "Nice meeting you, {nombre}",
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

function renderPart(part: string, values: EmailValues): string {
  return part.replace(tokenPattern, (_, key: EmailVariable) => {
    const value = values[key]?.trim() ?? "";
    return value === "null" || value === "undefined" ? "" : value;
  });
}

function footer(
  language: EmailLanguage,
  context: string,
  unsubscribeUrl: string,
): { plain: string; html: string } {
  const introduction =
    language === "es"
      ? context
        ? `Recibiste este correo como seguimiento a nuestro encuentro en ${context}.`
        : "Recibiste este correo como seguimiento a nuestro encuentro."
      : context
        ? `You received this email as a follow-up to our meeting at ${context}.`
        : "You received this email as a follow-up to our meeting.";
  const action =
    language === "es"
      ? "Si prefieres no recibir más comunicaciones, puedes darte de baja aquí."
      : "If you prefer not to receive further messages, you can unsubscribe here.";
  const label = language === "es" ? "darte de baja aquí" : "unsubscribe here";
  const actionPrefix = action.slice(0, action.indexOf(label));
  return {
    plain: `${introduction}\n${action}\n${unsubscribeUrl}`,
    html: `<p>${escapedHtml(introduction)}<br>${escapedHtml(actionPrefix)}<a href="${escapedHtml(unsubscribeUrl)}">${escapedHtml(label)}</a>.</p>`,
  };
}

/** Renders an immutable fixed footer; caller must supply a Foloo HTTPS URL. */
export function renderEmailPreview(
  template: EmailTemplate,
  values: EmailValues,
  unsubscribeUrl: string,
): EmailPreview {
  validateEmailTemplate(template);
  const url = new URL(unsubscribeUrl);
  if (url.protocol !== "https:") throw new Error("invalid_unsubscribe_url");
  const context =
    template.origin === "event" ? values.evento?.trim() : values.lugar?.trim();
  const subject = renderPart(template.subject, values)
    .replace(/[\r\n]+/g, " ")
    .replace(/,\s*$/, "")
    .trim();
  let body = renderPart(template.body, values);
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
  const signature = renderPart(template.signature, values);
  const message = `${body.trim()}\n\n${signature.trim()}`.trim();
  const fixed = footer(template.language, context ?? "", unsubscribeUrl);
  const plainText = `${message}\n\n${fixed.plain}`;
  const htmlMessage = message
    .split(/\n\s*\n/)
    .map(
      (paragraph) => `<p>${escapedHtml(paragraph).replace(/\n/g, "<br>")}</p>`,
    )
    .join("");
  return { subject, plainText, html: `${htmlMessage}${fixed.html}` };
}
