#!/usr/bin/env bash
# Legal CALL-E Cloud Run deploy for THIS fork only.
# Service name must be exactly daftar-call-e.
# Never targets the frozen All Things Agentic service.
#
# Abort unless:
# - git origin contains daftar-call-e and does not contain daftar-closing-agent.git
# - service name is daftar-call-e (never daftar-closing-agent)
# - flags/env do not contain daftar-closing-agent-1487285471
# - the command is not the ADK Cloud Run deployer
# - DAFTAR_CALL_E_DEPLOY is exactly true
#
# Usage (from repo):
#   export DAFTAR_CALL_E_DEPLOY=true
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
# Frozen hostname daftar-closing-agent-1487285471 is not a deploy target.
FROZEN_HOST="daftar-closing-agent-1487285471"
RUNNER_SA="call-e-runner@${PROJECT}.iam.gserviceaccount.com"
ACCOUNT_EXPECT="akrm.codes@gmail.com"
OWNER_MEMBER="user:${ACCOUNT_EXPECT}"
SNAPSHOT="${_script_dir}/../../docs/contest/AGENTIC_CLOUD_RUN_FREEZE.md"
OPS="${HOME}/.daftar-owner-ops"
URL_FILE="${OPS}/daftar-call-e-url"
mkdir -p "${OPS}"
chmod 700 "${OPS}" 2>/dev/null || true

# Leftover Flutter env must not trip refuse (it is not a deploy flag).
unset CLOSING_AGENT_BASE_URL || true

cd "${_script_dir}/.."
if [[ ! -f main.py || ! -f Dockerfile || ! -f requirements.txt ]]; then
  echo "deploy_daftar_call_e.sh: expected to run from agent/ (cwd=$(pwd))" >&2
  exit 1
fi

repo_root="$(cd .. && pwd)"
if [[ "$(basename "$repo_root")" != "daftar-call-e" ]]; then
  echo "deploy_daftar_call_e.sh: abort unless cwd is …/daftar-call-e/agent" >&2
  exit 1
fi

CHECK_FREEZE="${repo_root}/tool/check_agentic_freeze.sh"
ENV_FILE="${repo_root}/.env"

daftar_refuse_frozen_cloud_run "$@" || exit 1

if [[ "${DAFTAR_CALL_E_DEPLOY:-}" != "true" ]]; then
  echo "deploy_daftar_call_e.sh: DAFTAR_CALL_E_DEPLOY must be exactly true" >&2
  exit 2
fi

for a in "$@"; do
  if [[ "$a" == "--allow-unauthenticated" ]]; then
    echo "deploy_daftar_call_e.sh: refusing unauthenticated deploy" >&2
    exit 1
  fi
done

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

account="$(gcloud config get-value account 2>/dev/null || true)"
if [[ "${account}" != "${ACCOUNT_EXPECT}" ]]; then
  echo "deploy_daftar_call_e.sh: gcloud account must be ${ACCOUNT_EXPECT}" >&2
  exit 1
fi

cfg_project="$(gcloud config get-value project 2>/dev/null || true)"
if [[ "${cfg_project}" != "${PROJECT}" ]]; then
  echo "deploy_daftar_call_e.sh: gcloud project must be ${PROJECT}" >&2
  exit 1
fi

if [[ ! -f "${CHECK_FREEZE}" ]]; then
  echo "deploy_daftar_call_e.sh: missing freeze checker" >&2
  exit 1
fi
bash "${CHECK_FREEZE}" || exit 1

if ! gcloud iam service-accounts describe "$RUNNER_SA" --project="$PROJECT" >/dev/null 2>&1; then
  echo "deploy_daftar_call_e.sh: runtime SA missing: $RUNNER_SA" >&2
  exit 1
fi

