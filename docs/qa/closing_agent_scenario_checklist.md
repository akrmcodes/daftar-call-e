# Closing Agent — scenario checklist

Thorough device-and-script QA for the **contest Closing Agent path**: sample-store seed → mid-day capture → close-the-day → **Confirm & Send Statements** → SMTP proofs and failure handling.

This is **not** the ≤4 min film script. Run this checklist **before** filming Gate 4 ([`gate4_device_runbook.md`](gate4_device_runbook.md)) and the contest shot list ([`contest_demo.md`](../contest_demo.md)).

**Related:** [`tool/demo_seed_emails.md`](../../tool/demo_seed_emails.md) · [`qa/README.md`](README.md) (SMTP Proof of Action pointer) · [`roadmap_v2.md`](../roadmap_v2.md) §4 (close-the-day law)

---

## Binding rules

| Rule | Detail |
| --- | --- |
| Package | `com.akrmcodes.daftar` |
| Currency after seed | **USD only** (integer **cents**). Spoken **500** on this fixture = **$500.00** (`50_000` cents), not $5.00. |
| Outreach consent | **One** tap of **Confirm & Send Statements** on the plan. Desk = live progress, **not** a second Approve. |
| SMTP `250` | Gmail **accept**, not mailbox-delivered. Never narrate “delivered.” Never fake `daftar.agent.whatsapp.status`. |
| Live To: addresses | Gitignored `tool/demo_seed_emails.local.json`. This doc uses tags `demo1`…`demo7` only. |
| Banned as success path | `Open WhatsApp`, `Start sending`, `wa.me`, Yes/all-20 reminder sheet, Attach statements sheet, debug **1000-txn** perf seed |

---

## Sample-store fixture

Source: [`lib/core/utils/demo_store_seeder.dart`](../../lib/core/utils/demo_store_seeder.dart). Rank at close = **age then owed**. After the filmed Mohamed +$500 debt, Top 5 order does **not** change.

| # | Name (EN / AR) | Phone | Email tag | Pre-capture net | Age | Tone | MIME at close |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Mohamed / محمد | `+967700000001` | `demo1` | $801.50 | 55d | Firm | PDF |
| 2 | Ahmed / أحمد | `+967700000002` | `demo2` | $600.00 | 45d | Firm | PDF |
| 3 | Nadia / نادية | `+967700000003` | `demo3` | $80.00 | 40d | Reminder | PDF |
| 4 | Salem / سالم | `+967700000004` | `demo4` | $400.00 | 35d | Firm | PDF |
| 5 | Layla / ليلى | `+967700000005` | `demo5` | $350.00 | 31d | Firm | PDF |
| 6 | Omar / عمر | `+967700000006` | `demo6` | $150.00 | 12d | Reminder | text-only |
| 7 | Yousef / يوسف | `+967700000007` | `demo7` | $37.00 | 4d | Friendly | text-only |

**After mid-day confirm (3.1):** Mohamed **$1,301.50**.

**Today strip before filmed capture:** seed already has **2** rows on `localDay` (Mohamed mineral water **$1.50**, Yousef eggs **$2.00**) so Drift `localDay` is non-empty.

**Workspace shape:** exactly **one** Mohamed; **1** ledger `Customers` / `الزبائن`; store name **kept** if set, else `Sample Store` / `متجر نموذجي`; `defaultCurrency=USD`, multi-currency **off**.

Default inboxes (override via dart-define): `akrm.codes+demo1` … `demo4`; `qubati.akrm+demo5` … `demo7` — see [`tool/demo_seed_emails.md`](../../tool/demo_seed_emails.md).

---

## How to use each pass

Every pass lists:

1. **Preconditions** — device, network, seed state
2. **Steps** — exact taps, utterances, or shell commands
3. **Expected** — UI strings (EN; AR in Pass 10), data, side effects
4. **Pass / fail** — checkbox
5. **Cleanup** — re-seed when the workspace is dirty

Record results in the **Sign-off** table at the end.

---

## Pass 0 — Automated (CI / laptop)

