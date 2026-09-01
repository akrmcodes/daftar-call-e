// ============================================================================
// Edge Function: push-sync-ops
// ============================================================================
// Stage 8.4 — Accept local audit ops, assign op_seq, project entity rows.
//
// Stage 8.8 hardening:
//   • Action allow-list. The audit_logs CHECK constraint accepted only
//     CREATE/UPDATE/DELETE while the client emits five more verbs, so an
//     archived ledger produced a 23514 that aborted the batch — and, because
//     the client retries the same batch forever, permanently deadlocked that
//     device's outbound queue.
//   • Per-op isolation. A single malformed op no longer aborts the batch; it is
//     reported in `failed[]` so the rest of the queue drains.
//   • Atomic usage accounting via consume_sync_usage (was SELECT-then-UPSERT).
//   • Duplicate races resolve to `duplicate` instead of 500.
//   • Commit-ordered op_seq. Drawing the sequence number and writing the audit
//     row were two separate transactions, so numbers became visible to a puller
//     out of order: if a push holding op_seq 10 committed after one holding 11,
//     a puller reading in between advanced its watermark to 11 and never
//     received op 10 again — silent, permanent loss of a financial operation.
//     Measured at ~40% loss with 8 concurrent writers. Both steps now happen
//     inside append_sync_audit_op() under a per-workspace advisory lock held to
//     COMMIT, so op_seq order is commit order and the gap is closed outright.
// ============================================================================

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import type { Database } from "../_shared/database.types.ts";
import {
  type AdminClient,
  applyEntityOp,
  currentUsageMonth,
  isSyncableEntityType,
  isSyncOpAction,
  normalizePushAction,
  parseFieldDeltas,
  type PushOpFailure,
  type PushOpInput,
  type PushOpResult,
  SYNC_EVENT_MONTHLY_CAP,
  validateEntityDeltas,
} from "../_shared/sync_ops.ts";
import {
  ConflictError,
  ForbiddenError,
  HttpError,
  InternalError,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
  toErrorResponse,
  ValidationError,
} from "../_shared/http.ts";
import { isWritableRole, requireSyncJwt } from "../_shared/verify_sync_jwt.ts";
import {
  DEVICE_ID_MAX_LENGTH,
  ENTITY_ID_MAX_LENGTH,
  parseInstant,
  readJsonBody,
  requireString,
} from "../_shared/validation.ts";

interface PushRequest {
  device_id?: string;
  ops?: PushOpInput[];
}

/** Bounds the work a single request can schedule. */
const MAX_OPS_PER_PUSH = 500;

interface NormalizedOp {
  id: string;
  entityType: string;
  entityId: string;
  action: string;
  loggedAt: string;
  deltas: Record<string, unknown> | null;
  /** CRUD shape the entity projection understands. */
  projectedAction: string;
  projectedDeltas: Record<string, unknown> | null;
}

/** Validates one op. Throws {@link ValidationError} with a stable code. */
function normalizeOp(raw: PushOpInput): NormalizedOp {
  const id = requireString(raw?.id, "op.id", ENTITY_ID_MAX_LENGTH);
  const entityType = requireString(
    raw?.entity_type,
    "op.entity_type",
    64,
  );
  const entityId = requireString(
    raw?.entity_id,
    "op.entity_id",
    ENTITY_ID_MAX_LENGTH,
  );
  const action = requireString(raw?.action, "op.action", 64);

  if (!isSyncableEntityType(entityType)) {
    throw new ValidationError("Unsupported entity_type", "invalid_request");
  }
  if (!isSyncOpAction(action)) {
    throw new ValidationError("Unsupported action", "invalid_action");
  }

  const deltas = parseFieldDeltas(raw?.field_deltas);
  const projected = normalizePushAction(action, deltas);

  // The op-log row is written before the projection, so every delta the
  // projection could reject must be rejected here instead.
  validateEntityDeltas(entityType, projected.action, projected.deltas);

  return {
    id,
    entityType,
    entityId,
    action,
    loggedAt: parseInstant(raw?.local_timestamp, "op.local_timestamp"),
    deltas,
    projectedAction: projected.action,
    projectedDeltas: projected.deltas,
  };
}