daftar_iam_add() {
  local out rc
  set +e
  out="$("$@" 2>&1)"
  rc=$?
  set -e
  if [[ "${rc}" -eq 0 ]]; then
    echo "IAM granted." >&2
    return 0
  fi
  if [[ "${out}" == *"already exists"* ]]; then
    echo "IAM already present (ok)." >&2
    return 0
  fi
  printf '%s\n' "${out}" >&2
  return "${rc}"
}

echo "deploy_daftar_call_e: copying mailbox env from frozen revision (describe only)" >&2
# shellcheck source=read_gmail_env_from_frozen.sh
source "${_script_dir}/read_gmail_env_from_frozen.sh"
unset DAFTAR_FREEZE_READ_ONLY DAFTAR_GMAIL_ENV_SERVICE || true
if [[ -z "${GMAIL_SMTP_USER:-}" || -z "${GMAIL_SMTP_FROM:-}" ]]; then
  echo "deploy_daftar_call_e.sh: GMAIL_SMTP_USER and GMAIL_SMTP_FROM are required" >&2
  exit 1
fi
if [[ "${GMAIL_SMTP_USER}" != "${GMAIL_SMTP_FROM}" ]]; then
  echo "deploy_daftar_call_e.sh: GMAIL_SMTP_USER must equal GMAIL_SMTP_FROM" >&2
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "deploy_daftar_call_e.sh: missing gitignored .env (OAuth audiences)" >&2
  exit 1
fi

_aud_tmp="$(mktemp)"
chmod 600 "${_aud_tmp}"
python3 - "${ENV_FILE}" "${_aud_tmp}" <<'PY'
from pathlib import Path
import sys

env_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
needed = (
    "GOOGLE_SERVER_CLIENT_ID",
    "GOOGLE_OAUTH_CLIENT_ID_ANDROID",
    "GOOGLE_OAUTH_CLIENT_ID_IOS",
)
vals: dict[str, str] = {}
for raw in env_path.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, _, value = line.partition("=")
    key = key.strip()
    value = value.strip().strip("'").strip('"')
    if key in needed:
        vals[key] = value
missing = [k for k in needed if not vals.get(k)]
if missing:
    raise SystemExit("missing OAuth audience keys in .env")
if len({vals[k] for k in needed}) != 3:
    raise SystemExit("OAuth audiences must be three distinct client IDs")
out_path.write_text("\n".join(vals[k] for k in needed) + "\n", encoding="utf-8")
PY
WEB_AUD="$(sed -n '1p' "${_aud_tmp}")"
ANDROID_AUD="$(sed -n '2p' "${_aud_tmp}")"
IOS_AUD="$(sed -n '3p' "${_aud_tmp}")"
rm -f "${_aud_tmp}"
if [[ -z "${WEB_AUD}" || -z "${ANDROID_AUD}" || -z "${IOS_AUD}" ]]; then
  echo "deploy_daftar_call_e.sh: expected 3 custom audiences" >&2
  exit 1
fi
echo "deploy_daftar_call_e: custom-audience count=3 (values not printed)" >&2

echo "deploy_daftar_call_e: copying timeout/memory/cpu from frozen describe" >&2
_res="$(
  gcloud run services describe "${FROZEN_SERVICE}" \
    --project="${PROJECT}" \
    --region="${REGION}" \
    --format=json | python3 -c '
import json, sys
d = json.load(sys.stdin)
tpl = ((d.get("spec") or {}).get("template") or {})
inner = tpl.get("spec") or {}
containers = inner.get("containers") or [{}]
c = containers[0]
limits = ((c.get("resources") or {}).get("limits") or {})
timeout = inner.get("timeoutSeconds") or (tpl.get("metadata") or {}).get("annotations", {}).get("run.googleapis.com/timeout")
if not timeout:
    timeout = 300
memory = limits.get("memory") or "1Gi"
cpu = limits.get("cpu") or "1"
print(timeout, memory, cpu)
'
)"
read -r CR_TIMEOUT CR_MEMORY CR_CPU <<<"${_res}"
echo "deploy_daftar_call_e: timeout=${CR_TIMEOUT} memory=${CR_MEMORY} cpu=${CR_CPU}" >&2

