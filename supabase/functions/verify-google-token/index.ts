// ============================================================================
// Edge Function: verify-google-token
// ============================================================================
// Stage 8.2 — Auth Bridge (Google Sign-In → Custom Sync JWT)
//
// ARCHITECTURE:
//   1. Client sends Google ID Token (from Google Sign-In SDK)
//   2. This function verifies the token cryptographically against Google JWKs
//   3. Maps the verified identity to a workspace (auto-creates on first sync)
//   4. Signs and returns a short-lived custom sync JWT for PostgREST access
//
// SECURITY POSTURE:
//   • Google ID Token verified against live Google public JWKs (not shared secret)
//   • Token issuer, audience, and expiry strictly validated
//   • Custom sync JWT signed with Supabase JWT secret (HMAC-SHA256)
//   • JWT `role` = "authenticated" (PostgREST Postgres role)
//   • JWT `workspace_role` = owner/editor/viewer (RLS permission tier)
//   • Token TTL: 3600 seconds (1 hour) per supabase_config_reference.md §9
//   • service_role used for DB access (bypasses RLS) — authoritative bridge
//   • Anti-enumeration: identical error messages for all failure modes
//   • Per-IP abuse gate that FAILS OPEN and charges only failed verifications.
//     This is the sole token issuance path, so a limiter malfunction must never
//     lock the user base out of their own ledgers; and because successful
//     sign-ins cost nothing, a carrier-grade NAT shared by thousands of
//     legitimate users is throttled only by the invalid traffic it emits.
//     See authFailureGate in _shared/rate_limit.ts.
//
// PRODUCTION NOTE (supabase_config_reference.md §7.1):
//   Projects migrated to ECC JWT signing keys may reject HS256 tokens.
//   Validate on daftar-prod after deploy; switch to ES256 if required.
//
// ZERO MAU:
//   Supabase Auth is disabled. This function is the SOLE token issuance path.
//   End users are NOT Supabase MAUs → $0 MAU billing.
// ============================================================================

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../_shared/database.types.ts";
import {
  authFailureGate,
  clientIp,
  rateLimitedResponse,
  recordAuthFailure,
} from "../_shared/rate_limit.ts";

// ── Constants ───────────────────────────────────────────────────────────────

const GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs";
const GOOGLE_ISSUERS = ["https://accounts.google.com", "accounts.google.com"];

const ALLOWED_AUDIENCES = [
  Deno.env.get("GOOGLE_CLIENT_ID_WEB") ?? "",
  Deno.env.get("GOOGLE_CLIENT_ID_ANDROID") ?? "",
  Deno.env.get("GOOGLE_CLIENT_ID_IOS") ?? "",
].filter((aud) => aud.length > 0);

if (ALLOWED_AUDIENCES.length === 0) {
  console.error(
    "FATAL: No GOOGLE_CLIENT_ID_* secrets configured. Set via supabase secrets set.",
  );
}

const SYNC_JWT_TTL_SECONDS = 3600;
const SYNC_JWT_ISSUER = "supabase";
const POSTGREST_ROLE = "authenticated";
const CLOCK_SKEW_SECONDS = 30;

let jwksCache: { keys: GoogleJwk[]; fetchedAt: number } | null = null;
const JWKS_CACHE_TTL_MS = 60 * 60 * 1000;

/**
 * Minimum gap between forced JWKS refreshes. An unknown `kid` triggers a
 * refresh, so without this floor an attacker could mint tokens with random
 * `kid` values and turn every request into an outbound fetch to Google.
 */
const JWKS_FORCED_REFRESH_MIN_INTERVAL_MS = 60 * 1000;
let lastForcedJwksRefreshAt = 0;

/** HMAC-SHA256 keys shorter than the 256-bit block weaken the construction. */
const MIN_JWT_SECRET_LENGTH = 32;

/** Infrastructure / config failures → HTTP 503 (same body as auth failures). */
class AuthBridgeInfraError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AuthBridgeInfraError";
  }
}

// ── Types ───────────────────────────────────────────────────────────────────

interface GoogleJwk {
  kty: string;
  alg: string;
  use: string;
  kid: string;
  n: string;
  e: string;
}

interface GoogleIdTokenPayload {
  iss: string;
  aud: string;
  sub: string;
  email: string;
  email_verified: boolean;
  name?: string;
  picture?: string;
  iat: number;
  exp: number;
  nbf?: number;
}

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

