# CALL-E live dial window (Stage 6 film only)

**Do not run this SOP during Stage 4 device QA.** Use [`stage4_phone_qa.md`](stage4_phone_qa.md) with dial **off** before Stage 5. Pre–Stage 5.5 owner rehearsal (not filming): [`pre_stage_5_5_rehearsal.md`](pre_stage_5_5_rehearsal.md).

This document is the **credit-safe** procedure for the one consented live ring filmed in §6.3 Video.

---

## Default (always)

| Layer | Setting |
| --- | --- |
| Cloud Run `daftar-call-e` | `CALLE_ALLOW_DIAL=false`, min instances **0**, max **2** |
| Flutter APK | No `CALLE_ALLOW_DIAL=true` dart-define |
| Credits | ~**199** remaining in pool (1 spent Gate 0); product cap **5** recipients per batch |

PSTN burns a credit only on **`calls.create`** inside `run-batch`. Device polling is **GET only** — it does not re-create. Danger appears when **both** Cloud Run and the APK have `CALLE_ALLOW_DIAL=exact true`.

---

## When to arm (film day only)

1. Stage 4 device QA and Stage 5 feature freeze are green.
2. One allowlisted **US DID** in owner-ops allowlist; provider app/webphone ready to answer.
3. Demo desk has **one** call-set row (collapse to a single US recipient for filming).
4. Cloud Run warm once on **`daftar-call-e`** (ID-token `list-apps`). Never frozen Agentic URL.

### Arm Cloud Run (short window)

```bash
export DAFTAR_CALL_E_DEPLOY=true
# Optional: min 1 only for the film window (revert to 0 after)
# export DAFTAR_CALL_E_MIN_INSTANCES=1
export DAFTAR_CALL_E_ALLOW_DIAL=true
bash agent/scripts/deploy_daftar_call_e.sh
```

Or env-only update if revision is otherwise correct:

```bash
gcloud run services update daftar-call-e \
  --project=daftar-closing-agent --region=us-central1 \
  --update-env-vars=CALLE_ALLOW_DIAL=true \
  --min=0 --max=2 --min-instances=0 --max-instances=2
```

**Never** set `DAFTAR_CALL_E_ALLOW_DIAL=true` on frozen `daftar-closing-agent`.

### Arm device (same window)

Rebuild/run with owner-ops overlay that sets **exact** `CALLE_ALLOW_DIAL=true`, allowlist = your US DID, `CALLE_ALLOWLIST_REGION=US`. Example keys in [`tool/demo_seed_emails.example.json`](../../tool/demo_seed_emails.example.json).

---

## Film take (one session)

1. Close the day → Collections Desk → **Confirm & Call** (**one tap** — `callConsented` blocks a second tap in the same desk).
2. Answer on the US DID; deliver the short consented script (“I’ll pay {integer} on {date}”).
3. Wait for terminal GET (~60s initial delay, then ~7s polls). HUD shows `runId` last-8 + status.
4. Promise card on contact; mark status if needed (Kept opens payment entry — Save still required). Narrate **promise ≠ paid**.
5. Optional: Logs Explorer `daftar.agent.call` with `action=terminal` on service `daftar-call-e`.

---

## Disarm immediately (mandatory)

Within minutes of terminal GET:

```bash
gcloud run services update daftar-call-e \
  --project=daftar-closing-agent --region=us-central1 \
  --update-env-vars=CALLE_ALLOW_DIAL=false \
  --min=0 --max=2 --min-instances=0 --max-instances=2
```

Rebuild/run the APK **without** `CALLE_ALLOW_DIAL=true`.

Verify: Settings / policy shows dial off; Confirm & Call on a fresh desk returns kill-switch refusal.

---

## Credit burn traps (avoid)

| Trap | Mitigation |
| --- | --- |
| Dial left on overnight | Disarm Cloud Run + APK immediately after the take |
| Multiple Confirm & Call on fresh close-days | Each close-day = new `batchId` = new `create` |
| §5.1 retry while armed | Do not ship retry until after film; retry = second `create` |
| `invalidHandle` replan | Min-0 can drop process-local handle between plan and run; `_planThenRun` may retry once — keep **one** recipient |
| Poll timeout | Marks failed / `needsHuman`; does **not** `run-batch` again |
| Laptop `create_and_wait` smoke | Separate from device film; uses its own idempotency file |

---

## After film

Tick §6.3 owner film-day items and Stage 6 Validation Gate (live ring, HUD last-8 vs logs). See [`roadmap_v3.md`](../roadmap_v3.md) beat sheet.
