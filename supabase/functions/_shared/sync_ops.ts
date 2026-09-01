// ============================================================================
// Shared types and helpers for push/pull sync Edge Functions (Stage 8.4)
// ============================================================================
// Every write in here previously ignored the `{ error }` half of the
// supabase-js result. A failed projection write (FK violation, tenant-integrity
// trigger, malformed amount) was therefore invisible: the audit row was still
// inserted, the client was told "applied", and the server's mirror of the
// ledger silently diverged from the op-log. All writes now propagate.
// ============================================================================

import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "./database.types.ts";
import { InternalError, ValidationError } from "./http.ts";
import {
  ENTITY_ID_MAX_LENGTH,
  isValidMoneyAmount,
  parseInstant,
  requireString,
} from "./validation.ts";

export type AdminClient = SupabaseClient<Database>;

export interface PushOpInput {
  id: string;
  entity_type: string;
  entity_id: string;
  action: string;
  field_deltas?: Record<string, unknown> | string | null;
  local_timestamp: string;
}

export interface PushOpResult {
  id: string;
  op_seq: number;
  server_updated_at: string;
  status: "applied" | "duplicate";
}

/** An op the server refused. Reported separately so it never becomes an ack. */
export interface PushOpFailure {
  id: string;
  code: string;
}

export interface PullOpRow {
  id: string;
  entity_type: string;
  entity_id: string;
  action: string;
  payload: Record<string, unknown> | null;
  device_id: string;
  logged_at: string;
  server_updated_at: string;
  op_seq: number;
  /** Workspace role of the device actor at push time (owner/editor/viewer). */
  workspace_role: string;
}

/**
 * Every action string the Flutter client can emit.
 * MUST stay in sync with the `audit_logs_action_check` constraint
 * (migration 20260806120000). The op-log stores the verb verbatim because the
 * merge engine distinguishes archive from delete from carry-forward.
 */
export const SYNC_OP_ACTIONS = [
  "CREATE",
  "UPDATE",
  "DELETE",
  "RESTORE",
  "ACTIVATE_ARCHIVED",
  "USER_ARCHIVE",
  "USER_UNARCHIVE",
  "CARRY_FORWARD",
] as const;

export type SyncOpAction = typeof SYNC_OP_ACTIONS[number];

export function isSyncOpAction(value: string): value is SyncOpAction {
  return (SYNC_OP_ACTIONS as readonly string[]).includes(value);
}

export const SYNCABLE_ENTITY_TYPES = [
  "ledger",
  "contact",
  "transaction",
] as const;

export type SyncableEntityType = typeof SYNCABLE_ENTITY_TYPES[number];

export function isSyncableEntityType(
  value: string,
): value is SyncableEntityType {
  return (SYNCABLE_ENTITY_TYPES as readonly string[]).includes(value);
}

/** Outcome of projecting one op onto the server's entity mirror. */
export type EntityApplyOutcome =
  | "applied"
  | "skipped_no_deltas"
  | "skipped_stale"
  | "skipped_missing";

export function parseFieldDeltas(
  raw: PushOpInput["field_deltas"],
): Record<string, unknown> | null {
  if (raw == null) return null;
  if (typeof raw === "string") {
    try {
      const parsed = JSON.parse(raw);
      return typeof parsed === "object" && parsed !== null
        ? parsed as Record<string, unknown>
        : null;
    } catch {
      return null;
    }
  }
  return raw;
}

/**
 * Maps the extended client verbs onto the CRUD shape the entity projection
 * understands. The op-log keeps the original verb; only the projection is
 * normalized.
 */
export function normalizePushAction(
  action: string,
  deltas: Record<string, unknown> | null,
): { action: string; deltas: Record<string, unknown> | null } {
  switch (action) {
    case "USER_ARCHIVE":
      return {
        action: "UPDATE",
        deltas: { ...(deltas ?? {}), isUserArchived: true },
      };
    case "USER_UNARCHIVE":
      return {
        action: "UPDATE",
        deltas: { ...(deltas ?? {}), isUserArchived: false },
      };
    case "RESTORE":
      return {
        action: "UPDATE",
        deltas: { ...(deltas ?? {}), isDeleted: false },
      };
    case "ACTIVATE_ARCHIVED":
      return {
        action: "UPDATE",
        deltas: { ...(deltas ?? {}), isArchived: false },
      };
    default:
      return { action, deltas };
  }
}

