/** Safe application errors mapped to the stable HTTP error envelope. */

export class ApplicationError extends Error {
  constructor(
    readonly code: string,
    readonly statusCode: number,
    message: string,
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
