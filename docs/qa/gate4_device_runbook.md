# Gate 4 device runbook

Owner film-day checklist. Gate 4 is **closed** (Stage 4–5 shipped). Keep this file for the proofs the locked cut already required.

Run the full scenario pass first: [`closing_agent_scenario_checklist.md`](closing_agent_scenario_checklist.md).

Judges may score from **video**. SMTP `250` is Gmail **accept**, not mailbox-delivered. Hybrid E (`wa.me` / human Send) is a **contest-period leftover**, not substrate and not the climax. Canonical Proof of Action copy: root [`README.md`](../../README.md).

Live To: addresses stay in the gitignored overlay. This file must not contain them.

## 1. Warm Cloud Run (Appendix E)

Cold start must not be the on-camera `/run` or send-batch.

- Service: `daftar-closing-agent`
- Region: `us-central1`
- Project: `daftar-closing-agent`
- URL: `https://daftar-closing-agent-1487285471.us-central1.run.app`

```bash
SERVICE_URL=https://daftar-closing-agent-1487285471.us-central1.run.app
TOKEN=$(gcloud auth print-identity-token)
curl -sS -H "Authorization: Bearer $TOKEN" "$SERVICE_URL/list-apps"
# → ["closing_agent"]
```

Invoker stays ID-token (`allAuthenticatedUsers` is OK). **No** `allUsers`. **No** `daftar-wa-webhooks`.

## 2. Seed sample store (release-visible)

**Onboarding:** First ledger beat → **Try with Demo Store** / **تجربة متجر افتراضي** (set Language to English for foreign judges).

**Settings:** **Reset sample store data** (confirm → brief report).

Optional email override:

```bash
flutter run --dart-define-from-file=tool/demo_seed_emails.local.json
```

Defaults route to owner plus-aliases (`akrm.codes+demo1` … `qubati.akrm+demo7`). Drive linked. Do not use the debug 1000-txn perf seed. Overlay keys: [`tool/demo_seed_emails.md`](../../tool/demo_seed_emails.md).

## 3. Close the day → Confirm & Send Statements

1. FAB → mid-day capture (`Mohamed owes 500 sugar` / `محمد عليه ٥٠٠ سكر`) → confirm.
2. Close the day: plan → Drift `localDay` summary → Drive (fail does not abort) → Collections Desk (send set of **7**; 5 statement / 2 reminder-only).
3. **Confirm & Send Statements**. One tap covers the whole send set. Do not open `wa.me`.

**Skip outreach** is a **separate** pass: skip the desk with **no** SMTP; report must stay truthful.

## 4. Film proofs

| Must / Should | What |
| --- | --- |
| **Must** | SMTP **`250`** in Cloud Logging **and** at least **one inbox with PDF** (ranked Top 5 / statement set) |
| **Should** | Five statement messages **and** at least **one text-only remainder** inbox |
| Console | `jsonPayload.event="daftar.agent.email"` with unique `Message-ID` per row |

Logs Explorer:

```text
resource.type="cloud_run_revision"
resource.labels.service_name="daftar-closing-agent"
jsonPayload.event="daftar.agent.email"
```

Do **not** narrate `250` as delivered. Do **not** fake `daftar.agent.whatsapp.status` / `delivered`.

## 5. After film

Tick §4.11 Manual Gate 4 and the Stage 4 Validation Gate only when the Must row is true on camera. **Architecture HUD** should appear in the Stage 6 film cut (see [`contest_demo.md`](../contest_demo.md)). Gate 4 is already closed; this section is the historical exit rule.
