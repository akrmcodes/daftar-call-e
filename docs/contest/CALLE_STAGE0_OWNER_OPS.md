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
| Outbound KYC | **Not done** until the owner confirms it in the CALL-E dashboard. Outbound requires KYC ([heycall-e.com](https://www.heycall-e.com/)). Chat or MCP ringing does **not** prove Developer API KYC. |

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

### Stage 0.3 (not now) — Secret Manager

When 0.3 starts, create the secret from the file (never Console paste in a screenshot):

```bash
gcloud secrets create calle-api-key \
  --project=daftar-closing-agent \
  --data-file="$HOME/.daftar-owner-ops/calle-api-key"
```

If the secret already exists, use `gcloud secrets versions add` — do **not** print the value. Bind it as a **file mount** on service **`daftar-call-e` only** (Stage 1). Never bind it to frozen `daftar-closing-agent`.

## Do not skip 0.2

Gate 0 needs a **US DID** (Zadarma/Sonetel) before laptop `create_and_wait`. GCP 0.3 can proceed in parallel **after** KYC is confirmed, but the live ring is 0.2 + 0.5.
