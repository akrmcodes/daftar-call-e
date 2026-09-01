// ============================================================================
// Shared Database types for Edge Functions (Stage 8)
// ============================================================================
// Hand-authored from supabase/migrations to match the live schema.
// Regenerate via `supabase gen types typescript` when the remote schema
// stabilizes; keep this file as the Deno LSP source of truth until then.
//
// Used as: withSupabase<Database>(...)
// ============================================================================

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type TokenKind = "share" | "referral" | "worker_invite";
export type TokenState =
  | "active"
  | "claimed"
  | "expired"
  | "revoked"
  | "superseded";

export type WorkspaceMemberRole = "owner" | "editor" | "viewer";
export type WorkspaceMemberStatus = "pending" | "active";
export type WorkspaceTier = "free" | "pro" | "pro_plus";

export type Database = {
  public: {
    Tables: {
      workspaces: {
        Row: {
          id: string;
          owner_identity: string;
          status: string;
          tier: WorkspaceTier | null;
          sharing_cap: number;
          soft_deleted_at: string | null;
          purge_after: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          owner_identity: string;
          status?: string;
          tier?: WorkspaceTier | null;
          sharing_cap?: number;
          soft_deleted_at?: string | null;
          purge_after?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          owner_identity?: string;
          status?: string;
          tier?: WorkspaceTier | null;
          sharing_cap?: number;
          soft_deleted_at?: string | null;
          purge_after?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      workspace_members: {
        Row: {
          id: string;
          workspace_id: string;
          invited_email: string | null;
          identity_hash: string | null;
          role: WorkspaceMemberRole;
          status: WorkspaceMemberStatus;
          seat_index: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          workspace_id: string;
          invited_email?: string | null;
          identity_hash?: string | null;
          role: WorkspaceMemberRole;
          status?: WorkspaceMemberStatus;
          seat_index: number;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          workspace_id?: string;
          invited_email?: string | null;
          identity_hash?: string | null;
          role?: WorkspaceMemberRole;
          status?: WorkspaceMemberStatus;
          seat_index?: number;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      deep_link_tokens: {
        Row: {
          token: string;
          kind: TokenKind;
          intent_payload: Json;
          workspace_id: string | null;
          created_by: string | null;
          state: TokenState;
          expires_at: string;
          claimed_by: string | null;
          claimed_at: string | null;
          created_at: string;
        };
        Insert: {
          token: string;
          kind: TokenKind;
          intent_payload?: Json;
          workspace_id?: string | null;
          created_by?: string | null;
          state?: TokenState;
          expires_at: string;
          claimed_by?: string | null;
          claimed_at?: string | null;
          created_at?: string;
        };
        Update: {
          token?: string;
          kind?: TokenKind;
          intent_payload?: Json;
          workspace_id?: string | null;
          created_by?: string | null;
          state?: TokenState;
          expires_at?: string;
          claimed_by?: string | null;
          claimed_at?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      rate_limit_buckets: {
        Row: {
          bucket_key: string;
          tokens: number;
          last_refill: string;
        };
        Insert: {
          bucket_key: string;
          tokens?: number;
          last_refill?: string;
        };
        Update: {
          bucket_key?: string;
          tokens?: number;
          last_refill?: string;
        };
        Relationships: [];
      };
      invite_send_queue: {
        Row: {
          id: string;
          workspace_id: string | null;
          kind: string;
          payload: Json;
          status: string;
          created_at: string;
          available_at: string;
        };
        Insert: {
          id?: string;
          workspace_id?: string | null;
          kind: string;
          payload?: Json;
          status?: string;
          created_at?: string;
          available_at?: string;
        };
        Update: {
          id?: string;
          workspace_id?: string | null;
          kind?: string;
          payload?: Json;
          status?: string;
          created_at?: string;
          available_at?: string;
        };
        Relationships: [];
      };
      ops_alert_events: {
        Row: {
          id: string;
          alert_type: string;
          detail: Json;
          created_at: string;
        };
        Insert: {
          id?: string;
          alert_type: string;
          detail?: Json;
          created_at?: string;
        };
        Update: {
          id?: string;
          alert_type?: string;
          detail?: Json;
          created_at?: string;
        };
        Relationships: [];
      };
      invite_renewal_requests: {
        Row: Record<string, unknown>;
        Insert: Record<string, unknown>;
        Update: Record<string, unknown>;
        Relationships: [];
      };
      deep_link_events: {
        Row: Record<string, unknown>;
        Insert: Record<string, unknown>;
        Update: Record<string, unknown>;
        Relationships: [];
      };
      workspace_devices: {
        Row: {
          workspace_id: string;
          device_id: string;
          identity_hash: string;
          last_seen_at: string;
          status: string;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          workspace_id: string;
          device_id: string;
          identity_hash: string;
          last_seen_at?: string;
          status?: string;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          workspace_id?: string;
          device_id?: string;
          identity_hash?: string;
          last_seen_at?: string;
          status?: string;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      sync_usage_counters: {
        Row: {
          workspace_id: string;
          usage_month: string;
          event_count: number;
          updated_at: string;
        };
        Insert: {
          workspace_id: string;
          usage_month: string;
          event_count?: number;
          updated_at?: string;
        };
        Update: {
          workspace_id?: string;
          usage_month?: string;
          event_count?: number;
          updated_at?: string;
        };
        Relationships: [];
      };
      ledgers: {
        Row: Record<string, unknown>;
        Insert: Record<string, unknown>;
        Update: Record<string, unknown>;
        Relationships: [];
      };
      contacts: {
        Row: Record<string, unknown>;
        Insert: Record<string, unknown>;
        Update: Record<string, unknown>;
        Relationships: [];
      };
      transactions: {
        Row: Record<string, unknown>;
        Insert: Record<string, unknown>;
        Update: Record<string, unknown>;
        Relationships: [];
      };
      audit_logs: {
        Row: Record<string, unknown>;
        Insert: Record<string, unknown>;
        Update: Record<string, unknown>;
        Relationships: [];
      };
    };
    Views: Record<string, never>;
    Functions: {
      provision_workspace: {
        Args: {
          p_identity_hash: string;
          p_email: string;
        };
        Returns: {
          workspace_id: string;
          workspace_role: string;
        }[];
      };
      /** @deprecated Unsafe — see append_sync_audit_op. */
      next_global_op_seq: {
        Args: Record<string, never>;
        Returns: number;
      };
      append_sync_audit_op: {
        Args: {
          p_workspace_id: string;
          p_op_id: string;
          p_entity_type: string;
          p_entity_id: string;
          p_action: string;
          p_payload: Record<string, unknown> | null;
          p_logged_at: string;
          p_device_id: string;
        };
        Returns: {
          op_seq: number;
          server_updated_at: string;
          status: string;
        }[];
      };
      consume_sync_usage: {
        Args: {
          p_workspace_id: string;
          p_usage_month: string;
          p_events: number;
          p_cap: number;
        };
        Returns: {
          allowed: boolean;
          event_count: number;
        }[];
      };
      claim_worker_seat: {
        Args: {
          p_workspace_id: string;
          p_invited_email: string;
          p_requested_role: string;
        };
        Returns: {
          member_id: string | null;
          effective_role: WorkspaceMemberRole | null;
          seat_index: number | null;
          outcome: string;
        }[];
      };
      ensure_audit_log_partitions: {
        Args: {
          p_months_ahead?: number;
        };
        Returns: number;
      };
      peek_rate_limit: {
        Args: {
          p_bucket_key: string;
          p_capacity: number;
          p_refill_per_hour: number;
          p_cost?: number;
        };
        Returns: {
          allowed: boolean;
          tokens_remaining: number;
          retry_after_seconds: number;
        }[];
      };
      consume_rate_limit: {
        Args: {
          p_bucket_key: string;
          p_capacity: number;
          p_refill_per_hour: number;
          p_cost?: number;
        };
        Returns: {
          allowed: boolean;
          tokens_remaining: number;
          retry_after_seconds: number;
        }[];
      };
      consume_rate_limits: {
        Args: {
          p_checks: Json;
        };
        Returns: {
          allowed: boolean;
          retry_after_seconds: number;
        }[];
      };
    };
    Enums: {
      token_kind: TokenKind;
      token_state: TokenState;
    };
    CompositeTypes: Record<string, never>;
  };
};
