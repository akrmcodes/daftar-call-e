# CALL-E Stage 0 owner ops (no secrets)

**Not** a judging file. **Never** paste `CALLE_API_KEY`, App Passwords, E.164, or audience client IDs here.

Local secret directory (mode 700): `$HOME/.daftar-owner-ops/` — not in git.

## 0.1 Account / credits (as of 2026-09-01)

| Item | Status |
| --- | --- |
| CALL-E dashboard login | **Done** — `akrmcodes@gmail.com` at [heycall-e.com](https://www.heycall-e.com/) / [API keys](https://dashboard.heycall-e.com/account/api-keys). This is the email for the Devpost “CALL-E account email” field (Stage 7). Contest **GCP** remains `akrm.codes@gmail.com` — do not mix OAuth clients. |
| Developer API key | **Created.** Hold **only** on this machine until Stage **0.3** Secret Manager `calle-api-key`. Never Flutter `.env`, never git, never chat, never screenshots. |
| Extra-calls form | **Submitted** ([form](https://forms.gle/EPQttEZ1rkW8iq9q6)) — **+200** if this is an existing account; 1–5 business days, **not guaranteed**. |
| Free pool until extras land | **20** calls. Exhaustion **pauses** access — **no auto-charge**. Optional `~$0.05` / call is a purchase, not required. **Do not** burn calls on Flutter UI. Live cap **3** recipients until extras confirm (product cap 5). |
| Outbound KYC | **Not a separate control on the API keys page.** CALL-E’s marketing FAQ: outbound needs KYC **before number/outbound activation** ([heycall-e.com](https://www.heycall-e.com/)). Look under Account / Verification / Numbers — not API Keys. **Developer API key works:** 2026-09-01 probe `GET /v1/calls/{missing}` → **404** `not_found` (not 401/403 / `credential_grant_unavailable`). First live `create` (0.5) is the real outbound gate. |

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

### Stage 0.3 — Secret Manager (allowed now)

Create the secret from the local file (never Console paste in a screenshot). **Do not** `gcloud run deploy daftar-closing-agent`.

```bash
gcloud secrets create calle-api-key \
  --project=daftar-closing-agent \
  --data-file="$HOME/.daftar-owner-ops/calle-api-key"
```

If the secret already exists, use `gcloud secrets versions add` — do **not** print the value. Bind it as a **file mount** on service **`daftar-call-e` only** (Stage 1). Never bind it to frozen `daftar-closing-agent`.

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
- **Still required:** Linphone shows **Registered** on the Callcentric account (not only sip.linphone.org). Human PSTN call rings Linphone. Do **not** Activate SMS. Do **not** `create_and_wait` until that ring.

0.3 GCP (secret + naming) can run in parallel. Live ring = this DID + remaining 0.5.
