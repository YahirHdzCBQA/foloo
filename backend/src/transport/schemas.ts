/** Runtime request schemas protect PostgreSQL from invalid mobile payloads. */

import { z } from "zod";

const nullableText = (max: number) =>
  z.string().trim().max(max).nullable().optional();

export const profileSchema = z.object({
  name: z.string().trim().min(1).max(160),
  company: z.string().trim().min(1).max(160),
  position: nullableText(160),
  phone: nullableText(40),
  photoUrl: z.url().nullable().optional(),
});

export const eventSchema = z
  .object({
    id: z.uuid(),
    name: z.string().trim().min(1).max(160),
    startsAt: z.iso.datetime({ offset: true }),
    endsAt: z.iso.datetime({ offset: true }),
  })
  .refine((value) => Date.parse(value.endsAt) >= Date.parse(value.startsAt), {
    message: "endsAt must be on or after startsAt",
    path: ["endsAt"],
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
    email: z.email().nullable().optional(),
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

export const mediaSchema = z.object({
  id: z.uuid(),
  kind: z.enum(["business_card", "reference_image", "voice_note"]),
  contentType: z.string().trim().min(1).max(120),
  byteSize: z.number().int().min(0),
  capturedAt: z.iso.datetime({ offset: true }),
  durationMs: z.number().int().min(0).nullable().optional(),
  sha256: z
    .string()
    .regex(/^[a-f0-9]{64}$/i)
    .nullable()
    .optional(),
});
