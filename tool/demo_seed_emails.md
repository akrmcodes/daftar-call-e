# Demo seed overlay (emails + US DID)

Compile-time overlay for [`DemoStoreSeeder`](../lib/core/utils/demo_store_seeder.dart). Release builds use owner plus-aliases by default; forks may override via `--dart-define-from-file`.

## Files

| Path | Git | Values |
| --- | --- | --- |
| [`demo_seed_emails.example.json`](demo_seed_emails.example.json) | committed | owner plus-aliases (`akrm.codes+demo1` … `qubati.akrm+demo7`); empty `DAFTAR_SEED_US_DID` |
| `demo_seed_emails.local.json` | **gitignored** | optional overrides for forks (emails + owner US DID) |

Copy the example to the local path only if you need different inboxes or a live call target. Same keys. Do **not** commit secrets.

## Keys

### `DAFTAR_SEED_US_DID` (Mohamed — call-eligible contact)

Owner inbound **US DID** in E.164 (`+1` …). Seeds Mohamed (index 0) only. Remaining six contacts use Yemen Mobile placeholders (`+96777…`) plus valid emails.

- **Not** Envied — do not add to repo-root `.env`.
- **Not** `CALLE_ALLOWLIST` — that stays Cloud Run / `$HOME/.daftar-owner-ops/` only.
- Empty or invalid → Mohamed also gets a Yemen placeholder (email rail / `callUnavailable` at close).
- Never commit a live DID. Never log the resolved value.

Resolver: [`lib/core/utils/demo_seed_us_did.dart`](../lib/core/utils/demo_seed_us_did.dart).

### `DAFTAR_SEED_EMAIL_<tag>` (all seven contacts)

Tags: `demo1`, `demo2`, `demo3`, `demo4`, `demo5`, `demo6`, `demo7`.

| Index | Tag | Default inbox |
| --- | --- | --- |
| 1 Mohamed | `demo1` | `akrm.codes+demo1@gmail.com` |
| 2 Ahmed | `demo2` | `akrm.codes+demo2@gmail.com` |
| 3 Nadia | `demo3` | `akrm.codes+demo3@gmail.com` |
| 4 Salem | `demo4` | `akrm.codes+demo4@gmail.com` |
| 5 Layla | `demo5` | `qubati.akrm+demo5@gmail.com` |
| 6 Omar | `demo6` | `qubati.akrm+demo6@gmail.com` |
| 7 Yousef | `demo7` | `qubati.akrm+demo7@gmail.com` |

PDF vs text-only is **not** a seed flag. [`ClosingPdfPolicy.rankedTop5`](../lib/domain/value_objects/closing_ritual_result.dart) ranks at close (age then owed). Top 5 get statement PDFs; Omar and Yousef are text-only in the default mix.

## Gate 4 film

**Onboarding:** Store beat → **Try with Demo Store** / **تجربة متجر افتراضي** (release-visible).

**Settings:** **Reset sample store data** (same fixture, with confirm).

Optional override:

```bash
flutter run --dart-define-from-file=tool/demo_seed_emails.local.json
```

Resolver: [`lib/core/utils/demo_seed_emails.dart`](../lib/core/utils/demo_seed_emails.dart) and [`lib/core/utils/demo_seed_us_did.dart`](../lib/core/utils/demo_seed_us_did.dart). Invalid dart-define values fall back to compiled defaults. Addresses and DIDs are never logged.
