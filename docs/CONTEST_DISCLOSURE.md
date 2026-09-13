# Contest Disclosure — CALL-E: Your Code Is Calling

**Project:** Daftar Closing Agent / وكيل إغلاق الدفتر — **Confirm & Call**  
**Hackathon:** [CALL-E: Your Code Is Calling](https://call-e.devpost.com/) · individual · prize aim **Most Practical Use Case**  
**Repository:** `daftar-call-e` (`https://github.com/akrmcodes/daftar-call-e.git`)  
**Binding contract:** [`docs/roadmap_v3.md`](roadmap_v3.md) **v3.5**  
**Submission Period:** 23 Jul 2026 21:30 SGT – 14 Sep 2026 23:45 SGT  
**Devpost project start:** 1 Sep 2026  
**Date:** 2026-09-14 (final)

Per [Official Rules §4 — New & Existing](https://call-e.devpost.com/rules): a Project may be newly created **or**, if it existed before the Submission Period, **must have been significantly updated after the start of the Submission Period**. Entrants should explain that update. CALL-E is **not** “new projects only.”

**This is an existing project.** The Daftar ledger existed before 23 Jul 2026. The Closing Agent (Gemini 3.5 + ADK + Cloud Run + device HITL + Gmail SMTP) was built in **August 2026** for [All Things Agentic](https://allthingsagentichackathon.devpost.com/). That calendar **overlaps** the CALL-E window; we still **do not claim it as CALL-E-new**.

**Significant update (this submission):** **Confirm & Call** — plan confirm starts the close-the-day ritual only; dual-rail HITL is the **Collections Desk** after aging (not a paused dispatch task). After merchant **Confirm & Call**, Cloud Run **`daftar-call-e`** runs Daftar-local `plan-batch` then `run-batch` (`calle-ai==0.7.0` `CalleClient.calls.create` / `POST /v1/calls`) and the device polls `GET /v1/calls/{runId}` for allowlisted, region-eligible overdue contacts in the call set (cap **5**). The structured **promise** is integer `promised_amount_minor`, not a payment. Gmail SMTP remains the rail for Yemen / missing phone / Confirm without calling. Gemini never dials and never cashiers. The Python SDK is **imported and actually called at runtime** on `daftar-call-e`. Public demo: [YouTube](https://youtu.be/wV1QqQgAiLE) (roadmap **§6.3**). This file is eligibility, not the video.

Heritage Cloud Run `https://daftar-closing-agent-1487285471.us-central1.run.app` is **frozen All Things Agentic production** — not the CALL-E service. Do not redeploy it. Snapshot: [`contest/AGENTIC_CLOUD_RUN_FREEZE.md`](contest/AGENTIC_CLOUD_RUN_FREEZE.md). CALL-E runtime service: **`daftar-call-e`**.

**Demo destination:** the owner **owns and answers** the Callcentric US DID in **Linphone** (CALL-E Support 2026-09-09). No live number in git. Never real debtors. No friend mobile.

## Standard tools (not the significant update)

Frameworks and platforms used by the Project, **not** claimed as the CALL-E update: Flutter, Drift, Riverpod, go_router, Google ADK, Vertex Gemini 3.5 Flash, Cloud Run, Gmail SMTP, Firebase client config, Python **`calle-ai`**, CALL-E Developer API (`https://api.heycall-e.com`).

## Pre-existing substrate (not claimed as contest-new)

Offline-first debt ledger already present in this repository **before August 2026**, including:

| Area | Examples |
| --- | --- |
| Core ledger | Drift schema, ledgers / contacts / transactions / balances, soft deletes, audit log, integer money |
| Application use cases | Create/add ledger, contact, transaction; reminder eligibility; voice entity context |
| Auth V2 + Drive backup | Google Sign-In, Drive `appDataFolder`, backup queue, WorkManager auto-backup |
| UI shell | Khazna theme, main shell FAB, settings, quick-add, contact picker, PDF statements, WhatsApp URL helper ([`whatsapp_util.dart`](../lib/core/utils/whatsapp_util.dart)) |
| Activation / tiers | Entitlement engine, Pro feature flags |
| Stage 8 sync code (quarantined) | Sync/collaboration/deep-link stacks remain in tree but are **disabled** (`AppConstants.kContestDisableMultiDeviceSync`) — engines never start; not part of the submission narrative |

## Prior work — All Things Agentic (Aug 2026)

Built for a **different** hackathon. **Not CALL-E-new**, even though August 2026 sits inside the CALL-E Submission Period.

Frozen ADK catalog (eight FunctionTools, no send-email tool, no call tool): `parse_goal`, `propose_debt`, `propose_payment`, `propose_create_contact`, `propose_create_ledger`, `propose_closing_plan`, `propose_whatsapp_drafts`, `propose_statement` — enforced by [`agent/tests/test_tool_catalog_freeze.py`](../agent/tests/test_tool_catalog_freeze.py). Sibling FastAPI routes `POST /v1/email/send-batch` and `POST /v1/tts` are **not** FunctionTools.

| Area | Description | Status |
| --- | --- | --- |
| `agent/` ADK runtime | Google ADK `root_agent` · Gemini **3.5-flash** · eight frozen FunctionTools | **Landed (Agentic)** — frozen URL `https://daftar-closing-agent-1487285471.us-central1.run.app` |
| Device bridge | Dio client, confirm gate (`AgentConfirmGate`), `proposalId` single-flight | **Landed (Agentic)** |
| Day Journal | Contest Drift tables + AI audit trail use cases | **Landed (Agentic)** |
| Closing Agent UI | Plan taskmaster, confirm cards, FAB tap→AI / long-press→quick-add | **Landed (Agentic)** |
| Close-the-day ritual | Drift `localDay` summary → Drive backup → aging → Collections Desk | **Landed (Agentic)** |
| Gmail SMTP outreach | `POST /v1/email/send-batch` after **Confirm & Send Statements**; send set ≤20; MIME PDF on device-ranked Top 5 | **Landed (Agentic)** |
| Chirp TTS | Sibling `POST /v1/tts` — not an ADK tool | **Landed (Agentic)** |
| Architecture HUD | Model, tool scope, HITL rail, SMTP Message-ID last-8 after **Confirm & Send Statements** | **Landed (Agentic)** |
| FAB coach | One-shot spotlight ([`daftar_coach_mark.dart`](../lib/presentation/shared/widgets/daftar_coach_mark.dart)) | **Landed (Agentic)** |
| Sample store seeder | **Try with Demo Store** | **Landed (Agentic)** |
| Hybrid E queue | Contest-period leftover: `propose_whatsapp_drafts` + `wa.me` human send queue (prepare-only; inert desk flag). **Not** the filmed climax or SMTP fallback | **Leftover** |

## CALL-E contest-new (this submission)

The August ADK/SMTP closer is **prior work above — not this bucket.** CALL-E-new is **Confirm & Call** plus the sibling Developer API path.

| Area | Description | Status |
| --- | --- | --- |
| Confirm & Call | Device HITL on the Collections Desk (plan confirm starts the ritual only). Daftar-local `plan-batch` (zero PSTN) → `run-batch` / `calls.create` → poll `GET /v1/calls/{runId}` | **Landed** (Stages 1–5) |
| `agent/calls/` sibling | `calle-ai==0.7.0` `from calle import CalleClient`; `POST /v1/calls` (`calls.create`); poll `GET /v1/calls/{id}`; **not** an ADK tool; **no** API `confirm_token` | **Landed** (Stage 1) |
| Cloud Run `daftar-call-e` | New service, default min **0** / max **2**, ID-token only. Live dial window uses min **1** so confirm handles survive plan→run. Must not mutate the frozen Agentic URL | **Landed** (Stage 1) |
| Dual rail | Call set ≤5 (J.10 + allowlist); email remainder / YE `callUnavailable` via SMTP | **Landed** (Stages 2–3) |
| Schema 26 | `collection_call_batches` / `collection_call_runs` / `collection_promises`; `contacts.doNotCall`; integer promise only — **no** txn from the call | **Landed** (Stage 2.1) |
| HUD call chip | `runId` last-8 = CALL-E `call.id` | **Landed** (Stages 3–4) |
| Agent Skill PR | `skills/ledger-collections-call/` on awesome-phone-call-agents | **Merged** [CALLE-AI/awesome-phone-call-agents#385](https://github.com/CALLE-AI/awesome-phone-call-agents/pull/385) (2026-09-11, Ray-56; dry-run default) |

## What we are submitting

An **existing** shop ledger plus Agentic closer, **significantly updated** for CALL-E: close-of-day collections that **phone** consented, region-eligible overdue contacts via the CALL-E SDK/API and write an integer **promise** on device. Yemen and other unsupported regions stay on **email**. Money still commits **on confirm** (Model C). Stage One pass/fail is CALL-E **imported and actually called at runtime** on `daftar-call-e`. The public ≤3:00 on-device live ring is **§6.3**.
