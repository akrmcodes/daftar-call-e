#!/usr/bin/env bash
# Stage 8.4–8.6 two-phone Android QA — Mac preflight checks.
# Run from repo root: ./tool/qa_preflight.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; }

echo "=== Daftar Stage 8 QA preflight ==="
echo "Repo: $ROOT"
echo

# 1. LAN IP vs .env
LAN_IP=""
for iface in en0 en1; do
  ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
  if [[ -n "$ip" ]]; then
    LAN_IP="$ip"
    break
  fi
done

if [[ -z "$LAN_IP" ]]; then
  warn "Could not detect LAN IP (en0/en1). Connect Wi‑Fi and re-run."
else
  pass "Detected LAN IP: $LAN_IP"
fi

if [[ ! -f .env ]]; then
  fail "Missing .env at repo root. Copy .env.example and fill values."
  exit 1
fi

activation_url="$(grep -E '^ACTIVATION_API_BASE_URL=' .env | tail -1 | cut -d= -f2- || true)"
if [[ "$activation_url" == *127.0.0.1* ]]; then
  warn ".env ACTIVATION_API_BASE_URL uses 127.0.0.1 — physical phones cannot reach this. Use LAN IP."
elif [[ -n "$LAN_IP" && -n "$activation_url" && "$activation_url" != *"$LAN_IP"* ]]; then
  warn ".env ACTIVATION_API_BASE_URL does not contain $LAN_IP"
else
  pass ".env ACTIVATION_API_BASE_URL looks LAN-ready"
fi

for key in SUPABASE_PUBLISHABLE_KEY ACTIVATION_API_BASE_URL GOOGLE_SERVER_CLIENT_ID; do
  if grep -q "^${key}=" .env && ! grep -q "^${key}=$" .env && ! grep -q "^${key}=<" .env; then
    pass ".env has $key"
  else
    fail ".env missing or placeholder: $key"
  fi
done

# 2. env.g.dart freshness
if [[ .env -nt lib/core/env/env.g.dart ]]; then
  warn "lib/core/env/env.g.dart is older than .env — run build_runner"
else
  pass "env.g.dart is up to date with .env"
fi

# 3. Supabase JWT secret in config.toml
if grep -A2 '\[edge_runtime.secrets\]' supabase/config.toml | grep -q 'JWT_SECRET'; then
  pass "supabase/config.toml defines edge_runtime.secrets.JWT_SECRET"
else
  fail "Missing [edge_runtime.secrets] JWT_SECRET in supabase/config.toml"
fi

if [[ -f supabase/functions/.env ]] && grep -q '^JWT_SECRET=' supabase/functions/.env; then
  pass "supabase/functions/.env has JWT_SECRET"
else
  warn "supabase/functions/.env missing JWT_SECRET"
fi

# 4. Supabase stack
if command -v supabase >/dev/null 2>&1; then
  if supabase status >/dev/null 2>&1; then
    pass "Supabase local stack is running"
    echo
    supabase status 2>/dev/null | sed -n '1,20p' || true
    echo
    warn "Recommended before QA: supabase db reset (clean workspaces/tokens)"
  else
    warn "Supabase not running — run: supabase start && supabase db reset"
  fi
else
  warn "supabase CLI not found in PATH"
fi

# 5. Migrations present
for mig in \
  20260802180000_stage_8_4_sync_engine.sql \
  20260803170000_fix_provision_workspace_ambiguity.sql \
  20260804120000_grant_service_role_sync_tables.sql \
  20260804140000_stage_8_5_deep_link_attribution.sql
do
  if [[ -f "supabase/migrations/$mig" ]]; then
    pass "migration $mig"
  else
    fail "missing migration $mig"
  fi
done

# 6. Flutter / codegen
if command -v flutter >/dev/null 2>&1; then
  pass "flutter $(flutter --version 2>/dev/null | head -1)"
else
  warn "flutter not in PATH"
fi

echo
echo "=== Suggested next commands ==="
cat <<EOF
cd $ROOT
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter pub get
supabase db reset   # if stack is up and you want a clean slate
flutter devices
docker logs -f supabase_edge_runtime_daftar 2>&1   # edge logs in another terminal

Pro+ offline code for Phone A:
dart run tool/generate_offline_activation_code.dart proplus

QA runbook:
docs/archive/stage_8_5_8_6_android_two_phone.md
EOF
