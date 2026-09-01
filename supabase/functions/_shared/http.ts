// ============================================================================
// Shared HTTP layer for Edge Functions (Stage 8.8)
// ============================================================================
// Single source of truth for CORS, JSON responses, typed errors and the
// error → status mapping. Previously each function re-implemented the mapping
// by comparing `error.message` against a hand-maintained list of strings, and
// the lists had drifted apart: invite-worker mapped "Missing claims" to 401
// while revoke-worker-invite mapped the same failure to 500.
// ============================================================================

/**
 * Stable machine-readable error codes. Clients branch on these; they are part
 * of the wire contract and must not be renamed without a client change.
 */
export type ErrorCode =
  | "unauthorized"
  | "forbidden"
  | "invalid_request"
  | "invalid_action"
  | "not_found"
  | "method_not_allowed"
  | "conflict"
  | "seat_cap_exceeded"
  | "device_cap_exceeded"
  | "sync_event_cap_exceeded"
  | "device_registration_failed"
  | "usage_counter_read_failed"
  | "usage_counter_write_failed"
  | "rate_limited"
  | "internal_error"
  | "service_unavailable";

/** Base class for errors that carry an HTTP status and a stable code. */
export class HttpError extends Error {
  readonly status: number;
  readonly code: ErrorCode;

  constructor(status: number, code: ErrorCode, message: string) {
    super(message);
    this.name = "HttpError";
    this.status = status;
    this.code = code;
  }
}

/** 401 — token missing, malformed, expired, or claims unusable. */
export class AuthError extends HttpError {
  constructor(message = "Authentication failed") {
    super(401, "unauthorized", message);
    this.name = "AuthError";
  }
}

/** 403 — authenticated but the workspace role is insufficient. */
export class ForbiddenError extends HttpError {
  constructor(message = "Forbidden") {
    super(403, "forbidden", message);
    this.name = "ForbiddenError";
  }
}

/** 400 — request body or query string failed validation. */
export class ValidationError extends HttpError {
  constructor(message: string, code: ErrorCode = "invalid_request") {
    super(400, code, message);
    this.name = "ValidationError";
  }
}

/** 409 — a cap or uniqueness invariant would be violated. */
export class ConflictError extends HttpError {
  constructor(message: string, code: ErrorCode = "conflict") {
    super(409, code, message);
    this.name = "ConflictError";
  }
}

/** 500 — an internal step failed; never surfaces the underlying text. */
export class InternalError extends HttpError {
  constructor(
    message = "Internal server error",
    code: ErrorCode = "internal_error",
  ) {
    super(500, code, message);
    this.name = "InternalError";
  }
}

/** 503 — a dependency or required secret is unavailable. */
export class ServiceUnavailableError extends HttpError {
  constructor(message = "Service unavailable") {
    super(503, "service_unavailable", message);
    this.name = "ServiceUnavailableError";
  }
}

const CORS_ALLOW_HEADERS =
  "authorization, x-client-info, apikey, content-type, x-device-id";

/**
 * Comma-separated origin allowlist. Unset (the default) keeps `*`, which is
 * correct for the native mobile clients: every endpoint is bearer-token
 * authenticated and none of them accept cookies, so `*` grants a browser
 * nothing it could not already do with a plain fetch. Set this once a browser
 * origin exists.
 */
function allowedOrigins(): string[] {
  return (Deno.env.get("EDGE_ALLOWED_ORIGINS") ?? "")
    .split(",")
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);
}

/** CORS headers for a specific request, honouring the origin allowlist. */
export function corsHeaders(req?: Request): Record<string, string> {
  const allowlist = allowedOrigins();
  const base: Record<string, string> = {
    "Access-Control-Allow-Headers": CORS_ALLOW_HEADERS,
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
  };

  if (allowlist.length === 0) {
    return { ...base, "Access-Control-Allow-Origin": "*" };
  }

  const origin = req?.headers.get("Origin") ?? "";
  return {
    ...base,
    Vary: "Origin",
    ...(allowlist.includes(origin)
      ? { "Access-Control-Allow-Origin": origin }
      : {}),
  };
}

/** Static headers for contexts with no request in scope. */
export const CORS_HEADERS: Record<string, string> = corsHeaders();

export function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
  req?: Request,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(req),
      "Content-Type": "application/json",
      ...extraHeaders,
    },
  });
}

/** Preflight response. */
export function optionsResponse(req?: Request): Response {
  return new Response("ok", { headers: corsHeaders(req) });
}

/** 405 with the standard body shape. */
export function methodNotAllowed(req?: Request): Response {
  return jsonResponse(
    { error: "Method not allowed", code: "method_not_allowed" },
    405,
    req,
  );
}

/** Opaque 401. Kept identical for every auth failure mode (anti-enumeration). */
export function authErrorResponse(req?: Request): Response {
  return jsonResponse(
    { error: "Authentication failed", code: "unauthorized" },
    401,
    req,
  );
}

/**
 * Maps any thrown value to a response. `HttpError` subclasses keep their status
 * and code; everything else collapses to an opaque 500 so internal exception
 * text can never reach a client.
 */
export function toErrorResponse(
  fnName: string,
  error: unknown,
  req?: Request,
): Response {
  if (error instanceof HttpError) {
    if (error.status >= 500) {
      console.error(`[${fnName}] ${error.code}:`, error.message);
    }
    return jsonResponse(
      { error: error.message, code: error.code },
      error.status,
      req,
    );
  }

  console.error(`[${fnName}] unhandled:`, error);
  return jsonResponse(
    { error: "Internal server error", code: "internal_error" },
    500,
    req,
  );
}
