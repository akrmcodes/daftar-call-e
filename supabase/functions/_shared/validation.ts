// ============================================================================
// Shared request validation (Stage 8.8)
// ============================================================================
// Every value that reaches the database or a rate-limit bucket key passes
// through here first. Unbounded caller-controlled strings previously flowed
// into `rate_limit_buckets.bucket_key` (its primary key), letting a caller grow
// that table without limit, and into `audit_logs.logged_at`, where an
// unparseable value produced a raw Postgres error instead of a 400.
// ============================================================================

import { ValidationError } from "./http.ts";

/** Opaque deep-link tokens are 32 hex chars (`crypto.randomUUID()` de-hyphenated). */
export const TOKEN_MIN_LENGTH = 32;
export const TOKEN_MAX_LENGTH = 128;

export const EMAIL_MAX_LENGTH = 254;
export const DEVICE_ID_MAX_LENGTH = 128;
export const ENTITY_ID_MAX_LENGTH = 128;
export const USER_AGENT_MAX_LENGTH = 256;

/** How far outside "now" a client-supplied op timestamp may sit. */
export const LOGGED_AT_MAX_FUTURE_MS = 24 * 60 * 60 * 1000;
export const LOGGED_AT_MAX_PAST_MS = 10 * 365 * 24 * 60 * 60 * 1000;

/** Lowercases and trims. Does not validate — use {@link requireEmail}. */
export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

/**
 * Deliberately permissive: one `@`, non-empty local part, a dotted domain, no
 * whitespace. Stricter grammars reject valid real-world addresses, and the
 * authoritative check is that the invitee can actually sign in with it.
 */
const EMAIL_PATTERN = /^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$/;

export function isValidEmail(value: string): boolean {
  return value.length <= EMAIL_MAX_LENGTH && EMAIL_PATTERN.test(value);
}

/** Returns a normalized email or throws a 400. */
export function requireEmail(value: unknown, field: string): string {
  if (typeof value !== "string") {
    throw new ValidationError(`Invalid ${field}`);
  }
  const normalized = normalizeEmail(value);
  if (!isValidEmail(normalized)) {
    throw new ValidationError(`Invalid ${field}`);
  }
  return normalized;
}

/** Returns a trimmed string within [1, maxLength] or throws a 400. */
export function requireString(
  value: unknown,
  field: string,
  maxLength: number,
): string {
  if (typeof value !== "string") {
    throw new ValidationError(`Invalid ${field}`);
  }
  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed.length > maxLength) {
    throw new ValidationError(`Invalid ${field}`);
  }
  return trimmed;
}

/** Trimmed string within bounds, or null when absent. Throws only on overflow. */
export function optionalString(
  value: unknown,
  field: string,
  maxLength: number,
): string | null {
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new ValidationError(`Invalid ${field}`);
  }
  const trimmed = value.trim();
  if (trimmed.length === 0) return null;
  if (trimmed.length > maxLength) {
    throw new ValidationError(`Invalid ${field}`);
  }
  return trimmed;
}

/** Truncates for storage/logging rather than rejecting. */
export function truncate(value: string, maxLength: number): string {
  return value.length <= maxLength ? value : value.slice(0, maxLength);
}

/** Deep-link tokens: length-bounded, hex/base64url alphabet only. */
export function isValidOpaqueToken(value: string): boolean {
  return value.length >= TOKEN_MIN_LENGTH &&
    value.length <= TOKEN_MAX_LENGTH &&
    /^[A-Za-z0-9_-]+$/.test(value);
}

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function isUuid(value: string): boolean {
  return UUID_PATTERN.test(value);
}

export function requireUuid(value: unknown, field: string): string {
  if (typeof value !== "string" || !isUuid(value.trim())) {
    throw new ValidationError(`Invalid ${field}`);
  }
  return value.trim();
}

/**
 * INTEGER MONEY. Monetary amounts are integers in the smallest currency unit;
 * a fractional or out-of-range value is a client bug that must never reach the
 * ledger. `Number()` coercion previously let `1500.7` through to a BIGINT
 * column, where it failed inside a swallowed database error.
 */
export function isValidMoneyAmount(value: unknown): value is number {
  return typeof value === "number" &&
    Number.isSafeInteger(value) &&
    value > 0;
}

/**
 * Parses an ISO-8601 instant and returns it normalized to UTC.
 * Rejects unparseable values and values implausibly far from now.
 */
export function parseInstant(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new ValidationError(`Invalid ${field}`);
  }
  const parsed = Date.parse(value);
  if (!Number.isFinite(parsed)) {
    throw new ValidationError(`Invalid ${field}`);
  }
  const now = Date.now();
  if (parsed > now + LOGGED_AT_MAX_FUTURE_MS) {
    throw new ValidationError(`${field} is too far in the future`);
  }
  if (parsed < now - LOGGED_AT_MAX_PAST_MS) {
    throw new ValidationError(`${field} is too far in the past`);
  }
  return new Date(parsed).toISOString();
}

/**
 * Sanitizes a value before it becomes part of a `rate_limit_buckets.bucket_key`.
 * Bounds the length and strips characters outside a safe set so a caller cannot
 * mint unbounded distinct primary keys or smuggle separators into the key
 * namespace.
 */
export function bucketKeySegment(value: string, maxLength = 64): string {
  const cleaned = value.replace(/[^A-Za-z0-9._@-]/g, "_");
  return truncate(cleaned, maxLength);
}

/** Parses a JSON body, mapping malformed input to 400 rather than 500. */
export async function readJsonBody<T>(req: Request): Promise<T> {
  try {
    const parsed = await req.json();
    if (parsed === null || typeof parsed !== "object") {
      throw new ValidationError("Invalid request body");
    }
    return parsed as T;
  } catch (error) {
    if (error instanceof ValidationError) throw error;
    throw new ValidationError("Invalid request body");
  }
}
