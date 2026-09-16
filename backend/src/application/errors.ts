/** Safe application errors mapped to the stable HTTP error envelope. */

export class ApplicationError extends Error {
  constructor(
    readonly code: string,
    readonly statusCode: number,
    message: string,
    readonly diagnosticCode?: string,
  ) {
    super(message);
    this.name = "ApplicationError";
  }
}

export const unauthorized = () =>
  new ApplicationError("unauthenticated", 401, "Authentication is required.");

export const notFound = (resource: string) =>
  new ApplicationError("not_found", 404, `${resource} was not found.`);

export const conflict = (message: string) =>
  new ApplicationError("conflict", 409, message);

export const revisionConflict = () =>
  new ApplicationError(
    "revision_conflict",
    409,
    "The lead changed remotely. The local edit was preserved and can be retried.",
  );
