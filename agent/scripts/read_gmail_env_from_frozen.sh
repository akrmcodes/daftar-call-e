#!/usr/bin/env bash
# Read-only: copy GMAIL_SMTP_USER / GMAIL_SMTP_FROM from the frozen All Things
# Agentic Cloud Run revision into this shell. Never deploys. Never prints
# mailbox addresses.
#
#   source ./scripts/read_gmail_env_from_frozen.sh

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Source this file: source ./scripts/read_gmail_env_from_frozen.sh" >&2
  echo "read-only; will not deploy" >&2
  exit 1
fi

_daftar_gmail_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=refuse_frozen_cloud_run.sh
source "${_daftar_gmail_dir}/refuse_frozen_cloud_run.sh"

export DAFTAR_FREEZE_READ_ONLY=1
export DAFTAR_GMAIL_ENV_SERVICE="daftar-closing-agent"
daftar_refuse_frozen_cloud_run || return 1

_daftar_pair="$(python3 "${_daftar_gmail_dir}/preserve_gmail_env.py")" || return 1
GMAIL_SMTP_USER="$(printf '%s\n' "$_daftar_pair" | sed -n '1p')"
GMAIL_SMTP_FROM="$(printf '%s\n' "$_daftar_pair" | sed -n '2p')"
export GMAIL_SMTP_USER GMAIL_SMTP_FROM
unset _daftar_pair

if [[ -z "${GMAIL_SMTP_USER:-}" || -z "${GMAIL_SMTP_FROM:-}" ]]; then
  echo "Frozen revision is missing GMAIL_SMTP_USER/FROM. Aborting." >&2
  return 1
fi

echo "Copied GMAIL_SMTP_USER/FROM from frozen Cloud Run (values not printed)." >&2
echo "read-only; will not deploy" >&2
unset _daftar_gmail_dir
