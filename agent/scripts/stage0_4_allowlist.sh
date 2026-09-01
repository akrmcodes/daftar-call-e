#!/usr/bin/env bash
# Stage 0.4: kill switch + E.164 allowlist files in $HOME/.daftar-owner-ops/
# Does not mutate Cloud Run. Does not print E.164. Does not dial.
#
# Usage:
#   bash agent/scripts/stage0_4_allowlist.sh

set -euo pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=refuse_frozen_cloud_run.sh
source "${_script_dir}/refuse_frozen_cloud_run.sh"

export DAFTAR_FREEZE_READ_ONLY=1
daftar_refuse_frozen_cloud_run "$@" || exit 1

OPS_DIR="${HOME}/.daftar-owner-ops"
DID_FILE="${OPS_DIR}/test-did"
DIAL_FILE="${OPS_DIR}/calle-allow-dial"
LIST_FILE="${OPS_DIR}/calle-allowlist"
REGION_FILE="${OPS_DIR}/calle-allowlist-region"

echo "stage0_4_allowlist: preflight"

if [[ ! -d "${OPS_DIR}" ]]; then
  echo "stage0_4_allowlist: missing ${OPS_DIR}" >&2
  exit 1
fi

python3 - "${DID_FILE}" "${DIAL_FILE}" "${LIST_FILE}" "${REGION_FILE}" "${OPS_DIR}" <<'PY'
import os
import shutil
import stat
import sys

did_path, dial_path, list_path, region_path, ops_dir = sys.argv[1:]

dir_mode = stat.S_IMODE(os.stat(ops_dir).st_mode)
if dir_mode & 0o077:
    os.chmod(ops_dir, 0o700)

if not os.path.isfile(did_path):
    print("stage0_4_allowlist: missing test-did", file=sys.stderr)
    sys.exit(1)

st = os.stat(did_path)
mode = stat.S_IMODE(st.st_mode)
if mode & 0o077:
    print(f"stage0_4_allowlist: test-did mode {oct(mode)} is group/world readable", file=sys.stderr)
    sys.exit(1)

raw = open(did_path, "rb").read().decode("utf-8")
text = raw.strip()
if "\n" in text or "," in text:
    print("stage0_4_allowlist: test-did must be a single E.164", file=sys.stderr)
    sys.exit(1)
if not (text.startswith("+1") and text[1:].isdigit() and len(text) == 12):
    print("stage0_4_allowlist: test-did is not a US E.164 of expected length", file=sys.stderr)
    sys.exit(1)

os.umask(0o077)

with open(dial_path, "w", encoding="utf-8") as f:
    f.write("false")
os.chmod(dial_path, 0o600)

shutil.copyfile(did_path, list_path)
# copyfile preserves mode on some systems; force 600 and strip newline if any
with open(list_path, "wb") as f:
    f.write(text.encode("utf-8"))
os.chmod(list_path, 0o600)

with open(region_path, "w", encoding="utf-8") as f:
    f.write("US")
os.chmod(region_path, 0o600)

# Re-read without printing the number
check = open(list_path, "rb").read().decode("utf-8")
if check != text:
    print("stage0_4_allowlist: allowlist copy mismatch", file=sys.stderr)
    sys.exit(1)
region = open(region_path, encoding="utf-8").read()
dial = open(dial_path, encoding="utf-8").read()
if dial != "false":
    print("stage0_4_allowlist: kill switch file must be false", file=sys.stderr)
    sys.exit(1)
if region != "US":
    print("stage0_4_allowlist: region file must be US", file=sys.stderr)
    sys.exit(1)

print("stage0_4_allowlist: wrote calle-allow-dial=false, calle-allowlist (hidden), calle-allowlist-region=US")
print(f"stage0_4_allowlist: files mode 600; ops dir mode {oct(stat.S_IMODE(os.stat(ops_dir).st_mode))}")
PY

echo "stage0_4_allowlist: default remains off. Gate 0 smoke may export true in that shell only."
echo "stage0_4_allowlist: done"
exit 0