**Preconditions:** Repo at the commit under test; Flutter SDK matches `pubspec`.

**Steps** — run from repo root:

```bash
flutter analyze
flutter test test/core/utils/dev_database_seeder_test.dart
flutter test test/core/utils/demo_seed_emails_test.dart
flutter test test/presentation/providers/closing_agent_controller_test.dart
flutter test test/presentation/screens/closing_agent/
flutter test test/application/agent/
```

**Expected:**

- [x] `flutter analyze` → **No issues found**
- [x] Seeder tests: **7** contacts, **5** PDF / **2** text-only, USD balances, desk-eligible emails
- [x] Widget tests use current copy: `Reconciling ledger entries...`, `Reconcile ledger`, `Confirm & Send Statements`
- [x] Controller tests: Approve path uses dispatch metrics; no `wa.me` on lead path

**Cleanup:** None.

---

## Pass 1 — Warm Cloud Run (Appendix E)

**Preconditions:** `gcloud` authenticated; project `daftar-closing-agent`; network on.

**Steps:**

```bash
SERVICE_URL=https://daftar-closing-agent-1487285471.us-central1.run.app
TOKEN=$(gcloud auth print-identity-token)
curl -sS -H "Authorization: Bearer $TOKEN" "$SERVICE_URL/list-apps"
```

**Expected:**

- [x] Response body includes `closing_agent` (e.g. `["closing_agent"]`)
- [x] **Fail** if the first on-camera `/run` or send-batch is a cold start
- [x] Invoker uses ID token; **no** `allUsers`; **no** `daftar-wa-webhooks`

**Cleanup:** None.

---

## Pass 2 — Seed (two entry points)

### 2.A — Onboarding seed (clean profile)

**Preconditions:** Fresh install or cleared app data; **no** `hasSeenOnboarding`.

**Steps:**

1. Complete onboarding beats: Hero → **Language: English** (for judge-friendly EN pass) → Look → Store (optional name) → Google (sign in for Drive) or skip → Pro skip → **first ledger beat**
2. On ledger beat, tap **Try with Demo Store** / **تجربة متجر افتراضي** (not Suppliers)
3. Wait for brief seed **report** dialog
4. Land on home shell

**Expected:**

- [x] Report: **7** contacts, **5** statement / **2** text-only (or equivalent report fields)
- [x] `hasSeenOnboarding` complete; FAB available
- [x] Contacts ledger shows 7 overdue USD accounts; Mohamed balance **$801.50** before capture

### 2.B — Settings re-seed

**Preconditions:** Any workspace; note current **store name**.

**Steps:**

1. Settings → **Sample store** section → **Reset sample store data**
2. Confirm dialog **Reset sample store?** → **Reset**
3. Wait for report dialog

**Expected:**

- [x] Contacts, ledgers, transactions replaced; **store name kept** if previously set
- [x] Google `googleAccountId` / email **preserved** (OAuth not wiped)
- [x] Same 7-contact fixture restored

### 2.C — Optional email overlay

**Steps:**

```bash
flutter run --dart-define-from-file=tool/demo_seed_emails.local.json
```

Then Settings → **Reset sample store data** (or onboarding seed).

**Expected:**

- [x] Each contact email matches keys in local JSON (`DAFTAR_SEED_EMAIL_demo1` … `demo7`)
- [x] Invalid define values fall back to compiled defaults (no crash, no address logged)

### 2.D — Negative

**Steps:** Attempt debug **1000-txn** perf seed (Developer Tools, debug only).

**Expected:**

- [x] **Do not** use perf seed for any close-path pass in this checklist
- [x] If run accidentally: **Reset sample store data** before Pass 3+

**Cleanup:** Re-seed via 2.B whenever contacts/txns are mutated off-script.

---

## Pass 3 — Mid-day capture

**Preconditions:** Pass 2 complete; Google signed in (for agent); network on unless scenario says otherwise.

**Idle studio (EN):**

| Element | Expected string |
| --- | --- |
| Title | Closing Agent |
| Empty title | What should we record? |
| Composer hint | Write in the ledger |
| Working banner (while agent runs) | Reconciling ledger entries... |
| Example chips | Mohamed paid 500 · Ahmed owes 200 |

