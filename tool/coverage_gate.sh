#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MIN_DOMAIN="${MIN_DOMAIN:-80}"
MIN_APPLICATION="${MIN_APPLICATION:-80}"

flutter test test/domain test/application test/core test/data test/presentation --coverage

python3 << PY
from pathlib import Path
import sys

min_domain = float("${MIN_DOMAIN}")
min_application = float("${MIN_APPLICATION}")

records = []
current_file = None
lf = lh = 0
for line in Path("coverage/lcov.info").read_text().splitlines():
    if line.startswith("SF:"):
        if current_file is not None:
            records.append((current_file, lf, lh))
        current_file = line[3:]
        lf = lh = 0
    elif line == "end_of_record":
        if current_file is not None:
            records.append((current_file, lf, lh))
        current_file = None
        lf = lh = 0
    elif line.startswith("LF:"):
        lf = int(line[3:])
    elif line.startswith("LH:"):
        lh = int(line[3:])

def layer_stats(prefix: str):
    files = [
        (f, lf, lh)
        for f, lf, lh in records
        if f.startswith(f"lib/{prefix}/")
        and not f.endswith(".freezed.dart")
        and not f.endswith(".g.dart")
    ]
    total_lf = sum(lf for _, lf, _ in files)
    total_lh = sum(lh for _, _, lh in files)
    pct = (100.0 * total_lh / total_lf) if total_lf else 0.0
    return pct, total_lh, total_lf, len(files)

domain_pct, domain_lh, domain_lf, domain_files = layer_stats("domain")
app_pct, app_lh, app_lf, app_files = layer_stats("application")

print(f"Domain:      {domain_pct:.2f}% ({domain_lh}/{domain_lf} lines, {domain_files} files)")
print(f"Application: {app_pct:.2f}% ({app_lh}/{app_lf} lines, {app_files} files)")

failed = False
if domain_pct < min_domain:
    print(f"FAIL: Domain coverage {domain_pct:.2f}% < {min_domain}%", file=sys.stderr)
    failed = True
if app_pct < min_application:
    print(f"FAIL: Application coverage {app_pct:.2f}% < {min_application}%", file=sys.stderr)
    failed = True

if failed:
    sys.exit(1)

print("PASS: Domain and Application layers meet coverage gate.")
PY
