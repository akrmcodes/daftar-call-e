// ============================================================================
// Shared sync JWT verification (Stage 8.5+)
// ============================================================================
// Verifies the HS256 tokens minted by verify-google-token.
//
// Verification order is security-critical and must not be reordered:
//   1. structural parse            4. signature verification
//   2. header alg pin (HS256)      5. temporal claims (exp / iat / nbf)
//   3. header typ check            6. identity claims
// No claim is trusted before step 4 succeeds, which forecloses both
// algorithm-confusion and `alg: none`.
// ============================================================================

import { AuthError, ServiceUnavailableError } from "./http.ts";

const CLOCK_SKEW_SECONDS = 30;

/**
 * HMAC-SHA256 keys shorter than the 256-bit block offer less than the nominal
 * security of the construction. Supabase-issued secrets are far longer; this
 * only catches a misconfigured deployment.
 */
const MIN_JWT_SECRET_LENGTH = 32;

export interface SyncJwtClaims {
  workspace_id: string;
  workspace_role: WorkspaceRole;
  identity_hash: string;
}

export type WorkspaceRole = "owner" | "editor" | "viewer";

const WORKSPACE_ROLES: readonly string[] = ["owner", "editor", "viewer"];

interface SyncJwtPayload {
  sub: string;
  iss: string;
  aud: string;
  iat: number;
  exp: number;
  role: string;
  workspace_id: string;
  workspace_role: string;
  identity_hash: string;
}

function base64urlDecode(input: string): Uint8Array {
  const base64 = input.replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64 + "=".repeat((4 - (base64.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

/**
 * Deno/TypeScript 6 types `Uint8Array.buffer` as `ArrayBufferLike`.
 * WebCrypto `subtle.verify` requires a true `ArrayBuffer` view source.
 */
function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(
    bytes.byteOffset,
    bytes.byteOffset + bytes.byteLength,
  ) as ArrayBuffer;
}

/** Reads the bearer token from the Authorization header, or null. */
export function extractBearerToken(req: Request): string | null {
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) return null;
  const token = auth.slice(7).trim();
  return token.length > 0 ? token : null;
}

function decodeJsonSegment(segment: string, label: string): unknown {
  try {
    return JSON.parse(new TextDecoder().decode(base64urlDecode(segment)));
  } catch {
    throw new AuthError(`Invalid token ${label}`);
  }
}

/**
 * Verifies a sync JWT and returns its trusted claims.
 *
 * @throws {AuthError} for every rejection reason. Callers must surface a single
 *   opaque 401 so the failure mode is not observable to an attacker.
 */
export async function verifySyncJwt(
  token: string,
  secret: string,
): Promise<SyncJwtClaims> {
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new AuthError("Invalid token format");
  }

  const [headerB64, payloadB64, signatureB64] = parts;

  const header = decodeJsonSegment(headerB64, "header") as {
    alg?: unknown;
    typ?: unknown;
  };

  // Pin before any signature work: rejects `none` and RS256 key confusion.
  if (header.alg !== "HS256") {
    throw new AuthError("Unsupported algorithm");
  }
  if (header.typ !== undefined && header.typ !== "JWT") {
    throw new AuthError("Invalid token type");
  }

  const signingInput = `${headerB64}.${payloadB64}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );

  const signatureBytes = base64urlDecode(signatureB64);
  const isValid = await crypto.subtle.verify(
    "HMAC",
    key,
    toArrayBuffer(signatureBytes),
    new TextEncoder().encode(signingInput),
  );

  if (!isValid) {
    throw new AuthError("Invalid signature");
  }

  // Everything below this line is now attributable to the signing key.
  const payload = decodeJsonSegment(payloadB64, "payload") as SyncJwtPayload;

  if (typeof payload.exp !== "number" || !Number.isFinite(payload.exp)) {
    throw new AuthError("Invalid exp claim");
  }
  if (typeof payload.iat !== "number" || !Number.isFinite(payload.iat)) {
    throw new AuthError("Invalid iat claim");
  }

  const nowSeconds = Math.floor(Date.now() / 1000);
  if (payload.exp < nowSeconds - CLOCK_SKEW_SECONDS) {
    throw new AuthError("Token expired");
  }
  if (payload.iat > nowSeconds + CLOCK_SKEW_SECONDS) {
    throw new AuthError("Token issued in the future");
  }

  const nbf = (payload as { nbf?: unknown }).nbf;
  if (nbf !== undefined) {
    if (typeof nbf !== "number" || !Number.isFinite(nbf)) {
      throw new AuthError("Invalid nbf claim");
    }
    if (nbf > nowSeconds + CLOCK_SKEW_SECONDS) {
      throw new AuthError("Token not yet valid");
    }
  }

  if (payload.iss !== "supabase") {
    throw new AuthError("Invalid issuer");
  }
  if (payload.aud !== "authenticated") {
    throw new AuthError("Invalid audience");
  }
  if (payload.role !== "authenticated") {
    throw new AuthError("Invalid PostgREST role");
  }

  const workspaceId = payload.workspace_id;
  const workspaceRole = payload.workspace_role;
  const identityHash = payload.identity_hash ?? payload.sub;

  if (
    typeof workspaceId !== "string" || workspaceId.length === 0 ||
    typeof identityHash !== "string" || identityHash.length === 0 ||
    typeof workspaceRole !== "string"
  ) {
    throw new AuthError("Missing claims");
  }

  if (!WORKSPACE_ROLES.includes(workspaceRole)) {
    throw new AuthError("Invalid workspace role");
  }

  return {
    workspace_id: workspaceId,
    workspace_role: workspaceRole as WorkspaceRole,
    identity_hash: identityHash,
  };
}

/**
 * Resolves the HMAC signing secret from the runtime environment.
 * Returns undefined when absent or implausibly short.
 */
export function resolveSupabaseJwtSecret(): string | undefined {
  const secret = Deno.env.get("SUPABASE_JWT_SECRET") ??
    Deno.env.get("SUPABASE_INTERNAL_JWT_SECRET") ??
    Deno.env.get("JWT_SECRET");

  if (!secret) return undefined;
  if (secret.length < MIN_JWT_SECRET_LENGTH) {
    console.error(
      "sync_jwt_secret_too_short",
      JSON.stringify({ min_length: MIN_JWT_SECRET_LENGTH }),
    );
    return undefined;
  }
  return secret;
}

/** Verifies an optional bearer token. Returns null instead of throwing. */
export async function tryRequireSyncJwt(
  req: Request,
): Promise<SyncJwtClaims | null> {
  const token = extractBearerToken(req);
  if (!token) return null;
  const secret = resolveSupabaseJwtSecret();
  if (!secret) return null;
  try {
    return await verifySyncJwt(token, secret);
  } catch {
    return null;
  }
}

/**
 * Verifies a required bearer token.
 *
 * @throws {AuthError} when the token is missing or invalid.
 * @throws {ServiceUnavailableError} when the signing secret is unconfigured —
 *   a deployment fault, not a caller fault, so it must not read as a 401.
 */
export async function requireSyncJwt(req: Request): Promise<SyncJwtClaims> {
  const token = extractBearerToken(req);
  if (!token) {
    throw new AuthError();
  }

  const secret = resolveSupabaseJwtSecret();
  if (!secret) {
    console.error("sync_jwt_secret_missing");
    throw new ServiceUnavailableError("Server configuration error");
  }

  return await verifySyncJwt(token, secret);
}

/** True for roles permitted to mutate business data. */
export function isWritableRole(role: string): boolean {
  return role === "owner" || role === "editor";
}