### 3.1 — Filmed debt capture (happy path)

**Steps:**

1. Tap center FAB → Closing Agent
2. Type `Mohamed owes 500 sugar` → send (or mic + same utterance)
3. Wait for agent read-back / confirm card
4. Tap **Record debt** / **تسجيل دين**

**Expected:**

- [x] Money **not** in Drift before confirm
- [x] After confirm: snack **Recorded** / **تم التسجيل**
- [x] Mohamed net balance **$1,301.50** (801.50 + 500.00)
- [x] Transaction visible on Mohamed contact / today strip
- [x] HUD (if on): capture scope, model/tool/latency chips update

### 3.2 — Dismiss without confirm

**Steps:** Repeat 3.1 utterance; tap **Skip** or dismiss confirm without recording.

**Expected:**

- [x] Mohamed still **$801.50**
- [x] No new debt txn for the 500 sugar line

### 3.3 — Payment chip

**Steps:** Tap chip **Mohamed paid 500** → confirm **Record payment**.

**Expected:**

- [x] Confirm shows **Record payment**
- [x] Mohamed net decreases by **$500.00** from pre-chip balance

**Cleanup:** **Reset sample store data** before Pass 4.

### 3.4 — Unknown contact

**Steps:** Type `Fatima owes 100` → send.

**Expected:**

- [x] **Which account?** / **أي حساب؟** or create-account flow
- [x] **No** silent write to Drift

### 3.5 — Microphone

**Steps:**

1. Long-press mic → see **Recording** / **Hold to speak** states; **Slide up to cancel** while holding
2. Cancel (slide up or release per UI)
3. (Separate run) Deny microphone permission → tap mic

**Expected:**

- [x] Cancel path: **no** submit / no txn
- [x] Denied: **Microphone access is off. Open Settings to allow Daftar to record.**

### 3.6 — Offline capture honesty

**Preconditions:** Enable airplane mode **before** opening agent.

**Steps:** Open agent; attempt capture utterance.

**Expected:**

- [x] Localized error (e.g. **Connection problem** / **Sign in with Google to use the agent.**) — **not** raw exception text
- [x] Exit agent; **ledger / quick-add still work** offline

**Cleanup:** Disable airplane mode; re-seed if needed.

---

## Pass 4 — Close the day → Confirm & Send Statements

**Preconditions:** Pass 2 seed; Mohamed capture 3.1 done (or re-seed + 3.1); Google signed in; Cloud Run warmed (Pass 1); network on; email overlay points to inboxes you control.

**Steps:**

1. FAB → Closing Agent
2. Utter or type **Close today** / **Close my day** / **أقفل اليوم** / **اقفل يومي**
3. Wait for **Today's closing plan** / **خطة إقفال اليوم**
4. Verify plan disclosure mentions outreach consent
5. Tap **Confirm & Send Statements** / **تأكيد وإرسال الكشوفات**
6. Observe ritual progress → Collections Desk → dispatch → report card

**Plan must list 13 ritual tasks in order (EN):**

| # | Task title (EN) | AR |
| --- | --- | --- |
| 1 | Reconcile ledger | مطابقة القيود |
| 2 | Collect today's debts | جمع ديون اليوم |
| 3 | Collect today's payments | جمع دفعات اليوم |
| 4 | Tally per-currency totals | جمع المجاميع لكل عملة |
| 5 | Stamp the day snapshot | ختم لقطة اليوم |
| 6 | Prepare vault payload | تحضير حمولة الخزنة |
| 7 | Seal backup to Drive | ختم النسخة على درايف |
| 8 | Scan aging balances | مسح أرصدة التقادم |
| 9 | Rank by urgency | ترتيب حسب الإلحاح |
| 10 | Compile outreach list | تجهيز قائمة المدينين المستهدفين |
| 11 | Dispatch collection emails | إرسال مطالبات التحصيل |
| 12 | Compose day report | تأليف تقرير اليوم |
| 13 | Present the day seal | عرض ختم اليوم |

