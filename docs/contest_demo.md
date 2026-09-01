# Contest demo — ≤4:00 shooting bible

Stage **4.5** / Stage **6** of [`roadmap_v2.md`](roadmap_v2.md). **Recording is Stage 6.** This file is the judged cut.

Thorough pre-film QA: [`qa/closing_agent_scenario_checklist.md`](qa/closing_agent_scenario_checklist.md). Device proofs: [`qa/gate4_device_runbook.md`](qa/gate4_device_runbook.md).

> **v2.8 (binding).** Close-the-day outreach is Gmail SMTP after **Confirm & Send Statements**. Hybrid E (`wa.me`) is leftover — **not** the climax. Device drafts are Appendix C.2. Silent send is banned. SMTP **250** = Gmail **accept**, not mailbox-delivered.

## Rules that bind this cut

| Rule | How this film obeys |
| --- | --- |
| First **4:00** only (Christina 14:28) | Hard stop on **Day closed**. Nothing after. |
| English narration **or** EN subtitles | **Both:** English TTS + **burned-in EN subtitles** (Arabic RTL UI). |
| Live Proof of Action | Confirm, ritual, send-batch, inbox, HUD, Cloud Logging = **real 1×**. Not After Effects. |
| Gemini model + agent framework **said aloud** | VO names **Gemini 3.5 Flash**, **Google ADK**, **Cloud Run**. |
| GCP on camera | Logs Explorer `daftar.agent.email` — **250** + **Message-ID**. |
| Official tip: skip long intros / do not film sign-up | Illustrated **problem is 32s max**. Full onboarding (Hero → Language → Look → Google) is **not** in this 4:00. |

**AI voiceover is allowed.** Official Devpost self-check: *“Not comfortable narrating? An AI voiceover beats silence or mumbling.”* Christina prefers human voice (12:36) — burned-in EN subtitles cover that. Do **not** claim Veo / Lyria.

**Voice:** Google Chirp 3 HD Enceladus `en-US` (`POST /v1/tts`) or a free ElevenLabs English male. **0.95×**. No theatrical accent. Export WAV. No music under SMTP or GCP.

```
0:00 ──────── 0:32 ──────────────────────── 3:52 ──── 4:00
 illustrated     live Taskmaster (device + Console)    Day closed
 night (AE OK)   1× real — AE lower-thirds only        hard stop
```

## Owner prep (not on camera)

1. **Device.** Dedicated profile, package `com.akrmcodes.daftar`.
2. **Build.** Sample store is **not** `kDebugMode`-gated.
   - Onboarding (off camera): Language → English **or** Arabic UI + EN subtitles. Store **محل الغانم** if you want that name on C.2 subjects. First ledger → **Try with Demo Store**.
   - Settings: **Reset sample store data**. **Show agent architecture** ON.
3. **Drive** linked. Unsigned Drive → backup `skippedUnsigned` (do not film that as success).
4. **Seed.** 7 contacts, 5 PDF / 2 text-only. **Not** the 1000-txn seed.
5. **Warm Cloud Run:** `daftar-closing-agent` · `us-central1` · `https://daftar-closing-agent-1487285471.us-central1.run.app`
6. **VO + picture kit.** WAV timed to the tables below. Five illustration stills + **one** torn-ledger photo (no faces, no live phone numbers). SRT matching the VO. YouTube **public** + EN captions.

Paste `محمد عليه ٥٠٠ سكر` — **do not type** the close path.

## Expected after seed

[`DemoStoreSeeder.seedData`](../lib/core/utils/demo_store_seeder.dart):

| Item | Value |
| --- | --- |
| Contacts **N** | **7** (all emailed, overdue) |
| Ledgers | **1** — `Customers` / `الزبائن` |
| Currency | **USD only** (integer cents) |
| Capture | Exactly one `Mohamed` / `محمد` |
| PDF split | Ranked Top **5** MIME PDF; **Omar** and **Yousef** text-only |
| Spoken **500** | **$500.00** (`50_000` cents) |

## After Effects — allowed vs banned