/** Wraps a supabase-js error into an opaque 500 without leaking driver text. */
function assertNoError(
  error: { code?: string; message?: string } | null,
  operation: string,
): void {
  if (!error) return;
  console.error(
    "sync_projection_write_failed",
    JSON.stringify({ operation, code: error.code ?? null }),
    error.message ?? "",
  );
  throw new InternalError(`Failed to apply ${operation}`);
}

function optionalText(value: unknown): string | null {
  return value != null ? String(value) : null;
}

/**
 * INTEGER MONEY guard. Rejects fractional, negative, zero and non-finite
 * amounts before they reach the BIGINT column.
 */
function requireMoney(value: unknown, field: string): number {
  if (!isValidMoneyAmount(value)) {
    throw new ValidationError(`Invalid ${field}`, "invalid_request");
  }
  return value;
}

/** `credit_limit` may be absent, but when present it is integer money. */
function optionalMoney(value: unknown, field: string): number | null {
  if (value == null) return null;
  return requireMoney(value, field);
}

/**
 * Runs every delta check {@link applyEntityOp} would run, without touching the
 * database.
 *
 * push-sync-ops appends the op-log row before projecting (the append is what
 * assigns `op_seq`), so a delta the projection would reject has to be caught
 * *before* the append — otherwise the op-log would carry a row that can never
 * be projected, and the client would retry it forever.
 *
 * Takes the normalized action/deltas pair from {@link normalizePushAction},
 * because that is what the projection actually sees.
 *
 * @throws {ValidationError} when a delta would be rejected downstream.
 */
export function validateEntityDeltas(
  entityType: string,
  action: string,
  deltas: Record<string, unknown> | null,
): void {
  if (!isSyncableEntityType(entityType) || deltas == null) return;

  if (action === "CREATE") {
    if (entityType === "contact") {
      requireString(deltas.ledgerId, "ledgerId", ENTITY_ID_MAX_LENGTH);
      optionalMoney(deltas.creditLimit, "creditLimit");
    } else if (entityType === "transaction") {
      requireString(deltas.contactId, "contactId", ENTITY_ID_MAX_LENGTH);
      requireMoney(deltas.amount, "amount");
      if (deltas.transactionDate != null) {
        parseInstant(deltas.transactionDate, "transactionDate");
      }
    }
    return;
  }

  if (action !== "UPDATE") return;

  if (entityType === "contact") {
    if (deltas.creditLimit != null) {
      requireMoney(deltas.creditLimit, "creditLimit");
    }
  } else if (entityType === "transaction") {
    if (deltas.amount != null) requireMoney(deltas.amount, "amount");
    if (deltas.transactionDate != null) {
      parseInstant(deltas.transactionDate, "transactionDate");
    }
  }
}

/**
 * Projects one op onto the server's entity mirror.
 *
 * UPDATE and DELETE carry a monotonic guard: a row is only touched when its
 * stored `op_seq` is null or strictly lower than this op's. Concurrent pushes
 * are assigned `op_seq` by the server but complete in arbitrary order, so
 * without the guard a lower-numbered op landing late would overwrite newer
 * state — last-write-wins by arrival time rather than by sequence.
 *
 * @throws {ValidationError} when the deltas are structurally invalid.
 * @throws {InternalError} when the database rejects the write.
 */
