#!/usr/bin/env bash
# Read-only: describe frozen All Things Agentic Cloud Run and diff revision
# against docs/contest/AGENTIC_CLOUD_RUN_FREEZE.md.
# Safe to run anytime. Never deploys.

set -euo pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${_script_dir}/.." && pwd)"
SNAPSHOT="${repo_root}/docs/contest/AGENTIC_CLOUD_RUN_FREEZE.md"
REFUSE="${repo_root}/agent/scripts/refuse_frozen_cloud_run.sh"

export DAFTAR_FREEZE_READ_ONLY=1
# shellcheck source=../agent/scripts/refuse_frozen_cloud_run.sh
source "$REFUSE"
daftar_refuse_frozen_cloud_run || exit 1

PROJECT="daftar-closing-agent"
REGION="us-central1"
FROZEN_SERVICE="daftar-closing-agent"

if [[ ! -f "$SNAPSHOT" ]]; then
  echo "check_agentic_freeze.sh: missing $SNAPSHOT" >&2
  exit 1
fi

live="$(gcloud run services describe "$FROZEN_SERVICE" \
  --project="$PROJECT" \
  --region="$REGION" \
  --format='value(status.latestReadyRevisionName)')"

snap="$(sed -n 's/^\*\*latestReadyRevisionName:\*\* `\([^`]*\)`.*/\1/p' "$SNAPSHOT" | head -1)"

echo "live:  $live"
echo "snap:  $snap"

if [[ "$snap" == "PENDING" || -z "$snap" ]]; then
  echo "Snapshot is PENDING — owner must record describe output. Not a mismatch fail." >&2
  exit 0
fi

if [[ "$live" != "$snap" ]]; then
  echo "FREEZE BREACH: frozen revision changed. STOP CALL-E work until owner reviews." >&2
  exit 1
fi

echo "Freeze OK: $live"
exit 0
