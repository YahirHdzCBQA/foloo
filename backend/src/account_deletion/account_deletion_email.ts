/** Minimal bilingual transactional copy for Account Deletion notifications. */

import type { DeletionLocale } from "./account_deletion_workflow.js";

export type AccountDeletionEmail = Readonly<{
  subject: string;
  plainBody: string;
  htmlBody: string;
}>;

export function accountDeletionRequestEmail(
  locale: DeletionLocale,
  supportAddress: string,
): AccountDeletionEmail {
  return locale === "es"
    ? render("Recibimos tu solicitud de eliminación", [
        "Recibimos tu solicitud de eliminación de cuenta de Foloo.",
        "La solicitud está en proceso. Este mensaje no confirma que la eliminación haya terminado.",
        "La eliminación es irreversible y el acceso quedará bloqueado.",
        `Si necesitas ayuda, escribe a ${supportAddress}.`,
      ])
    : render("We received your account deletion request", [
        "We received your Foloo account deletion request.",
        "The request is being processed. This message does not confirm completion.",
        "Deletion is irreversible and access will be blocked.",
        `For help, contact ${supportAddress}.`,
      ]);
}

export function accountDeletionCompletedEmail(
  locale: DeletionLocale,
  supportAddress: string,
): AccountDeletionEmail {
  return locale === "es"
    ? render("Tu cuenta de Foloo fue eliminada", [
        "La eliminación de tu cuenta de Foloo se completó.",
        "La operación es irreversible y ya no puedes acceder con esa identidad.",
        "Podrás registrarte después del periodo de bloqueo como una cuenta completamente nueva, sin recuperar datos anteriores.",
        `Si necesitas ayuda, escribe a ${supportAddress}.`,
      ])
    : render("Your Foloo account was deleted", [
        "Your Foloo account deletion is complete.",
        "The operation is irreversible and that identity can no longer access Foloo.",
        "After the registration block ends, you may sign up as a completely new account without recovering prior data.",
        `For help, contact ${supportAddress}.`,
      ]);
}

function render(
  subject: string,
  paragraphs: readonly string[],
): AccountDeletionEmail {
  const escaped = paragraphs.map(escapeHtml);
  return {
    subject,
    plainBody: paragraphs.join("\n\n"),
    htmlBody: escaped
      .map((paragraph) => `<p style="margin:0 0 12px">${paragraph}</p>`)
      .join(""),
  };
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
