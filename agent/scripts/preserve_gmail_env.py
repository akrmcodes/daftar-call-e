#!/usr/bin/env python3
"""Print GMAIL_SMTP_USER then GMAIL_SMTP_FROM (two lines) from a Cloud Run service.

Used by preserve_gmail_env.sh and read_gmail_env_from_frozen.sh.
Never writes mailbox addresses to stderr.

DAFTAR_GMAIL_ENV_SERVICE is required (no default). Describing the frozen
All Things Agentic service is allowed only with DAFTAR_FREEZE_READ_ONLY=1.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys

PROJECT = "daftar-closing-agent"
REGION = "us-central1"
FROZEN_SERVICE = "daftar-closing-agent"


def _env_map(resource: dict) -> dict[str, str]:
    spec = resource.get("spec") or {}
    template = spec.get("template") or {}
    inner = template.get("spec") or spec
    containers = inner.get("containers") or []
    env: dict[str, str] = {}
    if not containers:
        return env
    for item in containers[0].get("env") or []:
        if "value" in item:
            env[str(item["name"])] = str(item.get("value") or "")
    return env


def main() -> int:
    service = os.environ.get("DAFTAR_GMAIL_ENV_SERVICE", "").strip()
    if not service:
        print(
            "DAFTAR_GMAIL_ENV_SERVICE is required. "
            "For CALL-E deploy set it to daftar-call-e. "
            "To copy mailbox env from the frozen Agentic service, source "
            "read_gmail_env_from_frozen.sh (read-only).",
            file=sys.stderr,
        )
        return 1
    if service == FROZEN_SERVICE and os.environ.get("DAFTAR_FREEZE_READ_ONLY") != "1":
        print(
            "REFUSE: describing daftar-closing-agent for a deploy is forbidden. "
            "Source read_gmail_env_from_frozen.sh (read-only) or set "
            "DAFTAR_GMAIL_ENV_SERVICE=daftar-call-e.",
            file=sys.stderr,
        )
        return 1

    raw = subprocess.check_output(
        [
            "gcloud",
            "run",
            "services",
            "describe",
            service,
            "--project",
            PROJECT,
            "--region",
            REGION,
            "--format=json",
        ],
        text=True,
    )
    env = _env_map(json.loads(raw))
    user = env.get("GMAIL_SMTP_USER", "").strip()
    from_addr = env.get("GMAIL_SMTP_FROM", "").strip()
    if not user or not from_addr:
        print(
            "Cloud Run is missing GMAIL_SMTP_USER/FROM. "
            "Set them in the shell from a known-good revision, then deploy. "
            "Do not pass empty GMAIL_SMTP_USER= (that wiped send-batch on 00050).",
            file=sys.stderr,
        )
        return 1
    if user != from_addr:
        print(
            "GMAIL_SMTP_USER does not equal GMAIL_SMTP_FROM. Aborting.",
            file=sys.stderr,
        )
        return 1
    print(user)
    print(from_addr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