echo "deploy_daftar_call_e: grant actAs on call-e-runner" >&2
daftar_iam_add gcloud iam service-accounts add-iam-policy-binding "${RUNNER_SA}" \
  --project="${PROJECT}" \
  --member="${OWNER_MEMBER}" \
  --role="roles/iam.serviceAccountUser" \
  --quiet

_project_number="$(gcloud projects describe "${PROJECT}" --format='value(projectNumber)')"
_compute_sa="${_project_number}-compute@developer.gserviceaccount.com"
_cloudbuild_sa="${_project_number}@cloudbuild.gserviceaccount.com"
daftar_iam_add gcloud iam service-accounts add-iam-policy-binding "${RUNNER_SA}" \
  --project="${PROJECT}" \
  --member="serviceAccount:${_compute_sa}" \
  --role="roles/iam.serviceAccountUser" \
  --quiet
daftar_iam_add gcloud iam service-accounts add-iam-policy-binding "${RUNNER_SA}" \
  --project="${PROJECT}" \
  --member="serviceAccount:${_cloudbuild_sa}" \
  --role="roles/iam.serviceAccountUser" \
  --quiet

echo "deploy_daftar_call_e: loading allowlist from owner-ops (values not printed)" >&2
ALLOWLIST_FILE="${OPS}/calle-allowlist"
REGION_FILE="${OPS}/calle-allowlist-region"
if [[ ! -f "${ALLOWLIST_FILE}" || ! -f "${REGION_FILE}" ]]; then
  echo "deploy_daftar_call_e.sh: missing calle-allowlist or calle-allowlist-region" >&2
  exit 1
fi
# YAML env file so comma-separated E.164 is not split by --update-env-vars.
_env_file="$(mktemp "${OPS}/daftar-call-e-env.XXXXXX")"
chmod 600 "${_env_file}"
trap 'rm -f "${_env_file:-}"' EXIT
python3 - "${ALLOWLIST_FILE}" "${REGION_FILE}" "${_env_file}" "${PROJECT}" <<'PY'
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

allow_path, region_path, out_path, project = sys.argv[1:5]
gmail_user = os.environ.get("GMAIL_SMTP_USER", "").strip()
gmail_from = os.environ.get("GMAIL_SMTP_FROM", "").strip()
if not gmail_user or not gmail_from or gmail_user != gmail_from:
    raise SystemExit("gmail sender env missing or mismatched")
raw = Path(allow_path).read_text(encoding="utf-8")
entries = [part.strip() for part in raw.split(",") if part.strip()]
if not entries:
    raise SystemExit("allowlist file is empty")
e164 = re.compile(r"\+[1-9]\d{7,14}$")
for item in entries:
    if not e164.fullmatch(item):
        raise SystemExit("allowlist entry is not E.164")
region = Path(region_path).read_text(encoding="utf-8").strip()
if not re.fullmatch(r"[A-Z]{2}", region):
    raise SystemExit("allowlist region must be a 2-letter ISO code")
# Kill switch stays off on Cloud Run for this slice.
pairs = {
    "GOOGLE_GENAI_USE_VERTEXAI": "TRUE",
    "GOOGLE_CLOUD_PROJECT": project,
    "GOOGLE_CLOUD_LOCATION": "global",
    "GMAIL_SMTP_HOST": "smtp.gmail.com",
    "GMAIL_SMTP_PORT": "587",
    "GMAIL_SMTP_USER": gmail_user,
    "GMAIL_SMTP_FROM": gmail_from,
    "CALLE_ALLOW_DIAL": "false",
    "CALLE_ALLOWLIST": ",".join(entries),
    "CALLE_ALLOWLIST_REGION": region,
}
lines = [f"{key}: {json.dumps(value)}" for key, value in pairs.items()]
Path(out_path).write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"deploy_daftar_call_e: allowlist_region={region} entries={len(entries)}", file=sys.stderr)
PY

