/// Cold-start session resolution outcome from session bootstrap (Phase 1.3).
///
/// See `docs/product/roadmap.md` (Stage 4.5 — Auth V2) — Session Bootstrap State Machine.
///
/// [migrationRelinkRequired] and [needsReauth] exist because Drift identity and
/// silent auth outcomes must never be conflated (Auth V2 Phase 1.4 non-goals).
enum AuthSessionState {
  /// Secure bundle is valid and the Google Sign-In session is warm or
  /// recoverable via lightweight authentication.
  linked,

  /// No secure bundle and no Drift `googleAccountId` — user has never linked
  /// or completed sign-out cleanup.
  unlinked,

  /// Drift still holds a `googleAccountId` from Auth V1 but the secure bundle
  /// is absent. Requires one-time interactive re-link — never treat as signed in.
  migrationRelinkRequired,

  /// Secure bundle exists but silent authentication failed (revoked token,
  /// expired consent, or SDK session lost). User must re-authenticate.
  needsReauth,
}
