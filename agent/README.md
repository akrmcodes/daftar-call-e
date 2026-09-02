# Daftar Closing Agent (`agent/`)

Frozen **device ↔ Cloud Run** wire contract + ADK runtime for the All Things Agentic submission.

| Artifact | Role |
| --- | --- |
| [`openapi.yaml`](openapi.yaml) | **Normative** OpenAPI 3.1 — Appendix J + Stage 1.2 tool payloads + J.7 send-batch + `/v1/tts` |
| [`main.py`](main.py) / [`Dockerfile`](Dockerfile) | Custom FastAPI: ADK `/run` (`get_fast_api_app`, `web=False`) + send-batch + `POST /v1/tts` |
| [`email_send/`](email_send/) | J.7 multipart handler, C.2 body, stdlib SMTP, process-local idempotency |
| [`tts/`](tts/) | Chirp 3 HD Enceladus unary MP3 (`ar-XA` / `en-US`). ADC. Not Gemini Live. |
| [`closing_agent/`](closing_agent/) | ADK Python app (`root_agent`, model `gemini-3.5-flash`) |
| [`docs/architecture/contest_architecture.md`](../docs/architecture/contest_architecture.md) | Contest diagram · HITL · frozen catalog · why no SequentialAgent |
| [`docs/roadmap_v2.md`](../docs/roadmap_v2.md) Appendix J | Human-readable twin (must stay in sync) |

## Single-agent lock (contest)

This submission ships **one** ADK `LlmAgent` named `closing_agent` with eight frozen FunctionTools on `ALL_TOOLS`. There is **no** `SequentialAgent`, `AgentTool`, or `sub_agents` graph — mid-day capture is one intent-dependent hop; close ritual is device-deterministic after plan confirm.

- Enforced: [`tests/test_tool_catalog_freeze.py`](tests/test_tool_catalog_freeze.py), [`tests/test_single_agent_lock.py`](tests/test_single_agent_lock.py)
- Coordinator + scoped sub-agents (B-Prime) are **out of scope** for this contest window; see contest architecture doc for rationale.

## Deployed service (Stage 1.1)

**CALL-E freeze:** this table is the **frozen** All Things Agentic production service. Do not redeploy. Snapshot: [`docs/contest/AGENTIC_CLOUD_RUN_FREEZE.md`](../docs/contest/AGENTIC_CLOUD_RUN_FREEZE.md). Legal CALL-E service is **`daftar-call-e`** via [`scripts/deploy_daftar_call_e.sh`](scripts/deploy_daftar_call_e.sh). Binding: [`docs/roadmap_v3.md`](../docs/roadmap_v3.md).

| Field | Value |
| --- | --- |
| Project | `daftar-closing-agent` |
| Region | `us-central1` |
| Service | `daftar-closing-agent` |
| URL | `https://daftar-closing-agent-1487285471.us-central1.run.app` |
| App name | `closing_agent` |
| Runtime SA | `agent-runner@daftar-closing-agent.iam.gserviceaccount.com` |
| Auth | Authenticated invokers only (`roles/run.invoker`) |
| Scaling (cost lock) | **Min 0 / Max 2** — never the Cloud Run default max of 100 |
| Env | `GOOGLE_GENAI_USE_VERTEXAI=TRUE`, `GOOGLE_CLOUD_LOCATION=global`, `GOOGLE_CLOUD_PROJECT=daftar-closing-agent` |
| Model | `gemini-3.5-flash` (pinned in `closing_agent/agent.py`) |

### Cost locks (mandatory on every deploy)

