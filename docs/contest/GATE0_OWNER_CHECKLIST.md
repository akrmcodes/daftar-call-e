# Gate 0 — Owner Ops Checklist (Contest)

> **Complete. Not current work.** GCP, credits form, Devpost start date, and Stage 8 quarantine are done. Stages 1–5 already shipped. Do not treat this file as the next task.

Agent-completable Stage 8 quarantine and docs were finished before Stage 1 (ADK / Cloud Run).

Binding contract: [`roadmap_v2.md`](../roadmap_v2.md) §0.0–0.3, Gate 0.
Submission Period: **3–31 Aug 2026**.

## Done (historical — all checked)

### 1. Credits (deadline: form closes 28 Aug 2026 12:00 PT)

- [x] Open https://forms.gle/riGhgDSHkHeMx8Ca6
- [x] Request **$150** All Things Agentic credits for **`akrm.codes@gmail.com`**
- [x] Expect up to **72 business hours** review — do not wait to create the GCP project

### 2. Devpost

- [x] Set project **start date** to **3 Aug 2026** (Submission Period opens that day)
- [x] Track preview: **Taskmaster** · Individual

### 3. GCP project (`akrm.codes@gmail.com`)

- [x] Create project e.g. `daftar-closing-agent` → note `PROJECT_ID`
- [x] Prefer region **`us-central1`**
- [x] Link billing (trial OK if credits lag)
- [x] Budget alerts **$50 / $100 / $140**
- [x] `gcloud auth login` · `gcloud config set project $PROJECT_ID`

### 4. Enable APIs

- [x] All 13 APIs enabled on `daftar-closing-agent` (verified 13 Aug 2026)

```bash
gcloud services enable \
  aiplatform.googleapis.com \
  generativelanguage.googleapis.com \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com \
  speech.googleapis.com \
  texttospeech.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com
```

### 5. Runtime service account

- [x] Create `agent-runner@daftar-closing-agent.iam.gserviceaccount.com` (13 Aug 2026)
- [x] Roles: `roles/aiplatform.user`, `roles/secretmanager.secretAccessor`, `roles/logging.logWriter`, `roles/speech.client` (STT); TTS — API enabled, no separate IAM role
- [x] Prefer Vertex + SA — **no Gemini API key in Flutter**; deploy with `--service-account=agent-runner@$PROJECT_ID.iam.gserviceaccount.com` in Stage 1

### 6. Device / smoke

- [x] Dedicated demo phone or profile for package `com.akrmcodes.daftar`
- [x] Cold start → create ledger → add txn
- [x] Settings: **no** Sync Report / Team / Join Workspace rows
- [x] Drive sign-in + backup smoke (if OAuth clients present)
- [x] Confirm `.env` never committed
- [x] **Drive PKCE:** root `.env` must exist **before** any Android build — Gradle reads `GOOGLE_OAUTH_CLIENT_ID_ANDROID` into `appAuthRedirectScheme`. Missing `.env` used to fall back to `com.akrmcodes.daftar` and broke consent return (Chrome → Google Search). Build now **fails** if the key is missing. After restoring `.env`, do a clean rebuild before testing “Complete Drive permissions”.

## Already done by agent (do not redo)

- Kill-switch `kContestDisableMultiDeviceSync`
- Sync/deep-link engines no-op; mutation trigger no-op; route redirects
- Sync / Team / **Join Workspace** settings rows hidden
- Pro+ Plans/activation sync marketing softened (contest ARB keys); compare sync row omitted
- Defense-in-depth: exchange JWT / AppLinks / `canUseFeature(multiDeviceSync)` / CollaborationGate hard-off
- [`CONTEST_DISCLOSURE.md`](../CONTEST_DISCLOSURE.md) + root README
- Roadmap v2.2 quarantine contract
- Drive/auth use cases still present; analyze clean on quarantine + backup surfaces
- Working tree has no staged `.env` / client secrets (`.env` is gitignored)

## Historical close-out

Gate 0 in [`roadmap_v2.md`](../roadmap_v2.md) is checked. Stages 1–6 already shipped. Current owner work is Stage 7 (Devpost track / submit), not this checklist.