async function registerDevice(
  admin: AdminClient,
  workspaceId: string,
  deviceId: string,
  identityHash: string,
): Promise<void> {
  const { error } = await admin.from("workspace_devices").upsert({
    workspace_id: workspaceId,
    device_id: deviceId,
    identity_hash: identityHash,
    last_seen_at: new Date().toISOString(),
    status: "active",
  }, { onConflict: "workspace_id,device_id" });

  if (!error) return;

  if (error.message.includes("device_cap_exceeded")) {
    throw new ConflictError(
      "Device registration failed",
      "device_cap_exceeded",
    );
  }
  console.error("register_device_failed:", error.message);
  throw new InternalError(
    "Device registration failed",
    "device_registration_failed",
  );
}

/**
 * Atomically reserves `batchSize` events against the monthly cap.
 * The previous read-then-write lost increments under concurrent pushes, so two
 * batches could each observe headroom that only one of them actually had.
 */
async function reserveSyncUsage(
  admin: AdminClient,
  workspaceId: string,
  batchSize: number,
): Promise<void> {
  const { data, error } = await admin.rpc("consume_sync_usage", {
    p_workspace_id: workspaceId,
    p_usage_month: currentUsageMonth(),
    p_events: batchSize,
    p_cap: SYNC_EVENT_MONTHLY_CAP,
  });

  if (error) {
    console.error("consume_sync_usage_failed:", error.message);
    throw new InternalError(
      "Sync usage check failed",
      "usage_counter_write_failed",
    );
  }

  const row = Array.isArray(data) ? data[0] : data;
  if (!row || (row as { allowed?: boolean }).allowed !== true) {
    throw new ConflictError(
      "Sync usage check failed",
      "sync_event_cap_exceeded",
    );
  }
}

/** Releases a reservation when the batch could not be applied. */
async function releaseSyncUsage(
  admin: AdminClient,
  workspaceId: string,
  events: number,
): Promise<void> {
  if (events <= 0) return;
  const { error } = await admin.rpc("consume_sync_usage", {
    p_workspace_id: workspaceId,
    p_usage_month: currentUsageMonth(),
    p_events: -events,
    p_cap: SYNC_EVENT_MONTHLY_CAP,
  });
  if (error) {
    console.error("release_sync_usage_failed:", error.message);
  }
}

interface AppendedOp {
  opSeq: number;
  serverUpdatedAt: string;
  status: "applied" | "duplicate";
}

/**
 * Assigns `op_seq` and appends the op-log row in a single transaction holding
 * this workspace's advisory lock.
 *
 * This replaces a draw RPC followed by a separate insert. Besides closing the
 * out-of-order visibility gap, holding the lock across the idempotency probe
 * removes the check-then-insert race that used to surface as a 23505.
 */
async function appendAuditOp(
  admin: AdminClient,
  workspaceId: string,
  deviceId: string,
  op: NormalizedOp,
): Promise<AppendedOp> {
  const { data, error } = await admin.rpc("append_sync_audit_op", {
    p_workspace_id: workspaceId,
    p_op_id: op.id,
    p_entity_type: op.entityType,
    p_entity_id: op.entityId,
    p_action: op.action,
    p_payload: op.deltas,
    p_logged_at: op.loggedAt,
    p_device_id: deviceId,
  });

  if (error) {
    console.error("append_sync_audit_op_failed:", error.message);
    throw new InternalError("Push failed");
  }

  const row = (Array.isArray(data) ? data[0] : data) as {
    op_seq?: number | string | null;
    server_updated_at?: string | null;
    status?: string | null;
  } | null;

  if (!row || row.op_seq == null || row.server_updated_at == null) {
    console.error("append_sync_audit_op_empty_result");
    throw new InternalError("Push failed");
  }

  return {
    opSeq: Number(row.op_seq),
    // Postgres serializes timestamptz as `…306843+00:00`; the ack previously
    // carried `new Date().toISOString()` (`…306Z`). Normalized so the shape the
    // client parses does not change with this refactor.
    serverUpdatedAt: normalizeInstant(row.server_updated_at),
    status: row.status === "duplicate" ? "duplicate" : "applied",
  };
}

function normalizeInstant(raw: string): string {
  const parsed = new Date(raw);
  return Number.isNaN(parsed.getTime()) ? raw : parsed.toISOString();
}

