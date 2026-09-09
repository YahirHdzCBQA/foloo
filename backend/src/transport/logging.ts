/** Emits structured, minimal CloudWatch-compatible events without request bodies. */

export function logEvent(
  level: "info" | "error",
  event: Record<string, unknown>,
): void {
  const entry = JSON.stringify({
    level,
    timestamp: new Date().toISOString(),
    ...event,
  });
  if (level === "error") console.error(entry);
  else console.info(entry);
}
