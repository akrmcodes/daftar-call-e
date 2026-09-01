# Daftar (دفتر) — Closing Agent

Arabic-first, offline-first debt ledger for shops that still close the day on paper, plus **Daftar Closing Agent** (وكيل إغلاق الدفتر): a **Taskmaster** workflow that captures the merchant’s **business day** (voice or text) and runs close-the-day — Drift `localDay` summary → Google Drive backup → FIFO aging → **Confirm & Send Statements** → Gmail SMTP send set.

Each Cloud Run `/run` is **fast on purpose**. The long-running task is the **shop’s day**, persisted in Drift; Cloud Run plans on demand and may scale to zero.

**Hackathon:** [All Things Agentic](https://allthingsagentichackathon.devpost.com/) · **Track:** Taskmaster · **Individual**
**Submission Period:** 3–31 Aug 2026 · **Official deadline:** 31 Aug 2026, **17:00 PDT**

The Drift / Khazna debt ledger is **pre-existing substrate** (in this repository before 3 Aug 2026) and is disclosed in [`docs/CONTEST_DISCLOSURE.md`](docs/CONTEST_DISCLOSURE.md). **Daftar Closing Agent** (Google ADK + Gemini 3.5 + Cloud Run + device HITL + Gmail SMTP) was built during the Submission Period.

Docs index: [`docs/README.md`](docs/README.md).

## Architecture (judges)

**[Contest architecture](docs/architecture/contest_architecture.md)** — Flutter ↔ Cloud Run (ADK) ↔ Gemini 3.5 ↔ Drift (source of truth) ↔ `smtp.gmail.com`.

![Daftar Closing Agent architecture](docs/architecture/contest_architecture.png)

- **HITL (Model C):** Gemini `propose_*` (+ `parse_goal` for ask / ambiguous) → merchant **Confirm** → device **Drift commit**. Close: one **Confirm & Send Statements** on the plan → device ritual (`localDay` → Drive → aging → desk) → `POST /v1/email/send-batch` (not an ADK tool).
- **§5.6 HUD:** Settings **Show agent architecture** shows model, tool scope, HITL rail (Propose → Confirm → Commit → Rank), correlation last-8, and `Sent ·` Message-ID last-8 after SMTP **250**.
- **Frozen catalog:** Eight FunctionTools on one `root_agent` — [`agent/tests/test_tool_catalog_freeze.py`](agent/tests/test_tool_catalog_freeze.py).
- **No SequentialAgent / B-Prime this submission:** Mid-day capture is one intent-dependent hop (parallel `propose_*`); the close ritual is device-deterministic after plan confirm.

Official **Architectural Discipline** (30% — also the Best Architectural Design criterion):

- **Decouple** — Cloud Run plans; Drift commits; SMTP is a sibling route, not a tool.
- **State** — Drift + `ClosingAgentPhase` on device; scoped `daftarContext` (ledger not dumped into Gemini). No vector DB — financial SoT, not RAG.
- **Credentials** — ID tokens with Cloud Run custom audiences; Gmail App Password in Secret Manager only.
- **Failures** — confirm-gate lock; Drive skip; per-row SMTP; Cloud Run down → ledger intact. Durable send key is device `batchId`.

### Proof of Action (SMTP)

Gmail SMTP **250** means the message was **accepted** into Gmail. It is **not** mailbox-delivered, **not** a read receipt, and **not** a DSN. Gmail SMTP has **no** delivery webhook — do not narrate `250` as “delivered.”

| What you should see | Meaning |
| --- | --- |
| **Inbox + PDF** | Proof of Action for the ranked **Top 5** (MIME `application/pdf`) |
| **Text-only remainder** | Intentional. Rest of the send set is Appendix C.2 `text/plain` |
| Cloud Logging `daftar.agent.email` | **250** + unique **Message-ID** per recipient |
| Device HUD `Sent ·` | Message-ID last-8 matching logs |

## Where to look

| Path | What |
| --- | --- |
| `lib/presentation/` | Flutter UI (Closing Agent, HUD, FAB coach) |
| `lib/application/` | Use cases (providers call these — never repositories) |
| `lib/domain/` | Entities, repositories (interfaces), integer money |
| `lib/data/` | Drift + Dio — not imported from presentation |
| `lib/presentation/shared/widgets/daftar_architecture_hud.dart` | §5.6 Architecture HUD |
| `lib/presentation/shared/widgets/daftar_coach_mark.dart` | First-run FAB spotlight (custom overlay) |
| `agent/closing_agent/` | ADK `root_agent` + eight FunctionTools |
| `agent/email_send/` | Sibling `POST /v1/email/send-batch` — **not** an ADK tool |
| `agent/tts/` | Sibling `POST /v1/tts` (Chirp) — **not** an ADK tool |
| `agent/openapi.yaml` | Device ↔ agent wire contract |
| `supabase/` · `link-hosting/` | Stage 8 sync/deep-link — **quarantined**, not the agent backend |
| [`docs/architecture/contest_architecture.md`](docs/architecture/contest_architecture.md) | Diagram + HITL + tool freeze |
| [`docs/contest_demo.md`](docs/contest_demo.md) | ≤4 min film script |
| [`docs/CONTEST_DISCLOSURE.md`](docs/CONTEST_DISCLOSURE.md) | Substrate vs contest-new |
| [`docs/qa/flutter_env.template.md`](docs/qa/flutter_env.template.md) | Gitignored `.env` keys |

## Implementation insights

- **One `root_agent`.** Mid-day is intent-dependent; a `SequentialAgent` pipeline would add hops without a better confirm story. Taskmaster scores a complete workflow, not a multi-agent org chart.
- **Drift is the source of truth**, not Firestore. The merchant’s day must survive Cloud Run scale-to-zero and airplane mode. Drive backup is recovery, not a second ledger.
- **SMTP is a sibling FastAPI route**, not an ADK tool. Gemini must not send money or email. Outreach consent is **Confirm & Send Statements** on the device.
- **Scale-to-zero is the design.** Idle always-on agents are a poor implementation. The durable work is on the phone.
- **Integer money only.** `amountMinor: int`. Spoken **500** on the USD demo fixture is **$500.00** (`50_000` cents).

## Proud, not all in the 4-minute cut

Ask Books (device-local); compound turns with parallel `propose_*`; audit log + soft deletes; Architecture HUD; catalog freeze tests; Arabic-first RTL; offline-first ledger; FAB coach as a custom overlay hole (not a third-party canvas).

## Binding docs

| Doc | Role |
| --- | --- |
| [`docs/README.md`](docs/README.md) | Judge vs owner vs not-judging index |
| [`docs/roadmap_v2.md`](docs/roadmap_v2.md) | **Sole execution contract** (Stages 0–7) |
| [`docs/architecture/contest_architecture.md`](docs/architecture/contest_architecture.md) | Architecture diagram + HITL |
| [`docs/contest/plan.md`](docs/contest/plan.md) | Orientation only — not a second checklist |
| [`docs/CONTEST_DISCLOSURE.md`](docs/CONTEST_DISCLOSURE.md) | Eligibility split |
| [`docs/contest_demo.md`](docs/contest_demo.md) | ≤4 min film script |
| [`docs/qa/closing_agent_scenario_checklist.md`](docs/qa/closing_agent_scenario_checklist.md) | Pre-film QA |
| [`docs/product/roadmap.md`](docs/product/roadmap.md) | Product Phase 2 — **deferred** after contest |

## Stack (contest mandate)

- **Client:** Flutter · Drift · Riverpod · go_router · Khazna (Lapis Lux)
- **Agent:** Google ADK · **Gemini 3.5+** (`gemini-3.5-flash`) · **Cloud Run** (single `closing_agent` LlmAgent)
- **Money:** integer minor units · confirm-before-commit (Model C)
- **Outreach:** Gmail SMTP after **Confirm & Send Statements**. Hybrid E (`wa.me`) is a **contest-period leftover**, not substrate and not the filmed climax.

## Spin-up (judges / collaborators)

Judges may score from **video + repo**. A live device build needs owner/collaborator OAuth + AES keys. Never paste live values into issues, Devpost, or chat. There is **no** committed `.env.example` (`.gitignore` matches `.env.*`).

**Clone checklist** (Dart SDK `^3.11.4` · Android `minSdk` 26 · package `com.akrmcodes.daftar`):

1. [`docs/CONTEST_DISCLOSURE.md`](docs/CONTEST_DISCLOSURE.md) (substrate honesty).
2. [`docs/architecture/contest_architecture.md`](docs/architecture/contest_architecture.md) (diagram + HITL).
3. `flutter pub get`
4. Copy keys from [`docs/qa/flutter_env.template.md`](docs/qa/flutter_env.template.md) into a **gitignored** repo-root `.env`. Generated `*.g.dart` is not in git — `BACKUP_AES_KEY` and `GOOGLE_SERVER_CLIENT_ID` have no defaults. Android Gradle **fails** without `GOOGLE_OAUTH_CLIENT_ID_ANDROID`. Never commit `.env`.
5. `dart run build_runner build --delete-conflicting-outputs`
6. **Flutter run:** emulator **API 34+ with Google Play**. Google sign-in for agent + Drive. Onboarding **Try with Demo Store** (or Settings **Reset sample store data**). Settings **Show agent architecture** ON for the HUD.
   - Optional To: overlay: `flutter run --dart-define-from-file=tool/demo_seed_emails.local.json` (see [`tool/demo_seed_emails.md`](tool/demo_seed_emails.md)).
   - **Do not** tap **Confirm & Send Statements** against the live service unless you own the To: addresses. Committed sample-store defaults are the **owner film fixture**; a clone would email those inboxes.

### Judge APK / emulator (no Flutter)

Judges may score from **video + repo**. Installing Flutter is optional. The contest artifact is a **release** APK (package `com.akrmcodes.daftar`, `minSdk` 26). It is signed with the **debug keystore** (sideload / emulator only — not Play Store). The binary is **not** in git (`/build/` is ignored).

**Download:** [Google Drive — `app-release.apk`](https://drive.google.com/file/d/1UZQY6gfxLuL2wN-PnQR2FcfvAibQ7oR6/view?usp=sharing) (anyone-with-link). Do not commit the APK. A GitHub Release of the same file is optional later; Drive is the hosted path unless replaced.

**Sideload (physical device):**

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

**Emulator (Android Studio, no Flutter SDK):** Device Manager → virtual device **API 34+ with Google Play** → drag the APK onto the emulator, or `adb install` the same file.

**First run:** Google sign-in until Drive is **linked** → onboarding **Try with Demo Store** (or Settings **Reset sample store data**) → Settings **Show agent architecture** ON (HUD is off in release until toggled).

**Pro+ is optional.** Closing Agent (FAB, close-the-day, Gmail SMTP) works on the **regular / Free** build. To unlock remaining product surfaces (logo / branded PDF, etc.), judges use the activation code in **Devpost Testing instructions** (not on the public project page). In the app: **Settings → Plan & activation → Add activation code**. Stage 8 multi-device sync stays quarantined even after Pro+.

**Do not** tap **Confirm & Send Statements** unless you own the compiled To: addresses (owner film plus-aliases).

**Owner rebuild** (collaborators with `.env` only): `flutter pub get` → `dart run build_runner build --delete-conflicting-outputs` → `flutter build apk --release` → output `build/app/outputs/flutter-apk/app-release.apk`.

7. **Agent:** [`agent/openapi.yaml`](agent/openapi.yaml) · deploy from `agent/` per [`agent/README.md`](agent/README.md) (`gcloud run deploy --source=.`). **Never** `adk deploy cloud_run` — that wipes `POST /v1/email/send-batch` and `POST /v1/tts`. Flags: `--no-allow-unauthenticated`, min **0** / max **2**, ID token + custom audiences. Unauthenticated GET of the `.run.app` URL is **403** (expected).
   - Gmail App Password: Secret Manager `gmail-smtp-app-password` mounted at `/secrets/gmail-smtp-app-password` on project `daftar-closing-agent` — **never** in Flutter, git, or chat.
   - Service: `https://daftar-closing-agent-1487285471.us-central1.run.app` (authenticated invokers, ID token).
8. **Pre-film QA:** [`docs/qa/closing_agent_scenario_checklist.md`](docs/qa/closing_agent_scenario_checklist.md) · warm Cloud Run before recording.

UI follows [`docs/design_system.md`](docs/design_system.md) (Khazna v3 · Lapis Law).