**Allowed:** intro Ken Burns; story clock `21:00 → 00:40` labeled *one typical close* (not a study); EN lower-thirds (`HITL`, `not an ADK tool`, `250 = accept`); circle HUD chips.

**Banned:** fake inbox, fake log JSON, fake SMTP **250**, compositing WhatsApp as the send, speeding the **live** money/email/GCP takes into a lie. Trim dead air around them; do not invent frames.

---

## Act A — Illustrated night (0:00–0:32)

**Only** place for AI stills, a real كشكول photo, and the story clock. Not a documentary.

**Do not invent headcounts** (“47 million merchants waste 3 hours”). Geography: **Yemen, Egypt, and shops across the Arabic-speaking street**. ILO line only (informal employment ≈ **half** of employment in Arab States — cite ILO informality profile, not a fake country table).

**Still style (free ImageFX / Bing Image Creator):** `flat editorial illustration, simple line-drawn shopkeeper, Arabic ledger دفتر, limited palette charcoal and cream, no photorealism, no logos, no readable customer PII, 16:9`. Khazna onyx + bone. **No lapis fills.** Ken Burns ≤10%.

| Clock | Picture | VO (read this) |
| --- | --- | --- |
| 0:00–0:05 | Title card: **Daftar Closing Agent · Taskmaster** | In Yemen, Egypt, and shops across the Arab street, the day still ends in a paper دفتر. |
| 0:05–0:12 | Stick-merchant, customers, scribbled names; one customer leaves, a line left blank | Debts live in memory. One forgotten name is a forgotten balance. |
| 0:12–0:20 | Night: copying the daily book into the main book; clock **23:10** | After midnight he copies the day into the big book, adds totals by hand, and still has not told who owes. |
| 0:20–0:26 | **Your photo** of a torn/worn كشكول | The book tears. The night does not. |
| 0:26–0:32 | Clock **00:40** + super: *ILO: about half of employment in Arab States is informal* | ILO: about half of employment in Arab States is informal. Close-the-day is the chore they should not still do by hand. |

---

## Act B — Live Taskmaster (0:32–4:00)

Smash-cut to the **seeded** device. HUD on. Cloud Run warm.

| Clock | Picture | VO (read this) |
| --- | --- | --- |
| 0:32–0:42 | FAB / composer | Daftar Closing Agent. The shop’s day is the long-running task. Gemini 3.5 Flash on Cloud Run with Google ADK plans; Drift on the phone is the source of truth. |
| 0:42–1:18 | Paste or speak `محمد عليه ٥٠٠ سكر` → Confirm → list updates | Mid-day capture. Mohamed owes five hundred dollars sugar. Gemini proposes; I confirm; Drift commits. Integer money. No silent write. |
| 1:18–2:28 | Plan → ritual (`localDay` → Drive → aging) → Desk: **5 PDF / 2 text** | One confirm on the plan. The device runs summary, Drive backup, and aging. Gemini does not pick who is emailed. |
| 2:28–2:52 | **Confirm & Send Statements** + HUD chips | Confirm and Send Statements is outreach consent. Not an ADK send tool. HUD: Cloud Run, gemini-3.5-flash. |
| 2:52–3:22 | Mohamed inbox **MIME PDF**. Omar or Yousef **text-only** | Proof of Action: inbox PDF on the ranked Top 5. Remainder is text-only on purpose. |
| 3:22–3:52 | Logs Explorer (filter below) | Cloud Logging: SMTP 250 and a unique Message-ID. 250 is accept, not delivered. |
| 3:52–4:00 | Day closed card | Day closed. Hard stop. |

**Optional 6s FAB-coach** only if Act B is already in time — **not** a substitute for Hero → Language → Look. Full clean-profile onboarding is **off** this cut ([`roadmap_v2.md`](roadmap_v2.md) §6.1 line 1084).

### GCP on camera

- Cloud Run: `https://console.cloud.google.com/run/detail/us-central1/daftar-closing-agent?project=daftar-closing-agent`
- Logs: `https://console.cloud.google.com/logs?project=daftar-closing-agent`

```text
resource.type="cloud_run_revision"
resource.labels.service_name="daftar-closing-agent"
jsonPayload.event="daftar.agent.email"
```