# Two Secret Manager files cannot share one mount directory on Cloud Run.
# Gmail stays /secrets/gmail-smtp-app-password (email_send default).
# CALL-E key is /calle-secrets/calle-api-key.
echo "deploy_daftar_call_e: gcloud run deploy daftar-call-e (source=agent/)" >&2
set +e
gcloud run deploy daftar-call-e \
  --source=. \
  --project="${PROJECT}" \
  --region="${REGION}" \
  --quiet \
  --no-allow-unauthenticated \
  --min=0 --max=2 \
  --min-instances=0 --max-instances=2 \
  --port=8000 \
  --timeout="${CR_TIMEOUT}" \
  --memory="${CR_MEMORY}" \
  --cpu="${CR_CPU}" \
  --service-account="${RUNNER_SA}" \
  --env-vars-file="${_env_file}" \
  --update-secrets=/secrets/gmail-smtp-app-password=gmail-smtp-app-password:latest,/calle-secrets/calle-api-key=calle-api-key:latest \
  --set-custom-audiences="${WEB_AUD},${ANDROID_AUD},${IOS_AUD}" \
  >"${OPS}/daftar-call-e-deploy.out" \
  2>"${OPS}/daftar-call-e-deploy.err"
_deploy_rc=$?
set -e
rm -f "${_env_file}"
python3 - "${OPS}/daftar-call-e-deploy.out" "${OPS}/daftar-call-e-deploy.err" <<'PY'
from pathlib import Path
import re
import sys

def scrub(path: Path) -> str:
    text = path.read_text(encoding="utf-8", errors="replace") if path.is_file() else ""
    text = re.sub(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}", "[redacted-email]", text)
    text = re.sub(r"[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com", "[redacted-audience]", text)
    text = re.sub(r"GMAIL_SMTP_(USER|FROM)=[^,\s]+", r"GMAIL_SMTP_\1=[redacted]", text)
    text = re.sub(r"CALLE_ALLOWLIST=\S+", "CALLE_ALLOWLIST=[redacted]", text)
    text = re.sub(r"\+[1-9]\d{7,14}", "[redacted-e164]", text)
    lines = [line for line in text.splitlines() if len(line) <= 400]
    return "\n".join(lines[-40:])

sys.stderr.write(scrub(Path(sys.argv[1])) + "\n")
sys.stderr.write(scrub(Path(sys.argv[2])) + "\n")
PY
rm -f "${OPS}/daftar-call-e-deploy.out" "${OPS}/daftar-call-e-deploy.err"
if [[ "${_deploy_rc}" -ne 0 ]]; then
  echo "deploy_daftar_call_e.sh: deploy failed (rc=${_deploy_rc})" >&2
  exit "${_deploy_rc}"
fi

