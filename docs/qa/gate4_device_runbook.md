# Gate 4 device runbook (heritage — Agentic / SMTP)

> **Heritage only.** This runbook targeted the **frozen** All Things Agentic service (`daftar-closing-agent-1487285471`) and SMTP-first Gate 4 proofs. **Do not use it for CALL-E v3 filming or warm-up.**

## Use instead

| Purpose | Document |
| --- | --- |
| Stage 4 phone QA (dial off, before Stage 5) | [`stage4_phone_qa.md`](stage4_phone_qa.md) |
| Stage 6 live ring filming (dial on, credit-safe window) | [`calle_live_dial_window.md`](calle_live_dial_window.md) |
| §6.3 beat sheet + film checklist | [`roadmap_v3.md`](../roadmap_v3.md) §6.3 |
| Long scenario regression | [`closing_agent_scenario_checklist.md`](closing_agent_scenario_checklist.md) |

**CALL-E service:** `daftar-call-e` (owner-ops URL). **Never** warm or deploy the frozen Agentic hostname for new work.

---

## Historical context (read-only)

Gate 4 was closed for the Agentic submission (Stage 4–5 SMTP shipped). The checklist below remains for archive reference only.

Run the full scenario pass first: [`closing_agent_scenario_checklist.md`](closing_agent_scenario_checklist.md).

Judges may score from **video**. SMTP `250` is Gmail **accept**, not mailbox-delivered. Hybrid E (`wa.me` / human Send) is a **contest-period leftover**, not substrate and not the climax. Canonical Proof of Action copy: root [`README.md`](../../README.md).

Live To: addresses stay in the gitignored overlay. This file must not contain them.

### 1. Warm Cloud Run (Appendix E) — **do not run against frozen URL**

- Service: `daftar-closing-agent` (frozen)
- Region: `us-central1`
- Project: `daftar-closing-agent`
- URL: `https://daftar-closing-agent-1487285471.us-central1.run.app` — **immutable through 13 Oct 2026**

### 2. Seed sample store (release-visible)

**Onboarding:** First ledger beat → **Try with Demo Store** / **تجربة متجر افتراضي**.

**Settings:** **Reset sample store data**.

Optional email override:

```bash
flutter run --dart-define-from-file=tool/demo_seed_emails.local.json
```

### 3. Close the day → Confirm & Send Statements (heritage SMTP climax)

1. FAB → mid-day capture → confirm.
2. Close the day → Collections Desk.
3. **Confirm & Send Statements**.

### 4. Film proofs (heritage)

| Must / Should | What |
| --- | --- |
| **Must** | SMTP **`250`** in Cloud Logging **and** at least **one inbox with PDF** |
| **Should** | Five statement messages **and** at least **one text-only remainder** inbox |
| Console | `jsonPayload.event="daftar.agent.email"` with unique `Message-ID` per row |

Logs Explorer (heritage service name):

```text
resource.type="cloud_run_revision"
resource.labels.service_name="daftar-closing-agent"
jsonPayload.event="daftar.agent.email"
```

Do **not** narrate `250` as delivered.

### 5. After film (heritage)

Architecture HUD should appear in the Stage 6 film cut. Gate 4 was closed for Agentic; CALL-E v3 film lives in §6.3.