export default {
  fetch: withSupabase<Database>(
    { auth: ["publishable"] },
    async (req, ctx) => {
      if (req.method === "OPTIONS") {
        return optionsResponse(req);
      }
      if (req.method !== "POST") {
        return methodNotAllowed(req);
      }

      let admin: AdminClient | null = null;
      let workspaceId = "";
      let reserved = 0;
      let consumed = 0;

      try {
        const claims = await requireSyncJwt(req);
        if (!isWritableRole(claims.workspace_role)) {
          // Viewers may pull but never push. RLS enforces the same rule at the
          // database layer; this is the application half of that pair. 403, not
          // 401: the token is valid, so a client that refreshes on 401 would
          // otherwise loop.
          throw new ForbiddenError("Read-only role");
        }

        const body = await readJsonBody<PushRequest>(req);
        const deviceId = requireString(
          body?.device_id,
          "device_id",
          DEVICE_ID_MAX_LENGTH,
        );

        const rawOps = body?.ops ?? [];
        if (!Array.isArray(rawOps)) {
          throw new ValidationError("Invalid ops");
        }
        if (rawOps.length > MAX_OPS_PER_PUSH) {
          throw new ValidationError("Too many ops in one push");
        }

        workspaceId = claims.workspace_id;
        admin = ctx.supabaseAdmin;

        await registerDevice(
          admin,
          workspaceId,
          deviceId,
          claims.identity_hash,
        );

        // Validate the whole batch before reserving quota so a malformed op
        // never consumes a customer's monthly allowance.
        const normalized: NormalizedOp[] = [];
        const failed: PushOpFailure[] = [];
        for (const raw of rawOps) {
          try {
            normalized.push(normalizeOp(raw));
          } catch (error) {
            const code = error instanceof HttpError
              ? error.code
              : "invalid_request";
            const id = typeof raw?.id === "string" ? raw.id : "";
            if (id.length === 0) {
              // Without an id the client cannot reconcile the failure, so this
              // is a malformed request rather than a per-op failure.
              throw error;
            }
            failed.push({ id, code });
          }
        }

        if (normalized.length > 0) {
          await reserveSyncUsage(admin, workspaceId, normalized.length);
          reserved = normalized.length;
        }

        const results: PushOpResult[] = [];

        for (const op of normalized) {
          // The op-log is the source of truth and the entity tables are a
          // derived mirror, so the log is written first. The mirror is then
          // brought up to date under applyEntityOp's monotonic op_seq guard,
          // which makes this replay-safe: a duplicate whose projection never
          // landed on an earlier attempt heals here, and one that did is
          // skipped as stale.
          const appended = await appendAuditOp(
            admin,
            workspaceId,
            deviceId,
            op,
          );

          try {
            const outcome = await applyEntityOp(
              admin,
              workspaceId,
              op.entityType,
              op.entityId,
              op.projectedAction,
              op.projectedDeltas,
              appended.serverUpdatedAt,
              appended.opSeq,
            );
            if (outcome === "skipped_missing") {
              // The op-log still records it — other devices replay it — but the
              // server mirror is missing the parent row, which is worth seeing.
              console.warn(
                "push_projection_target_missing",
                JSON.stringify({
                  workspace_id: workspaceId,
                  entity_type: op.entityType,
                  action: op.action,
                }),
              );
            }
          } catch (error) {
            if (error instanceof ValidationError) {
              // normalizeOp pre-validates every delta the projection can
              // reject, so reaching here means the two disagree. The op is
              // already in the log and cannot be un-acked; failing the request
              // would only make the client retry it forever. Ack it and shout,
              // leaving the mirror stale rather than the queue deadlocked.
              console.error(
                "push_projection_rejected_after_append",
                JSON.stringify({
                  workspace_id: workspaceId,
                  entity_type: op.entityType,
                  action: op.action,
                  op_seq: appended.opSeq,
                  code: error.code,
                }),
              );
            } else {
              throw error;
            }
          }

          if (appended.status === "applied") consumed += 1;
          results.push({
            id: op.id,
            op_seq: appended.opSeq,
            server_updated_at: appended.serverUpdatedAt,
            status: appended.status,
          });
        }

        // Duplicates and rejected ops did not consume new capacity.
        await releaseSyncUsage(admin, workspaceId, reserved - consumed);
        reserved = 0;

        return jsonResponse({ results, failed }, 200, req);
      } catch (error) {
        if (admin && reserved > consumed) {
          await releaseSyncUsage(admin, workspaceId, reserved - consumed);
        }
        return toErrorResponse("push-sync-ops", error, req);
      }
    },
  ),
};
