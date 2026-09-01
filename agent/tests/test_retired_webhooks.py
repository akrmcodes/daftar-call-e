"""§4.12 lock — WhatsApp webhooks stay retired. No live deploy."""

from __future__ import annotations

from pathlib import Path

import yaml

from email_send.router import router

_AGENT_ROOT = Path(__file__).resolve().parents[1]
_FORBIDDEN = (
    "daftar.agent.whatsapp.status",
    "daftar-wa-webhooks",
    "/v1/whatsapp",
)


def test_email_router_has_no_webhook_or_whatsapp_path() -> None:
    paths = [str(getattr(route, "path", "")) for route in router.routes]
    assert paths
    for path in paths:
        lowered = path.lower()
        assert "webhook" not in lowered
        assert "whatsapp" not in lowered


def test_openapi_has_no_webhook_or_whatsapp_path() -> None:
    spec = yaml.safe_load((_AGENT_ROOT / "openapi.yaml").read_text(encoding="utf-8"))
    paths = spec.get("paths") or {}
    assert "/v1/email/send-batch" in paths
    assert "/v1/tts" in paths
    for path in paths:
        lowered = str(path).lower()
        assert "webhook" not in lowered
        assert "whatsapp" not in lowered


def test_agent_source_has_no_webhook_status_events() -> None:
    roots = (
        _AGENT_ROOT / "email_send",
        _AGENT_ROOT / "closing_agent",
        _AGENT_ROOT / "tts",
    )
    hits: list[str] = []
    for root in roots:
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            if path.suffix not in {".py", ".yaml", ".yml"}:
                continue
            text = path.read_text(encoding="utf-8")
            for needle in _FORBIDDEN:
                if needle in text:
                    hits.append(f"{path.relative_to(_AGENT_ROOT)}: {needle}")
    assert hits == []
