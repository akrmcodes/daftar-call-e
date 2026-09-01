// ============================================================================
// Edge Function: pull-sync-ops
// ============================================================================
// Stage 8.4 — Return ordered op-log rows since a watermark op_seq.
//
// Stage 8.8 hardening:
//   • The archived-ledger filter ran up to three point queries per row (≈600
//     round trips for a full page). It is now three bulk queries per page.
//   • Withheld ops could strand the client. The client derives its watermark
//     from the ops it applies, so a page consisting entirely of withheld ops
//     returned `[]`, left the watermark unchanged, and stalled that device
//     forever. The scan now continues past withheld runs, and the response
//     carries an explicit `next_since_op_seq` cursor.
// ============================================================================

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import type { Database } from "../_shared/database.types.ts";
import {
  type AdminClient,
  PULL_DEFAULT_LIMIT,
  PULL_MAX_LIMIT,
  PULL_MAX_SCAN_PAGES,
  type PullOpRow,
} from "../_shared/sync_ops.ts";
import {
  InternalError,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
  toErrorResponse,
  ValidationError,
} from "../_shared/http.ts";
import { requireSyncJwt } from "../_shared/verify_sync_jwt.ts";

interface AuditLogRow {
  id: string;
  entity_type: string;
  entity_id: string;
  action: string;
  payload: Record<string, unknown> | null;
  device_id: string;
  logged_at: string;
  server_updated_at: string | null;
  op_seq: number | null;
  workspace_id: string;
}

/**
 * Role reported for ops whose device no longer maps to an active membership
 * (typically a revoked worker's historical ops). Those ops were written by a
 * writer, so the merge engine must continue to treat them as writer ops.
 */
const UNKNOWN_DEVICE_ROLE = "editor";

async function resolveDeviceRoles(
  admin: AdminClient,
  workspaceId: string,
  deviceIds: string[],
): Promise<Map<string, string>> {
  const roleByDevice = new Map<string, string>();
  if (deviceIds.length === 0) {
    return roleByDevice;
  }

  const { data: devices, error: devicesError } = await admin
    .from("workspace_devices")
    .select("device_id, identity_hash")
    .eq("workspace_id", workspaceId)
    .in("device_id", deviceIds);

  if (devicesError) {
    console.error("pull_device_lookup_failed:", devicesError.message);
    return roleByDevice;
  }

  const identityHashes = [
    ...new Set(
      (devices ?? [])
        .map((device) => device.identity_hash)
        .filter((hash): hash is string =>
          typeof hash === "string" && hash.length > 0
        ),
    ),
  ];

  const roleByIdentity = new Map<string, string>();
  if (identityHashes.length > 0) {
    const { data: members, error: membersError } = await admin
      .from("workspace_members")
      .select("identity_hash, role")
      .eq("workspace_id", workspaceId)
      .eq("status", "active")
      .in("identity_hash", identityHashes);

    if (membersError) {
      console.error("pull_member_lookup_failed:", membersError.message);
    } else {
      for (const member of members ?? []) {
        if (member.identity_hash) {
          roleByIdentity.set(member.identity_hash, member.role);
        }
      }
    }
  }

  for (const device of devices ?? []) {
    const role = roleByIdentity.get(device.identity_hash) ??
      UNKNOWN_DEVICE_ROLE;
    roleByDevice.set(device.device_id, role);
  }

  return roleByDevice;
}

/**
 * Resolves, for one page of rows, which entity ids sit under a user-archived
 * ledger. Three bulk queries regardless of page size.
 */
async function resolveArchivedEntityIds(
  admin: AdminClient,
  workspaceId: string,
  rows: AuditLogRow[],
): Promise<Set<string>> {
  const archived = new Set<string>();

  const contactIds = new Set<string>();
  const transactionIds = new Set<string>();
  for (const row of rows) {
    if (row.entity_type === "contact") contactIds.add(row.entity_id);
    else if (row.entity_type === "transaction") {
      transactionIds.add(row.entity_id);
    }
  }
  if (contactIds.size === 0 && transactionIds.size === 0) {
    return archived;
  }

  const { data: archivedLedgers, error: ledgerError } = await admin
    .from("ledgers")
    .select("id")
    .eq("workspace_id", workspaceId)
    .eq("is_user_archived", true);

  if (ledgerError) {
    console.error("pull_ledger_lookup_failed:", ledgerError.message);
    throw new InternalError("Pull failed");
  }

  const archivedLedgerIds = new Set(
    (archivedLedgers ?? []).map((row) => String(row.id)),
  );
  if (archivedLedgerIds.size === 0) {
    return archived;
  }

  // Transactions reach a ledger through their contact, so resolve those first.
  const contactLookupIds = new Set(contactIds);
  let contactIdByTransaction = new Map<string, string>();

  if (transactionIds.size > 0) {
    const { data: transactions, error: txnError } = await admin
      .from("transactions")
      .select("id, contact_id")
      .eq("workspace_id", workspaceId)
      .in("id", [...transactionIds]);

    if (txnError) {
      console.error("pull_transaction_lookup_failed:", txnError.message);
      throw new InternalError("Pull failed");
    }

    contactIdByTransaction = new Map(
      (transactions ?? []).map((
        row,
      ) => [String(row.id), String(row.contact_id)]),
    );
    for (const contactId of contactIdByTransaction.values()) {
      contactLookupIds.add(contactId);
    }
  }

  if (contactLookupIds.size === 0) {
    return archived;
  }

  const { data: contacts, error: contactError } = await admin
    .from("contacts")
    .select("id, ledger_id")
    .eq("workspace_id", workspaceId)
    .in("id", [...contactLookupIds]);

  if (contactError) {
    console.error("pull_contact_lookup_failed:", contactError.message);
    throw new InternalError("Pull failed");
  }

  const ledgerByContact = new Map(
    (contacts ?? []).map((row) => [String(row.id), String(row.ledger_id)]),
  );

  for (const contactId of contactIds) {
    const ledgerId = ledgerByContact.get(contactId);
    if (ledgerId && archivedLedgerIds.has(ledgerId)) {
      archived.add(contactId);
    }
  }

  for (const [transactionId, contactId] of contactIdByTransaction) {
    const ledgerId = ledgerByContact.get(contactId);
    if (ledgerId && archivedLedgerIds.has(ledgerId)) {
      archived.add(transactionId);
    }
  }

  return archived;
}

