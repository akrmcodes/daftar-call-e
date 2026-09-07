# QA

Owner / film notes. **Not** the first-pass judging pack.

**Judges (start here):** root [`README.md`](../../README.md) → [`docs/README.md`](../README.md) → [`CONTEST_DISCLOSURE.md`](../CONTEST_DISCLOSURE.md) → [`architecture/contest_architecture.md`](../architecture/contest_architecture.md) → [`contest_demo.md`](../contest_demo.md) → [`devpost_draft.md`](devpost_draft.md) → [`flutter_env.template.md`](flutter_env.template.md).

| Document | Role |
| --- | --- |
| [`stage4_phone_qa.md`](stage4_phone_qa.md) | **Stage 4 device QA (dial off)** — run before Stage 5 |
| [`calle_live_dial_window.md`](calle_live_dial_window.md) | Stage 6 live ring SOP (credit-safe; dial on briefly) |
| [`closing_agent_scenario_checklist.md`](closing_agent_scenario_checklist.md) | Long pre-film regression (Passes 0–13) |
| [`gate4_device_runbook.md`](gate4_device_runbook.md) | **Heritage** Agentic SMTP film-day archive — do not use for CALL-E warm-up |
| [`devpost_draft.md`](devpost_draft.md) | Paste-ready Devpost fields |
| [`flutter_env.template.md`](flutter_env.template.md) | Gitignored `.env` keys |

**Binding contract:** [`docs/roadmap_v3.md`](../roadmap_v3.md). Heritage Agentic calendar: [`roadmap_v2.md`](../roadmap_v2.md) (frozen — do not execute).

## SMTP Proof of Action

Canonical judge copy is the root [`README.md`](../../README.md) Proof of Action table.

- Gmail SMTP **250** = **accept**, not mailbox-delivered. Do not fake delivery webhooks.
- Film **inbox + PDF** (ranked Top 5) and at least one **text-only remainder**.
- Hybrid E (`wa.me`) is a **contest-period leftover**, not substrate and not the filmed climax.
- Sample store: onboarding **Try with Demo Store** or Settings **Reset sample store data**. Optional overlay: [`tool/demo_seed_emails.md`](../../tool/demo_seed_emails.md).

## CALL-E dial policy

- **Default:** Cloud Run `daftar-call-e` + APK keep `CALLE_ALLOW_DIAL=false` (min instances 0).
- **Stage 4 exit:** [`stage4_phone_qa.md`](stage4_phone_qa.md) — no live ring.
- **Stage 6 film:** [`calle_live_dial_window.md`](calle_live_dial_window.md) — arm dial only for the take, disarm immediately.

Archived multi-device QA: [`docs/archive/stage_8_5_8_6_android_two_phone.md`](../archive/stage_8_5_8_6_android_two_phone.md).