_new_url="$(
  gcloud run services describe daftar-call-e \
    --project="${PROJECT}" \
    --region="${REGION}" \
    --format='value(status.url)'
)"
if [[ -z "${_new_url}" || "${_new_url}" != https://daftar-call-e-* ]]; then
  echo "deploy_daftar_call_e.sh: unexpected service URL (not printed)" >&2
  exit 1
fi
if [[ "${_new_url}" == *"${FROZEN_HOST}"* ]]; then
  echo "deploy_daftar_call_e.sh: REFUSE frozen hostname in new URL" >&2
  exit 1
fi
printf '%s\n' "${_new_url}" > "${URL_FILE}"
chmod 600 "${URL_FILE}"
echo "deploy_daftar_call_e: URL written to owner-ops (not README)" >&2

unset WEB_AUD ANDROID_AUD IOS_AUD GMAIL_SMTP_USER GMAIL_SMTP_FROM CALLE_ALLOWLIST CALLE_ALLOWLIST_REGION

echo "deploy_daftar_call_e: invoker IAM on daftar-call-e only" >&2
_invoker_rc=0
set +e
_invoker_out="$(
  gcloud run services add-iam-policy-binding daftar-call-e \
    --project="${PROJECT}" \
    --region="${REGION}" \
    --member="allAuthenticatedUsers" \
    --role="roles/run.invoker" \
    --quiet 2>&1
)"
_invoker_rc=$?
set -e
if [[ "${_invoker_rc}" -ne 0 ]]; then
  if [[ "${_invoker_out}" == *"already exists"* ]]; then
    echo "deploy_daftar_call_e: authenticated-users invoker already present" >&2
  else
    echo "deploy_daftar_call_e.sh: authenticated-users invoker failed. STOP." >&2
    echo "Do not open the service. Do not bind a public principal." >&2
    printf '%s\n' "${_invoker_out}" | python3 -c 'import re,sys; t=sys.stdin.read(); print(re.sub(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}", "[redacted]", t)[:800])' >&2
    exit 1
  fi
fi
daftar_iam_add gcloud run services add-iam-policy-binding daftar-call-e \
  --project="${PROJECT}" \
  --region="${REGION}" \
  --member="${OWNER_MEMBER}" \
  --role="roles/run.invoker" \
  --quiet

echo "deploy_daftar_call_e: post-verify (filtered)" >&2
python3 - "${PROJECT}" "${REGION}" "${LEGAL_SERVICE}" "${FROZEN_SERVICE}" "${SNAPSHOT}" "${RUNNER_SA}" <<'PY'
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

project, region, legal, frozen, snapshot, runner_sa = sys.argv[1:7]
pub = "all" + "Users"


def describe(name: str) -> dict:
    raw = subprocess.check_output(
        [
            "gcloud",
            "run",
            "services",
            "describe",
            name,
            "--project",
            project,
            "--region",
            region,
            "--format=json",
        ],
        text=True,
    )
    return json.loads(raw)


def iam_policy(name: str) -> dict:
    raw = subprocess.check_output(
        [
            "gcloud",
            "run",
            "services",
            "get-iam-policy",
            name,
            "--project",
            project,
            "--region",
            region,
            "--format=json",
        ],
        text=True,
    )
    return json.loads(raw)


def scaling(resource: dict) -> tuple[str, str, str, str]:
    meta = resource.get("metadata") or {}
    ann = meta.get("annotations") or {}
    svc_max = ann.get("run.googleapis.com/maxScale") or "?"
    svc_min = ann.get("run.googleapis.com/minScale") or "0"
    tpl = ((resource.get("spec") or {}).get("template") or {})
    tpl_ann = (tpl.get("metadata") or {}).get("annotations") or {}
    rev_max = tpl_ann.get("autoscaling.knative.dev/maxScale") or "?"
    rev_min = tpl_ann.get("autoscaling.knative.dev/minScale") or "0"
    return svc_min, svc_max, rev_min, rev_max


def env_map(resource: dict) -> dict[str, str]:
    tpl = ((resource.get("spec") or {}).get("template") or {}).get("spec") or {}
    containers = tpl.get("containers") or [{}]
    out: dict[str, str] = {}
    for item in containers[0].get("env") or []:
        if "value" in item:
            out[str(item.get("name"))] = str(item.get("value") or "")
    return out


def secret_names(resource: dict) -> set[str]:
    tpl = ((resource.get("spec") or {}).get("template") or {}).get("spec") or {}
    names: set[str] = set()
    for vol in tpl.get("volumes") or []:
        sec = vol.get("secret") or {}
        n = sec.get("secretName") or ""
        if n:
            names.add(n)
    return names


def audience_count(resource: dict) -> int:
    ann = (resource.get("metadata") or {}).get("annotations") or {}
    raw = ann.get("run.googleapis.com/custom-audiences") or "[]"
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return 0
    if isinstance(parsed, list):
        return len(parsed)
    return 0


def sa_name(resource: dict) -> str:
    tpl = ((resource.get("spec") or {}).get("template") or {}).get("spec") or {}
    return str(tpl.get("serviceAccountName") or "")


frozen_res = describe(frozen)
legal_res = describe(legal)
snap = ""
text = Path(snapshot).read_text(encoding="utf-8")
for line in text.splitlines():
    if line.startswith("**latestReadyRevisionName:**"):
        snap = line.split("`")[1]
        break
frozen_rev = (frozen_res.get("status") or {}).get("latestReadyRevisionName") or ""
if snap and frozen_rev != snap:
    print(f"FREEZE BREACH: frozen {frozen_rev} != snapshot {snap}", file=sys.stderr)
    raise SystemExit(1)
if sa_name(frozen_res) != "agent-runner@daftar-closing-agent.iam.gserviceaccount.com":
    print("FREEZE BREACH: frozen runtime SA changed", file=sys.stderr)
    raise SystemExit(1)

if sa_name(legal_res) != runner_sa:
    print("new service runtime SA mismatch", file=sys.stderr)
    raise SystemExit(1)
svc_min, svc_max, rev_min, rev_max = scaling(legal_res)
if svc_max != "2" or rev_max != "2":
    print(f"cost lock fail: svc_max={svc_max} rev_max={rev_max}", file=sys.stderr)
    raise SystemExit(1)
envs = env_map(legal_res)
vertex_ok = (
    envs.get("GOOGLE_GENAI_USE_VERTEXAI") == "TRUE"
    and envs.get("GOOGLE_CLOUD_LOCATION") == "global"
    and envs.get("GOOGLE_CLOUD_PROJECT") == project
    and envs.get("CALLE_ALLOW_DIAL") == "false"
)
if not vertex_ok:
    print("Vertex/kill-switch env mismatch", file=sys.stderr)
    raise SystemExit(1)
allowlist = envs.get("CALLE_ALLOWLIST", "").strip()
allowlist_region = envs.get("CALLE_ALLOWLIST_REGION", "").strip()
if not allowlist:
    print("allowlist env missing", file=sys.stderr)
    raise SystemExit(1)
if len(allowlist_region) != 2 or not allowlist_region.isalpha():
    print("allowlist region missing", file=sys.stderr)
    raise SystemExit(1)
secrets = secret_names(legal_res)
if "gmail-smtp-app-password" not in secrets or "calle-api-key" not in secrets:
    print(f"secret mounts missing: {sorted(secrets)}", file=sys.stderr)
    raise SystemExit(1)
n_aud = audience_count(legal_res)
if n_aud != 3:
    print(f"custom-audience count={n_aud} want 3", file=sys.stderr)
    raise SystemExit(1)

policy = iam_policy(legal)
members: list[str] = []
for binding in policy.get("bindings") or []:
    if binding.get("role") == "roles/run.invoker":
        members.extend(binding.get("members") or [])
if any(m == pub or m.endswith(":" + pub) for m in members):
    print("forbidden public binding present. STOP.", file=sys.stderr)
    raise SystemExit(1)
if "allAuthenticatedUsers" not in members:
    print("missing authenticated-users invoker", file=sys.stderr)
    raise SystemExit(1)

print(f"frozen_rev={frozen_rev}")
print(f"new_rev={(legal_res.get('status') or {}).get('latestReadyRevisionName')}")
print(f"new_sa=call-e-runner")
print(f"scale service={svc_min}/{svc_max} revision={rev_min}/{rev_max}")
print(f"audiences={n_aud}")
print("secrets=gmail+calle")
print("vertex=ok calle_allow_dial=false")
print(f"allowlist_region={allowlist_region}")
print("allowlist=present")
print("invoker=authenticated-users+owner")
print("freeze=ok")
PY

echo "deploy_daftar_call_e: done. Frozen revision still matches snapshot." >&2
echo "Post-deploy: describe BOTH services; frozen latestReadyRevisionName must match ${SNAPSHOT}" >&2
