# All Things Agentic Cloud Run freeze

**Date recorded:** 2026-09-01

This file is a **read-only snapshot**. Recording a revision is **not permission to update**, deploy, replace traffic, delete, or change IAM on this service.

CALL-E work in `daftar-call-e` must not mutate All Things Agentic production through at least **13 Oct 2026**. Legal CALL-E Cloud Run name is **`daftar-call-e`**, via [`agent/scripts/deploy_daftar_call_e.sh`](../../agent/scripts/deploy_daftar_call_e.sh) only (Stage 1 — not this pass).

## Frozen identity

| Field | Value |
| --- | --- |
| GCP project | `daftar-closing-agent` |
| Region | `us-central1` |
| Cloud Run service | `daftar-closing-agent` |
| URL | `https://daftar-closing-agent-1487285471.us-central1.run.app` |
| Runtime SA | `agent-runner@daftar-closing-agent.iam.gserviceaccount.com` |

**latestReadyRevisionName:** `daftar-closing-agent-00055-pbm`

Recorded with `gcloud run services describe` on 2026-09-01. The numbered `*.run.app` URL above is the frozen Envied default. Describe also reports a hash hostname; that is the same service, not a second deploy target.

Owner-machine local copy (not in git): `$HOME/.daftar-owner-ops/daftar-closing-agent-00055-identity.yaml` (revision, URL, SA, image) and `daftar-closing-agent-iam.yaml` (IAM policy only, no env).

## Exact describe command (allowed)

```bash
gcloud run services describe daftar-closing-agent \
  --project=daftar-closing-agent \
  --region=us-central1
```

`get-iam-policy` and `list` are also allowed. **Not permission to update.**

Forbidden: `gcloud run deploy daftar-closing-agent`, `gcloud run services update/replace/replace-traffic/delete`, `add-iam-policy-binding` / `set-iam-policy` on this service, `adk deploy cloud_run`.

Re-check (read-only): [`tool/check_agentic_freeze.sh`](../../tool/check_agentic_freeze.sh).

## CALL-E runtime SA (not the frozen runner)

Created 2026-09-01: `call-e-runner@daftar-closing-agent.iam.gserviceaccount.com`. Future service `daftar-call-e` uses this SA. Do **not** change `agent-runner`.

## Secret `calle-api-key`

Owner created a Developer API key out of band (2026-09-01). It is **not** in git. Stage **0.3** (2026-09-02) loaded it into Secret Manager `calle-api-key` from `$HOME/.daftar-owner-ops/calle-api-key` via [`agent/scripts/stage0_3_gcp.sh`](../../agent/scripts/stage0_3_gcp.sh). Never write a key to git, Flutter, chat, or logs.

## Stage 0.3 (2026-09-02) — Secret Manager + IAM only

- Secret `calle-api-key` version 1 enabled. Accessor: `call-e-runner` only (secret-level).
- Secret `gmail-smtp-app-password`: **added** `call-e-runner` `secretAccessor`; **kept** `agent-runner`. Frozen Cloud Run mount unchanged.
- Project IAM on `call-e-runner` only: `roles/aiplatform.user`, `roles/logging.logWriter`, `roles/speech.client`. **No** project-level `secretAccessor` on this SA.
- Cloud Run `daftar-call-e` still **does not exist**. Frozen revision still `daftar-closing-agent-00055-pbm`. Vertex env on the frozen revision still `TRUE` / `global`.
- Stage 1 will file-mount `/secrets/calle-api-key` and `/secrets/gmail-smtp-app-password` on **`daftar-call-e` only**.

## Non-goals (still)

- No Confirm & Call
- No `daftar-call-e` Cloud Run create/deploy
- No Cloud Run mutate / IAM on `daftar-closing-agent`
- No Envied `defaultValue` change
- Do not enable `billingbudgets.googleapis.com`. Owner confirmed 2026-09-02 that $50 / $100 / $140 budgets remain.
