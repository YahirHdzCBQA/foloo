/** Locks down safe API error mapping without exposing internal details. */

import assert from "node:assert/strict";
import test from "node:test";
import { z } from "zod";

import { ApplicationError } from "../src/application/errors.js";
import { errorResponse } from "../src/transport/error_response.js";

test("maps validation errors to the stable envelope", () => {
  let failure: unknown;
  try {
    z.uuid().parse("bad");
  } catch (error) {
    failure = error;
  }
  const response = errorResponse(failure, "request-1");
  assert.equal(response.statusCode, 400);
  assert.deepEqual(JSON.parse(response.body ?? "{}"), {
    error: {
      code: "validation_error",
      message: "Request validation failed.",
      requestId: "request-1",
    },
  });
});

test("does not leak database or unexpected error messages", () => {
  const response = errorResponse(
    new Error("password=secret database detail"),
    "request-2",
  );
  assert.equal(response.statusCode, 500);
  assert.doesNotMatch(response.body ?? "", /secret|database detail/);
});

test("preserves safe application status codes", () => {
  const response = errorResponse(
    new ApplicationError("conflict", 409, "Safe conflict."),
    "request-3",
  );
  assert.equal(response.statusCode, 409);
});
