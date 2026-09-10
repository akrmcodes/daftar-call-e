# Flutter `.env` template (judges / collaborators)

Copy these keys into a **gitignored** `.env` file at the repository root. **Never commit** `.env` or paste live values in issues, Devpost, or video.

There is **no** `.env.example` in git (`.gitignore` matches `.env.*`). This markdown table is the key list.

**Order** (codegen needs packages first):

```bash
flutter pub get
# create repo-root .env from the table below
dart run build_runner build --delete-conflicting-outputs
```

Generated `*.g.dart` is gitignored. `BACKUP_AES_KEY` and `GOOGLE_SERVER_CLIENT_ID` have **no** Envied defaults — a clone does not compile without `.env`.

## Required keys

| Key | Purpose | Notes |
| --- | --- | --- |
| `BACKUP_AES_KEY` | AES-256 backup encryption (Base64, 32 bytes decoded) | From secure vault — loss bricks V1 backups |
| `GOOGLE_SERVER_CLIENT_ID` | Web OAuth client ID (`serverClientId` for Sign-In + Drive scopes) | **Web application** type in Google Cloud Console |
| `GOOGLE_OAUTH_CLIENT_ID_ANDROID` | Android installed-app client ID | Required for Android builds (PKCE + Cloud Run custom audience) |
| `GOOGLE_OAUTH_CLIENT_ID_IOS` | iOS client ID | Required for iOS builds |
| `ACTIVATION_API_BASE_URL` | Supabase Edge Functions base | Contest path may not exercise activation |
| `SUPABASE_PUBLISHABLE_KEY` | Supabase `apikey` header | Client-safe with RLS |
| `DEEP_LINK_BASE_URL` | Minted invite URL base | Default `https://daftar.app/i` |
| `CLOSING_AGENT_BASE_URL` | Cloud Run agent base URL | **Required.** Empty Envied default. Use the `daftar-call-e` URL from `$HOME/.daftar-owner-ops/daftar-call-e-url`. Never the frozen Agentic hostname. |

## Optional dart-defines (demo overlay)

Not in `.env` — use `--dart-define-from-file=tool/demo_seed_emails.local.json` for sample-store overrides. See [`tool/demo_seed_emails.md`](../../tool/demo_seed_emails.md).

| Key | Purpose | Notes |
| --- | --- | --- |
| `DAFTAR_SEED_EMAIL_demo1` … `demo7` | SMTP To: for the seven overdue contacts | Committed defaults are owner plus-aliases |
| `DAFTAR_SEED_US_DID` | Mohamed's phone (call-eligible US DID) | **Not Envied.** Gitignored local JSON only. Empty = Yemen placeholder for Mohamed |
| `CALLE_ALLOW_DIAL` | Device kill switch for PSTN | Exact `true` only. Keep empty through Stage 3.1. **Not Envied.** |
| `CALLE_ALLOWLIST` | Device E.164 allowlist (comma-separated) | **Not Envied.** Must include the seed DID or Mohamed stays email-only |
| `CALLE_ALLOWLIST_REGION` | NANP declared ISO for `+1` numbers | Default `US` when empty |

Do **not** run live **Confirm & Send Statements** or **Confirm & Call** unless you own the To: addresses and DID. `CALLE_API_KEY` is **never** a Flutter dart-define.

## Gmail SMTP (Cloud Run only)

The Gmail **App Password** lives in Secret Manager `gmail-smtp-app-password` on project `daftar-closing-agent`. It is mounted on Cloud Run at `/secrets/gmail-smtp-app-password`. **Never** add it to Flutter `.env`.

## CALL-E device policy (dart-define — not `.env`)

`CALLE_ALLOW_DIAL`, `CALLE_ALLOWLIST`, and `CALLE_ALLOWLIST_REGION` may be set in the gitignored `tool/demo_seed_emails.local.json` overlay for **device** defense in depth. Parse rules match Cloud Run ([`agent/calls/settings.py`](../../agent/calls/settings.py)). Settings **Allow CALL-E outbound** GlowPill persists merchant intent in Drift; effective dial also requires compile-time `CALLE_ALLOW_DIAL=true` and Cloud Run.

`CALLE_API_KEY` / Secret Manager `calle-api-key` is **not** an Envied key and **never** belongs in Flutter dart-defines. Laptop Gate 0 smoke uses a shell export; production mounts the API key on **`daftar-call-e`**. Owner-ops (no values): [`docs/contest/CALLE_STAGE0_OWNER_OPS.md`](../contest/CALLE_STAGE0_OWNER_OPS.md) §0.4.

Deploy and env details: [`agent/README.md`](../../agent/README.md).

## Android build note

Gradle reads `GOOGLE_OAUTH_CLIENT_ID_ANDROID` for the AppAuth redirect scheme. A missing key **fails the build** — create `.env` before any Android `flutter run` / APK build. Dart SDK `^3.11.4` · `minSdk` 26.
