# Stage 4 device QA (dial off)

Owner phone pass **before Stage 5**. This is **not** filming. PSTN must stay off.

**Binding contract:** [`docs/roadmap_v3.md`](../roadmap_v3.md) §4.5 + Stage 4 Validation Gate.

**Live ring (Stage 6 film only):** [`calle_live_dial_window.md`](calle_live_dial_window.md) — do **not** run that SOP during this pass.

Full scenario regression (optional, longer): [`closing_agent_scenario_checklist.md`](closing_agent_scenario_checklist.md).

---

## Preconditions (do once)

1. **Cloud Run lock** — service `daftar-call-e` only (never frozen `daftar-closing-agent`):
   - `CALLE_ALLOW_DIAL=false`
   - min instances **0**, max **2** (service + revision layers)
   - Verify with `gcloud run services describe daftar-call-e` (project `daftar-closing-agent`, region `us-central1`). Do not print allowlist E.164 or secrets.
2. **Flutter `.env`** — `CLOSING_AGENT_BASE_URL` from `$HOME/.daftar-owner-ops/daftar-call-e-url` only. Never the frozen Agentic hostname.
3. **Dedicated demo profile** — package `com.akrmcodes.daftar`. Do not overwrite the Agentic judging APK.
4. **Dial off on device** — do **not** pass `--dart-define=CALLE_ALLOW_DIAL=true`. Overlay [`tool/demo_seed_emails.example.json`](../../tool/demo_seed_emails.example.json) keeps `CALLE_ALLOW_DIAL` empty.
5. **Settings** — Architecture HUD on. GlowPill **Allow CALL-E outbound** should read off (compile-time until §5.2).
6. **Seed** — onboarding **Try with Demo Store** or Settings **Reset sample store data**. Optional email overlay: `flutter run --dart-define-from-file=tool/demo_seed_emails.local.json`.
7. **Warm `daftar-call-e` once** (cold start ~30s after min 0):

```bash
SERVICE_URL="$(cat "$HOME/.daftar-owner-ops/daftar-call-e-url")"
TOKEN=$(gcloud auth print-identity-token)
curl -sS -H "Authorization: Bearer $TOKEN" "$SERVICE_URL/list-apps"
# → ["closing_agent"]
```

Never warm `daftar-closing-agent-1487285471`.

---

## Pass A — Call rail, zero PSTN

1. Mid-day capture → **Close the day** → Collections Desk with **US + YE** overdue rows.
2. **Confirm & Call** (one tap only):
   - Expect **kill switch** / `needsHuman` / failed call progress — **no ring**, no PSTN credit burn.
   - YE row still shows **Can't call** (`callUnavailable`).
   - **Confirm & Send Statements** still visible after consent.
3. **Confirm without calling** once — email rail remains available.
4. **Airplane mode** (or disable Wi‑Fi) → retry Confirm & Call or desk action:
   - Ledger intact; localized ErrorTranslator copy; no silent retry-create.

**Pass criteria:** No `run-batch` success that implies `calls.create` while dial is off. YE never in call set.

---

## Pass B — Email rail independent

1. Same desk session (or fresh close-day): **Confirm & Send Statements**.
2. Expect SMTP **250** + Message-ID per row; Architecture HUD **Sent ·** last-8.
3. If email overlay is set: at least one **PDF** inbox (ranked Top 5) and one **text-only** remainder.
4. **Skip outreach** once on a separate pass: no SMTP; closing report truthful.

**Pass criteria:** YE / `callUnavailable` rows still emailed when pending. SMTP `250` ≠ delivered (do not narrate as inbox-delivered).

---

## Pass C — HUD / observability (no live ring)

1. After Pass A kill-switch attempt: HUD call chip must **not** say `delivered` or `paid`.
2. Optional laptop — Logs Explorer on **`daftar-call-e`**:

```text
resource.type="cloud_run_revision"
resource.labels.service_name="daftar-call-e"
jsonPayload.event="daftar.agent.email"
```

For call events (plan rows may log; terminal only on terminal GET — no per-poll spam):

```text
resource.type="cloud_run_revision"
resource.labels.service_name="daftar-call-e"
jsonPayload.event="daftar.agent.call"
```

---

## Pass D — Do not do during Stage 4 QA

- No `CALLE_ALLOW_DIAL=true` on Cloud Run or the APK.
- No live US DID ring.
- No Gate 4 / §6.3 filming.
- No Stage 5.1 retry (second `calls.create`).
- No `gcloud run deploy` unless fixing a misconfigured `daftar-call-e` revision.
- No `DAFTAR_CALL_E_ALLOW_DIAL=true`.

---

## Exit

When all Pass A–C criteria are met, tick §4.5 and Stage 4 Validation Gate in [`roadmap_v3.md`](../roadmap_v3.md). Then start Stage 5.

Live ring + HUD last-8 vs Cloud Logging proof moves to **§6.3 Video** / Stage 6 Validation Gate.