Cloud Run revisions default to **100** max instances. This service must stay at **min=0, max=2** on **both** layers ([service-level `--min`/`--max`](https://docs.cloud.google.com/run/docs/configuring/max-instances) and [revision-level `--min-instances`/`--max-instances`](https://docs.cloud.google.com/sdk/gcloud/reference/run/deploy)):

| Layer | Flags | Live annotations |
| --- | --- | --- |
| Service (caps the whole service immediately) | `--min=0 --max=2` | `run.googleapis.com/maxScale: '2'` (min 0 is the default; omitted when 0) |
| Revision (immutably set on each new revision) | `--min-instances=0 --max-instances=2` | `autoscaling.knative.dev/maxScale: '2'` |

Omitting `--max-instances=2` on a later deploy creates a revision with max **100**. Service-level `--max=2` still caps spend, but `gcloud run services describe` would then show a revision max of 100 — that is a **hard ban**. Always pass all four flags.

**Do not** run `adk deploy cloud_run` after Stage 4.7 — it generates a closed `main.py` and would wipe `POST /v1/email/send-batch` and `POST /v1/tts`.

Redeploy (custom FastAPI, same service). Gmail mailbox env comes from the **operator shell** or the **live revision** — never commit or print `GMAIL_SMTP_USER` / `GMAIL_SMTP_FROM`. Snapshot custom-audience **count** (must stay 3) before deploy; restore if wiped; never print client IDs.

**Do not pass empty mailbox env.** `gcloud run deploy --update-env-vars=...,GMAIL_SMTP_USER="$GMAIL_SMTP_USER"` with an unset shell variable **clears** the live keys. That is how revision **00050** (26 Aug 2026) broke send-batch (`from_user_mismatch`, SMTP never attempted) while Drive backup still worked. Source the helper first so empty shells copy USER/FROM from the live service, or omit those two keys from `--update-env-vars` entirely.

> **DO NOT RUN — frozen All Things Agentic.**
> The block below is **historical**. Do not `gcloud run deploy` / `gcloud run services update` service `daftar-closing-agent`. CALL-E deploys **`daftar-call-e` only** via [`scripts/deploy_daftar_call_e.sh`](scripts/deploy_daftar_call_e.sh). Binding: [`docs/roadmap_v3.md`](../docs/roadmap_v3.md). To copy mailbox env from the frozen revision (describe only): `source ./scripts/read_gmail_env_from_frozen.sh`.

```text
HISTORICAL — do not execute. Frozen All Things Agentic Cloud Run.

cd agent
source ./scripts/preserve_gmail_env.sh

# Audience count only — do not print the JSON array of client IDs
gcloud run services describe daftar-closing-agent \
  --project=daftar-closing-agent --region=us-central1 \
  --format='value(metadata.annotations.run.googleapis.com/custom-audiences)' \
  | python3 -c "import json,sys; a=sys.stdin.read().strip(); print(len(json.loads(a) if a else []))"

gcloud run deploy daftar-closing-agent \
  --source=. \
  --project=daftar-closing-agent \
  --region=us-central1 \
  --no-allow-unauthenticated \
  --min=0 --max=2 \
  --min-instances=0 --max-instances=2 \
  --port=8000 \
  --service-account=agent-runner@daftar-closing-agent.iam.gserviceaccount.com \
  --update-env-vars=GOOGLE_GENAI_USE_VERTEXAI=TRUE,GOOGLE_CLOUD_PROJECT=daftar-closing-agent,GOOGLE_CLOUD_LOCATION=global,GMAIL_SMTP_USER="$GMAIL_SMTP_USER",GMAIL_SMTP_FROM="$GMAIL_SMTP_FROM",GMAIL_SMTP_HOST=smtp.gmail.com,GMAIL_SMTP_PORT=587 \
  --update-secrets=/secrets/gmail-smtp-app-password=gmail-smtp-app-password:latest
```

`--update-env-vars` merges Vertex + Gmail From/user (same address) without wiping other env. App Password is the **file mount** `/secrets/gmail-smtp-app-password` — never an env var, never in logs or JSON, and **never in the Flutter app** (Secret Manager + Cloud Run only). Idempotency store is **process-local** (Cloud Run **min 0** drops it on scale-to-zero; durable SoT is Drift in §4.8).

Idempotent lock (**HISTORICAL — do not execute**):

```text
HISTORICAL — do not execute. Frozen All Things Agentic Cloud Run.

gcloud run services update daftar-closing-agent \
  --project=daftar-closing-agent \
  --region=us-central1 \
  --min=0 --max=2 \
  --min-instances=0 --max-instances=2
```

Verify (must print `Min: 0, Max: 2` and revision `Max instances: 2`). **Read-only** `describe` is allowed:

```bash
gcloud run services describe daftar-closing-agent \
  --project=daftar-closing-agent \
  --region=us-central1
# Scaling: Auto (Min: 0, Max: 2)
# Max instances: 2
```

## Transport

ADK-native endpoints on authenticated Cloud Run (no custom `/health`):

1. `GET /list-apps`
2. `POST /apps/{app}/users/{userId}/sessions/{sessionId}` — **create-only** on ADK InMemorySessionService. Flutter:
   - **Skips** the POST when this process already ensured `userId + sessionId` (keepAlive DS).
   - **409** = already exists (success).
   - **400** = already exists **only if** JSON `detail` is a string **and contains the posted `sessionId`** (FastAPI `{"detail":"Session already exists: <id>"}`). Other 400s are real failures. Do not match English “already exists” for merchant copy — the UUID is the contract.
   - `daftarContext` still travels on `/run`.
3. `POST /run` — if the instance scaled to zero and the in-memory session is gone, `/run` may 404. Flutter **clears** the warm key, POSTs create once, and retries `/run` once.
4. `POST /v1/email/send-batch` — Appendix **J.7** multipart (manifest JSON + `pdf_{contactId}`). Same Cloud Run IAM + custom audiences as `/run`. **Not** an ADK tool. Stdlib Gmail SMTP MIME + PDF. Send set cap **20**; MIME PDF on device-ranked Top **5** only.
5. `POST /v1/tts` — Chirp 3 HD Enceladus MP3 (`locale` `ar` \| `en`, cap 2000 chars). Same IAM. **Not** an ADK tool. Runtime SA needs `roles/cloudtts.user`. Device `flutter_tts` is the offline fail-soft.

Warm-path goal: one `/run`, one model hop (`propose_*`, not `parse_goal` on clear capture/close), MINIMAL thinking. Subsequent Sends should be a few seconds, not 10–20s. First Send with **min-instances 0** stays a cold start. Zero-millisecond LLM responses are not possible on Vertex.

See [ADK Cloud Run deploy](https://adk.dev/deploy/cloud-run/) (`get_fast_api_app`) and the [GCP ADK tutorial](https://docs.cloud.google.com/run/docs/ai/build-and-deploy-ai-agents/deploy-adk-agent).

### Context carriage (locked)

| Channel | Content |
| --- | --- |
| `stateDelta.daftarContext` | Full [`DeviceAgentRequest`](openapi.yaml) (correlationId, locale, merchantLocalDay, ledgers, voiceHints, currency flags, goalText, optional audioRef) |
| `newMessage.parts[].text` | Same string as `goalText` |

Flutter (Stage 2) builds `daftarContext` from Drift / settings / `GetActiveVoiceContextUseCase` and never embeds Vertex or Gemini keys.

## Auth (Appendix J.1)

GSI v7 ID tokens from Flutter (`GoogleAuthDs.obtainIdToken`) have **`aud` = the Web OAuth client ID** (`GOOGLE_SERVER_CLIENT_ID`), not the `*.run.app` URL. PKCE-minted ID tokens (silent hourly refresh) have **`aud` = the Android or iOS installed-app client ID**. Sending a JWT without a matching Cloud Run **custom audience** yields **401** at the GFE. `gcloud auth print-identity-token` still works because its audience is the service URL.

**Contest path (no Gemini key, no token-broker, no `--allow-unauthenticated`):**

1. Keep Cloud Run authenticated.
2. Custom audiences = Web client ID **and** Android/iOS installed-app client IDs (GSI `aud` vs PKCE `aud`).
3. Grant `roles/run.invoker` to `allAuthenticatedUsers` (any Google-authenticated user; still requires a valid Google ID token — not public).
4. Flutter: reuse the **linked** Google session’s ID token. Interceptor is silent (`allowInteractive: false`). Agent Send hydrates via the **PKCE refresh token** (`openid`) — never GSI `attemptLightweightAuthentication` / a second account picker.

| Rule | Value |
| --- | --- |
| Cloud Run | Authenticated invokers only (`--no-allow-unauthenticated`) |
| Primary | Google **ID token** (`Authorization: Bearer`) of the same `googleUserId` as Drive (`AuthSessionBundle`). Cached on the bundle; interceptor uses `obtainIdToken(allowInteractive: false)` |
| Silent renew | PKCE `grant_type=refresh_token` returns `id_token` when the grant includes `openid`. GSI lightweight restore is **forbidden** on Send |
| Audience | Custom audiences = Web client ID (`GOOGLE_SERVER_CLIENT_ID`) + Android/iOS installed-app client IDs |
| Invoker | `allAuthenticatedUsers` has `roles/run.invoker` (still requires a Google ID token; not public). `user:akrm.codes@gmail.com` may remain as a redundant binding |
| Fallback | `X-Daftar-Agent-Secret` is **not** implemented in Stage 2.2 (only if custom audience is blocked) |
| Forbidden | Gemini API key / Vertex SA key in the Flutter app; `--allow-unauthenticated`; interceptor `authenticate()` / a second Google picker |

Owner ops (missing either → live Flutter 401). Do **not** print or commit the Web client ID.

> **DO NOT RUN — frozen All Things Agentic.** The following `update` / `add-iam-policy-binding` commands are **historical**. Do not mutate service `daftar-closing-agent`.

```text
HISTORICAL — do not execute. Frozen All Things Agentic Cloud Run.

# Custom audiences = product-GCP OAuth clients from gitignored .env
# (Web = GSI aud; Android/iOS = PKCE-minted ID token aud)
gcloud run services update daftar-closing-agent \
  --project=daftar-closing-agent \
  --region=us-central1 \
  --add-custom-audiences="$GOOGLE_SERVER_CLIENT_ID" \
  --add-custom-audiences="$GOOGLE_OAUTH_CLIENT_ID_ANDROID" \
  --add-custom-audiences="$GOOGLE_OAUTH_CLIENT_ID_IOS"

gcloud run services add-iam-policy-binding daftar-closing-agent \
  --project=daftar-closing-agent \
  --region=us-central1 \
  --member='allAuthenticatedUsers' \
  --role='roles/run.invoker'
```

If Domain Restricted Sharing rejects `allAuthenticatedUsers`, use `--no-invoker-iam-check` **and** verify the Google ID token inside the ADK container (`google.oauth2.id_token.verify_oauth2_token` with the Web client ID). Do not leave Run open with no verify.

Verify (audience value is a secret-adjacent client ID — do not paste it into tickets):

```bash
gcloud run services describe daftar-closing-agent \
  --project=daftar-closing-agent \
  --region=us-central1 \
  --format='yaml(status.url,status.conditions)'
# metadata.annotations.run.googleapis.com/custom-audiences must be non-empty
```

## Proposals

Every successful tool result is an **`AgentProposal`**:

- `proposalId` — UUID (idempotency key)
- `tool` — e.g. `propose_debt`, `propose_closing_plan`
- `payload` — tool-specific object (OpenAPI components)
- `confirmRequired` — `true` for money / create / WhatsApp / statement / closing-plan; `false` for `parse_goal`

Failures return `{status: "error", error_message}` **without** `proposalId` so the model can retry.

### Money (HARD)

- Field name: **`amountMinor`**
- Type: **`integer` only** (smallest currency unit)
- Plus `currencyCode` string
- Never `double` / `num` / float / Decimal / string / bool amounts
- Precision (match Flutter `CurrencyPrecision`):
  - **YER** — 0 dp → spoken `500` → `amountMinor: 500`
  - **SAR / USD** — 2 dp → spoken `500` → `amountMinor: 50000`
- Tools do **not** convert major→minor; the model must pass the correct integer.
- Empty currency → `daftarContext.defaultCurrency`; if `isMultiCurrencyEnabled` is false, currency is forced to default.

### Tool surface (Stage 1.2)

Implemented in [`closing_agent/tools.py`](closing_agent/tools.py) (+ helpers in [`closing_agent/proposal.py`](closing_agent/proposal.py)); wired from [`closing_agent/agent.py`](closing_agent/agent.py):

| Tool | Notes |
| --- | --- |
| `parse_goal` | `goalClass` enum; `confirmRequired: false`. Instruction: **do not** call on clear debt/payment/close/create/statement — one `propose_*` hop. Use only for `ask`, `backup_only`, or ambiguous text. Tool stays in `ALL_TOOLS` / OpenAPI. |
| `propose_debt` / `propose_payment` | `contactHint`, `amountMinor` int, currency, optional `itemName` (goods / صنف), optional `note` (remark), ledger; resolves `contactId` from `voiceHints` |
| `propose_create_contact` | `ledgerId` **required** when `daftarContext.ledgers.length > 1` |
| `propose_create_ledger` | `type` ∈ customers / suppliers / personal / custom |
| `propose_closing_plan` | ordered `steps`; echoes `merchantLocalDay`; instruction requires ≥3 for close-day |
| `propose_whatsapp_drafts` | `{contactId, tone, body}[]` — prepare only |
| `propose_statement` | optional UUID `contactId` + `contactHint`; device resolves from Drift |

No custom `GET /health` — smoke uses ADK `/list-apps`, session create, `/run`.

### Observability (Stage 1.3)

ADK `before_/after_model_callback` and `before_/after_tool_callback` emit **single-line JSON** to stdout ([Cloud Logging structured logs](https://cloud.google.com/logging/docs/structured-logging)). Cloud Run maps them to `jsonPayload`.

| Field | Events |
| --- | --- |
| `session_id` | model + tool |
| `tool_name` | tool |
| `latency_ms` | model + tool |
| `model_id` | model + tool (`gemini-3.5-flash`) |
| `correlation_id` | when `daftarContext.correlationId` is set |
| `event` | `daftar.agent.model` / `daftar.agent.tool` (+ `.start`) / `daftar.agent.email` |

Demo / Logs Explorer query:

```text
resource.type="cloud_run_revision"
resource.labels.service_name="daftar-closing-agent"
jsonPayload.event=("daftar.agent.tool" OR "daftar.agent.model" OR "daftar.agent.email" OR "daftar.agent.tts")
```

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="daftar-closing-agent" AND jsonPayload.event="daftar.agent.tool"' \
  --project=daftar-closing-agent --limit=5 --format=json
```

### Local tests

```bash
cd agent
python3 -m venv /tmp/daftar-agent-venv   # or any venv
/tmp/daftar-agent-venv/bin/pip install -r requirements-dev.txt
/tmp/daftar-agent-venv/bin/python -m pytest tests/ -q
```

Send-batch tests mock `smtplib` (no live Gmail). The App Password must never appear in log JSON or HTTP bodies. TTS tests inject a fake Chirp client (no live Cloud TTS). Merchant text must never appear in `daftar.agent.tts` logs.

## Confirm gate (device — Stage 2)

Documented in OpenAPI under `/contract/confirm` and `/contract/cancel` (**not** Cloud Run routes):

1. Single-flight lock while a `proposalId` is committing
2. Re-confirm of an already-committed `proposalId` → success / noop (no second Drift write)
3. Cancel → never writes money (optional journal “skipped”)

## Smoke

Heritage ADK `/run` smoke (All Things Agentic, **frozen** service — describe-only; do not retarget):

```bash
cd agent
python3 scripts/smoke_1_4.py
# Writes agent/smoke_evidence/*_report.json (gitignored)
```

**Verified (13 Aug 2026):** close-day → `propose_closing_plan` with ≥3 steps; Mohamed → `propose_debt` `amountMinor=500` (YER); logs show `model_id=gemini-3.5-flash`.

CALL-E sibling smoke (Stage 1.4 — **`daftar-call-e` only**, no PSTN, kill switch stays false). URL and allowlist come from `$HOME/.daftar-owner-ops/` (never git):

```bash
cd agent
python3 scripts/smoke_calls_plan_run.py
# unauth 403, dry-run, YE unsupportedRegion, over-cap 400,
# plan killSwitch, run-batch 403, GET fake runId 404
```

Do **not** use `smoke_1_4.py` for CALL-E routes. Do **not** pass `--live` or set `CALLE_ALLOW_DIAL=true` for this script.

Stage 4.7 send-batch (after deploy; one owned To from env — do not print the mailbox):

```bash
GMAIL_SMTP_TO=… python3 scripts/smoke_4_7_send_batch.py
# http=200 status=sent smtpCode=250 smtpMessageId=… logOk=True
```
