> **Archived — not binding for All Things Agentic (Submission Period 3–31 Aug 2026).**
> Contest execution contract: `docs/roadmap_v2.md`.
> Original date retained for historical accuracy.

# Auth Cold-Start Validation Matrix

Manual device checklist for verifying Google session persistence after the cold-start auth fix (cached OAuth token + bootstrap credential gate). Run on **physical** Android (Samsung/OEM) and iOS devices — emulators do not reproduce OEM Google Play Services cold-start races.

**Implementation status (code):** Bootstrap returns `linked` when `AuthSessionBundle.hasValidCachedAccessToken` is true even if `attemptLightweightAuthentication()` returns null. Tokens are captured atomically at interactive sign-in from `authorizeScopes` return value. Android secure storage uses `encryptedSharedPreferences: true`.

## Prerequisites

- Valid `GOOGLE_SERVER_CLIENT_ID` in `.env`
- Preflight screen enabled: Settings → Developer → Preflight smoke test (if routed)
- Fresh install or cleared app data for baseline tests

## Matrix

| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Interactive sign-in on Account screen | `linked` state, email visible, Connected badge |
| 2 | Force-kill app (swipe away from recents) | — |
| 3 | Relaunch within 5 minutes | Account shows email + **Restore access** OR **Connected** if SDK silent auth succeeds |
| 4 | Preflight → Silent Sign-In | `attemptLightweightAuthentication` returns account OR logs null (document platform) |
| 5 | Preflight → Drive round-trip | Upload/list/download/delete succeeds without Settings navigation |
| 6 | Force-kill → wait 60+ minutes → relaunch | If silent auth null, cached access token should still allow Drive round-trip until TTL (~55 min from last token capture) |
| 7 | Sign out | Bundle deleted, `unlinked` state |
| 8 | Background auto-backup (if enabled) | Workmanager task completes or shows `needs_reauth` notification — never interactive UI |

## Failure triage

| Symptom | Likely cause |
|---------|----------------|
| `unlinked` after kill (no email) | Bundle not written — check secure storage / sign-in finalize |
| Email visible, `needsReauth` | Expected when SDK lightweight auth fails; Drive should still work via cached token or foreground self-heal |
| Drive fails in foreground | Check OAuth client IDs (web + Android SHA-1), scope grant at link time |
| Drive fails headless only | Cached token expired; user must restore access interactively once |

## Recording results

Log device model, OS version, and preflight output for each matrix row. File issues with the silent-auth log line and bootstrap state (`linked` / `needsReauth` / `unlinked`).
