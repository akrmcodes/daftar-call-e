#!/usr/bin/env bash
# Legal CALL-E Cloud Run deploy for THIS fork only.
# Service name must be exactly daftar-call-e.
# Never targets the frozen All Things Agentic service.
#
# Abort unless:
# - git origin contains daftar-call-e and does not contain daftar-closing-agent.git
# - service name is daftar-call-e (never daftar-closing-agent)
# - flags/env do not contain daftar-closing-agent-1487285471
# - the command is not adk deploy
#
# This pass (Stage 1 not started): exits 2 if daftar-call-e does not exist.
# Future Stage 1: gcloud run deploy daftar-call-e with the flags below.
#
# Usage (from repo):
#   bash agent/scripts/deploy_daftar_call_e.sh
#   (cwd may be repo root or agent/)

set -euo pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=refuse_frozen_cloud_run.sh
source "${_script_dir}/refuse_frozen_cloud_run.sh"

PROJECT="daftar-closing-agent"
REGION="us-central1"
LEGAL_SERVICE="daftar-call-e"
FROZEN_SERVICE="daftar-closing-agent"
RUNNER_SA="call-e-runner@${PROJECT}.iam.gserviceaccount.com"
SNAPSHOT="${_script_dir}/../../docs/contest/AGENTIC_CLOUD_RUN_FREEZE.md"

cd "${_script_dir}/.."
if [[ ! -f main.py && ! -f Dockerfile && ! -f requirements.txt ]]; then
  echo "deploy_daftar_call_e.sh: expected to run from agent/ (cwd=$(pwd))" >&2
  exit 1
fi

repo_root="$(cd .. && pwd)"
if [[ "$(basename "$repo_root")" != "daftar-call-e" ]]; then
  echo "deploy_daftar_call_e.sh: abort unless cwd is …/daftar-call-e/agent" >&2
  exit 1
fi

daftar_refuse_frozen_cloud_run "$@" || exit 1

# Infer service from args; default legal name. Never daftar-closing-agent.
SERVICE_NAME="$LEGAL_SERVICE"
for a in "$@"; do
  case "$a" in
    --service=*) SERVICE_NAME="${a#--service=}" ;;
    --service_name=*) SERVICE_NAME="${a#--service_name=}" ;;
    daftar-call-e|daftar-closing-agent) SERVICE_NAME="$a" ;;
  esac
done

if [[ "$SERVICE_NAME" != "$LEGAL_SERVICE" ]]; then
  echo "deploy_daftar_call_e.sh: require explicit service daftar-call-e (got: $SERVICE_NAME)" >&2
  exit 1
fi

daftar_refuse_frozen_cloud_run "$SERVICE_NAME" || exit 1

if ! gcloud run services describe "$LEGAL_SERVICE" \
  --project="$PROJECT" \
  --region="$REGION" \
  --format='value(metadata.name)' >/dev/null 2>&1; then
  echo "Stage 1 not started: Cloud Run service daftar-call-e does not exist. Refusing deploy." >&2
  exit 2
fi

if ! gcloud iam service-accounts describe "$RUNNER_SA" --project="$PROJECT" >/dev/null 2>&1; then
  echo "deploy_daftar_call_e.sh: runtime SA missing: $RUNNER_SA" >&2
  exit 1
fi

# Future Stage 1 flags (not reached until daftar-call-e exists):
# gcloud run deploy daftar-call-e \
#   --source=. \
#   --project=daftar-closing-agent \
#   --region=us-central1 \
#   --no-allow-unauthenticated \
#   --min=0 --max=2 \
#   --min-instances=0 --max-instances=2 \
#   --port=8000 \
#   --service-account=call-e-runner@daftar-closing-agent.iam.gserviceaccount.com

echo "daftar-call-e exists. Deploy is Stage 1 — this wrapper will not silently skip freeze checks." >&2
echo "Post-deploy: describe BOTH services; frozen latestReadyRevisionName must match ${SNAPSHOT}" >&2

_frozen_rev="$(gcloud run services describe "$FROZEN_SERVICE" \
  --project="$PROJECT" \
  --region="$REGION" \
  --format='value(status.latestReadyRevisionName)')"
_snap_rev=""
if [[ -f "$SNAPSHOT" ]]; then
  _snap_rev="$(sed -n 's/^\*\*latestReadyRevisionName:\*\* `\([^`]*\)`.*/\1/p' "$SNAPSHOT" | head -1)"
fi
if [[ -n "$_snap_rev" && "$_snap_rev" != "PENDING" && "$_frozen_rev" != "$_snap_rev" ]]; then
  echo "FREEZE BREACH: frozen latestReadyRevisionName is ${_frozen_rev}, snapshot is ${_snap_rev}. STOP." >&2
  exit 1
fi

echo "Frozen revision still ${_frozen_rev}. Refusing to deploy from this pass without Stage 1 owner intent." >&2
exit 2
