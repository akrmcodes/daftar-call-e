#!/usr/bin/env bash
# Source before `gcloud run deploy` so empty shell vars cannot wipe mailbox env.
# Copies GMAIL_SMTP_USER / GMAIL_SMTP_FROM from DAFTAR_GMAIL_ENV_SERVICE if unset.
# Never prints mailbox addresses. Never deploys daftar-closing-agent.
#
#   export DAFTAR_GMAIL_ENV_SERVICE=daftar-call-e
#   source ./scripts/preserve_gmail_env.sh
#
# To copy mailbox env from the frozen Agentic service (describe only):
#   source ./scripts/read_gmail_env_from_frozen.sh
#
# Revision 00050 (26 Aug 2026) passed GMAIL_SMTP_USER="$GMAIL_SMTP_USER" with an
# empty operator shell and cleared the live keys. send-batch then fail-closed
# as from_user_mismatch. Do not pass those flags when the values are empty.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Source this file: source ./scripts/preserve_gmail_env.sh" >&2
  exit 1
fi

_daftar_preserve_gmail_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=refuse_frozen_cloud_run.sh
source "${_daftar_preserve_gmail_dir}/refuse_frozen_cloud_run.sh"
daftar_refuse_frozen_cloud_run "$@" || return 1

if [[ "${DAFTAR_GMAIL_ENV_SERVICE:-}" == "daftar-closing-agent" && "${DAFTAR_FREEZE_READ_ONLY:-}" != "1" ]]; then
  echo "REFUSE: preserve_gmail_env.sh will not target daftar-closing-agent for a deploy." >&2
  echo "Source read_gmail_env_from_frozen.sh (read-only) or set DAFTAR_GMAIL_ENV_SERVICE=daftar-call-e." >&2
  return 1
fi

if [[ -z "${DAFTAR_GMAIL_ENV_SERVICE:-}" ]]; then
  echo "DAFTAR_GMAIL_ENV_SERVICE is required (no default). Refusing so this cannot silently describe daftar-closing-agent." >&2
  return 1
fi

if [[ -z "${GMAIL_SMTP_USER:-}" || -z "${GMAIL_SMTP_FROM:-}" ]]; then
  _daftar_pair="$(python3 "${_daftar_preserve_gmail_dir}/preserve_gmail_env.py")" || return 1
  GMAIL_SMTP_USER="$(printf '%s\n' "$_daftar_pair" | sed -n '1p')"
  GMAIL_SMTP_FROM="$(printf '%s\n' "$_daftar_pair" | sed -n '2p')"
  export GMAIL_SMTP_USER GMAIL_SMTP_FROM
  unset _daftar_pair
  echo "Copied GMAIL_SMTP_USER/FROM from Cloud Run (values not printed)." >&2
else
  echo "GMAIL_SMTP_USER/FROM already set in shell (values not printed)." >&2
fi

if [[ -z "${GMAIL_SMTP_USER:-}" || -z "${GMAIL_SMTP_FROM:-}" ]]; then
  echo "GMAIL_SMTP_USER and GMAIL_SMTP_FROM are required. Aborting so an empty shell cannot wipe Cloud Run mailbox env." >&2
  return 1
fi

if [[ "${GMAIL_SMTP_USER}" != "${GMAIL_SMTP_FROM}" ]]; then
  echo "GMAIL_SMTP_USER must equal GMAIL_SMTP_FROM. Aborting." >&2
  return 1
fi

unset _daftar_preserve_gmail_dir