async function fetchPage(
  admin: AdminClient,
  workspaceId: string,
  sinceOpSeq: number,
  limit: number,
): Promise<AuditLogRow[]> {
  const { data, error } = await admin
    .from("audit_logs")
    .select(
      "id, entity_type, entity_id, action, payload, device_id, logged_at, server_updated_at, op_seq, workspace_id",
    )
    .eq("workspace_id", workspaceId)
    .gt("op_seq", sinceOpSeq)
    .not("op_seq", "is", null)
    .order("op_seq", { ascending: true })
    .limit(limit);

  if (error) {
    console.error("pull_query_failed:", error.message);
    throw new InternalError("Pull failed");
  }

  return (data ?? []) as AuditLogRow[];
}

function parseNonNegativeInt(raw: string, field: string): number {
  const value = Number(raw);
  if (!Number.isFinite(value) || !Number.isInteger(value) || value < 0) {
    throw new ValidationError(`Invalid ${field}`);
  }
  return value;
}

export default {
  fetch: withSupabase<Database>(
    { auth: ["publishable"] },
    async (req, ctx) => {
      if (req.method === "OPTIONS") {
        return optionsResponse(req);
      }
      if (req.method !== "GET") {
        return methodNotAllowed(req);
      }

      try {
        const claims = await requireSyncJwt(req);
        const url = new URL(req.url);

        const sinceOpSeq = parseNonNegativeInt(
          url.searchParams.get("since_op_seq") ?? "0",
          "since_op_seq",
        );
        const limitRaw = url.searchParams.get("limit");
        const limit = limitRaw == null ? PULL_DEFAULT_LIMIT : Math.min(
          Math.max(parseNonNegativeInt(limitRaw, "limit"), 1),
          PULL_MAX_LIMIT,
        );

        const workspaceId = claims.workspace_id;
        const admin = ctx.supabaseAdmin;

        const ops: PullOpRow[] = [];
        let cursor = sinceOpSeq;
        let exhausted = false;

        // Keep scanning past runs of withheld ops so the cursor always advances
        // when a deliverable op exists beyond them.
        for (let page = 0; page < PULL_MAX_SCAN_PAGES; page++) {
          const rows = await fetchPage(admin, workspaceId, cursor, limit);
          if (rows.length === 0) {
            exhausted = true;
            break;
          }

          const usable = rows.filter(
            (row) => row.server_updated_at != null && row.op_seq != null,
          );
          const archivedEntityIds = await resolveArchivedEntityIds(
            admin,
            workspaceId,
            usable,
          );
          const roleByDevice = await resolveDeviceRoles(
            admin,
            workspaceId,
            [...new Set(usable.map((row) => row.device_id).filter(Boolean))],
          );

          // The cursor advances one row at a time, and only for rows that have
          // been fully handled. Advancing it per page instead would skip the
          // tail of a page that the output limit cut short.
          let reachedLimit = false;
          for (const row of rows) {
            if (ops.length >= limit) {
              reachedLimit = true;
              break;
            }

            if (row.server_updated_at != null && row.op_seq != null) {
              if (!archivedEntityIds.has(row.entity_id)) {
                ops.push({
                  id: row.id,
                  entity_type: row.entity_type,
                  entity_id: row.entity_id,
                  action: row.action,
                  payload: row.payload,
                  device_id: row.device_id,
                  logged_at: row.logged_at,
                  server_updated_at: row.server_updated_at,
                  op_seq: Number(row.op_seq),
                  workspace_role: roleByDevice.get(row.device_id) ??
                    UNKNOWN_DEVICE_ROLE,
                });
              }
              cursor = Math.max(cursor, Number(row.op_seq));
            }
          }

          if (reachedLimit) break;
          if (rows.length < limit) {
            exhausted = true;
            break;
          }
        }

        // `next_since_op_seq` is the highest op_seq the server examined, which
        // includes withheld rows. A client that adopts it never re-reads a
        // withheld run; a client that still derives its watermark from the
        // returned ops stays correct, just less efficient.
        const highestReturned = ops.length > 0
          ? ops[ops.length - 1].op_seq
          : sinceOpSeq;

        return jsonResponse(
          {
            ops,
            next_since_op_seq: Math.max(cursor, highestReturned),
            has_more: !exhausted,
          },
          200,
          req,
        );
      } catch (error) {
        return toErrorResponse("pull-sync-ops", error, req);
      }
    },
  ),
};