**Plan CTAs:**

- [x] **Confirm & Send Statements** (primary, single lapis glow)
- [x] **Confirm without sending** / **تأكيد دون إرسال**
- [x] **Approve plan** **not** shown as outreach gate
- [x] Disclosure (EN): *Confirm & Send Statements is outreach consent…*

**During ritual:**

- [x] Working banner: **Reconciling ledger entries...**
- [x] Drive backup failure **does not** abort ritual (if you can simulate grant missing, see Pass 7)

**Collections Desk:**

- [x] Title area: **Collections** · **7 reminders** / **7 تذكيرات**
- [x] Rows: Mohamed, Ahmed, Nadia, Salem, Layla → badge **PDF attached** / **كشف مرفق**
- [x] Rows: Omar, Yousef → **Reminder only** / **تذكير فقط**
- [x] Preview **subject** matches Appendix C.2:

  ```text
  EN: {{store_name}}: outstanding balance {{amount_line}}
  AR: {{store_name}}: رصيد مستحق {{amount_line}}
  ```

- [x] Preview **body** matches device composer (greeting · store · amount · CTA · optional note · close) — **no** longer LLM freeform than SMTP sends
- [x] **No** **Open WhatsApp**, **Start sending**, or second **Confirm & Send Statements** as new consent on **SMTP lead** desk
- [x] Dispatch progress: **Sending 1 of 7** … **Sending 7 of 7** (`collectionsQueueSending`)

**Report card — Day closed:**

- [x] Summary includes today's debts/payments (includes filmed 500)
- [x] Queue metrics: **7 sent**, **0 failed** (happy path)
- [x] **Statements: ranked Top 5** on report when SMTP ran
- [x] HUD email chip (if enabled): **Sent · {Message-ID last-8}**

**Cleanup:** Leave workspace for Pass 5 proofs; do not re-seed until Pass 6 or 13.

---

## Pass 5 — SMTP proofs (Must / Should)

**Preconditions:** Pass 4 completed with **Confirm & Send Statements**.

### 5.A — Inbox (Must / Should)

| ID | Check | Pass |
| --- | --- | --- |
| 5.1 | **Must:** ≥1 inbox (`demo1` Mohamed) with MIME **application/pdf** statement | ☐ |
| 5.2 | **Should:** All **5** PDF rows (demo1–demo5) received PDF attachment | ☐ |
| 5.3 | **Should:** ≥1 text-only inbox (`demo6` Omar or `demo7` Yousef) — **no** PDF, C.2 body only | ☐ |
| 5.4 | Subject line matches store name + outstanding balance format | ☐ |
| 5.5 | **Do not** claim receipt = delivery | ☐ |

### 5.B — Cloud Logging (Must)

**Steps:** Logs Explorer — project `daftar-closing-agent`:

```text
resource.type="cloud_run_revision"
resource.labels.service_name="daftar-closing-agent"
jsonPayload.event="daftar.agent.email"
```

**Expected:**

- [x] One log row per sent recipient (7 on happy path)
- [x] SMTP response **250**
- [x] Unique **`Message-ID`** per row (duplicate → Gmail `421 4.7.28`)
- [x] **No** fake `daftar.agent.whatsapp.status` / `delivered`

**Console URLs (prep):**

- Cloud Run: `https://console.cloud.google.com/run/detail/us-central1/daftar-closing-agent?project=daftar-closing-agent`
- Logs: `https://console.cloud.google.com/logs?project=daftar-closing-agent`

---

## Pass 6 — Confirm without sending

**Preconditions:** **Fresh seed** (Pass 2.B) — do not reuse Pass 4 workspace.

**Steps:**

1. Optional: mid-day capture 3.1 (not required for outreach)
2. **Close today** → plan → **Confirm without sending** / **تأكيد دون إرسال**
3. Complete ritual through report

**Expected:**

- [x] Day summary + Drive attempt still run
- [x] **Zero** SMTP / send-batch calls (no new mail in demo inboxes)
- [x] Report truthful: outreach **skipped** / no **sent** count inflation
- [x] Desk may not appear or shows skip path — **no** silent send

