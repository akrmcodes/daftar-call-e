# Daftar — Project Log

**Not a judging artifact.** Append-only engineering journal for the owner and later agents. Newest entries at the bottom. Maintained per `.cursor/rules/project-log.mdc`.

Judges: start at [`README.md`](../README.md) and [`docs/README.md`](README.md).

> **Binding contest contract (historical Agentic):** [`docs/roadmap_v2.md`](roadmap_v2.md) (Submission Period 3–31 Aug 2026).
> **CALL-E (this fork, from 2026-09-01):** [`docs/roadmap_v3.md`](roadmap_v3.md) **v3.2**.
> Entries dated **before 3 Aug 2026** document the **disclosed ledger substrate** (and earlier product Phase 2 work), not contest-new agent deliverables.
> Product Phase 2 mega-roadmap is deferred — see [`docs/product/roadmap.md`](product/roadmap.md) stub + [`docs/archive/`](archive/).


## 2026-08-13 — Stage 0.2 Enable GCP APIs

### Context
Owner requested completion of roadmap §0.2: enable all contest-stack Google Cloud APIs on project `daftar-closing-agent` before Stage 1 (ADK + Cloud Run + Gemini).

### Done
- Ran `gcloud services enable` for all 13 APIs listed in [`docs/roadmap_v2.md`](roadmap_v2.md) §0.2 on project `daftar-closing-agent`
- Verified each API reports `ENABLED` via `gcloud services list --enabled` (13 Aug 2026)
- Updated §0.2 checkbox in [`docs/roadmap_v2.md`](roadmap_v2.md)
- Updated §4 in [`docs/GATE0_OWNER_CHECKLIST.md`](GATE0_OWNER_CHECKLIST.md)

### Architecture / decisions
- API set unchanged from roadmap v2.2 — matches ADK Cloud Run deploy codelab baseline plus Speech/TTS for Stage 5 voice stretch
- `generativelanguage.googleapis.com` enabled alongside Vertex (`aiplatform.googleapis.com`) for flexibility; runtime will prefer Vertex + SA per §0.3
- Console URL for manual spot-check: https://console.cloud.google.com/apis/dashboard?project=daftar-closing-agent

### Ops / verification
```bash
gcloud config get-value project   # daftar-closing-agent
gcloud services enable ...        # Operation finished successfully
# Per-API loop: 13/13 ENABLED
```

### Status
§0.2 complete. Next Gate 0 owner ops: §0.1 Vertex routing env plan, §0.4 quarantine validation.

## 2026-08-13 — Stage 0.3 Identity & Secret Manager

### Context
Owner requested §0.3: runtime service account for contest ADK agent on Cloud Run with least-privilege IAM, Secret Manager posture, and git secret hygiene verification.

### Done
- Created SA `agent-runner@daftar-closing-agent.iam.gserviceaccount.com` (display: Daftar Closing Agent runtime)
- Project IAM bindings on SA:
  - `roles/aiplatform.user` — Vertex / Gemini via ADC
  - `roles/secretmanager.secretAccessor` — runtime secret injection
  - `roles/logging.logWriter` — Cloud Run structured logs
  - `roles/speech.client` — classic Cloud Speech-to-Text
- Verified `.gitignore` patterns (`*.env`, `.env.*`, `client_secret_*.json`, `client_*.plist`) via `git check-ignore`; zero tracked secret-pattern files in git
- Updated §0.3 in [`docs/roadmap_v2.md`](roadmap_v2.md) and §5 in [`docs/GATE0_OWNER_CHECKLIST.md`](GATE0_OWNER_CHECKLIST.md)

### Architecture / decisions
- **Vertex + SA only** for Gemini — no API key in Flutter; optional API key (if ever needed) → Secret Manager → Cloud Run env/secret mount only
- **Text-to-Speech:** API enabled in §0.2; Google documents no predefined IAM role for the standard Synthesis API — SA auth + enabled API suffices (per [TTS access control](https://cloud.google.com/text-to-speech/access-control))
- **Speech-to-Text:** `roles/speech.client` grants `recognizers.recognize` without admin/editor scope
- Stage 1 deploy: pass `--service-account=agent-runner@daftar-closing-agent.iam.gserviceaccount.com` on `adk deploy cloud_run`
- Console IAM: https://console.cloud.google.com/iam-admin/serviceaccounts?project=daftar-closing-agent

### Ops / verification
```bash
gcloud iam service-accounts describe agent-runner@daftar-closing-agent.iam.gserviceaccount.com
gcloud projects get-iam-policy daftar-closing-agent \
  --flatten=bindings[].members \
  --filter="bindings.members:agent-runner" --format="table(bindings.role)"
# → aiplatform.user, secretmanager.secretAccessor, logging.logWriter, speech.client
git ls-files | rg '\.env|client_secret|client_.*\.plist'  # empty
```

### Status
§0.3 complete. Next: §0.1 Vertex routing env vars, §0.4 quarantine manual validation, Stage 1 deploy.

## 2026-08-13 — Stage 0.4 Quarantine review, copy, and hardening

### Context
Owner requested meticulous review of Stage 8 client quarantine (§0.4). Prior kill-switch work was verified; remaining gap was Pro+ sync marketing on the Plans/activation demo path, plus defense-in-depth so invite/JWT/deep-link code cannot hit contest-forbidden Edge Functions.

### Done
- **Audit confirmed** runtime/UI/route/mutation/Drive-safe quarantine already landed (`kContestDisableMultiDeviceSync`, engine stubs, settings hide, route redirects, permission owner stub)
- **Contest copy** (product ARB keys kept; flip-switch safe):
  - `premiumHeroTaglineContest`, `tierCardTaglineProPlusContest`, `tierCardHighlightProPlus2Contest` in [`app_ar.arb`](../lib/core/l10n/app_ar.arb) / [`app_en.arb`](../lib/core/l10n/app_en.arb)
  - Gated in [`activation_screen.dart`](../lib/presentation/screens/premium/activation_screen.dart), [`plan_tier_card.dart`](../lib/presentation/screens/premium/widgets/plan_tier_card.dart)
  - Omit `tierFeatureSync` compare row when kill-switch on ([`plan_compare_section.dart`](../lib/presentation/screens/premium/widgets/plan_compare_section.dart))
- **Defense-in-depth:**
  - [`ExchangeSyncTokenUseCase`](../lib/application/auth/exchange_sync_token_use_case.dart) — never calls Auth Bridge when quarantined
  - [`DeepLinkController`](../lib/presentation/providers/deep_link_providers.dart) — no AppLinks subscribe / resolve / claim
  - [`canUseFeature(multiDeviceSync)`](../lib/presentation/providers/entitlement_providers.dart) forced false
  - [`CollaborationGate`](../lib/application/collaboration/collaboration_gate.dart) denies before entitlement
- Tests: unlock always false; exchange never hits bridge — both green
- Roadmap §0.4 marketing-copy checkbox marked; owner smoke left unchecked

### Architecture / decisions
- Soften copy via *additional* contest ARB keys — do not delete product sync marketing strings
- Drive backup / `PendingCloudSyncStore` / session bootstrap untouched
- Manifest App Links left in tree (policy: code stays; runtime no-op + route redirect)

### Ops / verification
```bash
flutter gen-l10n
flutter test test/application/auth/exchange_sync_token_use_case_test.dart \
  test/application/sync/is_multi_device_sync_unlocked_use_case_test.dart
# → All tests passed (5)
dart analyze …touched files → no issues
```

### Status
§0.4 agent work complete. **Owner still must:** cold-start smoke, Drive sign-in smoke, Gate 0 credits/budget visibility, §0.1 Vertex routing env. Do not start Stage 1 until Validation Gate is complete.

## 2026-08-13 — Fix Drive AppAuth PKCE redirect (scheme mismatch)

### Context
Owner reported: Backup → Complete Google Drive permissions → Continue → Chrome loads briefly then lands on Google Search (new account same). Working tree `/Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar` still completed the grant. Suspected Stage 8 quarantine; root cause was build config.

### Done
- Restored gitignored contest root `.env` from the working project (read-only on working tree)
- Hardened [`android/app/build.gradle.kts`](../android/app/build.gradle.kts): missing/invalid `GOOGLE_OAUTH_CLIENT_ID_ANDROID` now **fails the build** (no silent `com.akrmcodes.daftar` fallback)
- `flutter clean` + `:app:processDebugMainManifest` — merged debug manifest now registers  
  `android:scheme="com.googleusercontent.apps.1006508283232-d81m4q7jt8q3b4r830njsg85b9l1qdsu"` + path `/oauth2redirect`
- Documented in [`docs/GATE0_OWNER_CHECKLIST.md`](GATE0_OWNER_CHECKLIST.md) §6

### Architecture / decisions
- **Not** a Drive use-case / quarantine bug — Dart `DriveOfflineGrantDs` matches working tree
- Runtime `env.g.dart` already embedded the real Android client ID; Gradle without `.env` registered a **different** redirect scheme → consent redirect had no receiver
- `.env` remains gitignored; never commit

### Ops / verification
```bash
# Before: scheme=com.akrmcodes.daftar
# After:  scheme=com.googleusercontent.apps.1006508283232-d81m4q7jt8q3b4r830njsg85b9l1qdsu
./gradlew :app:processDebugMainManifest  # BUILD SUCCESSFUL
```
Owner must **reinstall** via `flutter run` (clean wiped the prior install artifacts) then smoke: Complete Drive permissions → return to app → upload.

### Status
Config fix landed. Drive smoke still owner-side after fresh install.

## 2026-08-13 — Stage 1.0 Wire contract (Appendix J → OpenAPI)

### Context
Stage 0 Validation Gate complete. Owner requested §1.0: freeze device↔agent wire contract before Flutter UI / ADK deploy.

### Done
- Created [`agent/openapi.yaml`](../agent/openapi.yaml) (OpenAPI 3.1) encoding Appendix J:
  - ADK paths: `GET /list-apps`, session create, `POST /run`
  - `DeviceAgentRequest` via `stateDelta.daftarContext`
  - `AgentProposal` envelope + all §1.2 tool payloads; `amountMinor` **integer only**
  - Auth: Google ID token primary; `X-Daftar-Agent-Secret` fallback
  - Confirm/cancel schemas (device-side Stage 2; not Cloud Run routes)
- Created [`agent/README.md`](../agent/README.md)
- Marked roadmap §1.0 checkboxes; updated [`docs/CONTEST_DISCLOSURE.md`](CONTEST_DISCLOSURE.md) + root README pointers

### Architecture / decisions
- Single OpenAPI artifact (no separate tool-schema pack until §1.2 implements ADK tools)
- Context carriage locked: `daftarContext` + `goalText` in `newMessage`
- No Python ADK / Cloud Run deploy in this band (§1.1+)

### Ops / verification
```bash
ruby -ryaml -e 'YAML.load_file("agent/openapi.yaml"); ...'  # structural OK
# amountMinor → AmountMinor type: integer; all 8 tools in ProposalTool enum
```

### Status
§1.0 complete. Next: §1.1 ADK scaffold + `adk deploy cloud_run` with `gemini-3.5-flash` / Vertex global.

## 2026-08-13 — Stage 1.1 ADK scaffold + Cloud Run deploy

### Context
Owner requested §1.1: create ADK project pinned to `gemini-3.5-flash` and deploy authenticated Cloud Run with Stage 0 SA + Vertex global env.

### Done
- Scaffold [`agent/closing_agent/`](../agent/closing_agent/): `agent.py` (`root_agent`, model `gemini-3.5-flash`), proposal tools aligned with OpenAPI, `requirements.txt` (`google-adk==1.14.0`)
- IAM prep: Cloud Build builder + Artifact Registry/Storage/Run on compute SA; `roles/iam.serviceAccountUser` on `agent-runner` for owner + compute SA
- Deployed:
  ```bash
  uvx --from google-adk==1.14.0 adk deploy cloud_run \
    --project=daftar-closing-agent --region=us-central1 \
    --service_name=daftar-closing-agent --app_name=closing_agent \
    closing_agent -- --no-allow-unauthenticated --min-instances=0 \
    --service-account=agent-runner@daftar-closing-agent.iam.gserviceaccount.com \
    --set-env-vars=GOOGLE_GENAI_USE_VERTEXAI=TRUE,GOOGLE_CLOUD_PROJECT=daftar-closing-agent,GOOGLE_CLOUD_LOCATION=global
  ```
- Service URL: `https://daftar-closing-agent-1487285471.us-central1.run.app`
- Verified `GET /list-apps` with ID token → `["closing_agent"]` HTTP 200
- Granted `roles/run.invoker` to `akrm.codes@gmail.com`
- Updated roadmap §1.1, [`agent/README.md`](../agent/README.md), disclosure

### Architecture / decisions
- Authenticated only (no `--allow-unauthenticated`) per Appendix J.1
- Vertex routing: Cloud Run in `us-central1`; model calls via `GOOGLE_CLOUD_LOCATION=global`
- Tool stubs return Appendix J envelopes now; Stage 1.2/1.4 refine + smoke capture/closing goals

### Ops / verification
```bash
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  https://daftar-closing-agent-1487285471.us-central1.run.app/list-apps
# ["closing_agent"]
```

### Status
§1.1 complete. Next: §1.3 observability polish if needed, then §1.4 live `/run` smoke (close day + Mohamed owes 500).

## 2026-08-13 — Stage 1 cost locks (min=0, max=2)

### Context
Owner required cost locks on the same Cloud Run deploy: `min-instances=0`, `max-instances=2`. Hard ban: Cloud Run default max of 100.

### Done
- Live service `daftar-closing-agent` (`us-central1`) updated:
  ```bash
  gcloud run services update daftar-closing-agent \
    --project=daftar-closing-agent --region=us-central1 \
    --min=0 --max=2 --min-instances=0 --max-instances=2
  ```
- Both layers locked (Google Cloud Run docs: service `--max` vs revision `--max-instances`):
  - Service: `run.googleapis.com/maxScale: '2'`
  - Revision `daftar-closing-agent-00002-4ml`: `autoscaling.knative.dev/maxScale: '2'`
- Docs: [`agent/README.md`](../agent/README.md) redeploy + idempotent lock + verify; roadmap §1.1 + Appendix E

### Architecture / decisions
- **Both layers required.** Service-level `--max=2` is the spend cap (Google-recommended). Revision-level `--max-instances=2` is required so a later `adk deploy` cannot leave a revision at the default 100 (hard ban) even if the service cap still holds.
- Min 0 is Cloud Run’s default (scale-to-zero). YAML omits `minScale` when 0; human describe still shows `Scaling: Auto (Min: 0, Max: 2)`.
- ADK `adk deploy cloud_run … --` passthrough must include `--min=0 --max=2 --min-instances=0 --max-instances=2` on every redeploy.

### Ops / verification
```bash
gcloud run services describe daftar-closing-agent \
  --project=daftar-closing-agent --region=us-central1
# Scaling: Auto (Min: 0, Max: 2)
# Max instances:   2
```

### Status
Cost-lock goal complete. Next: §1.2 tool surface / §1.3 observability / §1.4 `/run` smoke.

## 2026-08-13 — Stage 1.2 Tool proposal surface

### Context
Owner requested §1.2: harden the ADK tool proposal surface to match Appendix J / `agent/openapi.yaml`, with integer-money guards, `daftarContext` awareness, and unit tests — then redeploy with cost locks.

### Done
- Split package:
  - [`agent/closing_agent/proposal.py`](../agent/closing_agent/proposal.py) — envelope, money/UUID/enum guards, `daftarContext` reader
  - [`agent/closing_agent/tools.py`](../agent/closing_agent/tools.py) — eight FunctionTools
  - [`agent/closing_agent/agent.py`](../agent/closing_agent/agent.py) — `gemini-3.5-flash` + routing instruction (YER 0 dp / SAR+USD 2 dp; no `/health`)
- OpenAPI: Mohamed YER example `amountMinor` **500** (was 50000); `AmountMinor` docs aligned with Flutter `CurrencyPrecision`
- Tests: [`agent/tests/test_proposal_tools.py`](../agent/tests/test_proposal_tools.py) + [`agent/requirements-dev.txt`](../agent/requirements-dev.txt) — **18 passed**
- Docs: roadmap §1.2 checked; [`agent/README.md`](../agent/README.md) tool table + money precision
- Redeployed Cloud Run with `--min=0 --max=2 --min-instances=0 --max-instances=2`

### Architecture / decisions
- Success = exact `AgentProposal`; failure = `{status, error_message}` without `proposalId`
- `tool_context` reads `daftarContext` (ADK-injected; omitted from LLM schema)
- LLM-facing args stay primitives / `list[str]` (avoid nested BaseModel required-field ADK bug)
- Tools never convert major→minor; instruction + tests lock YER spoken 500 → `amountMinor=500`
- Multi-ledger `propose_create_contact` errors if `ledger_id` missing

### Ops / verification
```bash
cd agent && python -m pytest tests/ -q   # 18 passed
gcloud run services describe daftar-closing-agent \
  --project=daftar-closing-agent --region=us-central1
# Scaling: Auto (Min: 0, Max: 2)
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  https://daftar-closing-agent-1487285471.us-central1.run.app/list-apps
# ["closing_agent"]
```

### Status
§1.2 complete. Next: §1.3 observability, then §1.4 live `/run` smoke.

## 2026-08-13 — Stage 1.3 Observability

### Context
Owner requested §1.3: structured logs with session id, tool name, latency_ms, model id, verified in Cloud Logging / Cloud Run.

### Done
- [`agent/closing_agent/observability.py`](../agent/closing_agent/observability.py) — stdout JSON structured logs (`daftar.agent.model` / `daftar.agent.tool`)
- Wired ADK callbacks on [`agent/closing_agent/agent.py`](../agent/closing_agent/agent.py) (`before_/after_model`, `before_/after_tool`)
- Tests: [`agent/tests/test_observability.py`](../agent/tests/test_observability.py) — **21** agent tests total
- Docs: roadmap §1.3, README Logs Explorer query, project log
- Redeployed with cost locks; verified Cloud Logging jsonPayload fields after a live `/run`

### Architecture / decisions
- Cloud Run auto-ingests single-line JSON stdout as `jsonPayload` (no extra logging client dependency)
- Callbacks return `None` (observe-only; no behavior change) per ADK callback docs
- Do not log full tool args (PII / money); log `tool_name`, `latency_ms`, `session_id`, `model_id`, optional `correlation_id` / `proposal_id`
- Screenshot path for demo: Console → Cloud Run → `daftar-closing-agent` → Logs → filter `jsonPayload.event`

### Ops / verification
```bash
# Live /run (obs verify) → HTTP 200; Cloud Logging showed:
# daftar.agent.model  session_id=obs-retry-…  latency_ms=2363  model_id=gemini-3.5-flash
# daftar.agent.tool   session_id=obs-retry-…  tool_name=propose_debt  model_id=gemini-3.5-flash

gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="daftar-closing-agent" AND (jsonPayload.event="daftar.agent.tool" OR jsonPayload.event="daftar.agent.model")' \
  --project=daftar-closing-agent --limit=5 --format='value(jsonPayload.event,jsonPayload.session_id,jsonPayload.tool_name,jsonPayload.latency_ms,jsonPayload.model_id)'
```

### Status
§1.3 complete. Next: §1.4 live `/run` smoke (close day + Mohamed owes 500).

## 2026-08-13 — Stage 1.4 ADK smoke + Stage 1 gate

### Context
Owner requested §1.4: live ADK API smoke (`/list-apps`, session, `/run` close-day + Mohamed debt) and `gemini-3.5-flash` proof in logs.

### Done
- Smoke script [`agent/scripts/smoke_1_4.py`](../agent/scripts/smoke_1_4.py) (evidence under `agent/smoke_evidence/`, gitignored)
- Live results (overall **pass**):
  - `GET /list-apps` → `["closing_agent"]` HTTP 200
  - Session create HTTP 200
  - “close my day” → `propose_closing_plan` with **4** steps HTTP 200
  - “Mohamed owes 500” → `propose_debt` `amountMinor=**500**` (YER) HTTP 200
  - Cloud Logging `jsonPayload.model_id=gemini-3.5-flash` on `daftar.agent.model`
- YER 100× mis-scale defense: [`correct_zero_decimal_scale`](../agent/closing_agent/proposal.py) (spoken 500 + model 50000 → 500)
- Roadmap §1.4 + **Stage 1 Validation Gate** checked; README smoke section updated
- Unit tests: **22 passed**

### Architecture / decisions
- Smoke parses ADK event `functionResponse` parts into Appendix J proposals
- Zero-decimal currency correction only when `goalText` spoken int `S` and model passed `S*100` (does not invent amounts)
- Cost locks unchanged (min 0 / max 2)

### Ops / verification
```bash
cd agent && python3 scripts/smoke_1_4.py
# overall_pass=True
```

### Status
**Stage 1 complete (gate closed).** Next: Stage 2 device bridge + confirm gate + Day Journal + FAB.

## 2026-08-13 — Stage 2.1 Contest Drift schema (v19)

### Context
Land contest persistence so Stage 2.2–2.3 can write Day Journal and agent sessions without presentation importing Drift. Money writes stay on existing transaction/contact/ledger use cases.

### Done
- Drift **schemaVersion 18 → 19** (`lib/core/constants/db_constants.dart`) + `onUpgrade` `from < 19` in [`lib/data/datasources/local/drift_database.dart`](../lib/data/datasources/local/drift_database.dart)
- Tables: `day_journal_entries` (append-only), `agent_sessions`, `agent_turns`, `agent_outbox` (thin queue; processors deferred to Stage 5)
- Domain/data slice: Freezed entities, enums, models, mappers, local DS, repository impls (`Either` / `DatabaseFailure`; audit on session + turn writes)
- Application: [`lib/application/agent/`](../lib/application/agent/) — append/list journal, start/complete session, append/update-confirm turn, enqueue/list-pending outbox
- `@riverpod` keepAlive wiring in [`lib/presentation/providers/core_providers.dart`](../lib/presentation/providers/core_providers.dart)
- `DriveBackupConstants.schemaVersion` **14 → 19** (BACKUP_SPEC alignment). Whole-file SQLite snapshot already includes new tables.
- Tests: mapper round-trips, in-memory `schemaVersion == 19` session→turn→journal, mocktail use-case validation + happy path — **21 passed**
- Roadmap §2.1 checked; schema-today note updated to **19**

### Architecture / decisions
- Journal `amount` is `int?` minor units only; no FK to contacts/ledgers (audit survives soft-delete)
- `localDay` is calendar `YYYY-MM-DD` TEXT, not a timestamp
- Soft-delete + `syncVersion` only on mutable session/turn rows
- Providers call use cases only; application has no Drift/Flutter imports
- Outbox `kind` is a string (`pending_run`) so Stage 5 can add kinds without another bump
- Non-goals: Dio/ID-token client (2.2), confirm-gate UI (2.3), money writes

### Ops / verification
```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/data/mappers/agent_mapper_round_trip_test.dart \
  test/data/repositories/agent_schema_v19_test.dart \
  test/application/agent/agent_use_cases_test.dart
# 21 passed
dart analyze lib/application/agent lib/data/datasources/local/drift_database.dart
# No issues found
```

### Status
§2.1 complete. Next: Stage 2.2 agent Dio client + ID-token auth + confirm-gate single-flight. Do not start 2.2 in this slice.

## 2026-08-13 — Stage 2.2 Agent client (device bridge)

### Context
Wire Flutter to the authenticated Cloud Run ADK service: Envied base URL, dedicated Dio + Google ID-token interceptor, application use cases that assemble Appendix J context, process-local confirm-gate single-flight, Riverpod notifier that only calls those use cases. No Closing Agent UI and no money writes (Stage 2.3).

### Done
- Envied `CLOSING_AGENT_BASE_URL` in [`lib/core/env/env.dart`](../lib/core/env/env.dart) (obfuscated; default = live Stage 1 URL); appended the key to gitignored contest `.env`
- Domain constants [`lib/domain/constants/closing_agent_constants.dart`](../lib/domain/constants/closing_agent_constants.dart) (`appName=closing_agent`, connect 15s / send 30s / receive 120s)
- Data: dedicated Dio (not `dioClientProvider`), ID-token interceptor via `GoogleAuthDs.obtainIdToken(allowInteractive: true)`, ADK `list-apps` / session / `/run` in [`lib/data/datasources/remote/closing_agent_remote_ds.dart`](../lib/data/datasources/remote/closing_agent_remote_ds.dart)
- Mapper [`lib/data/mappers/adk_event_proposal_mapper.dart`](../lib/data/mappers/adk_event_proposal_mapper.dart) — `amountMinor` must be Dart `int` (reject `double` / `String`)
- Application: `RunClosingAgentTurnUseCase`, `AgentConfirmGate`, `ConfirmAgentProposalUseCase`, `CancelAgentProposalUseCase` under [`lib/application/agent/`](../lib/application/agent/)
- Persistence follow-up: `AgentSessionRepository.findActive`, `AgentTurnRepository.findByProposalId`
- Riverpod: [`lib/presentation/providers/closing_agent_controller.dart`](../lib/presentation/providers/closing_agent_controller.dart) + keepAlive wiring in [`lib/presentation/providers/core_providers.dart`](../lib/presentation/providers/core_providers.dart) (use cases only)
- Cloud Run: custom audience = Web client ID; `roles/run.invoker` already on `user:akrm.codes@gmail.com`; scale still min 0 / max 2 (revision `daftar-closing-agent-00007-l9w`)
- Auth documented in [`agent/README.md`](../agent/README.md); Appendix J.1 note that GSI `aud` is the Web client ID
- Roadmap §2.2 checked

### Architecture / decisions
- GSI v7 ID tokens have `aud` = `GOOGLE_SERVER_CLIENT_ID`, not `*.run.app` — custom audience unblocks Flutter without `--allow-unauthenticated` or `X-Daftar-Agent-Secret`
- Confirm `committed` means Drift confirm-state only — **no** `AddTransactionUseCase`
- In-flight same `proposalId` → `rejected_in_flight`; already confirmed → `noop_already_committed`
- One active Drift session per mode; ADK `userId` = `googleAccountId` else `DeviceIdentity.currentOrNull` else `anonymous`
- Non-goals: Closing Agent screen / FAB, journal-on-cancel, shared-secret header, speech

### Ops / verification
```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/data/mappers/adk_event_proposal_mapper_test.dart \
  test/application/agent/closing_agent_client_test.dart
# 9 passed (mapper int vs 500.0/"500"; parallel confirm; empty goal; Dio body + Bearer; 401 → AuthFailure)
```

### Status
§2.2 complete. Next: Stage 2.3 Closing Agent UI + confirm money writes. Do not start 2.3 in this slice.

## 2026-08-13 — Stage 2.3 Closing Agent screen

### Context
Build the Closing Agent as a Khazna intent-preview studio (not a chat): Confirm writes money/contact + Day Journal, Cancel writes nothing, FAB tap opens the agent and long-press keeps quick-add, with a first-run tip. Mic/TTS stay stubs. Light §2.4: create-contact Confirm stays disabled until a ledger is chosen when more than one active ledger exists.

### Done
- `CommitAgentProposalUseCase` + `ResolveAgentContactUseCase` — [`lib/application/agent/commit_agent_proposal_use_case.dart`](../lib/application/agent/commit_agent_proposal_use_case.dart), [`lib/application/agent/resolve_agent_contact_use_case.dart`](../lib/application/agent/resolve_agent_contact_use_case.dart). Same `AgentConfirmGate` as §2.2. Debt/payment → `AddTransactionUseCase` + journal `debtConfirmed`/`paymentConfirmed`. Create-contact → `CreateContactUseCase` + `contactCreated`. Closing plan → journal `closingPlanConfirmed` only. Other tools → confirm-state only. 0 or >1 contact matches → `contact_unresolved` (no silent first-match). Second confirm → `noop_already_committed`, no second money write.
- Cancel remains confirm-state `skipped` only — **no journal** (§2.6 / Gate 2 “balances unchanged”).
- Screen + route `/closing-agent` on the root navigator (luxury page enter, no shell FAB on the Confirm surface): [`lib/presentation/screens/closing_agent/`](../lib/presentation/screens/closing_agent/), [`lib/app/router/app_routes.dart`](../lib/app/router/app_routes.dart). Composer, skeletons, plan checklist, Confirm cards (verb labels), ErrorTranslator sheets. Providers call use cases only.
- FAB §2.5: tap → agent, long-press → existing quick-add ([`lib/presentation/shared/widgets/main_shell.dart`](../lib/presentation/shared/widgets/main_shell.dart)). First-run tip sheet persisted as `hasSeenAgentFabTip`.
- Drift **schema 19 → 20** (`DbConstants` + `DriveBackupConstants` + `onUpgrade from < 20`). Settings entity/model/mapper/repo updated.
- ARB (`app_ar.arb` template + `app_en.arb`) + ErrorTranslator codes: `goal_text_required`, `agent_id_token_missing`, `unauthorized`, `closing_agent_request_failed`, `proposal_in_flight`, `contact_unresolved`, `ledger_required`.
- Tests: [`test/application/agent/commit_agent_proposal_use_case_test.dart`](../test/application/agent/commit_agent_proposal_use_case_test.dart). Roadmap §2.3, light §2.4 ledger gate, §2.5, §2.6 unit items checked.

### Architecture / decisions
- Confirm Card is an intent preview (who / amount LTR integer money / currency / verb), not “هل أنت متأكد؟”. One lapis glow: pending Confirm owns primary CTA; composer send drops to secondary. Lapis is light, not paint.
- Application does not import the data-layer proposal mapper — the notifier passes `AgentProposal`.
- `!isMultiCurrencyEnabled` forces `defaultCurrency` in the commit UC. Full currency-on-create UI (§2.4 remainder) is out of this slice.
- Non-goals: §2.3b speech lock, create-ledger / WhatsApp / PDF / Drive execution, name-disambiguation picker, Gate 2 device demo.

### Ops / verification
```bash
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter test test/application/agent/commit_agent_proposal_use_case_test.dart \
  test/application/agent/closing_agent_client_test.dart \
  test/data/mappers/adk_event_proposal_mapper_test.dart \
  test/data/repositories/agent_schema_v19_test.dart \
  test/application/agent/agent_use_cases_test.dart
# 32 passed
```

### Status
§2.3 + §2.5 + light §2.4 ledger gate + §2.6 unit tests complete. Next: do **not** start 2.3b. Remaining: §2.4 currency-on-create UI, Gate 2 device demo, speech.

## 2026-08-13 — Closing Agent UI + Cloud Run auth copy

### Context
Device log showed RenderFlex overflow when the IME opened, a 96×48 oval `DaftarButton.icon` crowding a tiny field, and submit mapping Cloud Run 403 to workspace-owner “صلاحيتك في مساحة العمل…”.

### Done
- Studio layout: drop dual-`Expanded` 40/60 split. Header + scrollable body + **intrinsic** composer dock. `SafeArea` once; composer does not add `padding.bottom`. Unfocus on submit. Idle studio prompt + tappable example chips. [`lib/presentation/screens/closing_agent/closing_agent_screen.dart`](lib/presentation/screens/closing_agent/closing_agent_screen.dart)
- Composer: 48×48 square mic/send (`DaftarTapTarget`, `radiusSm`, lapis hairline + `AppGlows.ctaRest` on send). Multiline field (2–4 lines). [`lib/presentation/screens/closing_agent/widgets/closing_agent_composer.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_composer.dart)
- [`DaftarTextField`](lib/presentation/shared/widgets/daftar_text_field.dart): optional `minLines`/`maxLines`; hint stays while empty when `label` is null.
- Cloud Run 401 → `AuthFailure(closing_agent_unauthorized)`; 403 → `AuthFailure(closing_agent_forbidden)`. Never `ForbiddenFailure` / `errorForbiddenMessage`. [`lib/data/repositories/closing_agent_runtime_repository_impl.dart`](lib/data/repositories/closing_agent_runtime_repository_impl.dart), [`lib/core/utils/error_translator.dart`](lib/core/utils/error_translator.dart), ARB `errorClosingAgentForbidden`.

### Architecture / decisions
- Workspace sync 403 still uses `errorForbiddenMessage` via `mapEdgeFunctionFailure` (unchanged). Agent transport does not go through that remap.
- Lapis remains light, not paint. Mic stub only. No `DaftarButton.icon` on the composer (that constructor is a 96×48 stadium).
- Remaining Cloud Run 403 after this copy fix is IAM/audience on the Google account — not a Flutter mapping bug.

### Ops / verification
```bash
flutter gen-l10n
flutter test test/application/agent/closing_agent_client_test.dart \
  test/core/utils/error_translator_agent_auth_test.dart \
  test/application/agent/commit_agent_proposal_use_case_test.dart
# 17 passed
```

### Status
UI overflow + oval controls + mis-mapped 403 copy fixed. Next: do **not** start 2.3b. Remaining: §2.4 currency-on-create UI, Gate 2, speech. IAM/gcloud only if 403 persists with the new agent copy.

## 2026-08-14 — Single Google session for Drive + Closing Agent

### Context
Drive backup stayed linked while Closing Agent opened a second Google picker (Credential Manager) and Cloud Run IAM allowed only `user:akrm.codes@gmail.com`. Other linked Gmail accounts (e.g. `daftar.core@gmail.com`) got 403. Drive uses a PKCE access token; the agent needs the GSI **ID token** of the same `googleUserId`.

### Done
- Cloud Run IAM: `allAuthenticatedUsers` + `roles/run.invoker` on `daftar-closing-agent` (`us-central1`). Existing `user:akrm.codes@gmail.com` binding kept. Custom audience unchanged (Web client ID). [`agent/README.md`](agent/README.md)
- Persist GSI ID token on [`AuthSessionBundle`](../lib/domain/value_objects/auth_session_bundle.dart) (`cachedIdToken` / `cachedIdTokenExpiresAt`). [`AuthSessionStore`](../lib/core/services/auth_session_store.dart) schema **v5** (v1–v4 still read). Written on Drive `signIn` / `persistSessionBundle`.
- [`GoogleAuthDs.obtainIdToken(allowInteractive: false)`](../lib/data/datasources/remote/google_auth_ds.dart): warm account token → unexpired bundle token → stop. Never `authenticate()` / One Tap.
- Interceptor always `allowInteractive: false`. [`closing_agent_remote_ds.dart`](../lib/data/datasources/remote/closing_agent_remote_ds.dart)
- User-gesture hydrate on agent Send: [`HydrateAgentIdTokenUseCase`](../lib/application/agent/hydrate_agent_id_token_use_case.dart) → `ensureLinkedIdToken(allowLightweightRestore: true)`. Accept only `account.id == bundle.googleUserId`. Mismatch fail-closed (`agent_google_account_mismatch`). Missing → `agent_id_token_missing` (existing ARB). Settings Google Sign-In remains the one login ceremony. [`closing_agent_controller.dart`](../lib/presentation/providers/closing_agent_controller.dart)

### Architecture / decisions
- Agent Bearer = GSI ID token of the linked Drive identity. No second picker that can switch accounts. No `openid` on Drive PKCE. No SA key in the app. Lightweight restore only on user-initiated Send, never launch/Workmanager/interceptor.
- JWT `exp` is decoded locally for cache TTL only; Cloud Run still verifies the signature. Invoker `allAuthenticatedUsers` still requires a Google ID token (not public / not `allUsers`).
- DRS fallback (`--no-invoker-iam-check` + in-container verify) was **not** needed.

### Ops / verification
```bash
gcloud run services add-iam-policy-binding daftar-closing-agent \
  --project=daftar-closing-agent --region=us-central1 \
  --member='allAuthenticatedUsers' --role='roles/run.invoker'
# bindings: allAuthenticatedUsers + user:akrm.codes@gmail.com → roles/run.invoker

dart run build_runner build --delete-conflicting-outputs
flutter test \
  test/data/datasources/remote/google_auth_ds_obtain_id_token_test.dart \
  test/data/datasources/remote/google_id_token_expiry_test.dart \
  test/core/services/auth_session_store_test.dart \
  test/domain/value_objects/auth_session_bundle_test.dart \
  test/application/agent/closing_agent_client_test.dart \
  test/application/agent/hydrate_agent_id_token_use_case_test.dart \
  test/data/repositories/auth_repository_impl_test.dart \
  test/core/utils/error_translator_agent_auth_test.dart
# 87 passed
```

### Status
Single Google session for Drive + agent is in place. Next: do **not** start 2.3b. Remaining: §2.4 currency-on-create UI, Gate 2, speech.

## 2026-08-14 — Analyzer follow-up (recovery auth + constructor order)

### Context
`flutter analyze` after the single-session slice: `RecoveryAuthRepository` did not implement `AuthRepository.ensureLinkedIdToken`.

### Done
- Implemented `ensureLinkedIdToken` on [`recovery_auth_repository.dart`](../lib/core/recovery/recovery_auth_repository.dart) (same hydrate/mismatch mapping as `AuthRepositoryImpl`).
- Unnamed Freezed factories before private `._()` in `agent_proposal.dart`, `device_agent_request.dart`, `closing_agent_state.dart`.
- Dropped redundant `allowInteractive: false` in obtain-id-token tests.

### Ops / verification
```bash
flutter analyze
# No issues found
```

### Status
Analyzer clean. No product-behavior change beyond the recovery-stack implementing the new port.

## 2026-08-14 — §2.3b speech lock + §2.4 create-contact currency

### Context
Lock Stage 5 speech as Option B (docs only) and finish §2.4 currency-on-create-contact. The unused `ConfirmAgentProposalUseCase` marked confirm-state without writing money — a footgun next to the live `CommitAgentProposalUseCase` path.

### Done
- **§2.3b LOCKED Option B** in [`docs/roadmap_v2.md`](roadmap_v2.md): Gemini 3.5 Flash turn-based multimodal audio on existing `/run`, same Appendix J schema, Model C confirm. No Flutter/ADK speech, mic, STT, TTS, or `audioRef` code. Rejected Option A (Cloud STT) is slip fallback only. §5.1 points at this lock. Gate 2 device-demo boxes left unchecked.
- Deleted [`lib/application/agent/confirm_agent_proposal_use_case.dart`](../lib/application/agent/confirm_agent_proposal_use_case.dart) and `confirmAgentProposalUseCase` provider. Single-flight `rejectedInFlight` coverage moved onto [`CommitAgentProposalUseCase`](../lib/application/agent/commit_agent_proposal_use_case.dart).
- Create-contact commit: `currencyCodeOverride` next to `ledgerIdOverride`. `!isMultiCurrencyEnabled` → `_currency` forces `defaultCurrency` (override ignored). Enabled → require override or `ValidationFailure(code: 'currency_required')`. Persists as `CreateContactUseCase.execute(creditCurrency:)`. No OpenAPI / `propose_create_contact` change.
- Confirm card: `currencyCodeByProposal` + inline ISO chips (lapis hairline, not `CurrencySelector`) only when create-contact **and** multi-currency on. Confirm disabled until a tap. Hidden when multi-currency off. Debt/payment cards unchanged.
- ARB EN+AR: `closingAgentSelectCurrency`, `closingAgentCurrencyRequiredHelper`, `errorCurrencyRequired`. [`error_translator.dart`](../lib/core/utils/error_translator.dart) maps `currency_required`. §2.4 **Currency** checkbox checked.

### Architecture / decisions
- Application reuses commit `_currency` (same policy as debt/payment force-default). Presentation cannot import a third helper for this write.
- Device override only — agent payload stays `name` / `phone` / `ledgerId`.
- No dialog. No currency picker on debt/payment confirm. No Cloud Run redeploy. No Stage 5 speech implementation.

### Ops / verification
```bash
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter analyze
# No issues found
flutter test \
  test/application/agent/commit_agent_proposal_use_case_test.dart \
  test/application/agent/closing_agent_client_test.dart \
  test/core/utils/error_translator_agent_auth_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_confirm_card_test.dart
# 25 passed
```

### Status
§2.3b locked (docs). §2.4 Currency implementation complete. Gate 2 “Multi-currency off → no currency prompt” remains a device-demo checkbox. Next: Gate 2 device demos; Stage 5 implements Option B.

## 2026-08-14 — Second-turn Closing Agent 400 (session already exists)

### Context
After a successful first Send + Confirm, the next Send failed immediately with `errorNetworkTitle` + `errorClosingAgentRequestFailed`. Live Cloud Run logs showed `POST /apps/.../sessions/{id}` returning **400** in ~4ms because ADK InMemorySessionService is create-only.

### Done
- [`closing_agent_remote_ds.dart`](../lib/data/datasources/remote/closing_agent_remote_ds.dart): session POST **400/409** = already exists (success). `/run` **404** → create once, retry `/run` once. Context still travels on `/run` `stateDelta.daftarContext`.
- [`agent/README.md`](../agent/README.md): documented create-only session POST.
- Tests in [`closing_agent_client_test.dart`](../test/application/agent/closing_agent_client_test.dart): 400/409 create succeeds; 401 still `closing_agent_unauthorized`; 404 `/run` retries.

### Architecture / decisions
- Status on this ADK endpoint is the contract — do not match English `detail` for merchant copy.
- No Cloud Run redeploy. No `min-instances` bump (cost lock). First-Send ~30s remains cold start + Vertex.
- Interceptor stays `allowInteractive: false`. Google One Tap after idle is GSI hydrate, not this 400.

### Ops / verification
```bash
flutter test test/application/agent/closing_agent_client_test.dart
# 10 passed
flutter analyze
# No issues found
```

### Status
Second-turn Send should reach `/run` while the Cloud Run instance still holds the session. Gate 2 device-demo boxes still unchecked.

## 2026-08-14 — Warm-path Closing Agent latency

### Context
Subsequent Sends took 10–20s on a **warm** Cloud Run instance (same `instanceId`). Cost: wasted session POST every turn, Gemini 3.5 Flash default **medium** thinking, and two model hops (`parse_goal` then `propose_*`). Honest target: one `/run`, one `propose_*`, MINIMAL thinking — a few seconds, not 10–20s. First Send with min-instances 0 stays a cold start.

### Done
- [`lib/data/datasources/remote/closing_agent_remote_ds.dart`](../lib/data/datasources/remote/closing_agent_remote_ds.dart): process-local skip of session POST when `userId+sessionId` is already ensured. **409** = already exists. **400** = already exists only if JSON `detail` contains the posted `sessionId`. `/run` **404** clears the warm key, then create + retry `/run`. Use case still calls create every turn; DS no-ops when warm.
- [`agent/closing_agent/agent.py`](../agent/closing_agent/agent.py): instruction forbids `parse_goal` on clear debt/payment/close/create/statement (one `propose_*` hop). `parse_goal` kept in `ALL_TOOLS`. `BuiltInPlanner` + `ThinkingConfig(thinking_level=MINIMAL, include_thoughts=False)` (verified on google-adk 1.14 / google.genai). No `generate_content_config.thinking_config` (ADK ValueError). Temperature / top_p unchanged.
- [`agent/README.md`](../agent/README.md): skip + 400 rule + one-hop routing.
- Tests: [`test/application/agent/closing_agent_client_test.dart`](../test/application/agent/closing_agent_client_test.dart), [`agent/tests/test_agent_instruction.py`](../agent/tests/test_agent_instruction.py).

### Architecture / decisions
- Do not skip session create in the application layer.
- Do not match English “already exists” for merchant copy — the UUID in `detail` is the 400 contract.
- Cost lock unchanged: min=0, max=2, both service and revision layers. No min-instances bump. No Stage 3 screens. `parse_goal` not deleted.
- Zero-millisecond Vertex responses are not possible.

### Ops / verification
```bash
flutter test test/application/agent/closing_agent_client_test.dart
# 12 passed
flutter analyze
# No issues found
cd agent && /tmp/daftar-agent-venv/bin/python -m pytest tests/ -q
# 24 passed
uvx --from google-adk==1.14.0 adk deploy cloud_run … --min=0 --max=2 --min-instances=0 --max-instances=2 …
# revision daftar-closing-agent-00008-dr7 then cost-lock update → daftar-closing-agent-00011-wg9
# URL https://daftar-closing-agent-1487285471.us-central1.run.app
# Service run.googleapis.com/maxScale: 2; revision autoscaling.knative.dev/maxScale: 2; min omitted (=0)
# IAM: allAuthenticatedUsers + user:akrm.codes@gmail.com remain roles/run.invoker
```

### Status
Warm-path client + agent shipped and redeployed. Gate 2 device-demo boxes still unchecked. Expect subsequent Sends in a few seconds while the instance is warm; first Send with scale-to-zero remains slow.

## 2026-08-14 — Stage 3.1 Capture

### Context
Roadmap §3.1 / Chapter 2: finish the daytime capture loop on device — prove payment confirm, name disambiguation chips, phone-contact picker on create-contact, create-ledger writes, and ask-the-books from Drift. No 3.2 aging, 3.3 PDF, 3.4 airplane, or Stage 3 Validation Gate.

### Done
- Payment: unit test in [`test/application/agent/commit_agent_proposal_use_case_test.dart`](../test/application/agent/commit_agent_proposal_use_case_test.dart) — `TransactionType.payment` + `DayJournalKind.paymentConfirmed` (live path already in [`commit_agent_proposal_use_case.dart`](../lib/application/agent/commit_agent_proposal_use_case.dart)).
- Disambiguation: [`list_agent_contact_candidates_use_case.dart`](../lib/application/agent/list_agent_contact_candidates_use_case.dart) wraps `SearchContactsUseCase` (`excludeUserArchivedLedgers: true`). Confirm card chips (monochrome + lapis hairline). Confirm disabled on 0 hits; many hits require a tap. `contactIdOverride` on commit (override → payload id → unique search; no silent first-match).
- Create-contact picker: [`NativeContactPickerService`](../lib/core/utils/native_contact_picker_service.dart) on the Confirm card via `importFromContacts`; name/phone **overrides** only. Hidden when `!isSupported`.
- Create-ledger: commit calls `CreateLedgerUseCase` (type → `LedgerType`, icons `people_alt_rounded` / `local_shipping_rounded` / `person_rounded` / `folder_special_rounded`, color `0xFF64748B`), journals `ledgerCreated`. Confirm card verb `closingAgentConfirmCreateLedger`. WhatsApp/statement stay read-only.
- Ask-the-books: [`answer_ask_books_use_case.dart`](../lib/application/agent/answer_ask_books_use_case.dart) + [`AgentAskCard`](../lib/presentation/screens/closing_agent/widgets/agent_ask_card.dart). Overdue = `netBalance < 0` only. Named balance via FTS; >1 → chips; 0 → helper. Empty overdue is success. Drift runs before/alongside `/run`; `turnResult.narrative` is flavor only — never model amounts on the card.
- Agent instruction ([`agent/closing_agent/agent.py`](../agent/closing_agent/agent.py)): ask must not invent amounts; device reads Drift.
- ARB + `flutter gen-l10n`: `closingAgentWhichContact`, create-ledger verb/types, ask title/empty/balance/unresolved.

### Architecture / decisions
- Providers → use cases only. Integer money. Confirm remains the only money/ledger/contact write (Model C).
- Unknown-name → auto-create on a money card is a non-goal (merchant uses create-contact).
- Disambiguation “voice” is the same chips (Stage 5 STT later).
- Cost lock unchanged: min=0, max=2, both layers. No min-instances bump.

### Ops / verification
```bash
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter analyze
# No issues found
flutter test \
  test/application/agent/commit_agent_proposal_use_case_test.dart \
  test/application/agent/list_agent_contact_candidates_use_case_test.dart \
  test/application/agent/answer_ask_books_use_case_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_confirm_card_test.dart
# 35 passed
cd agent && /tmp/daftar-agent-venv/bin/python -m pytest tests/ -q
# 24 passed
uvx --from google-adk==1.14.0 adk deploy cloud_run … --min=0 --max=2 --min-instances=0 --max-instances=2 …
# revision daftar-closing-agent-00012-mqk then cost-lock update → daftar-closing-agent-00013-854
# URL https://daftar-closing-agent-1487285471.us-central1.run.app
# Service run.googleapis.com/maxScale: 2; revision autoscaling.knative.dev/maxScale: 2; min omitted (=0)
# IAM: allAuthenticatedUsers + user:akrm.codes@gmail.com remain roles/run.invoker
```

### Status
Five §3.1 boxes checked in [`docs/roadmap_v2.md`](roadmap_v2.md). §3.2–3.4 and Stage 3 Validation Gate remain unchecked. Gate 2 device-demo boxes still unchecked.

## 2026-08-14 — Stage 3.2 Aging analysis (device)

### Context
Roadmap §3.2: extend reminder eligibility past “has phone,” expose a Collections VO with FIFO oldest-unpaid age and tone bands, and lock Mohamed 100 then +50 fixtures. Aging is Drift-only so it works when Cloud Run is unreachable. No Collections Desk UI, PDF, airplane-mode, or agent redeploy.

### Done
- Phone gate kept: [`GetReminderEligibleContactsUseCase`](../lib/application/contact/get_reminder_eligible_contacts_use_case.dart) + SQL in [`contact_local_ds.dart`](../lib/data/datasources/local/contact_local_ds.dart).
- Outstanding filter: Drift **`netBalance < 0`** (roadmap “balance > 0” = `owedMinor`). Never `netBalance > 0`.
- FIFO: [`compute_fifo_contact_aging.dart`](../lib/application/contact/compute_fifo_contact_aging.dart) — payments consume oldest debt; order is `transactionDate`, then `createdAt`, then `id`; **per currency**.
- Tone (Appendix C/D, oldest unpaid `ageDays`): friendly under 7d, reminder under 30d, firm 30d+. Enum [`reminder_tone_band.dart`](../lib/domain/enums/reminder_tone_band.dart).
- VO [`collections_candidate.dart`](../lib/domain/value_objects/collections_candidate.dart): contactId, name, phone, ledgerId, signed `netBalance`, `owedMinor`, currencyCode, ageDays, toneBand, daysSinceLastPayment, daysSinceLastDebt.
- UC [`get_collections_candidates_use_case.dart`](../lib/application/contact/get_collections_candidates_use_case.dart) + providers `getReminderEligibleContactsUseCaseProvider`, `getCollectionsCandidatesUseCaseProvider`. Sort: ageDays desc, owedMinor desc, name. Empty shortlist is success.

Mohamed fixtures (`asOf` = 2026-08-14 local, YER integer minor units):

| Fixture | Timeline | owedMinor | ageDays | toneBand |
|---|---|---|---|---|
| 100 then +50 | D-40 debt 100; D-10 debt 50 | 150 | 40 | firm |
| FIFO consume | same + D-5 payment 100 | 50 | 10 | reminder |
| Friendly | D-3 debt 100 | 100 | 3 | friendly |
| Reminder bound | D-7 debt 100 | 100 | 7 | reminder |
| Firm bound | D-30 debt 100 | 100 | 30 | firm |

### Architecture / decisions
- Providers → use cases only. Integer money. No Cloud Run / `daftarContext` aging fields. No desk UI / ARB this slice.
- FIFO uses merchant **event** date (`transactionDate`), not insert time (Appendix D said `createdAt`; Daftar’s financial date is `transactionDate`).
- Do not gate on Pro+ `FeatureFlag.advancedAnalytics`. Stage 4 still owns Top 5, drafts, and narration.

### Ops / verification
```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
# No issues found
flutter test \
  test/application/contact/compute_fifo_contact_aging_test.dart \
  test/application/contact/get_collections_candidates_use_case_test.dart \
  test/application/contact/contact_read_use_cases_test.dart
# 21 passed
```

### Status
Four §3.2 boxes checked. Gate 3 **Aging fixtures produce expected tone bands** checked. Golden-set / picker / PDF gate items, §3.3, §3.4, and Stage 4 Collections Desk remain unchecked.

## 2026-08-14 — Stage 3.3 On-demand PDF

### Context
Roadmap §3.3: goal “statement for X” should resolve the contact, reuse the existing contact-statement PDF pipeline, and open the system share sheet. Ambiguous FTS hits require identity chips. No airplane mode, Collections attach-PDF policy, Cloud Run, or `agent.py` changes.

### Done
- Typed payload [`ProposeStatementPayload`](../lib/domain/value_objects/agent_proposal.dart) + mapper [`adk_event_proposal_mapper.dart`](../lib/data/mappers/adk_event_proposal_mapper.dart) (`propose_statement` is no longer `generic`).
- [`CommitAgentProposalUseCase`](../lib/application/agent/commit_agent_proposal_use_case.dart) statement path is confirm-state only — no `AddTransactionUseCase`, no Day Journal.
- Prepare UC [`prepare_contact_statement_use_case.dart`](../lib/application/contact/prepare_contact_statement_use_case.dart) + VO [`contact_statement_export.dart`](../lib/domain/value_objects/contact_statement_export.dart). Amounts always from Drift (prefer `creditCurrency`; empty txn list is a valid zero statement). Application layer does not import `PdfGenerator`.
- Hint strip [`extract_statement_contact_hint.dart`](../lib/application/agent/extract_statement_contact_hint.dart): `statement for Mohamed` / `كشف حساب محمد` → `Mohamed` / `محمد`.
- Closing Agent Confirm card for `proposeStatement` (verb **`shareStatement`**). FTS >1 → chips (preselect payload `contactId` if present in the list); 0 hits + no id → Confirm off + `closingAgentContactUnresolvedHelper`.
- Share pipeline [`share_agent_statement.dart`](../lib/presentation/screens/closing_agent/share_agent_statement.dart): overlay + prepare UC + `ResolvePdfMerchantProfileUseCase` + `PdfGenerator` isolate + `PdfStorageService` + `StatementShare`, then `confirm()`. Failures reuse `pdf*` ARB via `ErrorTranslator`. WhatsApp drafts stay `_ReadOnlyRow`.

### Architecture / decisions
- Providers → use cases only. Integer money. Confirm is identity + share intent; generate/save/share must succeed before confirm-state flips.
- Device FTS is identity truth when >1 hits, even if the agent sent `contactId`.
- No new ARB keys. No OpenAPI / Cloud Run / Collections Desk attach-PDF (Stage 4).

### Ops / verification
```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
# No issues found (targeted Stage 3.3 files)
flutter test \
  test/data/mappers/adk_event_proposal_mapper_test.dart \
  test/application/agent/commit_agent_proposal_use_case_test.dart \
  test/application/agent/extract_statement_contact_hint_test.dart \
  test/application/contact/prepare_contact_statement_use_case_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_confirm_card_test.dart
# 39 passed
```

### Status
Two §3.3 boxes checked. Gate 3 **PDF share for one contact works** checked. Golden-set / picker / airplane (§3.4) remain unchecked.

## 2026-08-14 — Stage 3.4 Resilience

### Context
Roadmap §3.4: airplane mode must fail the agent call gracefully while quick-add still works, and Closing Agent user errors must go through `ErrorTranslator` / ARB. No Gate 3 golden-set/picker, no Cloud Run, no outbox.

### Done
- [`ClosingAgentRuntimeRepositoryImpl`](../lib/data/repositories/closing_agent_runtime_repository_impl.dart): Dio `connectionError` / timeouts / Cloud Run 503 (`service_unavailable`) remap to `closing_agent_request_failed` so merchants never see sync-server `errorServiceUnavailableMessage`.
- [`ClosingAgentController.submitGoal`](../lib/presentation/providers/closing_agent_controller.dart): after Drift ask-the-books, `ConnectivityStatus.offline` (radio none) skips hydrate + `/run` and leaves `running`. Ask card is kept. Avoids 15s connect timeout and a false “sign in with Google” on airplane.
- ARB: `errorClosingAgentRequestFailed` now says books are safe and **hold +** still works (EN + AR). New `errorProposalAlreadyCommitted`, `errorClosingAgentParseFailed`.
- [`ErrorTranslator`](../lib/core/utils/error_translator.dart) maps `contact_id_required`, `proposal_not_found` / `proposal_id_required`, `proposal_already_committed`, and ADK parse codes. English `Failure.message` is never shown on this path.
- Quick-add unchanged: FAB long-press remains local Drift (`AddTransactionUseCase`).

### Architecture / decisions
- `connectivity_plus` is a radio hint only (official warning). Dio remains the source of truth for Wi-Fi without internet. No ping / `internet_connection_checker`.
- Application layer still imports domain only; preflight is presentation via existing `connectivityServiceProvider`.
- Global `service_unavailable` copy stays sync-server. Scope is Closing Agent path, not a full-app translator audit. No Stage 5 outbox.

### Ops / verification
```bash
flutter gen-l10n
flutter analyze
# No issues found (targeted Stage 3.4 files)
flutter test \
  test/application/agent/closing_agent_client_test.dart \
  test/core/utils/error_translator_agent_auth_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart
# 29 passed
```

### Status
Two §3.4 boxes checked. Gate 3 golden-set / contact-picker remain unchecked. Stage 3 task checklist is complete aside from those gate items.

## 2026-08-15 — Capture path: unknown name, empty ledger, word amounts

### Context
Daytime capture dead-ends: unknown-name money Confirm was disabled, empty-ledger create-contact could not proceed, and spoken “one thousand” / “ألف” displayed as 10,000 on YER. Capture-first; Arabic ask-the-books phrasing deferred.

### Done
- Unknown-name money: 0 FTS hits on debt/payment → helper `closingAgentUnknownContactHelper`, verb Create & record, phone picker. [`agent_confirm_card.dart`](../lib/presentation/screens/closing_agent/widgets/agent_confirm_card.dart), [`closing_agent_screen.dart`](../lib/presentation/screens/closing_agent/closing_agent_screen.dart). Commit with `createIfMissing`: `CreateContactUseCase` then `AddTransactionUseCase`; journal `contactCreated` then debt/payment. Skip still writes nothing. >1 chips still require a tap — no silent create.
- Empty ledger: `DaftarTextField` + `closingAgentNoLedgerHelper` / `closingAgentLedgerNameHint` on create-contact and unknown-name money. [`CommitAgentProposalUseCase`](../lib/application/agent/commit_agent_proposal_use_case.dart) `_resolveLedgerId` creates a customers ledger via `CreateLedgerUseCase` when `ledgerNameOverride` is set, then contact (then txn).
- Spoken amounts: device [`correct_spoken_amount_minor.dart`](../lib/application/agent/correct_spoken_amount_minor.dart) + controller `amountMinorByProposal`. Agent [`proposal.py`](../agent/closing_agent/proposal.py) `correct_zero_decimal_scale` now parses EN/AR words and snaps `expected` / `×10` / `×100`. Digit `"10000"` left alone.

### Architecture / decisions
- One Confirm is consent. Providers still call use cases only. Integer money. No OpenAPI change. No محمد ↔ Mohammed table. Device owns the path so Gemini flakiness cannot freeze Confirm.
- Gate 3 golden-set / picker **not** checked (ask-the-books still deferred).

### Ops / verification
```bash
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter analyze  # no issues (targeted capture-path files)
flutter test \
  test/application/agent/correct_spoken_amount_minor_test.dart \
  test/application/agent/commit_agent_proposal_use_case_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_confirm_card_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart
# 44 passed (42 capture-path + 2 controller)
PYTHONPATH=agent python -m pytest agent/tests/test_proposal_tools.py -q
# 23 passed
# Cloud Run: adk deploy + scale lock → revision daftar-closing-agent-00016-znx
# autoscaling.knative.dev/maxScale: '2'  min 0
```

### Status
Capture-path gaps closed. Gate 3 golden-set / contact-picker still unchecked. Ask-the-books Arabic / last-payment / largest-outstanding remain a follow-up.

## 2026-08-15 — Ask-the-books: phrasing, names, last payment, largest debt

### Context
Device classifier was a short substring list. Misses went to Cloud Run; Gemini understood the question and narrated “open the customer list.” Leftover tokens (`Mohammed remaining`) made FTS AND-miss stored `Mohamed`. No last-payment or largest-debt intents. Empty leftover named asks dumped the overdue list. Online ask still called `/run` after Drift already answered.

### Done
- Intent + leftover strip: [`ask_books_intent.dart`](../lib/application/agent/ask_books_intent.dart) — `classifyAsk` / `extractAskNameHint`. Priority lastPayment / lastDebt → largest → overdue → namedBalance. Digits stay capture. [`ask_books_intent_test.dart`](../test/application/agent/ask_books_intent_test.dart).
- Name resolve (ask path only): FTS → first token → closed aliases [`ask_name_aliases.dart`](../lib/application/agent/ask_name_aliases.dart). Pronouns via `lastAskContactId`. Empty leftover → `AskBooksNeedName`, never overdue dump. [`answer_ask_books_use_case.dart`](../lib/application/agent/answer_ask_books_use_case.dart).
- Last payment / last debt / largest: Drift `TransactionRepository.getByContact` newest-first, integer minor units. VOs on [`ask_books_answer.dart`](../lib/domain/value_objects/ask_books_answer.dart). Outstanding lists sort by `owedMinor` desc. [`agent_ask_card.dart`](../lib/presentation/screens/closing_agent/widgets/agent_ask_card.dart) exhaustive switch. ARB `closingAgentAskLargestTitle` / `LastPayment` / `LastDebt` / `NoLast*` / `NeedName`.
- Skip `/run` when local `execute` returns a Right answer (online and airplane). [`closing_agent_controller.dart`](../lib/presentation/providers/closing_agent_controller.dart). [`agent.py`](../agent/closing_agent/agent.py): ask → `parse_goal(ask)` only; never invent amounts; never tell the merchant to open lists, sort balances, or leave the agent.

### Architecture / decisions
- Amounts only from Drift. Integer minor. `netBalance < 0` = they owe us.
- Device owns books Q&A. Classifier miss still hits Cloud Run; `_askFromParseGoal(forceAsk: true)` remains the safety net (extract name from notes, never raw FTS).
- No OpenAPI / new propose tool. No محمد↔Mohammed table in global FTS. Capture with digits unchanged. Gate 3 golden-set **not** checked. Capture-path / Stage 3.4 plan files not edited.

### Ops / verification
```bash
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter analyze  # no issues (ask-the-books files)
flutter test \
  test/application/agent/ask_books_intent_test.dart \
  test/application/agent/answer_ask_books_use_case_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_ask_card_test.dart
# 28 passed
cd agent && uv run --with pytest --with pyyaml --with jsonschema \
  python -m pytest tests/test_agent_instruction.py tests/test_proposal_tools.py -q
# 25 passed
# Cloud Run: adk deploy → daftar-closing-agent-00017-dz5
# scale lock update → daftar-closing-agent-00018-dt2 serving
# run.googleapis.com/maxScale: '2'  autoscaling.knative.dev/maxScale: '2'  min 0
```

### Status
Ask-core closed. Gate 3 golden-set / contact-picker still unchecked. Statements, Collections Desk, WhatsApp drafts, and global FTS tokenizer remain out of this turn.

## 2026-08-15 — Arabic ask + statement query accuracy

### Context
Three spoken/typed Arabic failures: `كم متبقي دين على محمد` never classified as ask (`متبقي` missing vs `رصيد`/`كم باقي`); `من صاحب أقل دين؟` had no smallest-ranking intent; `كشف حساب لاحمد عبدالله` died because `propose_statement` required an exact voiceHints match and Gemini narrated “add them first,” while FTS AND on `عبد الله` missed stored `عبدالله`.

### Done
- Named phrasing: `متبقي` / `متبقى` / `كم حساب` / `ما تبقى` in [`ask_books_intent.dart`](../lib/application/agent/ask_books_intent.dart). Bare `حساب`/`كشف` stay non-ask so `كشف حساب لمحمد` is still a statement. Leftover `كم متبقي دين على محمد` → `محمد`.
- Smallest outstanding: `AskBooksIntent.smallestOutstanding`, VO `AskBooksSmallestOutstanding`, sort `owedMinor` ascending, ARB `closingAgentAskSmallestTitle`, [`agent_ask_card.dart`](../lib/presentation/screens/closing_agent/widgets/agent_ask_card.dart).
- Shared resolver [`resolve_contact_hint_use_case.dart`](../lib/application/agent/resolve_contact_hint_use_case.dart) + [`arabic_name_particles.dart`](../lib/application/agent/arabic_name_particles.dart): FTS → collapse `عبد ` → expand glued `عبد…` → first token → aliases. Wired into ask and [`list_agent_contact_candidates_use_case.dart`](../lib/application/agent/list_agent_contact_candidates_use_case.dart). Statement extract strips attached `ل` on the first leftover token.
- Cloud: OpenAPI `ProposeStatementPayload` optional `contactId` + `contactHint`. [`propose_statement`](../agent/closing_agent/tools.py) always emits a proposal; unique space-stripped/alef-folded voiceHint still fills UUID. [`agent.py`](../agent/closing_agent/agent.py) never narrates missing-contact / add-them-first. Controller retries goal extract when payload hint FTS-misses.

### Architecture / decisions
- Amounts still Drift-only, integer minor. No FTS5 tokenizer change. Device owns name resolution; Cloud Run must not error on an unresolved statement hint. Gate 3 golden-set **not** checked. Ask-the-books plan file not edited.

### Ops / verification
```bash
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter analyze  # no issues (ask + statement files)
flutter test \
  test/application/agent/ask_books_intent_test.dart \
  test/application/agent/answer_ask_books_use_case_test.dart \
  test/application/agent/resolve_contact_hint_use_case_test.dart \
  test/application/agent/list_agent_contact_candidates_use_case_test.dart \
  test/application/agent/extract_statement_contact_hint_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_ask_card_test.dart
# 39 passed
cd agent && uv run --with pytest --with pyyaml --with jsonschema \
  python -m pytest tests/test_agent_instruction.py tests/test_proposal_tools.py -q
# 27 passed
# Cloud Run: adk deploy → daftar-closing-agent-00019-h6m
# scale lock update → daftar-closing-agent-00020-d7l serving
# run.googleapis.com/maxScale: '2'  autoscaling.knative.dev/maxScale: '2'  min 0
```

### Status
The three reported Arabic query bugs are closed. Gate 3 golden-set / contact-picker still unchecked. Global FTS tokenizer, extra dialects, WhatsApp, and Collections remain out of this turn.

## 2026-08-15 — Spoken amount accuracy (capture)

### Context
YER “two thousand” snapped correctly, but “two hundred” / “2 hundred” / Arabic duals (`مائتين` / `مئتين` / `ميتين`) recorded **20,000**. Gemini still emits 2-decimal minor units (`200` → `20000`). The device/Cloud snap only fires when `parseSpokenMajor` returns true major `S` and `amountMinor ∈ {S, S×10, S×100}`. Digits-before-words treated `2 hundred` as `2`, so `20000` was left alone. Dual hundreds were missing from the Arabic map.

### Done
- Rewrote spoken-major grammar (twins) in [`lib/application/agent/correct_spoken_amount_minor.dart`](../lib/application/agent/correct_spoken_amount_minor.dart) and [`agent/closing_agent/proposal.py`](../agent/closing_agent/proposal.py): mixed digit+scale (`2 hundred`, `2k`, `٢ مئة`) → EN/AR words (tens, dual/dialect hundreds, glued `خمسمئة`, leading glued `و`) → currency-anchored digit → last integer with year skip. Snap layer unchanged (`expected` / `×10` / `×100`; no `×1000`).
- Table tests: [`test/application/agent/correct_spoken_amount_minor_test.dart`](../test/application/agent/correct_spoken_amount_minor_test.dart) and [`agent/tests/test_proposal_tools.py`](../agent/tests/test_proposal_tools.py) — EN/AR hundred vs thousand, `2 hundred`, duals, `مائة وخمسين`, Arabic-Indic, `500 riyals on 14`, SAR leave-alone.

### Architecture / decisions
- Integer-only. Do not run `normalizeArabic()` ة→ه (destroys `مائة`). Alef-fold + tashkeel/tatweel strip only. Confirm / OpenAPI / Gate 3 unchanged. Capture-with-digits still capture.

### Ops / verification
```bash
flutter analyze lib/application/agent/correct_spoken_amount_minor.dart \
  test/application/agent/correct_spoken_amount_minor_test.dart
# No issues found
flutter test test/application/agent/correct_spoken_amount_minor_test.dart
# 41 passed
cd agent && uv run --with pytest --with pyyaml --with jsonschema \
  python -m pytest tests/test_proposal_tools.py -q
# 66 passed
# Cloud Run: adk deploy → daftar-closing-agent-00021-75q
# scale lock update → daftar-closing-agent-00022-dcd serving
# Scaling: Auto (Min: 0, Max: 2); revision Max instances: 2
# run.googleapis.com/maxScale: '2'  autoscaling.knative.dev/maxScale: '2'
```

### Status
Spoken hundred/dual/digit+scale capture snaps on device and Cloud. Gate 3 golden-set **not** checked. TTS read-back, WhatsApp, Collections, and global FTS remain out of this turn.

## 2026-08-15 — Arabic name resolution (ask leftover)

### Context
Named outstanding for محمد worked; the same ask for وليد showed no match, while a statement for وليد worked. Extract was chopping the first leftover token with `stripArabicNamePrefix` (`وليد` → `ليد`). Statement succeeded because Cloud `contactHint` was FTS-searched unmutated. Substring `replaceAll` of `على` would also destroy names like `عبدالعلى`.

### Done
- Shared token-bounded leftover helper [`leftoverNameTokens`](../lib/application/agent/arabic_name_particles.dart). Ask [`extractAskNameHint`](../lib/application/agent/ask_books_intent.dart) and [`extractStatementContactHint`](../lib/application/agent/extract_statement_contact_hint.dart) no longer call `stripArabicNamePrefix`. Glued `كشف حساب لوليد` still yields `وليد` via phrase-final `ل`.
- [`ResolveContactHintUseCase`](../lib/application/agent/resolve_contact_hint_use_case.dart): original FTS first; `stripFirstTokenPrefix` only on zero hits (`لمحمد` → `محمد`). `وليد` never queries `ليد` when the original hits.
- Tests: وليد / ليلى / فهد / بدر / فاطمة leftovers; `عبدالعلى`; `لمحمد`; statement `كشف حساب لوليد`; resolver + `AnswerAskBooksUseCase` وليد named balance.

### Architecture / decisions
- Device-only. FTS5 tokenizer unchanged. Closed transliteration aliases unchanged (not how Arabic وليد is found). Prefix-strip is a retry, not a preprocess. Gate 3 **not** checked. No Cloud Run (no agent.py / OpenAPI change).

### Ops / verification
```bash
flutter analyze lib/application/agent/arabic_name_particles.dart \
  lib/application/agent/ask_books_intent.dart \
  lib/application/agent/extract_statement_contact_hint.dart \
  lib/application/agent/resolve_contact_hint_use_case.dart \
  test/application/agent/ask_books_intent_test.dart \
  test/application/agent/extract_statement_contact_hint_test.dart \
  test/application/agent/resolve_contact_hint_use_case_test.dart \
  test/application/agent/answer_ask_books_use_case_test.dart
# No issues found
flutter test \
  test/application/agent/ask_books_intent_test.dart \
  test/application/agent/extract_statement_contact_hint_test.dart \
  test/application/agent/resolve_contact_hint_use_case_test.dart \
  test/application/agent/answer_ask_books_use_case_test.dart \
  test/application/agent/list_agent_contact_candidates_use_case_test.dart
# 39 passed
```

### Status
Any indexed name that survives token leftover extract is searched as written. Attached `ل`/`ب`/`و`/`ف` still resolve on FTS miss. Gate 3 / global FTS tokenizer / alias expansion remain out of this turn.

## 2026-08-15 — Stage 4.1 Closing orchestrator

### Context
After `propose_closing_plan` confirm, the merchant needed a device-owned close-the-day ritual: Drift `localDay` snapshot (including quick-add), Drive backup that cannot fail the close, aged Collections shortlist, Yes/Top 5/No + PDF policy prompts, then a Khazna hero report with a TTS hook. Collections Desk, Hybrid E queue, and real speech stay 4.2 / 4.3 / 5.1.

### Done
- Schema **v21**: `idx_txn_created_at` on `transactions.created_at` — [`lib/data/datasources/local/tables/transactions_table.dart`](../lib/data/datasources/local/tables/transactions_table.dart), `onUpgrade from < 21` in [`lib/data/datasources/local/drift_database.dart`](../lib/data/datasources/local/drift_database.dart); `DbConstants` + `DriveBackupConstants.schemaVersion` aligned
- [`TransactionRepository.getCreatedOnLocalDay`](../lib/domain/repositories/transaction_repository.dart): `createdAt` in device local TZ, `isDeleted = 0`, `isArchived = 0` (Appendix J.4)
- VOs/enums: [`ClosingDaySummary`](../lib/domain/value_objects/closing_day_summary.dart), [`ClosingRitualResult`](../lib/domain/value_objects/closing_ritual_result.dart), backup/reminder/PDF/step enums
- [`GetClosingDaySummaryUseCase`](../lib/application/agent/get_closing_day_summary_use_case.dart): integer per-currency totals; empty day is `Right` zeros
- [`RunClosingRitualUseCase`](../lib/application/agent/run_closing_ritual_use_case.dart): summary → `UploadDriveBackupUseCase` (queued / skippedUnsigned / failed + `needsHuman`) → `GetCollectionsCandidatesUseCase`; never WhatsApp; does not wait on prompts
- After plan confirm: progress, Yes/Top 5/No, PDF None/Selective/Selected, hero report + [`ClosingReportSpeech.announce`](../lib/core/utils/closing_report_speech.dart) no-op + haptic — widgets under [`lib/presentation/screens/closing_agent/widgets/`](../lib/presentation/screens/closing_agent/widgets/)
- ARB EN+AR (`flutter gen-l10n`); failures via `ErrorTranslator` / existing Drive ARB
- Roadmap **§4.1 only** ticked in [`docs/roadmap_v2.md`](roadmap_v2.md). Gate 4 unchecked

### Architecture / decisions
- Money truth stays Model C (Drift `createdAt` localDay, not journal)
- One plan confirm starts the ritual; skip plan remains cancel; skip-all = No after confirm (summary + backup already ran)
- PDF policy stored for 4.2, not executed; Top 5 = first 5 of ranked shortlist
- Providers call use cases only (`runClosingRitualUseCase` in [`closing_ritual_providers.dart`](../lib/presentation/providers/closing_ritual_providers.dart) to avoid core↔backup import cycle)
- Out of 4.1: Collections Desk UI, Hybrid E send queue, `flutter_tts`, Cloud Run / OpenAPI / `agent.py`, Gate 4

### Ops / verification
```bash
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter analyze  # Stage 4.1 paths — No issues found
flutter test \
  test/application/agent/get_closing_day_summary_use_case_test.dart \
  test/application/agent/run_closing_ritual_use_case_test.dart \
  test/domain/value_objects/closing_ritual_result_test.dart \
  test/domain/constants/closing_agent_constants_test.dart \
  test/data/repositories/get_created_on_local_day_test.dart \
  test/data/repositories/agent_schema_v19_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_ritual_reminder_prompt_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_ritual_report_card_test.dart
# 23 passed; schema v21 also re-run separately (1 passed)
```

### Status
§4.1 complete. Next: §4.2 Collections Desk UI. Backup enqueue-on-fail and empty-overdue paths are in; no WhatsApp open, no PDF batch, no Gate 4.

## 2026-08-15 — Stage 4.2 Collections Desk

### Context
After Yes/Top 5 and PDF policy, the Closing Agent now shows a device-owned Khazna Collections Desk: ranked Drift drafts (AR/EN Appendix C), tone override, per-row Open WhatsApp / Copy / Skip / PDF toggle, and Start sending that opens only the first pending chat.

### Done
- Domain: [`CollectionsDeskRow`](../lib/domain/value_objects/collections_desk_row.dart), [`CollectionsDeskRowStatus`](../lib/domain/enums/collections_desk_row_status.dart), [`CollectionsReminderDraftComposer`](../lib/domain/constants/collections_reminder_draft_composer.dart) (AR/EN, integer formatted amount, no shame lexicon)
- Application: [`BuildCollectionsDeskUseCase`](../lib/application/agent/build_collections_desk_use_case.dart), [`ComposeCollectionsReminderDraftUseCase`](../lib/application/agent/compose_collections_reminder_draft_use_case.dart) (`MoneyUtil.formatMinorUnitsForCode`; store fallback `"Daftar"`)
- Presentation: `ClosingAgentPhase.ritualDesk`; [`choosePdfPolicy`](../lib/presentation/providers/closing_agent_controller.dart) → Desk when `reminderSet` is non-empty; skip / tone / PDF / copy / open / `startSending` / `finishDesk`
- Shared [`shareContactStatementPdf`](../lib/presentation/screens/closing_agent/share_agent_statement.dart) (prepare → PDF → share sheet, no agent confirm)
- UI: [`collections_desk_panel.dart`](../lib/presentation/screens/closing_agent/widgets/collections_desk_panel.dart) (`ListView.builder`) + [`collections_desk_row.dart`](../lib/presentation/screens/closing_agent/widgets/collections_desk_row.dart); Start sending owns lapis glow; ARB EN+AR
- Roadmap **§4.2 only** ticked in [`docs/roadmap_v2.md`](roadmap_v2.md). Gate 4 and §4.3 unchecked

### Architecture / decisions
- Device-owned drafts from Drift `owedMinor`; Cloud Run `propose_whatsapp_drafts` is not called on this path
- Empty overdue and skip-all (No) still skip the Desk; skip-all rows or Done with remaining pending → existing hero report
- Start sending opens the first `pending` row only (Hybrid E = prepare + human tap); no N-tab spam
- Attach-PDF on → OS share sheet (`StatementShare`), not `wa.me`; WhatsApp launcher is a test seam
- Out of 4.2: 4.3 persist/resume/sticky/pause/metrics, 4.4 aging, 4.5 seed, Gate 4, Cloud Run / OpenAPI / `agent.py`, silent sends

### Ops / verification
```bash
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter analyze  # Stage 4.2 paths — No issues found
flutter test \
  test/domain/constants/collections_reminder_draft_composer_test.dart \
  test/application/agent/build_collections_desk_use_case_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart \
  test/presentation/screens/closing_agent/widgets/collections_desk_row_test.dart \
  test/presentation/screens/closing_agent/widgets/collections_desk_panel_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_ritual_reminder_prompt_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_ritual_report_card_test.dart \
  test/domain/value_objects/closing_ritual_result_test.dart
# 27 passed
```

### Status
§4.2 complete. Next: §4.3 Hybrid E send queue (persist/resume/sticky bar). Gate 4 still closed.

## 2026-08-15 — Stage 4.3 Hybrid E send queue

### Context
After Start sending on the Collections Desk, Hybrid E must keep “Sending i of N” across app resume and process death without silently opening extra WhatsApp chats. Official `wa.me` click-to-chat cannot attach PDFs or confirm Send; resume therefore offers the next pending row on a sticky bar (human tap), it does not auto-launch `wa.me`.

### Done
- Domain: [`CollectionsSendQueue`](../lib/domain/value_objects/collections_send_queue.dart), [`CollectionsSendQueueStatus`](../lib/domain/enums/collections_send_queue_status.dart), [`CollectionsQueueMetrics`](../lib/domain/value_objects/collections_queue_metrics.dart); [`ClosingRitualResult.queueMetrics`](../lib/domain/value_objects/closing_ritual_result.dart) + `overdueTotal` / `overdueCount` for Top 5 restore
- Drift **schemaVersion 21 → 22**: [`collections_send_queues`](../lib/data/datasources/local/tables/collections_send_queues_table.dart) + `collections_send_queue_items`; `onUpgrade from < 22` in [`drift_database.dart`](../lib/data/datasources/local/drift_database.dart); `DbConstants` + `DriveBackupConstants.schemaVersion` aligned; BACKUP_SPEC / Drive spec examples updated
- Application: [`Save` / `LoadInFlight` / `Complete` use cases](../lib/application/agent/collections_send_queue_use_cases.dart) via [`closing_ritual_providers.dart`](../lib/presentation/providers/closing_ritual_providers.dart)
- Controller: Start sending persists the queue; Open after queue-start sets `queueAwaitingResume`; [`onHostResumed`](../lib/presentation/providers/closing_agent_controller.dart) clears the flag + haptic (no second `wa.me`); Pause / Resume; hydrate from Closing Agent screen (`paused`/`hidden` → background, not `inactive`); Done leftover pending → skipped + metrics
- UI: [`collections_send_queue_bar.dart`](../lib/presentation/screens/closing_agent/widgets/collections_send_queue_bar.dart) sticky Open / Skip / Pause; report prepared / opened / skipped; ARB EN+AR
- Roadmap **§4.3 only** ticked in [`docs/roadmap_v2.md`](../docs/roadmap_v2.md). Gate 4, §4.4, §4.5 unchecked

### Architecture / decisions
- Persistence is Drift (not SharedPreferences / secure storage): one in-flight queue; integer money on item `netBalance`; device-owned draft bodies
- Resume = offer, not auto-launch (Hybrid E, no silent / N-tab spam). Share sheet must not advance (`inactive` ignored)
- Queue starts at Start sending, not at a lone per-row Open. New goal abandons the prior in-flight id
- Out of 4.3: 4.4 aging retune, 4.5 demo seed, Gate 4, Cloud Run / OpenAPI / `agent.py`, WhatsApp Business API, auto-opening the next chat

### Ops / verification
```bash
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter analyze  # Stage 4.3 paths — No issues found
flutter test \
  test/domain/constants/collections_reminder_draft_composer_test.dart \
  test/application/agent/build_collections_desk_use_case_test.dart \
  test/domain/value_objects/collections_queue_metrics_test.dart \
  test/domain/value_objects/closing_ritual_result_test.dart \
  test/data/repositories/agent_schema_v19_test.dart \
  test/data/repositories/collections_send_queue_repository_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart \
  test/presentation/screens/closing_agent/widgets/collections_desk_row_test.dart \
  test/presentation/screens/closing_agent/widgets/collections_desk_panel_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_ritual_reminder_prompt_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_ritual_report_card_test.dart
# 39 passed
```

### Status
§4.3 complete. Next: §4.4 adaptive tone (or explicit Appendix I deferral) then §4.5 demo seed. Gate 4 still closed.

## 2026-08-16 — Stage 4.4 Adaptive tone (+ 4.3 Hybrid E follow-up)

### Context
Friendly / Reminder / Firm existed from §3.2 as age-only 7/30 buckets; `daysSinceLastPayment` was computed and unused. Stage 4.4 keeps Appendix D’s 7/30 **base** and caps Firm → Reminder for a recent payer (≤14 local days), without promoting quieter accounts or adding shame language. A short 4.3 follow-up also aligns Hybrid E persist / PDF metrics with the verified `wa.me` click-to-chat contract (opened, not sent).

### Done
- **4.3 follow-up (do not re-tick §4.3 / Gate 4):**
  - [`share_agent_statement.dart`](../lib/presentation/screens/closing_agent/share_agent_statement.dart): `ShareResultStatus.dismissed` → cancelled (row stays `pending`); Android `unavailable` still counts as shared
  - Controller awaits `_persistQueue()` when `queueId != null`; persist `Left` → `actionFailure`; `markAwaitingResume` only if `queueStatus == active`
  - Composite index `idx_collections_send_queues_status_updated` on `(status, updated_at)` — schema stays **v22**, `CREATE INDEX IF NOT EXISTS` in `from < 22` and `beforeOpen` ([`drift_database.dart`](../lib/data/datasources/local/drift_database.dart), [`collections_send_queues_table.dart`](../lib/data/datasources/local/tables/collections_send_queues_table.dart))
- **4.4 adaptive tone:**
  - [`PaymentBehaviorBand`](../lib/domain/enums/payment_behavior_band.dart): `recent` (≤14) / `lapsed` (>14) / `none` (null)
  - [`reminder_tone_resolver.dart`](../lib/domain/constants/reminder_tone_resolver.dart): keep `reminderToneBandForAgeDays` as the documented base; production path `reminderToneBandForAging` never promotes; recent payer never Firm
  - [`FifoContactAging.toneBand`](../lib/application/contact/compute_fifo_contact_aging.dart) + [`CollectionsCandidate.paymentBehaviorBand`](../lib/domain/value_objects/collections_candidate.dart)
  - Composer firm CTAs distinct in AR+EN (courteous settle-when-able; no ignore / final notice / legal / agency / مماطل / تجاهل / إنذار)
  - Desk recency line ARB `collectionsDeskLastPaymentDays` when `daysSinceLastPayment != null` (omit if none — never “never paid”)
  - Selective PDF still `ageDays >= 30 || toneBand == firm` on the **candidate**, not the desk override
- Roadmap **§4.4 only** ticked in [`docs/roadmap_v2.md`](roadmap_v2.md) (full “three bands in Stage 4 **or** explicitly defer…” sentence). Gate 4, §4.5, Appendix I item 1 unchecked

### Architecture / decisions
- Adaptation is a **cap/modifier**, not new buckets. Western 30/60/90 invoice dunning does not apply (FIFO running-balance).
- `daysSinceLastDebt` stays on the VO for honesty / future; it is not a tone input.
- Desk `setDeskTone` still regenerates body only — it does not rewrite FIFO age.
- Resume still does not auto-launch `wa.me`. Metrics remain **opened**, not sent.
- Remaining gap: `daysSinceLastPayment` is not on `collections_send_queue_items`, so a hydrated queue omits the recency line until the next live candidate build.
- Out of 4.4: 4.5 demo seed, Gate 4, Cloud Run / `agent.py` / OpenAPI, WhatsApp Business API, 30/60/90 invoice buckets, threat language, silent sends, retuning the 7/30 **base** days

### Ops / verification
```bash
flutter analyze  # Stage 4.4 paths — No issues found
flutter test \
  test/domain/constants/reminder_tone_resolver_test.dart \
  test/domain/constants/collections_reminder_draft_composer_test.dart \
  test/application/contact/compute_fifo_contact_aging_test.dart \
  test/application/contact/get_collections_candidates_use_case_test.dart \
  test/application/agent/build_collections_desk_use_case_test.dart \
  test/domain/value_objects/closing_ritual_result_test.dart \
  test/domain/value_objects/collections_queue_metrics_test.dart \
  test/data/repositories/agent_schema_v19_test.dart \
  test/data/repositories/collections_send_queue_repository_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart \
  test/presentation/screens/closing_agent/widgets/collections_desk_row_test.dart \
  test/presentation/screens/closing_agent/widgets/collections_desk_panel_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_ritual_reminder_prompt_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_ritual_report_card_test.dart
# 70 passed
```

### Status
§4.4 complete (implemented in Stage 4, not deferred). Next: §4.5 demo seed, then Gate 4. Gate 4 still closed.

## 2026-08-16 — Stage 4.5 Demo seed

### Context
Gate 4 needs a filmable closing-day workspace: Pro, Arabic locale, Drive linked, overdue mix, and a ≤4 min script with GCP proof. The existing debug seeder was a bilingual multi-currency QA dump whose `createdAt: now` on every txn would have lied in Drift `localDay` summary.

### Done
- Rewrote [`DevDatabaseSeeder.seedData`](../lib/core/utils/dev_database_seeder.dart): one customers ledger (`المبيعات الرئيسية`), **N=12** Arabic YER contacts (exactly one `محمد علي`), 10 Desk-eligible / فاطمة no-phone / settled omitted; Friendly + Reminder + Firm + recent-payer cap (نادية); historical `createdAt` backdated with `transactionDate`; **2** today-strip rows; locale `ar`, YER, multi-currency off, `محل الغانم`; wipe collections queues + day journal + agent sessions/turns/outbox; preserve Drive Google ids
- Settings debug caption + invalidate locale / merchant / contacts after seed ([`settings_screen.dart`](../lib/presentation/screens/settings/settings_screen.dart))
- [`docs/contest_demo.md`](contest_demo.md): owner prep (debug Pro+, Drive, warm Cloud Run), expected N, ≤4 min shot list, opened ≠ sent, GCP Console URLs
- Roadmap **§4.5 only** ticked. Gate 4 and Stage 6 recording stay unchecked

### Architecture / decisions
- Seed stays debug-only (`kDebugMode`). Debug Pro+ via `DevEntitlement`; profile/release uses `dart run tool/generate_offline_activation_code.dart pro` (never commit a code)
- Drive cannot be faked; owner links Google before filming
- YER is 0 decimal places — filmed “500 sugar” is integer `500`
- Perf-seed button unchanged
- Out of 4.5: Gate 4 filming, Stage 6 YouTube lock, Cloud Run / `agent.py` edits, WhatsApp API, release APK seed, real customer phones

### Ops / verification
```bash
flutter analyze \
  lib/core/utils/dev_database_seeder.dart \
  lib/presentation/screens/settings/settings_screen.dart \
  test/core/utils/dev_database_seeder_test.dart
# No issues found
flutter test test/core/utils/dev_database_seeder_test.dart
# 5 passed
```

### Status
§4.5 complete. Next: Gate 4 (film the ritual on the seeded device). Gate 4 still closed.

## 2026-08-17 — Silent Closing Agent ID-token renewal (PKCE openid)

### Context
After ~1 hour of a linked Google session, Drive backup still worked (PKCE access-token refresh) but Closing Agent Send opened a Google account picker. GSI v7 ID tokens expire in ~3600s and `hydrateLinkedIdToken` called `attemptLightweightAuthentication()`, which on Android Credential Manager is allowed to show One Tap even while the Drive grant is healthy. Product GCP (`daftar-core-prod`) owns Flutter OAuth clients; contest GCP (`daftar-closing-agent`) hosts Cloud Run. Confirmed `.env` Web/Android/iOS client IDs belong to the product project — not mixed into the AI project.

### Done
- PKCE-only scopes `openid` + `email` in [`lib/domain/constants/auth_scopes.dart`](../lib/domain/constants/auth_scopes.dart). GSI `authenticate(scopeHint:)` stays `drive.appdata` only.
- [`DriveOfflineGrantDs`](../lib/data/datasources/remote/drive_offline_grant_ds.dart) requests `pkceOfflineGrantScopes`; persists AppAuth `idToken`.
- [`GoogleTokenRefreshClient`](../lib/data/datasources/remote/google_token_refresh_client.dart) parses optional `id_token`. [`ensureDriveCredential`](../lib/data/datasources/remote/google_auth_ds.dart) piggybacks it onto Drive refresh.
- [`hydrateLinkedIdToken`](../lib/data/datasources/remote/google_auth_ds.dart): unexpired cache → PKCE HTTP refresh (zero GSI UI) → `LinkedIdTokenNeedsOpenIdGrant` if Drive grant lacks openid. Interceptor still `allowInteractive: false`.
- [`completeDriveAuthorization`](../lib/data/repositories/auth_repository_impl.dart) no-ops only when `hasOpenIdOfflineGrant`; otherwise re-runs AppAuth with `loginHint` (one-time Custom Tabs consent, not an account picker).
- Agent error sheet CTA for `agent_openid_grant_required` → same Drive authorization ceremony. ARB EN+AR.
- Cloud Run custom audiences: Web (existing) + Android + iOS installed-app client IDs. IAM unchanged (`allAuthenticatedUsers` + `user:akrm.codes@gmail.com`). Revision `daftar-closing-agent-00024-bl9`.
- Docs: [`agent/README.md`](../agent/README.md), Appendix J.1, [`docs/architecture/GOOGLE_DRIVE_SYNC_SPEC.md`](architecture/GOOGLE_DRIVE_SYNC_SPEC.md).

### Architecture / decisions
- Silent ID-token mint uses the **existing** Drive PKCE refresh token. Do not create OAuth clients on the contest GCP project. Do not put Gemini keys in Flutter. Do not call GSI lightweight restore on Send.
- PKCE-minted ID tokens have `aud` = Android/iOS client ID; GSI tokens keep `aud` = Web client ID. Cloud Run accepts all three as custom audiences.
- Non-goals: Drive Workmanager path behavior (only optional id_token persist), Sign-In sheet, Stage 8 sync interactive path, Vertex env.

### Ops / verification
```bash
# Cloud Run: 3 custom audiences (web + android + ios); IDs not logged
dart analyze <touched auth/agent files>
# No issues found
flutter gen-l10n
flutter test \
  test/data/datasources/remote/google_token_refresh_client_test.dart \
  test/data/datasources/remote/google_id_token_expiry_test.dart \
  test/data/datasources/remote/google_auth_ds_obtain_id_token_test.dart \
  test/data/datasources/remote/google_auth_ds_headless_test.dart \
  test/data/datasources/remote/google_auth_ds_cached_client_test.dart \
  test/data/datasources/remote/google_auth_failure_mapper_test.dart \
  test/core/services/auth_session_store_test.dart \
  test/domain/value_objects/auth_session_bundle_test.dart \
  test/data/repositories/auth_repository_impl_test.dart \
  test/application/agent/hydrate_agent_id_token_use_case_test.dart \
  test/application/agent/closing_agent_client_test.dart \
  test/core/utils/error_translator_agent_auth_test.dart \
  test/application/backup/headless_drive_session_test.dart \
  test/data/datasources/remote/auth_silent_sign_in_gateway_impl_test.dart
```

Device follow-up: first Send after this build may open **one** AppAuth consent (hinted account) if the stored grant predates `openid`. After that, wait ~55 minutes and Send again — no Google account chooser. Drive backup in the same session must still succeed.

### Status
Silent agent ID-token renewal landed. Gate 4 filming can proceed after the one-time PKCE upgrade on the demo device.

## 2026-08-17 — Pre-Stage 5 Closing Agent precision

### Context
Harden the Cloud Run ADK agent before Stage 5 speech: rewrite system instructions for Daftar domain mastery and parallel compound intents, fix spoken-amount snap so multi-contact turns are not collapsed to one number, and lock the OpenAPI/Flutter tool contract. No `audioRef` / STT / TTS / mic.

### Done
- Rewrote [`agent/closing_agent/agent.py`](../agent/closing_agent/agent.py) `INSTRUCTION`: proposals-only Confirm Gate, Arabic idioms, integer money, J.4 `merchantLocalDay`, Model C / Hybrid E, skip `parse_goal` on clear capture/close, close-the-day → `propose_closing_plan` only (no WA-on-close), compound → multiple function calls in the same turn. Locked in [`agent/tests/test_agent_instruction.py`](../agent/tests/test_agent_instruction.py).
- Tool docstrings in [`agent/closing_agent/tools.py`](../agent/closing_agent/tools.py): one contact per call; call multiple times in parallel for compound intents. `parse_goal` stays in `ALL_TOOLS`. `propose_whatsapp_drafts` stays in the enum (explicit prepare-reminders without close-the-day).
- Hint-scoped spoken-amount snap (twins): [`agent/closing_agent/proposal.py`](../agent/closing_agent/proposal.py) `goal_slice_for_hint` / `correct_zero_decimal_scale` via `voiceHints`; [`lib/application/agent/correct_spoken_amount_minor.dart`](../lib/application/agent/correct_spoken_amount_minor.dart) + sibling `contactHint`s from the same turn in [`closing_agent_controller.dart`](../lib/presentation/providers/closing_agent_controller.dart) `_spokenAmounts`.
- Contract only (no Appendix J / schema field churn): mapper two-`functionResponse` test; OpenAPI `AgentTurnResponse.proposals` description 0..N envelopes from parallel tools in one `/run`.

### Architecture / decisions
- Keep `BuiltInPlanner` + `thinking_level=MINIMAL`. No `async def` rewrite. No new tools. Confirm remains per `proposalId`.
- Out of slice: Stage 5 audio, Cloud Run env/model change, WhatsApp Business API, 30/60/90 dunning, batch confirm-all.

### Ops / verification
```bash
cd agent && uv run --with pytest --with pyyaml --with jsonschema \
  python -m pytest tests/test_agent_instruction.py tests/test_proposal_tools.py -q
# 72 passed
flutter test test/application/agent/correct_spoken_amount_minor_test.dart \
  test/data/mappers/adk_event_proposal_mapper_test.dart
# 50 passed
flutter analyze lib/application/agent/correct_spoken_amount_minor.dart \
  lib/presentation/providers/closing_agent_controller.dart \
  lib/data/mappers/adk_event_proposal_mapper.dart
# No issues found
```

Live Gemini will not see the new instruction until Cloud Run redeploy (`adk deploy cloud_run` with existing min 0 / max 2 / Vertex `global` / `gemini-3.5-flash` — same flags as Stage 1.1). Local pytest is not production.

### Status
Precision slice complete. **Do not tick Stage 5, Gate 4/5, or Appendix I.** Next: optional Cloud Run redeploy, then Gate 4 filming or Stage 5 speech when ready.

## 2026-08-17 — Cloud Run redeploy (precision instruction)

### Context
Owner asked to deploy the Pre-Stage 5 Closing Agent precision code so live Gemini 3.5 Flash sees the new system instruction. Same Stage 1.1 flags: `gemini-3.5-flash`, min 0 / max 2 (both layers), Vertex `GOOGLE_CLOUD_LOCATION=global`.

### Done
- `uvx --from google-adk==1.14.0 adk deploy cloud_run` from [`agent/`](../agent/) with `--adk_version=1.14.0`, `--no-allow-unauthenticated`, `--min=0 --max=2 --min-instances=0 --max-instances=2`, SA `agent-runner@daftar-closing-agent.iam.gserviceaccount.com`, env `GOOGLE_GENAI_USE_VERTEXAI=TRUE` / `GOOGLE_CLOUD_PROJECT=daftar-closing-agent` / `GOOGLE_CLOUD_LOCATION=global`.
- Idempotent cost-lock `gcloud run services update` (same four scale flags). Custom audiences (3) and invoker IAM left intact.
- Serving revision **`daftar-closing-agent-00026-gq2`**. URL `https://daftar-closing-agent-1487285471.us-central1.run.app`.

### Architecture / decisions
- Model still pinned in [`agent/closing_agent/agent.py`](../agent/closing_agent/agent.py) (`gemini-3.5-flash`). No Stage 5 audio. No min-instances bump.
- Custom audience values are OAuth client IDs — not logged here.

### Ops / verification
```bash
gcloud run services describe daftar-closing-agent \
  --project=daftar-closing-agent --region=us-central1
# Scaling: Auto (Min: 0, Max: 2)
# Max instances: 2
# latestReadyRevisionName: daftar-closing-agent-00026-gq2
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  https://daftar-closing-agent-1487285471.us-central1.run.app/list-apps
# ["closing_agent"] HTTP 200
```

IAM: `roles/run.invoker` = `allAuthenticatedUsers` + `user:akrm.codes@gmail.com`. Env: Vertex TRUE, location global.

### Status
Live Cloud Run is on the precision instruction. First Send after scale-to-zero is still a cold start. **Do not tick Stage 5, Gate 4/5, or Appendix I.**

## 2026-08-17 — Home ledger grid shell dock clearance

### Context
With multiple ledgers on the home screen, the bottom row of the 2-column grid scrolled behind the floating glass navigation dock (`MainShell` uses `extendBody: true`).

### Done
- Added `bottomScrollClearance` (`safe area + AppDimensions.shellDockScrollInset`) and a trailing `SliverToBoxAdapter` spacer on [`lib/presentation/screens/home/home_screen.dart`](../lib/presentation/screens/home/home_screen.dart) — same pattern as backup and activation screens.

### Architecture / decisions
- Reused existing `shellDockScrollInset` token (64dp bar + margins + gap); no new layout constants.
- Clearance applied at the screen scroll level so all async states (loading, empty, populated) share the same bottom inset.

### Ops / verification
- `dart analyze lib/presentation/screens/home/home_screen.dart` — no issues.

### Status
Home ledger grid should fully scroll above the nav dock. Manual check: create 4+ ledgers and confirm the last row is tappable without overlapping the dock.

## 2026-08-17 — Precise contact matching on Confirm

### Context
Two Confirm-Gate bugs: (1) `propose_create_contact` errored when `daftarContext` had more than one ledger and Gemini omitted `ledger_id`, so Flutter never mounted a Confirm card and the model narrated “pick a book”; (2) a unique FTS prefix hit (`Mohammed` → `Mohammed Waleed`) silently auto-bound. Industry rule: never silently resolve an ambiguous name. Auto-bind only on exact normalized full names.

### Done
- Cloud: [`agent/closing_agent/tools.py`](../agent/closing_agent/tools.py) `propose_create_contact` always emits a proposal (optional `ledgerId`); [`agent/closing_agent/agent.py`](../agent/closing_agent/agent.py) instruction never narrates pick-a-book / already-registered / list of accounts.
- Shared [`lib/application/agent/contact_name_match.dart`](../lib/application/agent/contact_name_match.dart) `isExactContactNameMatch`. Applied in controller `_loadCandidates`, Confirm card, [`ResolveAgentContactUseCase`](../lib/application/agent/resolve_agent_contact_use_case.dart), [`AnswerAskBooksUseCase._namedForHint`](../lib/application/agent/answer_ask_books_use_case.dart). Cloud `resolve_contact_id` left exact/fold-only.
- Confirm: similar hits → existing chips + trailing Create “{name}” (`person_add`, monochrome + hairline). Confirm disabled until tap. Statement: chips only, no Create new. Unique exact money: one-tap, no chips.
- Create-contact searches similar names; unique exact disables Confirm (`contact_name_exists` helper). Ledger chips always visible while creating (`ledgers.isNotEmpty`); `ledgersReady` keeps Confirm disabled while `ledgersProvider` loads (no “name a new ledger”).
- ARB EN+AR: `closingAgentDidYouMean`, `closingAgentCreateNewNamed`, `closingAgentContactAlreadyExists`.

### Architecture / decisions
- Exact match = `normalizeArabic` + case-fold full-name equality. Aliases (`Mohamed`/`محمد`) and FTS `token*` uniqueness are **not** exact.
- Create new sets `createNewByProposal`; picking an existing contact clears it. Create-contact Confirm with a picked existing id short-circuits (no Drift create).
- Out of slice: Stage 5 speech, batch confirm-all, embeddings/fuzzy rankers, WhatsApp API, changing FTS `token*` itself.

### Ops / verification
```bash
cd agent && uv run --with pytest --with pyyaml --with jsonschema \
  python -m pytest tests/test_agent_instruction.py tests/test_proposal_tools.py -q
# 73 passed
flutter test test/application/agent/contact_name_match_test.dart \
  test/application/agent/commit_agent_proposal_use_case_test.dart \
  test/application/agent/answer_ask_books_use_case_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_confirm_card_test.dart
# 65 passed (confirm card 18)
flutter analyze lib/application/agent/contact_name_match.dart \
  lib/application/agent/resolve_agent_contact_use_case.dart \
  lib/application/agent/answer_ask_books_use_case.dart \
  lib/presentation/providers/closing_agent_controller.dart \
  lib/presentation/providers/closing_agent_state.dart \
  lib/presentation/screens/closing_agent/widgets/agent_confirm_card.dart \
  lib/presentation/screens/closing_agent/closing_agent_screen.dart
# No issues found
```

**Cloud Run redeploy required** for live Gemini to stop narrating “pick a book” (`propose_create_contact` still errors on serving revision `daftar-closing-agent-00026-gq2`). Same Stage 1.1 flags: `uvx --from google-adk==1.14.0 adk deploy cloud_run`, min 0 / max 2 both layers, Vertex `GOOGLE_CLOUD_LOCATION=global`, SA `agent-runner@…`. Device exact-match + chips work without redeploy.

### Status
Slice complete. **Do not tick Stage 5, Gate 4/5, or Appendix I.** Next: Cloud Run redeploy after merge, then Gate 4 filming or Stage 5 speech when ready.

## 2026-08-17 — Cloud Run redeploy (precise contact matching)

### Context
Owner asked to deploy the updated Closing Agent so live Gemini 3.5 Flash sees the create-contact instruction (`ledger_id` optional; never narrate “pick a book”) and the tool always emits a Confirm proposal.

### Done
- `uvx --from google-adk==1.14.0 adk deploy cloud_run` from [`agent/`](../agent/) with `--adk_version=1.14.0`, `--no-allow-unauthenticated`, `--min=0 --max=2 --min-instances=0 --max-instances=2`, SA `agent-runner@daftar-closing-agent.iam.gserviceaccount.com`, env `GOOGLE_GENAI_USE_VERTEXAI=TRUE` / `GOOGLE_CLOUD_PROJECT=daftar-closing-agent` / `GOOGLE_CLOUD_LOCATION=global`.
- Idempotent cost-lock `gcloud run services update` (same four scale flags). Custom audiences (3) and invoker IAM left intact.
- Serving revision **`daftar-closing-agent-00029-pdm`**. URL `https://daftar-closing-agent-1487285471.us-central1.run.app`.

### Architecture / decisions
- Model still pinned in [`agent/closing_agent/agent.py`](../agent/closing_agent/agent.py) (`gemini-3.5-flash`). No Stage 5 audio. No min-instances bump.
- Custom audience values are OAuth client IDs — not logged here.

### Ops / verification
```bash
gcloud run services describe daftar-closing-agent \
  --project=daftar-closing-agent --region=us-central1
# Scaling: Auto (Min: 0, Max: 2)
# Max instances: 2
# latestReadyRevisionName: daftar-closing-agent-00029-pdm
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  https://daftar-closing-agent-1487285471.us-central1.run.app/list-apps
# ["closing_agent"] HTTP 200
```

IAM: `roles/run.invoker` = `allAuthenticatedUsers` + `user:akrm.codes@gmail.com`. Env: Vertex TRUE, location global.

### Status
Live Cloud Run is on the precise-contact-matching instruction and `propose_create_contact` always-proposal tool. First Send after scale-to-zero is still a cold start. **Do not tick Stage 5, Gate 4/5, or Appendix I.**

## 2026-08-18 — Spoken goods → itemName (not observation)

### Context
“Mohammed bought 500 riyals of juice” was landing in transaction `description` (ملاحظة) because Closing Agent only had payload `note` and commit wrote `description: note`. Quick Add already persists goods as `itemName` (اسم الصنف). List title showed `—` with juice as subtitle.

### Done
- OpenAPI + [`agent/closing_agent/tools.py`](../agent/closing_agent/tools.py): optional `itemName` on `propose_debt` / `propose_payment`. [`agent/closing_agent/agent.py`](../agent/closing_agent/agent.py) instruction: goods → `item_name` only; remarks → `note`; never duplicate.
- Shared [`lib/application/agent/resolve_agent_money_goods.dart`](../lib/application/agent/resolve_agent_money_goods.dart): legacy `note`-only → `itemName`; duplicate item/note drops the copy.
- Commit + mapper: `itemName` + `description` on [`AddTransactionUseCase`](../lib/application/transaction/add_transaction_use_case.dart). Confirm card shows Item Name then Note; picked phone no longer overwrites goods.
- ARB: reused `itemName` + `closingAgentNoteLabel`. No new keys.

### Architecture / decisions
- No new Drift columns. No line items. Match Quick Add for goods; keep optional `note` → `description` like the full add dialog.
- Device fallback fixes juice even before Gemini learns `item_name`. After Cloud Run, remarks stay remarks.
- Out of slice: Confirm item editing, qty/unit price, Stage 5 speech.

### Ops / verification
```bash
cd agent && uv run --with pytest --with pyyaml --with jsonschema \
  python -m pytest tests/test_agent_instruction.py tests/test_proposal_tools.py -q
# 78 passed
flutter test test/application/agent/resolve_agent_money_goods_test.dart \
  test/application/agent/commit_agent_proposal_use_case_test.dart \
  test/data/mappers/adk_event_proposal_mapper_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_confirm_card_test.dart
# 56 passed
dart analyze lib/application/agent/resolve_agent_money_goods.dart \
  lib/application/agent/commit_agent_proposal_use_case.dart \
  lib/domain/value_objects/agent_proposal.dart \
  lib/data/mappers/adk_event_proposal_mapper.dart \
  lib/presentation/screens/closing_agent/widgets/agent_confirm_card.dart
# No issues found
```

### Status
Device + contract complete. Cloud Run redeploy required so live Gemini fills `itemName`. **Do not tick Stage 5, Gate 4/5, or Appendix I.**

## 2026-08-18 — Cloud Run redeploy (itemName goods)

### Context
Owner asked to implement spoken goods → `itemName`. Live Gemini needed the new tool arg and instruction so juice is not stuffed into `note`.

### Done
- `uvx --from google-adk==1.14.0 adk deploy cloud_run` from [`agent/`](../agent/) with `--adk_version=1.14.0`, `--no-allow-unauthenticated`, `--min=0 --max=2 --min-instances=0 --max-instances=2`, SA `agent-runner@daftar-closing-agent.iam.gserviceaccount.com`, env Vertex TRUE / project `daftar-closing-agent` / location `global`.
- Idempotent cost-lock `gcloud run services update`. Custom audiences (3) and invoker IAM left intact.
- Serving revision **`daftar-closing-agent-00031-j8v`**. URL `https://daftar-closing-agent-1487285471.us-central1.run.app`.

### Architecture / decisions
- Model still `gemini-3.5-flash`. No Stage 5 audio. No min-instances bump.
- Custom audience values are OAuth client IDs — not logged here.

### Ops / verification
```bash
gcloud run services describe daftar-closing-agent \
  --project=daftar-closing-agent --region=us-central1
# Scaling: Auto (Min: 0, Max: 2)
# Max instances: 2
# latestReadyRevisionName: daftar-closing-agent-00031-j8v
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  https://daftar-closing-agent-1487285471.us-central1.run.app/list-apps
# ["closing_agent"] HTTP 200
```

IAM: `roles/run.invoker` = `allAuthenticatedUsers` + `user:akrm.codes@gmail.com`. Env: Vertex TRUE, location global.

### Status
Live Cloud Run emits optional `itemName` for goods. Device fallback still maps legacy `note`-only juice to `itemName`. First Send after scale-to-zero is a cold start. **Do not tick Stage 5, Gate 4/5, or Appendix I.**

## 2026-08-19 — Brand identity: replace Flutter logos with Daftar mark

### Context
Owner supplied dark/light app-icon packs, a splash gradient (`background.png`), and two SVGs. Staging folders sat at the repo root. The Flutter default bird was still the launcher icon on every platform.

### Done
- Canonical runtime assets: [`assets/brand/`](../assets/brand/) (`daftar_mark_on_light.svg`, `daftar_mark_on_dark.svg`, `background.png`).
- Masters + store marketing: [`brand/masters/`](../brand/masters/), [`brand/store/`](../brand/store/) (App Store 1024 + Play 512, light and dark).
- Replaced Flutter launcher icons on Android (adaptive + night + monochrome), iOS (light/dark/tinted), macOS, web (PWA + SVG favicon), Windows ICO.
- Native splash: Android `launch_background` (bone + mark / gradient + mark); iOS `LaunchLogo` + `LaunchBackground` + `LaunchColor`.
- In-app [`DaftarBrandMark`](../lib/presentation/shared/widgets/daftar_brand_mark.dart) on lock screen (glowXl), onboarding header, About sheet.
- Home-screen labels: Android/iOS `Daftar` / `دفتر`; web/Windows/Linux/macOS display name `Daftar`.
- Staging folders `AppIcons dark`, `AppIcons light`, `background/`, `SVG/` removed after move.
- Regenerator: [`tool/generate_brand_icons.py`](../tool/generate_brand_icons.py).

### Architecture / decisions
- Light appearance = black D + lapis bar on white. Dark appearance = white D + lapis bar on OLED `#000000` (the supplied “light” 1024 was white-on-white; composited from the transparent adaptive foreground).
- Android adaptive foregrounds keep appicon.co safe-zone padding. Full-bleed store/iOS/legacy icons restore the SVG artboard scale (~40% glyph).
- Lapis bar is part of the designed glyph, not UI chrome fill.

### Ops / verification
```bash
flutter test test/presentation/shared/widgets/daftar_brand_mark_test.dart
# 2 passed
dart analyze lib/presentation/shared/widgets/daftar_brand_mark.dart \
  lib/presentation/screens/auth/lock_screen.dart \
  lib/presentation/screens/onboarding/onboarding_screen.dart \
  lib/presentation/screens/settings/widgets/settings_about_sheet.dart
```

### Status
Flutter bird replaced. Owner should rebuild the app to see launcher/splash. Remaining: see conversation notes (iPad pack sizes were generated from 1024; original light store PNG was unusable white-on-white).

## 2026-08-19 — Fix Android night mipmap directory names

### Context
`flutter run` failed at `:app:mergeDebugResources` with `Invalid resource directory name` for `mipmap-mdpi-night`. Android requires night mode before density (`mipmap-night-mdpi`).

### Done
- Renamed `mipmap-{density}-night` → `mipmap-night-{density}` for mdpi–xxxhdpi.
- [`tool/generate_brand_icons.py`](../tool/generate_brand_icons.py) now writes the correct qualifier order.

### Status
Resource merger should succeed. Adaptive night icons were already valid (`drawable-night-*`).

## 2026-08-19 — App icon uses designed gradient background

### Context
The phone launcher still showed a flat white/black canvas. The designed `background.png` (black→lapis diagonal) was only on splash, not the home-screen icon.

### Done
- Full-bleed icons (iOS, Android mipmaps, Play/App Store, web, Windows, macOS) composite the white mark onto [`assets/brand/background.png`](../assets/brand/background.png).
- Android adaptive icon: background layer = gradient bitmap (`ic_launcher_background`); foreground = white mark inside the safe zone.
- Launch splash (Android light + iOS any) now uses the same gradient so cold-start matches the icon.
- Removed leftover invalid `mipmap-{density}-night` directories.

### Status
Uninstall/reinstall may be required on Samsung to bust the launcher icon cache.

## 2026-08-19 — Brand assets: keep SVG+PNG, drop identical dark copies

### Context
Review against Apple / Google / PWA rules: SVGs and platform PNGs are not interchangeable. After the gradient became the one launcher look, several dark/night/store/web/launch files were byte-identical duplicates.

### Done
- **Kept:** in-app [`assets/brand/*.svg`](../assets/brand/) (cropped viewBox), [`brand/masters/`](../brand/masters/) (1024 artboard + both adaptive PNG masters), [`assets/brand/background.png`](../assets/brand/background.png), store `appstore.png` + `playstore.png`, iOS `AppIcon-dark.png` + `AppIcon-tinted.png`, Android `ic_launcher_monochrome.xml`, night splash XML (`drawable-night/`, `drawable-night-v21/`).
- **Deleted identical copies:** `brand/store/*-dark.png`, unused `web/icons/Icon-*-dark.png`, `mipmap-night-*` and leftover invalid `mipmap-*-night`, `drawable-night-*dpi/ic_launcher_*`, iOS `LaunchLogo-dark*` / `LaunchBackground-dark.png`, Flutter leftover [`ios/Runner/Assets.xcassets/LaunchImage.imageset/`](../ios/Runner/Assets.xcassets/).
- [`tool/generate_brand_icons.py`](../tool/generate_brand_icons.py) no longer emits those duplicates.

### Architecture / decisions
One home-screen icon (white D on designed gradient). Two SVG colorways stay for in-app light/dark UI only. Do not merge UI SVGs with master SVGs.

### Status
Store upload remains one 1024 App Store PNG and one 512 Play PNG. No Icon Composer / Liquid Glass in this pass.

## 2026-08-19 — Restore designed launcher mark scale

### Context
The home-screen D looked oversized. The generator had cropped the designed adaptive foreground and scaled the glyph to 55% of the canvas (full-bleed at 40%). The master already has the correct size (~26% of 1024, inside Android’s 66% safe zone).

### Done
- [`tool/generate_brand_icons.py`](../tool/generate_brand_icons.py) now resizes [`brand/masters/adaptive_foreground_on_dark.png`](../brand/masters/adaptive_foreground_on_dark.png) onto the gradient as-is — no crop, no enlarge.
- Regenerated Android adaptive/mipmap, iOS App Icon, store, web, splash, and desktop rasters at that designed scale.

### Architecture / decisions
The designed 1024 foreground is the source of truth for launcher glyph size. Do not retune `GLYPH_FRAC`.

### Ops / verification
Adaptive xxxhdpi foreground glyph frac ~0.27 (was 0.55). App Store 1024 remains opaque (`hasAlpha: no`).

### Status
Uninstall/reinstall may be required on Samsung to bust the launcher icon cache.

## 2026-08-20 — Stage 4.6 Gmail SMTP owner-ops

### Context
Owner minted 2SV + App Password on a dedicated sender mailbox and created Secret Manager secret `gmail-smtp-app-password` on contest project `daftar-closing-agent`. Remaining §4.6 work was secret-level IAM, non-secret Cloud Run env (password not in env), local STARTTLS smoke (`250` + unique `Message-ID` + tiny PDF), and the explicit skip row. §4.7 send-batch application code was not started.

### Done
- Secret-level IAM: `roles/secretmanager.secretAccessor` on `gmail-smtp-app-password` for `agent-runner@daftar-closing-agent.iam.gserviceaccount.com` only. No webhook SA exists; none was bound. Secret resource policy members = that SA only (project-level Gate 0 bindings still inherit).
- Cloud Run `daftar-closing-agent` (`us-central1`) revision `daftar-closing-agent-00032-t9r`: `--update-env-vars` added `GMAIL_SMTP_USER` / `GMAIL_SMTP_FROM` (same dedicated sender), `GMAIL_SMTP_HOST=smtp.gmail.com`, `GMAIL_SMTP_PORT=587`. **No** `--update-secrets` (mount is §4.7). Vertex env preserved. Cost lock still min 0 / max 2. Runtime SA still `agent-runner`.
- Local smoke script [`agent/scripts/smoke_4_6_smtp.py`](../agent/scripts/smoke_4_6_smtp.py): stdlib `smtplib` + `EmailMessage`; App Password via `gcloud secrets versions access latest` (never printed / never in evidence). One owned To (env `GMAIL_SMTP_TO` only). Evidence under gitignored `agent/smoke_evidence/`.
- Smoke result: STARTTLS `smtp.gmail.com:587`, AUTH App Password, SMTP **`250`**, `Message-ID` `<178724901056.6403.3053504722292737247.42eb7d603c5c4a8f848611d3c306d4ec@gmail.com>`, attachment `daftar-smoke.pdf` (580 bytes), `toMasked=***odes@gmail.com`.
- §4.6 checkboxes in [`docs/roadmap_v2.md`](roadmap_v2.md) marked complete. Explicit skip (not Gate 4): Gmail API OAuth / restricted-scope verification, Workspace SMTP relay, custom-domain DKIM/SPF/DMARC, Resend / Brevo / SES, Meta WABA.

### Architecture / decisions
- App Password lives only in Secret Manager. Cloud Run env is non-secret From/user/host/port. Secret mount deferred to §4.7.
- Live From/To addresses are not written in the roadmap. Smoke To is env-only.
- Inherited project IAM (owner + default compute `roles/editor`) is unchanged Gate 0 posture; §4.6 grant on this secret is agent-runner only.

### Ops / verification
```bash
gcloud secrets add-iam-policy-binding gmail-smtp-app-password \
  --project=daftar-closing-agent \
  --member='serviceAccount:agent-runner@daftar-closing-agent.iam.gserviceaccount.com' \
  --role='roles/secretmanager.secretAccessor'
gcloud secrets get-iam-policy gmail-smtp-app-password --project=daftar-closing-agent
# → secretAccessor: agent-runner only

gcloud run services update daftar-closing-agent \
  --project=daftar-closing-agent --region=us-central1 \
  --min=0 --max=2 --min-instances=0 --max-instances=2 \
  --update-env-vars=GMAIL_SMTP_USER=…,GMAIL_SMTP_FROM=…,GMAIL_SMTP_HOST=smtp.gmail.com,GMAIL_SMTP_PORT=587
# revision daftar-closing-agent-00032-t9r; scale Min 0 / Max 2; no App Password in env

GMAIL_SMTP_USER=… GMAIL_SMTP_FROM=… GMAIL_SMTP_TO=… \
  python3 agent/scripts/smoke_4_6_smtp.py
# smtpCode=250 pass=True
```

Owner: confirm `daftar-smoke.pdf` is visible in the contest inbox (subject `Daftar §4.6 SMTP smoke`). SMTP `250` is accept, not a delivery webhook.

### Status
§4.6 complete. Next is §4.7 Cloud Run `POST /v1/email/send-batch` (mount secret; do not start §4.8 SMTP until this smoke stays green).

## 2026-08-20 — Stage 4.7 Cloud Run `POST /v1/email/send-batch`

### Context
§4.6 SMTP `250` and secret `gmail-smtp-app-password` were green. This slice adds deterministic FastAPI send-batch on the existing authenticated agent Cloud Run service (beside ADK `/run`). No Flutter / schema 23 / Gate 4 / Stage 5.

### Done
- Custom FastAPI: [`agent/main.py`](../agent/main.py) (`get_fast_api_app(agents_dir=…, web=False)` + email router), [`agent/Dockerfile`](../agent/Dockerfile), root [`agent/requirements.txt`](../agent/requirements.txt) (`google-adk==1.14.0`). Container copies `closing_agent` to `/app/adk_apps` so `GET /list-apps` stays `["closing_agent"]`.
- J.7 handler in [`agent/email_send/`](../agent/email_send/): multipart manifest + `pdf_{contactId}`, Appendix C.2 body assembly (no LLM `body`, no `amountMinor`), stdlib `EmailMessage` + `smtplib` STARTTLS 587 (465 only if connect/STARTTLS fails), App Password from mounted file `/secrets/gmail-smtp-app-password`, process-local idempotency, `event=daftar.agent.email` logs, 535 → `needsHuman` and no further SMTP.
- OpenAPI 2.3.0 path `POST /v1/email/send-batch` (tag `email-send`, `GoogleIdToken`). README: `gcloud run deploy --source` (do **not** `adk deploy` — it would wipe `main.py`), secret file mount, cost locks, do not print mailbox.
- Pytest (mock SMTP): 98 passed in `agent/tests/` including cap 5 → 400, unique Message-ID, From=user, one To, idempotency skip, >5 MB / missing PDF row `failed`, secret/PDF not in logs, C.2 EN/AR fixtures, 535 halt.
- Deploy: service `daftar-closing-agent` revision **`daftar-closing-agent-00036-4hz`** (`us-central1`). `--no-allow-unauthenticated`, min 0 / max 2 both layers, SA `agent-runner`, Vertex env preserved, `--update-secrets=/secrets/gmail-smtp-app-password=gmail-smtp-app-password:latest`. Custom-audience count stayed **3**. Invoker still `allAuthenticatedUsers` + `user:akrm.codes@gmail.com` (no `allUsers`).
- Smoke [`agent/scripts/smoke_4_7_send_batch.py`](../agent/scripts/smoke_4_7_send_batch.py): authenticated POST, `status=sent`, `smtpCode=250`, `smtpMessageId=<178725328156.1.117812002957067955.b969eaac93f642318a8cda356f54310e@gmail.com>`, `toMasked=***ents@gmail.com`, `needsHuman=false`. Cloud Logging `jsonPayload.event="daftar.agent.email"` (smtpCode 250, masked recipient). Evidence gitignored under `agent/smoke_evidence/`.
- §4.7 checkboxes in [`docs/roadmap_v2.md`](roadmap_v2.md) marked complete. **Not** ticked: Gate 4, §4.8–4.11, Stage 5.

### Architecture / decisions
- Auth remains Cloud Run IAM + J.1 custom audiences at the GFE. No second in-process JWT check. Shared-secret fallback still unimplemented.
- Idempotency is process-local (min 0 drops it). Durable SoT is Drift in §4.8.
- Live From/To addresses are not written here. Smoke To was the dedicated sender mailbox (env-only).
- Harmless extra unmounted secret volume name exists beside the `/secrets` mount; file path is `/secrets/gmail-smtp-app-password`.

### Ops / verification
```bash
cd agent
gcloud run deploy daftar-closing-agent --source=. --project=daftar-closing-agent --region=us-central1 \
  --quiet --no-allow-unauthenticated --min=0 --max=2 --min-instances=0 --max-instances=2 --port=8000 \
  --service-account=agent-runner@daftar-closing-agent.iam.gserviceaccount.com \
  --update-env-vars=GOOGLE_GENAI_USE_VERTEXAI=TRUE,GOOGLE_CLOUD_PROJECT=daftar-closing-agent,GOOGLE_CLOUD_LOCATION=global,GMAIL_SMTP_USER=…,GMAIL_SMTP_FROM=…,GMAIL_SMTP_HOST=smtp.gmail.com,GMAIL_SMTP_PORT=587 \
  --update-secrets=/secrets/gmail-smtp-app-password=gmail-smtp-app-password:latest
# revision daftar-closing-agent-00036-4hz; scale Min 0 / Max 2; audience_count=3

curl -sS -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  https://daftar-closing-agent-1487285471.us-central1.run.app/list-apps
# → ["closing_agent"]

GMAIL_SMTP_TO=… python3 scripts/smoke_4_7_send_batch.py
# http=200 status=sent smtpCode=250 logOk=True pass=True
```

Owner: confirm the smoke PDF is visible in the contest inbox (subject `Daftar: outstanding balance 500 YER`). SMTP `250` is accept, not a delivery webhook.

### Status
§4.7 complete. Next is §4.8 device one-Approve + schema 23 (`contacts.email`, `DispatchCollectionsEmailUseCase`). Do not start Gate 4 filming until §4.8–4.11 land.

## 2026-08-20 — Stage 4.8 Device one-Approve + schema 23

### Context
§4.7 send-batch is live on Cloud Run. This slice is Flutter + Drift only: schema 23 (`contacts.email` + SMTP queue fields), C.2-aligned on-device drafts, and one Khazna Approve path that builds statement PDFs then calls `POST /v1/email/send-batch`. Hybrid E / `wa.me` stays in the tree but is not the lead.

### Done
- Schema **23**: [`DbConstants.schemaVersion`](../lib/core/constants/db_constants.dart) and [`DriveBackupConstants.schemaVersion`](../lib/domain/constants/drive_backup_constants.dart) bumped together. [`drift_database.dart`](../lib/data/datasources/local/drift_database.dart) `onUpgrade from < 23` adds nullable `contacts.email` + `idx_contacts_email`, queue header `batchId`, item `email` / `subject` / `smtpMessageId` / `smtpCode`. Item statuses include `sending` | `sent` | `failed` (keep `opened` for Hybrid E). Spec examples in [`BACKUP_SPEC.md`](architecture/BACKUP_SPEC.md) and [`GOOGLE_DRIVE_SYNC_SPEC.md`](architecture/GOOGLE_DRIVE_SYNC_SPEC.md).
- Email threaded through Freezed [`Contact`](../lib/domain/entities/contact.dart), [`ContactModel`](../lib/data/models/contact_model.dart), mapper, create/update UCs ([`contact_email.dart`](../lib/domain/constants/contact_email.dart) — empty OK, plus-aliases OK, invalid → `ValidationFailure` `contact_email_invalid`), add/edit sheets, merge-engine LWW next to `phone`. Eligible shortlist query in [`contact_local_ds.dart`](../lib/data/datasources/local/contact_local_ds.dart) is non-empty **email**, not phone.
- C.2 composer 1:1 with Cloud Run [`c2_body.py`](../agent/email_send/c2_body.py): [`collections_reminder_draft_composer.dart`](../lib/domain/constants/collections_reminder_draft_composer.dart) + [`ComposeCollectionsReminderDraftUseCase`](../lib/application/agent/compose_collections_reminder_draft_use_case.dart). Desk preview uses those subject/body/named params. Integer `amount_line` (`500 YER` / `500 ر.ي`).
- [`DispatchCollectionsEmailUseCase`](../lib/application/agent/dispatch_collections_email_use_case.dart): cap 5; missing/invalid `to` or attach off → row `failed`; `PrepareContactStatementUseCase` + [`CollectionsStatementPdfRenderer`](../lib/application/agent/collections_statement_pdf_renderer.dart) (presentation [`DeviceCollectionsStatementPdfRenderer`](../lib/presentation/providers/device_collections_statement_pdf_renderer.dart) wraps `PdfGenerator`); PDF >5 MB (`ClosingAgentConstants.maxPdfBytes`) or timeout → row `failed`. One Dio multipart J.7 on [`ClosingAgentRemoteDs.sendEmailBatch`](../lib/data/datasources/remote/closing_agent_remote_ds.dart) — no JSON `Content-Type`, never App Password. `sent` only if `status==sent` + `smtpCode==250` + non-empty `smtpMessageId`. `skippedDuplicate` treated as sent. `needsHuman` → `AuthFailure` `smtp_needs_human`. Airplane/Dio → `NetworkFailure`; do not mark sent. Providers call the UC only (`dispatchCollectionsEmailUseCaseProvider`).
- UX: empty overdue/email shortlist → existing report, no SMTP. Non-empty → Collections Desk immediately (skip Yes/all-20 and Attach prompts). Force `top5` + `allInSet` (attach **on**). Lead CTAs **Skip outreach** | **Approve & send Top 5** (`DaftarButton` primary = monochrome + glow). Approve does not open `wa.me` / share-sheet. SMTP queues persist `batchId` so hydrate does not raise the Hybrid E sticky bar. Skip outreach marks remaining pending `skipped`, no SMTP.
- Report: [`CollectionsQueueMetrics`](../lib/domain/value_objects/collections_queue_metrics.dart) `prepared` / `sent` / `failed` / `skipped`; **opened ≠ sent**. [`closing_ritual_report_card.dart`](../lib/presentation/screens/closing_agent/widgets/closing_ritual_report_card.dart) shows sent/failed; opened only if leftover Hybrid E `opened > 0`.
- ARB EN+AR: Approve & send Top 5, Skip outreach, Sending…, PDF attached, contact email hint/validation, SMTP/auth/network via `ErrorTranslator`. `flutter gen-l10n`.
- Roadmap: **§4.8 only** ticked. §4.9–4.11, Gate 4, Stage 5 left open.

### Architecture / decisions
- Domain stays Flutter-free: PDF isolate lives behind `CollectionsStatementPdfRenderer`.
- SMTP persist uses `CollectionsSendQueueStatus.completed` + non-null `batchId`; Hybrid E leftover restore only when `batchId` is null.
- `UpdateContactParams.updateEmail` so archived-guard / partial updates do not wipe email.
- Out of slice: Cloud Run, `adk deploy`, §4.9 leftover filming checkboxes, §4.10 gitignored email seed, Gate 4 five-inbox film, HUD, Stage 5.

### Ops / verification
```
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter test \
  test/domain/constants/collections_reminder_draft_composer_test.dart \
  test/application/agent/dispatch_collections_email_use_case_test.dart \
  test/application/agent/build_collections_desk_use_case_test.dart \
  test/data/repositories/agent_schema_v19_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart \
  test/presentation/screens/closing_agent/widgets/collections_desk_panel_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_ritual_report_card_test.dart \
  test/application/contact/contact_use_cases_test.dart \
  test/application/contact/get_collections_candidates_use_case_test.dart \
  test/data/merge_engine_test.dart
```
Focused suites passed (C.2 fixtures, dispatch folds, schema 23 email round-trip, Approve metrics, Skip outreach no dispatch, merge LWW).

### Status
§4.8 complete. Next is §4.9 leftover filming rules (not the lead), then §4.10 demo email seed overlay. Do not start Gate 4 filming until §4.8–4.11 land.

## 2026-08-20 — Stage 4.9 Hybrid E leftover (not the lead)

### Context
Official `wa.me` is text-only and cannot attach a PDF. After §4.8 made SMTP MIME the Approve lead, leftover Hybrid E (`wa.me` + share-sheet + sticky bar) had to stay in the tree without being Approve success, the missing-email fallback, or SMTP sticky resume.

### Done
- [`lib/data/datasources/local/collections_send_queue_local_ds.dart`](lib/data/datasources/local/collections_send_queue_local_ds.dart) `getInFlight` now requires `batchId IS NULL` so a mis-saved SMTP `active` header cannot restore Sending i of N ([`lib/domain/repositories/collections_send_queue_repository.dart`](lib/domain/repositories/collections_send_queue_repository.dart) comment)
- [`ClosingAgentController._persistSmtpQueue`](lib/presentation/providers/closing_agent_controller.dart) sets in-memory `queueStatus: completed` so `isQueueInFlight` stays false if `collectionsBatchId` is later cleared
- Desk leftover Open / Skip / tone / attach disabled while `collectionsDispatching` via `leftoverActionsEnabled` on [`collections_desk_row.dart`](lib/presentation/screens/closing_agent/widgets/collections_desk_row.dart) / [`collections_desk_panel.dart`](lib/presentation/screens/closing_agent/widgets/collections_desk_panel.dart)
- Checkbox-mapped tests in controller, dispatch UC, queue DS, panel, row. Hybrid E `opened` / sticky tests kept compiling
- [`docs/roadmap_v2.md`](docs/roadmap_v2.md) §4.9 ticked only. Leftover comments: not the filmed climax, not the missing-email fallback

### Architecture / decisions
- Do not delete Hybrid E. Do not auto-open. Do not film. Approve never calls `openDeskRow` / `WhatsAppUtil` / share-sheet
- Missing/invalid email stays `failed`, never leftover Open
- Out of slice: §4.10 seed overlay, Gate 4, HUD, Stage 5, Cloud Run, `contest_demo.md`

### Ops / verification
```
flutter test \
  test/presentation/providers/closing_agent_controller_test.dart \
  test/application/agent/dispatch_collections_email_use_case_test.dart \
  test/data/repositories/collections_send_queue_repository_test.dart \
  test/presentation/screens/closing_agent/widgets/collections_desk_panel_test.dart \
  test/presentation/screens/closing_agent/widgets/collections_desk_row_test.dart
```

### Status
§4.9 complete. Next is §4.10 demo email seed overlay. Do not start Gate 4 filming until §4.10–4.11 land.

## 2026-08-20 — Roadmap v2.8 ranked send vs statement PDF

### Context
Owner rejected “email only five, leave the rest without service.” Cap 5 on **who is emailed** was a Meta To-list leftover. The close should email the overdue set and attach statements only for ranked Top 5 so the agent looks like it is triaging, not mail-merging. This pass is **roadmap-only** (plus this log). No Dart, Python, ARB, `contest_demo.md`, or `CONTEST_DISCLOSURE.md` edits.

### Done
- [`docs/roadmap_v2.md`](roadmap_v2.md) bumped to **v2.8** (2026-08-20). Headline, changelog, identity non-goals, MCP, pivots, Chapter 3–4, topology, schema-today **23**, as-of notes, Stage 4 goal/bans, Appendices B/C.2/D/F/G/H/I/**J.7**, footer.
- Remaining slice **§4.13 Ranked split** inserted after §4.9 (before §4.10). Live J.7: send cap **≤20**, PDF part **optional**.
- §4.10 retargeted to seed emails for **all filmed send-set contacts** (demo **10** desk-eligible). §4.11 + Gate 4 retargeted (Must: ≥1 PDF inbox; Should: five statement inboxes **and** ≥1 text-only inbox).
- [`docs/contest_demo.md`](contest_demo.md) / [`docs/CONTEST_DISCLOSURE.md`](CONTEST_DISCLOSURE.md) marked **stale vs v2.8** until Stage 6.

### Architecture / decisions
- **Send set** = aged overdue ∩ valid email, `min(shortlist, 20)`. **Statement set** = ranked Top 5 of that set (Appendix D). Remainder = C.2 text only; missing PDF is **not** `failed`.
- Who decides: **device aging**, not Gemini. No ADK send tool. No LLM-authored bodies. Plan **narrates** the split.
- Safety cap **20** (not Gmail 500/day, not unbounded). Demo seed is 10. Not the old unranked Yes/all-20 blast.
- §4.6–4.9 stay `[x]` as landed **v2.7** semantics (cap 5, PDF required). Overlay states landed code does **not** yet implement the split. **No schema bump** (`attachPdf` already per-row).
- Non-goals: send `>20`; PDF beyond ranked Top 5 on the close path; LLM chooses who gets a statement.

### Ops / verification
Checkbox audit (this pass):
- §4.6–4.9 remain `[x]`
- §4.13, §4.10, §4.11, Gate 4 remain `[ ]`
- Stage 5 / HUD still **do not start until Gate 4**
- No live From/To, E.164s, or App Passwords written in the roadmap or this log

### Status
Roadmap v2.8 is the binding contract. Next is **implement §4.13** (J.7 optional PDF + cap 20, device send set, dispatch must not fail `!attachPdf`), then §4.10 seed. **Not this pass.** Do not start Gate 4 film or Stage 5 until §4.13 + §4.10–4.11 land.

## 2026-08-21 — Stage 4.13 Ranked split (send set vs statement PDF)

### Context
v2.8 live contract: email the send set (`min(shortlist, 20)`), attach MIME PDFs only on ranked Top 5, remainder C.2 text-only. Landed §4.7–4.8 stayed `[x]` as v2.7 (cap 5, PDF required). This slice makes J.7 + desk/dispatch match the split. Official `wa.me` cannot attach PDF; Hybrid E leftover stays in tree.

### Done
- J.7 Cloud Run: [`agent/email_send/schemas.py`](agent/email_send/schemas.py) `MAX_RECIPIENTS = 20`; [`router.py`](agent/email_send/router.py) missing `pdf_{contactId}` → text-only SMTP (not `missing_pdf`); present PDF `>5 MB` still `failed`; `filename` optional. [`smtp_client.py`](agent/email_send/smtp_client.py) skips attachment when bytes absent (`text/plain`). OpenAPI maxItems 20.
- Device send set: [`ClosingRitualResult.reminderSet`](lib/domain/value_objects/closing_ritual_result.dart) for `all` = `shortlist.take(20)`. New `ClosingPdfPolicy.rankedTop5` (no schema bump). Controller opens desk with `all` + `rankedTop5` (does **not** force `top5` / `allInSet`).
- [`DispatchCollectionsEmailUseCase`](lib/application/agent/dispatch_collections_email_use_case.dart) cap 20; `!attachPdf` still send-batch without PDF bytes.
- Desk: statement vs reminder-only before Approve; Approve CTA **Approve & send** (EN+AR). Plan card ARB + ADK `INSTRUCTION` narrate the split; Gemini does not pick IDs.
- Redeploy `daftar-closing-agent` **not** `adk deploy`: source deploy revision `daftar-closing-agent-00037-bpq`, scale lock serving **`daftar-closing-agent-00038-rqc`**. URL unchanged. Custom-audience count **3**. Min 0 / max 2 both layers. Secret mount `/secrets`. **No** `allUsers`. Gmail From/user env left in place (not printed).

### Architecture / decisions
- Send set vs statement set is device aging (Appendix D), not an ADK send tool.
- Missing PDF part is **sent** text-only. Invalid `to` remains `failed`. Unique `Message-ID` per SMTP transaction (Gmail `421 4.7.28` on duplicates).
- Schema **23** unchanged. Hybrid E leftover (`wa.me` / share-sheet / sticky) retained; not the filmed climax.
- Out of slice: §4.10 seed overlay, §4.11 Gate 4 film list, HUD, Stage 5, `contest_demo.md`.

### Ops / verification
```
# Flutter (focused) + leftover Hybrid E: all passed
# Agent: 101 passed in agent/tests/
gcloud run services describe daftar-closing-agent \
  --project=daftar-closing-agent --region=us-central1
# Scaling: Min 0 / Max 2; latestReadyRevisionName: daftar-closing-agent-00038-rqc
```

### Status
§4.13 complete. Next is **§4.10** demo email seed overlay, then §4.11 + Gate 4. Do not start Gate 4 film or Stage 5 until §4.10–4.11 land.

## 2026-08-21 — Stage 4.10 Demo seed = emails

### Context
Desk eligibility is non-empty `contacts.email` ∩ overdue. The contest seeder still wrote phones only, so a seeded close produced an empty send set. §4.10 seeds emails on all **10** filmed desk-eligible contacts without committing live To: addresses.

### Done
- Resolver [`lib/core/utils/demo_seed_emails.dart`](lib/core/utils/demo_seed_emails.dart): ten `String.fromEnvironment('DAFTAR_SEED_EMAIL_<ascii>')` with RFC 2606 `demo+{tag}@example.com` defaults; empty/invalid falls back to placeholder; never logs addresses.
- [`DevDatabaseSeeder._buildContacts`](lib/core/utils/dev_database_seeder.dart) writes `DemoSeedEmails.forName`; فاطمة الحميدي and جار التسوية stay `email: null`; phones unchanged; names/store unchanged (`محمد علي`, `محل الغانم`). [`docs/contest_demo.md`](docs/contest_demo.md) **not** edited.
- Overlay: committed [`tool/demo_seed_emails.example.json`](tool/demo_seed_emails.example.json) + [`tool/demo_seed_emails.md`](tool/demo_seed_emails.md); gitignored `tool/demo_seed_emails.local.json` (plus-aliases, two inboxes: statement-ranked vs text-only remainder). Gate 4: `flutter run --dart-define-from-file=tool/demo_seed_emails.local.json`.
- Stage 6 copy-then: [`docs/qa/smtp_proof_readme_note.md`](docs/qa/smtp_proof_readme_note.md) (judges may score from video; SMTP `250` = accept not mailbox-delivered; inbox + PDF is Proof of Action; text-only remainder intentional; Hybrid E leftover). Pointer in [`docs/qa/README.md`](docs/qa/README.md).
- Tests: [`test/core/utils/demo_seed_emails_test.dart`](test/core/utils/demo_seed_emails_test.dart); seeder asserts 10 overdue ∩ email, `@example.com` placeholders in CI, Fatima/settled have no email.

### Architecture / decisions
- Device seed cannot read a repo JSON at runtime; dart-define compiles the overlay into the debug APK. CI / IDE without the local file keeps placeholders (safe).
- Overlay keys by ASCII tag, not rank. PDF vs text is still `ClosingPdfPolicy.rankedTop5` at close. Current seed Top 5 by age then owed: ليلى، سالم، نادية، عمر، هند. Mid-day Mohamed 500 does not change that set. Remap the local overlay if the txn mix changes.
- Schema **23** unchanged. No live emails or E.164s in the roadmap, example JSON, this log, or tests.

### Ops / verification
```
flutter test test/core/utils/dev_database_seeder_test.dart test/core/utils/demo_seed_emails_test.dart
git check-ignore -v tool/demo_seed_emails.local.json
```

### Status
§4.10 complete. Next is **§4.11** + Gate 4 device film. Do not start Stage 5 until Gate 4.

## 2026-08-21 — Stage 4.11 automated tests + §4.12 verify

### Context
§4.13 already covered most of the send-batch / Flutter §4.11 list. This pass filled the real gaps (SMTP stagger, Approve metrics on a send set larger than Top 5, client secret scan), locked §4.12 retired, and wrote the owner Gate 4 runbook. Device film is **not** this pass.

### Done
- Agent: [`test_stagger_sleeps_between_smtp_attempts`](agent/tests/test_email_send_batch.py) — `GMAIL_SMTP_STAGGER_SEC=1.0`, monkeypatch `asyncio.sleep`, one sleep between two text-only SMTP rows; harness still defaults stagger to `0`. Existing cap-20 / optional PDF / `250` / idempotency / Message-ID / secret / 5 MB / From==user / one-To cases remain.
- Flutter: controller `Approve send-set metrics cover all 8 rows not Top 5 only` in [`closing_agent_controller_test.dart`](test/presentation/providers/closing_agent_controller_test.dart) (`sent: 8`, `opened: 0`). [`test/core/security/flutter_smtp_secret_scan_test.dart`](test/core/security/flutter_smtp_secret_scan_test.dart) scans `lib/` for `GMAIL_SMTP_PASSWORD` / `smtp-app-password` / `gmail-smtp-app-password`.
- §4.12 lock: [`agent/tests/test_retired_webhooks.py`](agent/tests/test_retired_webhooks.py) — no webhook/whatsapp path on J.7 router or OpenAPI; forbidden `daftar.agent.whatsapp.status` / `daftar-wa-webhooks` / `/v1/whatsapp` absent from `email_send/` and `closing_agent/`. Hybrid E `propose_whatsapp_drafts` retained.
- Owner film: [`docs/qa/gate4_device_runbook.md`](docs/qa/gate4_device_runbook.md) + pointer in [`docs/qa/README.md`](docs/qa/README.md). No live To: / E.164s.

### Architecture / decisions
- §4.11 Manual Gate 4 and Stage 4 Validation Gate stay `[ ]` until inbox + PDF and `daftar.agent.email` (`250` + `Message-ID`) are on camera.
- §4.12 remains prose-only retired. No second Cloud Run. No `allUsers`. Proof stays SMTP accept + inbox, not a fake `delivered` webhook.
- Schema **23** unchanged. `contest_demo.md` not edited.

### Ops / verification
```
cd agent && python -m pytest tests/test_email_send_batch.py tests/test_retired_webhooks.py -q
# 23 passed
flutter test test/presentation/providers/closing_agent_controller_test.dart \
  test/core/security/flutter_smtp_secret_scan_test.dart \
  test/application/agent/dispatch_collections_email_use_case_test.dart \
  test/domain/constants/collections_reminder_draft_composer_test.dart \
  test/application/agent/build_collections_desk_use_case_test.dart \
  test/data/repositories/agent_schema_v19_test.dart \
  test/data/repositories/collections_send_queue_repository_test.dart
# 54 passed
gcloud run services list --project=daftar-closing-agent --region=us-central1
# names: daftar-closing-agent only (no daftar-wa-webhooks)
gcloud run services get-iam-policy daftar-closing-agent \
  --project=daftar-closing-agent --region=us-central1
# invoker: allAuthenticatedUsers + user (no allUsers)
```

### Status
§4.11 automated boxes complete. Next is **owner Gate 4 film** ([`docs/qa/gate4_device_runbook.md`](docs/qa/gate4_device_runbook.md)). Do not start Stage 5 until the Validation Gate is green.

## 2026-08-21 — Stage 4 close-path polish (before Gate 4 film)

### Context
A week-old five-gap memo described **v2.7 Hybrid E**. Live law is v2.8: one plan confirm → device ritual → **Approve & send** Gmail SMTP. This pass fixes what is still true on camera (WhatsApp copy, leftover desk chrome, unnamed device workflow, stale shot list). It does **not** reopen locked bans (LLM email bodies, silent send, HUD before Gate 4).

### Five-gap verdict

| Gap | Still valid? | What we did |
| --- | --- | --- |
| 1. Mid-ritual hand-holding | Partially | Lead path already skipped Yes / Top 5 / PDF prompts. Desk no longer paints Open WhatsApp, tone pickers, attach switches, or the Hybrid E sticky. Model C plan confirm stays. |
| 2. Agent didn’t write drafts | Invalid to “fix” with Gemini | Hard ban: LLM email bodies. Device C.2 composer is the contract. ADK copy now speaks **email**, not WhatsApp. `propose_whatsapp_drafts` unused on close. |
| 3. Not event-driven | Invalid to add cron | “سكر اليوم” is the close event. Documented in instruction only. No background closer. |
| 4. Not a durable workflow | Mostly already true, unnamed | Named `ClosingAgentPhase` as the device state machine (Drift; survives Cloud Run scale-to-zero). Plan-card ARB. No HUD. |
| 5. Demo doesn’t prove GCP | Owner film + Stage 5 | Gate 4 / Validation Gate stay `[ ]`. Runbook unchanged at [`docs/qa/gate4_device_runbook.md`](qa/gate4_device_runbook.md). |

### Done
- ADK [`agent/closing_agent/agent.py`](../agent/closing_agent/agent.py) `INSTRUCTION`: never claim ledger write **or email send**; money on confirm; outreach on device **Approve & send** (Gmail SMTP); Hybrid E `wa.me` leftover; close is the merchant utterance, not cron. Tests in [`agent/tests/test_agent_instruction.py`](../agent/tests/test_agent_instruction.py).
- SMTP Collections Desk: `showHybridELeftover` default **false** on [`collections_desk_row.dart`](../lib/presentation/screens/closing_agent/widgets/collections_desk_row.dart) / [`collections_desk_panel.dart`](../lib/presentation/screens/closing_agent/widgets/collections_desk_panel.dart). Lead screen wires `false`. Leftover=true keeps Open WhatsApp / tone / attach / sticky for existing tests.
- [`closing_ritual_panel.dart`](../lib/presentation/screens/closing_agent/widgets/closing_ritual_panel.dart) no longer renders Yes / Top 5 / PDF prompts. Widget files + `chooseReminderPolicy` kept.
- [`ClosingAgentPhase`](../lib/presentation/providers/closing_agent_state.dart) named as durable device workflow. Plan card [`closingAgentPlanDeviceRuns`](../lib/core/l10n/app_en.arb) EN+AR: Gemini plans; device commits (summary → backup → aging → email).
- [`docs/contest_demo.md`](contest_demo.md) v2.8 banner; shot list films Approve & send + inbox PDF + text-only + Console `daftar.agent.email`; seed `flutter run --dart-define-from-file=tool/demo_seed_emails.local.json`. Names/store unchanged (`محمد علي`, `محل الغانم`).
- Redeploy `daftar-closing-agent` **not** `adk deploy`: revision **`daftar-closing-agent-00039-n6r`**. URL unchanged. Audience count **3**. Min 0 / max 2 both layers. Secret mount `/secrets`. Invoker `allAuthenticatedUsers` + user. **No** `allUsers`. Gmail From/user env left in place (not printed).

### Architecture / decisions
- WhatsApp remains on contact-detail / settings-support / Pro+ marketing — not the close ritual.
- Hybrid E stays in the tree. Disabled WhatsApp is still visible; hiding was required, not `onPressed: null`.
- Device owns C.2 drafts. No send-email ADK tool. SMTP `batchId` queues are not Hybrid E hydrate. HUD is §5.6 Stage 5.
- Out of slice: Stage 5 speech/HUD/onboarding, Gate 4 device film, schema bump, new ADK send tool, deleting Hybrid E, live emails in git.

### Ops / verification
```
cd agent && python -m pytest tests/test_agent_instruction.py tests/test_email_send_batch.py tests/test_retired_webhooks.py -q
# 30 passed
flutter test test/presentation/screens/closing_agent/widgets/collections_desk_row_test.dart \
  test/presentation/screens/closing_agent/widgets/collections_desk_panel_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_plan_checklist_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_ritual_reminder_prompt_test.dart
# 35 passed
gcloud run services describe daftar-closing-agent \
  --project=daftar-closing-agent --region=us-central1
# Scaling: Min 0 / Max 2; latestReadyRevisionName: daftar-closing-agent-00039-n6r
# audience_count=3; invoker allAuthenticatedUsers + user (no allUsers)
curl -sS -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  https://daftar-closing-agent-1487285471.us-central1.run.app/list-apps
# → ["closing_agent"]
```

### Status
Close-path polish complete. **Manual Gate 4 and Stage 4 Validation Gate stay `[ ]`.** Next is owner film per [`docs/qa/gate4_device_runbook.md`](qa/gate4_device_runbook.md). Do not start Stage 5 until that gate is green.

## 2026-08-21 — Stage 5.1 Option B speech

### Context
Implement Gate 2 Option B: hold-to-talk WAV on existing authenticated `POST /run` (Gemini 3.5 Flash audio in + same Appendix J proposals), on-device TTS for confirm read-back and the closing report, mic-permission ARB, and a mute-TTS setting. No Live API, Cloud STT, HUD, or coach/onboarding.

### Done
- ADK `INSTRUCTION` treats `inline:` audio / `newMessage` inlineData as the utterance; ignore `__voice__`; first narrative sentence is the verbatim transcript. OpenAPI `AdkContentPart` is text **or** `inlineData` (`mimeType` + base64). Pytest: `tests/test_agent_instruction.py`, `tests/test_adk_audio_run.py`.
- Device `/run`: [`AgentAudioClip`](../lib/domain/value_objects/agent_audio_clip.dart) on [`RunClosingAgentTurnUseCase`](../lib/application/agent/run_closing_agent_turn_use_case.dart); `goalText=__voice__`, `audioRef=inline:audio/wav`; parts are text + `inlineData`. Voice skips local ask; amount-snap uses narrative.
- Hold-to-talk: [`record`](https://pub.dev/packages/record) WAV 16 kHz mono, 20s cap; [`permission_handler`](https://pub.dev/packages/permission_handler); Android `RECORD_AUDIO` + TTS `queries`; iOS `NSMicrophoneUsageDescription` + `PERMISSION_MICROPHONE=1`. Denied → ARB + Open Settings; no `/run`. Short tap = “Hold to speak”.
- On-device TTS: [`flutter_tts`](https://pub.dev/packages/flutter_tts) (`ar-SA` / `en-US`) via [`DeviceTts`](../lib/core/utils/device_tts.dart) + [`ClosingReportSpeech.announce`](../lib/core/utils/closing_report_speech.dart). Confirm card speaks visible name/amount/goods. Fail-soft.
- Schema **24**: `ttsMuted` default false. [`DbConstants.schemaVersion`](../lib/core/constants/db_constants.dart) and [`DriveBackupConstants.schemaVersion`](../lib/domain/constants/drive_backup_constants.dart) bumped together. Preferences `GlowPillToggle`. No §5.4 coach columns.
- ARB EN+AR: hold hint, recording, permission denied, open settings, mute TTS. [`docs/roadmap_v2.md`](roadmap_v2.md) **§5.1 only** ticked. Stage 5.4 coach flags retargeted to schema **25**.

### Architecture / decisions
- Bytes never go in `daftarContext` (marker only). Output stays TEXT + function calls. TTS is on-device so confirm/report still work offline. Plugins stay out of domain/application.
- Not in this slice: Gemini Live, Cloud STT/TTS, HUD, FAB spotlight, onboarding, new ADK tools.

### Ops / verification
```bash
cd agent && python -m pytest tests/test_agent_instruction.py tests/test_adk_audio_run.py tests/test_proposal_tools.py -q
# 82 passed
flutter test test/application/agent/closing_agent_client_test.dart \
  test/core/utils/closing_report_speech_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_composer_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart
# 45 passed
# plus schema v24, confirm/report cards, constants (earlier batch, all passed)
gcloud run deploy daftar-closing-agent --source=. --project=daftar-closing-agent --region=us-central1 \
  --quiet --no-allow-unauthenticated --min=0 --max=2 --min-instances=0 --max-instances=2 --port=8000 \
  --service-account=agent-runner@daftar-closing-agent.iam.gserviceaccount.com \
  --update-secrets=/secrets/gmail-smtp-app-password=gmail-smtp-app-password:latest
# revision daftar-closing-agent-00040-2cm; audience_count=3; invoker allAuthenticatedUsers + user (no allUsers)
curl -sS -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  https://daftar-closing-agent-1487285471.us-central1.run.app/list-apps
# → ["closing_agent"]
```

### Status
§5.1 complete. **Gate 5, §5.2–5.6, and Manual Gate 4 stay `[ ]`.** Stage 4 Validation Gate remains `[x]`. Next: §5.2 polish / remaining Stage 5 after owner film if still needed.

## 2026-08-21 — Stage 5.1 TTS silence (narrative + engine)

### Context
Voice input on Closing Agent worked, but merchants never heard replies (typed or hold-to-talk). Gemini `/run` is TEXT-only; the visible `narrative` was never spoken, and `DeviceTts` failed soft without language fallback, volume, audio focus, or iOS session reclaim. Confirm `dispose` also called `DeviceTts.stop()`.

### Done
- Hardened [`lib/core/utils/device_tts.dart`](../lib/core/utils/device_tts.dart): serial speak lock, `ar-SA`/`ar`/`en-US` fallback, volume 1.0, Android `speak(focus: true)`, iOS shared instance + playback/`defaultToSpeaker`, retry when `speak` is not success, debug logs.
- Presentation speaks `turn.narrative` on ready in [`closing_agent_controller.dart`](../lib/presentation/providers/closing_agent_controller.dart) unless `ttsMuted`. New turns call `DeviceTts.stop()`.
- Removed `DeviceTts.stop()` from [`agent_confirm_card.dart`](../lib/presentation/screens/closing_agent/widgets/agent_confirm_card.dart) dispose; `ValueKey(proposal.proposalId)` on confirm tiles.
- Hold-to-talk [`voice_capture.dart`](../lib/core/utils/voice_capture.dart): `AndroidRecordConfig(manageBluetooth: false)`, `AudioInterruptionMode.none`.

### Architecture / decisions
Plugins stay in `lib/core` + presentation. Confirm UI remains source of truth. Mute still honored. Not Live API / Cloud TTS. **§5.2 not started.**

### Ops / verification
```bash
flutter test test/core/utils/device_tts_test.dart \
  test/core/utils/closing_report_speech_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_confirm_card_test.dart
# 56 passed
```

### Status
Silent-reply fix landed. **Gate 5 and §5.2–5.6 stay `[ ]`.** Device check: mute off, media volume up, Arabic TTS voice installed if the engine has no `ar*` tag.

## 2026-08-21 — Chirp 3 HD agent voice

### Context
On-device `flutter_tts` worked after the silence fix but still sounded like Google Translate. Neural2/Studio have no Arabic voices. Lock: unary Chirp 3 HD Kore on the existing Cloud Run service, with `flutter_tts` as the offline fail-soft. Not Gemini Live, not audio on `/run`, not a second service.

### Done
- Cloud Run `POST /v1/tts`: [`agent/tts/router.py`](../agent/tts/router.py) JSON `{text, locale: ar|en}` → `ar-XA-Chirp3-HD-Kore` / `en-US-Chirp3-HD-Kore`, MP3 `speaking_rate=0.95`, cap 2000 chars, empty → 400. Structured log `daftar.agent.tts` (`voice`, `locale`, `chars`, `latency_ms`) — never merchant text. ADC `TextToSpeechClient`; `google-cloud-texttospeech==2.31.0` in [`agent/requirements.txt`](../agent/requirements.txt). Wired in [`agent/main.py`](../agent/main.py) + [`agent/Dockerfile`](../agent/Dockerfile). OpenAPI 2.4.0 path in [`agent/openapi.yaml`](../agent/openapi.yaml).
- Device Clean Architecture: [`AgentSpeechClip`](../lib/domain/value_objects/agent_speech_clip.dart), [`AgentSpeechRepository`](../lib/domain/repositories/agent_speech_repository.dart), [`SynthesizeAgentSpeechUseCase`](../lib/application/agent/synthesize_agent_speech_use_case.dart), [`AgentSpeechRepositoryImpl`](../lib/data/repositories/agent_speech_repository_impl.dart) via existing [`ClosingAgentRemoteDs`](../lib/data/datasources/remote/closing_agent_remote_ds.dart) ID-token interceptor. Playback [`AgentSpeech`](../lib/core/utils/agent_speech.dart) (`just_audio` + `audio_session` playback after mic) with in-memory cache and serial queue; any cloud Left / offline → [`DeviceTts`](../lib/core/utils/device_tts.dart).
- Callers: controller narrative, Confirm read-back, closing report, new-turn/mic/pop stop — all [`AgentSpeech`](../lib/core/utils/agent_speech.dart). Mute unchanged. Confirm dispose still does not stop speech.
- `just_audio` + `audio_session` in [`pubspec.yaml`](../pubspec.yaml). No Drift schema bump.

### Architecture / decisions
- Same Cloud Run IAM + custom audiences as `/run` (no `allUsers`, no in-process JWT). Secrets stay off the phone.
- Kore is the locked speaker; swap name only (`Charon` / `Achernar`) if Arabic is weak on device — do not change APIs.
- `roles/cloudtts.user` is not grantable in this project catalog; `texttospeech.googleapis.com` is enabled and unary synthesize succeeded with the runtime SA ADC. `roles/speech.client` remains STT-only.
- **Not in this slice:** Gemini Live / `/run_sse`, synthesize inside `/run`, Neural2/Studio, HUD/coach, §5.2, Gate 5.

### Ops / verification
```bash
cd agent && /tmp/daftar-agent-venv/bin/python -m pytest tests/test_tts.py tests/test_retired_webhooks.py -q
# 12 passed
flutter test test/core/utils/agent_speech_test.dart \
  test/core/utils/device_tts_test.dart \
  test/core/utils/closing_report_speech_test.dart \
  test/application/agent/synthesize_agent_speech_use_case_test.dart \
  test/application/agent/closing_agent_client_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_confirm_card_test.dart
# 86 passed
gcloud run deploy daftar-closing-agent --source=. --project=daftar-closing-agent --region=us-central1 \
  --quiet --no-allow-unauthenticated --min=0 --max=2 --min-instances=0 --max-instances=2 --port=8000 \
  --service-account=agent-runner@daftar-closing-agent.iam.gserviceaccount.com \
  --update-secrets=/secrets/gmail-smtp-app-password=gmail-smtp-app-password:latest
# revision daftar-closing-agent-00041-5ml; audience_count=3; invoker allAuthenticatedUsers + user (no allUsers)
# scale service max 2 / revision max 2
curl -sS -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  https://daftar-closing-agent-1487285471.us-central1.run.app/list-apps
# → ["closing_agent"]
# POST /v1/tts locale=en and locale=ar → HTTP 200 mimeType=audio/mpeg (authenticated; audio not logged)
```

### Status
Chirp 3 HD Kore is live on the existing Cloud Run service; device fail-soft is still `flutter_tts`. **Gate 5 and §5.2–5.6 stay `[ ]`.** Owner: one Arabic sentence and one English sentence on a real phone (media volume). If Kore Arabic is weak, swap the voice **name** only.

## 2026-08-21 — Stage 5.2 UI / l10n

### Context
Roadmap §5.2: Khazna/Lapis pass on Closing Agent + Collections Desk, EN+AR ARB (including keys for later §5.4–5.6 copy), and real missing-permission states for mic, contacts, and Drive. English is a first-class locale; Arabic remains primary.

### Done
- Shared info banner [`lib/presentation/shared/widgets/daftar_permission_banner.dart`](../lib/presentation/shared/widgets/daftar_permission_banner.dart) (`lapis800` / `lapis50` fill, secondary CTA). Replaced `_MicInfoBanner`. Contacts deny on Confirm; Drive unsigned on the ritual report with Sign in.
- Contacts: sealed [`NativeContactPickOutcome`](../lib/core/utils/native_contact_picker_service.dart) (`picked` / `cancelled` / `denied`). Controller banner on deny; resume re-check clears it. [`ContactPickerFieldSuffix`](../lib/presentation/shared/widgets/contact_picker_field_suffix.dart) default snack + Open Settings (never auto-opens Settings).
- Drive copy: `google_not_signed_in` → `backupDriveNotSignedIn` (not “sign-in failed”). Ritual `skippedUnsigned` uses `closingRitualBackupUnsigned` + Sign in CTA.
- Desk copy uses [`showDaftarSnackBar`](../lib/presentation/shared/widgets/daftar_snack_bar.dart) (monochrome floating, elevation 0). FAB tip sheet is title + tap row + hold row + Got it ([`agent_fab_tip_sheet.dart`](../lib/presentation/screens/closing_agent/widgets/agent_fab_tip_sheet.dart)).
- ARB EN+AR: permission strings; §5.4 FAB/Confirm/Approve coach keys; §5.5 setup-spine keys (old 4-pager kept); §5.6 HUD toggle/chip keys. iOS `NSMicrophoneUsageDescription` in `en.lproj` + `ar.lproj` InfoPlist.strings.
- Roadmap §5.2 four boxes `[x]`.

### Architecture / decisions
- Lapis fill only on the info banner. Sign in on the report is secondary (no extra `ctaRest`). `ownsPrimaryGlow` unchanged.
- Drive remains OAuth, not an OS permission. Contacts stay `flutter_contacts` (no `PERMISSION_CONTACTS`).
- **Not in this slice:** `tutorial_coach_mark`, onboarding rewrite, HUD widget / `AgentTurnResult` echo, schema 25, Gate 5, Chirp / `/v1/tts`.

### Ops / verification
```bash
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter test test/core/l10n/arb_parity_test.dart \
  test/core/utils/native_contact_picker_service_test.dart \
  test/core/utils/error_translator_agent_auth_test.dart \
  test/presentation/shared/widgets/daftar_permission_banner_test.dart \
  test/presentation/shared/widgets/daftar_snack_bar_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_fab_tip_sheet_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_ritual_report_card_test.dart \
  test/presentation/screens/closing_agent/closing_agent_l10n_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_confirm_card_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart
# 88 passed
```

### Status
§5.2 complete. Next: §5.3 hardening (mic-denial crash paths) then §5.4 FAB coach. Gate 5 stays `[ ]`.

## 2026-08-22 — Stage 5.3 Hardening

### Context
Roadmap §5.3: freeze the Gate 4 ADK tool catalog (no new FunctionTools without a send-set / SMTP regression) and close hold-to-talk crash paths around mic denial — including iOS Settings restart, `permanentlyDenied`, dispose races, and background interruption.

### Done
- Frozen eight-tool catalog: comment on [`agent/closing_agent/tools.py`](../agent/closing_agent/tools.py) `ALL_TOOLS`; pytest [`agent/tests/test_tool_catalog_freeze.py`](../agent/tests/test_tool_catalog_freeze.py) locks `ALL_TOOLS` `__name__` to OpenAPI `ProposalTool` enum; Dart [`test/domain/enums/proposal_tool_test.dart`](../test/domain/enums/proposal_tool_test.dart) locks [`ProposalTool`](../lib/domain/enums/proposal_tool.dart) wire names. Catalog: `parse_goal`, `propose_debt`, `propose_payment`, `propose_create_contact`, `propose_create_ledger`, `propose_closing_plan`, `propose_whatsapp_drafts`, `propose_statement`.
- [`VoiceCapture`](../lib/core/utils/voice_capture.dart): skip `Permission.request` when granted / permanently denied / restricted; status probe failure does not prompt; `start()` returns `bool`; `stop` / `cancel` / `dispose` never throw. Injectable [`VoiceRecorder`](../lib/core/utils/voice_capture.dart) port.
- [`ClosingMicHoldSession`](../lib/core/utils/closing_mic_hold_session.dart) owns the recording lock. Deny / recorder fail / dispose-during-begin / background abandon never leave `isRecording` true and never start the native recorder on deny.
- [`closing_agent_screen.dart`](../lib/presentation/screens/closing_agent/closing_agent_screen.dart): `setState` only if `mounted`; cancel capture on `paused` / `hidden` (no submit); resume re-checks mic grant. Open Settings remains tap-only.
- Controller [`refreshMicPermissionBanner`](../lib/presentation/providers/closing_agent_controller.dart) on `onHostResumed` (injected checker; does not loop `request()`).
- Roadmap §5.3 two boxes `[x]`.

### Architecture / decisions
- iOS terminating the process after a Settings mic toggle is OS behavior, not a Dart crash. Treat return as a cold start; never loop `request()` after `permanentlyDenied`.
- Recorder failures reuse the existing mic-denied banner (same merchant action: enable mic in Settings). No new ARB keys.
- **Not in this slice:** new ADK tools, Cloud Run redeploy, `tutorial_coach_mark`, setup spine, HUD, Gate 5 feature-freeze declaration (28 Aug).

### Ops / verification
```bash
flutter test test/core/utils/voice_capture_test.dart \
  test/core/utils/closing_mic_hold_session_test.dart \
  test/core/utils/closing_report_speech_test.dart \
  test/domain/enums/proposal_tool_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart \
  test/application/agent/dispatch_collections_email_use_case_test.dart
# 69 passed

cd agent && /tmp/daftar-agent-venv/bin/python -m pytest \
  tests/test_tool_catalog_freeze.py \
  tests/test_email_send_batch.py \
  tests/test_proposal_tools.py -q
# 94 passed
```

### Status
§5.3 complete. Next: §5.4 FAB coach (`tutorial_coach_mark`). Gate 5 stays `[ ]`.

## 2026-08-22 — Stage 5.4 FAB Coach

### Context
Roadmap §5.4 Must: replace the home FAB tip bottom sheet with a one-shot `tutorial_coach_mark` 1.3.x Khazna spotlight on the 44dp center FAB. Reuse `hasSeenAgentFabTip`. No schema bump. Confirm/Approve coaches deferred.

### Done
- Package [`tutorial_coach_mark: ^1.3.3`](../pubspec.yaml). Named alpha tokens in [`app_colors.dart`](../lib/app/theme/app_colors.dart) (`alphaScrim` / `alphaStrong` and §2.7 siblings).
- Wrapper [`daftar_coach_mark.dart`](../lib/presentation/shared/widgets/daftar_coach_mark.dart): RRect hole, `pulseEnable: false`, `enableTargetTab: false`, blur dim, RTL skip, title + tap/hold rows + Got it (`DaftarButton`). Only this file (and tests) import the package.
- [`MainShell`](../lib/presentation/shared/widgets/main_shell.dart) is a `ConsumerStatefulWidget` with a `GlobalKey` on `_InlineFab`. Shows the coach when home + ledgers ready + `!hasSeenAgentFabTip`. Persist via [`MarkAgentFabTipSeenUseCase`](../lib/application/settings/mark_agent_fab_tip_seen_use_case.dart).
- Removed [`AgentFabTipSheet`](../lib/presentation/screens/closing_agent/widgets/agent_fab_tip_sheet.dart) path from [`home_screen.dart`](../lib/presentation/screens/home/home_screen.dart). Demo seeder [`hasSeenAgentFabTip: false`](../lib/core/utils/dev_database_seeder.dart).
- Tests: [`daftar_coach_mark_test.dart`](../test/presentation/shared/widgets/daftar_coach_mark_test.dart), [`mark_agent_fab_tip_seen_use_case_test.dart`](../test/application/settings/mark_agent_fab_tip_seen_use_case_test.dart). Roadmap §5.4 Must boxes `[x]`. Should Confirm/Approve left `[ ]`.

### Architecture / decisions
- Spotlight from MainShell (dock FAB), not HomeScreen body overlay. Schema stays **24**. Providers still call the use case, never the repository.
- **Not in this slice:** Confirm coach, Approve coach, schema 25, §5.5 setup spine, §5.6 HUD, Gate 5.

### Ops / verification
```bash
flutter test test/presentation/shared/widgets/daftar_coach_mark_test.dart \
  test/application/settings/mark_agent_fab_tip_seen_use_case_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_fab_tip_sheet_test.dart \
  test/core/l10n/arb_parity_test.dart
# 13 passed
```

### Status
§5.4 Must complete. Next: §5.5 contest onboarding (or Gate 5 when calendar still holds). Gate 5 stays `[ ]`.

## 2026-08-22 — Stage 5.5 Contest onboarding

### Context
Replace the 4-page marketing carousel at `/onboarding` with a 7-beat Khazna setup spine (Hero → Language → Look → Store → Google → Pro → first ledger). Keep `hasSeenOnboarding` and complete into home so §5.4 FAB coach still runs after. Schema stays 24. No new packages. No Gate 5 / §5.6.

### Done
- Ungated [`UpdateMerchantProfileUseCase`](../lib/application/merchant/update_merchant_profile_use_case.dart) (dropped `brandedPdf` / `ActivationRepository`). Logo stays Pro-gated in `SetMerchantLogoUseCase`.
- Free [`merchant_branding_screen.dart`](../lib/presentation/screens/settings/merchant_branding_screen.dart): name/phone save enabled; logo picker hidden; upgrade banner kept.
- Beat machine [`onboarding_screen.dart`](../lib/presentation/screens/onboarding/onboarding_screen.dart) + widgets under `lib/presentation/screens/onboarding/widgets/` (`hero`, `language`, `look`, `store`, `google`, `pro`, `ledger`). Restyled [`onboarding_step_indicator.dart`](../lib/presentation/screens/onboarding/widgets/onboarding_step_indicator.dart). Removed global Skip and [`onboarding_page.dart`](../lib/presentation/screens/onboarding/widgets/onboarding_page.dart).
- Fail-soft [`onboarding_analytics.dart`](../lib/core/services/onboarding_analytics.dart) (`onboarding_start` / `onboarding_complete` when `analyticsEnabled`).
- Tests: [`onboarding_screen_test.dart`](../test/presentation/screens/onboarding/onboarding_screen_test.dart); merchant use-case + integration name persist on Free. Roadmap **§5.5** boxes `[x]`. Seeder still `hasSeenOnboarding: true`.

### Architecture / decisions
- Route, gate, `CompleteOnboardingUseCase` unchanged. Language autonyms (العربية / English) so the picker is stable across locale flips; `localeProvider.setLocale` rebuilds RTL/LTR before Continue.
- Google failure stays on beat. Invalid Pro code shows `activationErrorInvalid`; a second Continue still advances. Empty ledgers: one-tap `CreateLedgerUseCase` then complete; non-empty auto-skips ledger.
- Reduce-motion: `MediaQuery.disableAnimationsOf` skips `FadeSlideTransition`, CTA breath, and step-dot animation. Lapis Law: selected cards use existing selectable lapis **border**, never fill.

### Ops / verification
```bash
flutter test test/presentation/screens/onboarding/onboarding_screen_test.dart \
  test/application/merchant/merchant_profile_use_cases_test.dart \
  test/integration/merchant_branding_integration_test.dart \
  test/core/l10n/arb_parity_test.dart
# onboarding 8 passed; merchant 12 passed; branding integration 2 passed; arb parity 5 passed
```

### Status
§5.5 complete. Next: §5.6 HUD (or Gate 5 checklist). Gate 5 / §5.6 stay `[ ]`.

## 2026-08-22 — Stage 5.6 Architecture HUD

### Context
Contest overlay to prove Cloud Run + Gemini 3.5 Flash in-frame (model, tools, round-trip ms, correlation last-8, email sent + Message-ID last-8). Settings toggle, not a product tour. Echo telemetry from the Flutter `/run` wrapper — never Cloud Logging from the device.

### Done
- [`AgentTurnResult`](../lib/domain/value_objects/agent_turn_result.dart) gained `modelId`, `toolNames`, `latencyMs`. [`ClosingAgentRemoteDs._postRun`](../lib/data/datasources/remote/closing_agent_remote_ds.dart) fills them (`Stopwatch` around Dio `POST /run`; model pinned [`ClosingAgentConstants.modelId`](../lib/domain/constants/closing_agent_constants.dart) `gemini-3.5-flash`).
- Schema **25**: `demoArchitectureHud` default **false**. [`SetDemoArchitectureHudUseCase`](../lib/application/settings/set_demo_architecture_hud_use_case.dart) + Settings `GlowPillToggle`. [`DevDatabaseSeeder`](../lib/core/utils/dev_database_seeder.dart) writes **true**. `DbConstants` + `DriveBackupConstants` aligned; BACKUP_SPEC / Drive spec examples updated.
- Overlay [`daftar_architecture_hud.dart`](../lib/presentation/shared/widgets/daftar_architecture_hud.dart) mounted in [`DaftarApp.builder`](../lib/app/app.dart) under `AppLockOverlay`, top `SafeArea`, `IgnorePointer`, lapis **border** + `AppGlows.haloXs`, monochrome fill. Email chip from last accepted send-batch Message-ID (`sent` + SMTP 250). Existing ARB EN+AR wired (no new keys).
- Tests: HUD overlay / last-8 / no `delivered` / reduce-motion / FAB; use case; `/run` echo; seeder default on; schema 25 default off. Roadmap **§5.6** boxes `[x]`.

### Architecture / decisions
- Stock ADK `POST /run` unchanged. Device round-trip ms ≠ Cloud Logging `daftar.agent.model` `latency_ms`. Visibility is **only** `settings.demoArchitectureHud` (debug does not force the overlay).
- Providers call the HUD use case; HUD widget is presentation-only via [`architectureHudSnapshotProvider`](../lib/presentation/providers/architecture_hud_provider.dart). Never poll Gmail; never label delivered.
- Lapis Law: chips are surface fill + 1px lapis border + glow. Reduce-motion: static chips (no controllers). Confirm/Approve coaches unbuilt (would be schema 26).

### Ops / verification
```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/presentation/shared/widgets/daftar_architecture_hud_test.dart \
  test/presentation/providers/architecture_hud_provider_test.dart \
  test/application/settings/set_demo_architecture_hud_use_case_test.dart \
  test/application/agent/closing_agent_client_test.dart \
  test/core/utils/dev_database_seeder_test.dart \
  test/data/repositories/agent_schema_v19_test.dart \
  test/core/l10n/arb_parity_test.dart
# 44 passed
```

### Status
§5.6 complete. Gate 5 stays `[ ]` (seeded-session film remaining). Next: Gate 5 checklist / Stage 6 packaging.

## 2026-08-22 — FAB coach launch crash (Oops / ErrorWidget)

### Context
Cold start on device showed `DaftarFatalErrorView` (“Oops, a glitch occurred… Restart app”). Terminal: `FormatException: It was not possible to obtain target position (agent-fab)` then Riverpod `Bad state: Using "ref" when a widget is about to or has been unmounted` from `_MainShellState._showFabCoach` → `DaftarCoachMark.showFab.dismiss`. `tutorial_coach_mark` calls `skip()` during **build** when the FAB has no Overlay-relative position (first frames 0×0 / not laid out). That threw into `ErrorWidget.builder`.

### Done
- [`daftar_coach_mark.dart`](../lib/presentation/shared/widgets/daftar_coach_mark.dart): `isTargetLaidOut` mirrors `getTargetCurrent(..., rootOverlay: true)` (attached `RenderBox`, positive size, `localToGlobal` vs root Overlay). `showFab` is a no-op until that passes; `onSkip`/`onFinish` schedule dismiss on a microtask and never throw; `show()` wrapped in try/catch (do not persist if overlay was not inserted).
- [`main_shell.dart`](../lib/presentation/shared/widgets/main_shell.dart): retry coach up to 48 post-frame callbacks; capture `MarkAgentFabTipSeenUseCase` **while mounted** so dismiss never calls widget `ref`. Giving up a session does **not** set `hasSeenAgentFabTip`.
- Tests: unattached / zero-size key → not laid out; `showFab` no-op without throw. Existing Got it / Skip / overlay-hit tests still pass.

### Architecture / decisions
- Presentation-only. Providers still call the use case (not the repository). No package fork. HUD / Gate 5 / Confirm-Approve coaches unchanged.
- Persist only after a real dismiss (Got it / Skip / finish), never after a failed insert.

### Ops / verification
```bash
flutter test test/presentation/shared/widgets/daftar_coach_mark_test.dart
# 7 passed
```

### Status
Launch Oops from FAB coach closed. Hot restart / cold start should show home, then the FAB tip once the dock is laid out. Gate 5 stays `[ ]`.

## 2026-08-22 — Onboarding polish (overflow, branding, Drive, ledger)

### Context
Store beat overflowed when the keyboard opened (`RenderFlex` ~1.7–24px). Beats 5–7 were text-only; Pro did not showcase store branding; Google sign-in did not surface Drive offline grant; ledger beat lacked ledger-vs-account education and custom name.

### Done
- [`onboarding_beat.dart`](../lib/presentation/screens/onboarding/onboarding_beat.dart): `OnboardingBeatFrame` (scroll + keyboard insets), `OnboardingBeatHeader`, `OnboardingBeatLine`. All beats migrated off `Column` + `Spacer`.
- [`onboarding_store_beat.dart`](../lib/presentation/screens/onboarding/widgets/onboarding_store_beat.dart): keyboard-safe layout; icon header + body ARB.
- [`onboarding_google_beat.dart`](../lib/presentation/screens/onboarding/widgets/onboarding_google_beat.dart): trust rows + signed-in Drive grant banner. [`onboarding_screen.dart`](../lib/presentation/screens/onboarding/onboarding_screen.dart): after `signInWithGoogle`, if `!driveOfflineGrantReady` stay on beat; primary CTA → `completeDriveAuthorization` (presentation-only; no auth-repo PKCE chain).
- [`onboarding_pro_beat.dart`](../lib/presentation/screens/onboarding/widgets/onboarding_pro_beat.dart): `StoreLogoSeal`, store name, three Pro feature rows; activation code expander secondary.
- [`onboarding_ledger_beat.dart`](../lib/presentation/screens/onboarding/widgets/onboarding_ledger_beat.dart): ledger vs accounts copy; custom name chip + field + create. Language / Look / Hero beats: icon headers + short body lines.
- ARB EN+AR (`onboardingSetupLanguageBody` … `onboardingSetupLedgerCreate`). Tests: keyboard overflow, Drive grant flow, Pro store name, custom ledger (13 onboarding + 5 arb parity).

### Architecture / decisions
- §5.5 spine unchanged (`/onboarding`, beat order, skip rules). Lapis Law on icon chips (border + glow, no fill). Skip Google still allowed without grant.

### Ops / verification
```bash
flutter test test/presentation/screens/onboarding/onboarding_screen_test.dart \
  test/core/l10n/arb_parity_test.dart
# 18 passed
```

### Status
Onboarding polish shipped. Gate 5 unchanged `[ ]`.

## 2026-08-22 — §5.4 FAB coach not appearing on home

### Context
FAB spotlight (§5.4) did not show after home load despite `hasSeenAgentFabTip: false`. Cold start skips 100+ frames; coach preflight gave up after 48 post-frame attempts (~0.8s) before the bottom-nav FAB had a stable Overlay position. `GlobalKey` on `_InlineFab` StatefulWidget also made target geometry less reliable than the 44dp box.

### Done
- [`main_shell.dart`](../lib/presentation/shared/widgets/main_shell.dart): `GlobalKey` on the 44×44 FAB `Container` (`_fabCoachTargetKey`); retry up to 240 frames / 8s; reset pending flag when window expires so a later rebuild can retry; `ref.listen` on settings + ledgers; mark shown only when overlay actually inserts.
- [`daftar_coach_mark.dart`](../lib/presentation/shared/widgets/daftar_coach_mark.dart): `isTargetLaidOut` uses `Overlay.maybeOf(..., rootOverlay: true)` instead of `findRootAncestorStateOfType`.

### Ops / verification
```bash
flutter test test/presentation/shared/widgets/daftar_coach_mark_test.dart
# 7 passed
```

### Status
FAB coach should appear on home once ledgers + settings are ready and `!hasSeenAgentFabTip`. Clear flag in Settings DB or reinstall to re-test.

## 2026-08-22 — §5.4 FAB spotlight root-cause fix

### Context
FAB coach still did not appear on home after prior retry/preflight work. Analysis found three interacting bugs: erroneous persist on package failure paths, premature `_fabCoachShown`, and over-strict `isTargetLaidOut`.

### Done
- [`daftar_coach_mark.dart`](../lib/presentation/shared/widgets/daftar_coach_mark.dart): `isTargetLaidOut` mirrors `getTargetCurrent(..., rootOverlay: true)` (including `localToGlobal` fallback). Persist only when `userDismissIntent` is set (Got it / Skip pointer-down); `onFinish` no longer persists. Show via `rootNavigatorKey` + `showWithNavigatorStateKey`. `showFab` returns `Future<bool>` after overlay insert settles (`coach.isShowing`).
- [`main_shell.dart`](../lib/presentation/shared/widgets/main_shell.dart): await `showFab` result before `_fabCoachShown`; retry on `false`; removed redundant `Overlay.maybeOf` gate.
- Tests: [`daftar_coach_mark_test.dart`](../test/presentation/shared/widgets/daftar_coach_mark_test.dart) (bottom-nav layout + 8 cases); new [`main_shell_fab_coach_test.dart`](../test/presentation/shared/widgets/main_shell_fab_coach_test.dart) (ProviderScope + home shell → coach → Got it → `MarkAgentFabTipSeenUseCase`).

### Architecture / decisions
- Presentation-only; no package fork. Error `skip()` / `onFinish` from `tutorial_coach_mark` must never write `hasSeenAgentFabTip`.
- If coach still absent after deploy, DB may have `hasSeenAgentFabTip: true` from prior failed runs — clear app data or reset the flag.

### Ops / verification
```bash
flutter test test/presentation/shared/widgets/daftar_coach_mark_test.dart \
  test/presentation/shared/widgets/main_shell_fab_coach_test.dart
# 9 passed
```

### Status
§5.4 FAB spotlight fix shipped. Gate 5 FAB checkbox still `[ ]` until manual seeded-session smoke on device.

## 2026-08-22 — FAB coach tooltip centered on FAB

### Context
Tooltip card sat slightly to the right of the center FAB. `ContentAlign.top` is a full-width strip; the card shrink-wraps under `flutter_animate`, so RTL parked it on the start (right) edge.

### Done
- [`daftar_coach_mark.dart`](../lib/presentation/shared/widgets/daftar_coach_mark.dart): `Align(center)` + max-width cap (`screen − 2×pagePaddingH`); physical L/R padding so the box stays over the FAB in AR and EN.
- Test: tooltip `dx` matches FAB `dx` (±1px) in LTR and RTL.

### Ops / verification
```bash
flutter test test/presentation/shared/widgets/daftar_coach_mark_test.dart \
  test/presentation/shared/widgets/main_shell_fab_coach_test.dart
# 10 passed
```

### Status
Tooltip is centered on the FAB. Gate 5 unchanged `[ ]`.

## 2026-08-22 — FAB spotlight hole alignment (physical overlay coords)

### Context
Spotlight RRect was skewed right (“half on FAB, half beside”). `Align(center)` on the tooltip did not fix the hole. `tutorial_coach_mark` `getTargetCurrent` uses `localToGlobal(ancestor: overlay)` through the RTL glass dock — wrong `dx` for the 44dp FAB.

### Done
- [`daftar_coach_mark.dart`](../lib/presentation/shared/widgets/daftar_coach_mark.dart): `overlayTargetOf` = physical global minus overlay origin; `isTargetLaidOut` / `showFab` use it; `TargetFocus(targetPosition:)` **without** `keyTarget`; `daftarCoachFabTooltipCardKey` on painted card.
- Tests: bottom-nav FAB `overlayTargetOf` center matches FAB (LTR + RTL); card `dx` matches FAB after show; 11 widget tests pass.

### Ops / verification
```bash
flutter test test/presentation/shared/widgets/daftar_coach_mark_test.dart \
  test/presentation/shared/widgets/main_shell_fab_coach_test.dart
# 11 passed
```

### Status
Spotlight hole and tooltip card align on center FAB. Hot restart on device to confirm.

## 2026-08-22 — FAB coach gated on onboarding completion

### Context
FAB spotlight appeared over `/onboarding`. Router `initialLocation` is `/` so `MainShell` mounted briefly before redirect; coach used `rootNavigatorKey` overlay and showed while onboarding was visible.

### Done
- [`main_shell.dart`](../lib/presentation/shared/widgets/main_shell.dart): require `settings.hasSeenOnboarding` in `_scheduleFabCoachIfNeeded` and `_showFabCoach` (§5.4: after onboarding → home).
- [`main_shell_fab_coach_test.dart`](../test/presentation/shared/widgets/main_shell_fab_coach_test.dart): positive test sets `hasSeenOnboarding: true`; new test blocks coach when false.

### Status
Coach shows only after onboarding completes and user lands on home.

## 2026-08-22 — TTS voice Kore → Enceladus (Closing Agent)

### Context
Switch cloud TTS speaker from Chirp 3 HD Kore to Enceladus for Arabic and English confirm/read-back. Voice is server-side only (`POST /v1/tts`); Flutter sends `{text, locale}` unchanged.

### Done
- [`agent/tts/voices.py`](../agent/tts/voices.py): `VOICE_AR` → `ar-XA-Chirp3-HD-Enceladus`, `VOICE_EN` → `en-US-Chirp3-HD-Enceladus`.
- [`agent/tests/test_tts.py`](../agent/tests/test_tts.py): renamed Kore tests → Enceladus; updated assertions.
- Docs: [`agent/tts/router.py`](../agent/tts/router.py), [`agent/README.md`](../agent/README.md), [`agent/openapi.yaml`](../agent/openapi.yaml).

### Architecture / decisions
- Same API contract; `SPEAKING_RATE` (0.95) and `MAX_TTS_CHARS` (2000) unchanged.
- Offline `flutter_tts` fail-soft path untouched.

### Ops / verification
```bash
agent/.venv/bin/python -m pytest agent/tests/test_tts.py -q
# 9 passed
gcloud run deploy daftar-closing-agent --source=. --project=daftar-closing-agent --region=us-central1 \
  --quiet --no-allow-unauthenticated --min=0 --max=2 --min-instances=0 --max-instances=2 --port=8000 \
  --service-account=agent-runner@daftar-closing-agent.iam.gserviceaccount.com \
  --update-env-vars=GOOGLE_GENAI_USE_VERTEXAI=TRUE,GOOGLE_CLOUD_PROJECT=daftar-closing-agent,GOOGLE_CLOUD_LOCATION=global \
  --update-secrets=/secrets/gmail-smtp-app-password=gmail-smtp-app-password:latest
# revision daftar-closing-agent-00046-mw8 (overlapping source deploys); audience_count=3; invoker allAuthenticatedUsers + user (no allUsers)
# scale service max 2 / revision max 2
curl -sS -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  https://daftar-closing-agent-1487285471.us-central1.run.app/list-apps
# → ["closing_agent"]
# POST /v1/tts locale=en and locale=ar → HTTP 200 mimeType=audio/mpeg
# Cloud Logging jsonPayload.voice=en-US-Chirp3-HD-Enceladus (en) / ar-XA-Chirp3-HD-Enceladus (ar)
```

### Status
Enceladus is live on `/v1/tts`. Device listen test (AR + EN) is the remaining check — Flutter hot-restart is enough now that Cloud Run is redeployed.

## 2026-08-23 — Splash: transparent mark, monochrome canvas, launch curtain

### Context
Native splash showed a lapis gradient fill and opaque black square around the logo (adaptive-foreground master). Violated Lapis Law and looked unprofessional. Design system §16.4 calls for pure monochrome canvas + centered mark with `glowXl` after launch.

### Done
- [`tool/generate_brand_icons.py`](../tool/generate_brand_icons.py): splash marks rasterized with transparent alpha (SVG via cairosvg when available; PIL keyed fallback from adaptive masters). `splash_logo` / `splash_logo_light` on Android; iOS `LaunchLogo-dark` / `LaunchLogo-light` appearance variants. Launcher icons unchanged (gradient `background.png` only on home-screen icon).
- Android: solid `@color/splash_background` / `splash_background_light` in [`launch_background.xml`](android/app/src/main/res/drawable/launch_background.xml); Android 12+ [`values-v31/styles.xml`](android/app/src/main/res/values-v31/styles.xml) with transparent `windowSplashScreenIconBackgroundColor`. Removed `splash_background.png` gradient bitmap.
- iOS: [`LaunchScreen.storyboard`](ios/Runner/Base.lproj/LaunchScreen.storyboard) — monochrome `LaunchColor` only; no full-bleed gradient image.
- Flutter: [`daftar_launch_curtain.dart`](../lib/presentation/shared/widgets/daftar_launch_curtain.dart) — 400ms fade in, brief hold, fade out; `DaftarBrandMark` 96 + `glowXl`; reduce-motion skips; wired in [`app.dart`](../lib/app/app.dart).

### Architecture / decisions
- Lapis gradient stays on launcher icon only, not splash. Splash canvas is `surface0` / `surface0Light`. Not a GoRouter route.

### Ops / verification
```bash
tool/.brand-venv/bin/python tool/generate_brand_icons.py
flutter test test/presentation/shared/widgets/daftar_launch_curtain_test.dart \
  test/presentation/shared/widgets/daftar_brand_mark_test.dart
# 4 passed
```
**Full rebuild** (`flutter run` or reinstall) required to see native splash changes; hot restart is not enough.

### Status
Splash polish landed. Owner: cold start on device (dark + light OS appearance) — no black logo box, no gradient wash, glow curtain into first screen.

## 2026-08-23 — Android splash handoff: eliminate double-logo flash

### Context
Cold start on Android 12+ showed the logo without canvas, then blank, then the correct Flutter curtain mark — a triple handoff between legacy `launch_background` bitmap, SplashScreen API icon, and `DaftarLaunchCurtain` fading in from opacity 0.

### Done
- [`drawable-v31/launch_background.xml`](android/app/src/main/res/drawable-v31/launch_background.xml) + [`drawable-night-v31`](android/app/src/main/res/drawable-night-v31/launch_background.xml): solid canvas only on API 31+ (logo from `windowSplashScreenAnimatedIcon` alone).
- [`tool/generate_brand_icons.py`](../tool/generate_brand_icons.py): `ANDROID_SPLASH_MARK` 144 on 288dp canvas to match Flutter 96dp mark in Android 12 display circle; regenerated `splash_logo.png` / `splash_logo_light.png`.
- [`values/styles.xml`](android/app/src/main/res/values/styles.xml) + [`values-night/styles.xml`](android/app/src/main/res/values-night/styles.xml): `NormalTheme.windowBackground` → splash canvas colors.
- [`MainActivity.kt`](android/app/src/main/kotlin/com/akrmcodes/daftar/MainActivity.kt): disable Android 12 splash exit fade (`setOnExitAnimationListener { remove() }` before `super.onCreate()`).
- [`daftar_launch_curtain.dart`](../lib/presentation/shared/widgets/daftar_launch_curtain.dart): no fade-in — full opacity handoff, hold + fade-out (~450ms total).
- [`bootstrap.dart`](../lib/bootstrap.dart): system nav bar matches `surface0` / `surface0Light` from platform brightness on cold start.

### Architecture / decisions
Seamless handoff: native canvas + mark → Flutter same frame with `glowXl` → fade to app. Pre-API-31 still uses `launch_background` bitmap path.

### Ops / verification
```bash
tool/.brand-venv/bin/python tool/generate_brand_icons.py
flutter analyze
flutter test test/presentation/shared/widgets/daftar_launch_curtain_test.dart
```
**Full rebuild** required for native splash changes.

### Status
Android handoff fix landed. Owner: cold start on Android 12+ (light + dark) — no logo size jump or disappearance between native and Flutter frames.

## 2026-08-23 — Launcher icon: enlarge and center mark

### Context
Home-screen icon mark read small (~26% canvas width) and slightly high compared to peer apps on the launcher grid. Owner requested a slight, professional enlargement and centering.

### Done
- [`tool/generate_brand_icons.py`](../tool/generate_brand_icons.py): `LAUNCHER_GLYPH_WIDTH_FRAC = 0.305` (~17% larger than prior implicit 0.26); `composite_branded_icon()` rasterizes from [`brand/masters/daftar_mark_on_dark.svg`](../brand/masters/daftar_mark_on_dark.svg), crops bbox, scales, centers; adaptive `ic_launcher_foreground` uses matching `render_adaptive_foreground()`.
- Post-generation metrics guard: glyph width frac ∈ [0.29, 0.32], |horizontal center err| < 2px (verified `frac=0.306 center_err=(0.0,0.0)`).
- Regenerated Android mipmaps/adaptive, iOS/macOS App Icon, store, web, Windows ICO. Splash assets unchanged.

### Architecture / decisions
Single tuning knob: `LAUNCHER_GLYPH_WIDTH_FRAC`. SVG master is source of truth for launcher scale; optical Y offset 0 (SVG is centered; old PNG had −19px bias).

### Ops / verification
```bash
tool/.brand-venv/bin/python tool/generate_brand_icons.py
# launcher glyph frac=0.306 center_err=(0.0,0.0)
```
**Uninstall/reinstall** (or clear launcher cache on Samsung) required to see new home-screen icon.

### Status
Launcher scale bump landed. Owner: compare on device launcher grid vs peer apps; tune `LAUNCHER_GLYPH_WIDTH_FRAC` in 0.29–0.32 if needed.

## 2026-08-23 — Splash hi-res: density-qualified PNGs

### Context
Native splash mark looked pixelated on xxhdpi/xxxhdpi phones. A single 288×288 `drawable/splash_logo.png` (mdpi baseline) was upscaled ~2–3× while the on-screen mark stayed ~96dp.

### Done
- [`tool/generate_brand_icons.py`](../tool/generate_brand_icons.py): `ANDROID_SPLASH_DENSITY` buckets (mdpi 288 … xxxhdpi 1152); `write_splash_logos()` writes `splash_logo` / `splash_logo_light` per `drawable-*dpi/`; removes legacy `drawable/splash_logo*.png`; `assert_splash_density_outputs()` guards dimensions.
- On-screen splash size unchanged (`ANDROID_SPLASH_MARK` / `ANDROID_SPLASH_CANVAS`); Flutter handoff still 96dp.

### Ops / verification
```bash
tool/.brand-venv/bin/python tool/generate_brand_icons.py
# splash density buckets OK (mdpi=288 … xxxhdpi=1152)
```
**Full rebuild** (`flutter run` or reinstall) required — native splash assets are not hot-reloadable.

### Status
Hi-res splash buckets landed. Owner: cold start on xxhdpi+ device — native mark should be crisp through Flutter curtain handoff.

## 2026-08-23 — Plans screen: accurate feature matrix

### Context
Subscriptions / activation UI marketed Excel import/export, CSV export, analytics charts, customer portal, and automated WhatsApp statements — none fully shipped. Owner requested honest plan copy aligned with the app.

### Done
- [`app_en.arb`](lib/core/l10n/app_en.arb) + [`app_ar.arb`](lib/core/l10n/app_ar.arb): CSV import only (no Excel); PDF statements export (no CSV); contest Pro+ bullets → Closing Agent desk / voice & rituals; tagline without analytics.
- [`plan_compare_section.dart`](lib/presentation/screens/premium/widgets/plan_compare_section.dart): removed WhatsApp statements row; analytics dashboard + customer portal → Coming soon on all tiers; CSV import + PDF export rows unchanged.

### Architecture / decisions
Entitlement flags unchanged — UI only. Shipped: CSV import (free), PDF statements (basic/branded), store branding, Closing Agent highlighted on contest Pro+ cards.

### Ops / verification
```bash
flutter gen-l10n && flutter analyze lib/presentation/screens/premium/
```

### Status
Plans screen reflects shipped capabilities. Owner: review Settings → Plan & activation in AR + EN.

## 2026-08-23 — Closing Agent bilingual speech

### Context
Chirp 3 HD Enceladus was speaking the app locale even when the merchant asked for the other language (mismatched `language_code` vs script). Confirm cards echoed `name. amount. item`, the model restated the request, and ask/balance cards were silent.

### Done
- Session `speechLocaleOverride` on [`closing_agent_state.dart`](lib/presentation/providers/closing_agent_state.dart); phrase detection in [`speech_locale.dart`](lib/application/agent/speech_locale.dart); script safety net in [`speech_script_locale.dart`](lib/core/utils/speech_script_locale.dart) (Arabic letters → `ar-XA` Enceladus, else Latin → `en-US`). Reset on studio pop.
- Skip narrative TTS when a Confirm, Ask, or closing-plan card owns the turn. Confirm/ask lines use ARB `closingAgentSpeakDebt` / `SpeakPayment` / `SpeakBalance` (`محمد عليه 500` / `Mohamed owes 500`). [`AgentAskCard`](lib/presentation/screens/closing_agent/widgets/agent_ask_card.dart) speaks Drift facts, including after an ambiguous-name chip.
- Cloud Run instruction: no request echo, honor speak-AR/EN, silent verbatim first sentence for YER snap, no close-day PDF/reminder essay. Tests in [`test_agent_instruction.py`](agent/tests/test_agent_instruction.py).

### Architecture / decisions
UI locale / RTL unchanged. One utterance, one Chirp language_code. Amount snap still uses narrative first sentence; the device does not play it when a card will speak.

### Ops / verification
```bash
flutter gen-l10n && dart run build_runner build --delete-conflicting-outputs
flutter test test/application/agent/speech_locale_test.dart \
  test/application/agent/synthesize_agent_speech_use_case_test.dart \
  test/core/utils/agent_speech_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_speakable_lines_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_ask_card_test.dart
cd agent && uv run --with pytest --with fastapi --with httpx \
  python -m pytest tests/test_agent_instruction.py tests/test_tts.py -q
# 18 passed
```
**Cloud Run not redeployed this turn** — operator shell lacked `GMAIL_SMTP_USER` / `GMAIL_SMTP_FROM`; a `--update-env-vars` deploy would risk wiping mailbox config. Flutter hot restart is enough for device TTS routing. Prompt change needs `gcloud run deploy daftar-closing-agent` from [`agent/README.md`](../agent/README.md) with the Gmail env present and custom-audience count preserved.

### Status
Device speech locale + card TTS shipped. Live Gemini still uses the previous instruction until Cloud Run redeploy.

## 2026-08-23 — Closing Agent clerk Confirm-Gate speech

### Context
Card-reading TTS made interaction worse: debt cards echoed “Mohamed owes 500”, statement cards spoke UUIDs, and Chirp voiced markdown/`*`/`·`. The merchant needs a desk-clerk Confirm Gate: intended write, spoken riyals, real CTA.

### Done
- [`lib/core/utils/tts_sanitize.dart`](lib/core/utils/tts_sanitize.dart): strip markdown, RFC-4122 UUIDs, leftover `*`, `&` → and/و, ` · ` → comma. Applied in [`agent_speech.dart`](lib/core/utils/agent_speech.dart) and [`synthesize_agent_speech_use_case.dart`](lib/application/agent/synthesize_agent_speech_use_case.dart).
- Confirm/Ask clerk scripts in [`agent_speakable_lines.dart`](lib/presentation/screens/closing_agent/widgets/agent_speakable_lines.dart) + ARB: intended action + `{amount} riyals`/`ريال` + actual button label; create-if-missing vs existing; statement PDF. Ask keeps “owes / عليه” with currency words, overdue intro, candidate names only.
- [`agent_confirm_card.dart`](lib/presentation/screens/closing_agent/widgets/agent_confirm_card.dart): never display/speak UUID; statement title `Statement for {name}` / `كشف حساب {name}`; TTS uses contact.name only (chips keep `Name · Ledger`).
- Gemini INSTRUCTION rewritten as Arabic-first desk clerk; `contact_hint is always the spoken name` (never a UUID). [`propose_statement`](agent/closing_agent/tools.py) / money tools backfill `contactHint` from `voiceHints.displayName`.

### Architecture / decisions
Device authors Confirm/Ask/ritual speech (integer money from Drift). Gemini routes and must not invent amounts or IDs in the spoken line. UI locale / RTL unchanged. One Chirp language_code per clip.

### Ops / verification
```bash
flutter gen-l10n
flutter test test/core/utils/tts_sanitize_test.dart \
  test/core/utils/agent_speech_test.dart \
  test/application/agent/synthesize_agent_speech_use_case_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_speakable_lines_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_ask_card_test.dart \
  test/presentation/screens/closing_agent/widgets/agent_confirm_card_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart
# 94 passed
cd agent && uv run --with pytest --with fastapi --with httpx \
  --with jsonschema --with pyyaml \
  python -m pytest tests/test_agent_instruction.py tests/test_proposal_tools.py -q
# 83 passed
```
**Cloud Run not redeployed this turn** — operator shell lacked `GMAIL_SMTP_USER` / `GMAIL_SMTP_FROM`. Device clerk TTS works after hot restart. Prompt/tool backfill needs `gcloud run deploy daftar-closing-agent` from [`agent/README.md`](../agent/README.md) with Gmail env present and custom-audience count preserved.

### Status
Device clerk speech + sanitizer shipped. Live Gemini still uses the previous instruction until Cloud Run redeploy.

## 2026-08-23 — Cloud Run clerk prompt deploy

### Context
Clerk speech and `contact_hint` backfill were on the device and in `agent/`, but live Gemini still ran the previous instruction. Owner asked to deploy.

### Done
- Snapshotted custom-audience **count** (3) and copied live `GMAIL_SMTP_USER` / `GMAIL_SMTP_FROM` into the deploy shell without printing mailbox or client IDs.
- `gcloud run deploy daftar-closing-agent --source=.` from [`agent/README.md`](../agent/README.md): Vertex + Gmail env merge, App Password file mount, `--no-allow-unauthenticated`, cost lock min 0 / max 2 on service and revision.
- Revision **`daftar-closing-agent-00047-p6c`** serving 100% at `https://daftar-closing-agent-1487285471.us-central1.run.app`.

### Architecture / decisions
`--update-env-vars` kept mailbox From=user. Audience count stayed 3. Invoker: `allAuthenticatedUsers` + user, **no** `allUsers`. Temp env/audience files deleted after verify.

### Ops / verification
```bash
# audience_count=3  service_maxScale=2  revision_maxScale=2
# gmail_same_address=True  secret_volume_present=True
# invoker_allUsers=False
curl -sS -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  https://daftar-closing-agent-1487285471.us-central1.run.app/list-apps
# → ["closing_agent"]  HTTP 200
```

### Status
Live agent now has the clerk INSTRUCTION and statement name backfill. Device clerk TTS was already in the Flutter binary from the previous turn (hot restart).

## 2026-08-23 — Release sample store seeder (N=7)

### Context
Contest judges need a one-tap demo ledger in release builds without `--dart-define-from-file`. Seeder was debug-only, 12 contacts, forced Arabic/`محل الغانم`, and RFC 2606 email placeholders.

### Done
- [`lib/core/utils/demo_store_seeder.dart`](lib/core/utils/demo_store_seeder.dart) + [`demo_seed_report.dart`](lib/core/utils/demo_seed_report.dart): **7** locale-aware debtors, ranked aging (Top 5 PDF / 2 text-only), preserve store name + Drive ids; no locale/HUD/onboarding overwrite.
- [`lib/core/utils/demo_seed_emails.dart`](lib/core/utils/demo_seed_emails.dart): defaults `akrm.codes+demo1`–`demo4`, `qubati.akrm+demo5`–`demo7`; optional dart-define.
- [`lib/core/utils/dev_database_seeder.dart`](lib/core/utils/dev_database_seeder.dart): export + `DevDatabaseSeeder` typedef alias.
- Onboarding store beat **Try with Demo Store** / **تجربة متجر افتراضي** + report dialog; Settings **Reset sample store data** bento (release-visible).
- [`demo_seed_report_dialog.dart`](lib/presentation/shared/widgets/demo_seed_report_dialog.dart), ARB EN+AR, tests, [`docs/contest_demo.md`](docs/contest_demo.md), [`tool/demo_seed_emails.md`](tool/demo_seed_emails.md), [`docs/qa/gate4_device_runbook.md`](docs/qa/gate4_device_runbook.md).

### Architecture / decisions
Presentation calls seeder directly (existing exception). Perf seed + empty clear stay `kDebugMode`. Neutral generated names: `Sample Store` / `متجر نموذجي`. Capture target: single `Mohamed` / `محمد`.

### Ops / verification
```bash
flutter test test/core/utils/dev_database_seeder_test.dart \
  test/core/utils/demo_seed_emails_test.dart \
  test/presentation/screens/onboarding/onboarding_store_beat_test.dart
```

### Status
Release evaluators can seed from onboarding or Settings without debug tools. Debug Developer Tools still offers perf seed + wipe.

## 2026-08-23 — Sample store: ledger beat CTA + USD

### Context
Move demo seed CTA from store beat to first-ledger beat (replacing Suppliers). Foreign judges should see USD amounts, not YER from prior Look-beat currency choice.

### Done
- [`onboarding_ledger_beat.dart`](lib/presentation/screens/onboarding/widgets/onboarding_ledger_beat.dart): **Try with Demo Store** chip replaces Suppliers; completes onboarding after seed.
- [`onboarding_store_beat.dart`](lib/presentation/screens/onboarding/widgets/onboarding_store_beat.dart): removed duplicate CTA.
- [`demo_store_seeder.dart`](lib/core/utils/demo_store_seeder.dart): all txns `USD`; sets `defaultCurrency=USD`, `isMultiCurrencyEnabled=false` on seed.
- Tests + [`docs/contest_demo.md`](docs/contest_demo.md) USD note.

### Status
Onboarding demo path: ledger beat → sample store → home. Capture line: “Mohamed owes 500” = **50000** minor ($500.00).

## 2026-08-23 — Closing Agent Cinematic Studio

### Context
Elevate the Closing Agent idle/entry screen to Khazna Lapis Lux cinematic quality: emissive ambient well, specular-glass intent satellites, and a floating composer dock — aligned with the SmartBricks reference (room light + glass, not blue-filled UI).

### Done
- Tokens: [`app_glows.dart`](lib/app/theme/app_glows.dart) `glowWell`, `studioWellDark/Light`, `glowWellFloor`; [`app_colors.dart`](lib/app/theme/app_colors.dart) `specularRazorDark/Light`.
- Primitives: [`khazna_radial_well.dart`](lib/presentation/shared/widgets/khazna_radial_well.dart), [`khazna_specular_panel.dart`](lib/presentation/shared/widgets/khazna_specular_panel.dart).
- Idle studio: [`closing_agent_idle_studio.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_idle_studio.dart) — vault ring + brand mark, orbital/compact satellites, keyboard-hide.
- Screen re-stack: [`closing_agent_screen.dart`](lib/presentation/screens/closing_agent/closing_agent_screen.dart) full-bleed well (dims to 0.35 non-idle), floating dock.
- Composer glass dock: [`closing_agent_composer.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_composer.dart) — single `BackdropFilter` σ=16.
- Design system §5.6: fourth glass context + ambient-well vs CTA-halo distinction.
- Tests: `closing_agent_idle_studio_test.dart`, `khazna_studio_primitives_test.dart` (13 widget tests green with composer/l10n).

### Architecture / decisions
- Lapis Law preserved: well = BoxShadow emission only; one CTA halo on Send (idle) via existing `ownsPrimaryGlow` handoff.
- Satellites use fake glass (no per-card `BackdropFilter`); composer is the sole blur on route.
- No new packages; no fake KPI charts.

### Ops / verification
```bash
flutter test test/presentation/screens/closing_agent/widgets/closing_agent_idle_studio_test.dart \
  test/presentation/shared/widgets/khazna_studio_primitives_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_composer_test.dart \
  test/presentation/screens/closing_agent/closing_agent_l10n_test.dart
```

### Status
Idle studio shipped. Confirm/desk/ritual cards unchanged. Manual device pass recommended for dark/light, RTL, reduce-motion, keyboard.

## 2026-08-23 — Closing Agent Voice Chamber

### Context
Turn the Closing Agent composer mic into a Khazna Voice Chamber: hold morphs the glass dock’s inner row into an isolated harmonic ribbon with slide-up-to-cancel, precision haptics, reduce-motion fallback, and a chrome-less ink field — without new packages or scaffold rebuilds.

### Done
- Optional amplitude: [`voice_capture.dart`](lib/core/utils/voice_capture.dart) `VoiceRecorder.amplitude()` maps `onAmplitudeChanged` dB → 0..1; [`closing_mic_hold_session.dart`](lib/core/utils/closing_mic_hold_session.dart) exposes stream only while recording.
- Voice chamber: [`closing_agent_voice_chamber.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_voice_chamber.dart) — `_HarmonicRibbonPainter` (3 sine polylines, lapis stroke-only), `RepaintBoundary`, static 3-bar reduce-motion fallback, elapsed timer (20s cap), cancel hints.
- Composer morph: [`closing_agent_composer.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_composer.dart) — stateful inner-row morph, `_ComposerInkField` (transparent, no lapis focus ring), slide-up cancel at 64dp, glow handoff (mic steals `ctaRest` from Send while recording), haptic map (`longPress` / `selection` / `light`).
- Screen wiring: [`closing_agent_screen.dart`](lib/presentation/screens/closing_agent/closing_agent_screen.dart) passes `amplitudeStream` when `_mic.isRecording`.
- L10n: `closingAgentMicSlideToCancel`, `closingAgentMicReleaseToCancel`, `closingAgentMicRecordingElapsed` in [`app_en.arb`](lib/core/l10n/app_en.arb) / [`app_ar.arb`](lib/core/l10n/app_ar.arb).
- Tests: extended [`closing_agent_composer_test.dart`](test/presentation/screens/closing_agent/widgets/closing_agent_composer_test.dart), new [`closing_agent_voice_chamber_test.dart`](test/presentation/screens/closing_agent/widgets/closing_agent_voice_chamber_test.dart); amplitude fakes in voice_capture + mic session tests.

### Architecture / decisions
- Lapis Law: ribbon is hairline stroke + whisper alpha only; recording CTA halo on mic core, not Send; cancel hint uses `debt` text only.
- One `BackdropFilter` on composer dock unchanged; ticker isolated in chamber (`didChangeDependencies` for reduce-motion).
- Screen retains `ClosingMicHoldSession` ownership; composer owns pointer choreography only. No `audio_flux` / waveform packages.

### Ops / verification
```bash
flutter test test/presentation/screens/closing_agent/widgets/closing_agent_composer_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_voice_chamber_test.dart \
  test/core/utils/voice_capture_test.dart \
  test/core/utils/closing_mic_hold_session_test.dart \
  test/presentation/screens/closing_agent/closing_agent_l10n_test.dart
```

### Status
Voice Chamber shipped on composer hold path. Confirm/desk/ritual unchanged. Manual device pass recommended for hold-to-talk, slide-up cancel, RTL cancel copy, reduce-motion static ribbon, 20s auto-submit.

## 2026-08-24 — Confirm Vault Card

### Context
Redesign `AgentConfirmCard` to match reference-grade understated luxury: squircle obsidian shell, fading dot-matrix atmosphere, intent metadata chips, hero name, hairline separator, and amount + CTA footer — plus composer ink polish.

### Done
- Vault shell: [`agent_confirm_card.dart`](lib/presentation/screens/closing_agent/widgets/agent_confirm_card.dart) — `_ConfirmVaultShell` (squircle `radiusLg`, gradient fill, specular catch-light, glass hairline, dark breath glow preserved).
- Dot matrix: [`closing_agent_fade_dot_matrix.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_fade_dot_matrix.dart) — single-pass `_FadeDotMatrixPainter` in `RepaintBoundary`.
- Hierarchy: intent badge + top Skip pill, `titleLarge` hero, supporting item/note, picker chips restyled, footer amount (`amountLarge`) + compact primary CTA.
- L10n: `closingAgentIntentDebt/Payment/NewAccount/Ledger/Statement` in EN+AR ARB.
- Composer: [`closing_agent_composer.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_composer.dart) — `bodyMedium` ink field, mic/field hairline separator.
- Tests: extended [`agent_confirm_card_test.dart`](test/presentation/screens/closing_agent/widgets/agent_confirm_card_test.dart), new [`closing_agent_fade_dot_matrix_test.dart`](test/presentation/screens/closing_agent/widgets/closing_agent_fade_dot_matrix_test.dart).

### Architecture / decisions
- Lapis Law: CTA remains monochrome + `ctaRest` glow; chips use lapis hairline only when selected. No new packages or `BackdropFilter` on confirm card.
- Confirm logic (`_factsFor`, `_confirmEnabled`, TTS) unchanged. Skip moved from full-width secondary to top micro-pill.

### Ops / verification
```bash
flutter test test/presentation/screens/closing_agent/widgets/agent_confirm_card_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_fade_dot_matrix_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_composer_test.dart
```

### Status
Confirm vault card shipped. Manual device pass recommended for dark/light, RTL footer mirroring, reduce-motion static dots, debt/payment semantic colors.

## 2026-08-24 — Idle Seal Ceremony

### Context
Make Closing Agent idle feel ceremonial from first paint: animated vault ring, a unique Close Today seal beside example satellites (fills and submits the close-day goal), and a quieter composer ink field with focus underline.

### Done
- Vault ring: [`closing_agent_idle_studio.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_idle_studio.dart) — `_VaultHero` stateful with draw-on (~900ms) + 14s catch-light loop; static under `MediaQuery.disableAnimationsOf`; `RepaintBoundary` + `_VaultRingPainter` with `drawProgress` / `highlightPhase`.
- Close Today seal: `_CloseTodaySeal` — elongated squircle, lapis hairline + specular fill (no blue fill/glow), crescent icon, compact wrap below examples / orbital centered under subtitle; `onCloseToday` callback.
- Screen wiring: [`closing_agent_screen.dart`](lib/presentation/screens/closing_agent/closing_agent_screen.dart) — `_onCloseToday()` fills composer with `closingAgentCloseTodayGoal` then `submitGoal`.
- Composer ink: [`closing_agent_composer.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_composer.dart) — `_ComposerInkField` focus underline (0.5px `borderSubtle`, RTL-safe grow), `inkPrimary` caret, looser hint tracking.
- L10n: `closingAgentCloseToday`, `closingAgentCloseTodayGoal`, `closingAgentCloseTodaySemantics` in EN+AR ARB.
- Tests: extended [`closing_agent_idle_studio_test.dart`](test/presentation/screens/closing_agent/widgets/closing_agent_idle_studio_test.dart), [`closing_agent_composer_test.dart`](test/presentation/screens/closing_agent/widgets/closing_agent_composer_test.dart).

### Architecture / decisions
- Lapis Law: seal distinguished by shape + hairline + motion, not `ctaRest` / `glowMd`. Send still owns idle CTA halo.
- Examples fill only; seal fill+submit enters `propose_closing_plan` path. Seal hidden when keyboard open (same as satellites).
- No new packages; one `BackdropFilter` unchanged on composer dock.

### Ops / verification
```bash
flutter gen-l10n
flutter test test/presentation/screens/closing_agent/widgets/closing_agent_idle_studio_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_composer_test.dart
```
14 tests passing.

### Status
Idle Seal Ceremony shipped. Manual device pass recommended for vault draw-on, seal whisper highlight, reduce-motion static ring, RTL underline grow, Close Today submit flow.

## 2026-08-24 — Idle Ceremony Punch + Quill Field

### Context
First idle ceremony shipped but felt static on device: 14s catch-light was below perception, vault draw was hidden behind fade-in, seal resembled example chips, composer underline only appeared on focus.

### Done
- Vault: [`closing_agent_idle_studio.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_idle_studio.dart) — `_VaultHero` unwrapped from `FadeSlideTransition`; 600ms draw-on (`animationXSlow`) + one 2.4s catch-light sweep along arc then rest; brand mark scales `0.92→1.0`; haptic on draw complete; wider/brighter highlight segment.
- Seal: `_CloseTodaySeal` — 400ms delayed entrance (fade + scale `0.96→1.0`), painted `_CrescentGlyph`, 1px lapis hairline, one-shot 800ms perimeter catch-light then freeze; killed 10s border pulse.
- Composer: [`closing_agent_composer.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_composer.dart) — always-on 36% writing ledge at idle; grows to 100% on focus in 180ms; 1.5px caret; hint fades when focused-and-empty.
- Tests: updated [`closing_agent_idle_studio_test.dart`](test/presentation/screens/closing_agent/widgets/closing_agent_idle_studio_test.dart), [`closing_agent_composer_test.dart`](test/presentation/screens/closing_agent/widgets/closing_agent_composer_test.dart).

### Architecture / decisions
- Cinematic-but-fast: opening phrase ≤3s total, then quiet — no infinite ambient loops.
- Lapis Law preserved: seal hairline + traveling catch only; Send still owns idle CTA halo. No new packages.
- Reduce-motion: static vault ring + immediate seal visibility.

### Ops / verification
```bash
flutter test test/presentation/screens/closing_agent/widgets/closing_agent_idle_studio_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_composer_test.dart
```
14 tests passing.

### Status
Idle ceremony punch shipped. Hot-restart Closing Agent idle on device to verify vault draw, seal entrance at ~400ms, writing ledge at idle, focus grow.

## 2026-08-24 — Idle ceremony ring loop + seal glyph/hairline

### Context
On device the vault catch-light vanished after one sweep; Close Today crescent was half-clipped by the pill caps; hairline gleam was drawn on the outer path inside a clip, so corners went dark.

### Done
- Vault: [`closing_agent_idle_studio.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_idle_studio.dart) — after 600ms draw-on, catch-light **repeats** on a 4s chapter (2.4s full-orbit sweep, 1.6s rest). Reduce-motion still static.
- Seal silhouette: elongated squircle (`radiusLg`) instead of stadium `radiusCircular`, extra horizontal padding, clip only the specular fill — crescent no longer sits inside the pill cap.
- Crescent: filled moon via `Path.combine` difference, 18×18 inset canvas (`close-today-crescent`).
- Hairline: inset path (stroke fully inside), persistent 0.45 lapis hairline around **all four corners**, wrapping gleam (~22% of perimeter) looping every 2.4s.

### Architecture / decisions
- Periodic chapter, not a 14s crawl and not a one-shot. Send still owns idle CTA halo. No new packages.

### Ops / verification
```bash
flutter test test/presentation/screens/closing_agent/widgets/closing_agent_idle_studio_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_composer_test.dart
```
14 tests passing.

### Status
Hot-restart Closing Agent idle: vault ring should keep orbiting; Close Today moon fully visible; lapis hairline continuous through corners.

## 2026-08-24 — Close-Day Taskmaster + Ceremonial Report

### Context
Close-day was three disconnected surfaces (Gemini plan checklist, 3-row ritual progress, static report). Plan: one device-owned task graph where plan = execution log, honest step reveals, ceremonial report finale.

### Done
- Domain: [`closing_task_id.dart`](lib/domain/enums/closing_task_id.dart) — 13-step `ClosingTaskId` + `ClosingTaskOrder`.
- State/controller: [`closing_agent_state.dart`](lib/presentation/providers/closing_agent_state.dart), [`closing_agent_controller.dart`](lib/presentation/providers/closing_agent_controller.dart) — `ritualTasksDone` / `ritualTaskCurrent` / `ritualBackupStatus`; inline summary → backup → shortlist with staggered honest reveals; sync report-task completion on `_showRitualReport`.
- UI: [`closing_agent_taskmaster.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_taskmaster.dart) — plan review, executing rail, sealed rail, Approve plan CTA, lapis catch-light on active segment.
- Wired: [`closing_agent_screen.dart`](lib/presentation/screens/closing_agent/closing_agent_screen.dart) (plan + desk), [`closing_ritual_panel.dart`](lib/presentation/screens/closing_agent/widgets/closing_ritual_panel.dart) (running + report).
- Report: [`closing_ritual_report_card.dart`](lib/presentation/screens/closing_agent/widgets/closing_ritual_report_card.dart) — vault ring draw-on, `AnimatedFlipCounter`, staggered reveal, TTS + haptic.
- ARB EN+AR: task titles, live captions, `closingAgentApprovePlan`, `closingTaskmasterSealed`, report count units.
- Tests: [`closing_agent_taskmaster_test.dart`](test/presentation/screens/closing_agent/widgets/closing_agent_taskmaster_test.dart); updated [`closing_agent_controller_test.dart`](test/presentation/providers/closing_agent_controller_test.dart), [`closing_ritual_report_card_test.dart`](test/presentation/screens/closing_agent/widgets/closing_ritual_report_card_test.dart).

### Architecture / decisions
- Gemini `propose_closing_plan` titles are narrative only; device graph is canonical. Desk row 11 stays `current` until merchant approves/skips SMTP. Lapis Law preserved (rail gleam/border only). No new animation packages.

### Ops / verification
```bash
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter test test/presentation/screens/closing_agent/widgets/closing_agent_taskmaster_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_ritual_report_card_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart
```
46 tests passing.

### Status
Taskmaster + ceremonial report shipped. `AgentPlanChecklist` / `ClosingRitualProgress` superseded in production paths (widgets retained for legacy test). Device-verify: approve plan → watch 13 rows → desk pause → sealed report choreography.

## 2026-08-24 — Desk overflow + send preflight before desk

### Context
On device, Collections Desk overflowed (taskmaster + desk in a `Column` left ~45px for the panel). Google openid/send permission sheet appeared during Approve & send instead of before the desk task.

### Done
- [`closing_agent_taskmaster.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_taskmaster.dart) — `compact` mode (slim rail + current step) for desk phase; `blocked` row state + `closingTaskCaptionSendAuth`.
- [`closing_agent_screen.dart`](lib/presentation/screens/closing_agent/closing_agent_screen.dart) — desk uses compact taskmaster; listens for Drive grant completion → `resumeCollectionsDeskAfterPreflight()`.
- [`closing_agent_controller.dart`](lib/presentation/providers/closing_agent_controller.dart) — `_preflightCollectionsSend()` before `_openCollectionsDesk`; `ritualDeskPreflightPending`; `skipOutreach()` from preflight; `resumeCollectionsDeskAfterPreflight()`.
- [`closing_ritual_panel.dart`](lib/presentation/screens/closing_agent/widgets/closing_ritual_panel.dart) — blocked compact taskmaster + Skip outreach while preflight pending.

### Ops / verification
```bash
flutter test test/presentation/providers/closing_agent_controller_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_taskmaster_test.dart
```
43 tests passing.

### Status
Hot-restart close-day with overdue accounts: grant sheet should appear before desk opens; desk should scroll without overflow.

## 2026-08-25 — One-gate close: plan CTAs + live desk dispatch

### Context
Close already had plan confirm, then the ritual, then a second HITL **Approve & send** on Collections Desk. Contest Taskmaster one-gate: plan confirm is outreach consent.

### Done
- [`closing_agent_taskmaster.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_taskmaster.dart) — plan review disclosure + **Confirm & send** / **Confirm without sending** (no Skip-that-cancels).
- [`closing_agent_screen.dart`](lib/presentation/screens/closing_agent/closing_agent_screen.dart) — Confirm & send → `confirm(..., sendOutreach: true)`; Confirm without sending → `sendOutreach: false`.
- [`closing_agent_controller.dart`](lib/presentation/providers/closing_agent_controller.dart) — persist send intent; auto-dispatch SMTP after desk on send; skip desk+SMTP on no-send; leftover Hybrid E tests park desk with `autoDispatch: false`.
- [`collections_desk_panel.dart`](lib/presentation/screens/closing_agent/widgets/collections_desk_panel.dart) — SMTP footer is Sending i of N only; leftover Hybrid E keeps Approve / Skip / Open WhatsApp.
- ARB EN+AR: `closingAgentConfirmAndSend`, `closingAgentConfirmWithoutSending`, `closingAgentPlanOutreachConsent`; `closingTaskOpenDesk` = Send collections.
- Docs: [`roadmap_v2.md`](docs/roadmap_v2.md) consent lines; [`contest_demo.md`](docs/contest_demo.md) shot ~2:50; [`agent.py`](agent/closing_agent/agent.py) INSTRUCTION.

### Architecture / decisions
- Default `sendOutreach: false` so a stray `confirm(plan)` cannot silent-send.
- Preview=sent still holds at compose time; merchant is not required to gate on reading each draft.
- Hybrid E leftover must still never open `wa.me` on the SMTP lead path.

### Ops / verification
```bash
flutter gen-l10n
flutter test test/presentation/screens/closing_agent/widgets/closing_agent_taskmaster_test.dart \
  test/presentation/screens/closing_agent/widgets/collections_desk_panel_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart
```

### Status
One-gate close shipped in code. Film Confirm & send on the plan, then live desk progress + inbox — not a second Approve.

## 2026-08-25 — Close-day Drive grant copy

### Context
Merchants who sign in with Google but skip Drive consent saw misleading close-day copy: “No internet connection. Drive backup will resume when you're back online.” `silent_sign_in_failed` was classified as offline queue via `isTransientCloudSyncFailure`, not as a grant gap.

### Done
- [`closing_backup_status.dart`](lib/domain/enums/closing_backup_status.dart) — `ClosingBackupStatus.grantRequired`.
- [`map_closing_backup_status.dart`](lib/application/agent/map_closing_backup_status.dart) — shared mapper; grant codes (`silent_sign_in_failed`, `drive_scopes_not_authorized`, `drive_offline_grant_failed`) → `grantRequired`; wired in [`run_closing_ritual_use_case.dart`](lib/application/agent/run_closing_ritual_use_case.dart) and [`closing_agent_controller.dart`](lib/presentation/providers/closing_agent_controller.dart).
- ARB EN+AR: `closingRitualBackupGrantMissing`; action reuses `backupDriveOfflineGrantAction`.
- UI: [`closing_ritual_report_card.dart`](lib/presentation/screens/closing_agent/widgets/closing_ritual_report_card.dart) grant banner + Complete now; [`closing_ritual_panel.dart`](lib/presentation/screens/closing_agent/widgets/closing_ritual_panel.dart) `onGrantDrive` → `completeDriveAuthorization()`; [`closing_agent_taskmaster.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_taskmaster.dart) live caption.
- Tests: [`map_closing_backup_status_test.dart`](test/application/agent/map_closing_backup_status_test.dart), [`run_closing_ritual_use_case_test.dart`](test/application/agent/run_closing_ritual_use_case_test.dart), [`closing_ritual_report_card_test.dart`](test/presentation/screens/closing_agent/widgets/closing_ritual_report_card_test.dart); controller stub updated.

### Architecture / decisions
- Did **not** change `isTransientCloudSyncFailure` globally — background auto-backup still retries `silent_sign_in_failed` on cold start.
- Close-day mapper only distinguishes grant gap from true offline queue.

### Ops / verification
```bash
flutter gen-l10n
flutter test test/application/agent/map_closing_backup_status_test.dart \
  test/application/agent/run_closing_ritual_use_case_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_ritual_report_card_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart
```
55 tests passing in affected suites.

### Status
Grant-missing close-day path shows honest copy + Complete now; no false offline message.

## 2026-08-25 — Professional demo-store ledger

### Context
Sample-store seed put goods in transaction `description` and left `itemName` null, so contact ledgers showed **—** instead of item names. Fixture also had only one debt per contact with no realistic payment history.

### Done
- [`demo_store_seeder.dart`](lib/core/utils/demo_store_seeder.dart) — rewrote `_buildTransactions`: goods in `itemName`, invoice-style notes in `description` (`INV-…` / `فاتورة …`), `Payment` / `سداد` on payments. 4–5 events per contact with FIFO-cleared older invoices on Omar/Yousef. Today strip: Mohamed `Mineral water` + Yousef `Eggs` (not sugar — film capture still adds sugar live).
- Preserved contest invariants: net balances (~$801.50 / $600 / $80 / $400 / $350 / $150 / $37), tone bands (firm/reminder/friendly + Nadia cap), ranked Top 5 vs text-only Omar/Yousef, 2 today `createdAt` rows.
- [`dev_database_seeder_test.dart`](test/core/utils/dev_database_seeder_test.dart) — debts require `itemName` + `INV-` notes; ≥3 txns + payment per contact; collections rank tail assertion.

### Architecture / decisions
- `_TxnSpec` uses named fields (`itemName`, `description`) so goods and notes cannot drift again.
- No contact/email/phone/currency changes; perf seeder untouched.

### Ops / verification
```bash
flutter test test/core/utils/dev_database_seeder_test.dart
```
10 tests passing.

### Status
Reset sample store / Try with Demo Store now shows professional ledgers with item names and mixed debt/payment history.

## 2026-08-25 — Close-day plan ack + ceremonial report

### Context
The closing plan was silent (Gemini’s long narrative suppressed, nothing spoken in its place) and still dumped as on-screen essay. The report ceremony spoke only “Day closed. N debts. M payments” — never that the books were safe on Drive.

### Done
- Plan ack: [`closing_agent_controller.dart`](lib/presentation/providers/closing_agent_controller.dart) speaks `closingAgentSpeakPlanReady` (EN/AR ARB) instead of Gemini narrative; light haptic; mute still silent. [`closing_agent_screen.dart`](lib/presentation/screens/closing_agent/closing_agent_screen.dart) hides the narrative sliver while a plan is pending.
- Cloud Run instruction: [`agent.py`](agent/closing_agent/agent.py) — at most one clerk sentence for `propose_closing_plan`; never enumerate steps; device owns spoken ack.
- Report speech: [`closing_report_speakable.dart`](lib/core/utils/closing_report_speakable.dart) — seal + books + status-aware Drive safety + overdue if any. Honest: queued/grant/unsigned/failed never claim Drive is already saved.
- Ceremony: [`closing_ritual_report_card.dart`](lib/presentation/screens/closing_agent/widgets/closing_ritual_report_card.dart) — vault catch interpolates `glowXl` (uploaded) / `glowMd` (else); `light()` after draw; `tierUpgrade()` vs `transactionSaved()`; post-draw wait 450ms. No confetti, no extra BackdropFilter, no lapis fill.

### Architecture / decisions
- Overview on speech, 13 steps on the Taskmaster (Google conversation design). Peak–end is the report, not reading the plan.
- Clerk persona: ceremonial vault light, not carnival.

### Ops / verification
```bash
flutter gen-l10n
flutter test test/core/utils/closing_report_speakable_test.dart \
  test/core/utils/closing_report_speech_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_ritual_report_card_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart
```
53 tests passing in affected suites.

**Cloud Run redeploy required** so live Gemini stops enumerating plan steps in narrative.

### Status
Plan ack + vault report shipped on device. Redeploy `daftar-closing-agent` before filming.

## 2026-08-25 — Cloud Run redeploy (close-day plan ack instruction)

### Context
Device already speaks a one-sentence plan ack and hides Gemini’s essay. Live Gemini still needed the new `propose_closing_plan` instruction (never enumerate steps; device owns spoken ack).

### Done
- `gcloud run deploy --source=.` from [`agent/`](agent/) (not `adk deploy` — would wipe `main.py` email/TTS routes).
- Cost-lock `gcloud run services update` min 0 / max 2 both layers.
- Serving revision **`daftar-closing-agent-00049-9t8`**. URL `https://daftar-closing-agent-1487285471.us-central1.run.app`.
- Custom audiences still **3**. `/list-apps` → `["closing_agent"]`.

### Architecture / decisions
- Vertex `GOOGLE_CLOUD_LOCATION=global`, SA `agent-runner@…`, `--no-allow-unauthenticated`. Gmail secret remains file-mounted. No mailbox printed.

### Ops / verification
```bash
cd agent
gcloud run deploy daftar-closing-agent --source=. --project=daftar-closing-agent --region=us-central1 \
  --quiet --no-allow-unauthenticated --min=0 --max=2 --min-instances=0 --max-instances=2 --port=8000 \
  --service-account=agent-runner@daftar-closing-agent.iam.gserviceaccount.com \
  --update-env-vars=GOOGLE_GENAI_USE_VERTEXAI=TRUE,GOOGLE_CLOUD_PROJECT=daftar-closing-agent,GOOGLE_CLOUD_LOCATION=global \
  --update-secrets=/secrets/gmail-smtp-app-password=gmail-smtp-app-password:latest
gcloud run services update daftar-closing-agent \
  --project=daftar-closing-agent --region=us-central1 --quiet \
  --min=0 --max=2 --min-instances=0 --max-instances=2
# latestReadyRevisionName: daftar-closing-agent-00049-9t8
# Scaling: Auto (Min: 0, Max: 2); audience_count=3
curl -sS -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  https://daftar-closing-agent-1487285471.us-central1.run.app/list-apps
# → ["closing_agent"]
```

### Status
Live Cloud Run is on the plan-ack instruction. First Send after scale-to-zero is still a cold start.

## 2026-08-25 — Close-day report: today’s books + full clerk readout

### Context
The report card flip-counters and TTS treated today’s entry counts as generic “debts/payments,” then spoke “N overdue accounts are ready” and skipped prepared/sent/failed even when the desk had run. Arabic grant speech mixed Latin `Drive`, which Chirp misreads as a verb.

### Done
- Flip-counter units: [`app_en.arb`](lib/core/l10n/app_en.arb) / [`app_ar.arb`](lib/core/l10n/app_ar.arb) — `closingRitualReportDebtsUnit` / `PaymentsUnit` → “today's debts” / “ديون اليوم”.
- Speech script [`closing_report_speakable.dart`](lib/core/utils/closing_report_speakable.dart): today books → Drive safety → queue beat when `queueMetrics != null` (`{prepared} prepared, {sent} sent, {failed} failed`) → overdue remain only if metrics are null and `overdueCount > 0` → always `That's the close for today` / `هذا إقفال اليوم`.
- Speech Drive wording: EN `Google Drive`; AR grant `درايف` (no Latin `Drive`). Opened omitted. Currency totals, reminder/PDF policy still visual-only.

### Architecture / decisions
- Device-authored TTS only — **no Cloud Run redeploy**.
- Dedicated `closingRitualSpeakQueue` ARB; do not glue on-screen `{count} prepared` fragments.
- If the desk ran, do not also say overdue-are-ready.

### Ops / verification
```bash
flutter gen-l10n
flutter test test/core/utils/closing_report_speakable_test.dart \
  test/core/utils/closing_report_speech_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_ritual_report_card_test.dart
```
14 tests passing. Report card still matches `0 sent` / `Nothing to collect`.

### Status
Close-day report labels today’s books on screen and speaks the full clerk readout. No backend change.

## 2026-08-25 — Closing Agent: clerk-at-the-books wait + ink-well composer

### Context
After sending a command, the Closing Agent body fell back to four generic shimmer cards and dimmed the radial well, while the composer showed only a Material spinner. That read as list loading, not a clerk working.

### Done
- Shared vault seal: [`closing_agent_vault_seal.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_vault_seal.dart) — `ClosingAgentVaultSeal` (idle draw-then-catch + working continuous ink sweep), `ClosingAgentVaultLoadingArc` for send button.
- Working studio: [`closing_agent_working_studio.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_working_studio.dart) replaces `_RunningSkeleton` in [`closing_agent_screen.dart`](lib/presentation/screens/closing_agent/closing_agent_screen.dart); radial well stays at full opacity for `running`.
- Idle studio uses shared seal; ARB `closingAgentSpeakWorking`, `closingAgentWorkingElapsed`, composer hint `Write in the ledger` / `اكتب في الدفتر`.
- Ink-well composer: [`closing_agent_composer.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_composer.dart) — 1.5px lapis dock ring on focus, lapis ledge, 48dp field, working hint while running, vault arc on send (no body spinner).

### Architecture / decisions
- Khazna v3 only: monochrome shimmer removed from agent wait; lapis stroke/glow, no lapis fill, no new animation packages.
- Honest copy — no fake “Searching…” phases; elapsed timer after 3s only.
- Ritual Taskmaster wait unchanged.

### Ops / verification
```bash
flutter gen-l10n
flutter test test/presentation/screens/closing_agent/widgets/closing_agent_working_studio_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_composer_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_idle_studio_test.dart \
  test/presentation/screens/closing_agent/closing_agent_l10n_test.dart
```
20 tests passing.

### Status
Closing Agent `running` phase is a ceremonial clerk-at-the-books scene with an ink-well composer. Device-only; no Cloud Run change.

## 2026-08-25 — Closing Agent: top lumen glow, no wait timer

### Context
The elapsed-seconds counter (`Working · Ns`) made short turns feel slower. User asked for a Gemini-style top-of-screen living glow that exhales when the answer lands, without the timer.

### Done
- Removed elapsed timer/UI from [`closing_agent_working_studio.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_working_studio.dart); deleted `closingAgentWorkingElapsed` ARB.
- New [`closing_agent_working_glow.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_working_glow.dart): ~160dp top lapis crest (`BoxShadow` lerp `glowLg`↔`glowXl`, 2.4s breath), 1.5px top hairline, fade in 300ms / exhale out 450ms when `phase != running`; wired in [`closing_agent_screen.dart`](lib/presentation/screens/closing_agent/closing_agent_screen.dart).
- Composer polish: `glowXs` on focused ink ledge, 0.5px lapis dock hairline while running, `spacingSm` vertical field padding.

### Architecture / decisions
- Gemini **structure** (top crest, smooth fade-out), not Google’s four-color rainbow — Lapis Law preserved, no new packages, no second `BackdropFilter`.
- Reduce-motion: static `glowMd`, 100ms fade only.

### Ops / verification
```bash
flutter gen-l10n
flutter test test/presentation/screens/closing_agent/widgets/closing_agent_working_studio_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_working_glow_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_composer_test.dart
```
13 tests passing.

### Status
Wait is vault + clerk line + top lumen glow; timer removed. Device-only.

## 2026-08-25 — Closing Agent: professional horizon lumen

### Context
The first top-glow was a clipped oval sitting above the screen, so the light smeared instead of reading as a horizon. Breath also never drove paint.

### Done
- [`closing_agent_working_glow.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_working_glow.dart): wide ambient band on the top edge + narrower center core (`BoxShadow` layers, lapis emission only); 1.5px hairline peaks at center and dies at the corners (stroke shader, not fill); breath now rebuilds the crest (`Listenable.merge`).

### Architecture / decisions
- Center-weighted, top-to-bottom falloff — Gemini structure, Khazna light. No gradient fill, no rainbow, no extra `BackdropFilter`.

### Ops / verification
```bash
flutter test test/presentation/screens/closing_agent/widgets/closing_agent_working_glow_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_working_studio_test.dart
```
5 tests passing.

### Status
Top lumen is a precise horizon, not a blob.

## 2026-08-25 — Closing Agent: one confirm for compound capture

### Context
A single utterance (`new ledger + Mohammed + 400`) produced three separate Confirm cards with no ID threading between steps. Merchants had to confirm three times and re-pick ledger/contact on later cards.

### Done
- [`group_capture_proposals.dart`](lib/application/agent/group_capture_proposals.dart): pure helper — bundle when 2+ pending capture tools; commit order ledger → contact → money/statement; `buildCaptureProposalTiles` for sliver layout.
- [`closing_agent_controller.dart`](lib/presentation/providers/closing_agent_controller.dart): `confirmCaptureBundle` sequential commit with `ledgerId`/`contactId` threading, mid-chain retry via `committedIds`, `cancelCaptureBundle` skips all remaining; `createIfMissing: false` on money after contact created in bundle.
- [`agent_capture_bundle_card.dart`](lib/presentation/screens/closing_agent/widgets/agent_capture_bundle_card.dart): one Khazna vault card with ordered fact rows and single CTA (`closingAgentConfirmAll` / create-and-record when contact+money).
- [`closing_agent_screen.dart`](lib/presentation/screens/closing_agent/closing_agent_screen.dart): bundle sliver when grouped length ≥ 2; singles and plan/WhatsApp unchanged.
- [`agent_speakable_lines.dart`](lib/presentation/screens/closing_agent/widgets/agent_speakable_lines.dart): `captureBundleSpeakable` — one TTS overview.
- ARB: `closingAgentConfirmAll` (EN `Record in the books` / AR `سجّل في الدفتر`).
- Tests: `group_capture_proposals_test.dart`, controller `confirmCaptureBundle` (order + failure partial commit), `agent_capture_bundle_card_test.dart`.

### Architecture / decisions
- Turn proposal list remains source of truth — no compound domain type. Providers still call `CommitAgentProposalUseCase` only. No Cloud Run change; composer unchanged.

### Ops / verification
```bash
flutter gen-l10n
flutter test test/application/agent/group_capture_proposals_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart --name confirmCaptureBundle \
  test/presentation/screens/closing_agent/widgets/agent_capture_bundle_card_test.dart
```
7 tests passing.

### Status
Compound capture is one card, one Confirm, threaded writes. Confirm-all across separate turns still out of scope.

## 2026-08-25 — Compound capture preview fix

### Context
The bundle card treated each step like a standalone Confirm card: existing-ledger chips and currency pickers appeared even when the bundle already creates Distributors + Mohammed, and Mohammed was shown twice.

### Done
- [`agent_capture_bundle_card.dart`](lib/presentation/screens/closing_agent/widgets/agent_capture_bundle_card.dart): sibling-aware rows — pending ledger caption on contact row; hide ledger/currency pickers when a create-ledger step exists; money row is amount-only when contact is in the bundle; currency picker at most once and only when multi-currency is on.
- [`closing_agent_controller.dart`](lib/presentation/providers/closing_agent_controller.dart): `_bundleLedgerOverride` ignores stale `ledgerIdByProposal` picks on contact/money when the bundle includes `proposeCreateLedger`.
- Tests: expanded [`agent_capture_bundle_card_test.dart`](test/presentation/screens/closing_agent/widgets/agent_capture_bundle_card_test.dart); controller stale-ledger pick test in `confirmCaptureBundle` group.

### Architecture / decisions
- Preview-only logic stays on `AgentCaptureBundleCard`; single [`AgentConfirmCard`](lib/presentation/screens/closing_agent/widgets/agent_confirm_card.dart) unchanged. No Cloud Run.

### Ops / verification
```bash
flutter test test/presentation/screens/closing_agent/widgets/agent_capture_bundle_card_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart --name confirmCaptureBundle
```

### Status
Compound preview reads ledger → account → amount; confirm cannot route into a stale existing ledger.

## 2026-08-25 — Close-the-day ceremony (judging-panel pass)

### Context
Close-the-day is the film climax for judging. Taskmaster used a flat `DaftarCard` with no Skip; the report showed a brand mark, not a verified seal; composer caret was monochrome.

### Done
- [`closing_agent_vault_chrome.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_vault_chrome.dart): Confirm-grade vault shell (squircle, fade-dot, specular razor, glass rim, optional breath on plan review dark).
- [`closing_agent_taskmaster.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_taskmaster.dart): all modes wrapped in vault chrome; plan review Skip CTA; stronger current-row ink.
- [`closing_agent_screen.dart`](lib/presentation/screens/closing_agent/closing_agent_screen.dart): plan Skip → `cancel(proposalId)`.
- [`closing_ritual_report_card.dart`](lib/presentation/screens/closing_agent/widgets/closing_ritual_report_card.dart): one-shot verified seal — lapis ring draw → payment-green check → catch glow + `tierUpgrade` haptic.
- [`closing_agent_composer.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_composer.dart): lapis caret; quieter unfocused hint.
- Tests: [`closing_agent_taskmaster_test.dart`](test/presentation/screens/closing_agent/widgets/closing_agent_taskmaster_test.dart), [`closing_agent_vault_chrome_test.dart`](test/presentation/screens/closing_agent/widgets/closing_agent_vault_chrome_test.dart); existing report/composer tests retained.

### Architecture / decisions
- No new packages; no stock Lottie/confetti. Lapis Law preserved (glow/border only). Single-card Confirm/bundle unchanged. No Cloud Run.

### Ops / verification
```bash
flutter test test/presentation/screens/closing_agent/widgets/closing_agent_taskmaster_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_vault_chrome_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_ritual_report_card_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_composer_test.dart
```

### Status
Close-the-day reads as vault ceremony start → executing gleam → verified seal finish.

## 2026-08-25 — Verified seal handoff (lapis check → brand mark)

### Context
Report hero drew a payment-green check that never left; brand identity should land after the lock takes, matching idle vault seal language.

### Done
- [`closing_ritual_report_card.dart`](lib/presentation/screens/closing_agent/widgets/closing_ritual_report_card.dart): ring via shared `ClosingAgentVaultRingPainter`; lapis check draw → 160ms settle → reverse undraw → `DaftarBrandMark` (52dp) opacity/scale handoff during last 20% of undraw; `tierUpgrade` on land; reduce-motion shows final frame (ring + mark, no check).
- [`closing_ritual_report_card_test.dart`](test/presentation/screens/closing_agent/widgets/closing_ritual_report_card_test.dart): `DaftarBrandMark` present; motion ceremony pumps without throw.

### Architecture / decisions
Stroke-only lapis check (no fill). No Lottie. Report-hero only — Taskmaster/composer unchanged.

### Ops / verification
```bash
flutter test test/presentation/screens/closing_agent/widgets/closing_ritual_report_card_test.dart
```

### Status
Close-day finish: ring locks → lapis stamp → undraw → Daftar mark rests in the vault.

## 2026-08-25 — Floating composer: scroll under glass

### Context
Scrolling the Closing Agent panel showed a solid onyx band above the composer. The viewport was shrunk with bottom padding instead of letting content pass under the existing glass dock blur.

### Done
- [`closing_agent_screen.dart`](lib/presentation/screens/closing_agent/closing_agent_screen.dart): removed `Expanded` bottom padding; `dockScrollInset` threaded into `_AgentBody` / `_RunningBody`.
- Proposal `CustomScrollView`, [`closing_agent_idle_studio.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_idle_studio.dart), [`closing_agent_working_studio.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_working_studio.dart): `paddingBottom` on scroll views.
- [`collections_desk_panel.dart`](lib/presentation/screens/closing_agent/widgets/collections_desk_panel.dart): list bottom padding includes dock inset.

### Architecture / decisions
One `BackdropFilter` on composer unchanged; no scrim/fade above field. Content scrolls under glass; last tile still clears dock via scroll padding.

### Ops / verification
```bash
flutter test test/presentation/screens/closing_agent/widgets/closing_agent_composer_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_idle_studio_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_working_studio_test.dart \
  test/presentation/screens/closing_agent/widgets/collections_desk_panel_test.dart
```

### Status
Composer reads as floating glass over scrolling content, not a black slab.

## 2026-08-25 — Idle vault ring + chip alignment

### Context
First open of Closing Agent: vault catch-light snapped backward every chapter; example chips wrapped (`500` orphaned) due to 148dp orbital satellites; Arabic chip lacked a name.

### Done
- [`closing_agent_vault_seal.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_vault_seal.dart): continuous 2.4s full-orbit catch after draw-on (idle + working); no rest-gap gating.
- [`closing_agent_idle_studio.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_idle_studio.dart): single centered layout; dropped `_OrbitalLayout`; chips `maxLines: 1` / `softWrap: false`; Close today below.
- ARB: `Mohamed 500` / `Ahmed 200` (EN), `محمد 500` / `أحمد 200` (AR).
- Tests: idle studio + l10n updated.

### Status
Idle hero ring orbits smoothly; example chips stay one line with name + amount.

## 2026-08-25 — Backup screen: remove duplicate create CTA

### Context
First visit to cloud backup showed two “Create backup now” buttons — vault hero primary plus empty-history `EmptyState` CTA that vanished after the first backup.

### Done
- [`backup_history_section.dart`](lib/presentation/screens/settings/backup/widgets/backup_history_section.dart): empty history is icon + copy only; removed `onCreateBackup` and `EmptyState` CTA props.
- [`backup_screen.dart`](lib/presentation/screens/settings/backup/backup_screen.dart): dropped `onCreateBackup` wiring. Vault hero primary unchanged.

### Status
Single persistent create-backup action on first open.

## 2026-08-25 — Stage 5.6 HITL Architecture HUD (judging pass)

### Context
Judging panel needed the global Architecture HUD to expose agent routing, tool scoping, and proposal HITL states live on screen — without SequentialAgent, OpenAPI changes, or lapis fills.

### Done
- [`architecture_hud_provider.dart`](lib/presentation/providers/architecture_hud_provider.dart): `ArchitectureHudHitlStep` + `ArchitectureHudToolScope`; snapshot extends with phase, counts, desk stats, pinned `gemini-3.5-flash`; `visible` when toggle on (not chip-empty).
- [`daftar_architecture_hud.dart`](lib/presentation/shared/widgets/daftar_architecture_hud.dart): top-end compact instrument — routing line, scoped tools, four-station HITL rail, pending/recorded strip, SMTP sent last-8; Khazna monochrome + lapis border/glow only.
- ARB EN+AR: rail labels, scope labels, routing/pending copy; settings subtitle mentions HITL path.
- Tests: [`architecture_hud_provider_test.dart`](test/presentation/providers/architecture_hud_provider_test.dart), [`daftar_architecture_hud_test.dart`](test/presentation/shared/widgets/daftar_architecture_hud_test.dart) — step mapping, pinned model, never `delivered`.

### Architecture / decisions
Honest mid-day path Propose → Confirm → Commit; close-day adds Rank + Sent via desk. B-Prime / scoped sub-agents deferred until HUD verified. Stock `POST /run` / `AgentTurnResult` unchanged.

### Ops / verification
```bash
flutter gen-l10n
flutter test test/presentation/providers/architecture_hud_provider_test.dart \
  test/presentation/shared/widgets/daftar_architecture_hud_test.dart
```
27 tests passed.

### Status
§5.6 HUD instrument ready for judging-panel demo. B-Prime remains out of scope.

## 2026-08-25 — B-Prime verdict: single-agent lock + Stage 6 architecture packaging

### Context
After HUD verification, evaluated Coordinator + scoped sub-agents (B-Prime) vs Taskmaster rubric. Decision: keep one `root_agent` LlmAgent; package HITL + frozen catalog as the architecture story for judges.

### Done
- [`docs/architecture/contest_architecture.md`](docs/architecture/contest_architecture.md): mermaid diagram (Flutter · Cloud Run · Gemini · Drift · SMTP), HITL paths, eight-tool table, SequentialAgent rejection rationale.
- [`README.md`](README.md): Architecture section for judges — HITL, HUD, frozen catalog, no B-Prime this submission.
- [`agent/README.md`](agent/README.md): Single-agent lock section + test references.
- [`docs/plan.md`](docs/plan.md): v2.8 close path + link to contest architecture doc.
- [`agent/tests/test_single_agent_lock.py`](agent/tests/test_single_agent_lock.py): CI guard — no SequentialAgent/AgentTool imports; `root_agent` is single LlmAgent with eight tools.

### Architecture / decisions
No changes to [`agent/closing_agent/agent.py`](agent/closing_agent/agent.py), OpenAPI, or Flutter envelope. B-Prime deferred post-contest unless ADK harness proves proposal parsing survives coordinator routing.

### Ops / verification
```bash
cd agent && python3 -m pytest tests/test_single_agent_lock.py tests/test_tool_catalog_freeze.py -q
```

### Status
Stage 6 diagram + README packaging started. Video / Devpost remain Stage 6 follow-ups.

## 2026-08-25 — HUD instrument + composer polish (Khazna v3)

### Context
Elevate the Architecture HUD to a Khazna flight-instrument (specular squircle, trace rail, metadata pills) and polish the Closing Agent composer by removing yellow ink-ledge underlines, spell-check marks, and focus dock border — cursor-only focus per plan.

### Done
- [`lib/presentation/shared/widgets/daftar_architecture_hud.dart`](lib/presentation/shared/widgets/daftar_architecture_hud.dart): `_ArchitectureHudChrome` (squircle, glass fill, specular rim, lapis border/glow only); `_RoutingHeader` with status orb + metadata chips; `_ScopeBand` monochrome pill; `_HitlTraceRail` with `CustomPainter` baseline and trace nodes; `_EmailSentRow`; `maxWidth` 296; `overlayKey` / `IgnorePointer` / semantics preserved.
- [`lib/presentation/screens/closing_agent/widgets/closing_agent_composer.dart`](lib/presentation/screens/closing_agent/widgets/closing_agent_composer.dart): removed `_fieldFocused` and dock border reaction on focus; removed ink ledge underline; disabled spell-check/autocorrect/suggestions; lapis cursor + `TextSelectionTheme` for selection; quieter hint via `inkSecondary`.
- [`test/presentation/shared/widgets/daftar_architecture_hud_test.dart`](test/presentation/shared/widgets/daftar_architecture_hud_test.dart): chip/routing split expectations; `CustomPaint` trace rail; pending/recorded row.
- [`test/presentation/screens/closing_agent/widgets/closing_agent_composer_test.dart`](test/presentation/screens/closing_agent/widgets/closing_agent_composer_test.dart): focus test renamed — no dock border change; spell-check disabled smoke.

### Architecture / decisions
Presentation-only; `architecture_hud_provider` / OpenAPI unchanged. No second `BackdropFilter` on HUD. Lapis Law preserved — monochrome fill, lapis border/glow only. Running `/run` still uses existing lapis dock ring.

### Ops / verification
```bash
flutter test test/presentation/shared/widgets/daftar_architecture_hud_test.dart \
  test/presentation/screens/closing_agent/widgets/closing_agent_composer_test.dart
```
16 tests passed.

### Status
HUD instrument + composer polish complete for judging demo. No new ARB keys or provider changes.

## 2026-08-25 — HUD type craft (kill yellow underlines)

### Context
On-device HUD still showed double yellow lines under every word (Samsung spell-check + Latin copy rendered in Noto overline tokens). Recraft instrument typography and a11y so the contest HUD reads world-class on camera.

### Done
- [`lib/presentation/shared/widgets/daftar_architecture_hud.dart`](lib/presentation/shared/widgets/daftar_architecture_hud.dart): `_HudType` / `_HudText` — Inter (`numeralCaption`) for Latin/IDs/ms/tools; stripped Noto for Arabic scope/rail words; explicit `TextDecoration.none`; no `monospace`. `DefaultTextStyle` reset + `SelectionContainer.disabled`. `ExcludeSemantics` on visual tree; single `architectureHudSemantics` label (`explicitChildNodes: false`). TextScaler clamp `1.15`. Dropped full-panel lapis rectangle; chips single-row `Flexible`; rail label gap `spacingXs`.
- [`test/presentation/shared/widgets/daftar_architecture_hud_test.dart`](test/presentation/shared/widgets/daftar_architecture_hud_test.dart): no underline/overline; EN labels Inter not monospace; 360×640 @ 1.3× scale no overflow.

### Architecture / decisions
Presentation-only; provider/OpenAPI/ARB unchanged. Lapis Law: lapis light only on running orb + current HITL node. No second `BackdropFilter`.

### Ops / verification
```bash
flutter test test/presentation/shared/widgets/daftar_architecture_hud_test.dart
```
11 tests passed.

### Status
HUD type + a11y underline kill ready for device re-check on Samsung debug build.

## 2026-08-25 — Christina Lin pre-submission check-in briefing (Stage 6)

### Context
Live DevPost / Google Cloud check-in (Christina Lin, Willie Turney). Extract judge language and map to Daftar Taskmaster packaging before 31 Aug deadline.

### Done
- [`docs/contest_checkin_christina_lin.md`](docs/contest_checkin_christina_lin.md): executive verdict (fast `/run` OK; user-perspective long-running day); timestamped quote table; judge consumption path; gap analysis vs repo; Stage 6 must-dos (video, README four sections, diagram glance, disclosure, Devpost); do-not-do list; Akrm Q&A canonical answer.

### Architecture / decisions
No agent or code changes. Confirms Taskmaster track; packaging over B-Prime; Christina 40:35 framing for narration.

### Ops / verification
Documentation only.

### Status
Stage 6 packaging should cite briefing when updating README, `contest_architecture.md`, `contest_demo.md`, and filming.

## 2026-08-26 — Flutter analyze cleanup (87 → 0)

### Context
Bring `flutter analyze` to zero issues (7 warnings + 80 infos) with no behavior changes — mechanical `dart fix` first, then targeted hand edits.

### Done
- `dart fix --apply`: 49 mechanical fixes across 24 files (`directives_ordering`, `prefer_const_*`, `unused_import`, `use_null_aware_elements`, etc.)
- Hand fixes: dartdoc backticks (`demo_seed_emails.dart`, `demo_seed_report.dart`, `closing_task_id.dart`, `agent_capture_bundle_card.dart`); `unawaited` on `AnimationController` futures (`closing_agent_taskmaster.dart`, `closing_agent_vault_seal.dart`, `closing_agent_working_glow.dart`); `cascade_invocations` (`group_capture_proposals.dart`, `closing_agent_idle_studio.dart`, `closing_agent_vault_seal.dart`); `math.max<double>` revert for `prefer_int_literals` regression in idle studio painter; unused `notifier` removed in `closing_agent_controller_test.dart`

### Architecture / decisions
Lint-only; no rule suppressions in `analysis_options.yaml`. Reverted dart-fix `prefer_int_literals` on `math.max(36, …)` where it widened to `num` and broke the painter API.

### Ops / verification
```bash
flutter analyze   # No issues found!
flutter test test/core/utils/dev_database_seeder_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart
```
54 tests passed.

### Status
Analyze clean. Ready for CI / pre-commit.

## 2026-08-26 — Flutter analyze cleanup (87 → 0)

### Context
`flutter analyze` reported 7 warnings and 80 infos under `very_good_analysis`; needed a clean tree before Stage 6 packaging.

### Done
- `dart fix --apply` (49 mechanical fixes across 24 files).
- Hand fixes: unused imports, `comment_references` backticks, `discarded_futures` (`unawaited` on `AnimationController`), cascades, `gleamLength` double literal in idle studio.
- [`dev_database_seeder.dart`](lib/core/utils/dev_database_seeder.dart): package exports only.

### Ops / verification
```bash
flutter analyze   # No issues found
flutter test test/core/utils/dev_database_seeder_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart
```
10 + 54 tests passed.

### Status
Analyzer clean; no rule suppressions in `analysis_options.yaml`.

## 2026-08-26 — Closing Agent scenario checklist (QA)

### Context
Owner requested a precise, scenario-level test checklist for the contest Closing Agent path (seed → capture → close → SMTP proofs and failure cases), separate from the ≤4 min film script.

### Done
- [`docs/qa/closing_agent_scenario_checklist.md`](docs/qa/closing_agent_scenario_checklist.md) — Passes 0–13: automated tests, Cloud Run warm, seed entry points, mid-day capture scripts, **Confirm & Send Statements** ritual, inbox/Console proofs, confirm-without-sending, Drive/Google/SMTP failures, empty overdue, Arabic RTL, HUD, Hybrid E ban, re-close; fixture table (7 contacts, 5 PDF / 2 text-only); sign-off table; command appendix.
- Cross-links: [`docs/qa/README.md`](docs/qa/README.md), [`docs/qa/gate4_device_runbook.md`](docs/qa/gate4_device_runbook.md), [`docs/contest_demo.md`](docs/contest_demo.md).

### Architecture / decisions
Docs-only; no product code. Live To: addresses remain in gitignored overlay; checklist uses `demo1`…`demo7` tags only. Does not tick roadmap Gate 4 boxes.

### Ops / verification
Manual doc review; no `flutter test` required for markdown.

### Status
Ready for owner to run checklist before Gate 4 filming.

## 2026-08-26 — Final contest review (film-ready packaging)

### Context
Full audit against All Things Agentic judging (40% utility · 30% architecture · 30% demo). Live code was strong; judge-facing docs still said “to be built” / “Approve & send”; SMTP desk had no retry after failed auto-dispatch.

### Done
- [`docs/CONTEST_DISCLOSURE.md`](docs/CONTEST_DISCLOSURE.md) — v2.8 landed status; Gmail SMTP lead; Hybrid E leftover
- CTA alignment: [`README.md`](README.md), [`docs/contest_demo.md`](docs/contest_demo.md) (HUD in ≤4 min cut), [`docs/qa/gate4_device_runbook.md`](docs/qa/gate4_device_runbook.md), [`docs/plan.md`](docs/plan.md), [`docs/architecture/contest_architecture.md`](docs/architecture/contest_architecture.md), [`docs/qa/smtp_proof_readme_note.md`](docs/qa/smtp_proof_readme_note.md)
- [`agent/README.md`](agent/README.md) — send cap 20 / PDF Top 5; App Password never in Flutter
- [`agent/closing_agent/agent.py`](agent/closing_agent/agent.py) INSTRUCTION + [`agent/tests/test_agent_instruction.py`](agent/tests/test_agent_instruction.py) — **Confirm & Send Statements**
- SMTP desk **Retry sending** — [`collections_desk_panel.dart`](lib/presentation/screens/closing_agent/widgets/collections_desk_panel.dart), ARB EN+AR, [`closing_agent_screen.dart`](lib/presentation/screens/closing_agent/closing_agent_screen.dart)
- Stage 6 packaging: [`docs/qa/flutter_env.template.md`](docs/qa/flutter_env.template.md), [`docs/qa/devpost_draft.md`](docs/qa/devpost_draft.md)
- [`docs/roadmap_v2.md`](docs/roadmap_v2.md) — cleared stale flags; ticked 6.1 diagram/README/demo script

### Architecture / decisions
One consent on plan; Retry calls existing `approveAndSend()` (not second consent). No Hybrid E on lead path.

### Ops / verification
```bash
flutter analyze   # No issues found
flutter test test/presentation/screens/closing_agent/widgets/collections_desk_panel_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart
```
58 tests passed. Agent: `pytest tests/test_agent_instruction.py` (owner env).

### Status
Owner: run scenario checklist Passes 1–5, film per contest_demo, paste Devpost draft, submit ≤ 31 Aug PDT.

## 2026-08-26 — Cloud Run redeploy + warm (revision 00051)

### Context
Owner requested deploy of updated closing agent (INSTRUCTION: Confirm & Send Statements) before filming.

### Done
- `gcloud run deploy` from [`agent/`](agent/) → revision `daftar-closing-agent-00050-vts` (100% traffic)
- Idempotent scaling lock → `daftar-closing-agent-00051-bq8` (min 0 / max 2)
- Warm: `GET /list-apps` → `["closing_agent"]` HTTP **200**
- Service conditions: Ready · ConfigurationsReady · RoutesReady all **True**

### Ops / verification
```bash
SERVICE_URL=https://daftar-closing-agent-1487285471.us-central1.run.app
TOKEN=$(gcloud auth print-identity-token)
curl -sS -H "Authorization: Bearer $TOKEN" "$SERVICE_URL/list-apps"
```

### Status
Live endpoint warm; safe to film without cold-start on first `/run`.

## 2026-08-26 — FAB coach tip FAB-anchored layout

### Context
The FAB coach hint card was laid out in a full-width `ContentAlign.top` strip from `tutorial_coach_mark`, stretched by an expanded Got it button, and start-aligned — so in RTL the readable mass sat to the right of the centered FAB. Spotlight hole was already correct via `overlayTargetOf`; the tooltip box needed the same physical-X anchoring on all screen sizes.

### Done
- [`lib/presentation/shared/widgets/daftar_coach_mark.dart`](lib/presentation/shared/widgets/daftar_coach_mark.dart) — `ContentAlign.custom` strip with halo-matched `bottom`; `_FabCoachTooltipAnchor` / `_RenderFabTipAnchor` centers a compact card (max 320dp) on `fabCenterX` with `pagePaddingH` + view-padding clamp; `DaftarCoachMarkTooltip` capped at 320dp
- [`test/presentation/shared/widgets/daftar_coach_mark_test.dart`](test/presentation/shared/widgets/daftar_coach_mark_test.dart) — real dock geometry (`spacingLg` + `Row(Expanded, 44×44 FAB, Expanded)`); matrix en/ar × 320/360/412 widths; center/inset/compact assertions

### Architecture / decisions
Presentation-only; no package fork. Physical overlay X only (no `AlignmentDirectional`). Custom render object sizes to child height so Got it/Skip remain tappable inside the coach overlay. Lapis Law unchanged.

### Ops / verification
```bash
flutter test test/presentation/shared/widgets/daftar_coach_mark_test.dart \
  test/presentation/shared/widgets/main_shell_fab_coach_test.dart
```
12 tests passed.

### Status
FAB tip box centers on the dock FAB in LTR and RTL. No roadmap checkbox changes.

## 2026-08-26 — FAB coach spotlight hugs the button

### Context
On device the lapis spotlight still appeared right of the FAB: `imageFilter` blur wrapped the hole in `ClipPath`+`BackdropFilter` (Impeller offset), the ring was loose (`paddingFocus` 4, `radiusMd`), and the tooltip was forced to 320dp via `isExpanded: true` — a banner whose RTL start-aligned mass sat far from the button.

### Done
- [`lib/presentation/shared/widgets/daftar_coach_mark.dart`](lib/presentation/shared/widgets/daftar_coach_mark.dart) — `overlayTargetOf` via `overlayBox.globalToLocal`; removed `imageFilter`; `paddingFocus: 2`, `radiusSm`; card max 240dp shrink-wrap (`isExpanded: false`, no inner `ConstrainedBox`)
- [`test/presentation/shared/widgets/daftar_coach_mark_test.dart`](test/presentation/shared/widgets/daftar_coach_mark_test.dart) — assert painted `LightPaintRect.target.center` == FAB center; card width &lt; 85% screen and ≤ 240dp (en/ar × 320/360/412)

### Architecture / decisions
Sharp `LightPaintRect` cutout only — no backdrop blur on the coach overlay. `targetPosition` only (never `keyTarget`). Tooltip width follows content; anchor still clamps to `fabCenterX`.

### Ops / verification
```bash
flutter test test/presentation/shared/widgets/daftar_coach_mark_test.dart \
  test/presentation/shared/widgets/main_shell_fab_coach_test.dart
```
13 tests passed.

### Status
Spotlight hole and compact hint card both hug the center FAB. Hot-restart on device to confirm on glass dock.

## 2026-08-26 — FAB coach: own overlay spotlight (drop tutorial_coach_mark)

### Context
Three `tutorial_coach_mark` patches still left the lapis ring right of the FAB on Arabic RTL glass dock — the package paints `LightPaintRect` in a non-positioned full-screen child inside an RTL `Stack`, so the hole canvas origin shifts even when our `TargetPosition` snapshot is correct. Widget tests asserted the snapshot, not pixels vs the real dock.

### Done
- [`lib/presentation/shared/widgets/daftar_coach_mark.dart`](lib/presentation/shared/widgets/daftar_coach_mark.dart) — `OverlayEntry` + `_RenderFabSpotlight`: hole = `globalToLocal(fab.localToGlobal)` each paint; dim path + lapis stroke; `debugHoleRect`; shrink-wrap tooltip on same hole X; fade-in overlay
- Removed [`tutorial_coach_mark`](pubspec.yaml) dependency
- [`test/presentation/shared/widgets/daftar_coach_mark_test.dart`](test/presentation/shared/widgets/daftar_coach_mark_test.dart) — `debugHoleRect.center` vs FAB; tearDown `removeOverlayForTest`
- [`test/presentation/shared/widgets/main_shell_fab_coach_test.dart`](test/presentation/shared/widgets/main_shell_fab_coach_test.dart) — MainShell glass dock hole center en/ar (device proxy)

### Architecture / decisions
§5.4 engine exception for FAB coach only — hand-rolled hole punch in the same `RenderBox` that paints. Confirm/Approve coaches still unbuilt. `hasSeenAgentFabTip` / MainShell gates unchanged. Lapis Law: border-only ring, no lapis fill.

### Ops / verification
```bash
flutter test test/presentation/shared/widgets/daftar_coach_mark_test.dart \
  test/presentation/shared/widgets/main_shell_fab_coach_test.dart
```
14 tests passed.

### Status
Spotlight is painted from live FAB geometry every frame. Hot-restart on Samsung device to confirm ring sits on the center FAB.

## 2026-08-26 — Judge-ready documentation pack

### Context
Judges open video → README → diagram → repo. Docs still claimed a false `tutorial_coach_mark` stack, mixed Approve vs Confirm & Send Statements, used a future freeze date as done, and left Christina’s README/diagram asks open. Wander risk: pricing, monetization, archive, and the operational log looked like competing contracts.

### Done
- [`docs/README.md`](README.md) — judges / owner-film / not-judging index
- [`docs/project_log.md`](project_log.md) — header: not a judging artifact (history not rewritten)
- [`README.md`](../README.md) — Christina four blocks (Taskmaster day + fast `/run`, folder map, insights, unfilmed pride) + SMTP Proof of Action (250 = accept)
- [`docs/qa/smtp_proof_readme_note.md`](qa/smtp_proof_readme_note.md) — pointer to README
- [`docs/architecture/contest_architecture.md`](architecture/contest_architecture.md) — Judge glance + four captions; HITL = Confirm & Send Statements
- [`docs/CONTEST_DISCLOSURE.md`](CONTEST_DISCLOSURE.md) — 2026-08-26; FAB custom overlay (not `tutorial_coach_mark`); HUD after Confirm & Send Statements
- [`docs/contest_demo.md`](contest_demo.md) + [`docs/qa/devpost_draft.md`](qa/devpost_draft.md) — problem in first 30s; official deadline 17:00 PDT only; video URL owner fills
- [`docs/roadmap_v2.md`](roadmap_v2.md) — §5.4 engine exception; v2.4 changelog superseded 26 Aug; Approve→Confirm on contest-facing lines; product/agent graph frozen vs calendar freeze EOD 28 Aug; Stage 6.1 drafts `[x]`, video/APK/bonus `[ ]`
- Owner banners: [`GATE0_OWNER_CHECKLIST.md`](GATE0_OWNER_CHECKLIST.md), [`plan.md`](plan.md), [`qa/README.md`](qa/README.md), [`contest_checkin_christina_lin.md`](contest_checkin_christina_lin.md)
- Specs labeled not judging: design_system, BACKUP, Drive backup, monetization, pricing, [`roadmap.md`](roadmap.md), [`archive/README.md`](archive/README.md)

### Architecture / decisions
Official contest deadline on judge-facing pages: **31 Aug 2026, 17:00 PDT**. 18:00 AST stays owner buffer in roadmap only. SMTP **250** = accept, not delivered. FAB coach = custom overlay. No Flutter/agent code in this pass. Archive and project_log history not rewritten.

### Ops / verification
Grep contest-facing docs: no current `tutorial_coach_mark` dep claim; no 18:00 AST as second hard cut; no leftover **Approve** as outreach CTA; SMTP `delivered` only as a negation. Stage 6 remaining: record video, APK/emulator path, private-share, bonus.

### Status
Docs pack aligned for judging. Video / Devpost submit still open (Stage 6–7).

## 2026-08-26 — Best Architectural Design contest-score pass

### Context
Best Architectural Design is top score on official Architectural Discipline (30%), not a separate rubric. OpenAPI still claimed service-URL ID-token audience and listed unimplemented `AgentSharedSecret` as live OR-auth. Diagram/README did not map decouple / state / credentials / failures in one glance.

### Done
- Owner scorecard canvas (not a judging artifact)
- [`agent/openapi.yaml`](../agent/openapi.yaml) **2.4.1** — custom-audience ID tokens; `AgentSharedSecret` removed from path `security` (scheme kept as **not implemented**)
- [`docs/architecture/contest_architecture.md`](architecture/contest_architecture.md) — official four asks + engine lenses (no vectors; planner/device/SMTP SoC)
- [`README.md`](../README.md) — four Architectural Discipline bullets
- [`docs/qa/devpost_draft.md`](qa/devpost_draft.md) — official vocabulary + optional Best Architectural Design / Best Multimodal tags

### Architecture / decisions
No Flutter/agent runtime change. No SequentialAgent, no vector DB, no substrate DI retrofit. Failures: durable send SoT is device `batchId` / Drift; process-local Cloud Run idempotency stays documented.

### Ops / verification
Grep: no path-level `AgentSharedSecret`; no “audience MUST be the Cloud Run service URL”; contest CTA remains **Confirm & Send Statements**; SMTP `delivered` only as negation; `tutorial_coach_mark` only as “not this package.”

### Status
Judge-visible architecture maps the official 30% criterion. Video still open.

## 2026-08-27 — Contest architecture accuracy pass

### Context
The judge-facing mermaid in [`contest_architecture.md`](architecture/contest_architecture.md) had false edges: merchant skipped Flutter, HUD parented the confirm gate, Drive fed Drift, confirm called SMTP, the model filled the desk, and PDF bytes were labeled as `localDay` summary.

### Done
- Rewrote mermaid + glance ASCII: Merchant → Flutter → `/run`; Drift → Drive upload; desk → `send-batch` only after **Confirm & Send Statements**; HUD observes SMTP (no `hud --> confirm`)
- One caption table: official decouple/state/credentials/failures plus integer money, Day Journal audit, send-set/PDF split, Confirm without sending, TTS sibling not drawn
- HITL close stations match `_runClosingRitual`
- [`README.md`](../README.md) HITL bullet: ritual before `send-batch`

### Architecture / decisions
Figure stays sparse (Christina one-glance). Completeness in captions. No Hybrid E / Stage 8 / pricing on the figure. No Flutter/agent runtime change.

### Ops / verification
Grep: no `hud --> confirm`; no inverted Drive as close path; no `localDay summary PDF`; eight tools match `ALL_TOOLS`; SMTP `250` ≠ delivered.

### Status
Architecture file matches live close path. Video still open.

## 2026-08-27 — Devpost draft mapped to live form

### Context
Owner needed a paste-ready Devpost submission that matches the live All Things Agentic form (not a generic write-up). Official Rules/FAQs, README, disclosure, architecture, and the 25 Aug Christina check-in were used as sources.

### Done
- Rewrote [`docs/qa/devpost_draft.md`](qa/devpost_draft.md) field-by-field: name, elevator pitch, About (Markdown story), Built with tags, Try-it links, gallery shot list, video rules, Taskmaster / Individuals, start-date note (`08-09-26` vs Gate 0 `08-03-26`), repo, README Yes, hosted `.run` URL, private testing instructions, ADK + Cloud Run + Gemini 3.5 Flash, architecture upload, Startup Excellence **off**, bonus URLs as owner-fills
- Bound claims: HITL confirm, SMTP `250` ≠ delivered, eight frozen tools, Chirp not claimed as Gemma/Veo/Lyria, Cloud Run IAM not a public demo

### Architecture / decisions
No Flutter/agent runtime change. Best Architectural Design is not a form checkbox. Cloud Run URL is hosted-project, not a public try-it link.

### Ops / verification
Rules §6–8 (video ≤4 min, private repo share, bonus +0.2/+0.2/+0.6). Repo origin `https://github.com/akrmcodes/daftar-closing-agent`. Video, gallery files, blog, and social remain owner.

### Status
Owner can paste into Devpost. Stage 6 video + media still open.

## 2026-08-27 — Keep vs delete (unused libs / Supabase / WhatsApp)

### Context
Owner asked whether unused libraries, gitignored Supabase artifacts, and the unused WhatsApp path should be deleted before submit. Horizon: contest only (through 31 Aug). Policy already locked in [`roadmap_v2.md`](roadmap_v2.md) §0.4: quarantine Stage 8, do not excise.

### Done
- **No deletions.** `.gitignore` Supabase secret patterns, tracked [`supabase/`](../supabase/) + [`link-hosting/`](../link-hosting/), Hybrid E / `WhatsAppUtil`, frozen `propose_whatsapp_drafts`, and `supabase_flutter` all stay.
- Recorded optional post-submit APK slim on [`docs/roadmap.md`](roadmap.md) (zero-import candidates only).

### Architecture / decisions
| Surface | Verdict | Why |
| --- | --- | --- |
| `.gitignore` `supabase/.env` (etc.) | **Keep patterns** | Secret protection, not junk |
| Tracked `supabase/` + Stage 8 Dart | **Keep (quarantined)** | §0.4 / disclosure; `kContestDisableMultiDeviceSync` |
| `supabase_flutter` | **Keep** | [`sync_remote_ds.dart`](../lib/data/datasources/remote/sync_remote_ds.dart) still compiles; engine never starts |
| `WhatsAppUtil` + contact share | **Keep** | Live substrate |
| Hybrid E desk chrome | **Keep, flag off** | SMTP film path `showHybridELeftover: false` |
| `propose_whatsapp_drafts` | **Keep** | Tool 7 of 8 frozen catalog |
| Zero-import UI pkgs | **Defer after 31 Aug** | Freeze-week lockfile risk; no 4-min story change |

### Ops / verification
Did not edit `.gitignore`, `pubspec.yaml` dependencies, `supabase/`, or WhatsApp/ADK catalog. Activation remains Dio → `/activate`, not the Supabase SDK.

### Status
Contest surface unchanged. Post-submit optional trim listed on the Phase 2 stub.

## 2026-08-27 — README spin-up judge-grade audit

### Context
Stage 6.1 README spin-up was checked but clone order, folder map, and secret/repro honesty were not judge-grade. Official rules require documented spin-up even if judges score from video.

### Done
- [`README.md`](../README.md): `flutter pub get` → `.env` → `build_runner` → run; expanded folder map (`application`/`domain`/`data`, `email_send`, `tts`, quarantined `supabase/`); agent deploy cautions (never `adk deploy cloud_run`, min 0 / max 2, 403 unauthenticated); live send-batch / owner demo-inbox warning; Settings **Show agent architecture**; Dart `^3.11.4` · `minSdk` 26
- [`docs/qa/flutter_env.template.md`](qa/flutter_env.template.md): same order; no `.env.example` (`.env.*` gitignored)
- [`docs/qa/devpost_draft.md`](qa/devpost_draft.md): private testing instructions match
- [`docs/roadmap_v2.md`](roadmap_v2.md) §6 gate: clone checklist + disclosure **checked**; §6.1 line 1082 stays `[x]`

### Architecture / decisions
Judges may score from video + repo. Live compile still needs owner OAuth + AES. App Password remains Secret Manager name only. Drift is SoT; Supabase is not the agent backend.

### Ops / verification
Grep README: `gmail-smtp-app-password`, `CONTEST_DISCLOSURE`, Proof of Action, `pub get` before `build_runner`. No OAuth client IDs or mailbox addresses in README.

### Status
README spin-up is the clean-machine checklist. Video / APK hosting still open.

## 2026-08-27 — Contest film shooting bible (≤4:00)

### Context
Judged cut is the first **4:00** only. Official tips: skip long intros and sign-up. Christina wow + one workflow + live GCP. Rewrite [`docs/contest_demo.md`](contest_demo.md) as the shooting bible — do not record in this pass.

### Done
- [`docs/contest_demo.md`](contest_demo.md): Act A **0:00–0:32** illustrated night (Yemen/Egypt/Arab street, forgotten name, midnight copy, torn كشكول photo, ILO informal ~half — no fake headcounts); Act B **0:32–4:00** live Taskmaster (paste `محمد عليه ٥٠٠ سكر` → Confirm & Send → Mohamed PDF / Omar–Yousef text-only → Logs Explorer `daftar.agent.email` **250** + Message-ID → Day closed). VO tables, full stopwatch script, AE allowed/banned, ImageFX/Bing prompt skeleton, TTS + burned-in EN subtitles (Chirp Enceladus or ElevenLabs). Cold-start onboarding **out** of the cut
- [`docs/roadmap_v2.md`](roadmap_v2.md) §6.1 line **1083** stays `[x]` (script matches judged path). Line **1084** stays **unchecked** (Hero→Language→Look is setup, not judged 4:00; optional 6s FAB-coach only if time). Stage 6 “dry-run timed ≤4 min” stays **unchecked** (owner stopwatch)
- [`docs/contest_checkin_christina_lin.md`](contest_checkin_christina_lin.md): gap row + packaging note — Christina prefers human VO; official Devpost allows AI; film uses TTS + EN subs

### Architecture / decisions
Proof of Action cannot be After Effects. SMTP 250 = accept, not delivered. WhatsApp leftover not climax. Integer money; Gemini proposes / merchant confirms / Drift commits. Send-batch is FastAPI sibling, not an ADK tool.

### Ops / verification
No video recorded. No APK. No Stage 6 dry-run checkbox. ILO cited as about half of Arab States employment (informality profile), not a merchant-minute study.

### Status
Shooting bible ready. Owner: VO WAV, five stills + torn photo, SRT, then unedited live take. Video lock / YouTube / APK still open.

## 2026-08-28 — Close-the-day email was missing Cloud Run mailbox env

### Context
Confirm & Send showed **Sign-in required** / Gmail-password copy after a successful Drive backup. Owner is signed in. That banner is `AuthFailure smtp_needs_human`, not Google Sign-In.

### Done
- Live Cloud Run **`daftar-closing-agent-00052-gx4`**: copied `GMAIL_SMTP_USER` / `GMAIL_SMTP_FROM` from revision **00049-9t8** (values not printed). `user_set` / `from_set` / `equal` true. Secret mount unchanged. Audience count **3**. Min 0 / max 2
- Root cause: revision **00050** passed empty `GMAIL_SMTP_USER="$GMAIL_SMTP_USER"` and cleared the keys. send-batch fail-closed as `from_user_mismatch` (`smtpCode` null — SMTP never attempted)
- [`agent/scripts/preserve_gmail_env.sh`](../agent/scripts/preserve_gmail_env.sh) + [`preserve_gmail_env.py`](../agent/scripts/preserve_gmail_env.py): source before deploy; copy USER/FROM from live revision if unset; abort if still empty. [`agent/README.md`](../agent/README.md) documents the 00050 wipe
- [`agent/email_send/router.py`](../agent/email_send/router.py): `haltReason` on `daftar.agent.email`. [`settings.py`](../agent/email_send/settings.py) / [`main.py`](../agent/main.py): boot `daftar.agent.email_config` when From≠user (no mailbox text). Ships on the **next source deploy**
- Flutter: `from_user_mismatch` / `smtp_secret_unavailable` → `smtp_sender_misconfigured`. 535 stays `smtp_needs_human`. Title **Email was not sent** (not Sign-in required). ARB EN+AR + gen-l10n

### Architecture / decisions
Drive OAuth ≠ Gmail SMTP. App Password stays Secret Manager file mount. No mailbox in git, logs, or this entry.

### Ops / verification
`agent/.venv` `pytest tests/test_email_send_batch.py` — 23 passed. `flutter test` dispatch + error_translator — 28 passed. Owner: retry **Confirm & Send Statements** (no re-login). Expect Logs Explorer `smtpCode=250`. Mint a new App Password only if logs then show **535**. Hot-restart the app to pick up the new banner copy. Next `gcloud run deploy --source` must `source ./scripts/preserve_gmail_env.sh`.

### Status
Mailbox env restored on 00052. Video still open.

## 2026-08-28 — Contest film-day owner runbook

### Context
Owner is about to record the judged ≤4:00. Needed a sequential phone/laptop path: skip onboarding on camera, English UI paste strings, no Mohamed contact drill / payment / statement export.

### Done
- [`docs/contest_demo.md`](contest_demo.md): appended **Film day — owner runbook (English UI)** — off-camera seed + HUD; four laptop tabs (Mohamed PDF, Omar/Yousef text-only, Logs Explorer, Cloud Run backup); on-camera clock FAB → `Mohamed owes 500 sugar` → **Record debt** → **Close today** → **Confirm & Send Statements** → inbox → `daftar.agent.email` **250** → **Day closed**; explicit nos

### Architecture / decisions
English UI for this take; VO + EN subs still required. Drive ritual row is backup proof; Drive Console is not GCP. SMTP 250 = accept, not delivered.

### Ops / verification
Docs only. No video recorded. Warm `/list-apps` before the take.

### Status
Shooting bible + film-day sequence ready. Video lock / YouTube still open.

## 2026-08-28 — Cloud Run min 1 for film warm

### Context
Owner asked to keep `daftar-closing-agent` permanently warm during video recording so `/run` and send-batch are not a cold start.

### Done
- `gcloud run services update` **min 1 / max 2** both layers (service + revision). New revision **`daftar-closing-agent-00053-xk5`** (100% traffic)
- Gmail USER/FROM still set and equal. Custom audiences **3**. No `--update-env-vars`
- Warm: `GET /list-apps` HTTP **200** in ~0.76s → `["closing_agent"]`
- [`docs/contest_demo.md`](contest_demo.md) film-day note: min 1 for this window; scale back to min 0 after the take

### Architecture / decisions
Contest cost lock remains **min 0 / max 2** as the default. Min 1 is a recording-only exception (always-on instance billed). After film: `--min=0 --max=2 --min-instances=0 --max-instances=2`.

### Ops / verification
`service_minScale=1` `service_maxScale=2` `revision minScale=1` `maxScale=2`.

### Status
Live is warm for the take. Restore min 0 after recording.

## 2026-08-28 — USD spoken 500 snaps to $500.00 (not $5.00)

### Context
Demo store is USD. Gemini often sends `amountMinor: 500` (YER-style). Confirm card formatted 500 cents as **$5.00**. Same for typed/pasted **500** and **Ahmed owes 200** ($2.00). Snap already corrected over-scale (YER `50000` → `500`) but not under-scale.

### Done
- [`lib/application/agent/correct_spoken_amount_minor.dart`](../lib/application/agent/correct_spoken_amount_minor.dart) + [`agent/closing_agent/proposal.py`](../agent/closing_agent/proposal.py) `correct_zero_decimal_scale`: when `amountMinor == spoken` and `factor > 1`, return `spoken * factor` (USD `500` → `50000` cents). Do not invent amounts (Gemini `7` for “500” stays `7`). YER `factor=1` unchanged
- Tests: Dart `correct_spoken_amount_minor_test.dart` — Mohamed paid/owes 500, Ahmed 200, AR chips, YER `500` stays `500` / `50000` → `500`. Python `test_proposal_tools.py` — `propose_payment("Mohamed", 500)` USD → `50000`; `propose_debt("Ahmed", 200)` → `20000`

### Architecture / decisions
Twins stay in sync. Integer money only. Device Dart snap runs even if Cloud Run still returned 500.

### Ops / verification
`flutter test test/application/agent/correct_spoken_amount_minor_test.dart` — 51 passed. `agent/.venv` `pytest tests/test_proposal_tools.py` — 83 passed. Redeployed with `source ./scripts/preserve_gmail_env.sh`. Live **`daftar-closing-agent-00054-dpc`** (100% traffic). Gmail USER/FROM set and equal. Audiences **3**. min **1** / max **2** kept for film. `GET /list-apps` HTTP **200** in ~0.66s.

### Status
Phone needs **hot restart / rebuild** so Dart snap is on device. Restore min 0 after the take.

## 2026-08-28 — Cloud Run min 0 after film

### Context
Owner finished recording. Restore the contest cost lock (min 0 / max 2) so the always-on instance from the film window is not billed.

### Done
- `gcloud run services update` **min 0 / max 2** both layers. No `--update-env-vars`. Serving revision **`daftar-closing-agent-00055-pbm`** (100% traffic)
- Gmail USER/FROM still set and equal. Custom audiences **3**
- [`docs/contest_demo.md`](contest_demo.md) film-day note: recording window closed; cost lock restored

### Architecture / decisions
Contest default remains min 0 / max 2. No source rebuild.

### Ops / verification
`service minScale` unset (treat as 0) `maxScale=2` `revision minScale=0` `maxScale=2`.

### Status
Cost lock restored. Video packaging still open.

## 2026-08-30 — §6.1 hosted/testable APK path

### Context
Owner built `flutter build apk --release`, sideloaded with `adb install -r`, and verified the contest close path on device. Remaining work was judge-facing docs (no Flutter required) plus roadmap ticks. Binary stays out of git.

### Done
- [`README.md`](README.md) — **Judge APK / emulator**: package `com.akrmcodes.daftar`, debug-keystore sideload, API 34+ Play emulator, HUD toggle, SMTP To: warning, `[OWNER: public APK download link]` placeholder
- [`docs/qa/devpost_draft.md`](docs/qa/devpost_draft.md) — Try-it row 5 (owner APK URL); Testing instructions lead with APK then optional Flutter clone
- [`docs/roadmap_v2.md`](docs/roadmap_v2.md) — §6.1 hosted/testable `[x]`; §7.1 demo-device ritual `[x]`

### Architecture / decisions
Release APK remains debug-keystore signed (sideload only). Owner hosts Drive/GitHub Release; we do not invent a download URL.

### Status
Owner: upload `app-release.apk`, paste the URL into Devpost, submit by 31 Aug 2026 17:00 PDT.

## 2026-08-30 — Drive APK URL + judges-only Pro+ code

### Context
Owner hosted `app-release.apk` on Drive and provided a live Pro+ activation code for judges who want remaining product features. Closing Agent must stay scorable on Free.

### Done
- [`README.md`](README.md) — Drive download URL; Pro+ optional; code **not** in README; Settings → Plan & activation → Add activation code
- [`docs/qa/devpost_draft.md`](docs/qa/devpost_draft.md) — Try-it row 5 = Drive URL; Testing instructions include `PROPLUS-QM9VUV9VLH8ZC529`, redeem path, sync still quarantined; no code on public Try-it

### Architecture / decisions
Code lives only in the Devpost Testing paste (and this private-repo QA file). Public Try-it stays APK + repo + video.

### Status
Owner: paste Try-it row 5 + Testing instructions into Devpost; submit by 31 Aug 2026 17:00 PDT. Optional later GitHub Release of the same APK.

## 2026-08-30 — §7.1 Pre-submit audit (Stage 8 quarantine + no secrets)

### Context
Owner asked to close roadmap §7.1 lines 1116–1117 only: prove Stage 8 UI/engines stay off, prove no real credentials are in git, then tick those two boxes. Disclosure, architecture diagram, Devpost track, and §7.2 submit stay untouched.

### Done
- Kill-switch still `AppConstants.kContestDisableMultiDeviceSync = true` ([`app_constants.dart`](../lib/core/constants/app_constants.dart))
- Defense-in-depth: [`claim_deep_link_use_case.dart`](../lib/application/deep_link/claim_deep_link_use_case.dart), [`create_deep_link_use_case.dart`](../lib/application/deep_link/create_deep_link_use_case.dart), [`resolve_deep_link_use_case.dart`](../lib/application/deep_link/resolve_deep_link_use_case.dart), [`request_new_invite_use_case.dart`](../lib/application/deep_link/request_new_invite_use_case.dart) return `AuthFailure(code: contest_sync_quarantined)` and never call Edge Functions
- Locking tests: [`test/core/contest/stage8_quarantine_test.dart`](../test/core/contest/stage8_quarantine_test.dart), [`test/application/deep_link/deep_link_use_cases_quarantine_test.dart`](../test/application/deep_link/deep_link_use_cases_quarantine_test.dart), [`test/core/security/repo_secret_scan_test.dart`](../test/core/security/repo_secret_scan_test.dart)
- Accept-invite happy path retargeted to fail-closed ([`accept_worker_invite_use_case_test.dart`](../test/application/collaboration/accept_worker_invite_use_case_test.dart))
- [`.gitignore`](../.gitignore) — `*.apk` (Drive / GitHub Release only)
- [`docs/roadmap_v2.md`](roadmap_v2.md) §7.1 lines 1116–1117 `[x]`

### Architecture / decisions
| Surface | Evidence |
| --- | --- |
| Engines | [`main.dart`](../lib/main.dart) `_startSyncEngine` / `_startDeepLinkListener` early-return; [`SyncEngineController.build`](../lib/presentation/providers/sync_engine_providers.dart) bails when unlock is false |
| Routes | [`app_router_provider.dart`](../lib/app/router/app_router_provider.dart) redirects five Stage 8 paths to settings |
| Settings | Join Workspace / Sync Report / Team rows hidden ([`settings_screen.dart`](../lib/presentation/screens/settings/settings_screen.dart)) |
| Deep-link UCs | Four use cases now match [`ExchangeSyncTokenUseCase`](../lib/application/auth/exchange_sync_token_use_case.dart) |
| Secrets | `git ls-files` has no `.env` / `client_secret` / `.apk` / `.jks` / `.pem`; content scan skip-list = Firebase client config; live Pro+ code not in README |
| KEEP | `supabase/`, `link-hosting/`, Android App Links, Drive / `PendingCloudSyncStore` untouched. No Dio-layer kill-switch (Stage 8 HTTP unit tests stay valid) |

Firebase `google-services.json` / `firebase_options.dart` keys remain tracked (Google: not secrets). Live Pro+ stays only in [`docs/qa/devpost_draft.md`](qa/devpost_draft.md). Secret Manager **name** `gmail-smtp-app-password` in docs is not a leak.

### Ops / verification
```bash
git ls-files | rg -i '(\.env$|client_secret|\.apk$|\.jks$|\.pem$)'   # empty
flutter test \
  test/application/deep_link/deep_link_use_cases_quarantine_test.dart \
  test/application/collaboration/accept_worker_invite_use_case_test.dart \
  test/application/auth/exchange_sync_token_use_case_test.dart \
  test/application/sync/is_multi_device_sync_unlocked_use_case_test.dart \
  test/core/contest/stage8_quarantine_test.dart \
  test/core/security/repo_secret_scan_test.dart \
  test/core/security/flutter_smtp_secret_scan_test.dart
# → All tests passed (20)
```

### Status
§7.1 1116–1117 closed. Remaining §7.1: disclosure accuracy, architecture diagram, Devpost Taskmaster track. Then §7.2 submit by 31 Aug 2026 17:00 PDT.

## 2026-08-30 — §7.1 CONTEST_DISCLOSURE.md accurate

### Context
Owner asked to close roadmap §7.1 line 1118 only: refresh eligibility disclosure to match Official Rules (New Projects Only) and the 30 Aug tree. Architecture diagram, Devpost track, and §7.2 stay open.

### Done
- [`docs/CONTEST_DISCLOSURE.md`](CONTEST_DISCLOSURE.md) — as-of **2026-08-30**; Hybrid E is contest-period leftover (not substrate); eight FunctionTools named; Chirp `POST /v1/tts` + Ask-the-books rows; standard-stack paragraph; `whatsapp_util` stays in the substrate table
- [`docs/qa/devpost_draft.md`](qa/devpost_draft.md) — Disclosure paste sentence aligned (Hybrid E leftover)
- [`test/core/contest/contest_disclosure_accuracy_test.dart`](../test/core/contest/contest_disclosure_accuracy_test.dart) — source lock
- [`docs/roadmap_v2.md`](roadmap_v2.md) §7.1 line 1118 `[x]`

### Architecture / decisions
Official rules allow frameworks/libraries; the disclosed **pre-existing work** is the Daftar ledger in this repo from before 3 Aug 2026. Hybrid E (`propose_whatsapp_drafts` + `wa.me`) was built in the Submission Period — leftover, not filmed climax, not SMTP fallback. `send-batch` / TTS remain sibling FastAPI routes, not FunctionTools. No Pro+ code, App Password, or mailbox addresses in this file.

### Ops / verification
```bash
flutter test test/core/contest/contest_disclosure_accuracy_test.dart
```

### Status
§7.1 1116–1118 closed. Remaining §7.1: architecture diagram, Devpost Taskmaster track. Then §7.2 submit by 31 Aug 2026 17:00 PDT.

## 2026-08-30 — §7.1 architecture PNG in repo

### Context
Owner placed `contest_architecture.png` at the repo root as a precaution. §7.1 line 1120 requires a judge-facing diagram in-repo; Devpost uploads PNG/PDF (not Markdown). Mermaid-cli re-export hung in the sandbox — the file is the 27 Aug mermaid.live export of the locked TB mermaid (accuracy pass).

### Done
- Moved [`docs/architecture/contest_architecture.png`](architecture/contest_architecture.png) (180 KB, 1400×1972). Root duplicate removed
- [`docs/architecture/contest_architecture.md`](architecture/contest_architecture.md) — PNG under System diagram + edge caption (HITL → `/run`; Drive is backup only; desk → send-batch after Confirm; HUD observes). Mermaid kept as editable source
- [`README.md`](../README.md) — same PNG under Architecture (judges)
- [`docs/qa/devpost_draft.md`](qa/devpost_draft.md) — Try-it row 3 + Architecture **Upload** = this PNG
- [`test/core/contest/contest_architecture_png_test.dart`](../test/core/contest/contest_architecture_png_test.dart)
- [`docs/roadmap_v2.md`](roadmap_v2.md) §7.1 line 1120 `[x]`

### Architecture / decisions
Edges unchanged from 27 Aug mermaid: Merchant → HITL → Drift; HITL → POST /run → agent → 8 tools → Vertex Gemini; tools → HITL (Appendix J); Drift → Drive upload; Drift → desk → send-batch after Confirm and Send; SMTP → HUD observe-only. One Cloud Run. TTS not drawn. Credentials/failures stay in the caption table.

### Ops / verification
```bash
test ! -f contest_architecture.png
ls -lh docs/architecture/contest_architecture.png   # 180K
flutter test test/core/contest/contest_architecture_png_test.dart
```

### Status
§7.1 1116–1120 closed. Remaining §7.1: Devpost Taskmaster track. Owner: upload the same PNG on the Devpost Architecture diagram field (optional gallery still #10). Then §7.2 submit by 31 Aug 2026 17:00 PDT.

## 2026-08-30 — Docs IA reorg (hybrid + accuracy)

### Context
Judge, owner, product, and archive docs sat in one flat tree. Misleading names (`GOOGLE_DRIVE_SYNC_SPEC`) and stale Stage 7 ticks risked confusing submit-day readers. Contest-locked paths stay put.

### Done
- Rewrote [`docs/README.md`](README.md) as an audience index; added folder READMEs under [`architecture/`](architecture/), [`contest/`](contest/), [`product/`](product/), and [`qa/`](qa/)
- Moved owner contest ops: [`contest/plan.md`](contest/plan.md), [`contest/contest_checkin_christina_lin.md`](contest/contest_checkin_christina_lin.md), [`contest/GATE0_OWNER_CHECKLIST.md`](contest/GATE0_OWNER_CHECKLIST.md)
- Moved product stubs: [`product/roadmap.md`](product/roadmap.md), [`product/pricing-feature-matrix.md`](product/pricing-feature-matrix.md)
- Renamed [`architecture/GOOGLE_DRIVE_BACKUP_SPEC.md`](architecture/GOOGLE_DRIVE_BACKUP_SPEC.md) (was `GOOGLE_DRIVE_SYNC_SPEC.md`)
- Folded SMTP pointer into [`qa/README.md`](qa/README.md); deleted `qa/smtp_proof_readme_note.md`
- Accuracy: Stage 7 / Appendix G premature submit ticks unchecked; Christina gap table = 30 Aug; Hybrid E = contest-period leftover; archive voice-study / Drive relative links; design-system changelog footer → this log; Gate 4 banner; telemetry Status archived; stripped `file://` leaks in the performance roadmap
- Untracked `docs/.obsidian/`; gitignored
- Link sweep: root README Binding table, `roadmap_v2` Appendix H, Dart comments, [`tool/qa_preflight.sh`](../tool/qa_preflight.sh)

### Architecture / decisions
No move of `CONTEST_DISCLOSURE.md`, `contest_architecture.md` / `.png`, `contest_demo.md`, `roadmap_v2.md`, `design_system.md`, or this log. Project-log history not rewritten. Devpost Track / submit still owner.

### Ops / verification
```bash
rg -n 'GOOGLE_DRIVE_SYNC_SPEC|smtp_proof_readme|docs/plan\.md|docs/roadmap\.md|docs/pricing-feature-matrix' --glob '!docs/project_log.md'
flutter test test/core/contest/contest_disclosure_accuracy_test.dart test/core/contest/contest_architecture_png_test.dart
```

### Status
Docs tree is audience-split. Remaining §7.1: Devpost Taskmaster track. Then §7.2 submit by 31 Aug 2026 17:00 PDT.

## 2026-08-30 — Final submit audit hardening

### Context
Official-rules review found no disqualification-level gaps. Remaining risk: a shallow README reader missing the substrate split, and a checked optional bonus with no public URL in-repo.

### Done
- Root [`README.md`](../README.md) — two sentences under the hackathon line: Drift/Khazna ledger is pre-existing substrate (before 3 Aug 2026), disclosed in [`CONTEST_DISCLOSURE.md`](CONTEST_DISCLOSURE.md); Closing Agent (ADK + Gemini 3.5 + Cloud Run + HITL + Gmail SMTP) is Submission Period work
- [`docs/roadmap_v2.md`](roadmap_v2.md) §6.1 optional blog/social **unchecked** until a live public URL exists
- [`docs/contest/contest_checkin_christina_lin.md`](contest/contest_checkin_christina_lin.md) matching social bonus box unchecked
- [`docs/qa/devpost_draft.md`](qa/devpost_draft.md) — bonus fields **Leave blank** unless a live URL exists; do not claim the point without the link
- This log **not** deleted or relocated

### Architecture / decisions
Disclosure, architecture PNG, and Stage 0–6 checklists unchanged. Devpost Track / submit / freeze remain owner. False bonus claims are worse than leaving bonus empty.

### Ops / verification
```bash
flutter test test/core/contest/contest_disclosure_accuracy_test.dart test/core/contest/contest_architecture_png_test.dart
```

### Status
Repo hardening closed. Owner: paste [`qa/devpost_draft.md`](qa/devpost_draft.md), upload [`architecture/contest_architecture.png`](architecture/contest_architecture.png), paste public video URL, select Taskmaster, submit by 31 Aug 2026 17:00 PDT, then freeze.

## 2026-08-30 — Optional bonus URLs recorded

### Context
Owner already published the +0.2 content and social posts before submit; URLs were not in-repo when the bonus box was left unchecked.

### Done
- Verified [DEV](https://dev.to/akrmcodes/daftar-closing-agent-gemini-plans-the-shops-day-the-phone-commits-the-books-5bgl) is public and contains: *This piece was created for the purpose of entering the All Things Agentic Hackathon.*
- Verified [X](https://x.com/AkrmCodes/status/2092993899778457916) (`@AkrmCodes`, 27 Aug 2026) uses `#AllThingsAgenticHackathon`
- [`roadmap_v2.md`](roadmap_v2.md) §6.1 bonus **checked** with those URLs
- [`contest/contest_checkin_christina_lin.md`](contest/contest_checkin_christina_lin.md) matching box checked
- [`qa/devpost_draft.md`](qa/devpost_draft.md) bonus fields are paste-ready (not blank)

### Status
Owner pastes both URLs on Devpost. Do not claim Gemma / Veo / Lyria.

## 2026-08-30 — Devpost gallery pitch and About rewrite

### Context
Gallery tagline still said MENA. The shipped product is `ar`/`en` and built-in **YER, SAR, USD** — not North African languages or currencies. MENA is an overclaim on a judge-facing first glance.

### Done
- [`qa/devpost_draft.md`](qa/devpost_draft.md) — 189-character tagline (no fallback); owner scoring map + Do-not-say; thumbnail = gallery still 1; About **Judge glance** names Gemini 3.5 Flash + ADK + Cloud Run; Inspiration is paper-دفتر BYOF (`ar`/`en`, YER/SAR/USD); testing instructions name locales/currencies; checklist bans MENA / delivered / extra models
- Root [`README.md`](../README.md) line 3: “MENA merchants” → “shops that still close the day on paper”

### Status
Paste the draft. Do not claim MENA, SMTP delivered, or Gemma / Veo / Lyria.

## 2026-08-30 — About paste uses paths, not GitHub blobs

### Context
About is public on Devpost. GitHub blob URLs 404 for anyone who is not a collaborator; they are not a private channel to judges.

### Done
- [`qa/devpost_draft.md`](qa/devpost_draft.md) About: `docs/CONTEST_DISCLOSURE.md` as a path; Try it / docs lists `README.md`, architecture PNG/MD, film script; private-share note for `testing@devpost.com` + `cloudhackathons@google.com`; Cloud Run hostname stays on the Hosted project URL field only

### Status
Complete the two-email share before submit. Architecture PNG is the required upload.

## 2026-08-30 — Remaining Devpost field pastes

### Context
Live form requires Organization name even for Individuals. Hosted Cloud Run returns 403 in a browser. Social `x.com` may fail the form validator. Video URL still owner-fills.

### Done
- [`qa/devpost_draft.md`](qa/devpost_draft.md) — Organization **N/A** if required; Hosted URL 403 is expected (do not grant `allUsers`); social paste prefers `twitter.com` of the same tweet; YouTube Public + title/description table; Cloud Run stays off Try-it

### Status
Paste **Yes** for README testing. Paste DEV + twitter.com bonus URLs. Set YouTube Public, then paste the watch URL.

## 2026-08-30 — Testing instructions 255-character paste

### Context
Live Devpost field is optional, 255 characters, for gated-host credentials — not a README.

### Done
- [`qa/devpost_draft.md`](qa/devpost_draft.md) Testing instructions: 226-character paste — no Cloud Run login; 403 expected; optional Pro+ code **in this field only** (not README; `repo_secret_scan_test` locks README)

### Status
Paste that block. Pro+ stays off git and off public Try-it.

## 2026-08-30 — Stage 7 gate: submitted SHA + analyzer clean

### Context
Last open Stage 7 Validation Gate item: local tag/note of the submitted commit. `flutter analyze` reported four `unnecessary_raw_strings` infos in the secret-scan test.

### Done
- `flutter analyze` — **No issues found** after dropping unnecessary `r` prefixes in [`test/core/security/repo_secret_scan_test.dart`](../test/core/security/repo_secret_scan_test.dart) (regexes without `\` or `$`). `repo_secret_scan_test` still green
- Annotated tag **`contest-submit-2026-08-30`** on submitted `origin/main`: `71f05be0692ba1f415d9be8823f34e866ec373ba` (Merge PR #6 `speech-setup`)
- [`roadmap_v2.md`](roadmap_v2.md) §7 Validation Gate SHA box **checked**; Appendix G Taskmaster + submitted boxes aligned with §7.1 / §7.2

### Architecture / decisions
The tagged SHA is the Devpost freeze commit. Do **not** move the tag. Further product work belongs on a **fork** until winners are announced.

### Ops / verification
```bash
flutter analyze   # No issues found
git rev-parse contest-submit-2026-08-30^{}   # 71f05be0692ba1f415d9be8823f34e866ec373ba
```

### Status
Stage 7 Validation Gate closed.

## 2026-09-01 — Roadmap v3.1 contest-accurate lock

### Context
CALL-E: Your Code Is Calling submission uses [`docs/roadmap_v3.md`](roadmap_v3.md) as the sole implementation contract. v3.0 mixed MCP `plan_call` / `confirm_token` vocabulary with the Developer API production path. Official rules, [call-e-integrations](https://github.com/CALLE-AI/call-e-integrations), `calle-ai` 0.7.0, and awesome-phone-call-agents CONTRIBUTING required a surgical lock before Stage 0 work.

### Done
- [`docs/roadmap_v3.md`](roadmap_v3.md) **v3.1**: production = `calle-ai==0.7.0` `calls.create` / `GET /v1/calls/{id}`; `plan-batch` is Daftar-local (zero PSTN); `runId` := CALL-E `call.id`
- Renamed Minimum Contestable Product **MCP** → **MFP** (MCP = Model Context Protocol only)
- Credits: 20 new / +200 existing / pause not auto-charge; Gate 0 API 404 probe; Chat ≠ API
- Awesome-list payload: `skills/ledger-collections-call/` + dry-run + `validate_repository.py`
- Envied frozen-URL landmine, NANP `+1`, integer coercion, winning-criteria map, `kept` differentiation, Singapore residency, judge testing through 13 Oct 2026

### Architecture / decisions
Device **Confirm & Call** is HITL. Do not invent an API `confirm_token`. MCP/CLI remains owner-ops only (installation guide). Product catalog, Model C, dual rail, schema 26, eight-tool freeze unchanged. Disclosure / `docs/contest/README.md` pointer flip remain Stage 0/6.

### Ops / verification
Doc-only pass. No deploy. Sources: Devpost Official Rules, integrations region table, `@call-e/calle` 0.7.0 `calls.create` / `get`.

### Status
v3.1 is binding. Stage 0 checklists start unchecked. Extra-calls form and Developer API probe are day-1.

## 2026-09-01 — Roadmap v3.2 judging-criteria lock

### Context
v3.1 met Stage One (SDK at runtime) but the winning map did not answer every official Stage Two question — especially **worth building further**, non-obvious vs `kept`, thorough CALL-E use, and a film/About that states why it matters.

### Done
- [`docs/roadmap_v3.md`](roadmap_v3.md) **v3.2**: winning map quotes the four Devpost criteria + Impact tie-break; Confirm & Call stays in the product after submit
- Skill one-liner locked (§5.4); 3:00 beat sheet (§6.3); four-paragraph English Devpost About (§6.5); Appendix G on-device live ring + English About
- Do not open the film on Gemini/ADK. Product, calendar, and J.9 unchanged from v3.1

### Architecture / decisions
Prize lane remains Most Practical. Runtime proof remains the Flutter Gate 4 call. Skill dry-run stays no-call.

### Ops / verification
Doc-only. Sources: [call-e.devpost.com](https://call-e.devpost.com/) judging criteria; Official Rules §6 tie-break.

### Status
v3.2 is binding for judge-facing copy. Implement Stages 0–7 against this file.

## 2026-09-01 — Agentic Cloud Run freeze (CALL-E fork)

### Context
Defense-in-depth so this fork cannot accidentally mutate All Things Agentic production Cloud Run (`daftar-closing-agent`) while CALL-E Stage 1 is not started. Binding: [`docs/roadmap_v3.md`](roadmap_v3.md) v3.2.

### Done
- Always-on Cursor rule [`.cursor/rules/calle-agentic-freeze.mdc`](../.cursor/rules/calle-agentic-freeze.mdc); pointer in [`.cursor/rules/project-identity.mdc`](../.cursor/rules/project-identity.mdc); comment-only on [`lib/core/env/env.dart`](../lib/core/env/env.dart) (`defaultValue` unchanged)
- [`agent/scripts/refuse_frozen_cloud_run.sh`](../agent/scripts/refuse_frozen_cloud_run.sh); [`agent/scripts/deploy_daftar_call_e.sh`](../agent/scripts/deploy_daftar_call_e.sh) (exit 2 until `daftar-call-e` exists); [`tool/check_agentic_freeze.sh`](../tool/check_agentic_freeze.sh)
- Gmail landmine: `DAFTAR_GMAIL_ENV_SERVICE` required; [`agent/scripts/read_gmail_env_from_frozen.sh`](../agent/scripts/read_gmail_env_from_frozen.sh) describe-only
- [`agent/README.md`](../agent/README.md) deploy/update fences converted to HISTORICAL; snapshot [`docs/contest/AGENTIC_CLOUD_RUN_FREEZE.md`](contest/AGENTIC_CLOUD_RUN_FREEZE.md)
- File tests: [`test/core/contest/agentic_cloud_run_freeze_test.dart`](../test/core/contest/agentic_cloud_run_freeze_test.dart)

### Architecture / decisions
Frozen service `daftar-closing-agent` / URL `https://daftar-closing-agent-1487285471.us-central1.run.app` / SA `agent-runner`. Allowed live gcloud: describe / get-iam-policy / list only. Legal future service name `daftar-call-e` via the wrapper only. No Confirm & Call, no schema 26, no Flutter UI, no `daftar-call-e` deploy this pass.

### Ops / verification
- Origin: `https://github.com/akrmcodes/daftar-call-e.git`
- Describe-only: `latestReadyRevisionName` = `daftar-closing-agent-00055-pbm`
- Created SA `call-e-runner@daftar-closing-agent.iam.gserviceaccount.com` (did not change `agent-runner`; no `gmail-smtp-app-password` IAM; no `calle-api-key` secret — owner value not provided)
- `bash -n` on new scripts; `dart test test/core/contest/agentic_cloud_run_freeze_test.dart`

### Status
Freeze layer complete. Stage 1 Cloud Run `daftar-call-e` still not created. Envied default still the frozen hostname until Stage 1.

## 2026-09-01 — Owner-ops local freeze snapshot

### Context
Keep a home-directory-only identity + IAM copy of frozen Cloud Run `daftar-closing-agent` in case the live describe later differs from the repo snapshot.

### Done
- `$HOME/.daftar-owner-ops/` (mode 700): `daftar-closing-agent-00055-identity.yaml` and `daftar-closing-agent-iam.yaml` (mode 600)
- Pointer in [`docs/contest/AGENTIC_CLOUD_RUN_FREEZE.md`](contest/AGENTIC_CLOUD_RUN_FREEZE.md) — YAML contents not in git

### Architecture / decisions
Describe / get-iam-policy only. Identity format excludes env, mailbox, and custom-audiences. IAM not printed in chat.

### Ops / verification
Live `latestReadyRevisionName` still `daftar-closing-agent-00055-pbm`. `git status` must not list `~/.daftar-owner-ops`.

### Status
Local snapshot on the owner machine. Frozen service unchanged.

## 2026-09-01 — Contest plan.md aligned to roadmap v3.2

### Context
[`docs/contest/plan.md`](contest/plan.md) still described All Things Agentic (Confirm & Send Statements, SMTP-only, execution = v2.8). Binding contract is [`docs/roadmap_v3.md`](roadmap_v3.md) v3.2.

### Done
- Rewrote [`docs/contest/plan.md`](contest/plan.md) as CALL-E v3.2 orientation: Confirm & Call, dual rail, `daftar-call-e`, Developer API vs MCP, freeze URL, three-way eligibility buckets
- Appendix H row now says orientation **updated for v3.2**
- Did **not** copy Stage checklists, J.9 tables, or beat sheets. Did **not** rewrite root README, contest README, architecture PNG, or `CONTEST_DISCLOSURE.md`

### Architecture / decisions
Execution remains solely in roadmap v3.2. `plan-batch` is Daftar-local. Production path is `calle-ai` `calls.create`, not MCP. Frozen Agentic Cloud Run must not be redeployed.

### Ops / verification
Doc-only. No deploy. No Envied `defaultValue` change.

### Status
Orientation matches v3.2. Contest README / root README still Agentic until Stage 0/6.

## 2026-09-01 — Stage 0.0 contest hygiene (eligibility)

### Context
CALL-E Official Rules §4 **New & Existing** (not Agentic “new projects only”). Remaining 0.0 boxes: rewrite disclosure; flip contest README to v3.2.

### Done
- Rewrote [`docs/CONTEST_DISCLOSURE.md`](CONTEST_DISCLOSURE.md): three-way split (pre-Aug substrate; Aug Agentic prior work overlapping the CALL-E window but **not** CALL-E-new; Confirm & Call / `calle-ai` / `daftar-call-e` = **Planned**)
- [`docs/contest/README.md`](contest/README.md) execution contract → [`roadmap_v3.md`](roadmap_v3.md) v3.2
- Roadmap 0.0 boxes + Stage 6.2 README flip `[x]`; Appendix H updated; [`contest/plan.md`](contest/plan.md) no longer says disclosure is Agentic
- Retargeted [`test/core/contest/contest_disclosure_accuracy_test.dart`](../test/core/contest/contest_disclosure_accuracy_test.dart)

### Architecture / decisions
Significant update = Confirm & Call + Developer API at runtime. Do not claim CALL-E-new as landed. Frozen Agentic URL is prior production, not this contest’s service. Root README / judge pack remain Stage 6.

### Ops / verification
`flutter test` contest disclosure + freeze tests. No deploy. No Envied change.

### Status
Stage 0.0 complete. Next: Stage 0.1 CALL-E account / KYC / extra-calls form.

## 2026-09-01 — Stage 0.1 CALL-E account, credits, key handling

### Context
Owner logged into CALL-E as `akrmcodes@gmail.com`, created a Developer API key, and submitted the extra-calls form. Need a safe place for the key (not git / Flutter / chat) and an honest 0.1 checkbox state.

### Done
- [`docs/contest/CALLE_STAGE0_OWNER_OPS.md`](contest/CALLE_STAGE0_OWNER_OPS.md): local `$HOME/.daftar-owner-ops/calle-api-key` (chmod 600) until Stage 0.3 Secret Manager; 20-call budget; extra-calls submitted
- Roadmap 0.1: account, API key created, extra-calls, 20-call note **checked**; **outbound KYC still open**
- [`docs/qa/flutter_env.template.md`](qa/flutter_env.template.md): `CALLE_API_KEY` is not an Envied key

### Architecture / decisions
Key never in this chat or git. Secret Manager `calle-api-key` is Stage **0.3**. Chat ringing ≠ Developer API KYC. Do not skip **0.2** US DID before Gate 0 smoke.

### Ops / verification
No `gcloud secrets create` this pass (no key file in owner-ops yet). No deploy.

### Status
0.1 blocked only on **outbound KYC**. Then 0.2 DID; 0.3 GCP secret + `daftar-call-e` naming (still no deploy of frozen service).

## 2026-09-01 — Stage 0.5 API 404 probe (pulse check)

### Context
Owner saved `calle-api-key` at `$HOME/.daftar-owner-ops/` (mode 600). Requested a zero-cost Developer API probe and whether outbound KYC / 0.3 can proceed.

### Done
- `GET https://api.heycall-e.com/v1/calls/{nonexistent}` with bearer from that file → HTTP **404** `not_found` (key authenticates; not 401/403 / `credential_grant_unavailable`)
- Bearer not printed. Roadmap 0.5 probe + Gate 0 404 / disclosure / extra-calls boxes `[x]`
- [`docs/contest/CALLE_STAGE0_OWNER_OPS.md`](contest/CALLE_STAGE0_OWNER_OPS.md): KYC likely not on the API Keys page; 0.3 secret create allowed

### Architecture / decisions
404 proves the **Developer API key**, not outbound PSTN KYC. Live `create_and_wait` (rest of 0.5) still needs a US DID (0.2). Frozen Cloud Run still untouched.

### Ops / verification
curl only. No Secret Manager write. No deploy.

### Status
Key is good. **0.3 yes** (secret + naming, never deploy `daftar-closing-agent`). **0.1 KYC** leave open until a dashboard Verification/Numbers flow exists or first `create` fails. **0.2** still required before Gate 0 live ring.

## 2026-09-01 — Stage 0.2 DID alternatives (Zadarma/Sonetel +967 SMS)

### Context
Owner was rejected by Sonetel and Zadarma Preferred because they could not verify a Yemeni mobile. Asked for a cheaper, reliable US inbound destination (Numero eSIM or similar) without using a friend’s number unless last resort.

### Done
- Researched email-signup DID shops vs consumer “virtual number” apps
- [`docs/contest/CALLE_STAGE0_OWNER_OPS.md`](contest/CALLE_STAGE0_OWNER_OPS.md) §0.2 try-order: Callcentric → DIDWW → VoIP.ms → BubblyPhone; Numero/GV/Twilio trial/TextNow called out
- [`docs/roadmap_v3.md`](roadmap_v3.md) 0.2 notes, purchase/answer checkboxes, Appendix E cost line, Appendix F risk row

### Architecture / decisions
CALL-E still dials a **US** destination (`region: US`). Failure mode was **account OTP to +967**, not US SSN. Do not enable SMS/10DLC. Do not forward to +967 as the primary path. Friend SA/AE/EG remains last-resort Arabic take. 0.2 boxes stay **open** until a human test call rings.

### Ops / verification
Web research only. No purchase, no `gcloud`, no deploy, no E.164 in git.

### Status
Owner buys one inbound US DID next (Callcentric PPM first). Then human ring → `create_and_wait`. 0.3 Secret Manager can still run in parallel.

## 2026-09-02 — Stage 0.2 Callcentric DID purchased (human ring still open)

### Context
Owner could not complete Zadarma/Sonetel (+967 SMS). Bought a Callcentric US Pay Per Minute DID and configured Linphone; asked for a settings review before the human ring / CALL-E `create_and_wait`.

### Done
- Confirmed SKU: US / NY 347 / Pay Per Minute (inbound PSTN, not residential-unlimited/911 SKU)
- `$HOME/.daftar-owner-ops/test-did`: mode 600, 12-byte `+1` E.164, not a placeholder, outside the git repo
- Roadmap 0.2: purchase + E.164 store `[x]`; human ring and SMS-off confirmation still `[ ]`
- [`docs/contest/CALLE_STAGE0_OWNER_OPS.md`](contest/CALLE_STAGE0_OWNER_OPS.md): 0.2 status without E.164/SIP secrets

### Architecture / decisions
CALL-E still dials this US destination. Linphone SIP: `sip.callcentric.net` + UDP matches Callcentric’s Linphone guide. Gmail login is Linphone.org (or Callcentric web), not the SIP identity. Do not enable SMS. Do not burn a CALL-E credit until a human PSTN call rings Linphone.

### Ops / verification
Inspected DID file **format only** (length, `+1`, mode). Did not print E.164. No `gcloud`, no deploy, no `create_and_wait`.

### Status
0.2 blocked on **Registered** + **human ring**. 0.3 can still run in parallel.

## 2026-09-02 — Stage 0.3 Secret Manager + call-e-runner IAM

### Context
Roadmap §0.3: same contest GCP project, name Cloud Run `daftar-call-e` without creating it, store `calle-api-key` in Secret Manager, keep Gmail secret available to the future service, leave frozen All Things Agentic Cloud Run untouched.

### Done
- [`agent/scripts/stage0_3_gcp.sh`](../agent/scripts/stage0_3_gcp.sh): freeze preflight, `--data-file` create, additive secret + project IAM, post-describe
- Secret `calle-api-key` version 1; accessor `call-e-runner` only (secret-level)
- `gmail-smtp-app-password`: added `call-e-runner` `secretAccessor`; **kept** `agent-runner`
- `call-e-runner` project roles: `aiplatform.user`, `logging.logWriter`, `speech.client` (no project-wide `secretAccessor`)
- Frozen revision still `daftar-closing-agent-00055-pbm`; Vertex still `TRUE` / `global`; `daftar-call-e` still absent
- Roadmap 0.3 boxes `[x]` including owner Console budget confirm ($50 / $100 / $140); Gate 0 freeze + no-secrets-in-git `[x]`; KYC still open
- [`docs/contest/CALLE_STAGE0_OWNER_OPS.md`](contest/CALLE_STAGE0_OWNER_OPS.md), [`docs/contest/AGENTIC_CLOUD_RUN_FREEZE.md`](contest/AGENTIC_CLOUD_RUN_FREEZE.md)
- [`test/core/contest/agentic_cloud_run_freeze_test.dart`](../test/core/contest/agentic_cloud_run_freeze_test.dart) forbids mutate/`versions access` in the 0.3 script

### Architecture / decisions
Dedicated SA `call-e-runner` for future `daftar-call-e`. File mounts are Stage 1 on that service only. Envied frozen hostname default unchanged. Did not enable `billingbudgets.googleapis.com`.

### Ops / verification
Script exit 0. Independent describe: secrets `calle-api-key` + `gmail-smtp-app-password`; IAM members as above. Payload never printed. No Cloud Run create/deploy.

### Status
0.3 code/GCP done. Budgets **$50 / $100 / $140** owner-confirmed in Console. Next: 0.4 kill switch docs, then 0.5 `create_and_wait` after Linphone human ring.

## 2026-09-02 — Stage 0.4 kill switch + allowlist (owner-ops)

### Context
Roadmap §0.4: document `CALLE_ALLOW_DIAL` default false, gitignored comma-separated E.164 allowlist, and Gate 0 local `true` for the one DID only.

### Done
- [`agent/scripts/stage0_4_allowlist.sh`](../agent/scripts/stage0_4_allowlist.sh): writes `calle-allow-dial=false`, copies `test-did` → `calle-allowlist`, `calle-allowlist-region=US` (mode 600; E.164 never printed)
- [`docs/contest/CALLE_STAGE0_OWNER_OPS.md`](contest/CALLE_STAGE0_OWNER_OPS.md) §0.4: parse rules (`true` exact lowercase only); 0.5 shell export recipe
- [`docs/qa/flutter_env.template.md`](qa/flutter_env.template.md): kill switch / allowlist are not Envied
- [`.gitignore`](../.gitignore): `.daftar-owner-ops/`
- Roadmap 0.4 boxes `[x]`
- [`test/core/contest/agentic_cloud_run_freeze_test.dart`](../test/core/contest/agentic_cloud_run_freeze_test.dart): no `\+1\d{10}` in owner-ops; script has no Cloud Run mutate strings

### Architecture / decisions
Locked env names for Stage 1: `CALLE_ALLOW_DIAL`, `CALLE_ALLOWLIST`, `CALLE_ALLOWLIST_REGION`. NANP region is **US** from config, not inferred from `+1`. No FastAPI parser this pass. Friend SA/AE/EG not on the list.

### Ops / verification
Script exit 0. Files outside the repo. No `gcloud`, no deploy, no `create_and_wait`.

### Status
0.4 done. Next: 0.5 laptop `create_and_wait` after Linphone human ring, with `CALLE_ALLOW_DIAL=true` in that shell only.

## 2026-09-02 — Stage 0.5 laptop smoke (Gate 0 live ring)

### Context
Roadmap §0.5 / Gate 0: one consented Developer API `create_and_wait` to the owner US DID via `calle-ai==0.7.0`, Linphone answering on Wi-Fi. Burns 1 of 20 contest credits. Production `https://api.heycall-e.com`. No webhook, no Cloud Run mutate, no Flutter.

### Done
- Pinned `calle-ai==0.7.0` in [`agent/requirements.txt`](../agent/requirements.txt); installed into **this** repo [`agent/.venv`](../agent/.venv) only (`python -m pip`, not the copied `bin/pip` shebang)
- [`agent/scripts/stage0_5_laptop_smoke.py`](../agent/scripts/stage0_5_laptop_smoke.py) + [`agent/scripts/stage0_5_laptop_smoke.sh`](../agent/scripts/stage0_5_laptop_smoke.sh): freeze refuse; `CALLE_ALLOW_DIAL` must be exact `true`; disk `calle-allow-dial` stays `false`; region `US`; last-4 mask; persist Idempotency-Key before POST
- Live result: `status=completed`, `task_completed=true`, `structured_result.can_hear_clearly=yes`, `call.id=call_GfN-BQcGMORm2NkgSfxdIw` (~103s). Evidence: `$HOME/.daftar-owner-ops/stage0_5-result.json` (not git)
- Roadmap 0.1 outbound KYC, remaining 0.5 boxes, and Gate 0 live-call boxes `[x]`
- [`docs/contest/CALLE_STAGE0_OWNER_OPS.md`](contest/CALLE_STAGE0_OWNER_OPS.md) §0.5 without E.164
- [`test/core/contest/agentic_cloud_run_freeze_test.dart`](../test/core/contest/agentic_cloud_run_freeze_test.dart): smoke contains `create_and_wait` / `calle-ai`; no `gcloud run deploy` / `versions access`; owner-ops still has no `\+1\d{10}`

### Architecture / decisions
`create_and_wait` remains Gate 0 laptop-only. Stage 1 Cloud Run will `create` + poll `GET`, never `create_and_wait`. Kill switch file still `false`. Envied frozen hostname unchanged. No `daftar-call-e` deploy.

### Ops / verification
Copied `agent/.venv` `bin/pip` originally targeted the heritage Agentic tree; install used `agent/.venv/bin/python -m pip` so this fork’s site-packages received `calle-ai==0.7.0`. Wrapper refuses an interpreter whose prefix is not this fork. `unset CALLE_ALLOW_DIAL` after the smoke. Disk allow-dial remains `false`. Frozen Cloud Run untouched.

### Status
Gate 0 live ring **passed**. Stage 1 UI is unblocked. Credits **19 / 20** remaining until extras land.

## 2026-09-02 — Stage 1.0 deploy skeleton `daftar-call-e`

### Context
Roadmap §1.0: create authenticated Cloud Run `daftar-call-e` from this fork (ADK `/run` + send-batch + TTS), leave frozen All Things Agentic revision untouched, and cut Envied off the frozen hostname. No call routes.

### Done
- [`agent/.gcloudignore`](../agent/.gcloudignore) so `--source=.` does not upload `.venv`
- Unlocked [`agent/scripts/deploy_daftar_call_e.sh`](../agent/scripts/deploy_daftar_call_e.sh): `DAFTAR_CALL_E_DEPLOY=true`; freeze preflight; Gmail copy from frozen describe; three custom audiences; `call-e-runner` actAs; `gcloud run deploy daftar-call-e` only
- Service **`daftar-call-e`**: revision `daftar-call-e-00002-k46` (00001 created; audiences set to 3 on 00002). URL `https://daftar-call-e-1487285471.us-central1.run.app` in `$HOME/.daftar-owner-ops/daftar-call-e-url`
- Runtime SA `call-e-runner@…`; min 0 / max 2 both layers; `--no-allow-unauthenticated`; invoker `allAuthenticatedUsers` + owner
- Secret mounts: `/secrets/gmail-smtp-app-password` and `/calle-secrets/calle-api-key` (Cloud Run rejects two secrets in one directory)
- `CALLE_ALLOW_DIAL=false`; no DID in Cloud Run env; `calle-ai==0.7.0` in the image, not called
- Envied `CLOSING_AGENT_BASE_URL` default `''`; gitignored `.env` pointed at the new URL; `env.g.dart` regenerated
- Frozen revision still `daftar-closing-agent-00055-pbm` / SA `agent-runner`
- Roadmap 1.0 boxes `[x]`; freeze tests updated; owner-ops + freeze snapshot notes

### Architecture / decisions
No `agent/calls/`. No `create_and_wait` on Cloud Run. Custom audiences must be `--set-custom-audiences` (three `--add` on first create stored one). Envied empty default is the fail-closed landmine fix. Same GCP project number appears in both `*.run.app` hosts; service **name** is the freeze boundary.

### Ops / verification
Wrapper first attempt failed validation (two secrets under `/secrets`) — no service created. Second attempt created 00001. Audience update created 00002. `tool/check_agentic_freeze.sh` Freeze OK throughout. Unauthenticated `GET /list-apps` → **403**. User `gcloud auth print-identity-token --audiences` is not valid for user accounts; Flutter uses the three custom audiences (J.1).

### Status
1.0 done. Next: 1.1 `POST /v1/calls/plan-batch` (Daftar-local, zero PSTN).

## 2026-09-02 — Stage 1.1 `POST /v1/calls/plan-batch`

### Context
Roadmap §1.1 / J.9: Daftar-local plan-batch beside email/TTS. Allowlist, J.10, DNC, kill switch, C.3 echo, memory-only confirm handle. Never import `calle` or dial. Deploy `daftar-call-e` only.

### Done
- [`agent/calls/`](../agent/calls/): `settings.py`, `j10.py`, `masking.py`, `schemas.py`, `handles.py`, `router.py` (`POST /v1/calls/plan-batch` only). No `client.py`
- Wired [`agent/main.py`](../agent/main.py) `include_router` (GFE IAM, no in-process JWT) and [`agent/Dockerfile`](../agent/Dockerfile) `COPY calls ./calls`
- [`agent/tests/test_calls_plan_batch.py`](../agent/tests/test_calls_plan_batch.py): RFC 555 numbers; YE / not-allowlisted / DNC / NANP region / kill switch / dry-run echo / happy-path handle; fake `CalleClient.calls.create` must not run; source has no `calle` / `create_and_wait`
- Catalog freeze still eight tools; no `plan_call` / `run_call` / `propose_call`. OpenAPI 2.5.0 path `POST /v1/calls/plan-batch` only (no run/get)
- [`agent/scripts/deploy_daftar_call_e.sh`](../agent/scripts/deploy_daftar_call_e.sh): `--env-vars-file` loads `CALLE_ALLOWLIST` / `CALLE_ALLOWLIST_REGION` from owner-ops without printing E.164; `CALLE_ALLOW_DIAL=false`
- Service revision **`daftar-call-e-00003-f4q`**. Frozen still **`daftar-closing-agent-00055-pbm`**
- Roadmap §1.1 boxes `[x]`; owner-ops 1.1 without E.164

### Architecture / decisions
Plan-batch is Daftar-local. `confirmHandle` is process-local; min-instances 0 drops it (same class as email idempotency). NANP `region` must equal `CALLE_ALLOWLIST_REGION` (demo `US`), never inferred from `+1`. YE / `+967` always `unsupportedRegion`. Kill switch off + `dryRun: true` → `dryRun` + C.3 echo, no handle, no 403. 403 remains for **run-batch** (1.2). Secrets stay split (`/secrets/gmail-smtp-app-password`, `/calle-secrets/calle-api-key`).

### Ops / verification
`agent/.venv` pytest: `tests/test_calls_plan_batch.py` + catalog freeze + retired webhooks — 24 passed. `flutter test test/core/contest/agentic_cloud_run_freeze_test.dart` — 8 passed. Wrapper deploy created 00003; first post-verify used `CALLE_ALLOWLIST_REGION` as the gcloud `--region` (fixed in wrapper, not redeployed). Re-ran describe/IAM verify: scale 0/2 both layers, audiences 3, allowlist present, region `US`, kill switch false. Unauthenticated `POST /v1/calls/plan-batch` → **403**. `tool/check_agentic_freeze.sh` Freeze OK. No live `/run`, send-batch, TTS, or run-batch.

### Status
1.1 done. Next: 1.2 `POST /v1/calls/run-batch` (`calls.create`, kill switch, exact confirm handle). No commit unless asked.

## 2026-09-02 — Stage 1.2 `POST /v1/calls/run-batch`

### Context
Roadmap §1.2 / J.9: after exact Daftar confirm handle, queue non-blocking `calle-ai` `calls.create`. Kill switch 403. No `create_and_wait`, no GET, no live PSTN.

### Done
- [`agent/calls/handles.py`](../agent/calls/handles.py): plan snapshot (token, phone, region, locale, task, DNC, trigger) + runId store; `compare_digest`; consume handle after queue
- [`agent/calls/client.py`](../agent/calls/client.py): lazy `from calle import CalleClient`; key file `/calle-secrets/calle-api-key`; `create` only with J.9 schemas; no wait
- [`agent/calls/router.py`](../agent/calls/router.py) `POST /v1/calls/run-batch`: 403 kill switch; sequential per-recipient create (`Idempotency-Key = {batchId}:{contactId}`) because C.3 is unique per contact
- [`agent/tests/test_calls_run_batch.py`](../agent/tests/test_calls_run_batch.py): RFC 555; recording fake.create; missing handle 400; wrong handle `invalidHandle`; YE / not-allowlisted no create; skippedDuplicate; logs have no handle / E.164 / key
- OpenAPI 2.6.0 run-batch path; catalog still eight tools; no GET path
- Deploy **`daftar-call-e-00004-l6n`**. Frozen still **`daftar-closing-agent-00055-pbm`**. `CALLE_ALLOW_DIAL=false`
- Roadmap §1.2 boxes `[x]`; owner-ops 1.2 without E.164

### Architecture / decisions
Cloud Run kill switch stays off — authenticated run-batch is 403 until Stage 1.4 / 4. Sequential `create` (one recipient per task) so each C.3 `task` is sent as-is. Plan snapshot required because J.9 run body is only `contactId` + `confirmHandle`. Min-instances 0 drops handles and runIds (same class as email idempotency).

### Ops / verification
`agent/.venv` pytest plan-batch + run-batch + catalog + retired webhooks — **35 passed**. Freeze Dart tests — 8 passed. Wrapper post-verify: scale 0/2, audiences 3, allowlist present, region `US`, kill switch false. Unauthenticated `POST /v1/calls/run-batch` → **403**. `tool/check_agentic_freeze.sh` Freeze OK. No live `/run`, SMTP, TTS, or authenticated run-batch.

### Status
1.2 done. Next: 1.3 `GET /v1/calls/{runId}`. No commit unless asked.

## 2026-09-02 — Stage 1.3 `GET /v1/calls/{runId}`

### Context
Roadmap §1.3 / J.9: read-only proxy of `calle-ai` `calls.get` returning J.9 camelCase (status, terminal, taskCompleted, validated structuredResult, masked phone). Never wait, never dial, never return API key or confirm handle. Kill switch does not 403 GET.

### Done
- [`agent/calls/client.py`](../agent/calls/client.py): `get()` — lazy `CalleClient`, single `client.calls.get`, maps 404 → `CallNotFoundError`, auth → `UpstreamAuthError`, timeout/connection → `UpstreamUnavailableError`
- [`agent/calls/get_map.py`](../agent/calls/get_map.py): snake_case → J.9 GET; `terminal` for `{completed, failed, canceled}`; integer coercion (`500.0` → `500`; `500.5` omitted + `needsHuman` when terminal)
- [`agent/calls/schemas.py`](../agent/calls/schemas.py): `CallStructuredResult`, `CallGetResponse`
- [`agent/calls/handles.py`](../agent/calls/handles.py): `runId → phoneMasked` index on successful queue
- [`agent/calls/router.py`](../agent/calls/router.py) `GET /v1/calls/{runId}`: observability `action=get`; never log handle/key/full E.164/evidence_quote
- [`agent/tests/test_calls_get.py`](../agent/tests/test_calls_get.py): fake get; queued/in_progress non-terminal; coercion; terminal missing outcome; 404; kill switch off still 200; E.164 masked in response/logs
- OpenAPI **2.7.0** GET path + `CallGetResponse`; catalog still eight tools
- Deploy **`daftar-call-e-00005-8kw`**. Frozen still **`daftar-closing-agent-00055-pbm`**. `CALLE_ALLOW_DIAL=false`
- Roadmap §1.3 boxes `[x]`; owner-ops §1.3 without E.164

### Architecture / decisions
GET is read-only — `CALLE_ALLOW_DIAL=false` does not block polling. One `get` per request; no `wait_for_result`. Outbound JSON strips raw CALL-E blob (no transcripts, full phones, evidence arrays). `needsHuman` on GET body for invalid schema or missing `outcome` on terminal. Process-local mask index is best-effort (same class as confirm handles).

### Ops / verification
`agent/.venv` pytest plan + run + get + catalog + retired webhooks — **46 passed**. Freeze Dart tests — 8 passed. Pre/post `tool/check_agentic_freeze.sh` = `daftar-closing-agent-00055-pbm`. Unauthenticated `GET /v1/calls/{runId}` → **403**. No live CALL-E GET of Gate 0 call ids. No commit unless asked.

### Status
1.3 done. Next: 1.4 smoke script + Stage 1 validation gate. No commit unless asked.

## 2026-09-02 — Stage 1.4 Tests + OpenAPI + no-PSTN smoke

### Context
Roadmap §1.4 / Stage 1 validation gate: unit tests with fake CALL-E client, catalog freeze, OpenAPI J.9 paths, owner-ops smoke. No PSTN. Kill switch stays false. No `daftar-call-e` redeploy (routes already on `00005-8kw`).

### Done
- [`agent/tests/test_calls_plan_batch.py`](../agent/tests/test_calls_plan_batch.py): SpyCreator — dry-run and kill-switch-off plan never call `create`
- [`agent/tests/test_calls_openapi_j9.py`](../agent/tests/test_calls_openapi_j9.py): OpenAPI 2.7.0 J.9 paths, GoogleIdToken, GET kill switch does not block, required fields, integer amount, eight tools
- [`agent/tests/test_tool_catalog_freeze.py`](../agent/tests/test_tool_catalog_freeze.py): ban `plan_call` / `run_call` / `get_call_run` / `propose_call`; calls router is FastAPI `include_router`
- [`agent/scripts/smoke_calls_plan_run.py`](../agent/scripts/smoke_calls_plan_run.py): owner-ops URL/allowlist, identity token, no E.164 in logs/evidence
- Roadmap §1.4 + Stage 1 validation gate `[x]`; owner-ops §1.4; README sibling smoke (heritage `smoke_1_4.py` not retargeted)

### Architecture / decisions
YE remains HTTP 200 + `unsupportedRegion` (J.9 per-row reject). HTTP 400 is cap / invalid request / missing handle. Smoke does not flip `CALLE_ALLOW_DIAL`. GET of a fake `call.id` is a read-only 404 probe, not a dial. OpenAPI stays **2.7.0** (no schema change).

### Ops / verification
`agent/.venv` pytest plan + run + get + OpenAPI J.9 + catalog + retired webhooks — **57 passed**. Freeze Dart tests — 8 passed. `tool/check_agentic_freeze.sh` = `daftar-closing-agent-00055-pbm`. Smoke `smoke_calls_plan_run.py` against `daftar-call-e` — **8/8 pass** (unauth 403, dry-run, YE reject, over-cap 400, plan killSwitch, run-batch 403, GET fake id 404). No deploy. No commit unless asked.

### Status
1.4 and Stage 1 gate done. Next: Stage 2 (schema 26 / device contract). No commit unless asked.

## 2026-09-03 — Stage 2.1 Schema 26

### Context
Roadmap §2.1: bump Drift/Drive backup schema **25 → 26** with Confirm & Call collection tables, per-contact `doNotCall`, integer money only. No repositories, no PSTN, no Flutter call UI.

### Done
- Domain enums: `call_batch_trigger.dart`, `call_batch_status.dart`, `call_run_outcome.dart`, `collection_promise_status.dart`
- Drift tables: `collection_call_batches_table.dart`, `collection_call_runs_table.dart`, `collection_promises_table.dart`; `contacts.doNotCall` on `contacts_table.dart`
- `Contact` entity + `ContactModel` + `contact_local_ds.dart` FTS search map `doNotCall`
- `DbConstants.schemaVersion` and `DriveBackupConstants.schemaVersion` **26**; `onUpgrade from < 26` in `drift_database.dart`
- [`test/data/datasources/local/schema_v26_test.dart`](../test/data/datasources/local/schema_v26_test.dart): version parity, integer money inserts, `doNotCall` default + round-trip, `sqlite_master`, no `RealColumn`
- `agent_schema_v19_test.dart` expects schema **26**
- `BACKUP_SPEC.md`, `GOOGLE_DRIVE_BACKUP_SPEC.md`, roadmap §2.1 `[x]`, `CONTEST_DISCLOSURE.md` Schema 26 row

### Architecture / decisions
`doNotCall` on `contacts` (not settings). Persist `runId` (= CALL-E `call.id`) only — no confirm-handle column. `promisedDate` / promise dates as `TEXT` `YYYY-MM-DD`. Display-only `collection_promises` — no ledger movement until Stage 4. Stage 8 sync tables remain inert.

### Ops / verification
`dart run build_runner build --delete-conflicting-outputs`. `flutter test` schema_v26 + agent_schema_v19 — **8 passed**. `flutter analyze` on touched lib files — clean (import ordering fixed). No Cloud Run deploy. No commit unless asked.

### Status
§2.1 done. Next: §2.2 E.164 + region helper. No commit unless asked.

## 2026-09-03 — Stage 2.2 E.164 + region

### Context
Roadmap §2.2: device-side CALL-E E.164 formatting and J.10 region/allowlist gate mirroring `agent/calls/j10.py`. No Flutter UI, no Envied allowlist, no PSTN.

### Done
- [`lib/domain/value_objects/phone_number.dart`](../lib/domain/value_objects/phone_number.dart): `e164` getter (`+` + digits, ITU regex); `normalized` unchanged for WhatsApp
- [`lib/domain/constants/j10_calle_regions.dart`](../lib/domain/constants/j10_calle_regions.dart): `supportedRegions`, `callingRegion`, NANP sentinel — lockstep with `j10.py` / GitHub
- [`lib/domain/value_objects/call_eligibility.dart`](../lib/domain/value_objects/call_eligibility.dart): sealed `CallEmpty` / `CallInvalid` / `CallUnavailable` / `CallNotAllowlisted` / `CallEligible`
- [`lib/domain/constants/j10_region_gate.dart`](../lib/domain/constants/j10_region_gate.dart): `J10RegionGate.evaluate` (region gate + allowlist; no DNC/kill switch)
- [`test/domain/value_objects/phone_number_test.dart`](../test/domain/value_objects/phone_number_test.dart): E.164 group
- [`test/domain/constants/j10_region_gate_test.dart`](../test/domain/constants/j10_region_gate_test.dart): YE, SA, NANP+US, AE/EG/OM, empty, invalid, not allowlisted
- Roadmap §2.2 `[x]`

### Architecture / decisions
YE → `CallUnavailable` (email rail in 2.3). NANP `+1` never inferred as `US`; `declaredRegion` must match `allowlistRegion` for +1. Allowlist passed as `Set<String>` argument (Stage 2.5 persists). Full GitHub `supportedRegions` set on device — not a 5-country subset.

### Ops / verification
`flutter test` phone_number + j10_region_gate — **64 passed**. `flutter analyze` on touched lib — clean. No Cloud Run deploy. No commit unless asked.

### Status
§2.2 done. Next: §2.3 aging split (`rail`). No commit unless asked.

## 2026-09-03 — Stage 2.3 Aging split

### Context
Roadmap §2.3 / Appendix D: after FIFO rank, attach dual-rail `OutreachRail`, cap call set at 5 and email set at 20 (PDF Top 5). Device ranks; Gemini does not pick contact IDs.

### Done
- [`lib/domain/enums/outreach_rail.dart`](../lib/domain/enums/outreach_rail.dart): `call`, `email`, `both`, `callUnavailable`, `skipped`
- [`lib/domain/constants/dual_rail_split.dart`](../lib/domain/constants/dual_rail_split.dart): `DualRailSplit.split` + `DualRailSplitResult` (`callSet`, `emailSet`, `pdfTop5`)
- [`lib/domain/value_objects/collections_candidate.dart`](../lib/domain/value_objects/collections_candidate.dart): `doNotCall`, `rail`
- [`lib/domain/constants/contact_email.dart`](../lib/domain/constants/contact_email.dart): `isPresentAndValid`
- [`lib/domain/constants/j10_calle_regions.dart`](../lib/domain/constants/j10_calle_regions.dart): `declaredRegionFor`
- [`lib/domain/constants/closing_agent_constants.dart`](../lib/domain/constants/closing_agent_constants.dart): `maxCallRecipients = 5`
- [`lib/data/datasources/local/contact_local_ds.dart`](../lib/data/datasources/local/contact_local_ds.dart): `getContactsEligibleForCollectionsOutreach` (no email predicate; includes `do_not_call`)
- [`lib/application/contact/get_collections_candidates_use_case.dart`](../lib/application/contact/get_collections_candidates_use_case.dart): overdue universe + rank + split; optional `allowlist` / `allowlistRegion` / `allowDial`
- [`lib/domain/value_objects/closing_ritual_result.dart`](../lib/domain/value_objects/closing_ritual_result.dart): `emailRailShortlist`, `callSet`; `reminderSet` from email rail
- [`test/domain/constants/dual_rail_split_test.dart`](../test/domain/constants/dual_rail_split_test.dart), updated candidates + ritual tests
- Roadmap §2.3 `[x]`

### Architecture / decisions
Rank first (FIFO + age/balance sort), split second. YE / unsupported phone + valid email → `callUnavailable` on email rail. Call eligibility uses Stage 2.2 `J10RegionGate` + DNC + `allowDial` (default false). Heritage SMTP reminder query unchanged. `ProposeClosingPlanPayload` still steps-only — no contact ID picker.

### Ops / verification
`flutter test` dual_rail_split + closing_ritual_result + get_collections_candidates — **27 passed**. `flutter analyze` on touched lib — clean. `build_runner` for `core_providers`. No PSTN. No commit unless asked.

### Status
§2.3 done. Next: §2.4 demo seeder. No commit unless asked.

## 2026-09-03 — Stage 2.4 Demo seeder

### Context
Roadmap §2.4: sample store seeds one call-eligible contact (Mohamed) from a gitignored US DID dart-define; remaining six overdue contacts use valid Yemen Mobile placeholders plus emails to prove J.10 → `callUnavailable` / email rail. No live numbers in `lib/` or committed `tool/`.

### Done
- [`lib/core/utils/demo_seed_us_did.dart`](../lib/core/utils/demo_seed_us_did.dart): `DAFTAR_SEED_US_DID` resolver (NANP only); `yemenPlaceholder(0…6)` with `+96777…` prefix
- [`lib/core/utils/demo_store_seeder.dart`](../lib/core/utils/demo_store_seeder.dart): Mohamed phone from `DemoSeedUsDid.resolve` or YE fallback; optional `callEligibleE164` test param; indices 1–6 always YE
- [`tool/demo_seed_emails.example.json`](../tool/demo_seed_emails.example.json): empty `DAFTAR_SEED_US_DID`
- [`tool/demo_seed_emails.md`](../tool/demo_seed_emails.md), [`docs/qa/flutter_env.template.md`](../docs/qa/flutter_env.template.md): overlay docs (not Envied, not `CALLE_ALLOWLIST`)
- Tests: [`test/core/utils/demo_seed_us_did_test.dart`](../test/core/utils/demo_seed_us_did_test.dart); extended [`dev_database_seeder_test.dart`](../test/core/utils/dev_database_seeder_test.dart) (YE E.164, US override, dual-rail `both` / `callUnavailable`); [`demo_seed_emails_test.dart`](../test/core/utils/demo_seed_emails_test.dart)
- Roadmap §2.4 `[x]`

### Architecture / decisions
Mohamed (index 0) is the mid-day capture + call target. Empty/invalid DID → all seven on YE placeholders (CI/judge-safe). US DID via `--dart-define-from-file=tool/demo_seed_emails.local.json` only. Replaced invalid `+96770…` phones with `77`-prefix numbers so `PhoneNumber.isValid` and YE gate apply. No logging of DID. Stage 2 validation gate stays open (2.5).

### Ops / verification
`flutter test` demo_seed_us_did + demo_seed_emails + dev_database_seeder — **20 passed**. `flutter analyze` on touched lib/tests — clean. No PSTN. No commit unless asked.

### Status
§2.4 done. Next: §2.5 allowlist + DNC on device. No commit unless asked.

## 2026-09-03 — Stage 2.5 Allowlist + DNC on device

### Context
Roadmap §2.5: device-side defense in depth — compile-time `CALLE_*` policy (lockstep with Cloud Run), `RunBatchRecipientGuard` as last gate before future `run-batch`, read-only Settings kill-switch stub, and `doNotCall` preserved on contact update. No HTTP, Envied, schema 27, or PSTN.

### Done
- [`lib/domain/constants/calle_device_policy.dart`](../lib/domain/constants/calle_device_policy.dart): `parse` / `fromCompiled()` — exact `"true"` for `allowDial`, comma allowlist, default region `US`
- [`lib/domain/constants/run_batch_recipient_guard.dart`](../lib/domain/constants/run_batch_recipient_guard.dart): `RunBatchRecipientGuard.select` with omit reasons + cap 5
- [`lib/domain/constants/j10_region_gate.dart`](../lib/domain/constants/j10_region_gate.dart): comment — DNC/kill switch live in dual-rail + guard
- [`lib/application/agent/run_closing_ritual_use_case.dart`](../lib/application/agent/run_closing_ritual_use_case.dart): optional `devicePolicy` → candidates
- [`lib/presentation/providers/core_providers.dart`](../lib/presentation/providers/core_providers.dart): `calleDevicePolicyProvider`
- [`lib/presentation/providers/closing_agent_controller.dart`](../lib/presentation/providers/closing_agent_controller.dart): policy into candidates query
- [`lib/domain/repositories/contact_repository.dart`](../lib/domain/repositories/contact_repository.dart), [`update_contact_use_case.dart`](../lib/application/contact/update_contact_use_case.dart), [`contact_repository_impl.dart`](../lib/data/repositories/contact_repository_impl.dart): preserve `doNotCall` on update
- Settings stub: [`settings_screen.dart`](../lib/presentation/screens/settings/settings_screen.dart) + ARB `settingsCalleAllowDial*`
- Overlay docs: [`tool/demo_seed_emails.example.json`](../tool/demo_seed_emails.example.json), [`tool/demo_seed_emails.md`](../tool/demo_seed_emails.md), [`docs/qa/flutter_env.template.md`](../docs/qa/flutter_env.template.md)
- Tests: `calle_device_policy_test`, `run_batch_recipient_guard_test`, candidates DNC, ritual policy forward, `contact_do_not_call_test`, extended `demo_seed_emails_test`
- Roadmap §2.5 `[x]`; Stage 2 validation gate unit tests / seeder / analyze `[x]` (Schema 26 device smoke still open)

### Architecture / decisions
Server remains authoritative; device filter is defense in depth. `DAFTAR_SEED_US_DID` and `CALLE_ALLOWLIST` stay independent. Kill-switch stub is read-only (`GlowPillToggle` disabled) until Stage 5.2 persistence. No contact-edit DNC UI this slice.

### Ops / verification
`flutter test` policy + guard + candidates + ritual + contact DNC + demo_seed_emails — **30 passed**. `build_runner` for `calleDevicePolicyProvider`. `flutter gen-l10n`. `flutter analyze` on touched lib — clean. No PSTN. No commit unless asked.

### Status
§2.5 done. Stage 2 gate: only **Schema 26 migrates on a debug install** remains unchecked. Next: Stage 3 Confirm & Call UI. No commit unless asked.

## 2026-09-03 — Stage 3.1 Collections Desk (HITL, no HTTP)

### Context
Roadmap §3.1 / Chapter 3 steps 7–8 / Appendix C.3: Khazna HITL Collections Desk with one consent card (Confirm & Call · Confirm & Send), dual-rail badges, C.3 task preview matching wire `task`, promise≠payment copy, and call progress from per-row results only. No `plan-batch` HTTP, no PSTN, no auto-dispatch.

### Done
- [`lib/domain/constants/collections_call_task_composer.dart`](../lib/domain/constants/collections_call_task_composer.dart): C.3 EN lockstep + AR equivalent; `amount_line` from int via C.2 formatter; credit-limit extra sentence
- [`lib/domain/value_objects/collections_call_task.dart`](../lib/domain/value_objects/collections_call_task.dart), [`collections_call_progress.dart`](../lib/domain/value_objects/collections_call_progress.dart), [`collections_call_row_status.dart`](../lib/domain/enums/collections_call_row_status.dart)
- [`lib/domain/value_objects/collections_desk_row.dart`](../lib/domain/value_objects/collections_desk_row.dart): optional `callTask`
- [`lib/application/agent/build_collections_desk_use_case.dart`](../lib/application/agent/build_collections_desk_use_case.dart): full shortlist rows; C.3 on call/both; C.2 on email rails
- Presentation: [`collections_desk_consent_card.dart`](../lib/presentation/screens/closing_agent/widgets/collections_desk_consent_card.dart), [`outreach_rail_badge.dart`](../lib/presentation/screens/closing_agent/widgets/outreach_rail_badge.dart), [`collections_call_progress_bar.dart`](../lib/presentation/screens/closing_agent/widgets/collections_call_progress_bar.dart); panel/row/screen wiring
- [`lib/presentation/providers/closing_agent_state.dart`](../lib/presentation/providers/closing_agent_state.dart): `callConsented`, `sendConsented`, `callProgress`, desk counts
- [`lib/presentation/providers/closing_agent_controller.dart`](../lib/presentation/providers/closing_agent_controller.dart): `confirmAndCall` (guard + planned progress, no Dio); `confirmWithoutCalling`; `_autoDispatchOutreach` default false; desk opens when shortlist non-empty; email dispatch filters email-rail rows only
- ARB `collectionsDesk*` + `flutter gen-l10n`
- Tests: composer, progress, build desk dual-rail, consent card, panel SMTP HITL, controller Confirm & Call / without calling
- Roadmap §3.1 `[x]` (3.2–3.4 and Stage 3 gate unchanged)

### Architecture / decisions
C.3 bodies live in domain constants (preview == wire). One lapis fill per desk (promise banner). Primary glow: Confirm & Call when `callSet` non-empty, else Confirm & Send. Progress `callingIndex` = count of non-`planned` rows — no timer. Heritage Hybrid E leftover behind `showHybridELeftover` (default false).

### Ops / verification
`flutter test` collections_desk_consent + panel + build_collections_desk + collections_call_task_composer + collections_call_progress — **26 passed**. Controller Confirm & Call / without-calling tests passed. `flutter analyze` — no errors (info lints in test helpers only). No HTTP. No PSTN. No commit unless asked.

### Status
§3.1 done. Next: §3.2 B-trigger sheet. Stage 3.4 device dry-run vs Cloud Run gate still open.

## 2026-09-03 — CALL-E credits: +200 approved

### Context
Owner received **+200** extra CALL-E calls (form approved). Docs still referenced the original **20**-call free pool and “until extras land” language.

### Done
- [`docs/roadmap_v3.md`](roadmap_v3.md): Credits row, slip protocol, §0.1 checkbox note, Appendix E budget hygiene, Appendix F risk register — **200** in pool (1 spent Gate 0)
- [`docs/contest/CALLE_STAGE0_OWNER_OPS.md`](contest/CALLE_STAGE0_OWNER_OPS.md): §0.1 credits table + Gate 0 smoke credit line
- [`docs/contest/README.md`](contest/README.md): index blurb **200**-call budget

### Architecture / decisions
Historical project-log entries (e.g. **19 / 20** after Gate 0) left unchanged — accurate at time of write. Email send-set cap **≤20** and unrelated “20” values untouched.

### Ops / verification
**199 / 200** remaining after Gate 0 smoke. Product recipient cap **5** now that credits are confirmed.

### Status
Credits docs current. No code changes.

## 2026-09-03 — Stage 3.1 review + analyze fixes

### Context
Owner asked for a full review of the Stage 3.1 Collections Desk slice (many files) and a clean `flutter analyze`.

### Done
- Progress bar: track/fill now `StackFit.expand` + `SizedBox.expand` so `Calling i of N` actually paints (was 0×0)
- `confirm()` `autoDispatch` default **false** — production Confirm & Send on the plan no longer silent-SMTP; desk Confirm & Send is the fire
- `confirmAndCall` still runs the guard; kill switch / empty allowlist still seeds planned progress from the visible call set
- SMTP success skips leftover pending call-only rows before the report
- Lapis Law: Retry / SMTP Sending chrome is **secondary** while the consent card is on screen
- Consent card: one primary glow; tertiary uses `DaftarButton` haptics only
- Rail badge 32dp; C.3/C.2 gap; unused import; import order
- Tests: kill-switch progress seed; desk shows full shortlist (email cap 20); Approve path explicit `approveAndSend()`
- `flutter analyze` — **No issues found**

### Ops / verification
`flutter test` composer + progress + build desk + consent + panel + row + closing_agent_controller — **77 passed**. No HTTP. No PSTN. No commit unless asked.

### Status
§3.1 still ticked. 3.2–3.4 unchecked.

## 2026-09-04 — CALL-E credits doc sweep (200 pool)

### Context
Owner confirmed **+200** extra CALL-E calls approved. Remaining forward-looking docs still had “submitted / not guaranteed” wording from the pre-approval **20**-call era.

### Done
- [`docs/roadmap_v3.md`](roadmap_v3.md): v3.2 changelog credits note; §0.1 extra-calls checkbox; Stage 0 validation gate — **approved 2026-09-03**, **200** in pool

### Architecture / decisions
Historical `project_log` entries (e.g. **19 / 20** after Gate 0) unchanged. SMTP send-set cap **≤20**, Drift schema **20**, Egypt **+20**, and other unrelated “20” values untouched.

### Ops / verification
**199 / 200** remaining after Gate 0. Product recipient cap **5**.

### Status
Credits language current across active CALL-E docs.

## 2026-09-04 — Stage 3.1 desk gating + dual-rail demo seed

### Context
Owner debug-ran without `--dart-define-from-file`, so Try with Demo Store seeded seven Yemeni phones. Close-the-day showed only plan-review Send / without sending. Confirm & Call never appeared. Dual rail (YE → email, US DID → call) was already specified; the desk call set was emptied by kill switch + empty allowlist.

### Done
- [`lib/domain/constants/dual_rail_split.dart`](../lib/domain/constants/dual_rail_split.dart): call-set membership is region + allowlist + DNC + cap 5 — **not** `CALLE_ALLOW_DIAL`. Kill switch stays on [`RunBatchRecipientGuard`](../lib/domain/constants/run_batch_recipient_guard.dart)
- [`lib/domain/constants/calle_device_policy.dart`](../lib/domain/constants/calle_device_policy.dart): allowlist entries normalized via `PhoneNumber.e164`
- [`lib/presentation/providers/closing_agent_controller.dart`](../lib/presentation/providers/closing_agent_controller.dart): non-empty shortlist always opens the desk (including Confirm without sending). SMTP ID-token preflight no longer blocks the desk when a call set exists
- [`lib/presentation/screens/closing_agent/widgets/collections_desk_consent_card.dart`](../lib/presentation/screens/closing_agent/widgets/collections_desk_consent_card.dart): hide Confirm & Call / without calling when `callCount == 0`
- ARB plan copy: next screen is Collections (EN+AR)
- Overlay docs: [`tool/demo_seed_emails.md`](../tool/demo_seed_emails.md), [`docs/contest/CALLE_STAGE0_OWNER_OPS.md`](contest/CALLE_STAGE0_OWNER_OPS.md), [`docs/qa/flutter_env.template.md`](qa/flutter_env.template.md), root README
- Gitignored `tool/demo_seed_emails.local.json` written from owner-ops `test-did` (DID + allowlist, `CALLE_ALLOW_DIAL` empty). Not in git

### Architecture / decisions
Confirm & Call remains local HITL (`planned` progress only) — no `plan-batch` / `run-batch` / PSTN. Live ring is Stage 4. No E.164 in committed markdown. Cloud Run allowlist is a separate owner-ops copy.

### Ops / verification
`flutter analyze` on touched files — clean. Targeted tests — **132 passed**. Overlay `git check-ignore` confirmed. Linphone not used this pass.

### Status
§3.1 desk HITL is reachable with the overlay + re-seed. Next: §3.2 B-trigger, §3.3 HUD, §3.4 device dry-run.

## 2026-09-04 — Dedicated Collections Desk + live Confirm & Call (v3.3)

### Context
Plan review still started the close with heritage Send copy, and the Collections Desk was staged as compact taskmaster (“Dispatch collection emails”). Confirm & Call was local `planned` rows only. Cloud Run `daftar-call-e` had `CALLE_ALLOW_DIAL=false`, so device `run-batch` could not ring. Binding contract updated first, then desk UX, J.9 client, laptop smoke, and a demo-window deploy of **`daftar-call-e` only**.

### Done
- [`docs/roadmap_v3.md`](roadmap_v3.md) **v3.3**: plan confirm starts the ritual only; dual-rail consent is a **dedicated Collections Desk** after aging; device Confirm & Call = `plan-batch` → `run-batch` → poll GET. Kill switch `true` is a demo-window opt-in on `daftar-call-e` (default remains false). Live window min-instances **1**. No E.164 in the file.
- Desk UX: compact taskmaster removed on `ritualDesk` ([`closing_agent_screen.dart`](../lib/presentation/screens/closing_agent/closing_agent_screen.dart)). ARB `closingTaskOpenDesk` = Open collections desk / فتح مكتب التحصيل. Plan pair = Start close / Start close without outreach.
- Overlay lockstep (gitignored): last-4 + length agree across owner-ops `test-did`, `calle-allowlist`, and `tool/demo_seed_emails.local.json`. Device `CALLE_ALLOW_DIAL` exact `true` for this pass.
- Flutter J.9: domain VOs + remote DS `POST /v1/calls/plan-batch`, `POST /v1/calls/run-batch`, `GET /v1/calls/{runId}`; use cases; `confirmAndCall` plan→run→poll; one `invalidHandle` retry; persist `collection_call_runs` + integer `collection_promises`; **no** `AddTransactionUseCase`. YE omitted from plan-batch. Kill switch 403 → `needsHuman`.
- [`agent/scripts/deploy_daftar_call_e.sh`](../agent/scripts/deploy_daftar_call_e.sh): opt-in `DAFTAR_CALL_E_ALLOW_DIAL=true` and `DAFTAR_CALL_E_MIN_INSTANCES=0|1`. Post-verify expects the opted values (not hardcoded false).

### Architecture / decisions
Providers call use cases only. Same Google ID-token as SMTP. Never log confirm handles, API keys, or full E.164. Progress from GET, not a fake spinner. Wrapper default remains `CALLE_ALLOW_DIAL=false` / min 0. Frozen Agentic service is describe-only.

### Ops / verification
- Laptop smoke (`CALLE_ALLOW_DIAL=true` in-process only): dest last-4 `7244`, region `US`, `status=completed`, `call.id=call_GfN-BQcGMORm2NkgSfxdIw`, ~4s. Persisted idempotency key reused — treat remaining credits as **199 / 200** unless the dashboard shows otherwise. Did **not** mutate Cloud Run.
- Deploy **`daftar-call-e`** revision `daftar-call-e-00006-6vc`: `CALLE_ALLOW_DIAL=true`, min **1** / max **2**, SA `call-e-runner`. Frozen `daftar-closing-agent-00055-pbm` unchanged (`tool/check_agentic_freeze.sh` Freeze OK).
- Targeted tests (GET coerce, remote DS, persist, controller plan/run/GET/YE/403/retry/timeout, desk “Dispatch collection emails” absent) — **102 passed**. `dart analyze` on touched files — no errors.
- Device `R5CT10G3LXH` debug install with overlay is the remaining HITL: re-seed → Start close → aging → full desk → Confirm & Call. Gate 4 film still owner. 3.2 / 3.3 out of scope.

### Status
Roadmap §3.1 live progress, §3.4, §4.1, §4.2 write (except contact-card polish), §4.3 email independence ticked. Gate 3 device live checkbox and Gate 4 film remain open. **Revert Cloud Run** (`DAFTAR_CALL_E_ALLOW_DIAL` unset, min 0) after the device ring — do not leave kill switch true as the new default.

## 2026-09-04 — Cloud Run J.9 live (schema fix) + freeze intact

### Context
Owner asked to confirm publish vs frozen Agentic, then live-test **Cloud Run** J.9 (dry-run, then one dial), then the Flutter app. First `run-batch` on `00006` returned `failed` / `needsHuman` with no `runId` in ~2s.

### Done
- Read-only: frozen **`daftar-closing-agent-00055-pbm`** / SA `agent-runner`. CALL-E service **`daftar-call-e-00006-6vc`** then **`daftar-call-e-00007-vd6`**. Never mutated the frozen service.
- Dry-run subset [`agent/scripts/smoke_calls_dry_run_window.py`](../agent/scripts/smoke_calls_dry_run_window.py): unauth 403, `dryRun`, YE `unsupportedRegion`, over-cap 400, GET fake 404 — **5/5**. Dest last-4 `7244`. No `run-batch`.
- Root cause: CALL-E `recipient_result_schema` **400** `recipient_result_schema_invalid` — JSON Schema `type: ["integer","null"]` unsupported. Fixed [`agent/calls/schemas.py`](../agent/calls/schemas.py) to optional scalar types. [`docs/roadmap_v3.md`](roadmap_v3.md) J.9 snippet + v3.3 note. Create failures log `type`/`code` only ([`agent/calls/router.py`](../agent/calls/router.py)).
- Redeploy **`daftar-call-e` only** (`00007-vd6`): kill switch still **true**, min **1**. Post-verify freeze OK.
- Live J.9 [`agent/scripts/smoke_calls_live_j9.py`](../agent/scripts/smoke_calls_live_j9.py): plan 200 → run 200 → GET terminal. `runId=call_zQn3UWw0E9hTHp1rN2R75g`, `status=completed`, dest last-4 `7244`. Connectivity task → `taskCompleted` with no collections `outcome` → `needsHuman` (no invented amount). Evidence in owner-ops only.

### Architecture / decisions
Do not run Stage 1.4 `smoke_calls_plan_run.py` while the demo window is on (it asserts killSwitch). Laptop `calle-ai` create is not Cloud Run proof. Wrapper default remains false / min 0.

### Ops / verification
`agent/.venv` pytest plan/run/get/openapi — **51 passed**. Credits: this Cloud Run call is a **new** `call.id` → treat remaining as **198 / 200**. Device `flutter run` overlay **aborted** twice (`assembleDebug` exit 143). Demo window **left on** for Confirm & Call. Revert after the device ring.

### Status
Cloud J.9 PSTN path proven on `daftar-call-e`. Flutter HITL and kill-switch revert still open.

## 2026-09-04 — Completed-call banner fix + demo window revert

### Context
Owner confirmed the device Confirm & Call **did ring** (HITL succeeded despite earlier `assembleDebug` abort). GET was `status=completed` with `taskCompleted` and **no** collections `outcome`. Two stacked bugs showed an error sheet titled “Calls are paused” / “The call needs a person to review.” Ledger stayed unchanged (correct — no invented `promised_amount_minor`). Plan: treat that GET as success, split copy, then close the `daftar-call-e` demo window.

### Done
- [`lib/domain/value_objects/call_get_result.dart`](../lib/domain/value_objects/call_get_result.dart): do not coerce `needsHuman` from completed + missing outcome; ignore wire `needsHuman` on clean `completed` unless `amountInvalid`. `deskStatus` = **completed** even without outcome; `amountInvalid` / `failed` / `canceled` → failed. Never `delivered` / `paid`.
- [`lib/presentation/providers/closing_agent_controller.dart`](../lib/presentation/providers/closing_agent_controller.dart) `_pollQueuedCalls`: persist terminal as before (no `AddTransactionUseCase`; no promise upsert without valid int + `outcome=promised`). `_calleNeedsHuman` only for `amountInvalid` or non-completed terminal / true review. Completed without structured promise: row **completed**, **no** `actionFailure`.
- ARB EN+AR + gen-l10n: `errorCalleNeedsHumanTitle` (“Call needs a look” / “المكالمة تحتاج نظرة”), `errorCallePollTimeoutTitle` (“Call timed out” / “انتهى وقت المكالمة”). [`error_translator.dart`](../lib/core/utils/error_translator.dart): kill-switch title only for `calle_kill_switch`.
- [`agent/calls/get_map.py`](../agent/calls/get_map.py): `status == completed` without outcome → `needsHuman=false` (do not invent amount). `schema_invalid` still `needsHuman`. `failed`/`canceled` without outcome still `needsHuman`.
- Tests: [`call_get_result_test.dart`](../test/domain/value_objects/call_get_result_test.dart), controller completed-without-outcome (no error sheet), ErrorTranslator titles, [`agent/tests/test_calls_get.py`](../agent/tests/test_calls_get.py) `test_completed_without_outcome_is_not_needs_human`.
- [`docs/roadmap_v3.md`](roadmap_v3.md): Gate 3 “Device Confirm & Call hits J.9” **ticked**. §4.2: persist run, no invented amount, no paused copy. Gate 4 film **unchecked**.

### Architecture / decisions
Completed connectivity task without collections schema is a successful ring, not a review failure. Integer money unchanged. Wrapper default stays `CALLE_ALLOW_DIAL=false` / min 0. Never `gcloud run deploy daftar-closing-agent`. After revert, device Confirm & Call **403** until a future demo window.

### Ops / verification
- Flutter tests (GET VO, remote DS, ErrorTranslator, controller) — **81 passed**. `agent/.venv` pytest `test_calls_get.py` — **12 passed**. `dart analyze` on touched files — no issues.
- Deploy **`daftar-call-e` only** (`DAFTAR_CALL_E_DEPLOY=true`, `DAFTAR_CALL_E_ALLOW_DIAL` unset, min default **0**): revision **`daftar-call-e-00008-nbv`**. Post-verify: `CALLE_ALLOW_DIAL=false`, scale **0/2**, SA `call-e-runner`. Ships `get_map.py` and closes the window in one revision.
- `bash tool/check_agentic_freeze.sh` — **Freeze OK** `daftar-closing-agent-00055-pbm`.
- Credits **198 / 200**. Cloud Run live `call_zQn3UWw0E9hTHp1rN2R75g` already counted; this pass did not dial. Dest last-4 from prior live test: `7244`. No DID in this log.

### Status
Banner root cause fixed. Demo window closed. Gate 3 device J.9 green. Next: Stage 3.2 B-trigger / 3.3 HUD / Gate 4 film when the owner opens a new demo window.

## 2026-09-05 — Stage 3.2 credit-limit B-trigger (HITL)

### Context
Roadmap §3.2 / Chapter 5: after a debt save where `CreditWarningLevel.exceeded`, prompt the merchant to open outreach — never auto-dial. Yes uses the same Collections Desk and `plan-batch` / `run-batch` with `trigger=creditLimit`. No leaves the ledger as already committed (Model C). Not the filmed climax; kill switch stays false on `daftar-call-e`.

### Done
- [`lib/presentation/screens/contact/widgets/credit_limit_call_sheet.dart`](../lib/presentation/screens/contact/widgets/credit_limit_call_sheet.dart): Khazna confirmation sheet (Prepare the call / Not now), integer outstanding vs limit, promise ≠ payment banner. No `AlertDialog`.
- [`lib/presentation/screens/contact/credit_limit_b_trigger.dart`](../lib/presentation/screens/contact/credit_limit_b_trigger.dart): shared helper after debt save; navigates to Closing Agent when accepted.
- Wired exceeded debt path: [`add_transaction_dialog.dart`](../lib/presentation/screens/transaction/widgets/add_transaction_dialog.dart), [`quick_add_bottom_sheet.dart`](../lib/presentation/widgets/transactions/quick_add_bottom_sheet.dart), agent `confirm` / `confirmCaptureBundle` via `pendingCreditLimitPromptContactId` + [`closing_agent_screen.dart`](../lib/presentation/screens/closing_agent/closing_agent_screen.dart) listener.
- [`ClosingAgentController.openCreditLimitDesk`](../lib/presentation/providers/closing_agent_controller.dart): one contact via [`GetCollectionsCandidatesUseCase`](../lib/application/contact/get_collections_candidates_use_case.dart) `contactId` filter + dual rail; no ritual backup; `sendOutreachEnabled: true`. `finishDesk` returns `idle` for credit-limit (no day seal report).
- `callBatchTrigger` on [`ClosingAgentState`](../lib/presentation/providers/closing_agent_state.dart) threaded through desk compose, `confirmAndCall`, persist. C.3 hold sentence via [`CollectionsCallTaskComposer`](../lib/domain/constants/collections_call_task_composer.dart).
- ARB EN+AR + `errorCreditLimitNoOutreach`. [`collections_desk_panel.dart`](../lib/presentation/screens/closing_agent/widgets/collections_desk_panel.dart) credit-limit subtitle.

### Architecture / decisions
Second HITL only — sheet does not HTTP. Confirm & Call remains sole PSTN consent. Skip prompt during close-day `ritualDesk` / `ritualRunning`. Payments never prompt. Providers → use cases unchanged.

### Ops / verification
Targeted tests: credit-limit sheet, candidates `contactId` filter, desk compose hold sentence, controller `openCreditLimitDesk` (no plan/run), `finishDesk` → idle, `confirmAndCall` sends `creditLimit`. `dart analyze` on touched files. No Cloud Run deploy. No DID.

### Status
Roadmap §3.2 ticked. Gate 3 B-trigger no auto-dial ticked. Next: §3.3 HUD call chip, Gate 4 film when demo window reopens.

## 2026-09-05 — Stage 3.3 Architecture HUD call chip

### Context
Roadmap §3.3: extend the contest Architecture HUD with a CALL-E call chip (`Call ·` + `runId` last-8 + status). SMTP `Sent ·` chip unchanged. Never label completed as delivered or paid. Presentation-only — reads device `callProgress` updated by GET poll; no Cloud Run deploy.

### Done
- [`lib/domain/value_objects/collections_call_progress.dart`](../lib/domain/value_objects/collections_call_progress.dart): optional `runId` on progress rows (`call.id`).
- [`lib/presentation/providers/closing_agent_controller.dart`](../lib/presentation/providers/closing_agent_controller.dart): persist `runId` when `run-batch` queues; poll updates status without clearing id.
- [`lib/presentation/providers/architecture_hud_provider.dart`](../lib/presentation/providers/architecture_hud_provider.dart): `callRunId` + `callStatus` via `resolveCallChip`; passes `agent.callProgress`.
- [`lib/presentation/shared/widgets/daftar_architecture_hud.dart`](../lib/presentation/shared/widgets/daftar_architecture_hud.dart): `_CallChipRow` + `_CallStatusPill` (planned / ringing lapis glow / completed ink / failed debt border); telemetry strip above SMTP row.
- ARB EN+AR: `architectureHudCallId`, `architectureHudCallStatusOnly`, status labels (`planned` / `ringing` / `completed` / `failed`).
- Tests: [`architecture_hud_provider_test.dart`](../test/presentation/providers/architecture_hud_provider_test.dart), [`daftar_architecture_hud_test.dart`](../test/presentation/shared/widgets/daftar_architecture_hud_test.dart), [`collections_call_progress_test.dart`](../test/domain/value_objects/collections_call_progress_test.dart).

### Architecture / decisions
HUD never HTTP-polls. Last progress row with `runId` wins (SMTP Message-ID pattern). `completed` is CALL-E terminal status — not payment, not delivery. Khazna: monochrome fill, lapis border/glow on ringing pill only, no payment green on completed.

### Ops / verification
`flutter test` on HUD provider + widget + progress tests — **41 passed**. `flutter gen-l10n`. `dart analyze` on touched files — no errors. No Cloud Run deploy.

### Status
Roadmap §3.3 all four items ticked. Gate 3 HUD call chip ticked. Next: Gate 4 film / §4.4 HUD updates from live poll when demo window reopens.

## 2026-09-06 — Stage 4.1 Device poll loop hardening

### Context
Review of roadmap §4.1 found the happy path (persist `runId`, ~60s then 5–10s GET, timeout without re-create) was already correct but airplane-mode during poll, GET-driven progress, Drift on timeout, and `finishDesk` races needed hardening.

### Done
- [`lib/presentation/providers/closing_agent_controller.dart`](../lib/presentation/providers/closing_agent_controller.dart): GET `Left` surfaces `ErrorTranslator` copy and keeps polling; successful GET clears transient `NetworkFailure` only; `persistQueued` `Left` surfaced; rows stay `planned` until GET; timeout `persistTerminal` (`rawStatus: timeout`, `needsHuman: true`); `_callPollEpoch` invalidates stale UI on `finishDesk` / `confirmWithoutCalling` (Drift terminal writes still run).
- [`lib/domain/value_objects/call_get_result.dart`](../lib/domain/value_objects/call_get_result.dart): `planned` / `queued` / `preparing` / `unknown` → `planned`; `ringing` / `in_progress` → `ringing`; `canceled` → `failed`.
- [`lib/domain/value_objects/collections_call_progress.dart`](../lib/domain/value_objects/collections_call_progress.dart): `latestRowStatus` for desk status word.
- [`lib/presentation/screens/closing_agent/widgets/collections_call_progress_bar.dart`](../lib/presentation/screens/closing_agent/widgets/collections_call_progress_bar.dart): HUD ARB status word for latest row (no `delivered` / `paid`).
- Tests: [`call_get_result_test.dart`](../test/domain/value_objects/call_get_result_test.dart), [`collections_call_progress_test.dart`](../test/domain/value_objects/collections_call_progress_test.dart), [`collections_call_progress_bar_test.dart`](../test/presentation/screens/closing_agent/widgets/collections_call_progress_bar_test.dart), extended [`closing_agent_controller_test.dart`](../test/presentation/providers/closing_agent_controller_test.dart) (network GET, timeout Drift, epoch race, planned-until-GET).

### Architecture / decisions
Never `run-batch` again to poll. Poll epoch guards UI only — terminal Drift must not lose `runId`. Reused HUD status ARB keys on desk bar (Lapis 2dp stripe unchanged). §4.1 boxes remain ticked; §4.4 / Gate 4 film out of scope.

### Ops / verification
`flutter test` on touched test files — all passed. `flutter analyze` — no issues. No Cloud Run deploy.

### Status
Roadmap §4.1 hardened and remains ticked. Next: §4.2 contact-card polish or §4.4 HUD poll observability when owner prioritizes.

## 2026-09-06 — Stage 4.2 Write-back hardening

### Context
Review of roadmap §4.2 found integer write-back, Drift upsert, and no-ledger-txn rules were already correct, but `promised_date` was not validated on device, `persistTerminal` `Left` was dropped, and the contact card never read `collection_promises`.

### Done
- [`lib/domain/constants/promised_calendar_day.dart`](../lib/domain/constants/promised_calendar_day.dart): `YYYY-MM-DD` calendar validation (matches Cloud Run `get_map.py`).
- [`lib/domain/value_objects/call_get_result.dart`](../lib/domain/value_objects/call_get_result.dart): `dateInvalid` → `needsHuman`; invalid dates omitted from structured outcome.
- [`lib/domain/value_objects/collection_call_persist.dart`](../lib/domain/value_objects/collection_call_persist.dart): `dateInvalid` on terminal write; `shouldUpsertPromise` requires valid calendar day + currency.
- [`lib/presentation/providers/closing_agent_controller.dart`](../lib/presentation/providers/closing_agent_controller.dart): `_surfacePersistTerminal` surfaces Drift `Left`; never invents amount.
- [`lib/data/datasources/local/collection_call_local_ds.dart`](../lib/data/datasources/local/collection_call_local_ds.dart): batch header finalized only when all runs have `rawStatus`; `watchPendingPromisesByContact`.
- Contact card: [`CollectionPromise`](../lib/domain/entities/collection_promise.dart), [`WatchPendingCollectionPromisesUseCase`](../lib/application/contact/watch_pending_collection_promises_use_case.dart), [`ContactPendingPromiseBanner`](../lib/presentation/screens/contact/widgets/contact_pending_promise_banner.dart) on [`contact_detail_screen.dart`](../lib/presentation/screens/contact/contact_detail_screen.dart) (Khazna info banner, int money + date, promise ≠ payment).
- ARB `contactPendingPromiseBody` EN+AR. Tests across domain, local DS, controller, widget.

### Architecture / decisions
Promise remains display-only — no `AddTransactionUseCase`. Currency still required for promise upsert (cannot format int money without it). Completed without collections `outcome` unchanged (§4.2 / live lesson). §4.4 / Gate 4 film out of scope.

### Ops / verification
`flutter test` on touched files — all passed. `flutter analyze` — clean. `build_runner` + `gen-l10n`. No Cloud Run deploy.

### Status
Roadmap §4.2 all items ticked. Next: §4.3 YE film row or §4.4 HUD poll observability.

## 2026-09-06 — Stage 4.3 review + §4.4 Observability

### Context
Owner requested professional review of §4.3 (email remainder independence) and implementation of §4.4 (Cloud Logging terminal events + HUD poll chip).

### Done
- **§4.3 (kept ticked):** [`test/presentation/providers/closing_agent_controller_test.dart`](../test/presentation/providers/closing_agent_controller_test.dart) — US+YE desk: `confirmAndCall` plan-batch US-only, then `approveAndSend` dispatches both including YE. [`test/presentation/screens/closing_agent/widgets/collections_desk_consent_test.dart`](../test/presentation/screens/closing_agent/widgets/collections_desk_consent_test.dart) — Confirm & Send visible after `callConsented`. [`closing_agent_controller.dart`](../lib/presentation/providers/closing_agent_controller.dart) — `_invalidateCallPoll()` at start of `approveAndSend`.
- **§4.4 Cloud Run:** [`agent/calls/handles.py`](../agent/calls/handles.py) — `RunContext` map (`put_run_context` / `get_run_context`). [`agent/calls/router.py`](../agent/calls/router.py) — `action=terminal` only on terminal GET (no per-poll `action=get` spam); `correlationId` + `batchId` from run context; PII-safe fields only.
- **§4.4 HUD:** [`architecture_hud_provider.dart`](../lib/presentation/providers/architecture_hud_provider.dart) — `resolveCallChip` last row **with non-empty `runId`** wins for both `runId` and `status` (later `planned` rows no longer mask ringing/completed).
- Docs: [`docs/roadmap_v3.md`](../docs/roadmap_v3.md) §4.4 ticked; [`agent/README.md`](../agent/README.md) Logs Explorer query for `daftar.agent.call` on `daftar-call-e`; [`docs/architecture/contest_architecture.md`](../docs/architecture/contest_architecture.md) Cloud Logging row.

### Architecture / decisions
Plan/run `daftar.agent.call` emitters unchanged. Non-terminal GET polls emit **no** call log. Gate 4 film / Stage 6.3 YE inbox beat remain unchecked. No Cloud Run deploy. No Firebase Analytics.

### Ops / verification
`agent/.venv/bin/python -m pytest tests/test_calls_get.py` — 14 passed. `flutter test` on controller, HUD provider, consent widget — passed. `flutter analyze` on touched Dart files — clean.

### Status
§4.3 ticked (unchanged). §4.4 complete. Next: §4.5 Gate 4 film (owner) or Stage 4 validation gate.

## 2026-09-08 — Move Gate 4 film; dial-off phone QA

### Context
Owner moved live ring filming to Stage 6 (after Stage 5). Stage 4 should exit on thorough device QA with `CALLE_ALLOW_DIAL=false` and min instances 0. Credit burn must be avoided during QA.

### Done
- [`docs/roadmap_v3.md`](../docs/roadmap_v3.md): removed **4.5 Gate 4 film** from Stage 4; added **4.5 Device QA (owner)**; merged film bullets into **§6.3 Video**; retargeted Stage 4/5/6 gates and dependency graph (Stage 5 after dial-off QA, not live ring).
- [`docs/qa/stage4_phone_qa.md`](../docs/qa/stage4_phone_qa.md): dial-off phone pass (Passes A–D) before Stage 5.
- [`docs/qa/calle_live_dial_window.md`](../docs/qa/calle_live_dial_window.md): credit-safe arm/disarm SOP for Stage 6 film only.
- [`docs/qa/gate4_device_runbook.md`](../docs/qa/gate4_device_runbook.md): heritage banner (frozen Agentic SMTP — do not warm).
- [`docs/qa/README.md`](../docs/qa/README.md): binding contract → v3; QA doc index updated.

### Architecture / decisions
Default forever: Cloud Run + APK dial **off**, min **0**. Live `CALLE_ALLOW_DIAL=true` only per `calle_live_dial_window.md` on film day. Poll loop does not re-`create`; `callConsented` blocks double Confirm & Call per desk. §4.5 / Stage 4 Validation Gate remain **unchecked** until owner runs `stage4_phone_qa.md`. §6.3 / Stage 6 film items **unchecked**.

### Ops / verification
`gcloud run services describe daftar-call-e`: revision `daftar-call-e-00008-nbv`, `CALLE_ALLOW_DIAL=false`, minScale unset (0), maxScale 2 — **no update required**. Frozen `daftar-closing-agent-00055-pbm` untouched. No deploy. No `DAFTAR_CALL_E_ALLOW_DIAL=true`.

### Status
Roadmap reorganized. Next: owner runs [`docs/qa/stage4_phone_qa.md`](../docs/qa/stage4_phone_qa.md) on phone, then Stage 5. Film after feature freeze per §6.3.

## 2026-09-08 — Credit-limit call session + drop promise banner

### Context
Merchants saw a confusing “A promise is not a payment” banner after credit-limit saves, and **Prepare the call** dumped them onto the full Collections Desk with a second Confirm & Call tap. This slice removes the slogan everywhere and adds a dedicated Khazna call-session surface with one HITL, live progress, terminal summary, and leave/return chips.

### Done
- Removed `DaftarPermissionBanner` promise slogan from `lib/presentation/screens/contact/widgets/credit_limit_call_sheet.dart` and `lib/presentation/screens/closing_agent/widgets/collections_desk_consent_card.dart`; contact card promise banner keeps display copy with new `contactPendingPromiseSemantics` ARB key in `lib/presentation/screens/contact/widgets/contact_pending_promise_banner.dart`
- B-trigger: `CreditLimitBTrigger` → `startCreditLimitCallSession()` (`openCreditLimitDesk` + `confirmAndCall`) in `lib/presentation/screens/contact/credit_limit_b_trigger.dart`; `dismissCreditLimitSession()` and `finishDesk` no-op for `creditLimit` in `lib/presentation/providers/closing_agent_controller.dart`
- New `lib/presentation/screens/closing_agent/widgets/credit_limit_call_session.dart` (progress + summary + Done); routed from `lib/presentation/screens/closing_agent/closing_agent_screen.dart` when `callBatchTrigger == creditLimit`; composer hidden; working glow while live
- Resume chips: `lib/presentation/screens/closing_agent/widgets/credit_limit_call_resume_chip.dart` on `lib/presentation/shared/widgets/main_shell.dart` (home) and `lib/presentation/screens/contact/contact_detail_screen.dart`
- State helpers on `ClosingAgentState`: `isCreditLimitCallSessionActive`, `creditLimitCallSessionTerminal`, `creditLimitSessionContactId`; `CollectionsCallProgress.isTerminal` / `lastRowWithRunId`; thicker session progress bar variant
- EN+AR l10n keys; widget/controller tests; updated consent + sheet tests

### Architecture / decisions
- **One HITL** on the credit-limit sheet; close-the-day desk still uses Confirm & Call on `CollectionsDeskPanel`
- Session persists on pop/back until merchant taps **Done**; kill-switch / empty allowlist still surfaces honest `failed` progress (no fake ring)
- Lapis law preserved: glow edges and progress stripe only — no blue fills

### Ops / verification
- `flutter gen-l10n`
- `flutter test` credit-limit widget + controller tests (sheet, consent, session, controller `credit-limit` filter) — pass
- No Cloud Run / dial policy change

### Status
UX slice complete. Stage 5 / §6.3 / live dial unchanged. Owner can QA credit-limit flow on device with existing dial-off policy.

## 2026-09-08 — Fix Prepare the call no-op

### Context
Tapping **Prepare the call** dismissed the HITL sheet and then did nothing. Add-debt callers pop their dialog/sheet first, so `offerAfterDebtSave` saw `context.mounted == false` and skipped `startCreditLimitCallSession` / navigation.

### Done
- [`lib/presentation/screens/contact/credit_limit_b_trigger.dart`](lib/presentation/screens/contact/credit_limit_b_trigger.dart): after Prepare, start the session without requiring the caller widget; show the sheet and push Closing Agent via `rootNavigatorKey` / captured `GoRouter`
- [`lib/presentation/screens/contact/widgets/credit_limit_call_sheet.dart`](lib/presentation/screens/contact/widgets/credit_limit_call_sheet.dart) + [`app_bottom_sheet.dart`](lib/presentation/shared/widgets/app_bottom_sheet.dart): `useRootNavigator: true`
- Callers pass a surviving overlay context before pop: [`add_transaction_dialog.dart`](lib/presentation/screens/transaction/widgets/add_transaction_dialog.dart), [`quick_add_bottom_sheet.dart`](lib/presentation/widgets/transactions/quick_add_bottom_sheet.dart)
- Widget test [`test/presentation/screens/contact/credit_limit_b_trigger_test.dart`](test/presentation/screens/contact/credit_limit_b_trigger_test.dart): pop host → Prepare → session + `/closing-agent`

### Architecture / decisions
Kill switch / empty allowlist still refuse `run-batch` honestly. No Cloud Run or dial-on change.

### Ops / verification
- `dart analyze` on touched files — clean
- `flutter test` trigger + sheet tests — pass
- Phone: **hot restart** the existing `flutter run` session (hot reload is not enough)

### Status
Ready for device QA. Stage 5 / §6.3 / live dial unchanged.

## 2026-09-08 — Fix Prepare the call disposed WidgetRef crash

### Context
Phone Crashlytics: `Using "ref" when a widget is about to or has been unmounted` at `CreditLimitBTrigger.offerAfterDebtSave` line 69. The add-debt dialog’s `WidgetRef` was still used after Prepare; the merchant never reached the call session.

### Done
- [`lib/presentation/screens/contact/credit_limit_b_trigger.dart`](lib/presentation/screens/contact/credit_limit_b_trigger.dart): capture `ProviderScope.containerOf` from the root overlay at entry; all reads (`skip`, contact, balances, `startCreditLimitCallSession`) go through that container — never `ref.read` after an await
- [`test/presentation/screens/contact/credit_limit_b_trigger_test.dart`](test/presentation/screens/contact/credit_limit_b_trigger_test.dart): Prepare uses a **dialog `Consumer` `WidgetRef`** that is popped before the tap

### Architecture / decisions
App `ProviderContainer` outlives the add-debt route. Kill switch / empty allowlist still honest. No Cloud Run / dial-on.

### Ops / verification
- `dart analyze` on trigger + test — clean
- `flutter test test/presentation/screens/contact/credit_limit_b_trigger_test.dart` — pass
- Phone: **hot restart** (`R`) the running `flutter run` session

### Status
Ready for device QA. Stage 5 / §6.3 / live dial unchanged.

## 2026-09-08 — Credit-limit sheet: debt glow + keyboard overflow

### Context
After Prepare-the-call navigation worked, the exceeded-limit HITL sheet flashed a one-frame Column overflow when the keyboard was still animating closed after a debt save. The merchant also asked for a professional debt-red horizon glow (same light-not-paint grammar as the Closing Agent crest).

### Done
- [`lib/presentation/shared/widgets/app_bottom_sheet.dart`](lib/presentation/shared/widgets/app_bottom_sheet.dart): stop double-counting `viewInsets` in `maxHeight`; wrap scroll body in `Flexible`; optional `horizonGlow` + `accentBorderColor`
- [`lib/presentation/screens/contact/widgets/credit_limit_call_sheet.dart`](lib/presentation/screens/contact/widgets/credit_limit_call_sheet.dart): `waitForKeyboardToSettle` (unfocus + frame wait) before present; debt accent border + light haptic on enter
- [`lib/presentation/screens/contact/widgets/credit_limit_horizon_glow.dart`](lib/presentation/screens/contact/widgets/credit_limit_horizon_glow.dart): debt-red BoxShadow crest + 0.5px hairline; breath animation; respects reduce-motion
- [`lib/presentation/screens/contact/credit_limit_b_trigger.dart`](lib/presentation/screens/contact/credit_limit_b_trigger.dart): shared keyboard settle before sheet in both entry paths
- [`test/presentation/screens/contact/widgets/credit_limit_call_sheet_test.dart`](test/presentation/screens/contact/widgets/credit_limit_call_sheet_test.dart): viewInsets animate pump must not overflow; horizon glow present

### Architecture / decisions
Lapis Law preserved — primary CTA stays monochrome + lapis glow. Debt chroma is semantic emission only (shadow + hairline). Shared sheet infrastructure fix benefits all `AppBottomSheet` callers without changing close-the-day desk.

### Ops / verification
- `dart analyze` on touched files — clean (info-level only)
- `flutter test test/presentation/screens/contact/widgets/credit_limit_call_sheet_test.dart` — 3/3 pass
- Phone: **hot restart** (`R`) after landing

### Status
Ready for device QA on exceeded-limit save → sheet glow + no overflow flash. Dial-off / failed call unchanged (service disabled).

## 2026-09-08 — Credit-limit glow: inward wash

### Context
The first debt-red crest radiated past the sheet (negative offsets + large BoxShadow). The merchant asked for a softer, in-card glow that starts at the top edge and falls downward.

### Done
- [`lib/presentation/shared/widgets/app_bottom_sheet.dart`](lib/presentation/shared/widgets/app_bottom_sheet.dart): paint `horizonGlow` **inside** the clipped Material (behind content), `ClipRect` so blur cannot leave the card
- [`lib/presentation/screens/contact/widgets/credit_limit_horizon_glow.dart`](lib/presentation/screens/contact/widgets/credit_limit_horizon_glow.dart): inward wash — ellipses centered on the top edge so the upper half is clipped away; named alphas only; quieter breath
- [`lib/presentation/screens/contact/widgets/credit_limit_call_sheet.dart`](lib/presentation/screens/contact/widgets/credit_limit_call_sheet.dart): top accent hairline `alphaSoft` (was `alphaMedium`)

### Architecture / decisions
Still light-not-paint: no debt fill on the CTA. Glow is clipped to the sheet radius.

### Ops / verification
- `dart analyze` on touched files
- `flutter test test/presentation/screens/contact/widgets/credit_limit_call_sheet_test.dart`
- Phone: **hot restart** (`R`)

### Status
Visual polish on the HITL sheet. Dial-off unchanged.

## 2026-09-08 — B-trigger: Prepare the call only for supported numbers

### Context
Credit-limit exceeded saves showed **Prepare the call** for every contact (including Yemen and missing phones), then failed on dispatch. Merchant asked for the HITL only when the number is CALL-E region-supported; unsupported contacts keep the exceeded notification only.

### Done
- [`lib/domain/constants/j10_region_gate.dart`](lib/domain/constants/j10_region_gate.dart): `isSupportedCallingNumber` (allowlist ignored) + `isSupportedContactPhone` (DNC-aware)
- [`lib/presentation/screens/contact/credit_limit_b_trigger.dart`](lib/presentation/screens/contact/credit_limit_b_trigger.dart): gate `offerAfterDebtSave` / `presentPendingPrompt`; returns `bool` (sheet presented); `isCallPromptEligible` for callers
- [`lib/presentation/providers/closing_agent_controller.dart`](lib/presentation/providers/closing_agent_controller.dart): `_queueCreditLimitPromptIfNeeded` skips unsupported contacts
- [`lib/presentation/screens/transaction/widgets/add_transaction_dialog.dart`](lib/presentation/screens/transaction/widgets/add_transaction_dialog.dart) + [`quick_add_bottom_sheet.dart`](lib/presentation/widgets/transactions/quick_add_bottom_sheet.dart): in-app `creditLimitExceeded` snackbar when sheet skipped (unsupported phone only)
- Tests: [`test/domain/constants/j10_region_gate_test.dart`](test/domain/constants/j10_region_gate_test.dart), [`test/presentation/screens/contact/credit_limit_b_trigger_test.dart`](test/presentation/screens/contact/credit_limit_b_trigger_test.dart) (US shows sheet; YE / empty do not)

### Architecture / decisions
Region-only gate per owner choice — `CallNotAllowlisted` still sees Prepare; PSTN allowlist + kill switch unchanged on `run-batch`. OS `notificationExceededBody` still fires for all exceeded saves. No Cloud Run / dial-on change.

### Ops / verification
- `dart analyze` on touched files — clean (info-level ordering only)
- `flutter test` j10_region_gate + credit_limit_b_trigger — 18/18 pass
- Phone: **hot restart** (`R`); test YE contact → exceeded snackbar only; US DID → Prepare sheet

### Status
B-trigger HITL aligned with J.10 supported regions. Stage 5 / live dial unchanged.

## 2026-09-08 — Collections Desk: compact consent dock

### Context
Close-the-day paused with four stacked full-width consent buttons (~320dp) above draft previews, making C.3 / C.2 review difficult. Roadmap still requires four explicit HITL actions — layout only.

### Done
- [`lib/presentation/screens/closing_agent/widgets/collections_desk_consent_card.dart`](lib/presentation/screens/closing_agent/widgets/collections_desk_consent_card.dart): compact dock — two-up Call/Send primaries + one skip row; progress bar when in flight; collapses call rail after consent
- [`lib/presentation/screens/closing_agent/widgets/collections_desk_panel.dart`](lib/presentation/screens/closing_agent/widgets/collections_desk_panel.dart): drafts `Expanded` first; consent dock pinned below list; rail counts merged into header meta (`1 call · 2 emails`)
- [`lib/core/l10n/app_en.arb`](lib/core/l10n/app_en.arb) / [`app_ar.arb`](lib/core/l10n/app_ar.arb): `collectionsDeskWithoutCalling` / `collectionsDeskWithoutSending` (short skip copy)
- [`test/presentation/screens/closing_agent/widgets/collections_desk_consent_test.dart`](test/presentation/screens/closing_agent/widgets/collections_desk_consent_test.dart): four actions still present; RTL + YE-only + post-call collapse

### Architecture / decisions
Same four callbacks and single lapis glow moment. Dedicated desk preserved — not compact taskmaster. Khazna: monochrome dock + hairline top border; no lapis fill.

### Ops / verification
- `flutter gen-l10n`
- `flutter test test/presentation/screens/closing_agent/widgets/collections_desk_consent_test.dart` — 8/8 pass
- Phone: **hot restart** (`R`); Close the day → previews first, slim dock at bottom

### Status
Review-first Collections Desk UX. Dispatch semantics unchanged.

## 2026-09-08 — Collections Desk: rail chips + dynamic CTA

### Context
Four-button consent dock still crowded decision-making. Merchant requested two toggle chips (voice / email) and one dynamic primary whose label declares the exact outreach commit before dispatch.

### Done
- [`lib/presentation/screens/closing_agent/widgets/collections_desk_rail_chip.dart`](lib/presentation/screens/closing_agent/widgets/collections_desk_rail_chip.dart): Khazna filter-chip rail toggle (check scale, lapis hairline, `glowXs`, 48dp tap)
- [`lib/presentation/screens/closing_agent/widgets/collections_desk_consent_card.dart`](lib/presentation/screens/closing_agent/widgets/collections_desk_consent_card.dart): StatefulWidget — two chips + `AnimatedSwitcher` CTA; four commit modes (both / call / email / seal)
- [`lib/presentation/providers/closing_agent_controller.dart`](lib/presentation/providers/closing_agent_controller.dart): `commitDeskOutreach`; `pendingSendAfterCall` queues `approveAndSend` after call poll terminal
- [`lib/presentation/providers/closing_agent_state.dart`](lib/presentation/providers/closing_agent_state.dart): `pendingSendAfterCall` flag
- [`lib/presentation/screens/closing_agent/widgets/collections_desk_panel.dart`](lib/presentation/screens/closing_agent/widgets/collections_desk_panel.dart) / [`closing_agent_screen.dart`](lib/presentation/screens/closing_agent/closing_agent_screen.dart): `onCommitOutreach` wiring; header rail counts removed (chips carry counts)
- [`lib/core/l10n/app_en.arb`](lib/core/l10n/app_en.arb) / [`app_ar.arb`](lib/core/l10n/app_ar.arb): chip labels + four CTA strings with int placeholders
- Tests: [`collections_desk_consent_test.dart`](test/presentation/screens/closing_agent/widgets/collections_desk_consent_test.dart), [`collections_desk_panel_test.dart`](test/presentation/screens/closing_agent/widgets/collections_desk_panel_test.dart), controller `commitDeskOutreach both queues approveAndSend`

### Architecture / decisions
HITL preserved: chips are the four-way decision; CTA **names** counts before dial/SMTP. Dual-rail one-tap sets `pendingSendAfterCall` — SMTP only after terminal call rows (declared in label). Call-only commit does not auto-send. Hybrid E leftover chrome unchanged.

### Ops / verification
- `flutter gen-l10n`; `dart run build_runner build --delete-conflicting-outputs`
- `flutter test` consent + panel widgets — 18/18 pass
- Controller `commitDeskOutreach both queues approveAndSend after call terminal`
- Phone: **hot restart** (`R`); Close the day → chips + one button, drafts readable

### Status
Collections Desk consent UX v2 shipped. Stage 5 / live dial unchanged.

## 2026-09-08 — Stage 5.1: HITL no-answer / voicemail retry

### Context
Roadmap §5.1: one merchant-tapped retry for CALL-E rows whose structured outcome is `no_answer` or `voicemail`. Policy locked to **HITL only** (not auto-dial) to preserve Confirm → Create and contest credit budget.

### Done
- **Agent J.9:** [`agent/calls/schemas.py`](agent/calls/schemas.py) optional `attempt: 0|1`; [`agent/calls/router.py`](agent/calls/router.py) idempotency `{batchId}:{contactId}:retry1` on attempt 1; [`agent/calls/handles.py`](agent/calls/handles.py) retry run_id slot; OpenAPI **2.8.0**; pytest in [`agent/tests/test_calls_run_batch.py`](agent/tests/test_calls_run_batch.py)
- **Schema 27:** [`collection_call_runs_table.dart`](lib/data/datasources/local/tables/collection_call_runs_table.dart) `retryCount`; migration in [`drift_database.dart`](lib/data/datasources/local/drift_database.dart); [`DbConstants`](lib/core/constants/db_constants.dart) / [`DriveBackupConstants`](lib/domain/constants/drive_backup_constants.dart) bumped together
- **Device:** [`collections_call_progress.dart`](lib/domain/value_objects/collections_call_progress.dart) `outcome` + `retryCount`; [`closing_agent_controller.dart`](lib/presentation/providers/closing_agent_controller.dart) `retryUnansweredCalls`, SMTP hold via `callRetryOfferCount`, poll fix (`break` + timeout only when pending); desk + credit-limit retry CTA; EN/AR `collectionsDeskRetryUnanswered`
- Tests: controller retry (`attempt: 1`, promised no-offer, second retry no-op), consent widget, schema v27

### Architecture / decisions
HITL retry only — merchant taps “Retry unanswered — {n}”. Re-plan same `batchId` then `run-batch` with `attempt: 1`. One retry per contact (`retryCount`); no `scheduled_at`; cap 5 unchanged. Dual-rail `pendingSendAfterCall` held until retry consumed or merchant sends/seals/done.

### Ops / verification
- `agent/.venv/bin/python -m pytest tests/test_calls_run_batch.py tests/test_calls_openapi_j9.py`
- `dart run build_runner build --delete-conflicting-outputs`; `flutter gen-l10n`
- `flutter analyze`; targeted `flutter test` on controller + consent + schema
- **No Cloud Run deploy**; **no** `CALLE_ALLOW_DIAL=true`

### Status
§5.1 checklist ticked. Stage 5.2+ (kill switch UI, skill PR) unchanged.

## 2026-09-08 — Stage 5.1 review patches

### Context
Review found three controller gaps: `invalidHandle` recovery dropped `attempt: 1`, retry HTTP failure left rows `planned` (chips locked, SMTP held, offer spent), and no in-flight lock before hydrate.

### Done
- [`closing_agent_controller.dart`](lib/presentation/providers/closing_agent_controller.dart): pass `attempt` through `_planThenRun` invalidHandle re-plan; restore prior progress on retry create failure; `_retryUnansweredInFlight` before first await
- [`app_ar.arb`](lib/core/l10n/app_ar.arb): `إعادة الاتصال بمن لم يرد — {count}`
- Test: `no_answer holds pending SMTP until HITL retry completes`

### Status
§5.1 behavior unchanged; retry path no longer silently no-ops or sticks the desk.

## 2026-09-08 — Stage 5.2 Kill switch UI

### Context
Stage 5.2 adds the merchant-facing **Allow CALL-E outbound** GlowPill in Settings, persisted in Drift. Effective device dial requires GlowPill AND compile-time `CALLE_ALLOW_DIAL=true`; Cloud Run remains authoritative (403). No deploy or live dial in this slice.

### Done
- Schema **28**: `AppSettings.calleAllowDial` default `false` — [`app_settings_table.dart`](lib/data/datasources/local/tables/app_settings_table.dart), [`drift_database.dart`](lib/data/datasources/local/drift_database.dart), [`db_constants.dart`](lib/core/constants/db_constants.dart), [`drive_backup_constants.dart`](lib/domain/constants/drive_backup_constants.dart)
- Threaded through entity/model/mapper/repo — [`app_settings.dart`](lib/domain/entities/app_settings.dart), [`settings_model.dart`](lib/data/models/settings_model.dart), [`settings_mapper.dart`](lib/data/mappers/settings_mapper.dart), [`settings_repository_impl.dart`](lib/data/repositories/settings_repository_impl.dart)
- [`set_calle_allow_dial_use_case.dart`](lib/application/settings/set_calle_allow_dial_use_case.dart); [`calleDevicePolicyProvider`](lib/presentation/providers/core_providers.dart) AND overlay via [`CalleDevicePolicy.effectiveAllowDial`](lib/domain/constants/calle_device_policy.dart)
- Settings GlowPill enabled — [`settings_screen.dart`](lib/presentation/screens/settings/settings_screen.dart); EN/AR ARB; debug [`demo_store_seeder.dart`](lib/core/utils/demo_store_seeder.dart) arms pill when `kDebugMode`
- Tests: use case, policy AND matrix, schema 28, seeder `calleAllowDial == kDebugMode`
- Roadmap §5.2 ticked; QA copy updated — [`stage4_phone_qa.md`](docs/qa/stage4_phone_qa.md), [`flutter_env.template.md`](docs/qa/flutter_env.template.md)

### Architecture / decisions
- GlowPill **value** = persisted merchant intent (`calleAllowDial`), not effective AND
- Fail closed when settings not loaded (`persisted ?? false`)
- Device can only be stricter than server; no Cloud Run changes

### Ops / verification
- `flutter analyze` + targeted tests (settings/policy/schema/controller)
- No deploy; no `CALLE_ALLOW_DIAL=true` on Cloud Run

### Status
Roadmap §5.2 complete. Next bands per [`roadmap_v3.md`](docs/roadmap_v3.md).

## 2026-09-08 — Stage 5.3 Promise card polish

### Context
Roadmap §5.3: merchants mark pending CALL-E promises kept / broken / cancelled without ledger writes. Optional: Kept opens payment entry prefilled — Save still HITL.

### Done
- [`update_collection_promise_status_use_case.dart`](lib/application/contact/update_collection_promise_status_use_case.dart); repo/DS `updatePromiseStatus`; `persistTerminalWrite` preserves resolved status
- Contact [`ContactPendingPromiseBanner`](lib/presentation/screens/contact/widgets/contact_pending_promise_banner.dart) → DaftarCard + action/confirm sheets; EN/AR ARB
- [`showAddTransactionDialog`](lib/presentation/screens/transaction/widgets/add_transaction_dialog.dart): `initialType` + `initialAmountMinor` prefill after Kept
- Tests: use case, enum extension, local DS status flip + kept preservation, widget card
- Roadmap §5.3 ticked; film QA [`calle_live_dial_window.md`](docs/qa/calle_live_dial_window.md) step 4

### Architecture / decisions
- Promise status change never calls `AddTransactionUseCase`
- Merchant HITL wins over late terminal GET re-upsert
- No schema bump (status enum already in v26)

### Ops / verification
- `flutter analyze` + targeted tests
- No deploy; no `CALLE_ALLOW_DIAL=true`

### Status
Roadmap §5.3 complete. Next: §5.4 portable skill per [`roadmap_v3.md`](docs/roadmap_v3.md).

## 2026-09-08 — Stage 5.4 merge-contract rewrite (not implemented)

### Context
§5.4 was a thin checkbox. After studying [awesome-phone-call-agents](https://github.com/CALLE-AI/awesome-phone-call-agents) (`kept`, `appointment-confirm`, `service-dispatch-call`, CONTRIBUTING, `validate_repository.py`), the skill is useful only as a **HITL outbound call + display-only integer promise**, not a `kept` clone or a Flutter dump.

### Done
- [`docs/roadmap_v3.md`](docs/roadmap_v3.md) **v3.4**: §5.4 merge contract (scope vs `kept`, validator folder tree, SKILL.md/preview.py, locked README one-liner, PR mechanics, reject list)
- §6.4 now points at the **same** PR (Devpost URL + review replies; no second skill PR)
- **Did not** author `docs/skills/ledger-collections-call/` or open the awesome-list PR

### Architecture / decisions
- Skill never cashiers; never writes a ledger; region refuse including YE before `POST /v1/calls`
- Dual rail / Drift / Cloud Run stay product-only
- English-only PR copy; `locale: ar` documented in English

### Status
§5.4 checkboxes remain `[ ]` until the skill + PR land. Next: implement the skill per the new §5.4 contract.

## 2026-09-08 — Stage 5.4 skill source copy (usefulness lock)

### Context
Author `ledger-collections-call` in this repo only: HITL outbound collections **call** + display-only integer promise. Do not clone `kept`. No awesome-list PR in this slice.

### Done
- Source of truth: [`docs/skills/ledger-collections-call/`](docs/skills/ledger-collections-call/) — `SKILL.md`, `references/{overlap,safety,examples,result-schema,regions}.md`, `scripts/preview.py`, `scripts/test_preview.py`, `assets/sample-overdue.json`
- No skill-folder `README.md`
- `preview.py`: stdlib dry-run; YE / float / DNC refuse; E.164 last-4 mask; `--live` rejected; never POSTs
- Tests: `python3 docs/skills/ledger-collections-call/scripts/test_preview.py` — 5 passed
- Roadmap §5.4 **source-copy** and **preview.py** boxes ticked; **awesome-list PR** boxes remain `[ ]`

### Architecture / decisions
- Complements `kept` (campaign + capture + bank ledger) rather than replacing it
- J.10 supported-region frozenset copied into the skill; YE never eligible
- Promise is not a payment; no `AddTransaction`; no Cloud Run / Flutter in the skill

### Ops / verification
- `python3 docs/skills/ledger-collections-call/scripts/test_preview.py`
- No deploy; no `CALLE_ALLOW_DIAL=true`; no GitHub PR to awesome-phone-call-agents

### Status
Source copy ready for review. Next: copy into an awesome-list clone and open `feat/ledger-collections-call` per §5.4 PR mechanics.

## 2026-09-08 — Stage 5.4 awesome-list clone prep (no PR)

### Context
Owner forked/cloned [awesome-phone-call-agents](https://github.com/CALLE-AI/awesome-phone-call-agents) to `/Users/aq/Work/01_Projects/awesome-phone-call-agents`, branch `feat/ledger-collections-call`, `check_branch_name.py` green. This slice copies the skill and README bullet only — no push, no GitHub PR.

### Done
- Hygiene in source so the clone is merge-ready: [`references/regions.md`](docs/skills/ledger-collections-call/references/regions.md) host-agnostic dual-rail wording; [`references/examples.md`](docs/skills/ledger-collections-call/references/examples.md) both dry-run paths; [`scripts/preview.py`](docs/skills/ledger-collections-call/scripts/preview.py) lockstep comment without a Daftar import path
- Byte-identical copy into clone `skills/ledger-collections-call/` (no skill `README.md`)
- Locked Skills one-liner appended to the clone `README.md` after `concord-policy-audit` (`](path/) - ` punctuation; sentence unchanged)
- Clone verification: dry-run `status: not_called`; `test_preview.py` 5 passed; `python3 scripts/validate_repository.py` → `Repository validation passed.`
- Roadmap §5.4 clone-prep boxes ticked; **PR title / PR template remain `[ ]`**

### Architecture / decisions
- Complements `kept`; promise is display-only; `preview.py` still never POSTs
- Origin on the clone is `akrmcodes/awesome-phone-call-agents` (fork), not `daftar-closing-agent`

### Ops / verification
- `python3 docs/skills/ledger-collections-call/scripts/test_preview.py` (source)
- Clone: preview.py dry-run; `python3 skills/ledger-collections-call/scripts/test_preview.py`; `python3 scripts/validate_repository.py`
- No deploy; no `CALLE_ALLOW_DIAL=true`; no `git push`; no `gh pr create`; no commit in either repo

### Status
Clone is ready for owner review, then a local commit + PR. Next: push `feat/ledger-collections-call` and open the awesome-list PR per remaining §5.4 boxes.

## 2026-09-08 — Stage 5.4 clone push (PR open needs GitHub login)

### Context
Final review of the portable skill, recopy into the awesome-list clone, commit/push the fork, open the CALLE-AI PR. `gh` is not logged in on this machine, so the compare page was opened for the owner.

### Done
- Source hygiene: layout-based dry-run paths (no `daftar-call-e` label); drop J.9/J.10 and Daftar §5.3 from skill copy; DNC unittest
- Tests: `python3 docs/skills/ledger-collections-call/scripts/test_preview.py` — 6 passed
- Clone recopy byte-identical; `validate_repository.py` green
- Clone commit `5f77698` `feat(ledger-collections-call): add HITL integer-promise collections skill`
- Pushed `feat/ledger-collections-call` to `akrmcodes/awesome-phone-call-agents` (fork). Not `daftar-closing-agent`

### Architecture / decisions
- Skill still complements `kept`; dry-run only; no ledger write
- `skill-pack` has no upstream tracking — daftar-call-e commit is local only

### Ops / verification
- Clone: dry-run, 6 tests, `python3 scripts/validate_repository.py`
- No deploy; no `CALLE_ALLOW_DIAL=true`; daftar-call-e **not** pushed

### Status
§5.4 PR title / template stay `[ ]` until the upstream PR exists. Owner: submit from the GitHub compare page (browser opened) after `gh auth login` or using the prefilled title.

## 2026-09-08 — Stage 5.4 awesome-list PR opened (#385)

### Context
Owner opened and verified [CALLE-AI/awesome-phone-call-agents#385](https://github.com/CALLE-AI/awesome-phone-call-agents/pull/385) (`feat(ledger-collections-call): add HITL integer-promise collections skill`). Tick the remaining §5.4 PR boxes.

### Done
- Roadmap §5.4 PR title and template/complementarity-with-`kept` boxes marked `[x]`; PR URL recorded on the title line
- §5.5 freeze, Gate 5 freeze, §6.4 Devpost URL, and Stage 6 “PR opened” left `[ ]` (Devpost paste and freeze are later bands)

### Architecture / decisions
Unchanged: skill complements `kept`; display-only integer promise; dry-run default; no ledger write.

### Ops / verification
- Owner-verified PR: https://github.com/CALLE-AI/awesome-phone-call-agents/pull/385
- No deploy; no `CALLE_ALLOW_DIAL=true`; `skill-pack` still not pushed

### Status
§5.4 merge-contract work is complete pending maintainer review. Next: paste this PR URL on Devpost (§6.4), answer review comments, then Stage 5.5 freeze / Stage 6 packaging.

