# Demo seed overlay (emails + US DID)

Compile-time overlay for [`DemoStoreSeeder`](../lib/core/utils/demo_store_seeder.dart). Release builds use owner plus-aliases by default; forks may override via `--dart-define-from-file`.

**Required for Confirm & Call on a debug device.** `flutter run` without this file seeds **all seven** contacts with Yemen placeholders. The Collections Desk then has an empty call set.

## Files

| Path | Git | Values |
| --- | --- | --- |
| [`demo_seed_emails.example.json`](demo_seed_emails.example.json) | committed | owner plus-aliases (`akrm.codes+demo1` … `qubati.akrm+demo7`); empty `DAFTAR_SEED_US_DID` and `CALLE_ALLOWLIST` |
| `demo_seed_emails.local.json` | **gitignored** | owner overlay: emails + US DID + device allowlist |

Copy the example to the local path, then fill `DAFTAR_SEED_US_DID` and `CALLE_ALLOWLIST` from `$HOME/.daftar-owner-ops/test-did` (same E.164, `+` + digits). For the live Confirm & Call window, set `CALLE_ALLOW_DIAL` to exact `true` in the **local** overlay only; revert after the demo. Do **not** commit the local file. Never add a live DID to the example JSON.

## Keys

### `DAFTAR_SEED_US_DID` (Mohamed — call-eligible contact)

Owner inbound **US DID** in E.164 (`+1` …). Seeds Mohamed (index 0) only. Remaining six contacts use Yemen Mobile placeholders (`+96777…`) plus valid emails.

- **Not** Envied — do not add to repo-root `.env`.
- Independent of `CALLE_ALLOWLIST` — you must set **both**. Empty DID → Mohamed also gets a Yemen placeholder (`callUnavailable` at close).
- Empty allowlist with a US DID still puts Mohamed on **email** only (not allowlisted).
- Never commit a live DID. Never log the resolved value.

Resolver: [`lib/core/utils/demo_seed_us_did.dart`](../lib/core/utils/demo_seed_us_did.dart).

### Device CALL-E policy (`CALLE_*` dart-defines)

Compile-time device defense in depth. Desk call-set uses allowlist + J.10 + DNC. PSTN still requires `CALLE_ALLOW_DIAL=true` via [`RunBatchRecipientGuard`](../lib/domain/constants/run_batch_recipient_guard.dart) (Stage 4). Cloud Run reads the same names from `$HOME/.daftar-owner-ops/` — that is a **separate** copy.

| Key | Purpose |
| --- | --- |
| `CALLE_ALLOW_DIAL` | Exact lowercase `true` enables PSTN on device; anything else is off. Live Confirm & Call on device uses `true` |
| `CALLE_ALLOWLIST` | Comma-separated E.164. Spaced/dashed input is normalized. Empty = nobody on the call rail |
| `CALLE_ALLOWLIST_REGION` | NANP declared ISO (default `US`) |

- **Not** Envied — do not add to repo-root `.env`.
- Settings shows a **read-only** stub until Stage 5.2.
- Never commit live E.164. Never log allowlist values.

Resolver: [`lib/domain/constants/calle_device_policy.dart`](../lib/domain/constants/calle_device_policy.dart).

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

## Device run (Stage 3.1)

Dart-defines are **compile-time**. Hot reload / hot restart does **not** pick up a new overlay. After changing `demo_seed_emails.local.json`:

1. Stop the running app.
2. Relaunch with the flag below (full rebuild).
3. **Reset sample store data** or **Try with Demo Store** so Mohamed’s phone is rewritten.

```bash
flutter run -d <device> --debug --dart-define-from-file=tool/demo_seed_emails.local.json
```

Linphone rings on **Confirm & Call** when Cloud Run `daftar-call-e` has the kill switch on and this overlay sets `CALLE_ALLOW_DIAL` to exact `true`. Re-seed after changing the overlay.

Resolver: [`lib/core/utils/demo_seed_emails.dart`](../lib/core/utils/demo_seed_emails.dart) and [`lib/core/utils/demo_seed_us_did.dart`](../lib/core/utils/demo_seed_us_did.dart). Invalid dart-define values fall back to compiled defaults. Addresses and DIDs are never logged.
