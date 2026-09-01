#!/usr/bin/env bash
# Stage 0.3: Secret Manager calle-api-key + call-e-runner IAM.
# Same contest GCP project. Does not mutate Cloud Run.
#
# Legal later runtime name: daftar-call-e (Stage 1 only).
# Frozen All Things Agentic service is describe-only.
#
# Never: payload print, stdin secret, project-wide secretAccessor on
# call-e-runner, Cloud Run mutate, API activation.
#
# Usage (repo root or agent/):
#   bash agent/scripts/stage0_3_gcp.sh

set -euo pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=refuse_frozen_cloud_run.sh
source "${_script_dir}/refuse_frozen_cloud_run.sh"

export DAFTAR_FREEZE_READ_ONLY=1
daftar_refuse_frozen_cloud_run "$@" || exit 1

PROJECT="daftar-closing-agent"
REGION="us-central1"
ACCOUNT_EXPECT="akrm.codes@gmail.com"
FROZEN_SERVICE="daftar-closing-agent"
LEGAL_SERVICE="daftar-call-e"
SNAP_REV="daftar-closing-agent-00055-pbm"
RUNNER_SA="call-e-runner@${PROJECT}.iam.gserviceaccount.com"
AGENT_SA="agent-runner@${PROJECT}.iam.gserviceaccount.com"
CALLE_SECRET="calle-api-key"
GMAIL_SECRET="gmail-smtp-app-password"
KEY_FILE="${HOME}/.daftar-owner-ops/calle-api-key"
MEMBER="serviceAccount:${RUNNER_SA}"
ROLE_SECRET="roles/secretmanager.secretAccessor"

repo_root="$(daftar_freeze_repo_root)" || exit 1
CHECK_FREEZE="${repo_root}/tool/check_agentic_freeze.sh"

daftar_iam_add() {
  local out rc
  set +e
  out="$("$@" 2>&1)"
  rc=$?
  set -e
  if [[ "${rc}" -eq 0 ]]; then
    echo "IAM granted."
    return 0
  fi
  if [[ "${out}" == *"already exists"* ]]; then
    echo "IAM already present (ok)."
    return 0
  fi
  printf '%s\n' "${out}" >&2
  return "${rc}"
}

echo "stage0_3_gcp: preflight"

account="$(gcloud config get-value account 2>/dev/null || true)"
if [[ "${account}" != "${ACCOUNT_EXPECT}" ]]; then
  echo "stage0_3_gcp: gcloud account must be ${ACCOUNT_EXPECT} (got: ${account})" >&2
  exit 1
fi

cfg_project="$(gcloud config get-value project 2>/dev/null || true)"
if [[ "${cfg_project}" != "${PROJECT}" ]]; then
  echo "stage0_3_gcp: gcloud project must be ${PROJECT} (got: ${cfg_project})" >&2
  exit 1
fi

if [[ ! -x "${CHECK_FREEZE}" && ! -f "${CHECK_FREEZE}" ]]; then
  echo "stage0_3_gcp: missing ${CHECK_FREEZE}" >&2
  exit 1
fi
bash "${CHECK_FREEZE}" || exit 1

if [[ ! -f "${KEY_FILE}" ]]; then
  echo "stage0_3_gcp: missing key file (path not printed beyond owner-ops name)" >&2
  exit 1
fi

python3 - "${KEY_FILE}" <<'PY'
import os
import stat
import sys

path = sys.argv[1]
st = os.stat(path)
mode = stat.S_IMODE(st.st_mode)
if mode & 0o077:
    print(f"stage0_3_gcp: key file mode {oct(mode)} is group/world readable", file=sys.stderr)
    sys.exit(1)
if st.st_size < 8:
    print("stage0_3_gcp: key file empty or too small", file=sys.stderr)
    sys.exit(1)
data = open(path, "rb").read()
text = data.decode("utf-8", errors="replace")
if "PASTE_KEY_HERE" in text or "XXXXXXXXXX" in text:
    print("stage0_3_gcp: key file looks like a placeholder", file=sys.stderr)
    sys.exit(1)
print(f"key file ok: bytes={st.st_size} mode={oct(mode)}")
PY

if ! gcloud iam service-accounts describe "${RUNNER_SA}" \
  --project="${PROJECT}" \
  --format='value(email)' >/dev/null; then
  echo "stage0_3_gcp: missing runtime SA ${RUNNER_SA}" >&2
  exit 1
fi

if gcloud run services describe "${LEGAL_SERVICE}" \
  --project="${PROJECT}" \
  --region="${REGION}" \
  --format='value(metadata.name)' >/dev/null 2>&1; then
  echo "stage0_3_gcp: ${LEGAL_SERVICE} already exists — Secret Manager/IAM only; no Cloud Run mutate."
else
  echo "stage0_3_gcp: ${LEGAL_SERVICE} absent (expected until Stage 1)."
fi

echo "stage0_3_gcp: Secret Manager ${CALLE_SECRET}"

if gcloud secrets describe "${CALLE_SECRET}" --project="${PROJECT}" \
  --format='value(name)' >/dev/null 2>&1; then
  echo "stage0_3_gcp: secret exists — adding a version from the local file"
  gcloud secrets versions add "${CALLE_SECRET}" \
    --project="${PROJECT}" \
    --data-file="${KEY_FILE}"
else
  gcloud secrets create "${CALLE_SECRET}" \
    --project="${PROJECT}" \
    --replication-policy=automatic \
    --data-file="${KEY_FILE}"
fi

gcloud secrets describe "${CALLE_SECRET}" --project="${PROJECT}" \
  --format='value(name)' >/dev/null