**Cleanup:** **Reset sample store data** before repeating Pass 4/5.

---

## Pass 7 — Drive / Google surprises

Run each sub-scenario on a **re-seeded** workspace where possible.

| ID | Setup | Steps | Expected | Pass |
| --- | --- | --- | --- | --- |
| 7.1 | Google signed **out** | Close → Confirm & Send Statements | Ritual completes; backup line **Sign in to save tonight’s Drive backup.** / **سجّل الدخول لحفظ نسخة درايف الليلة.** | ☐ |
| 7.2 | Signed in, **Drive grant missing** | Close | **Drive permission was not granted. Approve access once to save tonight's backup.**; ritual **continues** | ☐ |
| 7.3 | Agent use, Google **not** signed in | Open FAB, capture | **Sign in with Google to use the agent.** | ☐ |
| 7.4 | OpenID grant stale | Agent turn | **A one-time Google permission update is required…** — **not** mixed with Drive-only copy | ☐ |

**Cleanup:** Re-seed after each row if close state dirty.

---

## Pass 8 — Cloud Run / SMTP failures

### 8.1 — Airplane during send

**Preconditions:** Re-seed; complete plan confirm with **Confirm & Send Statements**; enable airplane **after** plan confirm when ritual reaches dispatch (or before send-batch if timing allows).

**Expected:**

- [x] Localized **Connection problem** and/or **Email was not sent** (`errorSmtpTitle` — Cloud Run App Password or missing sender env; not Google Sign-In)
- [x] Drift **day summary already committed** (close not rolled back)
- [x] **No** automatic `wa.me` / WhatsApp fallback
- [x] **Continue closing the day** / **أكمل إقفال اليوم** available when back online

### 8.2 — Retry after recovery

**Steps:** Disable airplane; on Collections Desk tap **Retry sending** / **إعادة الإرسال** (visible when dispatch failed but rows still pending — not a second consent).

**Expected:**

- [x] **Retry sending** calls send-batch again via existing `approveAndSend()` — no WhatsApp, no **Start sending**
- [x] Honest metrics — no double-send without new consent

**Cleanup:** Re-seed.

---

## Pass 9 — Empty overdue

**Preconditions:** Workspace with **no** overdue emailed contacts (not the default sample store).

**Options:**

- **A:** Throwaway profile + minimal ledger, no overdue debtors with email
- **B:** Pay all 7 demo contacts to zero before close (time-consuming)
- **C:** Fresh store without sample seed

**Steps:** **Close today** → plan confirm (either CTA).

**Expected:**

- [x] **Nothing to collect** / **لا شيء للتحصيل** on report
- [x] Drive backup still attempted
- [x] **No** send-batch / no desk blast

**Cleanup:** Re-seed sample store for remaining passes.

---

## Pass 10 — Locale Arabic (RTL)

**Preconditions:** Settings → Language **Arabic**; **Reset sample store data** (Arabic names ledger **الزبائن**).

Repeat **3.1** with: `محمد عليه ٥٠٠ سكر`

Repeat **Pass 4** close with **أقفل اليوم** / **اقفل يومي**.

**Expected:**

- [x] RTL layout; Arabic contact names (محمد … يوسف)
- [x] Working: **جاري مراجعة وتدقيق الدفتر...**
- [x] Plan title: **خطة إقفال اليوم**
- [x] Tasks: **مطابقة القيود**, **تجهيز قائمة المدينين المستهدفين**, **إرسال مطالبات التحصيل**
- [x] CTAs: **تأكيد وإرسال الكشوفات**, **تأكيد دون إرسال**
- [x] Desk: **7 تذكيرات**; PDF / reminder-only badges in AR
- [x] Email subject C.2 Arabic: `{{store_name}}: رصيد مستحق {{amount_line}}`

**Cleanup:** Optional switch back to EN for filming.

---

## Pass 11 — Architecture HUD (Should)

