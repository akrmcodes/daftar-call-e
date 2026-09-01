"""Cloud Run FastAPI entrypoint — ADK routes plus email send-batch and TTS.

``adk deploy cloud_run`` generates a closed main.py (ADK only). Extra routes
must use ``get_fast_api_app`` then ``include_router``. ``web=False`` so a
root static mount cannot shadow ``/v1/*``.

Auth is Cloud Run IAM + Appendix J.1 custom audiences at the GFE. This module
does not verify JWTs a second time. Shared-secret fallback is unimplemented.
"""

from __future__ import annotations

from pathlib import Path

from google.adk.cli.fast_api import get_fast_api_app

from email_send.router import router as email_router
from email_send.settings import log_smtp_boot_config
from tts.router import router as tts_router

_ROOT = Path(__file__).resolve().parent
_ADK_APPS = _ROOT / "adk_apps"
# Container copies closing_agent → /app/adk_apps/closing_agent so /list-apps
# stays ["closing_agent"] (email_send is a sibling package, not an ADK app).
# Local uvicorn from agent/ uses this folder (closing_agent/ lives here).
AGENTS_DIR = str(_ADK_APPS if (_ADK_APPS / "closing_agent").is_dir() else _ROOT)

app = get_fast_api_app(
    agents_dir=AGENTS_DIR,
    web=False,
)

app.include_router(email_router)
app.include_router(tts_router)


@app.on_event("startup")
def _log_smtp_config() -> None:
    log_smtp_boot_config()
