> **Archived — not binding for All Things Agentic (Submission Period 3–31 Aug 2026).**
> Contest execution contract: `docs/roadmap_v2.md`.
> Original date retained for historical accuracy.

# Stage 8.5 & 8.6 — Two-Phone Android QA Runbook

Manual QA for **deep-link worker invites** (§8.5 resolve → §8.6 accept → claim → worker sync) on a **local Supabase stack** over LAN.

**Scope:** Stages 8.4 (sync), 8.5 (deep links), 8.6 (invite acceptance).  
**Out of scope for this runbook:** Play Install Referrer end-to-end (requires `daftar.app` deploy + Play internal testing).

---

## Prerequisites

| Item | Detail |
|------|--------|
| **Phone A** | Owner Google account; will unlock **Pro+** on device |
| **Phone B** | Different Google account; **exact email** used in worker invite |
| **Mac** | Supabase CLI, Docker, Flutter SDK |
| **Network** | Both phones on same Wi‑Fi as Mac; USB debugging enabled |
| **Google Cloud** | Debug SHA-1 on Android OAuth client (both phones) |

### Accounts checklist

- [ ] `owner@gmail.com` — Phone A Google Sign-In
- [ ] `worker@gmail.com` — Phone B Google Sign-In (must match invite email exactly)
- [ ] Two real Google accounts you can pick in the Sign-In picker

---

## Quick start

```bash
cd /path/to/daftar
chmod +x tool/qa_preflight.sh
./tool/qa_preflight.sh
```

Follow any warnings, then continue with **Pre-flight** below.

---

## Pre-flight (Mac, ~10 min)

### 1. Confirm LAN IP

```bash
ipconfig getifaddr en0
```

If it is **not** the IP in your `.env`, update project root `.env`:

```env
ACTIVATION_API_BASE_URL=http://<NEW_IP>:54321/functions/v1
SUPABASE_URL=http://<NEW_IP>:54321
```

Regenerate envied code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

> **Critical:** After any `.env` change, **fully stop and restart** the app on both phones.

### 2. Start Supabase with a clean DB

```bash
supabase start
supabase db reset    # recommended — wipes old workspaces/tokens
supabase status     # copy publishable/anon key → SUPABASE_PUBLISHABLE_KEY in .env if needed
```

Re-run `build_runner` only if you changed `.env`.

**Required migrations (applied by `db reset`):**

- `20260802180000_stage_8_4_sync_engine.sql`
- `20260803170000_fix_provision_workspace_ambiguity.sql`
- `20260804120000_grant_service_role_sync_tables.sql`
- `20260804140000_stage_8_5_deep_link_attribution.sql`

### 3. Verify Edge secrets

`supabase/config.toml` must include:

```toml
[edge_runtime.secrets]
JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"
```

`supabase/functions/.env` must have matching `JWT_SECRET` plus Google OAuth client IDs.

### 4. Network sanity checks

| Check | URL | Expected |
|-------|-----|----------|
| Mac Studio | `http://127.0.0.1:54323` | Supabase Studio |
| Each phone browser (same Wi‑Fi) | `http://<LAN_IP>:54321` | Kong JSON (not timeout) |

### 5. Edge logs (keep open)

```bash
docker logs -f supabase_edge_runtime_daftar 2>&1
```

---

## Build & install (~5 min)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter devices
```

Install on both phones (`flutter run -d <device_id>` or shared debug APK).  
**Full stop + restart** after any `.env` change.

---

## Phone A — Owner (~15 min)

| Step | Action |
|------|--------|
| A.1 | Complete onboarding |
| A.2 | Settings → Google Sign-In with **owner@gmail.com** |
| A.3 | Settings → Premium → enter offline Pro+ code (see below) |
| A.4 | Settings → Sync → **Sync now** — expect `auth_bridge_success`, no HTTP 503 |
| A.5 | Settings → Team → invite **worker@gmail.com** (exact match) → copy invite URL |

### Generate offline Pro+ code (Phone A)

```bash
dart run tool/generate_offline_activation_code.dart proplus
```

Paste into Settings → Premium → vault seal field. The field is a **single flexible input** with auto-dashes (`PROPLUS-XXXX-XXXX-XXXX-XXXX`). Full stop + restart is not required after typing a code, but sync JWT still needs a successful Sync now before Edge invite calls.

### Verify in Studio SQL

```sql
SELECT token, kind, state FROM deep_link_tokens
WHERE kind = 'worker_invite' ORDER BY created_at DESC LIMIT 1;

SELECT invited_email, status, role FROM workspace_members
ORDER BY created_at DESC LIMIT 3;
```

**Expect:**

- `deep_link_tokens.state = 'active'`
- `workspace_members.status = 'pending'` for worker email

Copy `<TOKEN>` from the invite URL: `https://daftar.app/i/<TOKEN>`.

---

## Phone B — Worker (~15 min)

