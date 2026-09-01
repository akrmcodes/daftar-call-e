// ============================================================================
// Test doubles and helpers shared by the Deno test suite
// ============================================================================
// Not imported by any Edge Function.
// ============================================================================

import type { AdminClient } from "./sync_ops.ts";

export interface QueryOutcome {
  data?: unknown;
  error?: { code?: string; message?: string } | null;
}

export interface RecordedCall {
  table: string;
  verb: string;
  payload?: unknown;
  filters: Array<[string, unknown]>;
  orFilter?: string;
}

/** Resolves the outcome for one query, given what the caller asked for. */
export type OutcomeResolver = (call: RecordedCall) => QueryOutcome;

export interface RecordedRpc {
  name: string;
  args?: Record<string, unknown>;
}

/** May throw, so tests can exercise a client that fails rather than returns. */
export type RpcResolver = (
  call: RecordedRpc,
) => QueryOutcome | Promise<QueryOutcome>;

class FakeQuery implements PromiseLike<QueryOutcome> {
  constructor(
    private readonly call: RecordedCall,
    private readonly resolver: OutcomeResolver,
  ) {}

  eq(column: string, value: unknown): this {
    this.call.filters.push([column, value]);
    return this;
  }

  in(column: string, value: unknown): this {
    this.call.filters.push([column, value]);
    return this;
  }

  or(expression: string): this {
    this.call.orFilter = expression;
    return this;
  }

  select(_columns?: string): this {
    return this;
  }

  maybeSingle(): this {
    return this;
  }

  then<TResult1 = QueryOutcome, TResult2 = never>(
    onfulfilled?:
      | ((value: QueryOutcome) => TResult1 | PromiseLike<TResult1>)
      | null,
    onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null,
  ): PromiseLike<TResult1 | TResult2> {
    return Promise.resolve(this.resolver(this.call)).then(
      onfulfilled,
      onrejected,
    );
  }
}

/**
 * Minimal stand-in for the supabase-js client covering the surface
 * `applyEntityOp` uses: `from(table).upsert|update|insert|select(...)`.
 */
export class FakeAdminClient {
  readonly calls: RecordedCall[] = [];
  readonly rpcCalls: RecordedRpc[] = [];

  constructor(
    private readonly resolver: OutcomeResolver = () => ({}),
    private rpcResolver: RpcResolver = () => ({ data: null, error: null }),
  ) {}

  /** Replaces the RPC behaviour; the resolver may return or throw. */
  onRpc(resolver: RpcResolver): this {
    this.rpcResolver = resolver;
    return this;
  }

  rpc(name: string, args?: Record<string, unknown>): Promise<QueryOutcome> {
    const call: RecordedRpc = { name, args };
    this.rpcCalls.push(call);
    // Wrapped so a synchronous throw surfaces as a rejected promise, matching
    // supabase-js.
    return (async () => await this.rpcResolver(call))();
  }

  from(table: string) {
    const build = (verb: string, payload?: unknown) => {
      const call: RecordedCall = { table, verb, payload, filters: [] };
      this.calls.push(call);
      return new FakeQuery(call, this.resolver);
    };

    return {
      upsert: (payload: unknown) => build("upsert", payload),
      update: (payload: unknown) => build("update", payload),
      insert: (payload: unknown) => build("insert", payload),
      select: (columns?: string) => build("select", columns),
      delete: () => build("delete"),
    };
  }

  /** Casts to the client type the production code expects. */
  asAdmin(): AdminClient {
    return this as unknown as AdminClient;
  }

  callsFor(table: string, verb: string): RecordedCall[] {
    return this.calls.filter((c) => c.table === table && c.verb === verb);
  }
}

const encoder = new TextEncoder();

function base64urlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

/** Signs a JWT with HS256 so tests can exercise the real verifier. */
export async function signTestJwt(
  payload: Record<string, unknown>,
  secret: string,
  header: Record<string, unknown> = { alg: "HS256", typ: "JWT" },
): Promise<string> {
  const headerB64 = base64urlEncode(encoder.encode(JSON.stringify(header)));
  const payloadB64 = base64urlEncode(encoder.encode(JSON.stringify(payload)));
  const signingInput = `${headerB64}.${payloadB64}`;

  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(signingInput),
  );

  return `${signingInput}.${base64urlEncode(new Uint8Array(signature))}`;
}

/** A well-formed sync JWT payload; override fields per test. */
export function syncJwtPayload(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  const now = Math.floor(Date.now() / 1000);
  return {
    sub: "identity-hash-1",
    iss: "supabase",
    aud: "authenticated",
    iat: now,
    exp: now + 3600,
    role: "authenticated",
    workspace_id: "11111111-1111-4111-8111-111111111111",
    workspace_role: "owner",
    identity_hash: "identity-hash-1",
    ...overrides,
  };
}

/** 32+ chars so it passes the minimum-strength check. */
export const TEST_JWT_SECRET = "test-secret-with-sufficient-entropy-0123456789";
