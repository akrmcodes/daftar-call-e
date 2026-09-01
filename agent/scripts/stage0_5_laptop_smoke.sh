#!/usr/bin/env bash
# Gate 0 laptop smoke. Places one real CALL-E call.
# Requires CALLE_ALLOW_DIAL=true in this shell. Does not mutate Cloud Run.
# Does not print the API key or full E.164.
#
#   export CALLE_ALLOW_DIAL=true
#   bash agent/scripts/stage0_5_laptop_smoke.sh

set -euo pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=refuse_frozen_cloud_run.sh
source "${_script_dir}/refuse_frozen_cloud_run.sh"

export DAFTAR_FREEZE_READ_ONLY=1
daftar_refuse_frozen_cloud_run "$@" || exit 1

if [[ "${CALLE_ALLOW_DIAL:-}" != "true" ]]; then
  echo "stage0_5: export CALLE_ALLOW_DIAL=true in this shell first" >&2
  exit 1
fi

repo_root="$(daftar_freeze_repo_root)" || exit 1
VENV="${repo_root}/agent/.venv"
PY="${VENV}/bin/python"
SMOKE="${_script_dir}/stage0_5_laptop_smoke.py"

if [[ ! -x "${PY}" ]]; then
  echo "stage0_5: missing ${PY} — create agent/.venv and pip install calle-ai==0.7.0" >&2
  exit 1
fi

prefix="$("${PY}" -c 'import sys; print(sys.prefix)')"
if [[ "${prefix}" != *"/daftar-call-e/"* ]] || [[ "${prefix}" == *"/03_Ai/"* ]]; then
  echo "stage0_5: refusing interpreter outside this fork" >&2
  exit 1
fi

# Load secrets into this process only; do not echo.
export CALLE_API_KEY
CALLE_API_KEY="$(cat "${HOME}/.daftar-owner-ops/calle-api-key")"
export CALLE_ALLOWLIST
CALLE_ALLOWLIST="$(cat "${HOME}/.daftar-owner-ops/calle-allowlist")"
export CALLE_ALLOWLIST_REGION
CALLE_ALLOWLIST_REGION="$(cat "${HOME}/.daftar-owner-ops/calle-allowlist-region")"
export CALLE_BASE_URL="https://api.heycall-e.com"

echo "stage0_5: Linphone must be Registered and Available. Dialing prod API."
set +e
"${PY}" "${SMOKE}"
rc=$?
set -e
unset CALLE_API_KEY CALLE_ALLOWLIST CALLE_ALLOWLIST_REGION
echo "stage0_5: env secrets unset. Unset CALLE_ALLOW_DIAL in the parent shell too."
unset CALLE_ALLOW_DIAL
exit "${rc}"