### Full VO (stopwatch)

Read against a timer before lock. If over 4:00, **cut Act A**, never GCP.

> In Yemen, Egypt, and shops across the Arab street, the day still ends in a paper دفتر. Debts live in memory. One forgotten name is a forgotten balance. After midnight he copies the day into the big book, adds totals by hand, and still has not told who owes. The book tears. The night does not. ILO: about half of employment in Arab States is informal. Close-the-day is the chore they should not still do by hand.
>
> Daftar Closing Agent. The shop’s day is the long-running task. Gemini 3.5 Flash on Cloud Run with Google ADK plans; Drift on the phone is the source of truth. Mid-day capture. Mohamed owes five hundred dollars sugar. Gemini proposes; I confirm; Drift commits. Integer money. No silent write. One confirm on the plan. The device runs summary, Drive backup, and aging. Gemini does not pick who is emailed. Confirm and Send Statements is outreach consent. Not an ADK send tool. HUD: Cloud Run, gemini-3.5-flash. Proof of Action: inbox PDF on the ranked Top 5. Remainder is text-only on purpose. Cloud Logging: SMTP 250 and a unique Message-ID. 250 is accept, not delivered. Day closed. Hard stop.

## Out of this cut

Full onboarding cold start · WhatsApp / `wa.me` as climax · claiming `delivered` · SequentialAgent · 1000-txn seed · typing the close · essay architecture on screen (repo has [`architecture/contest_architecture.md`](architecture/contest_architecture.md)) · fake statistics · music over logs.

---

## Film day — owner runbook (English UI)

Sequential day-of-film path. Judged window is **only the first 4:00**. This take uses **English UI** + English TTS + burned-in EN subtitles. Spoken **500** = **$500.00**.

**Do not film onboarding, Settings, or the HUD toggle.** Those are setup. Smash-cut Act B onto seeded **home + FAB**.

```text
prep (off camera) → 0:00–0:32 AE intro (can be later) → 0:32 phone FAB/capture/close
                 → laptop Mohamed PDF → Omar/Yousef text → Logs 250 → 3:52 Day closed STOP
```

### Direct answers (do not improvise)

| Question | Decision |
| --- | --- |
| Start with onboarding? | **No.** Hero → Language → Look → Store → Google **off camera**. |
| Then Settings + HUD? | **Yes, off camera.** Leave Settings. Camera starts on **home + FAB**. |
| Open Mohamed’s account after the 500? | **No.** Confirm card + snack is Drift proof. A contact drill eats the 4:00. |
| Also “Mohamed paid 500” or export a statement? | **No.** Checklist Pass 3.3 — not this film. |
| After close, open Drive on the web? | **No.** Watch **Seal backup to Drive** on the ritual. Drive Console is not GCP Proof of Action. |
| Emails then Google Cloud? | **Yes.** Mohamed **PDF**, then Omar or Yousef **text-only**, then Logs Explorer **250 + Message-ID**. |
| Then what? | **Day closed.** Hard stop. No WhatsApp, no architecture essay. |

Paste, do not type: `Mohamed owes 500 sugar` then `Close today`.

### Part 0 — Off camera (phone)

1. Dedicated profile, package `com.akrmcodes.daftar`. **Not** the 1000-txn debug seed.
2. Onboarding if needed: Language **English** → Look → store **محل الغانم** (or keep existing) → Google until Drive is **linked** → first ledger **Try with Demo Store**.
3. Settings → **Reset sample store data** → report: **7** contacts, **5** PDF / **2** text-only.
4. Settings → **Show agent architecture** **ON**. Leave Settings. Land on **home**.
5. Once, off camera: Mohamed balance **$801.50** before capture. Do not linger for the film.
6. Clipboard: `Mohamed owes 500 sugar`. Note (not on screen): `Close today`.
7. DND, brightness high. No Gmail or Console **on the phone**.

### Part 0 — Off camera (laptop — four Chrome tabs)

Already logged in. Hide bookmarks and unrelated mail. Zoom logs so `smtpCode` / `250` and `messageId` are readable.