// ── Cryptographic Helpers ───────────────────────────────────────────────────

/** Accepts only RSA signing keys usable for RS256. */
function isUsableRsaJwk(candidate: unknown): candidate is GoogleJwk {
  const jwk = candidate as Partial<GoogleJwk> | null;
  return !!jwk &&
    jwk.kty === "RSA" &&
    typeof jwk.kid === "string" && jwk.kid.length > 0 &&
    typeof jwk.n === "string" && jwk.n.length > 0 &&
    typeof jwk.e === "string" && jwk.e.length > 0 &&
    (jwk.alg === undefined || jwk.alg === "RS256") &&
    (jwk.use === undefined || jwk.use === "sig");
}

async function getGoogleJwks(): Promise<GoogleJwk[]> {
  const now = Date.now();
  if (jwksCache && now - jwksCache.fetchedAt < JWKS_CACHE_TTL_MS) {
    return jwksCache.keys;
  }

  const response = await fetch(GOOGLE_JWKS_URL);
  if (!response.ok) {
    throw new AuthBridgeInfraError(
      `Failed to fetch Google JWKs: ${response.status}`,
    );
  }

  const data = await response.json();
  if (!data || !Array.isArray(data.keys)) {
    throw new AuthBridgeInfraError("Malformed Google JWKS response");
  }

  const keys = data.keys.filter(isUsableRsaJwk);
  if (keys.length === 0) {
    throw new AuthBridgeInfraError("Google JWKS contained no usable RSA keys");
  }

  jwksCache = { keys, fetchedAt: now };
  return keys;
}

/**
 * Refetches the JWKS after an unknown `kid`, at most once per
 * {@link JWKS_FORCED_REFRESH_MIN_INTERVAL_MS}. Returns null when throttled.
 */
async function refreshJwksForUnknownKid(): Promise<GoogleJwk[] | null> {
  const now = Date.now();
  if (now - lastForcedJwksRefreshAt < JWKS_FORCED_REFRESH_MIN_INTERVAL_MS) {
    return null;
  }
  lastForcedJwksRefreshAt = now;
  jwksCache = null;
  return await getGoogleJwks();
}

