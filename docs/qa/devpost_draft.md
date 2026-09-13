# CALL-E Devpost — paste sheet (owner)

**Hackathon:** [CALL-E: Your Code Is Calling](https://call-e.devpost.com/) · prize aim **Most Practical Use Case** (no track dropdown — four equal criteria; ties break on **Real World Impact**).

**Binding:** [`docs/CONTEST_DISCLOSURE.md`](../CONTEST_DISCLOSURE.md) · [`docs/roadmap_v3.md`](../roadmap_v3.md) v3.5 §6.5.

**Deadline:** Submit before **14 Sep 2026 23:45 SGT** (owner buffer ≤ **18:00 AST** 14 Sep). If the live [Official Rules §1](https://call-e.devpost.com/rules) time differs from the homepage banner, **rules win**.

**Do not paste:** live E.164, `CALLE_API_KEY`, Gmail App Password, Pro+ codes, frozen Agentic hostname as the CALL-E service.

**CALL-E account email ≠ GCP:** dashboard = `akrmcodes@gmail.com` · contest GCP = `akrm.codes@gmail.com`.

---

## Pre-flight (before Submit)

- [ ] Community Guidelines: honest existing project; own work; gallery/video — no third-party music or marks without permission.
- [x] Video **≤3:00**, public YouTube, on-device live ring — URL below.
- [ ] Gallery: [`architecture/contest_architecture.png`](../architecture/contest_architecture.png) first (3:2 if needed, ≤5 MB).
- [ ] Three attestations on page 3: all checked.

---

## Page 1 — Project overview

### Project name

**Paste:**

```
Daftar Confirm & Call
```

| Check | Value |
| --- | --- |
| Character count | **21** / 60 max |
| Do not use | “CALL-E” alone, Agentic service name, Arabic-only title |

### Elevator pitch

**Paste:**

```
After close of day, shops still phone overdue customers themselves—or forget. Confirm & Call rings supported numbers and returns integer promises, not payments. Yemen stays on email.
```

| Check | Value |
| --- | --- |
| Character count | **182** / 200 max |

---

## Page 2 — Project details (public)

### About the project

Paste the Markdown block below into **About the project** (English required per Official Rules).

```markdown
## Inspiration

Across the Arab street, many shops still close the day on paper. After the ledger is copied, the merchant still has to **phone** overdue customers—or names get skipped and calls get forgotten. That specific phone chore is the problem—not “AI that makes phone calls.”

**Daftar** (دفتر) is an offline-first debt ledger that existed before this hackathon. In August 2026 a **Closing Agent** (Gemini + ADK + HITL) was added for a different contest. For **CALL-E** the significant update is **Confirm & Call**: consented outbound collections **calls** to supported numbers at close of day, with an integer **promise** on device—not a payment.

## What it does

- **Close of day:** merchant confirms the plan, opens the **Collections Desk**, and taps **Confirm & Call** (dual rail: up to five voice calls + email statements). The desk calls **all** supported rows in that set—not a single PSTN.
- **Device ranks** who can be called (aging, allowlist, do-not-call). **Gemini does not pick contact IDs.**
- **Call rail:** every region-eligible, allowlisted number in the call set gets a CALL-E `calls.create`; Yemen and other unsupported regions show **Can't call** and stay on **Gmail SMTP** (accepted ≠ delivered).
- **Promise card:** structured integer `promised_amount_minor` displays on device. **No ledger transaction** from the call. Payment stays a later human confirm (Model C).
- **Confirm & Call stays** in the product after the hackathon.

**Real World Impact:** Close-of-day collections for shops that still use paper books—they still make those calls themselves, or they forget. CALL-E returns a **promise**, not cash.

## How we built it

**Quality of the Idea:** HITL **Confirm & Call** on a dedicated desk—not a generic dialer. Non-obvious pieces: device-ranked dual rail; region gate refuses unsupported numbers instead of failing PSTN; integer promise never cashiers. Reusable contribution: Agent Skill [`ledger-collections-call`](https://github.com/CALLE-AI/awesome-phone-call-agents/tree/main/skills/ledger-collections-call) (merged [PR #385](https://github.com/CALLE-AI/awesome-phone-call-agents/pull/385))—complementary to community [`kept`](https://github.com/CALLE-AI/awesome-phone-call-agents/tree/main/apps/python/kept); this project did **not** invent collections promises.

**Technical Implementation:** Production path is the CALL-E **Developer API**, not MCP. On Cloud Run service **`daftar-call-e`**, Python imports **`calle-ai==0.7.0`** and calls `CalleClient.calls.create` (`POST /v1/calls`) at **runtime**—one create per eligible contact in the call set (cap 5). The **Android** app triggers `run-batch`; the device **polls `GET /v1/calls/{runId}`** (no public webhook; no `create_and_wait` on Cloud Run). CALL-E is a **sibling FastAPI route**—**not** a ninth ADK FunctionTool (eight-tool catalog frozen). Architecture HUD shows `Call ·` + last-8 of `call.id`. Gmail `send-batch` is the email rail after **Confirm & Send Statements**.

Stack: Flutter · Drift · Riverpod · Google ADK + Gemini 3.5 Flash (proposals only) · FastAPI on Cloud Run · Secret Manager for API keys.

**Product Experience & Demo:** ≤3:00 video: Close today → desk → **this demo:** one live on-device ring (seed had one US-eligible row; owner-owned Callcentric US DID answered in **Linphone**, disclosed on VO) → promise card → YE email row. The product cap is still **five** supported calls. English VO with burned-in EN subtitles over Arabic-capable UI.

**Repo:** https://github.com/akrmcodes/daftar-call-e · **Disclosure:** [`docs/CONTEST_DISCLOSURE.md`](https://github.com/akrmcodes/daftar-call-e/blob/main/docs/CONTEST_DISCLOSURE.md) · **Diagram:** [`docs/architecture/contest_architecture.md`](https://github.com/akrmcodes/daftar-call-e/blob/main/docs/architecture/contest_architecture.md)

CALL-E / AIRUDDER API traffic is **Singapore-hosted**. Names and amounts leave the device for the call rail.

## Challenges we ran into

- **Region honesty:** Yemen cannot be dialed on CALL-E; the product must refuse early and route to email—not pretend PSTN worked.
- **HITL boundaries:** Gemini proposes; the merchant confirms; the model does not dial or cashier. Separating ADK proposals from the CALL-E sibling route kept the eight-tool freeze intact.
- **Proof of Action:** `task_completed` / integer promise ≠ paid; SMTP **250** = Gmail **accepted**, not delivered; poll ≠ webhook theater.

## What we learned

Importing `calle-ai` and calling it at runtime on the device path—plus a dry-run Agent Skill—beats laptop-only smoke. A structured integer promise is useful only if the ledger still requires a later human confirm.

## What's next

Confirm & Call stays in the product. Dual rail stays for regions CALL-E cannot dial. A later Play Store listing is planned; multi-device sync stays deferred (Stage 8 quarantined in this repo).
```

### Built with

Add tags (≤25). Suggested list — add each chip Devpost accepts:

```
CALL-E
calle-ai
Python
Flutter
Dart
Android
Google-Cloud-Run
Google-ADK
Gemini
Vertex AI
FastAPI
Drift
SQLite
Riverpod
Gmail
OpenAPI
Secret Manager
```

**Do not add:** MCP (not the production path).

### Try it out links

| # | URL | Label (if asked) |
| --- | --- | --- |
| 1 | `https://github.com/akrmcodes/daftar-call-e` | Source repository |
| 2 | `https://github.com/CALLE-AI/awesome-phone-call-agents/pull/385` | Agent Skill PR (merged) |

Do **not** add Cloud Run URL (browser GET is **403** without ID token; no `allUsers`).

### Image gallery

1. **Must:** [`docs/architecture/contest_architecture.png`](../architecture/contest_architecture.png) — crop to 3:2 if needed; no E.164, no API keys on diagram.
2. **Optional:** film stills — Collections **Confirm** CTA, HUD chip last-8, promise card. Crop Cloud trial banner, Gmail “Paid” smart-reply chips, any E.164.

### Video demo link

**Paste:**

```
https://youtu.be/wV1QqQgAiLE
```

If Devpost’s embed rejects the short URL, paste:

```
https://www.youtube.com/watch?v=wV1QqQgAiLE
```

| Rule | Requirement |
| --- | --- |
| Length | **≤3:00** (judges need not watch past 3 min) |
| Visibility | **Public** |
| Device | Footage shows project on **Android** (device built for) |
| Language | English VO or **burned-in EN subtitles** |
| Audio | No copyrighted music |
| Content | Live CALL-E ring + promise ≠ payment; disclose owner answers demo DID |

**Live YouTube title** (already published — do not re-upload to change it):

```
Daftar Confirm & Call — close-of-day collections with CALL-E
```

**Live YouTube description** (already published):

```
CALL-E hackathon submission — Most Practical Use Case.

Close of day: HITL Confirm & Call places consented collections calls and writes an integer promise on device—not a payment. Yemen / unsupported regions stay on email.
```

Optional (not required to re-upload): add repo + [PR #385](https://github.com/CALLE-AI/awesome-phone-call-agents/pull/385) under the YouTube description if still editable.

---

## Page 3 — Additional info (judges / organizers)

### Submitter Type

**Select:** `Individual`

### Country of residence/incorporation

**Select:** `Yemen`

Official Rules §3 excludes Brazil, Quebec, Russia, Crimea, Cuba, Iran, North Korea, and comprehensively OFAC-sanctioned jurisdictions. Yemen is **not** in that enumerated list. Residence is the entrant’s legal residence, not the shop’s locale.

### Organization name (if applicable)

**Leave blank.**

### App status

**Select:** the option meaning **pre-existing / existing project updated during the Submission Period** (wording may be “Existing”, “Pre-existing”, or similar — **not** “New”).

Per [Official Rules §4 — New & Existing](https://call-e.devpost.com/rules): explain the significant update below.

### If pre-existing, explain what you updated during the submission period

**Paste:**

```
This is an existing offline-first shop ledger (Daftar) plus an August 2026 Closing Agent built for All Things Agentic—that closer is prior work, not claimed as CALL-E-new.

Significant update for CALL-E (Submission Period): Confirm & Call. After merchant HITL on the Collections Desk, Cloud Run service daftar-call-e imports calle-ai==0.7.0 and calls CalleClient.calls.create (POST /v1/calls) for allowlisted, region-eligible overdue contacts. The Android app polls GET /v1/calls/{runId}. The device stores an integer promised_amount_minor—a promise, not a payment. Gmail SMTP remains the rail for Yemen, missing phone, and Confirm without calling. Gemini never dials and never cashiers. Reusable Agent Skill ledger-collections-call merged in awesome-phone-call-agents PR #385.
```

### Testing instructions for application

**Paste:**

```
Judges can score from the public ≤3:00 video, this repo, and the merged Agent Skill PR without installing the APK. The repository is public for judging. Copyright is reserved (see LICENSE); clone, read, and run the skill dry-run. Do not change Cloud Run IAM.

Skill dry-run (no CALLE_API_KEY): docs/skills/ledger-collections-call/ — default is dry-run; never posts without --live.

Optional Flutter build: see README Spin-up (gitignored .env; never point CLOSING_AGENT_BASE_URL at the frozen All Things Agentic hostname). Do not tap Confirm & Call against live Cloud Run unless you own the destination DID and allowlisted contacts.

Cloud Run daftar-call-e is ID-token only—unauthenticated browser GET returns 403 (expected). No allUsers. No secrets in git or this form.
```

### Optional: URL where your functional demo app can be accessed

**Leave blank.**

Do not publish Cloud Run or APK URLs that imply open public access. Judges are not required to run the app ([Official Rules — Testing](https://call-e.devpost.com/rules)).

### Project submission pull request URL

**Paste:**

```
https://github.com/CALLE-AI/awesome-phone-call-agents/pull/385
```

Contribution Area: **Agent Skills** · `skills/ledger-collections-call/` · **merged** 2026-09-11. Do **not** open a second skill PR.

### Email address associated with your CALL-E account

**Paste:**

```
akrmcodes@gmail.com
```

Must match [CALL-E dashboard](https://dashboard.heycall-e.com/account/api-keys) login — **not** `akrm.codes@gmail.com` (GCP only).

### Which best describes the primary use case your project addresses?

**Select:** `Customer outreach` (or the closest live option — Devpost “What to Build” lists customer outreach explicitly).

### In one sentence, what real-world task does your CALL-E application handle?

**Paste:**

```
At shop close, after the merchant confirms, CALL-E places consented collections calls to customers with supported numbers and returns a structured integer promise on the device—not a payment—while unsupported regions continue to use email instead of PSTN.
```

### Attestations (required)

- [x] I, and, if applicable, all of my teammates, are at least the age of majority where I reside (e.g. 18 in the US).
- [x] I, and, if applicable, all of my teammates, are from an eligible jurisdiction to compete.
- [x] I, and, if applicable, all of my teammates, are not employees of the sponsor or its affiliates.

---

## Do not say (filter pass)

- “The app only places one call” as a **product** limit (call set cap is **5**; this demo filmed one eligible US row)
- “We invented collections” / clone of [`kept`](https://github.com/CALLE-AI/awesome-phone-call-agents/tree/main/apps/python/kept) without differentiation
- “Delivered” / “paid” for SMTP or promise outcomes
- Frozen `daftar-closing-agent-1487285471` as the CALL-E runtime service
- Webhook / `create_and_wait` as the production Android path
- Live E.164, API keys, or real debtor numbers

---

## Owner close-out

1. Paste remaining Devpost fields from this sheet (video URL is filled).
2. Upload gallery PNG (+ optional stills).
3. **Submit** before deadline; then Stage 7 freeze SHA (roadmap §7). Do **not** tick “Devpost submitted” in the roadmap until the form is actually submitted.
