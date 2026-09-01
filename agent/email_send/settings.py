"""Non-secret Gmail SMTP env + App Password file (never log the password)."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

DEFAULT_PASSWORD_FILE = "/secrets/gmail-smtp-app-password"
DEFAULT_HOST = "smtp.gmail.com"
DEFAULT_PORT = 587
DEFAULT_STAGGER_SEC = 1.0


@dataclass(frozen=True)
class SmtpSettings:
    user: str
    from_addr: str
    host: str
    port: int
    password_file: str
    stagger_seconds: float

    @classmethod
    def from_env(cls) -> SmtpSettings:
        port_raw = os.environ.get("GMAIL_SMTP_PORT", str(DEFAULT_PORT)).strip()
        try:
            port = int(port_raw)
        except ValueError:
            port = DEFAULT_PORT
        stagger_raw = os.environ.get(
            "GMAIL_SMTP_STAGGER_SEC", str(DEFAULT_STAGGER_SEC)
        ).strip()
        try:
            stagger = float(stagger_raw)
        except ValueError:
            stagger = DEFAULT_STAGGER_SEC
        return cls(
            user=os.environ.get("GMAIL_SMTP_USER", "").strip(),
            from_addr=os.environ.get("GMAIL_SMTP_FROM", "").strip(),
            host=os.environ.get("GMAIL_SMTP_HOST", DEFAULT_HOST).strip() or DEFAULT_HOST,
            port=port,
            password_file=(
                os.environ.get("GMAIL_SMTP_PASSWORD_FILE", DEFAULT_PASSWORD_FILE).strip()
                or DEFAULT_PASSWORD_FILE
            ),
            stagger_seconds=max(0.0, stagger),
        )

    def from_equals_user(self) -> bool:
        return bool(self.user) and self.user == self.from_addr

    def load_password(self) -> str:
        """Read mounted secret file. Caller must ``del`` the return value."""
        path = Path(self.password_file)
        return path.read_text(encoding="utf-8").strip()


def log_smtp_boot_config() -> None:
    """Emit whether From equals user. Never logs mailbox addresses."""
    from closing_agent.observability import emit_structured

    settings = SmtpSettings.from_env()
    ok = settings.from_equals_user()
    emit_structured(
        "daftar.agent.email_config",
        severity="ERROR" if not ok else "INFO",
        message="gmail_sender_ok" if ok else "gmail_sender_misconfigured",
        fromEqualsUser=ok,
    )
