# Deep-Link Hosting (Stage 8.5)

Static files for Android App Links, iOS Universal Links, and the
**mandatory landing page** (Decision 2A) that logs clicks and redirects to
the Play Store with Install Referrer payload.

## Deploy

Serve at the apex of `DEEP_LINK_HOST` (default `daftar.app`):

| Path | Content-Type | Notes |
|------|----------------|-------|
| `/.well-known/assetlinks.json` | `application/json` | Android App Links |
| `/.well-known/apple-app-site-association` | `application/json` | iOS Universal Links (no `.json` extension) |
| `/i/index.html` | `text/html` | Landing page for deferred install |
| `/i/*` | rewrite → `/i/index.html` | Token extracted from path by client JS |

### CDN / nginx rewrite (required)

```nginx
location ~ ^/i/ {
  try_files /i/index.html =404;
}
```

AASA must be served **without** redirects and with HTTPS.

## Landing page configuration

Before production deploy, edit [`i/index.html`](i/index.html) `CONFIG`:

| Key | Example | Source |
|-----|---------|--------|
| `functionsBaseUrl` | `https://<project>.supabase.co/functions/v1` | Supabase project settings |
| `publishableKey` | `eyJ…` | Supabase publishable (anon) key |
| `playPackageId` | `com.akrmcodes.daftar` | Android `applicationId` |
| `appStoreUrl` | `https://apps.apple.com/app/daftar/id…` | App Store Connect |

### Android Install Referrer (Decision 1A)

The landing page redirects Android users to:

```
https://play.google.com/store/apps/details
  ?id=com.akrmcodes.daftar
  &referrer=utm_source%3Ddaftar%26utm_medium%3Ddeep_link%26utm_content%3D{TOKEN}
```

The app reads `utm_content` on first launch via the Play Install Referrer API.

### iOS (Decision 1A — fallback only)

iOS redirects to the App Store listing. Deferred attribution uses clipboard
paste or manual code entry in the app — **no probabilistic match**.

## Placeholders to replace before production

| Placeholder | Source |
|-------------|--------|
| `REPLACE_WITH_ANDROID_SHA256_FINGERPRINT` | `keytool -list -v -keystore <upload-or-play>.jks` → SHA-256 |
| `REPLACE_WITH_APPLE_TEAM_ID` | Apple Developer → Membership → Team ID |
| `REPLACE_WITH_SUPABASE_FUNCTIONS_URL` | Supabase → Edge Functions base URL |
| `REPLACE_WITH_SUPABASE_PUBLISHABLE_KEY` | Supabase → API → publishable key |

## Environment variables

| Variable | Example | Used by |
|----------|---------|---------|
| `DEEP_LINK_BASE_URL` | `https://daftar.app/i` | Edge mint (`invite-worker`, `create-deep-link`) + Flutter `Env` |
| `DEEP_LINK_HOST` | `daftar.app` | CDN / static host + Android/iOS associated domain |
| `ANDROID_SHA256_FINGERPRINT` | `AB:CD:…` | Paste into `assetlinks.json` at deploy |
| `APPLE_TEAM_ID` | `ABCDE12345` | Paste into AASA `appID` at deploy |

## Local / LAN testing

App Links verification requires the real host. For LAN development, open
`https://daftar.app/i/<token>` on a device with the app installed after DNS
points at production, or paste the token into the Expired Invite ceremony
manual-code field.