echo "stage0_3_gcp: secret present (payload not printed)"

echo "stage0_3_gcp: secret-level IAM for call-e-runner"

daftar_iam_add gcloud secrets add-iam-policy-binding "${CALLE_SECRET}" \
  --project="${PROJECT}" \
  --member="${MEMBER}" \
  --role="${ROLE_SECRET}" \
  --quiet

daftar_iam_add gcloud secrets add-iam-policy-binding "${GMAIL_SECRET}" \
  --project="${PROJECT}" \
  --member="${MEMBER}" \
  --role="${ROLE_SECRET}" \
  --quiet

echo "stage0_3_gcp: project IAM for call-e-runner (not project-wide secretAccessor)"

daftar_iam_add gcloud projects add-iam-policy-binding "${PROJECT}" \
  --member="${MEMBER}" \
  --role="roles/aiplatform.user" \
  --quiet

daftar_iam_add gcloud projects add-iam-policy-binding "${PROJECT}" \
  --member="${MEMBER}" \
  --role="roles/logging.logWriter" \
  --quiet

daftar_iam_add gcloud projects add-iam-policy-binding "${PROJECT}" \
  --member="${MEMBER}" \
  --role="roles/speech.client" \
  --quiet

echo "stage0_3_gcp: post-flight frozen describe"

post="$(
  gcloud run services describe "${FROZEN_SERVICE}" \
    --project="${PROJECT}" \
    --region="${REGION}" \
    --format=json | python3 -c '
import json, sys
d = json.load(sys.stdin)
tpl = d["spec"]["template"]["spec"]
c = tpl["containers"][0]
rev = d["status"].get("latestReadyRevisionName", "")
sa = tpl.get("serviceAccountName", "")
envs = {e.get("name"): e.get("value", "") for e in (c.get("env") or [])}
secrets = sorted({
    (v.get("secret") or {}).get("secretName", "")
    for v in (tpl.get("volumes") or [])
    if (v.get("secret") or {}).get("secretName")
})
google_ok = (
    envs.get("GOOGLE_GENAI_USE_VERTEXAI") == "TRUE"
    and envs.get("GOOGLE_CLOUD_LOCATION") == "global"
    and envs.get("GOOGLE_CLOUD_PROJECT") == "daftar-closing-agent"
)
print(rev)
print(sa)
print("gmail" if "gmail-smtp-app-password" in secrets else "NO_GMAIL_VOLUME")
print("vertex_ok" if google_ok else "VERTEX_DRIFT")
'
)"

rev="$(printf '%s\n' "${post}" | sed -n '1p')"
sa="$(printf '%s\n' "${post}" | sed -n '2p')"
gmail_vol="$(printf '%s\n' "${post}" | sed -n '3p')"
vertex="$(printf '%s\n' "${post}" | sed -n '4p')"

ok=1
if [[ "${rev}" != "${SNAP_REV}" ]]; then
  echo "FREEZE BREACH: frozen revision is ${rev}, expected ${SNAP_REV}. STOP." >&2
  ok=0
fi
if [[ "${sa}" != "${AGENT_SA}" ]]; then
  echo "FREEZE BREACH: frozen runtime SA is ${sa}. STOP." >&2
  ok=0
fi
if [[ "${gmail_vol}" != "gmail" ]]; then
  echo "FREEZE BREACH: frozen Gmail secret volume missing. STOP." >&2
  ok=0
fi
if [[ "${vertex}" != "vertex_ok" ]]; then
  echo "FREEZE BREACH: Vertex env drifted on frozen revision. STOP." >&2
  ok=0
fi

if ! gcloud secrets get-iam-policy "${GMAIL_SECRET}" \
  --project="${PROJECT}" --format=json | python3 -c '
import json, sys
p = json.load(sys.stdin)
want_agent = "serviceAccount:agent-runner@daftar-closing-agent.iam.gserviceaccount.com"
want_call = "serviceAccount:call-e-runner@daftar-closing-agent.iam.gserviceaccount.com"
members = set()
for b in p.get("bindings") or []:
    if b.get("role") == "roles/secretmanager.secretAccessor":
        members.update(b.get("members") or [])
missing = [m for m in (want_agent, want_call) if m not in members]
if missing:
    print("missing", ",".join(missing), file=sys.stderr)
    sys.exit(1)
'; then
  echo "stage0_3_gcp: gmail secret IAM check failed (agent-runner must remain)." >&2
  ok=0
fi

if ! gcloud secrets get-iam-policy "${CALLE_SECRET}" \
  --project="${PROJECT}" --format=json | python3 -c '
import json, sys
p = json.load(sys.stdin)
want = "serviceAccount:call-e-runner@daftar-closing-agent.iam.gserviceaccount.com"
members = set()
for b in p.get("bindings") or []:
    if b.get("role") == "roles/secretmanager.secretAccessor":
        members.update(b.get("members") or [])
if want not in members:
    print("call-e-runner missing on calle-api-key", file=sys.stderr)
    sys.exit(1)
'; then
  echo "stage0_3_gcp: calle-api-key IAM check failed." >&2
  ok=0
fi

if [[ "${ok}" -ne 1 ]]; then
  echo "stage0_3_gcp: post-flight failed. Do not mutate Cloud Run to compensate." >&2
  exit 1
fi

echo "stage0_3_gcp: freeze still ${SNAP_REV}; Vertex unchanged; Gmail volume intact."
echo "stage0_3_gcp: calle-api-key stored; call-e-runner has secretAccessor on both secrets."
echo "stage0_3_gcp: Stage 1 will file-mount on ${LEGAL_SERVICE} only. Done."
exit 0