### Fresh state (recommended)

```bash
adb -s <PHONE_B_ID> shell pm clear com.akrmcodes.daftar
```

Re-open app, complete onboarding. **Do not sign in with Google yet.**

### Open invite (most reliable on LAN)

```bash
adb -s <PHONE_B_ID> shell am start -a android.intent.action.VIEW \
  -d "https://daftar.app/i/<TOKEN_FROM_INVITE>" \
  com.akrmcodes.daftar
```

> Uses App Links intent filter in `AndroidManifest.xml`. Does **not** require `daftar.app` to be deployed.

### Expected flow

1. **Team invitation** screen (preview with invited email + role) — **not** expired ceremony
2. Tap **Sign in with Google to accept**
3. Choose **worker@gmail.com**
4. Success → **You're in** → Open Daftar

### Verify in Studio

```sql
SELECT token, state, claimed_at FROM deep_link_tokens
WHERE kind = 'worker_invite' ORDER BY created_at DESC LIMIT 1;

SELECT invited_email, status, identity_hash FROM workspace_members
WHERE invited_email = 'worker@gmail.com';

SELECT event_type FROM deep_link_events
WHERE token = '<token>' ORDER BY created_at;
```

**Expect:**

- `deep_link_tokens.state = 'claimed'`
- `workspace_members.status = 'active'`
- `deep_link_events` includes `claim_ok`

### Expected edge log order

1. `resolve-deep-link`
2. `verify-google-token`
3. `claim-deep-link`
4. Second `verify-google-token` (merchant workspace, not new solo workspace)

---

## Phone B — Sync without personal Pro+ (~5 min)

| Step | Action |
|------|--------|
| B.1 | Settings → Sync Report → **Sync now** (should work — worker JWT grants `multiDeviceSync`) |
| B.2 | On Phone A, add a small ledger change |
| B.3 | On Phone B, **Sync now** / pull — data should reconcile |

---

## Skip for now (Part 5 — Play Install Referrer)

Requires:

- Deploy `link-hosting/` to `daftar.app`
- Real `assetlinks.json` SHA-256
- Play Console internal testing track

LAN `adb` intent path above fully covers §8.6 invite acceptance.

---

## Invite flow hardening (post QA crash fix)

After rebuilding both phones (**full restart**, not hot-reload only):

| Step | Phone | Expected |
|------|-------|----------|
| H.1 | A | Team → Invite worker → **no crash** → copy/share sheet with `https://daftar.app/i/<token>` |
| H.2 | A | Kill app → reopen Team → pending row → **Copy link** re-opens URL sheet |
| H.3 | B | `adb` open invite URL once → accept or ceremony → tap **Open Daftar** / back |
| H.4 | B | Cold start from launcher → **home/onboarding**, **not** ceremony or accept again |
| H.5 | B | Expired link → Request new invite → honest copy (no push promise) |
| H.6 | A | Team → **Renewal requests** section → **Resend invite** → new link works on B |
| H.7 | B | Open accept via link → back without accepting → cold start from launcher → **not** accept screen |
| H.8 | either | Force fatal error → **Restart** relaunches app (Android) |

> Cold-start replay is suppressed via `ConsumedInitialLinkStore` (sticky `getInitialLink`) plus `HandledDeepLinkStore` (dismissed terminal/accept tokens). Merchant renewal inbox uses Edge `list-invite-renewal-requests` / `fulfill-invite-renewal-request` — restart `supabase functions serve` if 404; FCM remains §8.7.

---

## Worker join + cross-account sync

Apply DB migration `20260805120000_provision_workspace_worker_priority.sql` (`supabase db reset` or migrate) before testing.

| Step | Phone | Expected |
|------|-------|----------|
| J.1 | B | Settings → **Have an invite code?** → paste invite URL → accept screen (no adb required) |
| J.2 | B | Accept with worker Google (no personal Pro+) → success → **Sync report** visible in Settings |
| J.3 | B | Sync report → **Sync now** — no "not unlocked" error |
| J.4 | A | Add/edit ledger entry → Sync now |
| J.5 | B | Sync now → owner's data appears (same `workspace_id`, different Google accounts) |

Studio check after J.2:

```sql
SELECT wm.invited_email, wm.status, wm.role, wm.identity_hash, wm.workspace_id
FROM workspace_members wm
WHERE lower(wm.invited_email) = 'worker@gmail.com';
```

Worker JWT must use **merchant** `workspace_id` with role `editor` or `viewer` — not a solo empty owner workspace.

---

## Seamless sync (Stage 8.4 Tier 1+2)

Both phones online, apps **open** (foreground). No manual Upload/Download unless verifying diagnostics.

