/** Runtime request schemas protect PostgreSQL from invalid mobile payloads. */

import { z } from "zod";

const nullableText = (max: number) =>
  z.string().trim().max(max).nullable().optional();

// CAP-03: keep the API's syntactic email rule aligned with the mobile form.
// Delivery/reputation policy remains a later server-side concern (SAL-07).
const leadEmailSchema = z
  .string()
  .trim()
  .regex(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
  .nullable()
  .optional();

export const profileSchema = z.object({
  name: z.string().trim().min(1).max(160),
  company: z.string().trim().min(1).max(160),
  position: nullableText(160),
  phone: nullableText(40),
  photoUrl: z.url().nullable().optional(),
});

const eventFields = {
  id: z.uuid(),
  name: z.string().trim().min(1).max(160),
  startsAt: z.iso.datetime({ offset: true }),
  endsAt: z.iso.datetime({ offset: true }),
};

export const eventSchema = z
  .object(eventFields)
  .refine((value) => Date.parse(value.endsAt) >= Date.parse(value.startsAt), {
    message: "endsAt must be on or after startsAt",
    path: ["endsAt"],
  });

export const eventUpdateSchema = z
  .object({
    name: eventFields.name,
    startsAt: eventFields.startsAt,
    endsAt: eventFields.endsAt,
    revision: z.number().int().positive(),
  })
  .refine((value) => Date.parse(value.endsAt) >= Date.parse(value.startsAt), {
    message: "endsAt must be on or after startsAt",
    path: ["endsAt"],
  });
export const eventDeleteSchema = z.object({
  revision: z.number().int().positive(),
});

export const leadSchema = z
  .object({
    id: z.uuid(),
    capturedAt: z.iso.datetime({ offset: true }),
    origin: z.enum(["event", "direct"]),
    eventId: z.uuid().nullable().optional(),
    place: nullableText(240),
    firstName: z.string().trim().min(1).max(160),
    lastName: nullableText(160),
    position: nullableText(160),
    company: z.string().trim().min(1).max(160),
    email: leadEmailSchema,
    phone: nullableText(40),
    leadType: z.enum(["customer", "partner", "supplier"]),
    interest: z.enum(["low", "medium", "high"]),
    writtenNote: nullableText(10_000),
    commercialFolio: nullableText(80),
  })
  .superRefine((value, context) => {
    if (value.origin === "event" && !value.eventId) {
      context.addIssue({
        code: "custom",
        path: ["eventId"],
        message: "eventId is required for event leads",
      });
    }
    if (value.origin === "direct" && !value.place) {
      context.addIssue({
        code: "custom",
        path: ["place"],
        message: "place is required for direct leads",
      });
    }
    if (!value.email && !value.phone) {
      context.addIssue({
        code: "custom",
        path: ["email"],
        message: "email or phone is required",
      });
    }
  });

export const leadUpdateSchema = z
  .object({
    revision: z.number().int().positive(),
    firstName: z.string().trim().min(1).max(160),
    lastName: nullableText(160),
    position: nullableText(160),
    company: z.string().trim().min(1).max(160),
    email: leadEmailSchema,
    phone: nullableText(40),
    leadType: z.enum(["customer", "partner", "supplier"]),
    interest: z.enum(["low", "medium", "high"]),
    writtenNote: nullableText(10_000),
    place: nullableText(240),
  })
  .superRefine((value, context) => {
    if (!value.email && !value.phone) {
      context.addIssue({
        code: "custom",
        path: ["email"],
        message: "email or phone is required",
      });
    }
  });

const mediaBaseSchema = z.object({
  id: z.uuid(),
  kind: z.enum(["business_card", "reference_image", "voice_note"]),
  contentType: z.enum(["image/jpeg", "audio/m4a"]),
  byteSize: z
    .number()
    .int()
    .positive()
    .max(100 * 1024 * 1024),
  capturedAt: z.iso.datetime({ offset: true }),
  durationMs: z.number().int().min(0).nullable().optional(),
  sha256: z
    .string()
    .regex(/^[a-f0-9]{64}$/i)
    .nullable()
    .optional(),
});

export const mediaSchema = mediaBaseSchema.superRefine((value, context) => {
  const expected = value.kind === "voice_note" ? "audio/m4a" : "image/jpeg";
  if (value.contentType !== expected) {
    context.addIssue({
      code: "custom",
      path: ["contentType"],
      message: `contentType must be ${expected} for ${value.kind}`,
    });
  }
  // Infrastructure abuse guard, not the unresolved product/UX duration limit.
  const maxBytes = value.kind === "voice_note" ? 100 : 25;
  if (value.byteSize > maxBytes * 1024 * 1024) {
    context.addIssue({
      code: "too_big",
      origin: "number",
      maximum: maxBytes * 1024 * 1024,
      inclusive: true,
      path: ["byteSize"],
      message: `${value.kind} exceeds the technical upload ceiling`,
    });
  }
});
