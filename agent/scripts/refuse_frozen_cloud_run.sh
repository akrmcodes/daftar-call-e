# Shared freeze checks for daftar-call-e. Source only — do not execute.
#
#   source "$(dirname "$0")/refuse_frozen_cloud_run.sh"
#   daftar_refuse_frozen_cloud_run "$@"
#
# Aborts (return 1) if this is the wrong repo or the command would mutate the
# All Things Agentic Cloud Run service.
#
# Set DAFTAR_FREEZE_READ_ONLY=1 for describe-only scripts so a leftover
# CLOSING_AGENT_BASE_URL in the operator shell does not block a freeze check.

_DAFTAR_FROZEN_SERVICE="daftar-closing-agent"
_DAFTAR_FROZEN_HOST="daftar-closing-agent-1487285471"

daftar_freeze_repo_root() {
  local here dir
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  dir="$here"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.git" && -d "$dir/agent" && -f "$dir/docs/roadmap_v3.md" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

daftar_refuse_frozen_cloud_run() {
  local root origin blob a
  root="$(daftar_freeze_repo_root)" || {
    echo "REFUSE frozen Cloud Run: cannot find daftar-call-e repo root" >&2
    return 1
  }
  case "$root" in
    */daftar-call-e) ;;
    *)
      echo "REFUSE frozen Cloud Run: repo root is not daftar-call-e ($root)" >&2
      return 1
      ;;
  esac

  origin="$(git -C "$root" remote get-url origin 2>/dev/null || true)"
  if [[ "$origin" != *daftar-call-e* ]]; then
    echo "REFUSE frozen Cloud Run: origin must contain daftar-call-e (got: $origin)" >&2
    return 1
  fi
  if [[ "$origin" == *daftar-closing-agent.git* ]]; then
    echo "REFUSE frozen Cloud Run: origin path is the Agentic repo ($origin)" >&2
    return 1
  fi

  blob="$* ${CLOUD_RUN_SERVICE:-} ${SERVICE:-} ${K_SERVICE:-}"
  if [[ "${DAFTAR_FREEZE_READ_ONLY:-}" != "1" ]]; then
    blob="$blob ${CLOSING_AGENT_BASE_URL:-}"
  fi

  if [[ "$blob" == *adk*deploy* ]] || [[ " $* " == *" adk "* ]]; then
    echo "REFUSE frozen Cloud Run: never adk deploy" >&2
    return 1
  fi
  if [[ "$blob" == *"$_DAFTAR_FROZEN_HOST"* ]]; then
    echo "REFUSE frozen Cloud Run: frozen hostname daftar-closing-agent-1487285471 is not a deploy target" >&2
    return 1
  fi

  for a in "$@"; do
    case "$a" in
      "$_DAFTAR_FROZEN_SERVICE"|--service="$_DAFTAR_FROZEN_SERVICE"|--service_name="$_DAFTAR_FROZEN_SERVICE")
        echo "REFUSE frozen Cloud Run: service name daftar-closing-agent is forbidden" >&2
        return 1
        ;;
    esac
  done

  if [[ "${DAFTAR_FREEZE_READ_ONLY:-}" != "1" ]]; then
    if [[ "${CLOUD_RUN_SERVICE:-}" == "$_DAFTAR_FROZEN_SERVICE" || "${SERVICE:-}" == "$_DAFTAR_FROZEN_SERVICE" ]]; then
      echo "REFUSE frozen Cloud Run: SERVICE/CLOUD_RUN_SERVICE is daftar-closing-agent" >&2
      return 1
    fi
  fi

  return 0
}
