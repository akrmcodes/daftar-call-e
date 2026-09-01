// Shared deep-link mint helpers (Stage 8.5).

import type { TokenKind } from "./deep_link_types.ts";
import { computeDeepLinkExpiresAt } from "./deep_link_types.ts";
import type { AdminClient } from "./sync_ops.ts";

/** Opaque token: UUID v4 without hyphens — 32 chars, 122 bits of entropy. */
export function mintOpaqueToken(): string {
  return crypto.randomUUID().replaceAll("-", "");
}

/** Redacts a token for logs: enough to correlate, not enough to redeem. */
export function tokenFingerprint(token: string): string {
  return `${token.slice(0, 6)}…(${token.length})`;
}

export function deepLinkBaseUrl(): string {
  const raw = Deno.env.get("DEEP_LINK_BASE_URL") ?? "https://daftar.app/i";
  return raw.endsWith("/") ? raw.slice(0, -1) : raw;
}

export function buildDeepLinkUrl(token: string): string {
  return `${deepLinkBaseUrl()}/${token}`;
}

export async function logDeepLinkEvent(
  admin: AdminClient,
  eventType:
    | "created"
    | "click"
    | "claim_ok"
    | "claim_terminal"
    | "renewal_requested",
  token: string | null,
  metadata?: Record<string, unknown>,
): Promise<void> {
  const { error } = await admin.from("deep_link_events").insert({
    token,
    event_type: eventType,
    metadata: metadata ?? null,
  });
  if (error) {
    // Analytics must never fail the caller's operation.
    console.error("deep_link_events_insert_failed:", error.message);
  }
}

export function mintExpiresAt(kind: TokenKind): Date {
  return computeDeepLinkExpiresAt(kind);
}