function base64urlDecode(input: string): Uint8Array {
  const base64 = input
    .replace(/-/g, "+")
    .replace(/_/g, "/");
  const padded = base64 + "=".repeat((4 - (base64.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function base64urlEncode(data: Uint8Array): string {
  let binary = "";
  for (const byte of data) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function verifyGoogleIdToken(
  idToken: string,
): Promise<GoogleIdTokenPayload> {
  if (ALLOWED_AUDIENCES.length === 0) {
    throw new AuthBridgeInfraError("Server configuration error");
  }

  const parts = idToken.split(".");
  if (parts.length !== 3) {
    throw new Error("Invalid token format");
  }

  const [headerB64, payloadB64, signatureB64] = parts;

  const header = JSON.parse(
    new TextDecoder().decode(base64urlDecode(headerB64)),
  );
  if (header.alg !== "RS256") {
    throw new Error("Unsupported algorithm");
  }

  if (typeof header.kid !== "string" || header.kid.length === 0) {
    throw new Error("Missing key id");
  }

  const jwks = await getGoogleJwks();
  const jwk = jwks.find((k) => k.kid === header.kid);
  if (jwk) {
    return verifyWithKey(jwk, headerB64, payloadB64, signatureB64);
  }

  // Google rotates keys, so an unknown kid may just mean a stale cache.
  const refreshedJwks = await refreshJwksForUnknownKid();
  const retryJwk = refreshedJwks?.find((k) => k.kid === header.kid);
  if (!retryJwk) {
    throw new Error("No matching key found");
  }
  return verifyWithKey(retryJwk, headerB64, payloadB64, signatureB64);
}

async function verifyWithKey(
  jwk: GoogleJwk,
  headerB64: string,
  payloadB64: string,
  signatureB64: string,
): Promise<GoogleIdTokenPayload> {
  const cryptoKey = await crypto.subtle.importKey(
    "jwk",
    {
      kty: jwk.kty,
      n: jwk.n,
      e: jwk.e,
      alg: "RS256",
      use: "sig",
    },
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );

  const signatureBytes = base64urlDecode(signatureB64);
  const signedData = new TextEncoder().encode(`${headerB64}.${payloadB64}`);

  const isValid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    Uint8Array.from(signatureBytes),
    signedData,
  );

  if (!isValid) {
    throw new Error("Invalid signature");
  }

  const payload: GoogleIdTokenPayload = JSON.parse(
    new TextDecoder().decode(base64urlDecode(payloadB64)),
  );

  if (!GOOGLE_ISSUERS.includes(payload.iss)) {
    throw new Error("Invalid issuer");
  }

  if (!ALLOWED_AUDIENCES.includes(payload.aud)) {
    throw new Error("Invalid audience");
  }

  if (typeof payload.sub !== "string" || payload.sub.length === 0) {
    throw new Error("Invalid subject");
  }
  if (typeof payload.email !== "string" || payload.email.length === 0) {
    throw new Error("Invalid email");
  }
  if (typeof payload.exp !== "number" || !Number.isFinite(payload.exp)) {
    throw new Error("Invalid exp claim");
  }
  if (typeof payload.iat !== "number" || !Number.isFinite(payload.iat)) {
    throw new Error("Invalid iat claim");
  }

  const nowSeconds = Math.floor(Date.now() / 1000);
  if (payload.exp < nowSeconds - CLOCK_SKEW_SECONDS) {
    throw new Error("Token expired");
  }

  if (payload.nbf !== undefined) {
    if (typeof payload.nbf !== "number" || !Number.isFinite(payload.nbf)) {
      throw new Error("Invalid nbf claim");
    }
    if (payload.nbf > nowSeconds + CLOCK_SKEW_SECONDS) {
      throw new Error("Token not yet valid");
    }
  }

  if (payload.iat > nowSeconds + CLOCK_SKEW_SECONDS) {
    throw new Error("Token issued in the future");
  }

  if (payload.email_verified !== true) {
    throw new Error("Email not verified");
  }

  return payload;
}

/**
 * Resolves the HS256 signing secret from the Supabase runtime env
 * (local + hosted). Rejects implausibly short secrets so a misconfigured
 * deployment fails closed rather than minting weakly-signed sync JWTs.
 * Logs the source variable name only — never the value.
 */
function resolveLocalJwtSecret(): string | undefined {
  const sources: Array<[string, string | undefined]> = [
    ["SUPABASE_JWT_SECRET", Deno.env.get("SUPABASE_JWT_SECRET")],
    [
      "SUPABASE_INTERNAL_JWT_SECRET",
      Deno.env.get("SUPABASE_INTERNAL_JWT_SECRET"),
    ],
    ["JWT_SECRET", Deno.env.get("JWT_SECRET")],
  ];
  for (const [name, value] of sources) {
    if (!value || value.length === 0) continue;
    if (value.length < MIN_JWT_SECRET_LENGTH) {
      console.error(
        "[verify-google-token] jwt_secret_too_short",
        JSON.stringify({ source: name, min_length: MIN_JWT_SECRET_LENGTH }),
      );
      continue;
    }
    console.log(`[verify-google-token] jwt_secret_source=${name}`);
    return value;
  }
  console.error("[verify-google-token] jwt_secret_missing");
  return undefined;
}

async function signSyncJwt(
  payload: SyncJwtPayload,
  secret: string,
): Promise<string> {
  const header = { alg: "HS256", typ: "JWT" };

  const headerB64 = base64urlEncode(
    new TextEncoder().encode(JSON.stringify(header)),
  );
  const payloadB64 = base64urlEncode(
    new TextEncoder().encode(JSON.stringify(payload)),
  );

  const signingInput = `${headerB64}.${payloadB64}`;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(signingInput),
  );

  const signatureB64 = base64urlEncode(new Uint8Array(signature));

  return `${headerB64}.${payloadB64}.${signatureB64}`;
}

async function resolveWorkspace(
  supabaseAdmin: SupabaseClient<Database>,
  identityHash: string,
  email: string,
): Promise<{ workspaceId: string; workspaceRole: string }> {
  const { data, error } = await supabaseAdmin.rpc("provision_workspace", {
    p_identity_hash: identityHash,
    p_email: email,
  });

  if (error) {
    console.error("provision_workspace RPC error:", error);
    throw new AuthBridgeInfraError(
      "Database error during workspace resolution",
    );
  }

  const rows = data;
  const row = rows?.[0];
  if (!row?.workspace_id || !row?.workspace_role) {
    throw new AuthBridgeInfraError("Workspace resolution returned no data");
  }

  return {
    workspaceId: row.workspace_id,
    workspaceRole: row.workspace_role,
  };
}

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export default {
  fetch: withSupabase<Database>(
    { auth: ["publishable"] },
    async (req, ctx) => {
      if (req.method === "OPTIONS") {
        return new Response("ok", { headers: CORS_HEADERS });
      }

      if (req.method !== "POST") {
        return new Response(
          JSON.stringify({ error: "Method not allowed" }),
          {
            status: 405,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
          },
        );
      }

      // A malformed body is a client error, not an authentication failure.
      let googleIdToken: unknown;
      try {
        const body = await req.json();
        googleIdToken = body?.id_token;
      } catch {
        googleIdToken = undefined;
      }

      if (typeof googleIdToken !== "string" || googleIdToken.length === 0) {
        return new Response(
          JSON.stringify({
            error: "Missing or invalid id_token",
            code: "invalid_request",
          }),
          {
            status: 400,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
          },
        );
      }

      // Sign-in abuse gate. Only previously-failed attempts from this IP can
      // close it, and any limiter malfunction admits the request — see
      // authFailureGate. Never gate on a successful sign-in.
      const callerIp = clientIp(req);
      const gate = await authFailureGate(ctx.supabaseAdmin, callerIp);
      if (!gate.allowed) {
        return rateLimitedResponse(gate.retryAfterSeconds);
      }

      try {
        const googlePayload = await verifyGoogleIdToken(googleIdToken);
        const identityHash = await sha256Hex(googlePayload.sub);
        const normalizedEmail = googlePayload.email.trim().toLowerCase();

        const { workspaceId, workspaceRole } = await resolveWorkspace(
          ctx.supabaseAdmin,
          identityHash,
          normalizedEmail,
        );

        const jwtSecret = resolveLocalJwtSecret();
        if (!jwtSecret) {
          throw new AuthBridgeInfraError("Server configuration error");
        }

        const nowSeconds = Math.floor(Date.now() / 1000);

        const syncPayload: SyncJwtPayload = {
          sub: identityHash,
          iss: SYNC_JWT_ISSUER,
          aud: POSTGREST_ROLE,
          iat: nowSeconds,
          exp: nowSeconds + SYNC_JWT_TTL_SECONDS,
          role: POSTGREST_ROLE,
          workspace_id: workspaceId,
          workspace_role: workspaceRole,
          identity_hash: identityHash,
        };

        const syncToken = await signSyncJwt(syncPayload, jwtSecret);

        return new Response(
          JSON.stringify({
            sync_token: syncToken,
            expires_in: SYNC_JWT_TTL_SECONDS,
            workspace_id: workspaceId,
            role: workspaceRole,
            identity_hash: identityHash,
          }),
          {
            status: 200,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
          },
        );
      } catch (error) {
        console.error("Auth bridge error:", error);
        const isInfra = error instanceof AuthBridgeInfraError ||
          (error instanceof Error &&
            (error.message.includes("Server configuration") ||
              error.message.includes("Failed to fetch Google JWKs")));

        // Charge only genuine rejections. An outage on our side must not spend
        // a legitimate user's budget and lock them out once we recover.
        if (!isInfra) {
          await recordAuthFailure(ctx.supabaseAdmin, callerIp);
        }

        return new Response(
          JSON.stringify({ error: "Authentication failed" }),
          {
            status: isInfra ? 503 : 401,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
          },
        );
      }
    },
  ),
};

/* ──────────────────────────────────────────────────────────────────────────
   ENVIRONMENT VARIABLES REQUIRED (set via `supabase secrets set`):

   GOOGLE_CLIENT_ID_WEB      = <web OAuth client id>
   GOOGLE_CLIENT_ID_ANDROID  = <android OAuth client id>
   GOOGLE_CLIENT_ID_IOS      = <ios OAuth client id>
   SUPABASE_JWT_SECRET       = (auto-provided by Supabase runtime)

   LOCAL INVOCATION:
   curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/verify-google-token' \
     --header 'apikey: <publishable_key>' \
     --header 'Content-Type: application/json' \
     --data '{"id_token":"<google_id_token>"}'
   ────────────────────────────────────────────────────────────────────────── */