1. **Gmail Mohamed (Must):** inbox for seed `demo1` (Mohamed / `akrm.codes+demo1`). One message with a **PDF** is enough. See [`tool/demo_seed_emails.md`](../tool/demo_seed_emails.md).
2. **Gmail Omar or Yousef (Should):** `demo6` Omar or `demo7` Yousef (`qubati.akrm+demo6` / `demo7`). **Text-only** C.2 — **no PDF**.
3. **Logs Explorer (Must):** [Logs](https://console.cloud.google.com/logs?project=daftar-closing-agent) · time **last 1 hour** · query:

```text
resource.type="cloud_run_revision"
resource.labels.service_name="daftar-closing-agent"
jsonPayload.event="daftar.agent.email"
```

4. **Cloud Run (backup 5s if logs lag):** [service](https://console.cloud.google.com/run/detail/us-central1/daftar-closing-agent?project=daftar-closing-agent) · `us-central1`.

Live service is back to the cost lock **min 0 / max 2** (revision `daftar-closing-agent-00055-pbm`) after the take. A first `/run` may be a cold start.

**Warm Cloud Run** (laptop terminal):

```bash
SERVICE_URL=https://daftar-closing-agent-1487285471.us-central1.run.app
TOKEN=$(gcloud auth print-identity-token)
curl -sS -H "Authorization: Bearer $TOKEN" "$SERVICE_URL/list-apps"
# expect ["closing_agent"]
```

If this fails, **do not record**. Mailbox env was restored on revision **00052**. Logs **535** → mint a new App Password. Missing USER/FROM → **Email was not sent**, not Sign-in.

**Intro stills** can be AE’d later (5 illustrations + torn كشكول, WAV, SRT). Record Act B first if stills are not ready. **Never** cut GCP to save time.

### Part 1 — On camera (Act B)

**Phone:** one take FAB → **Day closed**. **Laptop:** second take (or second recorder) starting at desk **Sending 7 of 7**. Edit: phone → inbox → logs → back to phone **Day closed**. Trim dead air. Do not speed money / SMTP / logs into a lie.

| Clock | Where | Do this |
| --- | --- | --- |
| 0:32–0:42 | Phone FAB | Open Closing Agent. HUD: **Cloud Run · gemini-3.5-flash**. Title **What should we record?** Do **not** tap **Mohamed paid 500**. |
| 0:42–1:18 | Phone | Paste `Mohamed owes 500 sugar` → send → **Record debt** → snack **Recorded**. **Do not** open Mohamed’s ledger. |
| 1:18–2:28 | Phone | Paste **Close today**. Wait **Today's closing plan**. **Confirm & Send Statements** — not **Confirm without sending**. Watch **Seal backup to Drive**. Desk: **Collections · 7 reminders**; Mohamed…Layla **PDF attached**; Omar, Yousef **Reminder only**. Hold ~2s. |
| 2:28–2:52 | Phone desk | **Sending 1 of 7** … **7 of 7**. AE circle HUD (`HITL`, `not an ADK tool`). No WhatsApp. |
| 2:52–3:22 | Laptop Gmail | Mohamed: open the **PDF**. Omar or Yousef: **no attachment**. Do not open all five PDFs. Do not say **delivered**. |
| 3:22–3:52 | Laptop Logs | Point at **250** and a unique **Message-ID**. Seven rows ideal; one 250 + Message-ID is the Must. Optional 3s Cloud Run page if the stream is slow. |
| 3:52–4:00 | Phone | **Day closed** — today’s books include the **$500**; **7 sent** on a happy path. **Hard stop.** |

### Part 2 — Not in the 4:00

Onboarding / Language / Google · HUD toggle · typing the 500 · Mohamed contact screen · **Mohamed paid 500** · generate statement from a contact · 1000-txn seed · WhatsApp · claiming `delivered` · Drive website · music under SMTP/GCP · fake inbox or fake log frames.

### Part 3 — After the take

AE: Ken Burns intro ≤32s; EN lower-thirds; burned-in EN subs. YouTube **public** + captions file. If over 4:00, shorten Act A, **never** GCP.

If SMTP fails: stop; do not fake logs; **Reset sample store data**; recapture 500; close again.