| Step | Phone | Expected |
|------|-------|----------|
| K.1 | A | Add transaction → **no Sync Report tap** → within ~2s B shows new entry |
| K.2 | B | Add transaction → A receives update automatically |
| K.3 | A | Airplane mode ON → add transaction → Airplane OFF → within ~5s B receives (connectivity restore + push-on-save) |
| K.4 | B | Home app (background, not killed) → A adds transaction → reopen B → data present (resume sync) |
| K.5 | B | Worker without personal Pro+ → K.1–K.2 still work (worker JWT unlock) |

> Closed-app background op-log sync (WorkManager/FCM) is **out of scope** for this band.

---

## Troubleshooting

| Symptom | First check |
|---------|-------------|
| 15s connection timeout | `ipconfig getifaddr en0` → update `.env` → `build_runner` → restart app |
| "Unable to connect to sync server" | Edge logs for 503; confirm `JWT_SECRET` in `config.toml` |
| "Network retry exhausted" on pull | `supabase db reset` (re-applies grant migration); edge logs for HTTP 500 |
| Expired ceremony on valid link | Rebuild latest app; use `adb` intent, not browser share |
| Email mismatch | Invite email must exactly match Google account on Phone B |
| Invite fails 403 | Phone A signed in + valid sync JWT + Pro+ — run Sync now before inviting |
| Team row / invite missing in debug | Hot-restart after this fix; Team requires owner role (now defaults for solo Pro+) |
| Crash after Send invite | Full rebuild (not hot reload); `AppBottomSheet` + invite sheet controller lifecycle fixed |
| Ceremony/accept on every cold start | `ConsumedInitialLinkStore` skips sticky `getInitialLink`; dismiss accept/ceremony once marks handled |
| Fatal **Restart** closes app only | Rebuild; Android `daftar/app_restarter` MethodChannel relaunches process |
| "Owner notified" but no push | Expected until FCM — owner sees **Renewal requests** in Team instead |
| Burst invites → rate limited | Expected §8.7 — localized **Too many requests** sheet (not premium upsell); wait for `retry_after` then retry |
| Third worker invite → Pro upsell | **Fixed** — should show **Team is full** sheet (`SeatCapExceededFailure`), not upgrade |
| No invite email in inbox | **Expected** — invites mint copy/share URL only; verify via success sheet + SQL on `deep_link_tokens` |
| Sync only works same Google account | Apply `provision_workspace_worker_priority` migration; worker JWT must be editor/viewer on merchant WS |
| Worker no Sync report after accept | Rebuild app; gate uses worker JWT role, not personal Pro+ |
| Manual Upload/Download required for every change | Rebuild both phones; verify K.1–K.5 (Realtime wake-up + push-on-save) |
| `syncAuthBridgeFailed` | JWT secret missing in edge worker — see Pre-flight §3 |

---

## Validation gate mapping (roadmap)

| Gate | Covered by this runbook |
|------|-------------------------|
| §8.4 two-device sync | Phone A/B sync steps |
| §8.6 worker invite accept | Phone B adb intent + Google claim |
| Worker sync without Pro+ | Phone B sync step |
| §8.5 Play Install Referrer | **Not covered** — production deploy only |

---

## Band L — §8.7 rate-limit + seat-cap UX (manual)

Apply migrations (including `20260805190000_stage_8_7_consume_rate_limits_inline.sql`):

```bash
supabase migration up
# or disposable QA: supabase db reset
```

### L.1 Seat cap (2 workers) — no Pro upsell

1. Phone A (owner, Pro+): invite **two** distinct worker emails (both pending).
2. Invite a **third** email.
3. **Expected:** **Team is full** error sheet — **not** premium upsell.
4. Revoke one pending invite, invite again — **Expected:** success + copy/share URL sheet.

### L.2 Rate limit — retry sheet (not upsell)

1. Revoke all pending workers so seats are free.
2. Burst invites (≥4/hour to same or different emails on Pro+).
3. **Expected:** **Too many requests** sheet with optional retry minutes.
4. Wait for cooldown, retry — invite succeeds.

### L.3 Verify invite minted locally (no email inbox)

Worker invites **do not send SMTP email** in this band. Proof:

1. Success sheet shows `invite_url` — copy/share manually.
2. SQL (Supabase Studio or `psql`):

```sql
select token, kind, state, expires_at, intent_payload
from deep_link_tokens
where kind = 'worker_invite'
order by created_at desc
limit 5;

select id, invited_email, status, seat_index
from workspace_members
where seat_index > 0
order by created_at desc;
```

3. **Inbucket / local mail UI:** expect **no** worker-invite messages until a transactional provider is wired.
4. Edge logs: `docker logs -f supabase_edge_runtime_daftar` — look for `[invite-worker] ok` vs `rate_limited` vs `seat_cap_exceeded`.

---

## Reference

- Full arc log: `docs/project_log.md` (2026-08-04 entry)
- Roadmap: `docs/archive/product_roadmap_phase2_v3.6.md` §8.4–§8.6
- Env template: `.env.example`
- Preflight script: `tool/qa_preflight.sh`