**Preconditions:** Settings → **Show agent architecture** / **عرض هيكل الوكيل** **on** (demo seed defaults HUD on in debug).

**Steps:**

1. Capture 3.1 → observe top HUD during `/run`
2. Complete Pass 4 send
3. Toggle HUD **off** in Settings → repeat FAB open

**Expected:**

- [x] HUD visible: **Cloud Run · gemini-3.5-flash** (or current model id), tool name, latency ms, **Ref {correlation last-8}**
- [x] HITL chips: Propose · Confirm · Commit · Rank (scope labels Capture / Close / Ask)
- [x] After SMTP: **Sent · {Message-ID last-8}**
- [x] Toggle off → **no** overlay
- [x] Reduce motion (`disableAnimations`): static chips, no animation dependency
- [x] HUD does **not** cover FAB coach mark (if coach not yet seen)

**Cleanup:** None.

---

## Pass 12 — Hybrid E ban (contest-period leftover)

**Preconditions:** SMTP lead desk after **Confirm & Send Statements** (Pass 4).

**On the primary SMTP desk (no `showHybridELeftover`):**

- [x] **Open WhatsApp** — **not** visible
- [x] **Start sending** — **not** visible
- [x] **Pause** sticky queue bar — **not** visible
- [x] **Skip outreach** — **not** visible as lead CTA
- [x] Legacy **Prepare collection reminders?** Yes / Top 5 / No — **not** shown
- [x] **Attach statements?** sheet — **not** shown on close path

**Note:** Hybrid E UI may still exist behind `showHybridELeftover` in tests — **do not film** as climax. Opening `wa.me` ≠ sent.

---

## Pass 13 — Re-close / dirty workspace

### 13.1 — Second close same `localDay`

**Preconditions:** Pass 4 successful send completed **today**.

**Steps:** FAB → **Close today** again without new capture.

**Expected:**

- [x] **No** silent second blast to all 7 inboxes without a **new** plan **Confirm & Send Statements**
- [x] Report metrics stay **honest** (no fake `sent` inflation)

### 13.2 — Reset integrity

**Steps:** Settings → **Reset sample store data** → confirm.

**Expected:**

- [x] Contacts, ledgers, transactions wiped; **store name kept**
- [x] 7 overdue USD fixture restored; Mohamed **$801.50** pre-capture

---

## Sign-off

| Field | Value |
| --- | --- |
| Date | |
| Tester | |
| Device / OS | |
| Build (debug / release / APK) | |
| Locale tested (EN / AR / both) | |
| Pass 0 analyze clean | ☐ |
| Pass 1 Cloud Run warm | ☐ |
| Pass 4 Confirm & Send Statements | ☐ |
| Pass 5 Must: inbox PDF (`demo1`) | ☐ |
| Pass 5 Should: 5 PDF + 1 text-only | ☐ |
| Pass 5 Console `250` + Message-ID | ☐ |
| Pass 6 Confirm without sending | ☐ |
| Pass 10 Arabic RTL | ☐ |
| Pass 12 No WhatsApp lead chrome | ☐ |
| Leftover Hybrid E seen on lead path | ☐ Y (fail) / ☐ N |

**Gate 4 film ready:** ☐ — only when Must rows are true on camera ([`gate4_device_runbook.md`](gate4_device_runbook.md)).

---

## Appendix — Quick command reference

```bash
# Analyze + core tests
flutter analyze
flutter test test/core/utils/dev_database_seeder_test.dart \
  test/presentation/providers/closing_agent_controller_test.dart \
  test/presentation/screens/closing_agent/

# Run on device with email overlay
flutter run --dart-define-from-file=tool/demo_seed_emails.local.json

# Warm Cloud Run
SERVICE_URL=https://daftar-closing-agent-1487285471.us-central1.run.app
TOKEN=$(gcloud auth print-identity-token)
curl -sS -H "Authorization: Bearer $TOKEN" "$SERVICE_URL/list-apps"

# Logs filter
# resource.type="cloud_run_revision"
# resource.labels.service_name="daftar-closing-agent"
# jsonPayload.event="daftar.agent.email"
```
