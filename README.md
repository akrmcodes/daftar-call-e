# Daftar (دفتر) — Confirm & Call

Arabic-first, offline-first debt ledger for shops that still close the day on paper. **Daftar Closing Agent** (وكيل إغلاق الدفتر) captures the merchant’s business day, then **Confirm & Call** places consented, region-eligible overdue collections calls and writes an integer **promise** — not a payment.

**Hackathon:** [CALL-E: Your Code Is Calling](https://call-e.devpost.com/) · individual · prize aim **Most Practical Use Case**  
**Submission Period:** 23 Jul 2026 – **14 Sep 2026 23:45 SGT**  
**Binding contract:** [`docs/roadmap_v3.md`](docs/roadmap_v3.md) **v3.5** · heritage (do not execute): [`docs/roadmap_v2.md`](docs/roadmap_v2.md) **v2.8**

At close of day, shops still phone overdue customers themselves — or they forget. After HITL **Confirm & Call**, Cloud Run **`daftar-call-e`** imports `calle-ai==0.7.0` and calls `CalleClient.calls.create` (`POST /v1/calls`). Yemen and other unsupported regions stay on **email** (`callUnavailable`). Dual rail is honest coverage, not a failed dial. Gemini never dials and never cashiers.

This is an **existing** project, significantly updated in the Submission Period. Three-way split: ledger substrate (pre-Aug 2026) · All Things Agentic closer (Aug 2026, **prior work**, not claimed as CALL-E-new) · Confirm & Call (this fork). Details: [`docs/CONTEST_DISCLOSURE.md`](docs/CONTEST_DISCLOSURE.md). Docs index: [`docs/README.md`](docs/README.md).

CALL-E / AIRUDDER API traffic is **Singapore-hosted**. Names and amounts leave the device. The demo destination is the **owner’s Callcentric US DID answered in Linphone**; the owner owns and answers it (CALL-E Support 2026-09-09). No live E.164 in git. Never real debtors. No friend mobile.

## Architecture (judges)

**[Contest architecture](docs/architecture/contest_architecture.md)** — Flutter ↔ Cloud Run **`daftar-call-e`** ↔ CALL-E Developer API (`calls.create` / poll GET) ↔ Drift SoT ↔ dual-rail `smtp.gmail.com`.

![Daftar Closing Agent — Confirm & Call](docs/architecture/contest_architecture.png)

- **HITL (Model C):** Gemini `propose_*` (+ `parse_goal`) → merchant **Confirm** → device **Drift commit**. Close: plan confirm starts the ritual only → aging rank (device; Gemini does not pick IDs) → Collections Desk. **Confirm & Call** = Daftar-local `plan-batch` (zero PSTN) → `run-batch` (`calls.create`) → poll `GET /v1/calls/{runId}`. **Confirm & Send Statements** = `send-batch` → SMTP. Confirm without calling / sending is first-class.
- **Rail:** Propose → Confirm → Commit → Rank → **Validate / Create / Poll**. CALL-E is **not** an ADK tool (same sibling pattern as SMTP `send-batch`).
- **HUD:** Settings **Show agent architecture** — `Call ·` + `runId` last-8 (= CALL-E `call.id`) + terminal status; `Sent ·` Message-ID last-8 after SMTP **250**.
- **Frozen catalog:** Eight FunctionTools on one `root_agent` — no dial tool — [`agent/tests/test_tool_catalog_freeze.py`](agent/tests/test_tool_catalog_freeze.py). Production is Developer API, not MCP `plan_call` / `run_call`.

### Proof of Action

| Signal | Means | Does **not** mean |
| --- | --- | --- |
| CALL-E `task_completed` / integer `promised_amount_minor` | Structured **promise** on device | **Paid.** Never `AddTransaction` |
| Device poll `GET /v1/calls/{runId}` | Terminal status from Developer API | Webhook theater. No public webhook. No `create_and_wait` on Cloud Run |
| Gmail SMTP **250** | Gmail **accepted** the message | Delivered, read, or DSN |

## Where to look

| Path | What |
| --- | --- |
| `lib/presentation/` | Flutter UI (Closing Agent, Collections Desk, HUD) |
| `lib/application/` | Use cases (providers call these — never repositories) |
| `lib/domain/` | Entities, repositories (interfaces), integer money |
| `lib/data/` | Drift + Dio — not imported from presentation |
| `lib/presentation/shared/widgets/daftar_architecture_hud.dart` | Architecture HUD (call + SMTP chips) |
| `agent/calls/` | Sibling FastAPI `plan-batch` / `run-batch` / GET — **`calle-ai` at runtime** |
| `agent/email_send/` | Sibling `POST /v1/email/send-batch` — **not** an ADK tool |
| `agent/closing_agent/` | ADK `root_agent` + eight frozen FunctionTools (proposals only) |
| `agent/tts/` | Sibling `POST /v1/tts` (Chirp) — heritage, not the climax |
| `agent/openapi.yaml` | Device ↔ agent wire contract (J.9 calls) |
| `docs/skills/ledger-collections-call/` | Portable Agent Skill (dry-run default) |
| `supabase/` · `link-hosting/` | Stage 8 sync/deep-link — **quarantined** |
| [`docs/architecture/contest_architecture.md`](docs/architecture/contest_architecture.md) | Diagram + HITL + captions |
| [`docs/CONTEST_DISCLOSURE.md`](docs/CONTEST_DISCLOSURE.md) | Substrate vs Agentic prior vs CALL-E-new |
| [`docs/qa/flutter_env.template.md`](docs/qa/flutter_env.template.md) | Gitignored `.env` keys |

## Implementation insights

- **CALL-E is a sibling route**, not a ninth FunctionTool. Catalog freeze forbids a dial tool.
- **Drift is the source of truth.** The merchant’s day survives Cloud Run scale-to-zero. Confirm handles are process-local — live dial uses min instances **1**, then min **0**.
- **Device ranks who is called.** Allowlist + J.10 + DNC; cap **5**. YE / unsupported → email / `callUnavailable`.
- **Integer money only.** `amountMinor: int`. Coerce `promised_amount_minor` or `needsHuman`.
- **Hybrid E** (`wa.me`) is a contest-period leftover — not substrate and not the filmed climax.

Confirm & Call **stays in the product** after the hackathon. Dual rail remains how Daftar covers shops CALL-E cannot dial. Phase 2 (sync / RevenueCat) stays deferred.

## Binding docs

| Doc | Role |
| --- | --- |
| [`docs/roadmap_v3.md`](docs/roadmap_v3.md) **v3.5** | **Binding** CALL-E execution contract |
| [`docs/roadmap_v2.md`](docs/roadmap_v2.md) **v2.8** | Frozen All Things Agentic heritage — **do not execute** |
| [`docs/README.md`](docs/README.md) | Judge vs owner vs not-judging index |
| [`docs/architecture/contest_architecture.md`](docs/architecture/contest_architecture.md) | Architecture diagram + HITL Validate / Create / Poll |
| [`docs/CONTEST_DISCLOSURE.md`](docs/CONTEST_DISCLOSURE.md) | Eligibility split (final) |
| [`docs/contest/plan.md`](docs/contest/plan.md) | Orientation only — not a second checklist |
| [`docs/qa/calle_live_dial_window.md`](docs/qa/calle_live_dial_window.md) | Film-day arm / disarm (`daftar-call-e` only) |
| [`docs/product/roadmap.md`](docs/product/roadmap.md) | Product Phase 2 — **deferred** |

## Stack

- **Client:** Flutter · Drift · Riverpod · go_router · Khazna (Lapis Lux)
- **Planner (proposals only):** Google ADK · `gemini-3.5-flash` · Cloud Run **`daftar-call-e`**
- **Call rail:** Python **`calle-ai==0.7.0`** · Developer API `https://api.heycall-e.com` · Secret Manager `calle-api-key`
- **Email rail:** Gmail SMTP after **Confirm & Send Statements** · Secret Manager `gmail-smtp-app-password`
- **Money:** integer minor units · confirm-before-commit (Model C)

## Spin-up (judges / collaborators)

Judges may score from **public video + this repo + skill dry-run**. They are not required to install the APK. A live device build needs owner/collaborator OAuth + AES keys. Never paste live values into issues, Devpost, or chat. There is **no** committed `.env.example` (`.gitignore` matches `.env.*`).

**Skill dry-run** (no `CALLE_API_KEY`): [`docs/skills/ledger-collections-call/`](docs/skills/ledger-collections-call/) — default is dry-run; never posts without `--live`.

**Clone checklist** (Dart SDK `^3.11.4` · Android `minSdk` 26 · package `com.akrmcodes.daftar`):

1. [`docs/CONTEST_DISCLOSURE.md`](docs/CONTEST_DISCLOSURE.md) (substrate honesty).
2. [`docs/architecture/contest_architecture.md`](docs/architecture/contest_architecture.md) (diagram + HITL).
3. `flutter pub get`
4. Copy keys from [`docs/qa/flutter_env.template.md`](docs/qa/flutter_env.template.md) into a **gitignored** repo-root `.env`. `CLOSING_AGENT_BASE_URL` Envied default is **empty** — point it at **`daftar-call-e` only** (`$HOME/.daftar-owner-ops/daftar-call-e-url`). Never the frozen Agentic hostname. Generated `*.g.dart` is not in git — `BACKUP_AES_KEY` and `GOOGLE_SERVER_CLIENT_ID` have no defaults. Android Gradle **fails** without `GOOGLE_OAUTH_CLIENT_ID_ANDROID`. Never commit `.env`.
5. `dart run build_runner build --delete-conflicting-outputs`
6. **Flutter run:** emulator **API 34+ with Google Play**. Google sign-in for agent + Drive. Onboarding **Try with Demo Store** (or Settings **Reset sample store data**). Settings **Show agent architecture** ON for the HUD.
   - Confirm & Call overlay (gitignored): `flutter run --dart-define-from-file=tool/demo_seed_emails.local.json` then **Reset sample store**. Without it, demo phones are Yemen-only. See [`tool/demo_seed_emails.md`](tool/demo_seed_emails.md).
   - **Do not** tap **Confirm & Call** or **Confirm & Send Statements** against the live service unless you own the destination DID and To: addresses. Committed sample-store defaults are the **owner film fixture**.
7. **Agent:** runtime service **`daftar-call-e`** (`https://daftar-call-e-1487285471.us-central1.run.app`) — ID-token only. Unauthenticated GET is **403** (expected). No `allUsers`. Deploy **only** via [`agent/scripts/deploy_daftar_call_e.sh`](agent/scripts/deploy_daftar_call_e.sh). **Never** `adk deploy cloud_run`. **Never** deploy, update, or change IAM on frozen All Things Agentic `daftar-closing-agent` (describe-only through 13 Oct 2026).
   - Secrets (Cloud Run file mounts, **never** Flutter / git / chat): `calle-api-key`, `gmail-smtp-app-password`.
8. **Film-day arm / disarm** (owner, §6.3): [`docs/qa/calle_live_dial_window.md`](docs/qa/calle_live_dial_window.md). Kill switch default is off. UI follows [`docs/design_system.md`](docs/design_system.md) (Khazna v3 · Lapis Law).

### Optional APK (not required to score)

Installing Flutter is optional. A **release** APK (package `com.akrmcodes.daftar`, `minSdk` 26, debug-keystore sideload only) may be hosted outside git. The binary is **not** in this repository (`/build/` is ignored). Stage 8 multi-device sync stays quarantined. Do **not** put Pro+ activation codes in git or this README.
