# CALL-E Stage 0 owner ops (no secrets)

**Not** a judging file. **Never** paste `CALLE_API_KEY`, App Passwords, E.164, or audience client IDs here.

Local secret directory (mode 700): `$HOME/.daftar-owner-ops/` — not in git.

## 0.1 Account / credits (as of 2026-09-01)

| Item | Status |
| --- | --- |
| CALL-E dashboard login | **Done** — `akrmcodes@gmail.com` at [heycall-e.com](https://www.heycall-e.com/) / [API keys](https://dashboard.heycall-e.com/account/api-keys). This is the email for the Devpost “CALL-E account email” field (Stage 7). Contest **GCP** remains `akrm.codes@gmail.com` — do not mix OAuth clients. |
| Developer API key | **Created.** In Secret Manager `calle-api-key` (2026-09-02) **and** local `$HOME/.daftar-owner-ops/calle-api-key`. Never Flutter `.env`, never git, never chat, never screenshots. |
| Extra-calls form | **Submitted** ([form](https://forms.gle/EPQttEZ1rkW8iq9q6)) — **+200** if this is an existing account; 1–5 business days, **not guaranteed**. |
| Free pool until extras land | **20** calls. Exhaustion **pauses** access — **no auto-charge**. Optional `~$0.05` / call is a purchase, not required. **Do not** burn calls on Flutter UI. Live cap **3** recipients until extras confirm (product cap 5). |
| Outbound KYC | **Proven 2026-09-02.** Live Developer API `create_and_wait` on `https://api.heycall-e.com` → terminal `completed`, `structured_result.can_hear_clearly=yes`. Not a separate control on the API keys page. 2026-09-01 probe `GET /v1/calls/{missing}` → **404** `not_found` still stands. |

### 0.5 API 404 probe (2026-09-01)

Ran from this machine against `https://api.heycall-e.com/v1/calls/00000000-0000-0000-0000-00000000dead`. HTTP **404**, body `error.code=not_found`. Bearer token **not** logged. Key file remains mode 600.

### Where to put the API key (now)

Do this **in your own terminal**. Do not paste the key into Cursor.

```bash
umask 077
printf '%s' 'PASTE_KEY_HERE' > "$HOME/.daftar-owner-ops/calle-api-key"
chmod 600 "$HOME/.daftar-owner-ops/calle-api-key"
# macOS Keychain is also fine; the file is for Stage 0.3 --data-file=
```

Replace `PASTE_KEY_HERE` locally. Confirm the file is **one line**, no quotes, mode `600`.

Laptop smoke (Stage **0.5**, after KYC + DID) can `export CALLE_API_KEY="$(cat "$HOME/.daftar-owner-ops/calle-api-key")"` in that shell only.

### Stage 0.3 — Secret Manager (done 2026-09-02)

Ran [`agent/scripts/stage0_3_gcp.sh`](../../agent/scripts/stage0_3_gcp.sh) as `akrm.codes@gmail.com`. Payload never printed.

| Item | Status |
| --- | --- |
| Secret `calle-api-key` | **Created** (version 1). File mount is **Stage 1** on `daftar-call-e` only |
| `call-e-runner` secretAccessor on `calle-api-key` | **Yes** (secret-level; not project-wide) |
| `call-e-runner` secretAccessor on `gmail-smtp-app-password` | **Added**; `agent-runner` **kept** |
| Project roles on `call-e-runner` | `aiplatform.user` · `logging.logWriter` · `speech.client` |
| Cloud Run `daftar-call-e` | **Created 2026-09-02** (Stage 1.0). URL in `$HOME/.daftar-owner-ops/daftar-call-e-url` (not README) |
| Frozen revision | still `daftar-closing-agent-00055-pbm` |
| Vertex on frozen revision | `GOOGLE_GENAI_USE_VERTEXAI=TRUE` · `GOOGLE_CLOUD_LOCATION=global` |

Re-run is safe (existing secret → `versions add`; existing IAM → already-present ok). Never `gcloud secrets versions access` (prints the key). Never bind either secret to frozen `daftar-closing-agent`.

### Owner: confirm billing budgets (Console only)

Owner confirmed 2026-09-02: alerts **$50 / $100 / $140** still exist. Did **not** enable `billingbudgets.googleapis.com`.

## 0.2 US DID (Zadarma/Sonetel blocked on +967 SMS)

CALL-E is the **caller**. Buy a **US destination** you answer on Wi‑Fi. Do **not** enable SMS/10DLC. Do **not** forward to +967 as the primary path. Friend SA/AE/EG mobile remains **last resort** (Arabic take), not Gate 0.

Root cause of Zadarma/Sonetel failure: they OTP the **Yemeni mobile**, not US DID KYC.

Try in this order (researched 2026-09-01):

| Order | Service | Why | Cost (approx.) | Catch |
| --- | --- | --- | --- | --- |
| **1** | [Callcentric](https://www.callcentric.com/login/) | Signup form is **name + email + password** — no mobile OTP. Real US PSTN inbound. Answer in Linphone/Zoiper over Wi‑Fi. | **Pay Per Minute** DID: **$1.95/mo + $3.95 setup + $0.015/min inbound**. Watch for **Dirt Cheap DID** overstock. | Leave SMS off. Prefer **inbound PPM**, not “residential unlimited / 911 home phone” SKUs (those want a US 911 address). Dollar Unlimited ($1/mo) is NY/NJ/IL/MA **and** residential-only — skip unless checkout does not demand a US address. |
| **2** | [DIDWW](https://www.didww.com/resources/regulatory-requirements) | US **geographic: registration not required**. Professional SIP. | Typically a few USD/mo + inbound per-min — confirm at checkout | At buy time confirm `needs_registration` is false. Softphone. |
| **3** | [VoIP.ms](https://wiki.voip.ms/article/Getting_Started) | Email signup. Cheap per-min US DID. | DID often ~$0.85–1.50/mo + per-min | May later ask **passport** (OK) — that is not +967 SMS. Avoid VPN at signup. |
| **4** | [BubblyPhone](https://bubblyphone.com/hub/us-number-without-ssn-or-address) | Email + balance; no SSN/US address. Browser dialer. | **$3 setup + $3/mo** | Keep the dialer tab open for Gate 0. Do **not** rely on forward-to-+967. Smaller vendor. |
| Avoid first | **Numero eSIM** virtual US number | In-app VoIP; their own guide says register with your **real SIM** — same Yemen SMS trap. Mixed inbound reviews. | ~€5/mo or ~€40/year | Only if the SKU lists inbound voice **and** they do not OTP +967. Human-test before CALL-E. |
| Avoid | Google Voice, Twilio **trial**, TextNow from YE | GV needs a US number. Twilio trial excludes YE and wants a verified Caller ID we do not have. TextNow is patchy abroad. | — | Telnyx paid often wants **mobile OTP**. |

Prove it: a **human** calls the +1 from a normal phone; it rings the softphone/app on Wi‑Fi. Then CALL-E `create_and_wait`. Put E.164 only in `$HOME/.daftar-owner-ops/` — never git.

### 0.2 status (2026-09-02)

- **Bought:** Callcentric **Pay Per Minute**, United States, NY 347. E.164 in `$HOME/.daftar-owner-ops/test-did` (mode 600, valid `+1` + 10 digits, not in git).
- **Linphone:** SIP username = Callcentric `1777…` (default extension `100` suffix is OK). Domain `sip.callcentric.net`. Transport **UDP**. Password must be the **extension SIP password** (My Callcentric → Extensions), not the website login and not Gmail.
- **Linphone:** **Registered** on the Callcentric account. Human PSTN ring done earlier. CALL-E live ring answered 2026-09-02 (0.5). Do **not** Activate SMS.

0.3 GCP (secret + naming) **done 2026-09-02**. 0.5 laptop smoke **done 2026-09-02**.

## 0.4 Kill switch + allowlist (2026-09-02)

Not judging copy. **Never** paste E.164 here. Values live only under `$HOME/.daftar-owner-ops/` (mode 700). Provision: `bash agent/scripts/stage0_4_allowlist.sh`.

| Env | File | Default | Parse |
| --- | --- | --- | --- |
| `CALLE_ALLOW_DIAL` | `calle-allow-dial` | **false** (file contents `false`) | PSTN only if the env value is the exact lowercase string `true`. Unset, empty, `TRUE`, `1`, `yes`, `false` → **off**. |
| `CALLE_ALLOWLIST` | `calle-allowlist` | empty = nobody | Comma-separated E.164 (`+` + digits). Trim each entry; exact match. Gate 0: the single US DID from `test-did`. |
| `CALLE_ALLOWLIST_REGION` | `calle-allowlist-region` | **US** for the demo DID | Required when the number is NANP. **Never** infer `US` from a leading `+1`. |

Not Envied. Not Flutter `.env`. Stage 1 `run-batch` (J.9) will 403 when the kill switch is off and reject any phone not on the allowlist. This pass does **not** implement that server.

### Status

Kill switch file is **`false`**. Allowlist is the one Callcentric US DID (not printed). Region **`US`**. Friend SA/AE/EG numbers stay **off** the list.

### Gate 0 smoke (0.5) — done 2026-09-02

Do **not** export `true` in a profile/rc file. Disk `calle-allow-dial` stays **`false`**. Only the smoke process may set `CALLE_ALLOW_DIAL=true`.

```bash
export CALLE_ALLOW_DIAL=true
bash agent/scripts/stage0_5_laptop_smoke.sh
unset CALLE_ALLOW_DIAL CALLE_ALLOWLIST CALLE_ALLOWLIST_REGION CALLE_API_KEY
```

Wrapper: [`agent/scripts/stage0_5_laptop_smoke.sh`](../../agent/scripts/stage0_5_laptop_smoke.sh) → [`agent/scripts/stage0_5_laptop_smoke.py`](../../agent/scripts/stage0_5_laptop_smoke.py). `calle-ai==0.7.0` in `agent/.venv` only. Production `https://api.heycall-e.com`. No webhook. No Cloud Run mutate.

**Result (no E.164, no key):** `status=completed`, `task_completed=true`, `structured_result.can_hear_clearly=yes`, `call.id=call_GfN-BQcGMORm2NkgSfxdIw`. Masked dest last-4 only in local `$HOME/.daftar-owner-ops/stage0_5-result.json` (not git). Contest credits: **1 of 20** spent.

When the smoke finishes: `unset CALLE_ALLOW_DIAL CALLE_ALLOWLIST CALLE_ALLOWLIST_REGION CALLE_API_KEY` or leave `CALLE_ALLOW_DIAL` unset (treated as false). Do not leave `true` in the environment.

## 1.0 Deploy skeleton (2026-09-02)

Ran [`agent/scripts/deploy_daftar_call_e.sh`](../../agent/scripts/deploy_daftar_call_e.sh) with `DAFTAR_CALL_E_DEPLOY=true`. Frozen All Things Agentic revision **unchanged**.

| Item | Status |
| --- | --- |
| Service | `daftar-call-e` · `us-central1` · runtime SA `call-e-runner@…` |
| Revision | `daftar-call-e-00002-k46` (audiences=3; 00001 had count 1) |
| URL | `$HOME/.daftar-owner-ops/daftar-call-e-url` → `https://daftar-call-e-1487285471.us-central1.run.app` (project number in the host is **not** the frozen Agentic hostname `daftar-closing-agent-1487285471…`) |
| Auth | `--no-allow-unauthenticated`. Invoker: `allAuthenticatedUsers` + `user:akrm.codes@gmail.com`. No public unauthenticated principal. |
| Cost lock | Min 0 / max 2 on **service and revision** |
| Secrets | `/secrets/gmail-smtp-app-password` and `/calle-secrets/calle-api-key` (Cloud Run cannot mount two secrets in one directory) |
| Kill switch | `CALLE_ALLOW_DIAL=false` (no DID in Cloud Run env) |
| Envied | `CLOSING_AGENT_BASE_URL` default **empty**; gitignored `.env` points at the new URL |
| Frozen | still `daftar-closing-agent-00055-pbm` / `agent-runner` |

Redeploy: `export DAFTAR_CALL_E_DEPLOY=true` then the wrapper. Never `gcloud run deploy daftar-closing-agent`. Never ADK Cloud Run deployer. 1.1+ call routes **not** in this revision.

## 1.1 plan-batch (2026-09-02)

`POST /v1/calls/plan-batch` is live on `daftar-call-e` only. Daftar-local: allowlist, J.10, DNC, kill switch, C.3 echo. **Does not** call CALL-E. **Does not dial.**

| Item | Status |
| --- | --- |
| Revision | `daftar-call-e-00003-f4q` |
| Kill switch | Cloud Run `CALLE_ALLOW_DIAL=false` (disk `calle-allow-dial` still `false`) |
| Allowlist | Loaded from `$HOME/.daftar-owner-ops/calle-allowlist` into Cloud Run env via `--env-vars-file` (comma-safe). **Never printed.** Region env `US` from `calle-allowlist-region` |
| Confirm handle | Process-local `(batchId, contactId) → token`. Re-plan replaces it. **Min instances 0 drops memory** (same class as email idempotency — not durable) |
| Secrets | Unchanged split mounts: `/secrets/gmail-smtp-app-password` and `/calle-secrets/calle-api-key` |
| Auth | Unauthenticated `POST /v1/calls/plan-batch` → **403** (GFE IAM; no in-process JWT) |
| Frozen | still `daftar-closing-agent-00055-pbm` |

`run-batch` / `GET /v1/calls/{runId}` are **not** deployed. Do not set `CALLE_ALLOW_DIAL=true` on Cloud Run until Stage 1.2.

