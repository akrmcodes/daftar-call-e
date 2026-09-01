// ============================================================================
// Shared types: Deep-Link & Attribution Service (Stage 8.6 / 8.6.1)
// ============================================================================
// Mirrors public.token_kind, public.token_state, and deep_link_tokens row.
// Typed claim results for claim-deep-link (discriminated union).
// ============================================================================

/** Mirrors `public.token_kind` ENUM. */
export type TokenKind = "share" | "referral" | "worker_invite";

/** Mirrors `public.token_state` ENUM. */
export type TokenState =
  | "active"
  | "claimed"
  | "expired"
  | "revoked"
  | "superseded";

export const TOKEN_KINDS = [
  "share",
  "referral",
  "worker_invite",
] as const satisfies readonly TokenKind[];

export const TOKEN_STATES = [
  "active",
  "claimed",
  "expired",
  "revoked",
  "superseded",
] as const satisfies readonly TokenState[];

export function isTokenKind(value: string): value is TokenKind {
  return (TOKEN_KINDS as readonly string[]).includes(value);
}

export function isTokenState(value: string): value is TokenState {
  return (TOKEN_STATES as readonly string[]).includes(value);
}

/** Default TTL in hours per kind (§8.6.1). */
export const DEEP_LINK_TTL_HOURS: Record<TokenKind, number> = {
  worker_invite: 72,
  share: 30 * 24,
  referral: 30 * 24,
};

/** Computes expires_at for a newly minted token. */
export function computeDeepLinkExpiresAt(
  kind: TokenKind,
  now: Date = new Date(),
): Date {
  const hours = DEEP_LINK_TTL_HOURS[kind];
  return new Date(now.getTime() + hours * 60 * 60 * 1000);
}

// ── Intent payload shapes (JSONB; kind lives on the row column) ──────────────

export interface WorkerInviteIntent {
  invited_email: string;
  role: "editor" | "viewer";
  member_id: string;
}

export interface ShareIntent {
  contact_id: string;
}

export interface ReferralIntent {
  referrer_id: string;
}

export type DeepLinkIntentPayload =
  | WorkerInviteIntent
  | ShareIntent
  | ReferralIntent;

/** Mirrors `deep_link_tokens` row (read from Supabase). */
export interface DeepLinkTokenRow {
  token: string;
  kind: TokenKind;
  intent_payload: DeepLinkIntentPayload;
  workspace_id: string | null;
  created_by: string | null;
  state: TokenState;
  expires_at: string;
  claimed_by: string | null;
  claimed_at: string | null;
  created_at: string;
}

// ── Typed claim results (§8.6.1) ────────────────────────────────────────────

export type DeepLinkClaimedBy = "by_you" | "by_other";

/** Full internal claim result — all discriminants visible to Edge Functions. */
export type DeepLinkClaimResult =
  | { status: "ok"; kind: TokenKind; intent: DeepLinkIntentPayload }
  | { status: "expired" }
  | { status: "revoked" }
  | { status: "not_found" }
  | { status: "already_claimed"; claimed_by: DeepLinkClaimedBy };

/**
 * Wire shape for unauthenticated callers.
 * Anti-enumeration: `not_found` collapses to `revoked` (§8.6.1).
 */
export type AnonymousDeepLinkClaimResult =
  | { status: "ok"; kind: TokenKind; intent: DeepLinkIntentPayload }
  | { status: "expired" }
  | { status: "revoked" }
  | { status: "already_claimed"; claimed_by: DeepLinkClaimedBy };

/** Collapses `not_found` → `revoked` for anonymous API responses. */
export function toAnonymousClaimResult(
  result: DeepLinkClaimResult,
): AnonymousDeepLinkClaimResult {
  if (result.status === "not_found") {
    return { status: "revoked" };
  }
  return result;
}