export async function applyEntityOp(
  admin: AdminClient,
  workspaceId: string,
  entityType: string,
  entityId: string,
  action: string,
  deltas: Record<string, unknown> | null,
  serverUpdatedAt: string,
  opSeq: number,
): Promise<EntityApplyOutcome> {
  if (!isSyncableEntityType(entityType)) {
    return "skipped_missing";
  }

  if (action === "CREATE") {
    if (!deltas) return "skipped_no_deltas";
    return await applyCreate(
      admin,
      workspaceId,
      entityType,
      entityId,
      deltas,
      serverUpdatedAt,
      opSeq,
    );
  }

  if (action === "UPDATE") {
    if (!deltas) return "skipped_no_deltas";
    return await applyUpdate(
      admin,
      workspaceId,
      entityType,
      entityId,
      deltas,
      serverUpdatedAt,
      opSeq,
    );
  }

  if (action === "DELETE") {
    return await applyStatePatch(
      admin,
      workspaceId,
      entityType,
      entityId,
      {
        is_deleted: true,
        deleted_at: serverUpdatedAt,
        server_updated_at: serverUpdatedAt,
        op_seq: opSeq,
      },
      opSeq,
    );
  }

  return "skipped_missing";
}

async function applyCreate(
  admin: AdminClient,
  workspaceId: string,
  entityType: SyncableEntityType,
  entityId: string,
  deltas: Record<string, unknown>,
  serverUpdatedAt: string,
  opSeq: number,
): Promise<EntityApplyOutcome> {
  if (entityType === "ledger") {
    const { error } = await admin.from("ledgers").upsert({
      id: entityId,
      workspace_id: workspaceId,
      name: String(deltas.name ?? ""),
      type: String(deltas.type ?? "personal"),
      icon: String(deltas.icon ?? "store"),
      color: String(deltas.color ?? "#6E6E76"),
      sort_order: Number(deltas.sortOrder ?? 0),
      server_updated_at: serverUpdatedAt,
      op_seq: opSeq,
    });
    assertNoError(error, "ledger create");
    return "applied";
  }

  if (entityType === "contact") {
    const { error } = await admin.from("contacts").upsert({
      id: entityId,
      workspace_id: workspaceId,
      ledger_id: requireString(
        deltas.ledgerId,
        "ledgerId",
        ENTITY_ID_MAX_LENGTH,
      ),
      name: String(deltas.name ?? ""),
      phone: optionalText(deltas.phone),
      notes: optionalText(deltas.notes),
      credit_limit: optionalMoney(deltas.creditLimit, "creditLimit"),
      credit_currency: optionalText(deltas.creditCurrency),
      avatar_color: String(deltas.avatarColor ?? "#6E6E76"),
      server_updated_at: serverUpdatedAt,
      op_seq: opSeq,
    });
    assertNoError(error, "contact create");
    return "applied";
  }

  const { error } = await admin.from("transactions").upsert({
    id: entityId,
    workspace_id: workspaceId,
    contact_id: requireString(
      deltas.contactId,
      "contactId",
      ENTITY_ID_MAX_LENGTH,
    ),
    type: String(deltas.type ?? "debt"),
    amount: requireMoney(deltas.amount, "amount"),
    currency: String(deltas.currency ?? "YER"),
    description: optionalText(deltas.description),
    item_name: optionalText(deltas.itemName),
    transaction_date: deltas.transactionDate != null
      ? parseInstant(deltas.transactionDate, "transactionDate")
      : serverUpdatedAt,
    attachment_path: optionalText(deltas.attachmentPath),
    server_updated_at: serverUpdatedAt,
    op_seq: opSeq,
  });
  assertNoError(error, "transaction create");
  return "applied";
}

