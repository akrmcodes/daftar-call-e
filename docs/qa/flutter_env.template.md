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
| `CLOSING_AGENT_BASE_URL` | Cloud Run agent base URL | Default in code: `https://daftar-closing-agent-1487285471.us-central1.run.app` |

## Optional dart-defines (demo inboxes)

Not in `.env` — use `--dart-define-from-file` for sample-store email overrides. See [`tool/demo_seed_emails.md`](../../tool/demo_seed_emails.md). Do **not** run live **Confirm & Send Statements** against the deployed service unless you own the To: addresses.

## Gmail SMTP (Cloud Run only)

The Gmail **App Password** lives in Secret Manager `gmail-smtp-app-password` on project `daftar-closing-agent`. It is mounted on Cloud Run at `/secrets/gmail-smtp-app-password`. **Never** add it to Flutter `.env`.

Deploy and env details: [`agent/README.md`](../../agent/README.md).

## Android build note

Gradle reads `GOOGLE_OAUTH_CLIENT_ID_ANDROID` for the AppAuth redirect scheme. A missing key **fails the build** — create `.env` before any Android `flutter run` / APK build. Dart SDK `^3.11.4` · `minSdk` 26.