async function applyUpdate(
  admin: AdminClient,
  workspaceId: string,
  entityType: SyncableEntityType,
  entityId: string,
  deltas: Record<string, unknown>,
  serverUpdatedAt: string,
  opSeq: number,
): Promise<EntityApplyOutcome> {
  const patch: Record<string, unknown> = {
    server_updated_at: serverUpdatedAt,
    op_seq: opSeq,
  };

  if (entityType === "ledger") {
    if (deltas.name != null) patch.name = String(deltas.name);
    if (deltas.icon != null) patch.icon = String(deltas.icon);
    if (deltas.color != null) patch.color = String(deltas.color);
    if (deltas.sortOrder != null) patch.sort_order = Number(deltas.sortOrder);
    if (deltas.isUserArchived != null) {
      patch.is_user_archived = Boolean(deltas.isUserArchived);
    }
    if (deltas.isDeleted != null) patch.is_deleted = Boolean(deltas.isDeleted);
    if (deltas.isArchived != null) {
      patch.is_archived = Boolean(deltas.isArchived);
    }
    if (deltas.carryForwardTargetLedgerId != null) {
      patch.carry_forward_target_ledger_id = String(
        deltas.carryForwardTargetLedgerId,
      );
    }
  } else if (entityType === "contact") {
    if (deltas.name != null) patch.name = String(deltas.name);
    if (deltas.phone != null) patch.phone = String(deltas.phone);
    if (deltas.notes != null) patch.notes = String(deltas.notes);
    if (deltas.creditLimit != null) {
      patch.credit_limit = requireMoney(deltas.creditLimit, "creditLimit");
    }
    if (deltas.creditCurrency != null) {
      patch.credit_currency = String(deltas.creditCurrency);
    }
    if (deltas.avatarColor != null) {
      patch.avatar_color = String(deltas.avatarColor);
    }
    if (deltas.isDeleted != null) patch.is_deleted = Boolean(deltas.isDeleted);
    if (deltas.isArchived != null) {
      patch.is_archived = Boolean(deltas.isArchived);
    }
  } else {
    if (deltas.type != null) patch.type = String(deltas.type);
    if (deltas.amount != null) {
      patch.amount = requireMoney(deltas.amount, "amount");
    }
    if (deltas.currency != null) patch.currency = String(deltas.currency);
    if (deltas.description != null) {
      patch.description = String(deltas.description);
    }
    if (deltas.itemName != null) patch.item_name = String(deltas.itemName);
    if (deltas.transactionDate != null) {
      patch.transaction_date = parseInstant(
        deltas.transactionDate,
        "transactionDate",
      );
    }
    if (deltas.isDeleted != null) patch.is_deleted = Boolean(deltas.isDeleted);
    if (deltas.isArchived != null) {
      patch.is_archived = Boolean(deltas.isArchived);
    }
  }

  return await applyStatePatch(
    admin,
    workspaceId,
    entityType,
    entityId,
    patch,
    opSeq,
  );
}

/** Applies a patch under the monotonic `op_seq` guard. */
async function applyStatePatch(
  admin: AdminClient,
  workspaceId: string,
  entityType: SyncableEntityType,
  entityId: string,
  patch: Record<string, unknown>,
  opSeq: number,
): Promise<EntityApplyOutcome> {
  const table = entityType === "ledger"
    ? "ledgers"
    : entityType === "contact"
    ? "contacts"
    : "transactions";

  const { data, error } = await admin
    .from(table)
    .update(patch)
    .eq("id", entityId)
    .eq("workspace_id", workspaceId)
    .or(`op_seq.is.null,op_seq.lt.${opSeq}`)
    .select("id");

  assertNoError(error, `${entityType} update`);

  if ((data ?? []).length > 0) return "applied";

  // Zero rows means either the row is absent or a newer op already won.
  const { data: existing, error: readError } = await admin
    .from(table)
    .select("id")
    .eq("id", entityId)
    .eq("workspace_id", workspaceId)
    .maybeSingle();

  assertNoError(readError, `${entityType} lookup`);

  const rowExists = Array.isArray(existing)
    ? existing.length > 0
    : existing != null;
  return rowExists ? "skipped_stale" : "skipped_missing";
}

/** Current UTC month as `YYYY-MM`. */
export function currentUsageMonth(now: Date = new Date()): string {
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  return `${year}-${month}`;
}

export const SYNC_EVENT_MONTHLY_CAP = 50_000;

export const PULL_DEFAULT_LIMIT = 200;

export const PULL_MAX_LIMIT = 500;

/**
 * How many extra pages pull-sync-ops may scan past rows it must withhold.
 * Ops under a user-archived ledger are withheld, but the client advances its
 * watermark from the ops it applies — so a page consisting entirely of withheld
 * ops would return `[]`, leave the watermark unchanged, and stall the device
 * permanently. Scanning forward guarantees progress whenever any deliverable op
 * exists beyond the withheld run.
 */
export const PULL_MAX_SCAN_PAGES = 10;
