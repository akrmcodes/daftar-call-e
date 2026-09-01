> **Archived — not binding for All Things Agentic (Submission Period 3–31 Aug 2026).**
> Contest execution contract: `docs/roadmap_v2.md`.
> Original date retained for historical accuracy.

# Daftar (دفتر) — Execution Roadmap

> **Version:** 3.6 · **Date:** 2026-08-06 · **Derived from:** `plan.md` v2.0 + `daftar_phase2_financial_study.md` + CDO Phase 2 Strategic Pivots (June 2026) + Local-First Docker Mandate (August 2026) + Growth / UX / Performance Pivot (August 2026) + Stage 8 Accuracy Audit (August 2026) + AI Voice Feature Study v2.0 (`ai_voice_feature_study.md`, August 2026)
>
> **v3.0 headline:** Phase 2 is re-scoped as **"The Killer Features."** AI Voice Input is **UNFROZEN** (made viable by a hard 600/month cap + on-device-first inference + 2026 model prices). The Next.js customer web portal is **abandoned** in favour of a **B2C app-download deep-link growth loop**. Multi-device sync gains a real **Merge Engine** with worker email invites and granular permissions. New stages are added for the **Viral Referral Engine**, **Monetization & Subscriptions**, and the **Enterprise Handoff**.
>
> **v3.1 Nuclear Auth Reset → Auth V2 Shipped (June 2026):** Stage 4.5 Google Auth + Drive was **purged** due to the **Amnesia Bug**, then rebuilt as **Auth V2** (persistence-first architecture). Phases 0–7 complete — Google Sign-In, Drive auto-backup, headless WorkManager sync, and Amnesia regression suite all verified (425/425 tests).
>
> **v3.3 Local-First Docker Mandate (August 2026):** Phase 2 is re-sequenced around **local Docker Supabase completeness** before any production cloud cutover. Ownership transfer and workspace-deletion/immutable receipts leave Stage 8; transactional-email deliverability is deferred to Enterprise Handoff; a dedicated **Production Supabase Deployment** stage lands after Analytics and before Monetization.
>
> **v3.4 Growth, UX & Performance Pivot (August 2026):** Explicit **Firebase preflight** (FCM / Crashlytics / Analytics); **Stunning Onboarding** as Stage 9; AI Voice relocated to **penultimate Stage 18**; zero-cost viral rewards + **B2C→B2B Bridge**; deepened analytics; dedicated **Extreme Performance** stage; forensic Phase 2 gaps closed. Phase 2 is now **Stages 8–19**.
>
> **v3.5 Stage 8 Accuracy Audit (August 2026):** Stage 8 — the load-bearing stage of Phase 2 — was re-verified claim-by-claim against the code on disk. Contradictions, arithmetic errors, and unbuilt-but-checked items were corrected; three implementation defects and one undefined parameter were surfaced as open work. Stage 8 checkboxes are now evidence-backed, and the Validation Gate was rewritten to actually cover what the stage promises. **Scope: Stage 8 only** — other stages have not yet had the same treatment.
>
> **v3.6 AI Voice Rebuild (August 2026):** The Stage 18 feature study was redone from scratch against the August 2026 model market ([`docs/archive/ai_voice_feature_study.md`](ai_voice_feature_study.md)). The v3.0 five-step on-device-first cascade is **retired** — Gemma 4 E4B requires ~5 GB RAM against a 2–4 GB target device, and the cascade carried 8 failure surfaces plus untestable dual quota semantics. New architecture: **one metered cloud call, one confirm** — Gemini 3.1 Flash-Lite audio→JSON with schema-locked output, deterministic Arabic-number/polarity cross-validation, a Voice Outbox for offline capture, and an accuracy-first golden-set gate built **before** the feature. Worst-case cost ≤ $3.60/Pro+ user/yr; fleet ceiling ≈ $8K/yr at 100K users (vs the $104K frozen-era estimate). **Scope: §§B–H, Stage 18, appendix + cross-references, pricing matrix v2.1.**

---

## Roadmap Overview

| Phase             | Stages       | Timeline             | Objective                                                                                       |
| ----------------- | ------------ | -------------------- | ----------------------------------------------------------------------------------------------- |
| **MVP (Phase 1)** | Stages 0–7   | 8–10 weeks           | Launch → Validate PMF → First revenue via activation codes                                       |
| **Phase 2**       | Stages 8–19  | 24–32 weeks post-MVP | Local Docker sync, **stunning onboarding**, B2C + immutable receipts, addictive analytics, ownership transfer, **prod Supabase cutover**, payments, **zero-cost viral loop + B2C→B2B bridge**, extreme performance, **AI Voice (late)**, enterprise handoff |

### Active Workstreams

| Workstream | Doc | Status |
|------------|-----|--------|
| Phase 2 Killer Features | Stages 8–19 below | Ready (Auth V2 gate passed); **local Docker baseline** for Stages 8–13; **Firebase preflight (0.3.2) required** before FCM/Crashlytics/Analytics are treated as live |

### Dependency Graph

```
Stage 0 (Project Scaffold + Google Cloud Preflight + Firebase Preflight)
  └── Stage 1 (Core Domain & Database — schema only, incl. MerchantProfile)
        ├── Stage 1.5 (Data Integrity Hardening)
        ├── Stage 2 (Ledger & Contact Management)
        │     └── Stage 3 (Transaction Engine & Balances)
        │           ├── Stage 4 (Reports, Import/Export & Backup — incl. Google Drive)
        │           │     └── Stage 4.5 — Auth V2 shipped (Google Sign-In + Drive)
        │           └── Stage 5 (Premium & Monetization)
        └── Stage 6 (Security, Settings & UX Polish)
              ↑ 6.3 Merchant Branding requires Stage 4 (PDF) + Stage 5 (tier gates)
              ↑ 6.7 Ledger Archiving requires Stage 5 (tier gates) + Stage 2 (ledger/contact management)
              └── Stage 7 (QA, Performance & Launch)
                    │
                    └── PHASE 2 — The Killer Features (local Docker first)
                          └── Stage 8 (Sync Backend, Merge Engine & Workspace Collaboration — local Docker)
                                ├── Stage 9 (Stunning Onboarding, Frictionless Setup & Delight System)
                                ├── Stage 10 (Smart Import & Merge)
                                ├── Stage 11 (WhatsApp Reminders, B2C Shared Accounts & Immutable Receipts)
                                │     ↑ requires Stage 8 Deep-Link + Stage 0.3.2 FCM foundation
                                ├── Stage 12 (The Addictive Analytics Dashboard)
                                ├── Stage 13 (Self-Service Account Ownership Transfer)
                                │     ↑ immediately before cloud cutover — schema-final ownership re-key
                                ├── Stage 14 (Production Supabase Deployment & Environment Configuration)
                                │     ↑ cloud gate — required before any public-endpoint stage
                                ├── Stage 15 (Monetization & Subscription Architecture)
                                │     ↑ requires Stage 14 (gateway webhooks need public HTTPS)
                                ├── Stage 16 (Viral Referral Engine & B2C→B2B Bridge)
                                │     ↑ requires Stage 8 Deep-Link + Stage 14 cloud; AI credits banked until Stage 18
                                ├── Stage 17 (Extreme Performance Optimization)
                                ├── Stage 18 (AI Voice Input & NLP — UNFROZEN, penultimate)
                                │     ↑ requires Stage 14 secrets + Stage 17 perf budgets re-validated
                                └── Stage 19 (Enterprise Handoff — Docs, Testing, Security & Email Infra)
```

> [!NOTE]
> **Shared Phase 2 foundation:** Stage 8 builds a single **Deep-Link & Attribution Service** (own-domain Universal Links / Android App Links + Play Install Referrer + Supabase token store) on **local Docker**. Both the B2C growth loop (Stage 11) and the Referral Engine (Stage 16) consume it. Firebase Dynamic Links is dead (shut down 2025-08-25) and is NOT used.
>
> **Local Docker baseline (v3.3):** Stages **8–13** are designed and validated against a local `supabase start` stack. Stage **14** is the sole production-cloud cutover. Stages **15–19** may assume a live project (AI Voice is Stage **18**).
>
> **Stage 8 subsection IDs are frozen** (on-disk migrations and QA docs reference `8.4` / `8.5` / `8.7`). Do not renumber Stage 8 internals.

### Key Architectural Pivots (v2.0)

| Pivot              | Old (v1.0)                         | New (v2.0)                                  | Rationale                                                                         |
| ------------------ | ---------------------------------- | ------------------------------------------- | --------------------------------------------------------------------------------- |
| **Authentication** | Supabase Auth (Phone OTP)          | Google Sign-In (`google_sign_in` v7+)       | Phone OTP costs $0.02–$0.05/SMS — unsustainable at scale. Google Sign-In is free. |
| **Cloud Backup**   | Supabase Storage                   | Google Drive (`drive.appdata` scope)        | Zero server-side storage cost. User's own Google account. No CASA audit needed.   |
| **PDF Statements** | Basic header                       | Merchant branding (logo, store name, phone) | Pro/Pro+ upsell. Professional appearance for WhatsApp-shared statements.          |
| **Pricing**        | Free / Pro $17/yr / Business $8/mo | Free / Pro $24.99/yr / Pro+ $49.99/yr       | Raises break-even from 85K to 32K users.                                          |

### Key Architectural Pivots (v3.0 — CDO Phase 2 Mandate, June 2026)

| Pivot                       | Old (v2.1)                                   | New (v3.0)                                                                                          | Rationale                                                                                                                   |
| --------------------------- | -------------------------------------------- | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| **AI Voice Input**          | FROZEN indefinitely (uncapped = $104K/yr)    | **UNFROZEN — Pro+.** Hard **600 voice inputs/month** cap + on-device-first + 2026 models            | The freeze assumed 50–100 uncapped cloud calls/day. A 600/mo cap with on-device-first collapses worst-case cost to ~$2–3/user/yr. |
| **AI STT model**            | (frozen) Whisper.cpp / GPT-4o-mini @ $730K   | On-device **Gemma 4 E4B / Whisper** primary; **Soniox** cloud fallback ($0.10/hr async)            | Soniox bundles Arabic STT + diarization + confidence at 2–8× less than OpenAI/Azure/Speechmatics.                          |
| **AI NLP model**            | (frozen) Gemini 2.0 Flash-Lite ($0.075/$0.30) | On-device **Gemma 4** / regex primary; **Gemini 3.1 Flash-Lite** ($0.25/$1.50) cloud fallback       | Gemini 2.0 Flash/Lite shut down 2026-06-01. 3.1 Flash-Lite is the cost-efficient successor; Gemma 4 is Apache-2.0 self-hostable. |
| **Customer Portal (B2C)**   | Next.js / Supabase web portal                | **Abandoned.** Replaced by an **app-download deep-link growth loop** + "Shared Accounts" ledger     | A web portal is a dead-end. An installed app is a locked-in, free-to-use customer who feeds the ecosystem and gets push.   |
| **Multi-device Sync**       | LWW sync engine (single user)                | **Merge Engine** + **worker email invites** + **granular permissions** (Owner/Editor/Viewer)       | Shops have employees. Collaboration is the Pro+ moat; the Merge Engine guarantees safe offline/online reconciliation.       |
| **WhatsApp Reminders**      | Pro+ "30/month" (un-costed)                  | Pro+ reminders with **strict per-tier quota + circuit breaker** on verified 2026 Cloud API rates    | Meta sets the price and it is uncontrollable; quotas + free-window/push offload guarantee Daftar never loses money.        |
| **Monetization**           | Manual activation codes (local only)         | **Supabase atomic single-use promo codes (RPC/trigger)** + automated **payment gateway** flow       | Atomic server-side redemption prevents code reuse; gateways unlock self-serve recurring revenue.                            |
| **Growth**                 | Word-of-mouth only                           | **Viral Referral Engine** — trackable deep-links, verified install+register, gamified AI rewards    | Turns the user base into the acquisition channel; rewards (free AI credits / unlocked analytics) cost pennies to grant.    |

> [!WARNING]
> **v3.6 supersession:** the three AI rows above (AI Voice Input / AI STT model / AI NLP model) are the historical v3.0 record. The on-device tier (Gemma 4 / Whisper.cpp) and the Soniox-fallback cascade are **retired** — see **Key Architectural Pivots (v3.6)** below and Financial Strategy §§B–D.

### Key Architectural Pivots (v3.3 — Local-First Docker Mandate, August 2026)

| Pivot | Old (v3.2) | New (v3.3) | Rationale |
| --- | --- | --- | --- |
| **Phase 2 execution baseline** | Mixed local + premature cloud assumptions inside Stage 8 | Stages **8–13** are **local Docker only**; Stage **14** is the dedicated production Supabase cutover | Eliminates premature cloud optimization; CTO develops exclusively on `supabase start` until feature surface is schema-final. |
| **Transactional email** | SPF/DKIM/DMARC + CAPTCHA step-up listed as Stage 8.7 delayed items | Deferred to **Stage 19.4** (Enterprise Handoff); §8.7 keeps rate-limit buckets + `invite_send_queue` with no SMTP send | No email provider is wired; invites mint copy/share URLs. Deliverability hardening belongs with production ops. |
| **Ownership transfer** | Stage 8.8 (Band D hardening) | **Stage 13** — immediately before Stage 14 cloud cutover | Re-keys `workspace.owner_identity` and every RLS ownership path; must be battle-tested locally before the migration snapshot is pushed. |
| **Immutable receipts / workspace deletion** | Stage 8.9 (depends on B2C Shared Accounts that do not exist yet) | Merged into **Stage 11** as §11.3 / §11.4, immediately after B2C Shared Accounts | Continuity guarantee cannot precede the B2C foundation it protects. |
| **Production Supabase** | Implicit / scattered (Frankfurt deferral note in §8.1) | Dedicated **Stage 14** after Analytics, before Monetization | Latest possible slot still strictly before the first hard public-endpoint dependency (gateway webhooks, real store installs). |

### Key Architectural Pivots (v3.4 — Growth, UX & Performance Mandate, August 2026)

| Pivot | Old (v3.3) | New (v3.4) | Rationale |
| --- | --- | --- | --- |
| **Firebase** | Packages in pubspec only; init commented out | Explicit **§0.3.2** Console + platform wiring + FCM/Crashlytics/Analytics smoke tests | FCM is the $0 push rail for B2C; Crashlytics backs the 99.5% gate; Analytics measures activation + viral loop. Inert Firebase was a silent defect. |
| **AI Voice placement** | Stage 10 (early Phase 2) | **Stage 18** — penultimate, after Performance | Deep-tech R&D must not dilute focus on core financial logic, sync, B2C, and growth. Credits banked until launch. |
| **Onboarding** | Weak 3–4 walkthrough screens in Stage 7.4 | Dedicated **Stage 9** — auto-detect locale/currency, guided first ledger, sticky teaching moments, Delight System | First impression compounds into every later stage; Phase 1 is shipped. |
| **Viral rewards** | 1-month Pro+ trial + 3 AI credits + analytics at 100 | **Zero-cost hybrid ladder** (permanent limit raises / branded PDF; time-boxed then permanent analytics & archive); Pro+ trial **cancelled** | Protect Pro ARPU; every reward has ~$0 marginal cost. |
| **B2C→B2B Bridge** | Absent | Every PDF / share / Shared Account embeds a localized CTA carrying the merchant's **referral token** | Merchants become unknowing marketers; attributed growth at $0 infra. |
| **Performance** | Scattered `[Delayed]` items in Stage 7.2 | Dedicated **Stage 17 Extreme Performance** with CI budgets | Absolute operational perfection before AI and enterprise handoff. |
| **Transactional email** | Stage 17.4 | **Stage 19.4** (Enterprise Handoff renumbered) | Same content; stage number follows Enterprise → 19. |

### Key Architectural Pivots (v3.6 — AI Voice Rebuild, August 2026)

| Pivot | Old (v3.0–v3.5) | New (v3.6) | Rationale |
| --- | --- | --- | --- |
| **AI Voice architecture** | 5-step cascade: on-device STT → cloud STT → regex → on-device NLP → cloud NLP | **Single call**: audio → Gemini 3.1 Flash-Lite → schema-locked JSON behind one hardened Edge Function | 8 failure surfaces → 4; one quota semantic; no GB-class model downloads on metered Yemeni internet; worst-case ≤ $3.60/user/yr. |
| **On-device inference** | Gemma 4 E4B / Whisper.cpp primary ("$0, private") | **Retired** — explicit non-goal with falsifiable revisit criteria (§C) | E4B: 2.5 GB download / ~5 GB RAM ≫ A03-class hardware (2–4 GB total); violates Stage 17 budgets (150 MB RAM / 30 MB APK); Gemma 4 audio evals contain no Arabic. |
| **Regex Arabic parser** | Primary NLP path (~70% claim, unvalidated) | **Validator, not parser** — deterministic amount/polarity cross-check on model output (§18.4) | Cross-checking catches model errors; competing with the model duplicates it badly. |
| **Offline voice** | Incoherent (offline + low confidence ⇒ dead end) | **Voice Outbox** — record offline, auto-parse on reconnect, confirm then commit | Honest offline-first: capture always works; parsing needs network; manual entry remains the always-offline path. |
| **Accuracy claim** | Aspirational ("flawlessly parsed"), ungated | **Measured**: golden-set CI gate built first (§18.1 — polarity 100%, amount ≥ 98%) + field-edit-rate telemetry | "Near-zero error" is engineered at the commit boundary (schema + cross-checks + Confirm Card), not assumed from WER. |

---

## Phase 1 — MVP

---

### Stage 0: Project Scaffold & Dev Environment (MVP)

**Goal:** Initialize the Flutter project, configure all tooling, establish the directory skeleton, validate Google Cloud integration end-to-end, and ensure every developer can build from a clean clone in < 5 minutes.

**Prerequisites:** None — first stage.

**Features from Product Plan:**

- N/A — infrastructure only

**Integration / Architecture Notes:**

- Flutter 3.x project targeting Android (min API 26) and iOS
- Riverpod with code generation (`riverpod_generator`, `build_runner`)
- Drift with code generation for type-safe SQLite
- go_router for navigation
- ARB-based localization (Arabic default, English)
- Google Sign-In for authentication (replaces Supabase Auth)
- Google Drive API for cloud backup (replaces Supabase Storage)
- Firebase Analytics + Crashlytics for telemetry

#### Task Checklist

**0.1 Flutter Project Initialization**

- [x] Create Flutter project with `flutter create --org com.daftar --project-name daftar ./`
- [x] Set `minSdkVersion` to 26 in `android/app/build.gradle`
- [x] Set iOS deployment target to 15.0 in `ios/Podfile` and Xcode project
- [x] Configure `analysis_options.yaml` with strict lint rules (`flutter_lints` + custom)
- [x] Add `.gitignore` entries for generated Drift/Riverpod files (`*.g.dart`, `*.drift.dart`)

**0.2 Dependency Installation**

- [x] Add core dependencies to `pubspec.yaml`:
  - `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`
  - `drift`, `sqlite3_flutter_libs`, `path_provider`, `path`
  - `go_router`
  - `flutter_localizations`, `intl`, `slang`
  - `uuid`, `equatable`, `freezed_annotation`, `json_annotation`
  - `dio`, `retrofit`
  - `local_auth`, `flutter_secure_storage`
  - `pdf`, `share_plus`, `file_picker`
  - `flutter_local_notifications`
  - `google_sign_in`
  - `googleapis` (Drive v3 API)
  - `image_picker`
  - `connectivity_plus`
  - `firebase_core`, `firebase_analytics`, `firebase_crashlytics`
  - [x] `firebase_messaging` — **required for FCM** (B2C push, morning analytics push, invite renewal pings); add before Stage 11
- [x] Add dev dependencies:
  - `build_runner`, `drift_dev`, `riverpod_lint`
  - `freezed`, `json_serializable`, `retrofit_generator`
  - `flutter_test`, `mocktail`, `integration_test`
- [x] Add tooling: FlutterFire CLI (`flutterfire_cli`) for generating `lib/firebase_options.dart`
  - Global CLI: `flutterfire_cli` **1.4.1** (`dart pub global activate flutterfire_cli` → `~/.pub-cache/bin/flutterfire`)
  - Prerequisite (local): CocoaPods + Ruby gem `xcodeproj` (required so `flutterfire configure` can register `GoogleService-Info.plist` in the Xcode project)
  - Generated: `lib/firebase_options.dart` + `firebase.json` for project `daftar-core-prod` (android + ios)
- [x] Remove `supabase_flutter` from dependencies (no longer used)

**0.3 Google Cloud Console Setup & Preflight Validation**

> [!IMPORTANT]
> This section must be completed and validated before any Google-dependent implementation (Stage 4.5) begins. A broken Google Cloud setup discovered late causes cascading delays.

- [x] Create Google Cloud project for Daftar
- [x] Enable Google Drive API in Cloud Console
- [x] Configure OAuth 2.0 consent screen (internal → external)
- [Delayed] Create OAuth 2.0 Client IDs:
  - [x] Android: with SHA-1 fingerprint (debug keystore)
  - [Delayed] Android: with SHA-1 fingerprint (release keystore) _(DEFERRED: Awaiting production release keystore generation to avoid SHA-1 collision)_
  - [x] iOS: with bundle identifier
- [x] Add `drive.appdata` scope to OAuth consent screen (non-sensitive — no CASA audit required)
- [x] Configure `google_sign_in` platform setup:
  - Android: add client ID to `android/app/src/main/res/values/strings.xml`
  - iOS: add `GoogleService-Info.plist` and URL scheme to `Info.plist`

**0.3.1 Preflight Smoke Test**

- [x] Build debug APK and install on a physical Android device (or emulator with Google Play Services)
- [x] Trigger `GoogleSignIn().signIn()` and verify:
  - OAuth consent screen appears with correct app name
  - `drive.appdata` scope is listed and grantable
  - Sign-in completes and returns a valid `GoogleSignInAccount`
- [x] Using the authenticated HTTP client, execute a round-trip test against the Drive v3 API:
  - Create a small text file in `appDataFolder` (`parents: ['appDataFolder']`)
  - Read the file back and verify contents match
  - Delete the file
- [x] Sign out and verify `GoogleSignIn().signOut()` clears auth state
- [x] Repeat sign-in and verify silent sign-in (`signInSilently()`) succeeds
- [Delayed] Repeat the same sign-in, Drive upload/download, sign-out, and silent sign-in flow on at least one iOS device or simulator configured with the iOS bundle ID and URL scheme.
- [x] If any step fails: diagnose and fix before proceeding past Stage 0
- [x] Document resolved setup issues in `README.md` for team onboarding

**0.3.2 Firebase Console Setup & Preflight**

> [!IMPORTANT]
> **Why Firebase is foundational (not optional).** Three products, three Phase 2 economics levers:
>
> | Product | Role in Daftar | Why it matters |
> |---|---|---|
> | **FCM (Cloud Messaging)** | Zero-cost push to Shared Account customers, morning analytics ritual, invite-renewal merchant pings | Stage 8 economics already price Realtime sockets + FCM at **$0 by design**. FCM is the rail that lets Stage 11 replace paid WhatsApp utility messages with free in-app push for app-installed customers — the single largest "never lose money" lever. |
> | **Crashlytics** | Mandatory crash + non-fatal reporting for a financial ledger | Stage 7.3 launch gate requires **≥ 99.5% crash-free**. Without Crashlytics init, Stage 6.5's shipped global error handler is a silent no-op. |
> | **Analytics** | Activation funnel, referral attribution, B2C→B2B bridge measurement | Stage 9 onboarding north-star (time-to-first-transaction) and Stage 16 viral loop are unmeasurable without it. Respect `analyticsEnabled` opt-out. |
>
> Firebase Dynamic Links is **dead** (shut down 2025-08-25) and is **NOT** used — deep links are own-domain App/Universal Links (Stage 8.5).

> [!CAUTION]
> **Status (2026-08-12):** §0.3.2 + §0.3.2.1 **complete** on physical Android (SM G990U) for `daftar-core-prod`: Crashlytics non-fatal, Analytics DebugView (`daftar_analytics_smoke`), FCM console test push, fail-soft init. Note: YE networks may block Analytics upload without a temporary phone VPN (laptop VPN alone is for Console viewing). Remaining Firebase gaps (not Stage 0 blockers): iOS APNs / `aps-environment` (Delayed); release SHA fingerprints; Stage 11.0 token registry / send path. Omit `DAFTAR_FIREBASE_SMOKE` in normal development.

- [x] Create (or link) a **Firebase project** bound to the **same Google Cloud project** used for Drive OAuth (shared identity — one billing/org surface)
- [x] Register **Android** app (`com.akrmcodes.daftar` or current applicationId):
  - [x] Extract **debug** SHA-1 / SHA-256 from `~/.android/debug.keystore` (`androiddebugkey`):
    - SHA-1: `50:45:7E:95:EC:90:B7:B2:66:56:BF:64:3A:42:E1:23:32:C5:89:2C`
    - SHA-256: `3A:0B:59:01:A6:92:4A:CF:D8:E7:43:CC:93:4E:96:17:25:0E:FF:93:04:01:6E:D0:88:04:97:3E:E2:C3:81:8F`
  - [x] Add debug fingerprints in Firebase Console (Android app settings)
  - [Delayed] Extract / add **release** SHA-1 / SHA-256 _(same deferral as Stage 0.3 release OAuth client — awaiting production release keystore)_
  - [x] Download `android/app/google-services.json` (tracked in git per project policy)
- [Delayed] Register **iOS** app (bundle ID):
  - [x] Download `ios/Runner/GoogleService-Info.plist`
  - Create APNs Authentication Key in Apple Developer → upload to Firebase Cloud Messaging
  - Add `aps-environment` to `ios/Runner/Runner.entitlements` (development → production for release)
- [x] Run FlutterFire CLI: `flutterfire configure` → generate `lib/firebase_options.dart`
  - Project: `daftar-core-prod` · platforms: android + ios · package/bundle: `com.akrmcodes.daftar`
  - Android app id: `1:1006508283232:android:c85bc6b54075d6346fba05`
  - iOS app id: `1:1006508283232:ios:f966bdc81b9e2b796fba05`
  - Artifacts: `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` (also in Xcode Resources via `project.pbxproj`), `firebase.json`
- [x] Android Gradle wiring:
  - [x] Apply `com.google.gms.google-services` **4.4.4** in `android/settings.gradle.kts` / apply in `android/app/build.gradle.kts` _(≥4.4.1 per Android Crashlytics docs; FlutterFire-configured line — 4.5.0 resolve hung in agent Gradle so kept verified 4.4.4)_
  - [x] Apply `com.google.firebase.crashlytics` **3.0.7** Gradle plugin for native symbol upload
  - Note: Flutter owns native Crashlytics/Analytics SDKs via pub packages — do **not** add Firebase Android BoM `implementation` lines (avoids version conflicts)
- [x] Enable in Firebase Console: **Google Analytics**, **Cloud Messaging** (owner); **Crashlytics** product finishes onboarding when the first report arrives (§0.3.2.1)
- [x] Uncomment / wire `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` in `lib/bootstrap.dart`
  - Fail-soft via `FirebaseBootstrap.initialize()` — never blocks Drift/ledger if init fails
  - Enables Crashlytics collection on success; `configureGlobalErrorHandling()` runs after init
- [x] Wire Analytics collection to `AppSettings.analyticsEnabled` (default on; honour opt-out)
  - `FirebaseAnalyticsConsent.apply` on cold start + `SettingsPreferences.setAnalyticsEnabled`
- [x] Add `firebase_messaging` dependency; scaffold token obtain + permission request (full token registry + send path lands in Stage 11.0)
  - `FcmTokenScaffold.initialize()` from deferred `main.dart` post-frame bootstrap (Android-ready; iOS APNs Delayed)

**0.3.2.1 Firebase Preflight Smoke Test**

> Owner device/console verification — **all items passed 2026-08-12** on SM G990U.

- [x] Force a test non-fatal / crash → verify event appears in Crashlytics console within minutes
  - Verified: harness non-fatal `daftar_crashlytics_smoke` (reason `0.3.2.1`)
- [x] Log a DebugView Analytics event → verify in Firebase DebugView
  - Verified with phone VPN (YE Wi‑Fi alone timed out FA uploads): DebugView showed `daftar_analytics_smoke` (+ `screen_view` / `user_engagement`); FA-SVC `Successful upload … 204` for `com.akrmcodes.daftar`
  - Consent: `setAnalyticsCollectionEnabled` + `setConsent(analyticsStorageConsentGranted: …)`
- [x] Send an FCM console test message to a physical device token → verify delivery (Android; iOS once APNs configured)
  - Verified: Console test → device notification via `FcmTokenScaffold` token
- [x] Confirm app remains fully usable if Firebase init fails (offline-first — never block ledger CRUD)
  - Code: [`FirebaseBootstrap.initialize`](lib/core/services/firebase_bootstrap.dart) never rethrows; ledger usable during smoke

**Normal development:** omit `DAFTAR_FIREBASE_SMOKE` (harness is off). Never leave the define on for release builds.

**0.4 Directory Skeleton**

- [x] Create `lib/app/` — `app.dart`, `router/`, `theme/`
- [x] Create `lib/core/` — `constants/`, `errors/`, `extensions/`, `utils/`, `l10n/`
- [x] Create `lib/domain/` — `entities/`, `enums/`, `repositories/`, `value_objects/`
- [x] Create `lib/application/` — `ledger/`, `contact/`, `transaction/`, `backup/`, `import/`, `auth/`, `merchant/`
- [x] Create `lib/data/` — `models/`, `mappers/`, `datasources/local/`, `datasources/remote/`, `repositories/`
- [x] Create `lib/presentation/` — `providers/`, `screens/`, `shared/widgets/`, `shared/animations/`
- [x] Create `lib/bootstrap.dart` — Drift DB init, Firebase init, provider overrides
- [x] Create `lib/main.dart` — entry point with `ProviderScope`

**0.5 Theming & Design Tokens**

- [x] Create `app_colors.dart` — full color palette (dark default + light), semantic tokens
- [x] Create `app_text_styles.dart` — Arabic-optimized typography scale (Noto Kufi Arabic + Inter)
- [x] Create `app_dimensions.dart` — spacing, radius, elevation, tap target sizes (≥ 48dp)
- [x] Create `app_theme.dart` — `ThemeData` for dark and light modes using tokens
- [x] Verify RTL rendering with Arabic text in both themes

**0.6 Localization Setup**

- [x] Create `app_ar.arb` (Arabic — default locale) with initial string keys
- [x] Create `app_en.arb` (English) with matching keys
- [x] Configure `l10n.yaml` for ARB code generation
- [x] Verify locale switching works (AR ↔ EN) with RTL/LTR layout change

**0.7 Routing Shell**

- [x] Configure `app_router.dart` with `GoRouter` and `ShellRoute` for bottom tab navigation
- [x] Define `route_names.dart` with all named route constants
- [x] Create placeholder screens for: Home, Ledger Detail, Contact Detail, Settings
- [x] Verify deep-link structure and back-navigation behavior

**0.8 CI / Build Verification**

- [x] Ensure `flutter analyze` passes with zero warnings
- [x] Ensure `flutter test` runs (even with zero tests)
- [x] Ensure `dart run build_runner build` generates Drift/Riverpod/Freezed code cleanly
- [x] Ensure `flutter build apk --split-per-abi` succeeds
- [x] Document build instructions in `README.md`

#### Stage 0 Validation Gate

- [x] A developer can clone the repo, run `flutter pub get && dart run build_runner build`, and build a debug APK in < 5 minutes.
- [x] Google Sign-In preflight smoke test (0.3.1) passes on at least one physical Android device and one iOS device.
- [x] Firebase preflight smoke test (0.3.2.1) passes: Crashlytics receives a test event, Analytics DebugView shows an event, FCM test push arrives on a physical Android device.
- [x] `Firebase.initializeApp` is live (not commented); `google-services.json`, `GoogleService-Info.plist`, and `firebase_options.dart` exist.
- [x] All CI checks (analyze, test, build) pass.

---

### Stage 1: Core Domain Layer & Database Foundation (MVP)

**Goal:** Define all domain entities, value objects, enums, failure types, and the complete Drift database schema. This stage produces zero UI — it is the foundational data contract. `MerchantProfile` is included as a pure data model and persistence layer only; its UI and PDF wiring are deferred to Stage 6.3.

**Prerequisites:** Stage 0 complete (project scaffold, directory skeleton, dependencies installed).

**Features from Product Plan:**

- Multi-Ledger System (schema)
- Core Transaction Engine (schema)
- Multi-Currency (schema)
- Credit Limits (schema)
- Contact Management (schema)
- Merchant Branding (schema and data layer only — no UI, no PDF wiring)
- Google Auth identity (domain interface only — implementation deferred to Stage 4.5)

**Integration / Architecture Notes:**

- Domain layer is pure Dart — zero Flutter/Drift imports
- Drift tables map 1:1 to domain entities via mappers in the data layer
- All monetary amounts stored as integers (smallest currency unit)
- UUIDs (v4) for all primary keys
- Soft-delete (`isDeleted`) + `syncVersion` on all mutable entities
- `MerchantProfile` exists as entity, repository interface, Drift table, mapper, local data source, and repository implementation — all purely local persistence. No use cases, providers, or screens are created here.
- `AuthRepository` exists as a pure-Dart domain interface only. Its implementation (`auth_repository_impl.dart`) depends on `google_sign_in` and is created in Stage 4.5 where it is first consumed.
- `BackupType` enum uses `googleDrive` instead of `cloud`
- `AppSettings` carries optional Google account identity fields (`googleAccountId?`, `googleAccountEmail?`)

#### Task Checklist

**1.1 Domain Enums**

- [x] Create `lib/domain/enums/ledger_type.dart` — `customers`, `suppliers`, `personal`, `custom`
- [x] Create `lib/domain/enums/transaction_type.dart` — `debt`, `payment`
- [x] Create `lib/domain/enums/backup_type.dart` — `local`, `googleDrive`

**1.2 Domain Value Objects**

- [x] Create `lib/domain/value_objects/money.dart` — `Money` (amount as `int` + `currencyCode`), arithmetic ops, display formatting
- [x] Create `lib/domain/value_objects/phone_number.dart` — validation, normalization, WhatsApp deep-link generation
- [x] Write unit tests for `Money` arithmetic (addition, comparison, edge cases with different currencies)
- [x] Write unit tests for `PhoneNumber` normalization (Yemeni formats, Saudi formats, with/without country code)

**1.3 Domain Entities (Freezed)**

- [x] Create `lib/domain/entities/ledger.dart` — `id`, `name`, `type`, `icon`, `color`, `sortOrder`, `createdAt`, `updatedAt`, `isDeleted`, `syncVersion`
- [x] Create `lib/domain/entities/contact.dart` — `id`, `ledgerId`, `name`, `phone?`, `notes?`, `creditLimit?`, `creditCurrency?`, `avatarColor`, timestamps, soft-delete, sync fields
- [x] Create `lib/domain/entities/transaction.dart` — `id`, `contactId`, `type`, `amount`, `currency`, `description?`, `itemName?`, timestamps, soft-delete, sync fields, `attachmentPath?`
- [x] Create `lib/domain/entities/currency.dart` — `id`, `code`, `symbol`, `nameAr`, `nameEn`, `decimalPlaces`, `isBuiltIn`, `isActive`
- [x] Create `lib/domain/entities/contact_balance.dart` — `contactId`, `currencyId`, `totalDebt`, `totalPayment`, `netBalance`, `lastUpdatedAt`
- [x] Create `lib/domain/entities/activation_code.dart` — `id`, `code`, `activatedAt`, `expiresAt`, `tier` (FREE/PRO/PRO_PLUS)
- [x] Create `lib/domain/entities/app_settings.dart` — `locale`, `themeMode`, `pinHash?`, `biometricEnabled`, `defaultCurrency`, `lastBackupAt`, `analyticsEnabled`, `googleAccountId?`, `googleAccountEmail?`
- [x] Create `lib/domain/entities/backup_metadata.dart` — `id`, `filePath`, `sizeBytes`, `createdAt`, `type` (LOCAL/GOOGLE_DRIVE), `checksum`, `googleDriveFileId?`
- [x] Create `lib/domain/entities/audit_log.dart` — `id`, `entityType`, `entityId`, `action`, `payload`, `timestamp`, `deviceId`
- [x] Create `lib/domain/entities/merchant_profile.dart` — `id`, `storeName`, `storePhone?`, `logoPath?`, `createdAt`, `updatedAt` (data model only — UI deferred to Stage 6.3)

**1.4 Domain Failures**

- [x] Create `lib/core/errors/failures.dart` — sealed `Failure` class: `DatabaseFailure`, `ValidationFailure`, `NetworkFailure`, `StorageFailure`, `AuthFailure`, `LimitExceededFailure`
- [x] Create `lib/core/errors/exceptions.dart` — data-layer exceptions that map to failures

**1.5 Domain Repository Interfaces**

- [x] Create `lib/domain/repositories/ledger_repository.dart` — CRUD + `watchAll()`, `getById()`
- [x] Create `lib/domain/repositories/contact_repository.dart` — CRUD + `watchByLedger()`, `search()`, `getById()`
- [x] Create `lib/domain/repositories/transaction_repository.dart` — CRUD + `watchByContact()`, `getByContact()`, `getByDateRange()`
- [x] Create `lib/domain/repositories/currency_repository.dart` — `getAll()`, `getBuiltIn()`, `addCustom()`, `toggleActive()`
- [x] Create `lib/domain/repositories/balance_repository.dart` — `getByContact()`, `watchByContact()`, `recalculate()`
- [x] Create `lib/domain/repositories/backup_repository.dart` — `createLocal()`, `restoreLocal()`, `uploadToDrive()`, `downloadFromDrive()`, `listDriveBackups()`, `listLocalBackups()`
- [x] Create `lib/domain/repositories/settings_repository.dart` — `get()`, `update()`, `watchSettings()`
- [x] Create `lib/domain/repositories/activation_repository.dart` — `activate()`, `getStatus()`, `isFeatureUnlocked()`
- [x] Create `lib/domain/repositories/audit_log_repository.dart` — `append()`, `getByEntity()`, `getRecent()`
- [x] Create `lib/domain/repositories/merchant_profile_repository.dart` — `get()`, `update()`, `setLogo()`, `clearLogo()` (pure Dart interface — UI deferred to Stage 6.3)
- [x] Create `lib/domain/repositories/auth_repository.dart` — `signInWithGoogle()`, `signOut()`, `getSignedInAccount()`, `isSignedIn()`, `signInSilently()` (pure Dart interface — implementation deferred to Stage 4.5)

**1.6 Core Utilities**

- [x] Create `lib/core/utils/money_util.dart` — `int` ↔ display string conversion using `Currency.decimalPlaces`
- [x] Create `lib/core/utils/uuid_util.dart` — UUID v4 generation wrapper
- [x] Create `lib/core/utils/date_util.dart` — Hijri/Gregorian helpers, relative date formatting (Arabic)
- [x] Create `lib/core/utils/validators.dart` — input validation (amount, name, phone, currency code)
- [x] Create `lib/core/extensions/string_extensions.dart` — Arabic normalization (strip diacritics, normalize Alef/Taa Marbuta)
- [x] Create `lib/core/extensions/num_extensions.dart` — currency formatting extensions
- [x] Create `lib/core/extensions/context_extensions.dart` — `BuildContext` helpers (theme, locale, screen size)
- [x] Create `lib/core/constants/app_constants.dart` — free tier limits (1 ledger, 50 contacts, 500 transactions), defaults
- [x] Create `lib/core/constants/db_constants.dart` — schema version, table names

**1.7 Drift Database Schema**

- [x] Create `lib/data/datasources/local/drift_database.dart` — main `@DriftDatabase` class with all table references
- [x] Define `Ledgers` Drift table with all columns, indexes on `isDeleted` and `sortOrder`
- [x] Define `Contacts` Drift table with FK to `Ledgers`, indexes on `ledgerId`, `name`, `isDeleted`
- [x] Define `Transactions` Drift table with FK to `Contacts`, indexes on `contactId`, `createdAt`, `isDeleted`
- [x] Define `Currencies` Drift table with unique constraint on `code`
- [x] Define `ContactBalances` Drift table with composite key (`contactId`, `currencyId`)
- [x] Define `BackupMetadatas` Drift table with `type` column supporting `LOCAL` and `GOOGLE_DRIVE` values, optional `googleDriveFileId` column
- [x] Define `AppSettingsTable` Drift table (single-row) with `googleAccountId` and `googleAccountEmail` columns
- [x] Define `ActivationCodes` Drift table with `tier` column supporting `FREE`, `PRO`, `PRO_PLUS`
- [x] Define `AuditLogs` Drift table with indexes on `entityType`+`entityId` and `timestamp`
- [x] Define FTS5 virtual table for Arabic contact name search
- [x] Create schema version 1 migration
- [x] Seed built-in currencies (YER, SAR, USD) on first launch
- [x] Run `build_runner` and verify generated `.g.dart` files compile
- [x] Define `MerchantProfiles` Drift table — `id`, `storeName`, `storePhone?`, `logoPath?`, timestamps

**1.8 Data Layer — Models & Mappers**

- [x] Create `lib/data/models/ledger_model.dart` — Drift companion ↔ domain `Ledger` mapping
- [x] Create `lib/data/models/contact_model.dart` — Drift companion ↔ domain `Contact` mapping
- [x] Create `lib/data/models/transaction_model.dart` — Drift companion ↔ domain `Transaction` mapping
- [x] Create `lib/data/mappers/ledger_mapper.dart` — `toDomain()` / `toCompanion()` extensions
- [x] Create `lib/data/mappers/contact_mapper.dart`
- [x] Create `lib/data/mappers/transaction_mapper.dart`
- [x] Create `lib/data/mappers/currency_mapper.dart`
- [x] Write unit tests for all mappers (round-trip: entity → companion → entity)
- [x] Create `lib/data/mappers/merchant_profile_mapper.dart`

**1.9 Data Layer — Local Data Sources**

- [x] Create `lib/data/datasources/local/ledger_local_ds.dart` — Drift CRUD queries for Ledgers
- [x] Create `lib/data/datasources/local/contact_local_ds.dart` — Drift CRUD + FTS search queries
- [x] Create `lib/data/datasources/local/transaction_local_ds.dart` — Drift CRUD + date-range queries
- [x] Create `lib/data/datasources/local/currency_local_ds.dart` — built-in + custom currency queries
- [x] Create `lib/data/datasources/local/balance_local_ds.dart` — balance aggregation + recalculation
- [x] Create `lib/data/datasources/local/settings_local_ds.dart` — single-row settings read/write
- [x] Create `lib/data/datasources/local/audit_log_local_ds.dart` — append-only log writes
- [x] Create `lib/data/datasources/local/merchant_profile_local_ds.dart` — CRUD for merchant profile (local persistence only)

**1.10 Data Layer — Repository Implementations**

- [x] Create `lib/data/repositories/ledger_repository_impl.dart` — implements `LedgerRepository`, delegates to local DS + audit log
- [x] Create `lib/data/repositories/contact_repository_impl.dart` — includes free-tier limit check (50 contacts)
- [x] Create `lib/data/repositories/transaction_repository_impl.dart` — updates `ContactBalance` on every write, free-tier limit (500 txns), audit log
- [x] Create `lib/data/repositories/currency_repository_impl.dart`
- [x] Create `lib/data/repositories/balance_repository_impl.dart`
- [x] Create `lib/data/repositories/settings_repository_impl.dart`
- [x] Create `lib/data/repositories/audit_log_repository_impl.dart`
- [x] Write integration tests: CRUD lifecycle for Ledger → Contact → Transaction with balance verification
- [x] Create `lib/data/repositories/merchant_profile_repository_impl.dart` — implements `MerchantProfileRepository`, manages logo file in app documents directory (pure local — no cloud, no UI)

> [!NOTE]
> `auth_repository_impl.dart` is NOT created in this stage. It depends on `google_sign_in` and `google_auth_ds.dart`, both of which are built in Stage 4.5 where authentication is first consumed. The pure-Dart `AuthRepository` interface (Stage 1.5) establishes the contract; the implementation follows when the dependency is available.

#### Stage 1 Validation Gate

- [x] All domain entities compile and pass Freezed code generation.
- [x] All Drift tables generate correctly and schema version 1 migration runs.
- [x] All mappers pass round-trip tests (entity → companion → entity).
- [x] MerchantProfile CRUD works via local data source and repository (no UI required).
- [x] `MerchantProfile` has no imports from `presentation/`, `application/`, or `pdf`.

---

### Stage 1.5: Data Integrity & Architectural Hardening (MVP)

**Goal:** Lock down data integrity invariants without changing the presentation-layer contract.

**Prerequisites:** Stage 1 complete.

**Integration / Architecture Notes:**

- Free-tier counts now fail closed via `Either<Failure, int>` instead of returning `0` on repository errors.
- Parent entity validation now runs before contact and transaction creation to prevent children under soft-deleted parents.
- Single-entity contact reads and ledger balance summaries now flow through dedicated use cases.
- Transaction item autocomplete now uses Arabic-normalized matching in the local data source instead of `LOWER(itemName)`.

#### Task Checklist

**1.5.1 Critical Data Integrity**

- [x] Refactor free-tier count methods in `contact_repository_impl.dart`, `ledger_repository_impl.dart`, and `transaction_repository_impl.dart` to fail closed with `DatabaseFailure` on query errors.
- [x] Update `CreateLedgerUseCase`, `CreateContactUseCase`, and `AddTransactionUseCase` to handle fail-closed count results explicitly.
- [x] Add active-parent preflight checks to `CreateContactUseCase` (ledger) and `AddTransactionUseCase` (contact) before any insert.

**1.5.2 Architectural Boundaries**

- [x] Create `GetContactByIdUseCase` and route `contactByIdProvider` through it instead of calling the repository directly.
- [x] Create `GetLedgerBalanceSummaryUseCase` and route `ledgerBalanceSummaryProvider` through it as a snapshot boundary.
- [x] Add `ContactRepository.getByLedger(...)` to support the ledger balance summary use case without direct provider-level repository access.

**1.5.3 Autocomplete & Audit Provenance**

- [x] Replace `LOWER(itemName)` autocomplete filtering with Arabic-normalized matching in `transaction_local_ds.dart` and `transaction_repository_impl.dart`.
- [x] Add `// TODO: AI Audit` markers to the cascade delete and restore paths in contact and ledger repositories for child-level provenance follow-up.

---

### Stage 2: Ledger & Contact Management (MVP)

**Goal:** Build the full Ledger and Contact management flows — from use cases through Riverpod providers to completed UI screens. Users can create ledgers, add contacts, search, and manage their contact list.

**Prerequisites:** Stage 1 + Stage 1.5 complete.

**Features from Product Plan:**

- Multi-Ledger System
- Contact Management
- Smart Autocomplete (history-based contacts)
- Dynamic Balance Card (ledger-level summary)
- Localization (AR/EN with RTL)

**Integration / Architecture Notes:**

- Riverpod `AsyncNotifier` providers watch Drift reactive streams via `watchAll()` / `watchByLedger()`
- Free-tier enforcement: max 1 ledger for free users (checked in use case layer)
- Arabic FTS search via Drift FTS5 for contact name lookup
- All UI follows bottom-sheet-centric, one-handed design

#### Task Checklist

**2.1 Application Layer — Ledger Use Cases**

- [x] Create `lib/application/ledger/create_ledger_use_case.dart` — validates name, enforces free-tier limit (1 ledger), returns `Either<Failure, Ledger>`
- [x] Create `lib/application/ledger/get_ledgers_use_case.dart` — streams all non-deleted ledgers sorted by `sortOrder`
- [x] Create `lib/application/ledger/update_ledger_use_case.dart` — name, icon, color, sort order
- [x] Create `lib/application/ledger/delete_ledger_use_case.dart` — soft-delete with cascade confirmation (warns about child contacts/transactions)
- [x] Write unit tests for all ledger use cases (mock repository)

**2.2 Application Layer — Contact Use Cases**

- [x] Create `lib/application/contact/create_contact_use_case.dart` — validates name uniqueness within ledger, enforces free-tier limit (50 contacts)
- [x] Create `lib/application/contact/get_contacts_use_case.dart` — streams contacts for a ledger, supports sort (name, balance, recent activity)
- [x] Create `lib/application/contact/search_contacts_use_case.dart` — Arabic-normalized FTS search via Drift
- [x] Create `lib/application/contact/update_contact_use_case.dart` — update name, phone, notes, credit limit
- [x] Create `lib/application/contact/delete_contact_use_case.dart` — soft-delete with transaction cascade warning
- [x] Create `lib/application/contact/check_credit_limit_use_case.dart` — compares current balance vs. limit, returns warning level
- [x] Write unit tests for all contact use cases

**2.3 Riverpod Providers**

- [x] Create `lib/presentation/providers/ledger_providers.dart`:
  - `ledgersProvider` — watches `GetLedgersUseCase`
  - `selectedLedgerIdProvider` — simple notifier for currently viewed ledger ID
  - `ledgerControllerProvider` — mutation provider for create/update/delete
- [x] Create `lib/presentation/providers/contact_providers.dart`:
  - `contactsProvider(ledgerId)` — family provider watching contacts stream for a ledger
  - `contactSearchQueryProvider` — search text state
  - `contactSearchResultsProvider` — watches `SearchContactsUseCase` from the current query
  - `selectedContactIdProvider` — simple notifier for detail view
  - `contactControllerProvider` — mutation provider for create/update/delete
- [x] Create `lib/presentation/providers/balance_providers.dart`:
  - `ledgerBalanceSummaryProvider(ledgerId)` — aggregated balance across all contacts in a ledger
  - `contactBalanceProvider(contactId)` — per-contact per-currency balances
- [x] Create `lib/presentation/providers/theme_provider.dart` — dark/light toggle, persists to settings
- [x] Create `lib/presentation/providers/locale_provider.dart` — AR/EN toggle, persists to settings
- [x] Run `build_runner` to generate Riverpod code

**2.4 Shared UI Components**

- [x] Create `lib/presentation/shared/widgets/app_bottom_sheet.dart` — reusable bottom-sheet wrapper with drag handle, RTL-aware
- [x] Create `lib/presentation/shared/widgets/currency_selector.dart` — dropdown/chip selector for active currencies
- [x] Create `lib/presentation/shared/widgets/search_bar.dart` — Arabic-optimized search with debounce, clear button
- [x] Create `lib/presentation/shared/widgets/empty_state.dart` — illustrated empty state with localized message + CTA
- [x] Create `lib/presentation/shared/widgets/limit_warning_banner.dart` — free-tier limit approaching/reached banner
- [x] Create `lib/presentation/shared/animations/fade_slide_transition.dart` — reusable enter/exit animation

**2.5 Home Screen**

- [x] Create `lib/presentation/screens/home/home_screen.dart` — scaffold with bottom nav, app bar with search + settings
- [x] Create `lib/presentation/screens/home/widgets/balance_card.dart` — animated summary: total owed (red) vs total merchant owes (green), per-currency breakdown, tap to expand
- [x] Create `lib/presentation/screens/home/widgets/ledger_list_tile.dart` — ledger name, icon, contact count, balance summary chip
- [x] Create Quick Add Transaction Bottom Sheet (`quick_add_bottom_sheet.dart`) — premium sheet from the main-shell FAB with smart contact-name autocomplete (Mohammed Logic ledger resolution), sliding segmented Debt عليه / Payment له control, and one-tap save
- [x] Implement pull-to-refresh behavior
- [x] Implement ledger reordering (drag-and-drop)

**2.6 Ledger Detail Screen**

- [x] Create `lib/presentation/screens/ledger/ledger_detail_screen.dart` — contact list for selected ledger, sort controls, search
- [x] Create `lib/presentation/screens/ledger/widgets/contact_list_tile.dart` — name, net balance (colored), last activity date
- [x] Create "Add Contact" bottom sheet — name (required), phone (optional), notes, credit limit, credit currency
- [x] Create "Edit Ledger" bottom sheet — rename, change icon/color
- [x] Implement swipe-to-delete with undo snackbar
- [x] Implement contact sorting (alphabetical, by balance, by recent activity)

**2.7 Contact Detail Screen (Basic — Transaction UI in Stage 3)**

- [x] Create `lib/presentation/screens/contact/contact_detail_screen.dart` — header with name, phone, balance summary; transaction list placeholder
- [x] Create `lib/presentation/screens/contact/widgets/balance_summary.dart` — per-currency balance display
- [x] Create "Edit Contact" bottom sheet
- [x] Implement WhatsApp deep-link button (phone → `wa.me/{phone}`)
- [x] Implement "Call" button via `url_launcher` (if phone present)

---

### Stage 3: Transaction Engine & Dynamic Balances (MVP)

**Goal:** Build the complete transaction recording flow — add debt (عليه), record payment (له), edit, delete with undo. Implement real-time balance updates and credit limit warnings.

**Prerequisites:** Stage 2 complete.

**Features from Product Plan:**

- Core Transaction Engine
- Multi-Currency balances
- Dynamic Balance Card
- Credit Limits & Warnings
- Smart Autocomplete (item names, recent prices)

**Integration / Architecture Notes:**

- Transactions update `ContactBalance` in the same Drift transaction (atomic)
- Credit limit checks fire on every debt transaction insert
- `flutter_local_notifications` for 80% and 100% credit limit breach
- Smart autocomplete queries recent `itemName` + `amount` from transaction history

#### Task Checklist

**3.1 Application Layer — Transaction Use Cases**

- [x] Create `lib/application/transaction/add_transaction_use_case.dart` — validates amount > 0, enforces free-tier limit (500 txns), updates `ContactBalance` atomically, checks credit limit post-insert, appends audit log
- [x] Create `lib/application/transaction/get_transactions_use_case.dart` — streams transactions for a contact, supports pagination (20/page), date filtering
- [x] Create `lib/application/transaction/update_transaction_use_case.dart` — recalculates balance after edit
- [x] Create `lib/application/transaction/delete_transaction_use_case.dart` — soft-delete + balance recalculation
- [x] Create `lib/application/transaction/calculate_balance_use_case.dart` — full recalculation from raw transactions (used for integrity verification)
- [x] Create `lib/application/transaction/get_autocomplete_suggestions_use_case.dart` — recent item names + last price for selected item
- [x] Write unit tests for all transaction use cases, especially balance atomicity and credit limit checks

**3.2 Riverpod Providers — Transactions**

- [x] Create `lib/presentation/providers/transaction_providers.dart`:
  - `transactionsProvider(contactId)` — paginated stream of transactions
  - `addTransactionProvider` — mutation provider with loading/error states
  - `autocompleteSuggestionsProvider(query)` — debounced item name suggestions
  - `recentPriceProvider(itemName)` — last recorded price for an item
- [x] Update `balance_providers.dart` with real-time reactivity after transaction mutations

**3.3 Transaction UI**

- [x] Create `lib/presentation/screens/transaction/add_transaction_sheet.dart` — bottom sheet:
  - Transaction type toggle (Debt عليه / Payment له) with clear visual distinction (red/green)
  - Amount input with large numeric keyboard, currency selector
  - Item name input with autocomplete dropdown
  - Description (optional) text field
  - Date picker (defaults to now, allows backdating)
  - "Save" button with haptic feedback
- [x] Create `lib/presentation/screens/contact/widgets/transaction_list_tile.dart`:
  - Type indicator (debt=red, payment=green)
  - Amount with currency symbol
  - Item name, description, date
  - Running balance after transaction
- [x] Implement transaction editing via bottom sheet (pre-populated fields)
- [x] Implement swipe-to-delete with undo snackbar (5-second undo window)
- [x] Implement pull-to-load-more pagination
- [x] Add transaction date grouping headers (Today, Yesterday, This Week, etc. — localized)

**3.4 Credit Limit Warnings**

- [x] Implement credit limit check in `add_transaction_use_case.dart` — fires after successful debt insert
- [x] Create notification service wrapper around `flutter_local_notifications`
- [x] Fire local notification at 80% credit utilization with localized Arabic message
- [x] Fire local notification at 100% credit utilization (limit breached) with urgent priority
- [x] Show in-app banner on Contact Detail screen when credit limit is near/breached
- [x] Configure notification channels for Android API 26+ (importance levels)

**3.5 Dynamic Balance Card Polish**

- [x] Implement animated number transitions on `balance_card.dart` (count-up animation)
- [x] Add per-currency breakdown with horizontal scroll chips
- [x] Add "Tap to see breakdown" expand/collapse animation
- [x] Implement color-coded net balance (red = owed to merchant, green = merchant owes)
- [x] Verify balance card updates reactively on transaction add/edit/delete

---

### Stage 4: Reports, Import/Export & Backup (MVP)

**Goal:** Generate PDF statements, share via WhatsApp, import from CSV (free for all tiers), and implement local + cloud (Google Drive) backup with full retry and error handling.

**Prerequisites:** Stage 3 complete. Stage 0.3.1 preflight validation passed (required for 4.5).

**Features from Product Plan:**

- WhatsApp PDF Reports
- CSV Import (free for all tiers)
- Local Backup
- Cloud Backup (Google Drive)

**Integration / Architecture Notes:**

- PDF generation runs in a Dart isolate to avoid UI jank
- PDF generator accepts an optional `MerchantProfile?` parameter for forward compatibility with Stage 6.3 branded headers; defaults to app-name-only header when null
- WhatsApp sharing via deep-link + system share sheet for PDF attachment
- CSV import is a 100% free feature — no tier gating on the import operation itself; workspace limits (1/50/500) govern how many imported records can be activated
- Cloud backup: encrypted `.daftar` file uploaded to user's Google Drive `appdata` folder via `googleapis` Drive v3 API
- Google Sign-In (implemented here in 4.5) provides both auth identity and Drive access
- Logo file is bundled inside `.daftar` backup files to preserve branding across restore/device migration

#### Task Checklist

**4.1 PDF Generation**

- [x] Create `lib/core/utils/pdf_generator.dart` — generates Arabic RTL and English LTR PDF statement using `pdf` package
- [x] Implement per-contact statement template: header (date range), contact info, transaction table, running balance, final summary
- [x] Support multi-currency statements (one section per currency)
- [x] Run PDF generation in isolate (`Isolate.run()`) with progress callback
- [x] Write test: generate PDF for 500-transaction contact, verify output is valid PDF
- [x] Accept optional `MerchantProfile?` parameter in `pdf_generator.dart`: when non-null and logo/name data is present, render branded header; when null, render default app-name-only header. This parameter is a forward-compatible hook — actual merchant data is wired in Stage 6.3.

**4.2 WhatsApp Sharing**

- [x] Create `lib/core/utils/whatsapp_util.dart` — deep-link builder for `wa.me/{phone}`
- [x] Implement share flow: generate PDF → save to temp dir → share via `share_plus` with WhatsApp package targeting
- [x] Implement fallback chain: WhatsApp Business → WhatsApp → generic share sheet
- [x] Add "Share Statement" button on Contact Detail screen
- [x] Add date range selector for statement period

**4.3 CSV Import (Free for All Tiers)**

- [x] Create `lib/application/import/import_csv_use_case.dart` — parse CSV, map columns, validate rows, insert contacts + transactions
- [x] Create `lib/core/utils/csv_parser.dart` — handles UTF-8 and Windows-1256 auto-detection
- [x] Create `lib/presentation/screens/settings/import_csv_screen.dart`:
  - File picker for `.csv` files
  - Preview first 5 rows
  - Column mapping UI (drag-drop or dropdown: which CSV column maps to name, phone, amount, etc.)
  - Encoding selector (auto / UTF-8 / Windows-1256)
  - Import progress bar
  - Summary: X contacts imported, Y transactions imported, Z rows skipped (with reasons)
- [x] Handle duplicate detection during import (same name + phone = merge or skip, user chooses)
- [x] Write tests for CSV parsing with Arabic text and English in both encodings

> [!NOTE]
> CSV Import is a **100% free feature**. No tier check gates the import operation. Imported rows land in the live workspace subject to existing free-tier limits (1 ledger, 50 contacts, 500 transactions). If workspace limits are exceeded, excess imports are stored but marked as archived. `ActivateArchivedImportsUseCase` later promotes archived rows into the live workspace after a tier upgrade or capacity increase; no separate import tier gate exists.

**4.4 Local Backup**

- [x] Create `lib/application/backup/create_local_backup_use_case.dart` — export Drift DB as encrypted `.daftar` file
- [x] Create `lib/application/backup/restore_backup_use_case.dart` — decrypt, validate checksum, replace DB, restart
- [x] Implement silent AES-256 encryption using an obfuscated app-bound key (via envied) and include a versioning header for future migration.
- [x] Create `lib/presentation/screens/settings/backup_screen.dart`:
  - "Create Backup" button with progress
  - List of local backups with date, size
  - "Restore from Backup" with file picker and confirmation dialog (warns about data overwrite)
  - Auto-backup reminder setting (weekly/monthly)
- [x] Store `BackupMetadata` in DB for backup history — implemented in `backup_repository_impl.dart` with `listBackups()` and new `deleteBackup()` method
- [x] Create `lib/presentation/providers/backup_providers.dart` — `BackupNotifier` (AsyncNotifier) managing `BackupState`, wiring `backupRepositoryProvider`, `createLocalBackupUseCaseProvider`, `restoreBackupUseCaseProvider`
- [x] Register `/settings/backup` route in `app_router.dart` and link from `settings_screen.dart`
- [x] Write integration test: create backup → clear DB → restore → verify all data intact
- [Delayed] Bundle merchant logo file inside `.daftar` backup archive (if present) for cross-device branding preservation

**4.5 Cloud Backup (Google Drive) — Full Specification**

> [!NOTE]
> **Auth V2 Epic — Successfully Shipped (June 2026).** The June 2026 Nuclear Auth Reset purged Auth V1 (~55 lib files) after the **Amnesia Bug** (Drift `googleAccountId` without a live SDK session). Auth V2 rebuilt Google Sign-In + Drive auto-backup with a persistence-first architecture. Checkboxes below retain the original Stage 4.5 specification for reference; the live implementation follows Auth V2 patterns:
>
> | Architectural win | Implementation |
> |---|---|
> | **Amnesia fix** | `AuthSessionBundle` in `flutter_secure_storage` is the authoritative session record; Drift `googleAccountId` is a denormalized UI hint only |
> | **Headless isolates** | `BackgroundSyncExecutor` reads the bundle directly — zero interactive `signIn()` from WorkManager |
> | **Riverpod state machine** | `authStateProvider` derives from `AuthSessionState` (`linked` / `unlinked` / `migrationRelinkRequired` / `needsReauth`) |
> | **Strict OS resilience** | `SessionBootstrapUseCase` on cold start; `needsReauth` degrades cloud features without blocking ledger CRUD |

**4.5.1 Google Auth Data Source & Repository**

- [x] Create `lib/data/datasources/remote/google_auth_ds.dart`:
  - Initialize `GoogleSignIn` with scopes: `[DriveApi.driveAppdataScope]`
  - `signIn()` — trigger interactive Google Sign-In flow, return `GoogleSignInAccount`
  - `signInSilently()` — attempt non-interactive sign-in for returning users (called on app startup and before every Drive operation)
  - `signOut()` — disconnect and clear auth state
  - `getAuthenticatedHttpClient()` — return `AuthClient` HTTP client using `GoogleSignInAccount.authHeaders` for Drive API calls
  - `isSignedIn()` — check current sign-in status synchronously
  - `getAccount()` — return current `GoogleSignInAccount` or null
- [x] Create `lib/data/repositories/auth_repository_impl.dart`:
  - Implements `AuthRepository` interface (defined in Stage 1.5)
  - Wraps `google_auth_ds.dart`
  - On sign-in: persist `googleAccountId` and `googleAccountEmail` to `AppSettings` via `SettingsRepository`
  - On sign-out: clear Google account fields from `AppSettings`; invalidate cached Drive file IDs in `BackupMetadata`
  - Map `google_sign_in` exceptions to `AuthFailure` variants

**4.5.2 Google Drive Backup Data Source**

- [x] Create `lib/data/datasources/remote/google_drive_backup_ds.dart`:
  - Accepts authenticated HTTP client from `google_auth_ds.dart`
  - `uploadBackup(File encryptedFile, {required Map<String, String> metadata})`:
    - Upload `.daftar` file to `appDataFolder` using Drive v3 `files.create` with `parents: ['appDataFolder']`
    - Use resumable upload for files > 5MB (`ResumableUploadOptions`); default upload for smaller files
    - Embed caller-supplied key/value pairs on the Drive file as `appProperties` (e.g. `appVersion`, `schemaVersion`, `checksum`, `backupTimestamp`)
    - Return created `drive.File` (includes id, `appProperties`, timestamps)
  - `listBackups()`:
    - Query `appDataFolder` for `.daftar` files with `q`, `spaces`, `trashed = false`, and paginated `files.list`
    - Partial response `$fields` includes `appProperties`; results sorted by `modifiedTime` descending
  - `downloadBackup(String fileId, String savePath)`:
    - Download via `files.get` with `DownloadOptions.fullMedia` (alt=media)
    - Stream `Media.stream` into `File(savePath).openWrite()` using `pipe` (no in-memory buffer of full file)
    - Return saved `File`
  - `deleteBackup(String fileId)`:
    - Delete file by ID via `files.delete`
    - Used for managing user's Drive quota from within the app

**4.5.3 Backup Use Cases**

- [x] Create `lib/application/backup/upload_drive_backup_use_case.dart`:
  - Check Google Sign-In status via `AuthRepository.isSignedIn()`
  - If not signed in: return `Left(AuthFailure.notSignedIn)` — caller must prompt sign-in
  - Attempt silent token refresh via `AuthRepository.signInSilently()` before proceeding
  - Create local backup → encrypt → upload to Google Drive
  - Store `BackupMetadata` locally with `type: BackupType.googleDrive`, `googleDriveFileId`, upload timestamp, account email
  - Return `Either<Failure, BackupMetadata>`
- [x] Create `lib/application/backup/download_drive_backup_use_case.dart`:
  - Check Google Sign-In status; attempt silent re-auth if token stale
  - List available Drive backups for user selection
  - Download selected backup → decrypt → validate checksum → restore
  - Return `Either<Failure, Unit>`

**4.5.4 Retry Policy & Queue Persistence**

- [x] Create `lib/core/utils/backup_retry_policy.dart`:
  - Exponential backoff: base delay 2s, multiplier 2x, max delay 5 minutes
  - Jitter: ±25% randomization on each delay to prevent thundering herd
  - Max retry attempts: 5
  - After final failure: mark operation as `failed`, emit `BackupFailure` with user-facing message
- [x] Persist pending backup state across app restarts:
  - Store in a dedicated Drift table `BackupQueueItems` linked to `BackupMetadata` when available, with `pendingBackupFilePath` (String?), `status` (queued / retrying / needsReauth / failed), `lastBackupAttemptAt` (DateTime?), `backupRetryCount` (int), and `nextRetryAt` (DateTime?)
  - On app resume: check for pending operations; if found, retry with backoff
  - On connectivity change (via `connectivity_plus`): if pending upload exists and network is available, retry
- [x] Before each retry: attempt silent token refresh; if auth expired, mark as `needsReauth` instead of retrying (user must re-authenticate)

**4.5.5 Error Handling**

- [x] Token refresh handling:
  - Before every Drive API call, verify token freshness via `signInSilently()`
  - If silent sign-in fails: mark operation as `needsReauth`; show non-blocking UI hint ("Sign in again to continue backups")
  - Never block app usage on auth failure (offline-first principle)
  - Never auto-prompt interactive sign-in during background retry — only on explicit user action
- [x] Google Drive quota errors:
  - Catch `403 storageQuotaExceeded` from Drive API response
  - Show user-friendly localized message: "Your Google Drive is full. Free up space or delete old Daftar backups."
  - Offer in-app Drive backup management: list backups with sizes, allow deletion of old backups
  - Do not retry quota errors (they are not transient)
- [x] Network errors:
  - Catch `SocketException`, `TimeoutException`, HTTP 5xx responses
  - Classify as transient; enqueue for retry per backoff policy (4.5.4)
  - Show "Backup will resume when internet is available" message
- [x] Corrupted download handling:
  - After download, verify file header (`.daftar` magic bytes) and checksum before attempting restore
  - If checksum mismatch: delete corrupted download, show "Backup file is damaged" message, offer to try another backup

**4.5.6 Backup Screen — Google Drive Section**

- [x] Update `lib/presentation/screens/settings/backup_screen.dart`:
  - Add "Google Drive" section below local backup section
  - **Not signed in state:** Google Sign-In button with Google branding guidelines; explanatory text ("Back up to your personal Google Drive — free, encrypted, and private")
  - **Signed in state:** show account email + avatar; "Backup to Drive" button; "Restore from Drive" button
  - **Drive backup list:** date, size, "Restore" and "Delete" actions for each backup
  - **Upload in progress:** progress bar with percentage; cancel button
  - **Download in progress:** progress bar with percentage
  - **Pending retry state:** "Backup pending — will retry automatically" indicator with manual "Retry Now" button
  - **Error states:** quota exceeded, auth expired, network unavailable — each with specific copy and action button
  - "Sign Out of Google" option at bottom of Drive section
- [x] Create `lib/presentation/providers/auth_providers.dart`:
  - `authStateProvider` — watches sign-in status reactively
  - `googleAccountProvider` — current signed-in account info (email, display name, photo URL)
  - `signInControllerProvider` — mutation provider for sign-in/sign-out flows

> [!IMPORTANT]
> **Auto-backup reliability (July 2026).** Android uses **chain-only** WorkManager
> scheduling (no dual periodic+chain). Cross-isolate flight lock + 80% cadence
> throttle prevent duplicate Drive uploads. Sticky `needs_reauth` is reserved for
> revoked/forbidden grants — never transient network. OAuth consent must be
> **In production** in Google Cloud Console (Testing mode refresh tokens expire
> in 7 days). See [`docs/architecture/GOOGLE_DRIVE_BACKUP_SPEC.md`](../architecture/GOOGLE_DRIVE_BACKUP_SPEC.md) §§6–7.

- [x] Background Automation Engine (Workmanager) & Auto-Backup UI:
  - `workmanager` periodic `backup_sync_task` with headless Flutter bindings
  - `BackgroundSyncManager` + `BackgroundSyncExecutor` (silent auth → upload)
  - Auto-backup toggle and daily/weekly interval in `AppSettings` + backup screen
  - Hidden `appDataFolder` educational hint on backup screen
  - Silent auth persistence fixes (`ensureDriveSession`, cached account reuse)

**4.5.7 Validation & Tests**

- [x] Integration test — happy path: sign in → create backup → encrypt → upload to Drive → sign out → sign in → list backups → verify uploaded backup appears → download → decrypt → verify checksum → restore → verify all data matches original
- [x] Integration test — token refresh: sign in → simulate token expiry → trigger upload → verify silent re-auth fires → upload succeeds
- [x] Integration test — quota exhaustion: mock `403 storageQuotaExceeded` response → verify user-friendly error message → verify no retry loop
- [x] Integration test — network failure and retry: mock network error → verify operation queued → simulate connectivity restored → verify retry fires → upload succeeds
- [x] Integration test — corrupted download: mock corrupted file download → verify checksum validation fails → verify "damaged backup" message → verify app does not attempt restore
- [x] Integration test — offline-first resilience: verify app is fully usable when Google Sign-In is unavailable; local backup works; no blocking modals

---

### Stage 5: Premium & Monetization (MVP)

**Goal:** Implement the freemium paywall, activation code validation, and premium feature gating across three tiers: Free, Pro ($24.99/yr), and Pro+ ($49.99/yr).

**Prerequisites:** Stage 3 complete (workspace limits need transaction engine). Stage 4 recommended but not blocking.

**Features from Product Plan:**

- Payment (Manual Activation Codes)
- Free Tier Limits (1 Ledger, 50 Contacts, 500 Transactions)
- Three-Tier Structure (Free / Pro / Pro+)

**Integration / Architecture Notes:**

- Activation codes validated locally (encrypted payload with expiry)
- Premium status stored as signed JWT/encrypted token in `flutter_secure_storage`
- Feature gating at the use-case layer — UI reflects locked status but the enforcement boundary is in application logic
- Optional server-side code validation via Edge Function call using `dio` (if connected)
- The following features are **NOT gated** (free for all tiers): `localBackup`, `googleDriveBackup`, `basicPdf`, `creditLimits`, `customCurrencies`, `csvImport`, `excelImport`
- `googleDriveBackup` entitlement flag remains **free for all tiers** (Auth V2 shipped)
- ~~AI features are not included in any tier (FROZEN)~~ → **v3.0 / v3.4:** AI Voice Input is a **Pro+** feature with a **600/month** cap (UNFROZEN — **Stage 18**), plus a Free/Pro trial allowance. See the v3.0 entitlement note in 5.1.

#### Task Checklist

**5.1 Activation Code System**

- [x] Create `lib/data/datasources/remote/activation_api_ds.dart` — Edge Function HTTP call via `dio` to validate code (online path; no `supabase_flutter` dependency)
- [x] Create `lib/data/repositories/activation_repository_impl.dart`:
  - `activate(code)` — try online validation first, fall back to offline validation (code format + checksum)
  - Store activation as encrypted token in `flutter_secure_storage` with expiry date and tier (PRO / PRO_PLUS)
  - `getStatus()` — check token validity, return tier + days remaining
  - `isFeatureUnlocked(feature)` — feature-flag check based on tier
- [x] Define premium feature flags:
  - **Pro tier:** `unlimitedLedgers`, `unlimitedContacts`, `unlimitedTransactions`, `brandedPdf`, `smartMerge`, `ledgerArchiving`
  - **Pro+ tier (includes all Pro):** `multiDeviceSync`, `whatsappAutomation`, `advancedAnalytics`, `aiVoiceInput`, `workspaceCollaboration`, `sharedAccountsHost` _(v3.0: `customerPortal` deprecated → `sharedAccountsHost`; `aiVoiceInput` + `workspaceCollaboration` added)_
  - **NOT gated (free for all):** `localBackup`, `googleDriveBackup`, `basicPdf`, `creditLimits`, `customCurrencies`, `csvImport`, `excelImport`

> [!NOTE]
> CSV and Excel import are **100% free features**. They are not gated behind any tier. The existing workspace limits (1 ledger, 50 contacts, 500 transactions) govern how many imported records can be live at once. Pro's `unlimitedLedgers`, `unlimitedContacts`, and `unlimitedTransactions` flags handle archive activation via `ActivateArchivedImportsUseCase` — no separate import flag is needed.

> [!IMPORTANT]
> **Retroactive Alignment (v3.0) — Entitlement Contract Update.** The v3.0 CDO mandate revises the Phase 2 entitlement flags defined here. The MVP-shipped flag set above remains valid; Phase 2 stages extend it as follows. Implement these as additive feature flags (the metered ones carry a monthly quota counter), NOT new tiers:
>
> | Flag | Tier | Quota / Notes |
> |---|---|---|
> | `aiVoiceInput` | **Pro+** | **600 voice inputs / month** (hard cap, monthly reset). UNFREEZES the previously frozen AI stage — **ships in Stage 18**. |
> | `aiVoiceTrial` | Free + Pro | Taste allowance: Free = 15 lifetime; Pro = 60 / month. Drives Pro+ upsell. Credits from referrals are **banked** until Stage 18. |
> | `workspaceCollaboration` | **Pro+** | Worker email invites + granular permissions (Owner / Editor / Viewer). |
> | `sharedAccountsHost` | **Pro+** | Merchant can publish read-only ledger views to customers' apps (B2C loop). |
> | `sharedAccountsViewer` | **Free (all)** | Any user can *receive* a shared read-only account — this is the free B2C hook. |
> | `referralRewards` | **Free (all)** | Earn AI credits / unlock analytics via verified referrals (Stage 16). |
> | `whatsappAutomation` | **Pro+** | Strict per-tier WhatsApp utility quota + circuit breaker (Stage 11). |
> | `advancedAnalytics` | **Pro+** | Unlockable for Free via verified referrals (Stage 16 reward ladder). |
>
> The `customerPortal` flag (web portal) is **deprecated** and replaced by `sharedAccountsHost` / `sharedAccountsViewer`. The line above stating *"AI features are not included in any tier (FROZEN)"* is **superseded** by `aiVoiceInput` (Pro+) per **Stage 18**.

**5.2 Free Tier Enforcement**

- [x] Add limit checks in `CreateLedgerUseCase` — reject if free tier and ledger count ≥ 1
- [x] Add limit checks in `CreateContactUseCase` — reject if free tier and total contacts ≥ 50
- [x] Add limit checks in `AddTransactionUseCase` — reject if free tier and total transactions ≥ 500
- [x] Return `LimitExceededFailure` with localized message and upgrade CTA
- [x] Show contextual upgrade prompts (not intrusive — inline banners, not blocking modals)
- [x] Verify CSV import flow does NOT check tier — import is always permitted; only workspace activation is limited
- [x] Create `ActivateArchivedImportsUseCase` — promote archived imported ledgers, contacts, and transactions into the live workspace after a tier upgrade, reusing the existing free-tier limit checks

**5.3 Premium UI**

- [x] Create `lib/presentation/screens/premium/activation_screen.dart`:
  - Code input field (formatted: XXXX-XXXX-XXXX)
  - "Activate" button with loading state
  - Success animation on activation
  - Current plan display (Free / Pro / Pro+)
  - Expiry date and days remaining
  - Tier comparison card showing Free vs Pro ($24.99/yr) vs Pro+ ($49.99/yr) features
  - CSV import explicitly shown as "Free" in comparison card — not listed under Pro
- [x] Create upgrade prompt widget — shown when free-tier limit is hit
- [x] Add premium badge/indicator on home screen (shows current plan)
- [x] Add "Manage Subscription" section in Settings

---

### Stage 6: Security, Settings & UX Polish (MVP)

**Goal:** Implement app-lock security, merchant branding settings with PDF wiring, Google Account management, complete all settings, and polish the entire UX with animations, haptics, and RTL refinement.

**Prerequisites:** Stage 1 (MerchantProfile schema), Stage 4 (PDF generator with `MerchantProfile?` parameter), Stage 5 (tier gates for branding).

**Features from Product Plan:**

- Biometric/PIN Security
- Theming (Dark/Light)
- Settings screen
- Merchant Branding (UI, use cases, and PDF wiring — schema was Stage 1)
- Google Account Management (unlink/rebind)
- UX/UI Excellence

**Integration / Architecture Notes:**

- PIN hash stored in `flutter_secure_storage`, never in Drift DB
- Biometric auth via `local_auth` package (fingerprint + FaceID)
- App lock triggers on app resume (after configurable timeout)
- Merchant branding screen gated behind Pro/Pro+ tier; its use cases, providers, and PDF wiring are all built here
- Google Account management (switch account, unlink, rebind) built here to prevent identity drift before Phase 2 sync
- Analytics opt-out toggle persisted in `AppSettings`

#### Task Checklist

**6.1 PIN & Biometric Lock**

- [x] Create `lib/core/utils/security_service.dart`:
  - PIN creation flow (enter + confirm)
  - PIN validation (hash comparison using SHA-256 + salt)
  - Biometric availability check and enrollment
  - App lock state management (locked/unlocked, timeout threshold)
- [x] Create `lib/presentation/screens/settings/security_screen.dart`:
  - Enable/disable PIN lock toggle
  - Change PIN flow
  - Enable/disable biometric unlock toggle
  - Auto-lock timeout selector (immediately, 1 min, 5 min, 15 min)
- [x] Create `lib/presentation/screens/auth/lock_screen.dart`:
  - PIN input with numeric keypad
  - Biometric prompt button
- [x] "Forgot PIN" destructive recovery — wipes local SQLite + secure PIN, routes to backup restore
- [x] Implement app lifecycle listener — trigger lock screen on resume after timeout
- [x] Write tests for PIN creation, validation, and lock timeout logic

> [!NOTE]
> **Forgot PIN** requires backup restore (intentionally destructive). Disabling app lock clears PIN material from secure storage so re-enable always runs the create-PIN flow.

**6.2 Settings Screen**

- [x] Create `lib/presentation/screens/settings/settings_screen.dart`:
  - Language selector (Arabic / English)
  - Theme selector (Dark / Light / System)
  - Default currency selector
  - Security section → links to security_screen
  - Backup section → links to backup_screen
  - Import section → links to import_csv_screen (no Pro badge — CSV is free)
  - Merchant Branding section → links to merchant_branding_screen (Pro/Pro+ badge)
  - Premium section → links to activation_screen
  - Google Account section → links to account_management (shows signed-in email or "Sign In" prompt)
  - Analytics opt-out toggle
  - About / Version info
  - Rate app link
  - Contact support (WhatsApp deep-link to support number)
- [x] Implement all settings persistence via `SettingsRepository`
- [x] Verify immediate reactivity on locale/theme change (no restart required)

**6.3 Merchant Branding (UI, Use Cases & PDF Wiring)**

> [!NOTE]
> This is where the MerchantProfile data model (Stage 1) is activated into a user-facing feature. The PDF generator's `MerchantProfile?` parameter (Stage 4.1) is wired with real data here. All merchant branding logic is gated behind Pro/Pro+ tier (Stage 5).

- [x] Create `lib/application/merchant/update_merchant_profile_use_case.dart`:
  - Check tier: return `LimitExceededFailure` if free tier
  - Validate store name (non-empty, max 100 chars)
  - Validate store phone (optional, use `PhoneNumber` value object)
  - Persist to `MerchantProfileRepository`
  - Return `Either<Failure, MerchantProfile>`
- [x] Create `lib/application/merchant/set_merchant_logo_use_case.dart`:
  - Check tier: return `LimitExceededFailure` if free tier
  - Accept image file from `image_picker`
  - Resize/compress to max 512x512 px, JPEG 80% quality (keep file size < 200KB)
  - Save to app documents directory with deterministic filename
  - Update `MerchantProfile.logoPath`
  - Return `Either<Failure, String>` (new logo path)
- [x] Create `lib/presentation/providers/merchant_profile_providers.dart`:
  - `merchantProfileProvider` — watches current profile from repository
  - `merchantProfileControllerProvider` — mutation provider for update/logo operations
- [x] Create `lib/presentation/screens/settings/merchant_branding_screen.dart`:
  - Logo section: circular preview of current logo (or placeholder icon)
  - "Upload Logo" button → `image_picker` (camera or gallery)
  - "Remove Logo" button (if logo exists)
  - Store name text input (Arabic/English)
  - Store phone text input (with country code selector)
  - "Preview PDF" button → generates sample PDF with current branding via `pdf_generator.dart` passing the `MerchantProfile`, opens in viewer
  - Save button with success feedback
  - Gate behind Pro/Pro+ tier check:
    - Free users: show all fields but disabled, with upgrade CTA banner at top
    - Pro/Pro+ users: full access
- [x] Wire `MerchantProfile` into PDF generation flow:
  - When generating a PDF statement (Contact Detail → "Share Statement"), load `MerchantProfile` from repository
  - Pass it to `pdf_generator.dart`'s optional parameter
  - If user is on free tier OR MerchantProfile is empty: generator renders default app-name header
  - If user is Pro/Pro+ and profile has data: generator renders branded header with logo, store name, phone
- [x] Register `/settings/merchant-branding` route in `app_router.dart`
- [x] Write tests: update profile → generate PDF → verify branding appears in header
- [x] Write tests: free-tier user → generate PDF → verify branding does NOT appear

**6.4 UX Polish & Micro-Animations**

- [x] Add page transition animations (shared element transitions for contact → detail)
- [x] Add bottom sheet enter/exit animations (spring physics)
- [x] Add haptic feedback on: transaction save, delete undo, PIN button press
- [x] Add skeleton loading states for all async data (shimmer effect)
- [x] Add pull-to-refresh animations on list screens
- [x] Verify all tap targets ≥ 48dp on low-DPI devices
- [x] Test one-handed reachability — all primary actions accessible from bottom 60% of screen
- [x] RTL audit: verify every screen renders correctly in Arabic (alignment, icons, swipe direction)
- [x] Performance: verify sub-100ms perceived latency for all local operations on Samsung A03 equivalent

**6.5 Error Handling & Edge Cases**

- [x] Implement global error handler — catches unhandled exceptions, logs to Crashlytics
- [x] Create user-friendly error bottom sheets (not raw exception messages)
- [x] Handle storage-full scenario gracefully (warn before, block backup when disk < 50MB)
- [x] Handle database integrity failure on startup (offer restore from backup)
- [x] Implement graceful offline → online transitions (queue failed cloud operations)

**6.6 Google Account Management — Auth V2 Epic (Shipped)**

> [!NOTE]
> Settings-level UI for managing the linked Google account. Account switch → stale Drive IDs ceremony is enforced by `HandleGoogleAccountChangeUseCase`. Required before Phase 2 sync (Stage 8) to prevent identity drift.

- [x] **Auth V2 Epic — Account Management UI restored**
  - `account_management_screen.dart` with identity passport, Google sign-in/out, switch-account flow, and trust copy
  - `migrationRelinkRequired` banner + re-link CTA for ghost Drift identities from Auth V1
  - `/settings/account` route registered; Settings tile shows live account email when linked
  - Account switch atomic ceremony: cancel WorkManager → delete bundle → stale Drive file IDs → clear queue → audit log
  - Identity drift integration test green (`identity_drift_integration_test.dart`)

**6.7 Ledger Archiving — Archive Vault (Pro/Pro+ Exclusive)**

> [!NOTE]
> Lets merchants move old/closed ledgers (e.g., past-year accounts, closed branches) into a dedicated "Archive Vault," decluttering the Home Screen while preserving full read-only access and data integrity. Exclusive to Pro/Pro+ users.

> [!CAUTION]
> This feature uses a **new `isUserArchived` column**, distinct from the existing `isArchived` column (import-overflow archive). The two are semantically independent: `isArchived` is system-controlled (CSV import overflow), `isUserArchived` is user-controlled (intentional vault archival). A ledger can be in both states simultaneously. Do NOT conflate them.

> [!NOTE]
> **Financial Close — Balance Carry Forward (CTO mandate):** Archiving a year-end ledger (e.g., "دفتر 2024") must not strand active debts. Merchants MAY optionally roll non-zero contact balances into a target ledger (existing or newly created, e.g., "دفتر 2025") as **opening-balance transactions** before the source is frozen. Contacts with flat zero balance across all currencies are skipped. This is an **optional step inside the Archive ceremony** — not a separate menu action. The entire rollover + archive MUST execute in a **single Drift transaction** (see §6.7.1).

- [x] **Schema:** Add `isUserArchived` boolean column (default `false`) to the `Ledgers` Drift table + index `idx_ledgers_user_archived`. Schema migration version N+1. No contact/transaction column changes — archival cascades from the ledger.
- [x] **Domain:** Add `isUserArchived` field to the `Ledger` Freezed entity. Add `archiveLedger()`, `unarchiveLedger()`, `watchArchived()`, and `getArchivedLedgerCount()` to `LedgerRepository` interface.
- [x] **Data — Mapper:** Update `LedgerMapper` for `isUserArchived` round-trip. Update `LedgerModel`.
- [x] **Data — LedgerLocalDS:** Update `watchAllLedgers()` to also filter `isUserArchived.equals(false)`. Add `watchArchivedLedgers()` method.
- [x] **Data — BalanceLocalDS (CRITICAL):** Rewrite `watchAllBalances()` to JOIN through `contacts → ledgers` and exclude balances where the parent ledger has `isUserArchived = true` OR `isArchived = true` OR `isDeleted = true`. This protects the global "Current Liquidity" calculation from including frozen/archived balances.
- [x] **Data — LedgerRepositoryImpl:** Implement `archiveLedger()` (set flag + audit `USER_ARCHIVE`), `unarchiveLedger()` (clear flag + audit `USER_UNARCHIVE`), `watchArchived()`, `getArchivedLedgerCount()`.
- [x] **Application — New Use Cases:**
  - `ArchiveLedgerUseCase` — validate Pro/Pro+ tier (`ledgerArchiving` feature key). Accepts optional `CarryForwardParams?`. Archive-only: set `isUserArchived=true`, audit `USER_ARCHIVE`. With carry-forward: delegate to `archiveWithCarryForward` (§6.7.1) — atomic rollover + archive in one Drift transaction.
  - `UnarchiveLedgerUseCase` — validate Pro/Pro+ tier, set `isUserArchived=false`, append audit log.
  - `GetArchivedLedgersUseCase` — stream archived ledgers for the Vault screen.
- [x] **Application — Guards (Read-Only Enforcement):** Add `isUserArchived` preflight check to `AddTransactionUseCase`, `UpdateTransactionUseCase`, `DeleteTransactionUseCase`, `CreateContactUseCase`, `UpdateContactUseCase`, `DeleteContactUseCase`, and `UpdateLedgerUseCase`. Return `ValidationFailure` with code `'ledger_archived'` when the parent ledger is user-archived. `DeleteLedgerUseCase` still allows soft-deletion of archived ledgers.
- [x] **Presentation — Providers:** Create `archivedLedgersProvider` (StreamProvider), `archiveLedgerControllerProvider` (AsyncNotifier), `archivedLedgerCountProvider` (derived count for badge).
- [x] **Presentation — Archive Vault Screen:** Khazna v3 dark screen listing archived ledgers with frozen balance display, read-only browse, un-archive action. Empty state when no ledgers archived. Separate "Archived Total" summary card (not part of global "Current Liquidity").
- [x] **Presentation — Home Screen:** Filter `isUserArchived=true` ledgers from main list. Add Archive Vault entry point (settings gear or dedicated icon). Optionally show badge with archived ledger count.
- [x] **Presentation — Ledger Detail:** Add "Archive Ledger" action in the ledger options bottom sheet. Archive action opens the **Financial Close wizard** (§6.7.1): optional carry-forward toggle, target picker, preview, confirm. When viewing an archived ledger from the Vault, show prominent read-only banner and disable transaction add FAB.
- [x] **Presentation — Contact Detail:** Show read-only banner if parent ledger is archived. Disable mutation actions. PDF export button remains active.
- [x] **Presentation — Quick Add Sheet:** Filter contact autocomplete to exclude contacts whose parent ledger has `isUserArchived=true`.
- [x] **Presentation — Contact Search:** Global search results include archived-ledger contacts, marked with "(مؤرشف / Archived)" badge. Navigation opens in read-only mode.
- [x] **Entitlement:** Add `ledgerArchiving` to the Pro/Pro+ feature flag set in `app_constants.dart` and `activation_repository_impl.dart`.
- [x] **Downgrade Behavior:** When Pro expires, the Archive Vault remains read-only accessible (view, search, PDF export, delete). Archive/unarchive actions are blocked with an upgrade CTA. Data is never held hostage.
- [x] **AI Voice Input (Phase 2 forward-compat):** Contacts in user-archived ledgers MUST NOT be part of the entity resolution context for AI Voice Input (**Stage 18**). If a spoken name matches only an archived contact, route to manual entry — never auto-create under an archived ledger.
- [x] **WhatsApp Reminders (Phase 2 forward-compat):** Archived ledger contacts MUST NOT receive automated WhatsApp reminders (Stage 11). Manual WhatsApp (tap phone button on contact detail) is still allowed.
- [x] **Tests:**
  - Unit: Archive/unarchive use cases with tier enforcement, all mutation guards.
  - Integration: Archive ledger → verify global balance excludes it → un-archive → verify re-included.
  - Integration: Downgraded user → vault accessible read-only → archive/unarchive blocked.
  - Integration: Import-overflowed ledger (`isArchived=true`) + user archive (`isUserArchived=true`) → both flags independent → `ActivateArchivedImportsUseCase` promotes `isArchived` without affecting `isUserArchived`.
  - Mapper: Round-trip test for `isUserArchived` field.
  - Integration: Financial close with carry-forward → verify opening-balance transactions and target ledger balances (§6.7.1).

**6.7.1 Balance Carry Forward — Financial Close / Rollover (Pro/Pro+ Exclusive)**

> [!IMPORTANT]
> Carry forward is bundled with archival. A merchant who opts in gets: (1) new contacts + opening-balance transactions in the target ledger, then (2) `isUserArchived=true` on the source — atomically. There is no supported path to rollover without archiving or to archive-with-rollover across multiple transactions.

- [x] **Schema:** Add nullable `carryForwardTargetLedgerId` (`TEXT`, FK to `ledgers.id`, no cascade) to `Ledgers` Drift table. Set only when a rollover executed; serves as idempotency guard (retry returns success if already set). Migration version N+1 (same migration as `isUserArchived` or immediately following). PostgreSQL mirror: `carry_forward_target_ledger_id UUID REFERENCES ledgers(id)`.
- [x] **Domain:** Add `carryForwardTargetLedgerId` to `Ledger` entity. Add `CarryForwardPreview` value object (contactCount, transactionCount, per-currency totals, source/target ledger names). Add to `LedgerRepository`:
  - `previewCarryForward({required String sourceLedgerId})` → `Either<Failure, CarryForwardPreview>` (read-only scan).
  - `archiveWithCarryForward(ArchiveWithCarryForwardParams)` → `Either<Failure, CarryForwardResult>` (atomic write).
- [x] **Data — Carry-forward scan query:** JOIN `contacts` → `contact_balances` WHERE `contacts.ledger_id = :sourceId` AND `contacts.is_deleted = 0` AND `contacts.is_archived = 0` AND `contact_balances.net_balance != 0`. Group by contact; skip contacts with no non-zero currency rows.
- [x] **Data — Atomic transaction (`archiveWithCarryForward`):** Single `database.transaction()`:
  1. **Idempotency guard:** If `source.carryForwardTargetLedgerId != null` OR `source.isUserArchived == true` → return existing result (no-op success).
  2. **For each qualifying contact:** INSERT new contact in target ledger (new UUID v4; copy `name`, `phone`, `notes`, `creditLimit`, `creditCurrency`, `avatarColor`; do NOT reuse source `contactId`).
  3. **For each non-zero currency on that contact:** INSERT one transaction:
     - `netBalance < 0` → `type = debt`, `amount = abs(netBalance)`
     - `netBalance > 0` → `type = payment`, `amount = netBalance`
     - `description` = localized `carryForwardOpeningBalanceNote` with `{ledgerName}` = source ledger name
     - `transactionDate` = ceremony timestamp (UTC)
  4. **Balance recompute:** Upsert `contact_balances` for each new contact (reuse `calculateContactBalances` pattern from `balance_calculator.dart`).
  5. **Archive source:** SET `isUserArchived = true`, `carryForwardTargetLedgerId = targetId`, bump `updatedAt` / `syncVersion`.
  6. **Audit:** Append `CARRY_FORWARD` on source ledger (payload: `operationId`, `targetLedgerId`, `contactsCreated`, `transactionsCreated`, per-currency totals) + per-entity `CREATE` audit logs for contacts and transactions.
- [x] **Application — Use Cases:**
  - `PreviewCarryForwardUseCase` — read-only; powers the archive wizard preview step.
  - Extend `ArchiveLedgerUseCase` — accept optional `CarryForwardParams?` (`targetLedgerId`, `operationId`). When `null`, archive only (existing behavior). When set, delegate to `archiveWithCarryForward`. Preflight validations:
    - Pro/Pro+ tier (`ledgerArchiving` feature key)
    - Source not `isUserArchived`, not `isDeleted`
    - Target not `isUserArchived`, not `isArchived`, not `isDeleted`, `targetId != sourceId`
    - Entitlement capacity: `activeContacts + preview.contactCount <= limit`, `activeTransactions + preview.transactionCount <= limit`; if target is new ledger, also `activeLedgers + 0 <= limit` (ledger created in preflight step before atomic txn)
    - Source has ≥1 non-zero balance when carry-forward requested; else `ValidationFailure(code: 'no_balances_to_carry')`
  - `ArchiveLedgerUseCase` (archive-only path) remains for merchants who toggle carry-forward OFF.
- [x] **Application — Guards:** Opening-balance transactions created by carry-forward bypass normal `AddTransactionUseCase` (repository-internal) but still respect integer-money and currency invariants. Target ledger `isUserArchived` guard does not apply to the ceremony itself (target must be live).
- [x] **Presentation — Archive Wizard (extend §6.7 Ledger Detail action):**
  - Step 1: Toggle `"Carry forward active balances"` (default ON when preview.contactCount > 0)
  - Step 2: Target ledger picker (live ledgers) + `"Create new ledger"` inline field
  - Step 3: Preview card (contacts, transactions, per-currency totals) via `previewCarryForwardProvider`
  - Step 4: Confirm → `archiveLedgerControllerProvider.execute(carryForward: params)`
  - Error surfaces: `LimitExceededFailure` with upgrade CTA, `no_balances_to_carry`, `ledger_archived`
- [x] **Localization:** ARB keys: `carryForwardToggleLabel`, `carryForwardToggleDescription`, `carryForwardTargetPickerLabel`, `carryForwardCreateNewLedger`, `carryForwardPreviewTitle`, `carryForwardPreviewContacts`, `carryForwardPreviewTransactions`, `carryForwardOpeningBalanceNote`, `carryForwardSuccess`, `carryForwardConfirmTitle`, `carryForwardConfirmBody`
- [x] **Phase 2 sync (§8.1 / §8.4):** Carry-forward ops sync as standard `CREATE`/`UPDATE` op-log entries. No new Realtime channels. `carry_forward_target_ledger_id` synced as a regular ledger field. Server idempotency via existing `(entityId, deviceId, opId)` duplicate guard. Pull-side balance recompute unchanged.
- [x] **Tests:**
  - Unit: Balance sign → transaction type mapping (debt vs payment); zero-balance contacts skipped; multi-currency contacts produce N transactions.
  - Unit: Preflight validations (same-ledger target, archived target, tier gate, limit exceeded).
  - Integration: Carry forward 5 contacts → verify target balances match source → source `isUserArchived=true` → global liquidity excludes source, includes target.
  - Integration: Crash simulation (exception mid-txn) → verify zero contacts/transactions created, source not archived.
  - Integration: Idempotent retry after success → no duplicate contacts/transactions.
  - Integration: Archive without carry-forward toggle → source archived, target untouched.
  - Sync (Phase 2): Push carry-forward batch → second device pull → balances match; duplicate push → no double-apply.

---

### Stage 7: QA, Performance & Launch Preparation (MVP)

**Goal:** Comprehensive testing, performance optimization, Play Store listing preparation, and launch.

**Prerequisites:** Stages 4, 5, and 6 complete.

**Features from Product Plan:**

- All MVP features integrated and polished
- Play Store / App Store submission

#### Task Checklist

**7.1 Testing**

> [!NOTE]
> **Auth V2 validation gate passed (June 2026).** Google/Drive integration tests, Amnesia regression suite (4/4), and headless background sync tests reinstated. `flutter test` — 425/425 pass.

- [x] Unit tests: ≥ 80% coverage on domain + application layers
- [x] Unit tests for all mappers, utilities, value objects
- [x] Integration tests: full CRUD lifecycle for each entity chain (ledger → contact → transaction → balance)
- [x] Integration tests: backup create → restore cycle (local)
- [x] Integration tests: Google Sign-In → Drive backup upload → download → restore → data verification
- [x] Integration tests: Google Sign-In token refresh failure → verify silent re-auth attempt → verify non-blocking UI prompt on failure
- [x] Integration tests: Google Drive quota exhaustion → verify user-friendly error → verify no retry loop
- [x] Integration tests: Drive backup with network failure → verify queue persistence → verify retry on connectivity restored
- [x] Integration tests: CSV import with sample Arabic data — verify no tier check blocks import (free feature)
- [x] Integration tests: CSV import exceeding free-tier limits → verify imports succeed but excess records are archived, then upgrade → activate archived imports and verify the data becomes live
- [x] Integration tests: activation code validation (online + offline)
- [x] Integration tests: merchant branding setup (Pro tier) → PDF generation with branded header
- [x] Integration tests: merchant branding attempt (Free tier) → verify tier gate prevents save
- [x] Integration tests: Google account switch -> verify old Drive file IDs invalidated -> verify new account works
- [Delayed] Widget tests for critical UI components (balance card, transaction sheet, lock screen, backup screen)
- [Delayed] End-to-end test: fresh install → create ledger → add contact → add debt → record payment → verify balance → generate PDF → share
- [x] End-to-end test: fresh install → Google Sign-In → backup to Drive → wipe data → restore from Drive → verify data
- [Delayed] RTL visual regression tests (screenshot comparison for AR vs EN)

**7.2 Performance Optimization**

- [Delayed] Profile app startup time on Samsung A03 — target < 2 seconds cold start
- [x] Profile transaction list scroll on 1000+ transactions — target 60fps
- [x] Profile PDF generation for 500 transactions — target < 5 seconds in isolate
- [x] Profile Drift query performance — add indexes where needed
- [Delayed] Optimize APK size with `--split-per-abi` — target < 30MB per ABI
- [Delayed] Verify memory usage stays under 150MB during normal operation
- [x] Run `flutter analyze` — zero warnings
- [x] Run `dart fix --apply` for any auto-fixable issues

**7.3 Launch Preparation**

- [Delayed] Create app icon (Arabic-styled دفتر logo) — all required sizes
- [Delayed] Create splash screen (branded, matches theme)
- [Delayed] Write Play Store listing (Arabic + English): title, short description, full description, keywords
- [Delayed] Create Play Store screenshots (5+ per language) — phone form factor
- [Delayed] Create Play Store feature graphic (1024x500)
- [Delayed] Configure Firebase App Distribution for beta testing
- [Delayed] Set up Google Cloud Console production project:
  - Production OAuth 2.0 Client IDs (Android release + iOS)
  - SHA-1 and SHA-256 fingerprints for release keystore
  - OAuth consent screen verified (if needed for `drive.appdata` — typically not required for non-sensitive scopes)
- [Delayed] Configure ProGuard/R8 rules for release build (preserve Google Sign-In classes)
- [Delayed] Generate signed release APK + App Bundle
- [Delayed] Submit to Google Play internal testing track
- [Delayed] Recruit 10–20 beta testers from target market (Yemeni/MENA merchants)
- [Delayed] Define crash-free rate target (≥ 99.5%) and user engagement metrics for PMF validation

**7.4 Documentation**

- [x] Write `README.md` with setup, build, and architecture overview
- [x] Document all environment variables and configuration (Google Cloud project IDs, OAuth client IDs, SHA fingerprints)
- [x] Document backup file format (`.daftar`) for future compatibility
- [x] Document activation code format and validation algorithm
- [x] Document Google Drive backup architecture (scope, appdata folder, encryption flow, retry policy)
- [x] Create onboarding walkthrough screens (3–4 screens explaining core value: track debts → backup to Google Drive → share branded PDFs) — **v3.4:** superseded/expanded by **Stage 9** Stunning Onboarding; keep as MVP stopgap until Stage 9 ships.

---

## Phase 2 — The Killer Features

> **Re-scoped June 2026 (v3.0).** Phase 2 turns Daftar from a single-user local ledger into a **collaborative, AI-assisted, self-growing ecosystem**. Every feature is engineered to be **offline-first**, **Arabic-first / RTL**, **financially bounded** (zero uncontrolled variable cost), and **secure by construction**. AI Voice is unfrozen because a hard usage cap — and, since v3.6, a single-call architecture whose *worst case* is ≤ $3.60/user/yr — makes it a rounding error, not a $104K liability.

> [!IMPORTANT]
> **Local Docker Development Baseline (v3.3).** Stages **8–13** target a local Supabase stack (`supabase start`, `supabase db reset`, Edge Functions on `127.0.0.1:54321` / LAN). Do **not** treat a production Supabase project as a prerequisite until **Stage 14**. Public-internet cutover items (Play Install Referrer against a live landing host, payment-gateway webhooks, real third-party store installs) are collected in Stage 14 / Stages 15–16 — they must not block local Validation Gates.

> [!IMPORTANT]
> **v3.4 sequencing.** **Stage 9 (Onboarding)** ships first after sync foundation — activation compounds into every later stage. **AI Voice is Stage 18** (penultimate). Referral AI credits granted in Stage 16 are **banked** until Stage 18 launches. **Firebase §0.3.2** must be live before Stage 11 FCM consumers.

---

## Phase 2 — Financial & API Strategy (2026, Web-Verified)

> [!IMPORTANT]
> WhatsApp rates (§A) were verified via live web research on **2026-06-06** (Meta rate card effective 2026-04-01). AI voice rates and model selection (§§B–D) were **fully re-verified and re-decided on 2026-08-06** — see [`docs/archive/ai_voice_feature_study.md`](ai_voice_feature_study.md) for the complete market scan, gap analysis, and decision record. These figures are the basis for every quota and circuit-breaker in Phase 2. Re-verify before contract signing — providers update rate cards ~every 6 months.

### A. WhatsApp Cloud API — Utility Message Pricing (per delivered template, USD)

Since **2025-07-01** Meta bills **per delivered template message** (not per 24h conversation). **Service messages** (customer-initiated, answered inside the 24h window) and **utility templates sent inside an open 24h customer-service window** are **FREE**.

| Market | Utility / msg | Notes for Daftar |
|---|---|---|
| **Yemen** (in "Rest of Middle East") | **~$0.0105** | Primary launch market. RoME = Bahrain, Iraq, Jordan, Kuwait, Lebanon, Oman, Qatar, Yemen. |
| **Saudi Arabia** (standalone) | **~$0.0107–0.0123** | Second market. |
| **Egypt** (standalone) | **~$0.0036–0.0041** | Cheapest MENA market. |
| **UAE** (standalone) | **~$0.0136** (AED ~0.05) | — |
| **Rest of Africa** | ~$0.0040 | — |
| Service / in-window utility | **$0.00 (FREE)** | The cost-avoidance lever we design around. |

- **Volume discounts:** 5–30% on utility/auth, monthly reset, per market+category.
- **Routing decision:** Use the **WhatsApp Cloud API directly** (no BSP markup). A BSP (Twilio/360dialog) would add **$0.005–0.025/msg + $50–500/mo** — avoid unless onboarding friction demands it.
- **Planning rate (conservative blended MENA):** **$0.012 / utility reminder.**

### B. Arabic Voice AI — Model Market Scan (re-verified 2026-08-06)

> [!IMPORTANT]
> **v3.6 rebuild.** The v3.0 five-step on-device-first cascade (Gemma 4 E4B / Whisper.cpp primary → Soniox → regex → Gemma 4 → Gemini fallbacks) is **retired** — its on-device anchor cannot run on the Samsung A03-class target hardware (see table) and its dual quota semantics were untestable. Full evidence and math: [`docs/archive/ai_voice_feature_study.md`](ai_voice_feature_study.md).

| Option | Price (effective, Aug 2026) | Arabic-dialect evidence | Verdict |
|---|---|---|---|
| **Gemini 3.1 Flash-Lite — audio→JSON in ONE call** | **~$0.0003–0.0005 / command** (audio in $0.50/1M tok @ 25 tok/s · out $1.50/1M · cache $0.025–0.05/1M · Batch −50%) | Language-general multimodal; schema-enforced JSON (`responseSchema`); must pass the §18.1 golden-set gate before GA | ✅ **PRIMARY** |
| **Soniox async STT** (+ Flash-Lite text parse) | $0.10/hr + ~$0.0001/parse | Best measured WER (**16.2%**) in the 2026 Gulf-Arabic production benchmark | ✅ **Contingency of record** (two-call; adapter flip, no app update) |
| OpenAI gpt-4o-mini-transcribe (+ text parse) | $0.18/hr ($0.003/min) | Whisper-class multilingual | Third option (vendor diversity) |
| Deepgram Nova-3 multilingual | $0.55/hr batch | Excellent Gulf Arabic; 424 ms EOU — agent-optimized, irrelevant to a confirm-card flow | ❌ 5× Soniox |
| Munsit (CNTXT AI, UAE) | from $8/mo ≈ $4.8–6/hr effective | **#1 Open Universal Arabic ASR Leaderboard** (~26.7% avg WER vs Whisper ~36.9%); 25+ dialects; sovereign/on-prem | ❌ subscription floor + ~50× unit cost at our volume; revisit on sovereign mandate |
| ElevenLabs Scribe v2 | ~$0.22–0.40/hr | ~32% Arabic WER; "not viable" in Gulf production test | ❌ |
| Voxtral Mini Transcribe 2 (Mistral) | $0.003/min | 13 languages, **Arabic absent**; zero Arabic output in production test | ❌ |
| Groq Whisper large-v3 / turbo | $0.04–0.111/hr | Poor / inconsistent Arabic dialect output | ❌ |
| Google Chirp 3 / Azure Speech | $0.96 / ~$1.00 per hr | Good–excellent, broad dialects | ❌ 10× price |
| **On-device Gemma 4 E2B/E4B** | $0 marginal | E4B: 2.5 GB download, ~5 GB RAM (Q4) — **exceeds A03-class hardware (2–4 GB total)**; E2B: 1.1 GB + ~1.5–2 GB RAM; Google's own audio evals (CoVoST/FLEURS) include **no Arabic**; violates Stage 17 budgets (< 150 MB RAM / < 30 MB APK) | ❌ **physics** |
| whisper.cpp tiny–small | $0, 75–466 MB | MSA-biased; dialect WER > 40% | ❌ quality floor |

### C. The Decision — One Call, One Confirm (v3.6)

**Primary:** the `ai-voice-parse` Edge Function sends the clip to **Gemini 3.1 Flash-Lite** (multimodal): audio in → `{transcript + schema-locked JSON}` out. STT, dialect handling, Arabic-Indic digits, spelled-out numbers, and NLP happen in **one metered call** — `responseSchema` strict JSON, temperature 0, thinking budget 0, **paid tier only** (the free tier trains on user data — banned).

**Contingency (pre-wired, not built):** the server-side provider adapter can flip to **Soniox async ($0.10/hr) + Flash-Lite text parse** with no app update if the §18.1 golden-set gate fails on dialect quality. OpenAI `gpt-4o-mini-transcribe` is documented as the third option for vendor diversity.

**Retired (v3.6):** the entire on-device tier (Gemma 4 E2B/E4B, whisper.cpp) and the regex parser as a *primary* path. The deterministic Arabic number parser survives as a **validator** (§18.4): it cross-checks the model's amount and polarity instead of competing with it. Rationale: the on-device anchor cannot run on target hardware, would add a GB-class download on metered Yemeni internet, and at a 600/mo cap the *entire worst-case* cloud bill (≤ $3.60/user/yr) is smaller than the engineering and quality risk of maintaining five inference paths. **Simplicity is the cost optimization.** On-device revisit criteria (all three required): ≤ 500 MB model, ≤ 15% WER on our golden set, ≤ 3 s inference on A03-class within ≤ 300 MB peak RAM.

### D. The 600/Month Voice Cap — Verified Economics (v3.6)

> [!NOTE]
> These economics govern **Stage 18**. Stage 16 may **bank** trial credits in `ai_usage_counters` before Stage 18 ships — cost remains $0 until redemption. **One command = one metered call = one quota unit** — no dual semantics.

**Caps: 600 commands / month / Pro+ (hard) · ≤ 40/day · ≤ 90 audio-min/month · ≤ 30 s/clip.** Avg clip 8 s.

| Cost line (per command) | Math | Cost | / user / yr @ cap |
|---|---|---|---|
| Audio in | 8 s × 25 tok/s = 200 tok × $0.50/1M | $0.00010 | $0.72 |
| Fixed prompt (budgeted ≤ 800 tok) | cached $0.025/1M ↔ uncached $0.25/1M | $0.00002–0.00020 | $0.14–1.44 |
| Output (transcript + JSON ≈ 120 tok) | × $1.50/1M | $0.00018 | $1.30 |
| **Total** | | **~$0.0003–0.00048 → planning rate $0.0005** | **~$2.20 expected · $3.60 ceiling (7,200 × $0.0005)** |

**Aggregate sanity (100K users; 1,500 Pro+ / 5,000 Pro):** all-maxed-everything ceiling ≈ **$8K/yr** (Pro+ $5.4K + Pro trial $1.8K + Free lifetime trickle — never happens simultaneously); realistic utilization ≈ **$1K/yr**. (The frozen estimate was **$104,000/yr** for uncapped usage.) **The cap is the financial control; the single call makes it auditable.**

> **UX framing that keeps it bounded:** 600/mo ≈ 20/day. Voice is the *convenience* path for on-the-go entry; the existing fast manual entry + autocomplete remains the bulk-entry path for 50–100/day shops. Voice is never positioned as the primary high-volume input.

### E. WhatsApp Reminder Economics — "Never Lose Money" Quota

- Pro+ quota **30 utility reminders / month** = 360/yr. Worst case (all chargeable, $0.012) = **$4.32/user/yr**.
- **Two cost-avoidance levers:** (1) reminders to customers who replied within 24h are **free** (service window); (2) customers who installed the app via the **B2C deep-link loop (Stage 11)** receive a **free in-app push**, not a paid WhatsApp message. Realistic Pro+ WhatsApp cost ⇒ **~$1.50/user/yr.**

### F. Per-Tier Cost Ceiling & Margin (verified-rate model)

| Tier | Price | MoR net | Worst-case marginal | Worst-case margin | Realistic margin |
|---|---|---|---|---|---|
| **Pro** | $24.99/yr | ~$23.24 | ~$0.00 (local-only) | **99.9%** | 99.9% |
| **Pro+** | $49.99/yr | ~$46.99 | voice $3.60 (v3.6 zero-cache ceiling) + WA $4.32 + sync $0.42 = **$8.34** | **82.2%** | voice $0.55 + WA $1.50 + sync $0.42 = $2.47 → **94.7%** |

### G. Hard Economic Limits the App MUST Enforce (Circuit Breakers)

| Limit | Value | Enforcement |
|---|---|---|
| Voice commands (Pro+) | **600 / month** (hard, monthly reset) | Server-authoritative counter in Supabase + local mirror; over-cap → graceful "manual entry" fallback, no cloud call. **1 command = 1 metered call = 1 unit** (v3.6). |
| Voice trial (Free / Pro) | 15 lifetime / 60 per month | Same counter table; upsell prompt on exhaustion. |
| Voice daily sub-cap | ≤ 40 commands / user / day | Anti-abuse throttle even within monthly cap. |
| Voice audio ceiling (v3.6) | ≤ **90 audio-min / user / month** + ≤ 30 s / clip (min 0.5 s) | Bounds the token ceiling independently of command count; rejected server-side before any spend. |
| WhatsApp utility reminders (Pro+) | **30 / month** | Quota counter + monthly reset; block + notify at cap. |
| Global AI monthly spend | Org-wide budget cap (default **$250/mo** ≈ 3× realistic fleet cost) | **Auto-pause** voice at threshold with localized status banner + ops alert; manual entry unaffected. |

### H. Security & Integrity Mandate (applies to ALL AI + backend endpoints)

- **No raw model selection from the client.** The client never names a model, endpoint, or key. It calls a **single hardened Supabase Edge Function** that chooses the model server-side. This shields core logic from external manipulation/"malicious selection."
- **Prompt-injection defense:** transcribed audio is treated as **untrusted data, never instructions.** Use a fixed system prompt + structured-output (JSON schema) extraction; strip/escape control phrases; the model returns data only, never executes tool calls from transcript content.
- **Keys server-side only:** AI provider keys (Gemini primary + optional fallback) live in Edge Function secrets — never in the app binary, Drift, or `flutter_secure_storage`.
- **Authenticated + rate-limited endpoints:** every Edge Function verifies the short-lived sync JWT, enforces per-user quotas, and rate-limits by user + device + IP.
- **Data minimization / leakage control (v3.6):** the audio clip is the **only** user content transmitted — no contact list, no ledger context, no PII beyond the spoken phrase. **Paid tier only** (provider training on API data disabled; the free tier trains and is banned). **No server-side audio or transcript retention** — telemetry stores counters and token/cost figures, never content.
- **Output validation:** parsed JSON is schema-validated and clamped (amount > 0, known currency, resolvable contact) before it can touch the ledger.

---

### Stage 8: Sync Backend, Merge Engine & Workspace Collaboration — HARDENED (Phase 2)

> [!IMPORTANT]
> **v3.1 Security & Architecture Overhaul (CDO audit, June 2026).** This stage was found to have four high-risk systemic gaps: (1) a manual, admin-dependent **account-migration blindspot**; (2) **un-rate-limited invitation endpoints** (email-spam / domain-blacklist vector); (3) **no expired deep-link lifecycle** (post-install stranding); and (4) **destructive workspace-deletion cascades** that could erase customers' receipts (regulatory + retaliation risk). **v3.3 relocation:** gaps (2) and (3) are redesigned in this stage (§8.7 rate limits + §8.5.1 TTL lifecycle). Gaps (1) and (4) are **relocated intact** — ownership transfer → **Stage 13**; immutable receipts / workspace deletion → **Stage 11** (§11.3 / §11.4) after B2C Shared Accounts exist. No existing capability is removed — the Merge Engine, deep-linked store routing, deferred-install attribution, and the Unfrozen Voice AI quotas are all preserved and strengthened.
>
> **v3.2 Execution Resequence (July 2026).** Stage 8 subsections were renumbered into a **strict dependency order**. Do not skip ahead. Do not start **Stage 10 (Smart Import)** until the Stage 8 Validation Gate passes (**Stage 9 Onboarding** may proceed in parallel). Legacy IDs are noted in italics on each subsection header for cross-reference continuity.
>
> **v3.3 Local-First Docker Mandate (August 2026).** Stage 8 is a **local Docker** stage. Schema tables that Stage 11 / Stage 13 consume (`archived_shared_ledger`, `migration_challenges`) remain declared in §8.1 so the migration set stays coherent; only the *feature work* relocated. Transactional-email deliverability (SPF/DKIM/DMARC, CAPTCHA step-up) is deferred to **§19.4**.
>
> **v3.5 Stage 8 Accuracy Audit (2026-08-06).** Every checked item in this stage was re-verified line-by-line against the migrations, Edge Functions, Dart sources, and test files on disk. **Checkboxes now mean "verified present," not "believed done."** Corrections applied: the Stage 9-vs-Stage 10 gating contradiction; the pessimistic break-even arithmetic; a `device_push_tokens` table claimed as delivered that no migration ever created; an archived-ledger Realtime design that was specified but never built (the shipped server-side design is better and is now what the roadmap describes); stale source line-number citations; understated §8.5.1 completeness. **Three defects and one specification gap were found and are recorded as unchecked items rather than quietly fixed in prose:** the ≤ 2 concurrent-Editor cap is not enforced (§8.6), the rate-limit tier is not resolved per caller (§8.7), no Postgres-level RLS test exists (§8.6 / Band E), and the tombstone retention window is undefined (§8.4).

**Goal:** Stand up the **local Docker** Supabase sync backend (PostgreSQL + Edge Functions), build the **Merge Engine** that guarantees safe offline/online reconciliation, add **bounded multi-worker collaboration** (email invites + granular permissions + hardened anti-spam rate limits), and ship the shared **Deep-Link & Attribution Service** (with a full TTL lifecycle). Authentication remains Google Sign-In (Auth V2); Supabase is used **only** for sync, collaboration, and growth infrastructure — never for end-user auth or primary storage. Ownership transfer and immutable customer receipts are **out of scope here** (Stages 13 and 11 respectively).

**Prerequisites:** Phase 1 complete. **Auth V2 complete** (Stage 4.5 + 6.6 + Stage 7 validation gate passed, June 2026). Google ID token → sync JWT handoff documented in §8.2. Local `supabase start` stack available.

**Features from Product Plan:**

- Multi-Device Sync (backend + Merge Engine)
- Multi-Worker Collaboration — **Pro+**, hard-capped at **Owner + 2 Workers** (see economics)
- Customer Sharing (B2C) — schema + tier-bound caps **Free 0 / Pro 30 / Pro+ 500** prepared here; product wiring in Stage 11
- Deep-Link & Attribution Service (shared foundation, full TTL lifecycle)
- Invite / share rate-limiting circuit breaker (no SMTP send in this stage)

**Integration / Architecture Notes:**

- PostgreSQL schema mirrors the Drift local schema with server-side fields (`workspace_id`, `server_updated_at`, `op_seq`, `deleted_at`).
- The tenant key is **`workspace_id`**, not the Google account ID directly — this is what makes multi-worker collaboration AND account-ownership transfer possible (many members → one workspace; ownership = a re-keyable pointer, not a hard-wired identity).
- Row-Level Security keys every **business** row to `workspace_id`; membership + role are checked via a `workspace_members` join. (Infrastructure tables — rate-limit buckets, ops alerts, growth counters — are service-role-only and deliberately not workspace-keyed; see §8.1.)
- Supabase Auth is NOT used — Google Sign-In ID tokens are verified server-side against Google's public JWKs and exchanged for a short-lived **custom sync JWT** carrying `workspace_id` + `role`. **Consequence: end users and B2C customers are NOT Supabase MAUs → $0 MAU billing.** The JWT TTL is **3600s**, which sets the worst-case window for any revocation to take effect.
- **B2C viewers never hold a persistent Realtime socket.** Shared Accounts use a **push-triggered, fetch-on-open** model (FCM push on change + a small read on open). This is the single most important cost decision — it keeps Realtime peak-connection billing and the ~50K concurrency ceiling out of the B2C path entirely. *(Stage 8 ships only the fetch-on-open interface stub; the FCM half of this model is §11.0.)*
- Edge Functions host all privileged logic — each authenticated, rate-limited, and free of service keys on the client. **In Stage 8** that means token exchange, op-log push/pull, invites, revocation, rate-limiting, and deep-link mint/resolve/claim. Later stages extend the same pattern to identity transfer (13), promo redemption (15), and the AI proxy (18).
- The **Merge Engine runs entirely client-side** over the local `AuditLog` op-log — there is no server-side merge. The server's only role in reconciliation is as the **ordering authority** (assigning `op_seq` + `server_updated_at`) and as the archived-ledger filter on pull.

#### Collaboration & Sharing Economics (Web-Verified, 2026-06-06)

> [!NOTE]
> Verified against the Supabase pricing & docs pages (Pro org). **Conclusion: marginal cost is NOT the binding constraint for sharing or collaboration — domain reputation, abuse surface, conflict overhead, and revenue protection are.** Caps are therefore set 1–3 orders of magnitude *below* the cost break-even.

**Verified Supabase unit rates (Pro org, $25/mo):** Edge Functions **$2 / 1M** invocations (after 2M incl.) · Egress **$0.09/GB** uncached / $0.03 cached (after 250 GB incl.) · Realtime **$10 / 1,000** peak connections + **$2.50 / 1M** messages (after 500 / 5M incl.) · MAU **$0.00325** (after 100K — *not incurred*, custom JWT) · Disk **$0.125/GB** (after 8 GB) · Compute Micro $10 → XL $210 → 4XL $960/mo.

**B2C Shared-Account marginal cost** (push-triggered + fetch-on-open; no viewer socket; no Supabase Auth):

| Cost driver | Realistic / customer / yr | Basis |
|---|---|---|
| Edge invocations (~144: ~96 push-triggers + ~48 opens) | **$0.00029** | $2 / 1M |
| Egress (~2 MB of ledger-slice reads) | **$0.00018** | $0.09 / GB |
| Storage (~5 KB binding row) | ~$0 | $0.125 / GB |
| Realtime / MAU / FCM push | **$0** | by design (FCM free; no socket; custom JWT) |
| **Total** | **≈ $0.0005 / customer / yr** | pessimistic 10× ⇒ ~$0.005 |

**Break-even ceiling:** Pro+ net (~$46.99) ÷ $0.0005 ≈ **~94,000** customers (realistic); ÷ $0.005 ≈ **~9,400** (pessimistic 10×) before sharing alone erases one subscription. **Cost ceiling ≫ any sane product cap** (≥ 18× the Pro+ cap of 500).

**Therefore — Customer Sharing caps (anti-abuse / reputation-bound, NOT cost-bound):**

| Tier | Host (share read-only) | Receive (viewer) | Marginal cost at cap (pessimistic) |
|---|---|---|---|
| **Free** | **0** | **Unlimited** (the free B2C hook) | $0 |
| **Pro** | **30** active shared customers | Unlimited | ~$0.15 / yr |
| **Pro+** | **500** active shared customers | Unlimited | ~$2.50 / yr |

> "Active" = claimed & not revoked; revoking frees a slot. Share-link *creation* is rate-limited (§8.7) and push fan-out is batched. 500 preserves the old portal's "500 links" ceiling — no degradation.

**B2B Worker collision math (why ≤ 2 workers):** the write-conflict surface grows quadratically with concurrent editors — pairs = W·(W−1)/2: **2 editors → 1 pair, 3 → 3, 4 → 6, 5 → 10.** Every extra concurrent writer multiplies ambiguous-merge edge-cases, audit-log volume, and support load. Realtime cost is trivial at this scale, so the limit is set by **conflict tractability + revenue protection**, not infrastructure.

| Tier | Worker seats | Concurrent editors | Devices |
|---|---|---|---|
| Free / Pro | **0** (solo) | 1 (the Owner) | per existing limits |
| **Pro+** | **Owner + up to 2 Workers** (3 seats max) | **≤ 2 concurrent Editors, and the Owner is always one of them** — so at most **one** Worker may be an Editor and the third member must be a Viewer | 10 |

> **Read the editor cap carefully — it is the tightest constraint in the stage.** 3 seats does *not* mean 3 editors. The Owner permanently occupies one editor slot, so the maximum concurrent-writer configuration is **Owner (Editor) + Worker A (Editor) + Worker B (Viewer) = 1 conflict pair**, exactly the surface the Merge Engine and Stage 10's exhaustive review UI were sized for. Allowing Owner + 2 Editors would be **3 pairs** and would silently invalidate that premise. *(This invariant is currently **not enforced** — see the defect in §8.6.)*

> Teams larger than 3 are deliberately out of scope for Pro+ and route to a future **Business/Enterprise** tier — this protects ARPU and keeps the merge surface QA-able.

#### Execution Order (Mandatory — Do Not Skip)

> [!IMPORTANT]
> Work **top → bottom**. Each band depends on the band above it. **Stage 10 (Smart Import & Merge)** is blocked until the Validation Gate passes; **Stage 9 (Onboarding)** is *not* blocked and may run in parallel (it is local-first and does not consume the Merge Engine).

| Band | §§ | Purpose | Status |
|---|---|---|---|
| **A — Foundation** | 8.1 → 8.3 | Schema/RLS, Auth Bridge, Merge Engine | **Complete** (Band A audit remediation applied) |
| **B — Live Sync** | 8.4 | Wire client ↔ server op-log (REST push/pull + Realtime wake-up) | **Core complete** — 2 open v3.4 gaps (bootstrap snapshot, tombstone-retention resync) |
| **C — Join Paths** | 8.5 → 8.6 | Deep links, then finish worker invite acceptance | **§8.5/§8.5.1 complete** (local Docker) — §8.6 has 3 open items (role change, revoked wipe, editor-cap defect) |
| **D — Hardening** | 8.7 | Invite/share rate-limit circuit breaker (no SMTP) | **Complete for this stage** (deliverability → §19.4) |
| **E — Gate** | Validation | Prove the whole stage end-to-end on local Docker | **Not started — the only remaining band** |

```
8.1 Schema & RLS                                   ← COMPLETE
  └── 8.2 Auth Bridge (Google → sync JWT)          ← COMPLETE
        └── 8.3 Merge Engine (local conflict resolution)   ← COMPLETE
              └── 8.4 Sync Engine — Client Wiring          ← CORE COMPLETE (2 gaps)
                    └── 8.5 Deep-Link & Attribution (+ 8.5.1 TTL)   ← COMPLETE
                          └── 8.6 Multi-Worker Collaboration        ← 3 gaps open
                                └── 8.7 Rate-Limiting Circuit Breaker  ← COMPLETE
                                      └── Stage 8 Validation Gate   ← YOU ARE HERE
                                            └── Stage 10 (only after gate)

(Stage 9 Onboarding runs in parallel — it does not depend on any band above.)

(v3.3 relocated — not in Stage 8:)
  Ownership Transfer          → Stage 13
  Immutable Receipts / Delete → Stage 11 (§11.3 / §11.4)
  Email deliverability / CAPTCHA → §19.4
```

#### Task Checklist

---

##### Band A — Foundation

**8.1 Supabase Project, Schema & RLS** *(formerly 8.2)*

- [x] Stand up the **local Docker Supabase stack** (`supabase start` + `supabase db reset` + Edge Functions on `127.0.0.1:54321` / LAN) as the Stage 8 development target, and **record the production region decision**: **me-south-1 (Bahrain)** for PDPL data-residency preference. *(Local Docker is the baseline per v3.3; the linked dev project in `supabase_config_reference.md` §4.2 is Frankfurt. **Provisioning the real production project in me-south-1 is owned by §14.2 — it is NOT a Stage 8 deliverable.**)*
- [x] Define PostgreSQL schema mirroring Drift tables (`ledgers`, `contacts`, `transactions`, `contact_balances`, `audit_logs`) plus Phase 2 tables:
  - `workspaces` (incl. re-keyable `owner_identity`, `status`, `soft_deleted_at`, `purge_after`) + `workspace_members` (role: `owner` / `editor` / `viewer`, `invited_email`, `status`, `seat_index`) — **seat cap enforced: max Owner + 2 Workers**
  - `shared_accounts` (host workspace → contact → claim token → viewer device binding, `state`, `revoked_at`) — used by Stage 11; **counts against the tier sharing cap**
  - `deep_link_tokens` (opaque token, intent payload, `kind`: `share` / `referral` / `worker_invite`, `expires_at`, `state`: `active`/`claimed`/`expired`/`revoked`/`superseded`) — used by §8.5 and Stages 11 & 14
  - `migration_challenges` (single-use ownership-transfer handshake: `old_identity_hash`, `new_identity_id`, factor flags, `expires_at`, `reversal_token`) — schema reserved here; **feature work in Stage 13**
  - `rate_limit_buckets` (token-bucket counters keyed by dimension: merchant, IP, dest-email/domain, global) — used by §8.7
  - `archived_shared_ledger` (decoupled, frozen read-only customer snapshots after workspace deletion) — schema reserved here; **feature work in Stage 11 (§11.4)**
  - `promo_codes` + `promo_redemptions` (single-use, atomic) — used by Stage 15
  - `referrals` (`referrer_identity_hash`, `referee_identity_hash`, `referral_code`, install-verified, register-verified, reward state) — used by Stage 16
  - `ai_usage_counters` (per **`identity_hash`** / month: voice count, cloud-call count, `spend_estimate_cents`) — used by **Stage 18**; Stage 16 may credit/bank rows before the feature ships
  - Plus the ordering authority: a `global_op_seq` sequence + `next_global_op_seq()` RPC backing §8.3's server-assigned `op_seq`
- [x] **Tables added by the later Stage 8 bands** (listed here so the migration set stays coherent and reviewable in one place):
  - `workspace_devices` + `sync_usage_counters` (§8.4 device cap + monthly sync-event cap) — `20260802180000_stage_8_4_sync_engine.sql`
  - `deep_link_events` + `invite_renewal_requests` (§8.5 attribution + §8.5.1 renewal ceremony) — `20260804140000_stage_8_5_deep_link_attribution.sql`
  - `invite_send_queue` + `ops_alert_events` (§8.7 circuit-breaker queue + ops alerting) — `20260805180000_stage_8_7_rate_limit_circuit_breaker.sql`
> [!WARNING]
> **`device_push_tokens` is NOT part of Stage 8** (v3.5 correction — it was previously listed above as a delivered Stage 8 table, but no migration ever created it). The table, its Edge registration path, and token pruning are owned by **§11.0 FCM Push Infrastructure**. Stage 8 therefore has **no push rail at all**, which is why every "ping the merchant" behaviour in §8.5.1 is in-app only. This is a scope correction, not an open Stage 8 task — do not add it to this stage.
- [x] **Ledger archiving column (Stage 6.7 sync integration):** `ledgers` PostgreSQL table adds `is_user_archived BOOLEAN DEFAULT false`. RLS policies enforce: readers get SELECT on archived rows; writers (Editor/Owner) CANNOT mutate contacts/transactions under `is_user_archived = true` ledgers (defense-in-depth). Only Owner can toggle `is_user_archived`. Supabase syncs the boolean flag only — no additional sync infra for archived data.
  - **Carry-forward sync:** `carry_forward_target_ledger_id` column synced on `ledgers`. Rollover-generated contacts and opening-balance transactions are ordinary `CREATE` ops — no special merge rules. Bulk ceremony ops share a `carryForwardOperationId` in audit payloads for server-side tracing.
- [x] Implement RLS: every **business** row (`ledgers`, `contacts`, `transactions`, `contact_balances`, `audit_logs`, `workspace_members`, `shared_accounts`) is keyed to `workspace_id`; access granted only if `auth-jwt.workspace_id` matches AND an active `workspace_members` row exists (`jwt_is_member` / `jwt_member_role` in `20260802160000_band_a_rls_hardening.sql`); **viewers get SELECT-only** policies; **B2C Shared-Account data-slice RLS deferred to Stage 11** (binding-row SELECT exists; contact/txn slice policies land with customer portal).
  - **Deliberately not workspace-keyed** (service-role-only, no client-facing RLS surface): `rate_limit_buckets`, `invite_send_queue`, `ops_alert_events`, `deep_link_events`, `migration_challenges`, `promo_codes`, `referrals`, `ai_usage_counters`. `deep_link_tokens.workspace_id` is **nullable** by design (referral tokens pre-date a workspace); `archived_shared_ledger` intentionally stores `workspace_id_origin` as plain TEXT so the snapshot survives workspace deletion (§11.4). Any future client-readable policy on these tables must be justified explicitly.
- [x] Enforce the **seat cap** (Owner + 2 Workers) as DB constraints (`seat_index` 0–2 + unique). **Sharing cap** DB guard stub: `workspaces.sharing_cap` (default 0) + `enforce_sharing_cap` trigger on `shared_accounts` — Edge Functions raise the cap with entitlements (Stage 11 completes product wiring Free 0 / Pro 30 / Pro+ 500).
- [x] Time-partition `audit_logs` by month (financial-study mandate: avoid vacuum bloat before 100K users).
- [x] Map verified identity → workspace membership (auto-create owner workspace on first sync). *(Implemented in Edge Function `verify-google-token` → `resolveWorkspace()` / `provision_workspace` RPC: looks up existing workspace by owner_identity, checks worker membership by email, or atomically creates workspace + owner seat on first sync.)*

**8.2 Auth Bridge (Google Sign-In → Supabase sync JWT)** *(formerly 8.3)*

- [x] Edge Function `verify-google-token`: **COMPLETE** — cryptographic Google ID token verification (RS256 against Google JWKs), identity→workspace resolution with auto-provisioning, HMAC-SHA256 custom sync JWT signing (`workspace_id` + `workspace_role` + `identity_hash`), anti-enumeration error responses (auth → 401, infra → 503, same body), CORS, 3600s TTL. *(`supabase/functions/verify-google-token/index.ts`)*
- [x] Create `supabase_auth_bridge_ds.dart`: exchange Google ID token for the short-lived custom sync JWT via `verify-google-token`; store in `flutter_secure_storage`; lazy refresh via `ensureSyncToken` (Stage 8.4 must call this off the local CRUD path). *(lib/data/datasources/remote/supabase_auth_bridge_ds.dart + lib/core/services/sync_token_store.dart + SyncAuthBridgeRepository)*
- [x] Bridge provider linking Google Sign-In status ↔ sync-token state; handle "Google valid but sync token expired → re-exchange"; Pro+ fail-closed RBAC via last-known membership (never escalate to owner). *(lib/presentation/providers/sync_auth_bridge_provider.dart + lib/application/auth/exchange_sync_token_use_case.dart + resolve_workspace_role_use_case.dart)*

**8.3 The Merge Engine (Conflict Resolution)** *(formerly 8.4)*

> [!IMPORTANT]
> Financial-grade integrity: **no transaction may ever be silently lost or double-counted** during sync. Balances are recomputed from transactions after every merge, never trusted as transported.

- [x] ~~**Op-log model:** sync is replay of the local append-only `AuditLog` (CREATE/UPDATE/DELETE ops), not row-diffing. Each op carries `entityId`, `field deltas`, `deviceId`, `localTimestamp`.~~  **COMPLETE** — `SyncOperation` freezed entity + `SyncOperations` Drift table + `SyncOperationModel` + mappers. Ops ordered by server-assigned `opSeq`, never device clocks. *(lib/domain/entities/sync_operation.dart, lib/data/datasources/local/tables/sync_operations_table.dart, lib/data/models/sync_operation_model.dart, lib/data/mappers/sync_operation_mapper.dart)*
- [x] ~~**Ordering authority:** server assigns a monotonic `op_seq` + `server_updated_at` on receipt; clients order by server values, not device clocks (clock-skew safe).~~  **COMPLETE** — `MergeEngineLocalDs.applyRemoteOps()` sorts by `opSeq` before processing; field-level LWW uses `serverUpdatedAt` for comparison. *(lib/data/datasources/local/merge_engine_local_ds.dart)*
- [x] ~~**Field-level Last-Write-Wins (LWW):** conflicts resolved per-field by latest `server_updated_at`, so two workers editing different fields of the same contact both succeed. **Deterministic tiebreak** for identical timestamps: **Owner > Editor**, then lowest `deviceId` — fully enumerable because concurrent editors are capped at 2 (see economics).~~  **COMPLETE** — `_lwwField<T>()` generic method: latest `serverUpdatedAt` wins per-field; on identical timestamps it applies the full documented tiebreak — (1) role priority (Owner > Editor > Viewer), then (2) **lowest `deviceId` lexicographically**. Spec and implementation match exactly. *(`_lwwField` in lib/data/datasources/local/merge_engine_local_ds.dart)*
- [x] ~~**Safety rules (non-negotiable):**~~  **COMPLETE** — All three rules enforced inside ACID transaction:
  - ~~**Modification wins over deletion**~~ — `_updateLedger`/`_updateContact`/`_updateTransaction` un-delete entities on remote edit + emit audit note.
  - ~~**Transactions are immutable ledger facts**~~ — `_createTransaction()` always additive, never conflicts. `_updateTransaction`/`_deleteTransaction` use LWW then trigger `_recalculateBalance()`.
  - ~~**Money is never merged arithmetically across devices**~~ — `_recalculateBalance()` deletes all `ContactBalance` rows for the contact and recomputes per-currency from the full surviving `transactions` set in a single DB transaction. *(`_recalculateBalance` in lib/data/datasources/local/merge_engine_local_ds.dart)*
- [x] ~~**Duplicate guard:** dedupe ops by `(entityId, deviceId, opId)` idempotency key so retried pushes can't double-apply.~~  **COMPLETE** — `_isAlreadyApplied()` checks the unique index `idx_sync_ops_idempotency` on `(entityId, deviceId, id)`. *(`_isAlreadyApplied` in lib/data/datasources/local/merge_engine_local_ds.dart)*
- [x] ~~**Tombstones:** deletes are tombstoned with `deleted_at` + retained for the sync window so offline devices learn of deletions.~~  **COMPLETE (local semantics)** — `_deleteLedger`/`_deleteContact`/`_deleteTransaction` set `isDeleted = true` (soft delete) + bump `syncVersion`; no row is ever hard-deleted. *(lib/data/datasources/local/merge_engine_local_ds.dart)* **The "sync window" itself is still undefined — see §8.4 open items;** retention is currently unbounded (no purge job), so this promise holds only by accident until the window is ratified.
- [x] ~~**Conflict surfacing:** ambiguous cases are flagged to the Smart Merge UI (**Stage 10**), not auto-merged — specifically **cross-worker concurrent-create** (two workers create the same contact offline) and delete-vs-edit races. With ≤ 2 workers the flagged-conflict set is small, bounded, and exhaustively testable.~~  **COMPLETE** — `MergeConflict` entity + `MergeConflicts` Drift table + `_surfaceAmbiguousConflict`/`_surfaceConcurrentCreate` methods persist conflicts for Stage 10 Smart Merge UI. ConflictType enum: `deleteVsEdit`, `concurrentCreate`, `ambiguous`. *(lib/domain/entities/merge_conflict.dart, lib/data/datasources/local/tables/merge_conflicts_table.dart, `_surfaceAmbiguousConflict` / `_surfaceDeleteVsEdit` / `_surfaceConcurrentCreate` in lib/data/datasources/local/merge_engine_local_ds.dart)*
- [x] ~~Create `sync status` provider (last sync, pending op count) + a **"Sync Report"** screen (what changed, what conflicted, what was auto-resolved).~~  **COMPLETE** — `SyncStatus` entity, `syncStatusProvider`/`unresolvedConflictsProvider` (Pro+ gated), `SyncReportScreen` with Khazna v3 Lapis Lux design (dormant banner for non-Pro+ users, status card, stats row, conflict tiles). Route: `/settings/sync-report`. *(lib/domain/entities/sync_status.dart, lib/presentation/providers/sync_providers.dart, lib/presentation/screens/sync/sync_report_screen.dart)*
- [x] ~~Tests: offline edits on 2 devices → reconnect → verify field-level merge; delete-vs-edit → verify edit survives; concurrent transaction inserts → verify both kept + balance correct; retried push → verify idempotency.~~  **COMPLETE** — **10 groups / 18 tests**: idempotency guard · field-level LWW · modification > deletion safety rule · concurrent transaction inserts · balance recalculation · deterministic tiebreaker (Owner > Editor, then lowest `deviceId`) · concurrent-create conflict · contact merge · financial silence bans · edge cases. *(test/data/merge_engine_test.dart, 679 lines)*

---

##### Band B — Live Sync

**8.4 Sync Engine — Client Wiring** *(formerly 8.9)*

> [!NOTE]
> **Depends on:** §8.1–§8.3. This is the heart of multi-device sync — without it the Merge Engine has nothing to pull/push against a live server.
>
> **Unlocks:** end-to-end multi-device reconciliation; later bands that assume ops flow over the network.
>
> **Transport shape (as shipped):** both push and pull are **REST calls to Edge Functions** (`push-sync-ops` / `pull-sync-ops`). Realtime is used **only as a wake-up signal** that tells the client "something changed in your workspace, go pull" — it never carries op payloads. This keeps Realtime message billing near zero and means a dropped socket degrades to polling, never to data loss.

- [x] Create `sync_remote_ds.dart` — Edge/REST push + pull of the op-log, plus a **workspace-scoped Realtime wake-up channel** (`sync-wakeup-{workspaceId}`) subscribed **only by Owner/Editor** (`startMerchantRealtime`). Viewers and B2C never open a socket; they pull on demand. *(lib/data/datasources/remote/sync_remote_ds.dart + lib/presentation/providers/sync_engine_providers.dart + lib/application/sync/start_sync_engine_use_case.dart)*
- [x] Push: local `AuditLog` ops → server; receive assigned `op_seq` + `server_updated_at`. *(Drift `sync_outbound_acks`, `push-sync-ops` Edge Function, `SyncEngineRepositoryImpl.pushPending`)*
- [x] Pull: server ops → local Drift via the Merge Engine (§8.3); recompute affected balances atomically. *( `pull-sync-ops` Edge Function + `pullAndMerge`)*
- [x] Manual "Sync Now" + automatic sync on connectivity change (`connectivity_plus`); respect Pro+ device cap (10 devices) + monthly sync-event cap (50,000). *(Sync Report CTA, `SyncEngineController`, `workspace_devices` + `sync_usage_counters` migration)*
- [x] **Archived ledger sync optimization (Stage 6.7 / CTO mandate) — implemented server-side, not per-channel.** *(v3.5 correction: this item previously mandated a `WHERE is_user_archived = false` Realtime filter and per-ledger subscribe/unsubscribe. Neither was built, and neither is needed — the shipped design achieves the same saving more cheaply.)* As shipped:
  - The `is_user_archived` flag **is** synced as an ordinary op-log field (`_shared/sync_ops.ts` push mapping).
  - **`pull-sync-ops` excludes child ops** (contacts/transactions) belonging to archived ledgers server-side (`shouldExcludeOp`), so an archived ledger costs **zero egress and zero merge work** on every device.
  - Realtime is **one workspace-scoped wake-up channel**, not one channel per ledger — so archiving cannot leave stale listeners behind and there is nothing to unsubscribe. Archive/un-archive needs no channel churn; the next pull simply includes or excludes the child ops.
  - **Deliberate non-goal:** per-ledger Realtime channels. They would multiply peak-connection billing (the exact cost driver §8's economics avoids) to save nothing.
- [x] Backpressure + retry with the existing exponential-backoff policy; never block offline usage. *(lib/core/utils/network_retry_policy.dart + orchestrator single-flight)*
- [x] **B2C client path (stub only in this band):** Shared-Account viewers use **push-triggered + fetch-on-open** (no persistent socket). Full customer-local immutable mirror is completed in **§11.3** — do not invent a parallel B2C write path here. *(`lib/data/datasources/remote/shared_account_sync_client.dart` — an 18-line **no-op placeholder**: `fetchOnOpen` and `onPushNotification` do nothing. It exists to pin the interface shape and forbid a parallel write path, not to deliver behaviour.)*
- [ ] **New-device bootstrap snapshot (v3.4 forensic gap):** a brand-new device currently replays the **entire** op-log. Add a periodic / on-demand **workspace snapshot checkpoint** (or compacted snapshot RPC) so first sync of a large shop is bounded — not O(all history).
  - **Acceptance:** first sync of a workspace with ≥ 50,000 historical ops completes in bounded time and bounded egress, and produces **the same surviving-row set and the same balances** as a full op-log replay of that workspace.
- [ ] **Define the op-log / tombstone retention window (blocks the item below — currently undefined).** §8.3 promises tombstones are "retained for the sync window," but **no window is specified in the roadmap, the migrations, or the client.** Today `audit_logs` is monthly-partitioned with **no purge job**, so retention is effectively infinite and the divergence risk is latent — it becomes real the instant compaction or a PDPL purge lands (§11.4 / §19.3). Ratify a concrete value before writing the resync logic. **Recommended default: 90 days** (3 `audit_logs` partitions; a device offline longer is a re-onboard, not a resync). Record it as a named server constant so client and server cannot drift.
- [ ] **Tombstone retention-miss detection + forced full resync (v3.4 forensic gap):** if a device stays offline longer than the retention window above, it can silently diverge. `pull-sync-ops` must detect that a client's cursor predates the retained window and return an explicit **`retention_miss`** result; the client then discards local state for that workspace and **rebuilds from the snapshot checkpoint** — never silently accepting a partial history.
  - **Depends on** the two items above (there is nothing to resync *from* without a snapshot, and nothing to detect *against* without a window).
  - **Acceptance:** a device whose cursor is older than the window receives `retention_miss` (not a truncated op page), rebuilds from snapshot, and ends with balances identical to an in-window device.

---

##### Band C — Join Paths (Deep Links → Worker Acceptance)

**8.5 Deep-Link & Attribution Service (Shared Foundation for Stages 11 & 16)** *(formerly 8.6)*

> [!CAUTION]
> **Firebase Dynamic Links shut down 2025-08-25.** Do NOT use it. Build on OS-native links + our own domain; add deferred-install attribution.
>
> **Depends on:** §8.1 (token tables), §8.2 (authenticated claim context). **Required before:** §8.6 invite acceptance, Stage 11, Stage 16.

- [x] Host link infra on our **own branded domain** (`daftar.app`): author `/.well-known/assetlinks.json` (Android App Links) and `/.well-known/apple-app-site-association` (iOS Universal Links). *(`link-hosting/.well-known/` + Android `intent-filter` with `autoVerify` + iOS `Runner.entitlements` `applinks:daftar.app` + `Env.deepLinkBaseUrl`.)*
  - ⚠️ **`assetlinks.json` still carries a placeholder SHA-256** and nothing is served from a public host, so **OS-level link verification cannot succeed yet.** Real fingerprint + live host are **§14.8**; Band E therefore exercises deep links over local/LAN only.
- [x] **Installed-app routing (deterministic, both platforms):** HTTPS link opens the app directly via App Links / Universal Links → in-app router resolves the `deep_link_tokens` intent. *(app_links DeepLinkController + go_router `/invite/*`)*
- [x] **Deferred routing (survives install):** *(Decision 1A: Android deterministic via Play Install Referrer; iOS clipboard/manual only — no probabilistic Edge)*
  - **Android (deterministic):** landing page at `link-hosting/i/index.html` redirects to Play Store with `referrer=utm_content={token}`; `PlayInstallReferrerService` reads Install Referrer on first launch → `resolve-deep-link` → invite accept flow. *(play_install_referrer + `log-deep-link-click`)*
  - **iOS (fallback only):** App Store redirect + clipboard/manual code in `ExpiredInviteCeremonyScreen` — probabilistic match **deferred by design**.
- [x] Edge Function `create-deep-link`: mints an opaque token + stores intent (`kind`, `workspaceId`, `contactId` or `referrerId`, TTL) → returns the short HTTPS URL. *(supabase/functions/create-deep-link)*
- [x] Edge Function `claim-deep-link`: validates token, binds it to the claiming device/account atomically, and returns a **typed result** (see §8.5.1) — never a generic error. *(supabase/functions/claim-deep-link + `google_email` gate for worker invites)*
- [x] Edge Function `resolve-deep-link`: read-only token preview for worker-invite routing without premature claim. *(supabase/functions/resolve-deep-link)*
- [x] Edge Function `log-deep-link-click`: landing-page click analytics (`deep_link_events.click`). *(Decision 2A)*
- [x] **Decision:** build this lightweight router in-house on Supabase (no vendor lock-in, cost-disciplined). Keep **Branch (free ≤10K MAU) / ChottuLink (free ≤25K MAU)** as a drop-in *only if* iOS deferred-match accuracy proves insufficient at scale.
- [x] Click + claim analytics logged for attribution (powers Referral verification in Stage 16). *(click via `log-deep-link-click`; claim via `claim-deep-link`)*

**8.5.1 TTL Lifecycle & Expired-Link Ceremony (Mandate 3)** *(formerly 8.6.1)*

> [!IMPORTANT]
> **Gap closed:** an expired / claimed / revoked token previously had no graceful path, stranding a user who installed *after* the link expired. Every terminal state now routes to a localized "Request New Invitation" ceremony that reaches the host merchant **in-app** (push delivery is §11.0).
>
> **Depends on:** §8.5 mint/claim functions. **Rate-limit wiring** for `request-new-invite` is finalized in §8.7 (implement the endpoint here; harden quotas there).

- [x] **Token state machine:** `active` → `claimed` | `expired` | `revoked` | `superseded`. TTL by kind: `worker_invite` **72h**, `share` **30d** (customers may install later), `referral` **30d**. *(Postgres `token_kind` / `token_state` ENUMs + `expires_at` in `20260706120000_deep_link_tokens_state_machine.sql`; the same three TTLs are mirrored in `supabase/functions/_shared/deep_link_types.ts` — SQL and TS agree.)*
- [x] **Typed claim results** (server): `ok(intent)`, `expired`, `revoked`, `already_claimed(by_you | by_other)`, `not_found` — anonymous callers cannot distinguish `not_found` from `revoked` (anti-enumeration). *(TS: `supabase/functions/_shared/deep_link_types.ts`; Dart sealed classes: `lib/domain/entities/deep_link/deep_link_claim_result.dart` + `deep_link_claimed_by.dart`.)*
- [x] **Client lifecycle routing** — applies to ALL entry paths (App Link, Universal Link, AND the **post-install Play Install Referrer / iOS deferred match**): on any non-`ok` terminal state, present the **"Request New Invitation" ceremony**, never a dead-end:
  - Localized (Arabic-first) explanation that the link expired.
  - One-tap **"Request a new invitation"** → Edge Function `request-new-invite` → **notifies the host merchant** in-app, carrying the original intent metadata so the merchant **one-taps "Re-send."** *(Shipped end-to-end minus push: `request-new-invite` inserts into `invite_renewal_requests`; `list-invite-renewal-requests` feeds a renewal inbox on the Team screen; **one-tap re-send** calls `invite-worker` then `fulfill-invite-renewal-request`. See `member_management_screen.dart`.)*
  - ⚠️ **The "ping" is passive, not pushed.** The merchant only sees the request when they next open the Team screen — there is **no FCM** in Stage 8 (`device_push_tokens` and the push rail are owned by **§11.0**, which explicitly closes this stub). A requester can therefore wait indefinitely if the merchant never opens that screen; the fallback is out-of-band (the requester tells the merchant).
  - Pending state ("We've notified {merchant} — a new link is on the way"); fallback = manual short-code entry. *(ExpiredInviteCeremonyScreen)*
- [x] **Re-issue rules:** a re-issued token marks the prior one `superseded`. Full multi-dimensional rate limits land in §8.7. *(`invite-worker` supersedes the prior token on re-invite; the renewal path routes through the same function, so re-sends inherit both the supersede rule and the §8.7 limits.)*
- [x] Tests: install *after* expiry → ceremony shown + merchant notified + re-send works; revoked link → ceremony (not raw error); `already_claimed(by_other)` → safe localized message; superseded old link → inert. *(Unit-level only: token parse + claim JSON mapping + Deno type-check. **The full install-after-expiry journey is not automated** — it is covered manually by the two-phone runbook and is a Band E gate item.)*

**8.6 Multi-Worker Collaboration — Email Invites & Granular Permissions (Pro+)** *(formerly 8.5)*

> [!NOTE]
> This is the Pro+ collaboration moat. A shop owner invites employees by **email**; they join the **same workspace** with a bounded role. **Hard limit: Owner + up to 2 Workers (3 seats max), and at most 2 concurrent Editors** — derived from the quadratic conflict-surface math in the economics block above. Free/Pro are solo.
>
> **The two caps are different rules and must not be conflated:**
> - **Seat cap = 3 members** (Owner + 2 Workers). Exceeding it is **rejected** (`seat_cap_exceeded`, HTTP 409).
> - **Editor cap = 2 concurrent Editors, and the Owner is one of them.** The Owner always occupies an editor slot, so at most **one** Worker may be an Editor and the third member must be a Viewer. Exceeding it is **not** an error — the requested role is silently **downgraded to Viewer** and the effective role is returned in the response.
>
> **Depends on:** §8.1–§8.4 for live sync; **§8.5** deep-link resolve + claim pipeline.

- [x] Edge Function `invite-worker`: owner submits invitee email + role (`editor` / `viewer`); creates a pending `workspace_members` row + a signed, expiring **email invite link** (own-domain Universal/App Link → in-app accept screen, `worker_invite` TTL per §8.5).
  - **Seat cap enforced server-side:** rejects with `seat_cap_exceeded` when the workspace already has 2 active/pending Workers, backed by the DB constraint `seat_index BETWEEN 0 AND 2` + `UNIQUE (workspace_id, seat_index)`.
  - **Subject to the invite rate-limit circuit breaker (§8.7).** *(multi-dimensional limiter + global breaker shipped in `20260805180000_stage_8_7_rate_limit_circuit_breaker.sql` + `_shared/rate_limit.ts`)*
- [ ] 🐞 **DEFECT — the ≤ 2 concurrent-Editor cap is not actually enforced (v3.5 audit).** `invite-worker` counts only rows with `role = 'editor'` and **omits the Owner**, who is editor-capable by definition. Because a 3rd Worker is rejected by the seat cap first, `editors.length >= 2` is **unreachable** — the downgrade branch is dead code, and a workspace can reach **Owner + 2 Editor Workers = 3 concurrent editors**. That is 3 conflict pairs instead of the 1 the Merge Engine was sized for, and it invalidates the "small, bounded, exhaustively testable" premise that **Stage 10's deterministic review UI** depends on. **Fix:** count the Owner in the editor tally (an Owner + 1 Editor workspace is already at the cap), keep the downgrade-not-reject semantics, surface the downgrade in the client, and add a regression test asserting the 2nd Editor invite comes back as `viewer`.
- [x] **Invite acceptance:** invitee installs/opens app → `resolve-deep-link` → Google Sign-In → email match → `claim-deep-link` → JWT re-exchange → merchant workspace sync. *(AcceptWorkerInviteUseCase + InviteAcceptHandoffScreen; worker sync entitlement without personal Pro+)*
- [x] **Permission matrix (enforced in BOTH the application use-case layer AND Postgres RLS — defense in depth):**

  | Capability | Owner | Editor | Viewer |
  |---|---|---|---|
  | View ledgers/contacts/balances | ✅ | ✅ | ✅ |
  | Add/edit/delete transactions | ✅ | ✅ | ❌ |
  | Create/edit contacts & ledgers | ✅ | ✅ | ❌ |
  | Voice input / WhatsApp reminders | ✅ | ✅ | ❌ |
  | Invite/remove workers, change roles † | ✅ | ❌ | ❌ |
  | Billing, promo codes, delete workspace | ✅ | ❌ | ❌ |
  | Configure shared customer accounts | ✅ | ✅ | ❌ |

  *† This is the **authorization** spec (`WorkspacePermission.inviteWorkers` in `lib/domain/permissions/permission_matrix.dart`, mirrored by RLS). Invite and remove are shipped; **"change roles" has no implementation yet** — see the role-change item below.*

- [x] Member management screen: list members + roles + status; **resend** invite; **revoke** invite; **remove** member (revokes their sync JWT on next refresh); plus the §8.5.1 renewal-request inbox with one-tap re-send. *(revoke via `revoke-worker-invite`; resend = re-invite the same email through `invite-worker`. **Changing an existing member's role is NOT in this screen** — see the next item.)*
- [ ] **Role-change flow (v3.4 forensic gap):** there is currently **no way to change a member's role after invite** — the role is fixed at invite time, so correcting a mistake means remove + re-invite (which burns a seat transition and a rate-limit token). Owner must be able to promote/demote Editor ↔ Viewer while honouring the **≤ 2 concurrent Editors** cap (fix the defect above first — otherwise the promote path inherits the same off-by-one); demotion mid-flight cancels pending writes gracefully.
- [ ] **Revoked-membership local wipe ceremony (v3.4 forensic gap):** when a worker is removed, the next token refresh must **wipe or lock** their local Drift copy of the shop workspace (financial data must not linger on a fired employee's phone). Today `RemoveWorkspaceMemberUseCase` only performs the remote removal + audit — **the ex-worker's full local copy of the merchant's ledgers survives on their device indefinitely.** Offer export-to-personal only if Owner explicitly grants it pre-revoke. Audit the wipe.
- [x] Audit every membership/permission change to `AuditLog`.
- [x] Tests: viewer attempts a write via tampered client → rejected by RLS; removed worker loses access on token refresh; editor cannot invite. *(**Application-layer only**: `test/domain/permissions/permission_matrix_test.dart`, `test/application/collaboration/invite_worker_use_case_test.dart`. **No test exercises Postgres RLS itself**, so the "defense in depth" claim above is currently proven on one layer, not two — the RLS half is a Band E gate item.)*

---

##### Band D — Hardening Mandates

**8.7 Email & Invite Rate-Limiting Circuit Breaker (Mandate 2)** *(unchanged number; was always 8.7)*

> [!IMPORTANT]
> **Gap closed:** invitation endpoints (worker invites, B2C shares, re-issues) were uncapped — a spam/abuse vector that risks **transactional-email domain blacklisting**. All invite-class endpoints now sit behind a multi-dimensional token-bucket limiter + a global circuit breaker.
>
> **Depends on:** §8.5 (`create-deep-link`, `request-new-invite`) and §8.6 (`invite-worker`) existing so limits can be applied to real endpoints. The §8.1 stub bucket has been replaced by the full circuit breaker.

- [x] **Multi-dimensional token buckets** (most-restrictive-wins), evaluated inside `invite-worker`, `create-deep-link` (`share` + `referral`), and `request-new-invite` (`renew_invite`). Every dimension is a burst capacity + sustained hourly refill, consumed atomically by the `consume_rate_limits` RPC. **Shipped values:**

  | Action | Dimension | Pro+ | Pro |
  |---|---|---|---|
  | `worker_invite` | workspace / hr | 3 | 2 |
  | `worker_invite` | workspace / day | 10 | 5 |
  | `share` · `referral` | workspace / hr | 20 | 10 |
  | `share` · `referral` | workspace / day | 100 | 50 |
  | all invite actions | source IP / hr | 30 | 15 |
  | all invite actions | destination email / hr | 1 | 1 |
  | all invite actions | destination domain / hr | 5 | 3 |
  | `renew_invite` | per-token / hr | 5 (refill 2) | 3 (refill 1) |
  | all invite actions | **global / hr** (circuit breaker) | 200 | 100 |

- [ ] **GAP — the per-merchant tier is not resolved per caller (v3.5 audit).** `resolveRateTier()` reads the deploy-wide env var `INVITE_RATE_TIER_DEFAULT` and **defaults every workspace to `pro_plus`**; no call site passes a per-workspace tier, so the `pro` schedule above is currently unreachable in production and a Pro merchant receives Pro+ (looser) limits. The tables are correct; the **wiring from entitlement → `ctx.tier`** is missing. Also note there is **no `free` schedule** — Free is expected to be blocked upstream (0 worker seats, 0 share hosts), which is an assumption Stage 11 must not break.
- [x] **Global leaky-bucket circuit breaker** on total outbound transactional email/hour: if tripped, **pause sending + queue** invites and alert ops — protects domain reputation over throughput. *(queue: `invite_send_queue`; alert: `ops_alert_events`; **no SMTP send in this band** — invites mint copy/share URLs only; SMTP drain + deliverability land in §19.4)*
- [x] **Normalized responses:** return a uniform "rate limited, retry-after" without revealing which dimension tripped (anti-probing).
- [x] Tests: burst past per-merchant cap → throttled; same-email hammering → cooled down; global breaker trip → queue + alert, no domain damage; limits scale by tier. *(Deno `supabase/functions/_shared/rate_limit_test.ts`; Flutter `test/data/datasources/remote/edge_function_errors_test.dart`, `test/core/utils/error_translator_rate_limit_test.dart`. **"Limits scale by tier" is proven against the schedule tables, not end-to-end** — see the tier-wiring gap above. SQL/`consume_rate_limits` integration coverage is a Band E gate item.)*

> [!NOTE]
> **Deferred to §19.4 (Enterprise Handoff — Transactional Email):** (1) verified sender domain with SPF/DKIM/DMARC + bounce/complaint feedback loop with merchant auto-suspend; (2) CAPTCHA / Play Integrity / DeviceCheck step-up on suspicious velocity. Soft velocity is already handled via the IP bucket's longer effective cooldown. Do **not** block Stage 8 on an email provider.

---

##### Band E — Gate

#### Stage 8 Validation Gate

> [!IMPORTANT]
> **Do not start Stage 10 (Smart Import & Merge) until every item below is checked.** Stage 10 consumes Merge Engine conflict flags and assumes live sync + worker caps are proven on **local Docker**. **Stage 9 (Onboarding)** may proceed in parallel — it is local-first and does not depend on the Merge Engine. Ownership-transfer and immutable-receipt gates live in Stages 13 and 11 respectively. Public-internet Install Referrer QA lives in **§14.8**.
>
> **Precondition — the gate cannot open while any Band A–D checkbox is unchecked.** As of the v3.5 audit that means: §8.4 bootstrap snapshot + retention window + retention-miss resync, §8.6 editor-cap defect + role-change flow + revoked-membership wipe, and §8.7 per-caller tier wiring. Close those first, then run the gate.

**Correctness (Merge Engine + caps)**

- [ ] Two devices + two workers can edit offline and reconcile with zero data loss and correct balances; a 3rd worker invite is rejected by the seat cap. *(requires §8.4 + §8.6)*
- [ ] **A workspace can never reach 3 concurrent Editors:** with Owner + 1 Editor already active, an `editor` invite comes back with effective role `viewer` and the client says so. *(closes the §8.6 editor-cap defect)*
- [ ] **Role change respects the caps:** promoting a Viewer when Owner + 1 Editor already exist is refused or downgraded, never silently granted; a demotion mid-write does not corrupt a pending op. *(requires §8.6 role-change flow)*
- [ ] Balances after any merge equal a from-scratch recomputation over the surviving transaction set — verified on a workspace with ≥ 1,000 transactions, in every currency present.

**Durability (new-device + long-offline)**

- [ ] **A brand-new device bootstraps from a snapshot, not from full history**, and lands on balances identical to a device that replayed everything. *(requires §8.4 snapshot)*
- [ ] **A device offline past the retention window is forced into a full resync** — it receives `retention_miss`, rebuilds from snapshot, and never silently accepts a truncated op page. *(requires §8.4 retention window + resync)*

**Security & tenancy**

- [ ] Viewer role cannot write through either the app or a tampered client — **and this is proven at both layers separately**: an application-layer test AND a direct Postgres test that bypasses the app and is rejected by RLS. *(requires §8.1 + §8.6; closes the untested half of "defense in depth")*
- [ ] **Cross-workspace isolation:** a valid sync JWT for workspace A cannot read or write any row of workspace B — attempted at the SQL layer, not just through the client.
- [ ] **A removed worker's local copy is wiped or locked on the next token refresh**, and the wipe is audited. *(requires §8.6 revoked-membership ceremony)*
- [ ] All privileged logic lives in authenticated, rate-limited Edge Functions; no service keys in the client. *(grep the built artifact, not just the source.)*

**Abuse control**

- [ ] Invite endpoints throttle correctly per dimension; the global circuit breaker trips, queues to `invite_send_queue`, raises an `ops_alert_events` row, and sends no SMTP. *(requires §8.7)*
- [ ] **Rate-limit responses are uniform** — a caller cannot tell which dimension tripped by comparing bodies, status codes, or timing.
- [ ] **A Pro workspace receives Pro limits and a Pro+ workspace receives Pro+ limits** against a live stack. *(closes the §8.7 tier-wiring gap)*

**Join paths & environment**

- [ ] An expired post-install deep link routes to the "Request New Invitation" ceremony and reaches the merchant (no stranding), and the merchant's one-tap re-send produces a working invite. *(requires §8.5.1; local/LAN. **Scope note:** the merchant is notified in-app only — real push delivery is §11.0 and is explicitly NOT gated here.)*
- [ ] Local Docker stack (`supabase start` + migrations + Edge Functions) supports the full merchant sync path end-to-end **from a clean `supabase db reset`** — no manual SQL, no hand-edited rows.

---

### Stage 9: Stunning Onboarding, Frictionless Setup & Delight System (Phase 2)

> [!IMPORTANT]
> **v3.4 Mandate 5.** Phase 1's onboarding was a weak 3–4 walkthrough in Stage 7.4. Activation compounds into every later stage — this stage makes the merchant's **first 90 seconds** breathtaking, Arabic-first, and frictionless. The **Delight System** extracted here is the shared success-moment primitive reused by Stages 12, 16, and 18 (AI no longer owns it).

**Goal:** Capture the merchant's heart from the first frame; auto-detect language / currency / country so setup is confirm-not-configure; guide them to their first ledger and theme; teach critical features with sticky (non-instantly-dismissable) moments; instrument the activation funnel.

**Prerequisites:** Stages 0–7 complete. Stage 0.3.2 Firebase Analytics strongly recommended for funnel events. Stage 8 not strictly required (onboarding is local-first).

**Features from Product Plan:**

- Stunning Onboarding & Frictionless Setup (new — v3.4)
- Delight System (shared success UX primitive)
- Educational UX / sticky teaching moments

#### Task Checklist

**9.1 First-Run Experience (Heart-Capture)**

- [ ] Animated splash → 3–4 Khazna v3 story screens (Arabic-first RTL): track debts → share statements → never lose a receipt → grow free with referrals.
- [ ] Lapis is **glow / hairline only** — never fill (Lapis Law). Monochrome surfaces + semantic debt/payment accents only.
- [ ] 60fps animation budget; `MediaQuery.disableAnimations` / reduce-motion → static story cards, no forced motion.
- [ ] Existing users (already have a ledger) get a lightweight **"What's new"** variant — never force the full first-run flow again.

**9.2 Zero-Friction Auto-Detection**

- [ ] Pre-select **language** from device locale (Arabic if `ar*`, else English) — one-tap confirm.
- [ ] Pre-select **country** from SIM MCC (preferred) and/or coarse IP geolocation when online; fallback = device locale region.
- [ ] Map country → **default currency** (YE→YER, SA→SAR, EG→EGP, AE→AED, …); allow override.
- [ ] Prefer **Arabic-Indic numerals** (`٠١٢…`) when Arabic locale; Gregorian + optional Hijri display helpers already in core.
- [ ] Detect timezone for morning-push scheduling (Stage 12).
- [ ] **No GPS permission.** Fully offline-safe: if network/SIM unavailable, device locale alone is enough.
- [ ] Single **"Looks right?"** confirmation screen showing language + country + currency + theme preview.

**9.3 Guided First Ledger & Theme**

- [ ] Ledger template picker with pre-filled Arabic names (e.g. زبائن / موردين / شخصي) + icon/color.
- [ ] Live **theme** preview (Dark / Light / System) before commit.
- [ ] Optional store name (+ optional logo later) feeding `MerchantProfile` so the first branded PDF is one tap away.
- [ ] Optional first contact + optional "import CSV" hook (free feature).
- [ ] North-star outcome: merchant reaches **first saved transaction** with minimal taps.

**9.4 Sticky Teaching Moments (Educational UX Hack)**

> [!CAUTION]
> Do **not** allow instant dismiss of critical tips. Replace "Skip" with a **5-second countdown ring** *or* a mandatory **"Don't show again"** checkbox the user must consciously tick. Accessibility escape hatch is mandatory so screen-reader / reduce-motion users are never trapped.

- [ ] Coach-marks for: Quick-Add FAB, Debt(عليه)/Payment(له) polarity, swipe-to-delete + undo, Google Drive backup, Archive Vault (when Pro).
- [ ] Per-tip persistence in `AppSettings` / local prefs; frequency cap so the system never feels hostile.
- [ ] Countdown ring is visual + announced to TalkBack/VoiceOver; a11y path allows immediate dismiss via explicit "I understand" after focus.
- [ ] Tests: tip cannot be dismissed before 5s without checkbox; a11y path works; "don't show again" sticks across restarts.

**9.5 Notification Permission Priming**

- [ ] Contextual pre-prompt (Arabic-first) explaining *why* (balance alerts, customer updates, morning summary) **before** the OS dialog.
- [ ] Android 13+ `POST_NOTIFICATIONS` + iOS APNs request after priming (depends on Stage 0.3.2 FCM foundation).
- [ ] Soft-deny path: Settings deep-link later; never block onboarding.

**9.6 Delight System (Shared Success Primitive)**

- [ ] Extract reusable success moment: bundled vault/coin chime (≤1s), haptic map (`mediumImpact` / `heavyImpact`), balance count-up (`animationXSlow`), celebratory reveal (`animationOnboard`).
- [ ] Respect silent mode + Settings toggle "Success sound" (default on).
- [ ] **Consumers:** Stage 12 goal-hit, Stage 16 reward unlock, Stage 18 AI commit, transaction save polish. AI Stage no longer owns this primitive.

**9.7 Activation Funnel Instrumentation**

- [ ] Firebase Analytics events per step: `onboarding_start`, `locale_confirmed`, `ledger_created`, `first_contact`, `first_transaction`, `onboarding_complete` (honour `analyticsEnabled`).
- [ ] North-star metric: **time-to-first-transaction**. Secondary: D1 / D7 retention.
- [ ] Drop-off funnel dashboard documented for ops.

#### Stage 9 Validation Gate

- [ ] Cold start → first saved transaction in **< 90 seconds** on a mid-range Android device (Arabic locale).
- [ ] A Yemeni or Saudi device needs **zero** manual language or currency selection (confirm-only).
- [ ] Teaching moments cannot be dismissed under 5 seconds except via the a11y path or explicit "Don't show again".
- [ ] Entire flow works **fully offline**.
- [ ] Existing users see "What's new", not the full first-run flow.

---

### Stage 10: Smart Import & Merge — ALIGNED TO THE FINANCIAL-GRADE SYNC LAYER (Phase 2)

> [!IMPORTANT]
> **v3.1 re-think (Mandate 5).** Stage 10 (formerly Stage 9) is re-aligned to the hardened Stage 8 layer. Because concurrent editors are **capped at 2** (Owner + 2 Workers), the conflict set is **small, bounded, and fully enumerable** — so Stage 10 presents a **deterministic, exhaustive** review rather than probabilistic auto-merge. Dedup + field-level resolution are made flawless and kept perfectly synchronized with the worker-collaboration limits and the immutable-money invariant.
>
> **v3.4:** Renumbered from Stage 9 → Stage 10 to make room for Onboarding. Subsection IDs below are **10.x**.

**Goal:** Intelligent, audited, reversible deduplication + a human-facing **conflict review UI** on top of the Stage 8 Merge Engine — for backup restore, CSV/Excel import, and the bounded multi-worker / multi-device conflicts the engine flags rather than auto-resolves.

**Prerequisites:** Stage 8 complete (Merge Engine, op-log ordering, worker cap, balance-recompute all provide Stage 10's inputs). Stage 9 (Onboarding) recommended but not blocking.

**Features from Product Plan:**

- Smart Import & Merge
- Excel Import

**Integration / Architecture Notes:**

- **Single source of truth:** deterministic field-level reconciliation + the deterministic tiebreak (Owner > Editor, then `deviceId`) live in the **Stage 8 Merge Engine**. Stage 10 adds (a) **dedup heuristics** for imported/restored/cross-worker data and (b) the **review UI** for engine-flagged ambiguous conflicts. There is exactly one merge pipeline — import, restore, and sync all flow through it.
- **Permission-aware:** import + merge-resolution are **writes** → allowed only for **Owner / Editor**; **Viewers cannot import or resolve** (enforced in use-case layer + RLS, per §8.6).
- **Immutable money invariant:** a transaction (a payment receipt) is never silently auto-deleted; deduplication only ever *flags* money records for human decision, then recomputes balances atomically.

#### Task Checklist

**10.1 Smart Dedup & Deterministic Conflict Review UI**

- [ ] Create `lib/application/import/smart_merge_use_case.dart` — the single orchestrator for dedup over imported/restored data AND engine-flagged conflicts from Stage 8 (including **cross-worker concurrent-create**).
- [ ] Contact deduplication heuristics:
  - Exact phone-number match → auto-merge (safe).
  - Arabic-normalized name similarity ≥ 85% (Levenshtein; diacritics + Alef/Taa-Marbuta normalized) → **flag**, never auto-merge.
  - **Cross-worker concurrent-create:** two workers create the same contact offline → flag → on merge, unify into one canonical contact and **re-point all child transactions**, then recompute balances.
- [ ] Transaction deduplication: same contact + amount + currency + `createdAt` within ±60s → **flag** (never auto-delete a money record).
- [ ] Review UI: duplicates / flagged conflicts shown side-by-side with the **deterministic winner pre-highlighted** (from the Stage 8 tiebreak) and an **Owner override**; choices = **"Merge" / "Keep Both" / "Skip"**; post-resolution balances recompute atomically.
- [ ] **Audited, idempotent, reversible:** every merge writes to `AuditLog`, is idempotent (safe to retry), and offers an **undo window** consistent with the rest of the app.
- [ ] Surface Stage 8 "modification-wins-over-deletion" and concurrent-create flags here for human resolution.
- [ ] Tests: Arabic name variants (with/without diacritics, Alef variants); cross-worker concurrent-create unification with transaction re-pointing + correct balance; ±60s transaction flag; Owner override of the deterministic winner; undo restores prior state.

**10.2 Excel Import (Free for All Tiers)**

- [ ] Add `spreadsheet_decoder` or equivalent package for `.xlsx` parsing.
- [ ] Create `lib/application/import/import_excel_use_case.dart` — routes imported rows through the **same archive-first → dedup → review** merge pipeline as CSV (no parallel path).
- [ ] Excel import screen with column mapping (like CSV) + sheet selector.
- [ ] Handle Arabic text in Excel files (encoding detection).
- [ ] **Worker-safe ingestion:** imports honour write-permissions (Editor/Owner only) and are **chunked/bounded** so a large import cannot overwhelm the sync of a small (≤ 3-seat) workspace or trigger a push/op-log storm.
- [ ] Tests with sample Arabic Excel files (incl. an oversized import → verify chunked, non-blocking sync).

**10.3 Synced-Workspace Backup Restore Safety (v3.4 forensic gap)**

> [!CAUTION]
> Restoring an old `.daftar` backup into a **live synced** workspace can fork the op-log and resurrect tombstoned rows. Restore MUST route through the merge pipeline — never a blind DB replace when sync is enabled.

- [ ] Detect sync-enabled workspace before restore; if enabled, run restore as an **import into the Merge Engine** (dedup + conflict review) rather than wholesale SQLite replace.
- [ ] Surface conflicts (resurrected deletes, duplicate contacts/txns) in the Stage 10 review UI.
- [ ] Tests: restore pre-sync backup into synced workspace → no op-log fork; tombstones not silently undone; balances recompute.

> [!NOTE]
> Excel Import, like CSV Import, is a **100% free feature**. No tier check gates the import *operation*; workspace limits govern activation of imported records, and worker write-permissions govern *who* may import.

#### Stage 10 Validation Gate

- [ ] Every merge path (import, restore, sync) flows through the single `smart_merge_use_case` pipeline.
- [ ] Viewers cannot import or resolve conflicts; Editors/Owner can.
- [ ] No payment receipt is ever auto-deleted; all merges are audited, idempotent, and undoable; balances always recompute correctly.
- [ ] Sync-enabled restore never blind-replaces the DB (routes through merge).

---

> [!NOTE]
> **v3.4:** AI Voice Input & NLP was relocated from this position (former Stage 10) to **Stage 18** (penultimate).
> Financial Strategy §§B–D still govern its economics. Referral AI credits (Stage 16) are **banked** until Stage 18 ships.

---

### Stage 11: Automated WhatsApp Reminders, B2C Shared Accounts & Immutable Receipts (Phase 2, Pro+)

> [!IMPORTANT]
> **v3.3 Mandate 4.** Workspace-deletion / immutable accounting facts (formerly §8.9) are integrated here. A continuity guarantee cannot precede the B2C Shared Accounts foundation it protects.
>
> **v3.4 logic order:** **FCM foundation (§11.0)** → WhatsApp cost-safe reminders → B2C bind loop (+ static B2C→B2B CTA) → customer-local immutable mirror → merchant deletion ceremony + server-side decoupled snapshot.

**Goal:** (a) Stand up **FCM** as the zero-cost push rail; (b) send official, quota-bounded **WhatsApp utility reminders** that can never lose money; (c) replace the abandoned web portal with an **app-download growth loop**; (d) guarantee that **customer receipts survive merchant workspace deletion**.

**Prerequisites:** Stage 8 complete. **Stage 0.3.2 Firebase Preflight** (FCM capable). Local Docker sufficient for bind + mirror; public-internet Install Referrer / Meta webhook cutover items land in **§14.8**.

**Features from Product Plan:**

- FCM Push Infrastructure (v3.4 — was an orphaned dependency)
- Automated WhatsApp Reminders (Pro+, strict quota)
- B2C Shared Accounts (replaces the Customer Portal)
- Immutable Accounting Fact Ledger (customer receipts survive merchant deletion) — *relocated from former §8.9*
- Static B2C→B2B Bridge CTA (forward-compat for Stage 16 attributed links)

> [!CAUTION]
> The Next.js / web customer portal is **abandoned**. A web page is a dead-end; an installed app is a retained, free-to-use customer who feeds the ecosystem, receives free push (not paid WhatsApp), and can later convert to a merchant.

#### Task Checklist

**11.0 FCM Push Infrastructure (Zero-Cost Rail — v3.4 forensic gap)**

> [!IMPORTANT]
> FCM had **no owning stage** despite four consumers (B2C txn push, morning analytics, invite-renewal merchant ping in §8.5.1, ownership-transfer Factor 3). This subsection is the owner.

- [ ] Add `firebase_messaging`; obtain / refresh FCM token; request permissions (after Stage 9.5 priming).
- [ ] Schema + Edge: `device_push_tokens` (identity / workspace_member / shared_account_binding → token, platform, `updated_at`); register on sign-in / claim; prune stale tokens.
- [ ] Edge Function `send-push` (or shared module): verify sync JWT or service role; fan-out by binding/workspace; never expose FCM server keys to the client.
- [ ] Close the §8.5.1 stub: `request-new-invite` merchant ping delivers **real FCM** + in-app inbox row (not DB-insert-only).
- [ ] Foreground / background / terminated handlers; Android notification channels; iOS presentation options.
- [ ] Tests: token register → send → receive on device; stale token pruned; analytics opt-out does not block transactional FCM (opt-out is Analytics-only).

**11.1 Automated WhatsApp Reminders (Official Cloud API, Cost-Safe)**

- [ ] Integrate the **WhatsApp Cloud API directly** (no BSP markup) via an Edge Function that holds the API token server-side.
- [ ] **Meta Business reality (v3.4 gap):** business verification, display-name approval, quality rating, and messaging-tier limits documented and gated in onboarding — do not assume templates go live on day one.
- [ ] Submit Meta-approved **utility templates** framed as **"account statements,"** NOT "debt collection" (avoids spam/harassment rejection — financial-study blind spot).
- [ ] **Multi-currency template disambiguation:** when a contact has balances in multiple currencies, template picks the primary overdue currency or sends one message per non-zero currency (documented choice).
- [ ] Reminder config per contact: frequency (weekly/monthly), day, localized Arabic template with current balance.
- [ ] **Customer consent & STOP:** opt-in before first automated utility; honour STOP / unsubscribe; log consent in audit.
- [ ] **Cost-avoidance routing (the "never lose money" core):**
  - If the customer **has the Daftar app** (Shared Account bound) → send a **FREE FCM push**, not WhatsApp.
  - If a reminder falls inside an open **24h service window** (customer replied) → it is **FREE** utility.
  - Otherwise → a paid utility template at the verified MENA rate (Yemen ~$0.0105, Saudi ~$0.0107, Egypt ~$0.0036; plan at **$0.012**).
- [ ] **Strict quota + circuit breaker:** Pro+ = **30 paid reminders/month** (counter + monthly reset); block + notify at cap; org-wide monthly WhatsApp budget breaker. Free/Pro = 0 automated reminders.
- [ ] Background scheduling (`workmanager` / `android_alarm_manager_plus`; `BGTaskScheduler` on iOS) + **OEM battery-optimization wizard** (Xiaomi, Huawei, Samsung, Oppo) — reliability is ~40–60% without it.
- [ ] Reminder history log (sent, free-vs-paid, delivered, read) for transparency + cost reporting.

**11.2 B2C Deep-Link Customer App Loop**

> [!NOTE]
> Reuses the Stage 8 Deep-Link & Attribution Service. Android deferred-install is deterministic (Play Install Referrer); iOS is best-effort + **manual-code fallback**. Local/LAN bind is the Stage 11 gate; production landing-host Install Referrer QA is collected in **§14.8**.

- [ ] **Generate a share link** (merchant, per contact): Edge Function `create-deep-link` mints an opaque token bound to `{workspaceId, contactId, kind: share}` with TTL → returns a short HTTPS link the merchant sends via WhatsApp/SMS.
- [ ] **Store routing (no app installed):** the HTTPS link routes the customer to the **Play Store / App Store** for their device, carrying the token (Android via Install Referrer; iOS via Universal Link + deferred match).
- [ ] **iOS manual-code fallback:** if deferred match fails, customer enters short code from the merchant's WhatsApp message.
- [ ] **Install interception & secure binding:** on first launch the app reads the token, calls `claim-deep-link`, verifies it (unexpired, unclaimed), and **atomically binds a read-only Shared Account** to the customer's device/account. Binding is SELECT-only via RLS (the customer can never write to the merchant's ledger).
- [ ] **B2C customer identity & device-change re-bind:** if the customer switches phones, a re-claim / transfer of the binding is supported without creating a second slot against the merchant's sharing cap.
- [ ] **B2C data-slice RLS** (completes the §8.1 deferral): contact/transaction SELECT policies scoped to the bound Shared Account slice — viewers never see other contacts in the merchant workspace.
- [ ] **Sharing-cap product wiring:** raise `workspaces.sharing_cap` from entitlements — Free **0** / Pro **30** / Pro+ **500** active shared customers (schema + `enforce_sharing_cap` trigger already in §8.1).
- [ ] **Push notifications (FCM):** when the merchant records a new transaction for that contact, the bound customer device receives a push ("New entry on your account with {store}"). Free; no WhatsApp cost.
- [ ] **In-app notification inbox** (v3.4 gap): persistent inbox for push payloads (txn updates, invite renewals, ownership Factor 3) so offline opens still surface events.
- [ ] **"Shared Accounts" ledger view:** a dedicated tab where the customer sees each merchant relationship, their running balance, and transaction history — **read-only**, Arabic RTL, same Khazna v3 design.
- [ ] **Archived-ledger visibility:** if the merchant archives the parent ledger (§6.7), the bound customer's Shared Account remains **read-only visible** with an "archived by merchant" banner — never a hard blank.
- [ ] **Revocation & expiry:** merchant can revoke a Shared Account (invalidates the binding + stops pushes); links expire per TTL.
- [ ] **Static B2C→B2B Bridge CTA (Stage 16 forward-compat):** on PDF share text, share landing page, and the customer's Shared Accounts tab, show a localized footer: *"أنشئ دفترَك الخاص مجانًا — للمصلحة أو للاستخدام الشخصي"* / "Create your own Daftar free for business or personal use." Stage 16 upgrades this CTA to carry the merchant's **referral token**.
- [ ] **Ecosystem lock-in:** the customer now has Daftar installed for free, can be nudged to start their own ledger (referral-eligible — Stage 16), and can receive future merchant updates as free push.
- [ ] Tests (local/LAN): share → claim → bind → new txn → FCM received → read-only enforced; revoke → push stops; iOS manual code path works. Production Install Referrer path → §14.8.

**11.3 Customer-Local Immutable Mirror (Primary Continuity Guarantee)**

> [!IMPORTANT]
> **Gap closed + retaliation protection (primary):** deleting a workspace must NEVER destroy a customer's receipts. Completes the B2C mirror stub noted in §8.4.

- [ ] On every successful Shared Account claim and subsequent push/fetch, **mirror the customer's slice** into a **read-only, append-only local Drift snapshot**.
- [ ] Include the Shared Account mirror in the customer's own free **Google Drive `drive.appdata` backup**.
- [ ] Mirror updates are append-only for transaction facts; merchant soft-deletes must not purge the customer's local history.
- [ ] Tests: customer opens full read-only history **offline** after merchant revokes the live binding; Drive restore rehydrates the mirror.

**11.4 Workspace Deletion Ceremony & Server-Side Decoupled Snapshot**

- [ ] **Server-side decoupled snapshot** into frozen read-only `archived_shared_ledger` with tombstone copy.
- [ ] **Deletion ceremony:** soft-delete + 30-day grace; owner sees how many customers/receipts preserved; customers notified (FCM + inbox).
- [ ] **Grace-period restore** re-attaches without duplicating the local mirror.
- [ ] **PDPL purge job** after retention.
- [ ] **Contact-level deletion vs receipts (v3.4 gap):** soft-deleting a **contact** must not erase a bound customer's mirror or archived slice — same immutability invariant one level down from workspace deletion.
- [ ] **Immutability invariant:** transaction facts never rewritten — only ownership pointers change.
- [ ] Tests: workspace delete → customer retains history; contact soft-delete → customer mirror intact; grace restore clean.

#### Stage 11 Validation Gate

- [ ] FCM token register → send → receive works on a physical Android device (iOS when APNs configured).
- [ ] A reminder to an app-installed customer is delivered as a free FCM push; a reminder to a non-app customer is a single paid utility template within quota.
- [ ] The 30/month paid-reminder cap and budget breaker are enforced server-side.
- [ ] A customer who claims a share link (local/LAN) lands on the bound Shared Account, read-only; B2C data-slice RLS rejects out-of-slice access.
- [ ] After a merchant deletes a workspace (or soft-deletes a contact), a bound customer retains full read-only receipts.
- [ ] Static B2C→B2B CTA appears on PDF share / landing / Shared Accounts tab.
- [ ] Grace-period restore re-attaches without duplicating or losing customer history.

---

### Stage 12: The Addictive Analytics Dashboard (Phase 2, Pro+)

> [!IMPORTANT]
> **v3.4 Mandate 4.** Metrics must be wildly useful and actionable — an indispensable morning ritual, not vanity charts. Celebratory moments reuse the **Stage 9.6 Delight System** (not the relocated AI stage).

**Goal:** Build an analytics screen the merchant *wants* to open every morning — turning raw ledger data into a daily ritual via fresh numbers, loss-aversion cues, a prioritized chase queue, and a sense of progress.

**Prerequisites:** Stage 8 complete (cross-device aggregation). Stage 9.6 Delight System. Stage 11.0 FCM for morning push. Pro+ entitlement (`advancedAnalytics`), also unlockable via Stage 16 reward ladder.

**Features from Product Plan:**

- Advanced Analytics (Pro+)

> [!NOTE]
> Khazna v3: charts are **monochrome** (axes/grid `inkMuted`); the only chroma is **debt = red**, **payment = green**. **No lapis fills** — lapis appears only as the glow on the single focused CTA. The merchant's money is the brightest object on screen. Fully **offline-first** — all metrics compute locally from Drift (synced devices aggregate when online).

#### The Daily Habit Loop (Nir Eyal "Hooked" model)

| Phase | Implementation |
|---|---|
| **Trigger** | A 7–8 AM localized **FCM** push: "صباح الخير — لديك ٣ مستحقات اليوم بقيمة ٤٬٢٠٠ ريال" ("Good morning — 3 dues today worth 4,200"). |
| **Action** | One tap from Home → dashboard (low friction). |
| **Variable reward** | Fresh-every-visit: Collection Health Score, "collected today" count-up, biggest movers, streak, at-risk debt changes. |
| **Investment** | Merchant sets a weekly collection goal + logs more transactions → richer insights → deeper lock-in. |

#### Metrics & Psychological Hooks

- [ ] **Collection Health Score (hero):** single 0–100 glance metric blending collection rate, aging risk, and streak — the daily "how am I doing?" number.
- [ ] **Today snapshot:** collected today (green count-up), new credit extended today (red), net — animated on open (`animationXSlow`).
- [ ] **Outstanding position:** total receivable vs payable, net, per-currency chips.
- [ ] **Debt aging buckets** (current / 30d / 60d / 90+): `debt_aging_use_case.dart`; 90+ "at-risk" visually emphasized → **loss-aversion**.
- [ ] **At-risk capital:** receivable weighted by aging bucket (90+ counts more) — capital literally at risk.
- [ ] **Days Sales Outstanding (DSO) trend:** average days to collect, week-over-week.
- [ ] **Collection rate trend** (payments ÷ new debt) with WoW delta arrows → progress/competence.
- [ ] **Cash-flow projection** (`cash_flow_use_case.dart`) from payment history.
- [ ] **Payment patterns** (`payment_patterns_use_case.dart`): average days-to-pay, best collection day, repeat cadence per contact.
- [ ] **Per-customer payment reliability score:** on-time vs late vs dormant — powers chase prioritization.
- [ ] **"Who to chase today" queue:** prioritized actionable list (amount × aging × reliability) with **one-tap** WhatsApp / FCM reminder (Stage 11).
- [ ] **Credit concentration risk:** top N debtors as % of total receivable — warn when overexposed.
- [ ] **Dormant-money finder:** contacts with balance but no activity in N days.
- [ ] **Month-over-month seasonality** sparkline for collections vs new credit.
- [ ] **Top debtors leaderboard** + follow-up nudges.
- [ ] **Collection streak / weekly goal gauge** — gamified ring; Delight System chime on goal hit (**§9.6**).
- [ ] **Biggest movers** since last visit → variable reward / novelty.
- [ ] **Empty / low-data states:** new merchants still see value (sample explanations, "add 5 transactions to unlock trends") — never a blank void.

#### Build Tasks

- [ ] Create analytics use cases above (pure Dart, computed locally; aggregate across synced devices).
- [ ] Heavy aggregates run in **`Isolate.run()`** for datasets ≥ 5,000 transactions.
- [ ] Dashboard screen with `fl_chart`: aging bar (red), collection-trend sparkline, cash-flow line, debtor distribution; chart accessibility (semantics labels).
- [ ] Date-range filter across all views; per-currency segmentation.
- [ ] Daily morning summary **FCM** push (respect notification settings; Analytics opt-out does not block this transactional push).
- [ ] **Weekly digest PDF** (shareable, merchant-branded) — feeds the Stage 11/16 B2C→B2B Bridge footer.
- [ ] PDF export with merchant branding (reuses `pdf_generator.dart` + `MerchantProfile?`).
- [ ] Gate behind Pro+ (or referral-unlocked); performance target: dashboard computes < 300ms on 5,000 transactions (isolate path for larger).

#### Stage 12 Validation Gate

- [ ] Morning FCM fires and deep-links to the dashboard.
- [ ] Collection Health Score + chase queue produce actionable, correct ordering on fixture data.
- [ ] All metrics recompute correctly per date range and per currency.
- [ ] Empty state is useful (not blank) for a brand-new ledger.
- [ ] Charts are Khazna v3 compliant (monochrome + red/green only, no lapis fill).

---

### Stage 13: Identity Management — Self-Service Account Ownership Transfer (Phase 2)

> [!IMPORTANT]
> **v3.3 Mandate 2.** Relocated from former §8.8. Placed **immediately before Stage 14 (Production Supabase Deployment)** so ownership re-key is schema-final and battle-tested on local Docker before any cloud migration snapshot is pushed.
>
> **Email-independence:** Factor 3 and cooling-off reversal use trusted-device confirmation (FCM + in-app inbox) via `workspace_devices` (§8.4) and Stage 11.0 FCM. Email variants are enhancements in **§19.4**.

**Goal:** Let a merchant safely transfer workspace ownership from Google Account A → Account B via a multi-factor ceremony, without admin intervention and without email infrastructure.

**Prerequisites:** Stage 8 complete (`migration_challenges`, Auth Bridge, rate limits, `workspace_devices`). Stage 11.0 FCM recommended for Factor 3 delivery. Stage 10 recommended (merge path if B already owns a workspace). Local Docker.

**Features from Product Plan:**

- Self-Service Account Ownership Transfer (multi-factor handshake) — *relocated from former §8.8*

#### Task Checklist

**13.1 Multi-Factor Transfer Ceremony**

- [ ] **Define the multi-factor transfer ceremony** (initiated from the NEW account, Account B, in-session):
  - **Factor 1 — Control of the new identity (B):** the user is already authenticated as B (active session).
  - **Factor 2 — Control of the old identity (A):** interactive re-authentication of Account A (Google Sign-In to A) inside the same flow.
  - **Factor 3 — Trusted-device out-of-band confirmation (no email):** single-use code via **FCM + in-app inbox** to Account A's devices in `workspace_devices`.
- [ ] Edge Function `request-ownership-transfer`: single-use short-TTL migration challenge; rate-limited; anti-enumeration.
- [ ] Edge Function `commit-ownership-transfer`: atomic re-key of `workspace.owner_identity`, members, entitlements; revoke A's sync JWT; audit both fingerprints.
- [ ] **Cooling-off reversal (device-delivered):** reversal token to A's devices for N days. *(Email variant → §19.4.)*
- [ ] **Edge cases:** A inaccessible or no enrolled device → backup-restore path; B already owns a workspace → **merge via Stage 10 Smart Merge** or keep separate.
- [ ] Update `account_management_screen.dart`: guided **"Transfer my data to this account"** ceremony (Arabic-first).
- [ ] Tests: full A→B with all factors; missing Factor 2/3 denied; reversal restores A; replay rejected; zero devices → backup-restore.

#### Stage 13 Validation Gate

- [ ] Account ownership transfers A→B atomically only when all three factors pass; reversal token restores A within the cooling-off window.
- [ ] Factor 3 and reversal work without any SMTP / email provider.
- [ ] Rate-limited transfer endpoints do not enumerate whether identity A exists.

---

### Stage 14: Production Supabase Deployment & Environment Configuration (Phase 2)

> [!IMPORTANT]
> **v3.3 Mandate 3.** This is the **sole production-cloud cutover** for Phase 2. It lands as late as possible, but **strictly before** any stage that inherently requires a live public endpoint (Stage 15 payment webhooks, Stage 16 real store-install attribution, Stages 17–19 performance / AI / enterprise). Stages 8–13 must be schema-final and green on local Docker before this stage begins.
>
> Grounded in the actual stack: **12 Edge Functions** + `_shared/`, **11+ migrations**, `project_id = "daftar"`, no CI deploy workflows yet, no deploy scripts. Current private ops note (`supabase_config_reference.md`, gitignored) documents a Frankfurt Free-Tier **dev** project; production target remains **me-south-1 (Bahrain)** per §8.1 PDPL preference.

**Goal:** Provision staging + production Supabase projects, apply the frozen migration set safely, deploy all Edge Functions with production secrets, wire release client builds, prove observability and cost guardrails, and close inherited public-internet QA items that could not pass on Docker.

**Prerequisites:** Stages 8–13 Validation Gates passed on local Docker. Schema freeze declared (no pending migrations that change ownership / B2C / sync contracts).

#### Task Checklist

**14.1 Freeze & Parity Audit**

- [ ] `supabase db reset` from zero on a clean local stack; migration history is **linear** (no branches / repaired holes).
- [ ] `supabase db diff` against local is **empty** after reset (schema matches migrations).
- [ ] `deno task check` / `lint` / `test` green for all Edge Functions under `supabase/functions/`.
- [ ] Full Flutter test suite green against local LAN Docker.
- [ ] Declare **schema freeze** for the cutover window; any post-freeze schema change requires an explicit Stage 14 re-entry.

**14.2 Provisioning (Staging + Production)**

- [ ] Create **production** Supabase project in **me-south-1 (Bahrain)** — closes the §8.1 Frankfurt deferral for PDPL data residency.
- [ ] Create a separate **staging** project (same region preferred) for dry runs; never dry-run against prod.
- [ ] Size compute/disk for expected Phase 2 load; enable **PITR** on production; configure network restrictions where available.
- [ ] Org-level MFA enforced; **service-role key** custody documented (never in client, never in git, never in CI logs).
- [ ] Confirm Realtime is enabled only via SQL migrations (not ad-hoc Dashboard toggles) — matches local policy.

**14.3 Environment & Secrets Matrix**

> [!CAUTION]
> Disaster vectors live here. Do not skip the JWT algorithm reconciliation or the `BACKUP_AES_KEY` carve-out.

- [ ] Enumerate and set **Edge secrets** (via `supabase secrets set` on staging then prod):
  - `GOOGLE_CLIENT_ID_WEB`, `GOOGLE_CLIENT_ID_ANDROID`, `GOOGLE_CLIENT_ID_IOS`
  - `SUPABASE_JWT_SECRET` / `SUPABASE_INTERNAL_JWT_SECRET` / `JWT_SECRET` (environment-specific)
  - `DEEP_LINK_BASE_URL`, `INVITE_RATE_TIER_DEFAULT`
  - Future AI/WhatsApp keys when those stages go live (`GEMINI_API_KEY` + optional fallback voice provider per §18.3, Meta) — placeholders documented, not committed
- [ ] Enumerate and set **Flutter client `.env` keys** per flavor (debug → LAN Docker; release → prod):
  - `BACKUP_AES_KEY`, `GOOGLE_SERVER_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_ID_ANDROID`, `GOOGLE_OAUTH_CLIENT_ID_IOS`
  - `ACTIVATION_API_BASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `DEEP_LINK_BASE_URL`
- [ ] **Reconcile Google client ID naming split:** client uses `GOOGLE_SERVER_CLIENT_ID` / `GOOGLE_OAUTH_CLIENT_ID_*`; Edge uses `GOOGLE_CLIENT_ID_WEB` / `_ANDROID` / `_IOS` — map one physical OAuth client ID under both names; document the mapping in the (gitignored) ops reference.
- [ ] **JWT algorithm reconciliation (critical):** local `config.toml` uses HS256 `JWT_SECRET`; cloud project may use **ECC P-256** with HS256 legacy verify-only. `verify-google-token` signs HMAC-SHA256 custom sync JWTs — verify signing + verification against **prod** keys before cutover; document the chosen production algorithm and TTL (3600s).
- [ ] **Rotate every secret ever used on a shared/dev machine**, with one carve-out: **`BACKUP_AES_KEY` must NOT rotate** — rotating it would render every existing `.daftar` backup unrestorable.
- [ ] Distinct `SUPABASE_JWT_SECRET` per environment so a **locally-signed sync JWT cannot authenticate against prod** (negative test in the gate).
- [ ] `.env.example` ↔ per-environment parity check; `supabase_config_reference.md` remains **gitignored** and owner-held (never commit live credentials).

**14.4 Migration Cutover**

- [ ] Staging dry run: link staging project → `db push` / ordered migration apply → full E2E sync smoke (two devices, worker invite, deep-link claim).
- [ ] Pre-prod cutover: backup + **PITR confirmed**; freeze writes if any early cloud data exists.
- [ ] Add a **guard script / checklist item** forbidding `supabase db reset` against a linked production project.
- [ ] Apply migrations to production in order; post-apply verification: RLS enabled on every business table, index inventory matches, `audit_logs` partitions provisioned forward.
- [ ] Per-migration rollback policy documented (forward-fix preferred; PITR as last resort).
- [ ] Resolve missing `supabase/seed.sql` referenced by `config.toml` (add empty/seed or remove the reference) so local and cloud tooling agree.

**14.5 Edge Function Deployment**

- [ ] Deploy all **12** functions: `verify-google-token`, `invite-worker`, `revoke-worker-invite`, `push-sync-ops`, `pull-sync-ops`, `create-deep-link`, `claim-deep-link`, `request-new-invite`, `log-deep-link-click`, `resolve-deep-link`, `list-invite-renewal-requests`, `fulfill-invite-renewal-request` (+ `_shared/`).
- [ ] Audit `verify_jwt = false` on every function and **document why** (`verify-google-token` is anonymous by design; the rest verify the custom sync JWT in `_shared/verify_sync_jwt.ts`).
- [ ] Fail-fast secret presence checks at cold start; CORS allowlist with **no wildcard**; rate-limit buckets + global breaker thresholds set for prod volume.
- [ ] Per-function smoke test against staging then prod.
- [ ] Flag / resolve the **missing `/activate` Edge Function** the Flutter client calls via `ACTIVATION_API_BASE_URL` (implement, or retarget the client to the Stage 15 `redeem-promo` path — do not ship a dangling URL).

**14.6 Client Build Wiring**

- [ ] Release flavors point to prod; debug continues to LAN Docker.
- [ ] Add a **prod counterpart** to `tool/verify_lan_env.dart` (current tool asserts a LAN IP — release builds must assert the prod Functions URL instead).
- [ ] Release keystore SHA-1 / SHA-256 registered in Google Cloud Console — closes the Stage 0.3 `[Delayed]` release-client item.
- [ ] Deploy `link-hosting/.well-known/*` with real values replacing `ANDROID_SHA256_FINGERPRINT`, `APPLE_TEAM_ID`, `REPLACE_WITH_SUPABASE_FUNCTIONS_URL`, `REPLACE_WITH_SUPABASE_PUBLISHABLE_KEY`.
- [ ] OAuth consent screen set to **In production** (Testing-mode refresh tokens expire in 7 days — Auth V2 invariant).

**14.7 Observability & Cost Guardrails**

- [ ] Log drains / dashboard for Edge + Postgres; route `ops_alert_events` to a real ops channel.
- [ ] Budget alerts on invocations, egress, disk, compute; LLM and WhatsApp breakers at prod thresholds (even if Stages 10/11 are not yet fully live — thresholds ready).
- [ ] Supabase advisors clean (security + performance).
- [ ] **Execute** a PITR restore drill on staging (not merely "enabled").

**14.8 Inherited Cutover Verifications**

> Items that could not pass a local-Docker Validation Gate because they require a public internet endpoint or real store install.

- [ ] A deep-link survives a fresh Android install via **Play Install Referrer** and routes to the correct intent. *(relocated from Stage 8 gate)*
- [ ] Production landing host + App Links / Universal Links verified on physical devices.
- [ ] B2C share → real store install → bind path (closes Stage 11 public-internet remainder).
- [ ] WhatsApp Cloud API webhook / template delivery against the production Meta app (if Stage 11 templates already submitted).

**14.9 CI Pipeline (v3.4 forensic gap)**

- [ ] Add GitHub Actions (or equivalent) workflow: `flutter analyze`, `flutter test`, `flutter build apk --debug`, `deno task check` / `lint` / `test` for Edge Functions.
- [ ] ARB parity check job: every key in `app_ar.arb` exists in `app_en.arb` and vice versa (fails the build on drift).
- [ ] No secrets in CI logs; use OIDC / encrypted secrets.

#### Stage 14 Validation Gate

- [ ] Staging rebuilt from zero matches production schema + function set.
- [ ] No service-role key, JWT signing secret, or provider API key exists in the client binary.
- [ ] Anon / publishable key reads **zero** workspace business rows (RLS holds).
- [ ] A **locally-signed** sync JWT is **rejected** by production.
- [ ] PITR restore drill and staging rollback rehearsal both completed.
- [ ] Inherited cutover items in §14.8 checked or explicitly waived with owner sign-off.

---

### Stage 15: Monetization & Subscription Architecture (Phase 2)

> [!NOTE]
> Formerly Stage 13. Renumbered under v3.3. **Requires Stage 14** — payment-gateway webhooks must POST to a public HTTPS URL even in sandbox.

**Goal:** Two revenue rails: (1) a **secure, single-use promo-code** system granting a 1-year premium license with bulletproof atomicity (codes can never be reused), and (2) automated **payment-gateway** subscriptions. Both ultimately issue the same server-signed entitlement token the app already consumes (Stage 5).

**Prerequisites:** Stage 8 (`promo_codes` / `promo_redemptions` schema). **Stage 14** (production/staging Edge Functions + public HTTPS). Builds on Stage 5 activation/entitlement.

**Features from Product Plan:**

- Payment (Manual Activation → atomic promo codes)
- Payment (Automated gateways / MoR — international)

#### Task Checklist

**15.1 Secure Single-Use Promo Codes (Supabase, Atomic)**

> [!IMPORTANT]
> A code must grant a **1-year premium license exactly once**. Reuse is impossible by construction — enforced at the database level, not in app logic.

- [ ] Schema: `promo_codes` (`id`, `code_hash`, `tier`, `duration = 12 months`, `status` ∈ `unused`/`redeemed`/`void`, `batch_id`, `created_at`) + `promo_redemptions` (`code_id` **UNIQUE**, `workspace_id`, `redeemed_at`) — the UNIQUE constraint alone makes double-redemption impossible.
- [ ] **Atomic redemption RPC** (Postgres `SECURITY DEFINER` function): perform a single compare-and-set — `UPDATE promo_codes SET status='redeemed' WHERE id=$1 AND status='unused' RETURNING ...` inside a transaction with row lock; insert the `promo_redemptions` row; on zero rows updated → return "already used/invalid." This is the **professional, cost-effective Supabase pattern** (no extra infra; the DB is the source of truth).
- [ ] **Edge Function `redeem-promo`** wraps the RPC: verifies the sync JWT, rate-limits attempts (brute-force/enumeration defense), passes only the hashed code, and on success **issues/extends the signed 1-year entitlement** (same token format as Stage 5, stored in `flutter_secure_storage`).
- [ ] Store **only code hashes** server-side; codes are high-entropy (XXXX-XXXX-XXXX); constant-time comparison; no validity leak via timing/error differences.
- [ ] Admin batch generator (creates N codes for a tier/campaign; export for the hawala/reseller distribution rail — see Yemen sanctions note in 15.2).
- [ ] Offline reconciliation: the existing offline format-check (Stage 5) gives instant UX, but **single-use atomicity requires the online RPC**; if redeemed offline-first, reconcile + revoke on reconnect if the server rejects.
- [ ] Tests: concurrent redemption of one code from two devices → exactly one succeeds; reused code → rejected; tampered entitlement → rejected.

**15.2 Automated Payment Gateways**

- [ ] **Merchant-of-Record** (Paddle or Lemon Squeezy) for international self-serve — handles global tax/VAT and chargebacks.
- [ ] In-app "Upgrade" → checkout (in-app WebView or external browser) → provider **webhook → Edge Function** (verify signature) → grant/extend entitlement server-side → app refreshes license.
- [ ] Subscription management: upgrade Pro ↔ Pro+, downgrade, cancel, renewal, grace period on failed payment.
- [ ] Pricing: Pro **$24.99/yr**, Pro+ **$49.99/yr**.
- [ ] Optional **RevenueCat** for native IAP where store policy requires it (accept the platform fee); keep MoR as the primary low-fee rail.
- [ ] **Yemen sanctions blind spot (financial study):** Paddle/Lemon Squeezy may refuse Yemeni transactions. The **promo-code rail (15.1)** is the sanctioned-market fallback; requires a legal entity in a non-sanctioned MENA country + a fintech-lawyer review of code distribution. Document explicitly.
- [ ] Entitlement is **always server-issued and signed** — never client-asserted. Sandbox-test all flows.

**15.3 Phase 2 Downgrade Semantics & Data Rights (v3.4 forensic gap)**

> [!IMPORTANT]
> **Never hold data hostage.** When Pro+ lapses, collaboration and sync degrade gracefully; data remains accessible.

- [ ] On Pro+ expiry: multi-device sync pauses (local CRUD continues); worker seats become read-only Viewers; Shared Accounts over Free/Pro cap become view-only until under cap (no hard delete of customer bindings).
- [ ] WhatsApp automation and AI voice (when Stage 18 live) disable with clear upgrade CTA; banked AI credits preserved.
- [ ] Merchant **self-service data export** (full `.daftar` + CSV) and **right-to-erasure** request flow (PDPL) — server soft-delete + grace, then purge per policy.
- [ ] Tests: downgrade mid-collaboration → workers retain read-only local access until wipe ceremony; export succeeds offline.

#### Stage 15 Validation Gate

- [ ] A promo code grants exactly one 1-year license and is provably unreusable under concurrency.
- [ ] A gateway purchase grants entitlement only via a signature-verified webhook.
- [ ] Cancel/downgrade/grace transitions are correct and reflected in the app on next refresh.

---

### Stage 16: The Viral Referral Engine & B2C→B2B Bridge (Phase 2)

> [!IMPORTANT]
> **v3.4 Mandate 3.** Zero-cost (or near-zero) viral incentives only. The **1-month Pro+ trial is cancelled** — it cannibalizes ARPU and has real marginal cost. Every reward below is either pure local entitlement or ~$0.0005/customer/yr Shared Account economics.
>
> **Requires Stage 14** for production deep-link hosting and real third-party store-install verification. AI credits are **banked** until **Stage 18**.

**Goal:** Turn every user into an acquisition channel via trackable deep-links **and** turn every merchant PDF/share into an attributed growth loop (B2C→B2B Bridge). Rewards grant only on **verified download + registration**.

**Prerequisites:** Stage 8 (Deep-Link, `referrals` table). Stage 11 (static Bridge CTA). Stage 12 (analytics unlock). **Stage 14** (production link host). Stage 9.6 Delight System.

**Features from Product Plan:**

- Viral Referral Engine (all tiers can earn)
- B2C→B2B Bridge (v3.4 growth hack)

#### Task Checklist

**16.1 Trackable Referral Links & Verified Attribution**

- [ ] Per-user referral link via `create-deep-link` (`kind: referral`, bound to `referrerId`).
- [ ] **Verification chain (server-authoritative):** click logged → app installed (Android: Play Install Referrer; iOS: deferred/best-effort + manual code) → new user **registers** (Google Sign-In) → Edge Function `claim-referral` marks `install_verified` + `register_verified`.
- [ ] **Anti-fraud:** one reward per unique new device + account; block self-referral; velocity limits + daily reward caps; optional Play Integrity / DeviceCheck; rewards idempotent.
- [ ] **Fraud revocation:** if a referral is later proven fraudulent, revoke time-boxed perks and claw back unused banked AI credits; permanent cosmetic badges may remain; audit every revocation.

**16.2 Zero-Cost Hybrid Reward Ladder (v3.4)**

> [!CAUTION]
> ~~5 verified invites → 1 month Pro+ trial~~ — **CANCELLED.** Rationale: real marginal cost (sync / WA / AI) + Pro ARPU cannibalization. Do not reintroduce without CTO sign-off.

**Per verified invite (permanent, ~$0):**

- [ ] Grant **3 banked AI Voice inputs** to `ai_usage_counters` / `aiVoiceTrial` — **redeemable only when Stage 18 ships**; UI shows "Banked — unlocks with Voice Input"; **no expiry before Stage 18 launch**.
- [ ] Permanent Free-tier capacity raise: **+10 contacts** and **+50 transactions** (stackable with a hard aggregate cap, e.g. never exceed Pro soft ceiling without paying).
- [ ] At **3 verified invites:** permanently unlock **`brandedPdf`** for Free (local PDF render — $0 infra; also feeds the Bridge).

**Milestone ladder (hybrid — time-boxed then permanent):**

- [ ] **5 verified:** 90-day unlock of `advancedAnalytics` + `ledgerArchiving`; converts to **permanent** at **25 verified**.
- [ ] **10 verified:** 90-day Free **Shared Account host slots** (e.g. 5 slots; ~$0.0005/customer/yr); permanent at **50 verified** (cap still anti-abuse bound).
- [ ] **100 verified:** permanent `advancedAnalytics` (if not already) + **Founding Merchant** badge + optional Khazna-compliant accent avatar frame (cosmetic, $0).

**Never-grant list (protect paid moat + real cost):**

- [ ] Do **not** grant via referral: `multiDeviceSync`, `whatsappAutomation`, `workspaceCollaboration`, uncapped AI, or any Pro+ trial.

- [ ] Idempotent grants via `rewards` table; every grant audited; aggregate caps enforced server-side.

**Cost note (adapts Financial Strategy §F):** all ladder rewards above are local entitlements or Shared Account slices already priced at ≪ $0.01/user/yr. Banked AI credits cost $0 until Stage 18; at Stage 18 they consume the existing trial/metered counters under the 600/mo hard cap.

**16.3 "Invite & Earn" UI**

- [ ] Invite screen: WhatsApp-first share sheet, copy link, progress bar to next reward, total verified count, **banked AI credit balance**.
- [ ] Per-invite status (clicked / installed / registered / rewarded).
- [ ] Celebratory moment on reward unlock — **Stage 9.6 Delight System**.

**16.4 B2C→B2B Bridge (Growth Hack)**

> [!IMPORTANT]
> Every PDF statement, WhatsApp share, B2C landing page, and Shared Accounts tab already ships a **static** CTA in Stage 11. This subsection **attributes** that CTA to the sharing merchant's referral token — merchants become unknowing marketers and earn rewards when customers convert.

**Tiered removable policy (CTO-approved):**

| Tier | Bridge appearance | Removable? |
|---|---|---|
| **Free** | Full footer + QR + localized CTA | No |
| **Pro** | Compact one-line CTA | No |
| **Pro+** | Compact CTA **on by default** | **Yes** — "Remove Daftar branding" becomes a Pro+ perk |

- [ ] Upgrade Stage 11 static CTA to carry `deep_link_tokens` with `kind: referral` bound to the sharing merchant.
- [ ] Surfaces: PDF footer, WhatsApp share text, B2C share landing, customer Shared Accounts tab.
- [ ] Pro+ Settings toggle: "Show Daftar invite on my statements" (default ON).
- [ ] Analytics events: `bridge_impression`, `bridge_tap`, `bridge_install`, `bridge_register` (honour analytics opt-out for Analytics only).
- [ ] Tests: Free PDF always shows full footer; Pro+ can hide; attributed claim credits the sharing merchant; self-referral blocked.

#### Stage 16 Validation Gate

- [ ] A reward is granted only after a genuinely new user installs AND registers (click-only and self-referral rejected).
- [ ] Pro+ trial is **not** grantable by any code path.
- [ ] Banked AI credits appear in UI and do not expire before Stage 18.
- [ ] Bridge attribution: merchant A shares PDF → customer installs via footer → A receives verified referral credit.
- [ ] Time-boxed perks expire correctly; permanent conversion at milestones works; fraud revocation claws back unused credits.

---

### Stage 17: Extreme Performance Optimization (Phase 2)

> [!IMPORTANT]
> **v3.4 Mandate 6.** Dedicated stage for absolute operational perfection. Formally **absorbs and closes** Stage 7.2 `[Delayed]` items (cold start < 2s, APK < 30MB/ABI, memory < 150MB). Reference: [`docs/architecture/PERFORMANCE_TELEMETRY_RUNBOOK.md`](architecture/PERFORMANCE_TELEMETRY_RUNBOOK.md).

**Goal:** Guarantee 60fps scrolling, sub-100ms local interactions, bounded sync, leak-free isolates, and CI budgets that fail the build on regression — before AI Voice (Stage 18) ships. (v3.6: Stage 18 adds **no on-device inference** — only capture + network; §18.7 re-validates these budgets.)

**Prerequisites:** Stages 8–16 feature-complete enough to profile real flows. Stage 14 staging project available for sync load tests.

#### Task Checklist

**17.1 Rendering & Jank Budgets**

- [ ] Profile list scroll (contacts, transactions, Shared Accounts) on Samsung A03-class hardware — **60fps** sustained; eliminate sync build_methods and oversized rebuild scopes.
- [ ] Prefer `ListView.builder` / slivers everywhere; ban `ListView(children:)` for unbounded lists (architecture rule).
- [ ] Impeller / Skia shader warm-up for first-frame jank on critical routes.

**17.2 Drift / SQLite Query Plans & Indexing**

- [ ] `EXPLAIN QUERY PLAN` audit for every hot path (FTS search, balance watch, sync pull apply, analytics aggregates).
- [ ] Confirm every WHERE / ORDER BY / JOIN column has an explicit Drift index (architecture invariant).
- [ ] PRAGMA tuning documented (`journal_mode=WAL`, synchronous, cache_size) for mid-range Android.

**17.3 Isolate Management**

- [ ] Inventory: PDF, CSV/Excel import, backup encrypt/decrypt, analytics aggregates, (future) AI voice capture/encode (§18.2 — no on-device inference) — all heavy work in `Isolate.run()` or dedicated workers.
- [ ] No large ByteData / image copies across isolate boundaries without transferables; measure peak RSS.

**17.4 Memory & Leak Audits**

- [ ] DevTools memory timeline on: sync storm, 1k-txn scroll, PDF of 500 txns, FCM flood — **< 150MB** steady state.
- [ ] Dispose StreamSubscriptions / Realtime channels / AnimationControllers; leak tests for SyncEngine and providers.

**17.5 Startup & Binary Size**

- [ ] Cold start **< 2 seconds** on Samsung A03 (closes Stage 7.2 Delayed).
- [ ] `--split-per-abi` APK **< 30MB** per ABI (closes Stage 7.2 Delayed); tree-shake icons/fonts; defer heavy native libs.

**17.6 Sync & Network Efficiency**

- [ ] Op-log batching / compression on push; snapshot checkpoint from §8.4 gap used for new-device bootstrap.
- [ ] Realtime wake-ups coalesce; no per-row channel storms.

**17.7 Battery & Background**

- [ ] WorkManager / BGTask cadence review; OEM battery wizard completeness (Stage 11).
- [ ] FCM high-priority only for user-visible events; data messages for silent sync wake.

**17.8 Performance CI Regression Guard**

- [ ] Budget file (e.g. `tool/perf_budgets.yaml`): cold start, frame build times, APK size, selected Drift query ms.
- [ ] CI job fails on budget breach; document how to update budgets intentionally.

#### Stage 17 Validation Gate

- [ ] Stage 7.2 Delayed items (cold start, APK size, memory) are **checked complete**.
- [ ] 60fps on 1000+ transaction scroll on mid-range Android.
- [ ] Performance CI budgets green on main.
- [ ] New-device sync of a large fixture workspace completes within an agreed SLA via snapshot — not full op-log replay.

---

### Stage 18: AI Voice Input & NLP — UNFROZEN (Phase 2, Pro+) — Penultimate

> [!TIP]
> **UNFROZEN (v3.0) · Relocated (v3.4 Mandate 2) · REBUILT (v3.6, 2026-08-06).** Formerly Stage 10. The v3.0 five-step on-device-first cascade was **retired** after a full model-market re-study: its on-device anchor (Gemma 4 E4B — 2.5 GB download, ~5 GB RAM) cannot run on the Samsung A03-class target hardware and contradicts Stage 17's own budgets (< 150 MB RAM, < 30 MB APK). The rebuilt architecture is **one metered cloud call, one confirm** — cheaper at its worst case than the cascade's claimed "realistic" case, with 4 failure surfaces instead of 8 and a single quota semantic. Evidence, market scan, and decision record: [`docs/archive/ai_voice_feature_study.md`](ai_voice_feature_study.md). Economics: **Financial Strategy §§B–D** (re-verified 2026-08-06).
>
> Referral AI credits granted in Stage 16 are **already banked** in `ai_usage_counters` — this stage redeems them (FIFO, idempotent).

**Goal:** Let a merchant dictate a transaction in natural spoken Arabic and have it parsed into a structured ledger entry with a **near-zero committed-error rate** — one hardened Edge call, deterministic cross-validation, an editable Confirm Card as the only path to the ledger, concluding with the Stage 9.6 Delight System. Accuracy is **measured and gated** (§18.1), never assumed.

**Prerequisites:** Stage 8 (`ai_usage_counters`, Edge proxy pattern). **Stage 14** (prod Edge secrets). **Stage 17** (perf budgets green). Pro+ `aiVoiceInput`; Free/Pro `aiVoiceTrial` + banked referral credits.

**Features from Product Plan:**

- AI Voice Input (Pro+, **600/month**; Free 15 lifetime / Pro 60 per month trial + banked referral credits)

#### Arabic NLP — The Core Semantic Contract

The parser MUST distinguish debt vs. payment from the Arabic preposition, parse Arabic-Indic digits **٠١٢٣٤٥٦٧٨٩** AND spelled-out numbers (خمس مئة = 500), extract optional currency and one or more items, and resolve the contact.

| Spoken phrase | Type | Contact | Amount | Currency | Item(s) / note |
|---|---|---|---|---|---|
| **محمد عليه ٥٠٠ سكر** ("Mohammed owes 500 for sugar") | **DEBT (عليه)** | محمد | 500 | default (YER) | سكر |
| **محمد له ٥٠٠ ريال حوال** ("Mohammed paid 500, transfer") | **PAYMENT (له)** | محمد | 500 | ريال (YER) | حوال (transfer / hawala note) |
| **محمد الزبيري عليه ٥٣٠ وريال سكر وزيت** | **DEBT (عليه)** | محمد الزبيري | 530 | ريال (YER) | [سكر, زيت] |
| **محمد احمد الزبيري عليه خمس مئه ريال سكر و حليب شاهي** | **DEBT (عليه)** | محمد احمد الزبيري | 500 (spelled) | ريال (YER) | [سكر, حليب, شاهي] |

> **Semantic rule:** `عليه` ⇒ **DEBT**. `له` ⇒ **PAYMENT**. This mapping is the single most important correctness invariant of the feature — it is **triple-enforced**: schema `enum` on the model output, a deterministic keyword guard (§18.4), and a 100%-polarity golden-set gate (§18.1).

#### Architecture — One Call, One Confirm (v3.6)

```
Capture (mic + waveform, 16 kHz mono Opus, 0.5–30 s, ~25 KB per 8 s)
   │ offline ──▶ Voice Outbox: encrypted local queue → auto-parse on
   ▼ online                    reconnect → notification → Confirm Card
Edge Function `ai-voice-parse`        ── the ONLY AI endpoint; 1 call = 1 quota unit
   ├─ verify sync JWT · resolve tier · quota + banked-credit FIFO
   │  (atomic, server-authoritative, idempotent by command UUID)
   ├─ Gemini 3.1 Flash-Lite REST: inline audio + fixed system prompt →
   │  {transcript + JSON} · responseSchema · temperature 0 · thinking 0
   │  (provider adapter — swappable server-side to Soniox+Flash-Lite text)
   └─ telemetry row (audio s, tokens, cost µ$, outcome) — audio NEVER persisted
   ▼
Deterministic post-validation                    ── §18.4, all local / deterministic
   ├─ schema clamp: type ∈ {debt, payment} · int amount > 0 · currency ∈ ledger set
   ├─ Arabic number cross-parser re-derives amount from transcript (٠–٩ / 0–9 /
   │  spelled-out) — mismatch ⇒ field flagged, never silently accepted
   ├─ polarity keyword guard: عليه/له must corroborate entry_type
   └─ contact resolution 100% LOCAL: normalized fuzzy match → duplicate chooser /
      create-contact flow / archived-ledger exclusion (§6.7)
   ▼
Editable Confirm Card (flagged fields pre-highlighted; money NEVER auto-committed)
   ▼ Commit → Delight System (§9.6)
```

- **One quota semantic:** every command consumes exactly **1 unit** of `ai_usage_counters` (redemption order: trial → banked referral credits → Pro+ monthly, FIFO). No hidden costs, no "sometimes free" ambiguity, no free-path abuse surface.
- **Offline-first posture (honest):** capture always works offline via the **Voice Outbox**; parsing requires connectivity by design. Manual Quick-Add remains the always-offline bulk path — voice is the Pro+ convenience layer (§D UX framing).
- **Integer-money invariant:** the model returns the **major-unit integer as spoken**; the client converts via the ledger currency's `decimalPlaces` before constructing `Money`. Spoken fractions (نص ريال) ⇒ amount flagged — never rounded silently.
- **Contingency (pre-wired, not built):** if the §18.1 gate fails on dialect quality, the adapter flips server-side to **Soniox async ($0.10/hr) + Flash-Lite text parse** — no app update. OpenAI `gpt-4o-mini-transcribe` documented as third option.

#### Task Checklist

**18.1 Golden Set & Accuracy Harness — BUILD FIRST (the gate everything else must pass)**

- [ ] Golden set: ≥ **150 recorded Arabic clips** (Yemeni-weighted + Saudi variants) with expected JSON — the 4 canonical phrases plus systematic variants: Arabic-Indic digits, spelled-out and compound numbers (خمس مئة / خمسمية / ألف وميتين وخمسين), multi-item lists, currency words, filler/hesitation, market background noise, and prompt-injection phrases. Scripted voices only (PII-free), versioned in-repo.
- [ ] `tool/voice_eval/` harness: replays clips against the staging `ai-voice-parse`, reports **per-field accuracy** (type / amount / contact / currency / items) + latency percentiles; runs in CI on demand and on any prompt/schema/model/provider change.
- [ ] **GA thresholds (hard gate):** polarity **100%** · amount exact ≥ **98%** · contact top-1 ≥ **95%** · commit-ready-with-zero-edits ≥ **90%** · flagged-or-correct (no silent wrong field) ≥ **99.5%**.
- [ ] Threshold miss ⇒ iterate prompt/schema; persistent miss ⇒ flip adapter to the two-call contingency and re-run the same gate.

**18.2 Capture & Voice Outbox**

- [ ] Microphone permission flow (Arabic-first privacy promise: "your clip is parsed, never stored").
- [ ] Recorder: 16 kHz mono Opus/AAC, hard stop at 30 s, minimum 0.5 s, ~25 KB per 8 s clip (2G/3G-friendly); waveform + recording timer; cancel / re-record. (No live partial transcript — deliberate: no streaming STT exists in the single-call design; the Confirm Card is the review surface.)
- [ ] **Voice Outbox (offline):** clips queue locally encrypted; auto-parse on connectivity (WorkManager, §4.5 headless pattern); local notification → Confirm Card; TTL 7 days (then playback + manual entry); queue cap ~20 clips.
- [ ] Record → stop → upload entirely off the main thread; zero dropped frames while the waveform animates (Stage 17 discipline).

**18.3 The `ai-voice-parse` Edge Function (single hardened AI endpoint)**

- [ ] Verify sync JWT → resolve tier → enforce quota + **banked-credit FIFO redemption atomically** (server-authoritative `ai_usage_counters`); idempotent by client-generated command UUID — retries never double-charge.
- [ ] Provider adapter interface `parse(audio, schema) → {transcript, entry, usage}`; primary **Gemini 3.1 Flash-Lite** via REST: inline base64 audio, strict `responseSchema`, temperature 0, thinking budget 0, **paid tier only**.
- [ ] Fixed Arabic-first system prompt (**budget ≤ 800 tokens** — the §D cost ceiling depends on it; cache-friendly); transcript treated as data, never instructions; **no user data beyond the clip** — no contact list, no ledger context.
- [ ] Reject before spend: > 30 s / < 0.5 s / > 1 MB payloads, over-quota, over daily/audio-minute sub-caps, breaker tripped.
- [ ] Timeout 15 s + single retry; error taxonomy (`over-quota` / `provider-down` / `unparseable`) mapped to `Failure` types with localized ARB messages.
- [ ] Telemetry per call: audio seconds, token counts, cost estimate (µ$), outcome, latency — **no transcript or audio stored**; feeds the ops dashboard + org breaker. Batch-tier (−50%) drain documented as an optional optimization for Outbox parses.

**18.4 Deterministic Post-Validation & Entity Resolution**

- [ ] `arabic_number_parser.dart` (core utils, pure Dart): Arabic-Indic ٠–٩ + Western digits + spelled-out numbers and compounds → `int`; ≥ 100-case unit table.
- [ ] Amount cross-check: re-derive the amount from the returned transcript; disagreement or absence ⇒ **amount field flagged** on the Confirm Card — never silently accepted.
- [ ] Polarity guard: عليه/له (and variants عليها/لها/عليهم…) must corroborate `entry_type`; conflict ⇒ type field flagged.
- [ ] Output clamp before any ledger touch: `int` amount > 0 and ≤ configured max; currency ∈ ledger's enabled set else flagged; items sanitized; unknown fields impossible by schema.
- [ ] Contact resolution **100% local**: Arabic-normalized fuzzy match (existing Alef/Taa/diacritics utils); duplicates across ledgers ⇒ chooser; missing ⇒ "Create contact?" + ledger picker; user-archived ledger contacts excluded (Stage 6.7 invariant — never auto-create under an archived ledger).

**18.5 Voice FAB, Confirm Card & Delight**

- [ ] Voice FAB: monochrome + lapis glow edge only (Lapis Law); `glowBreath` while listening; over-cap/offline states show the reason, not a dead button.
- [ ] Editable Confirm Card: every field editable; flagged fields pre-highlighted (semantic warning tint); money never auto-committed; **field-edit events logged to telemetry — the production accuracy metric**.
- [ ] Quota meter (X/600 + banked credits) in the voice sheet + Settings; trial-exhaustion upsell for Free/Pro.
- [ ] Success uses **Stage 9.6 Delight System** (chime + haptic + count-up).

**18.6 Quota, Cost Control, Security & Privacy**

- [ ] Enforce 600/month (Pro+) / 15 lifetime (Free) / 60/month (Pro) + **banked referral credits (FIFO, idempotent, no expiry pre-launch)**; server-authoritative with local mirror for instant UI.
- [ ] Anti-abuse sub-caps per §G: ≤ 40 commands/day, ≤ **90 audio-min/month**, ≤ 30 s/clip; rate limits by user + device + IP (§8.7 buckets).
- [ ] Org-wide monthly AI budget breaker (default **$250/mo** ≈ 3× realistic fleet cost): auto-pause voice with localized status banner + `ops_alert_events`; manual entry unaffected.
- [ ] **Prod secrets (post–Stage 14):** `supabase secrets set GEMINI_API_KEY` (+ optional fallback-provider key placeholder) per §14.3 — never in the client; paid-tier account verified (free tier trains on data — **banned**).
- [ ] Hardened endpoint per §H: client never names model/endpoint/key; **APK string scan proves no model/provider identifiers in the binary**; prompt-injection phrases live in the §18.1 golden set.
- [ ] Privacy: no server-side audio/transcript persistence; telemetry is counters only; PDPL posture documented; Vertex regional endpoint (+10% list) recorded as the data-residency lever — verify region/model availability if a mandate lands.
- [ ] Degradation matrix tested: offline → Outbox · over-cap → upsell + manual · provider down → retry-later + manual · breaker → pause banner + manual.

**18.7 Performance & Latency Validation**

- [ ] Latency budget: capture-stop → Confirm Card **p50 ≤ 3 s / p95 ≤ 7 s** on a 3G network profile, A03-class device; measured by the §18.1 harness + field telemetry.
- [ ] Stage 17 budgets re-run: APK Δ ≤ **+0.5 MB** (recorder only — **no bundled models**), memory < 150 MB steady, cold start unaffected, zero jank during waveform.
- [ ] ADR records "no model download/update subsystem" as a deliberate non-goal, with the §C on-device revisit criteria.

#### Stage 18 Validation Gate

- [ ] **§18.1 golden set passes all GA thresholds** — including 100% عليه/له polarity and the four canonical phrases — against the production provider configuration.
- [ ] Duplicate-name, missing-name, and archived-exclusion flows verified; every injected cross-check mismatch produces a flagged field on the Confirm Card (no silent acceptance path exists).
- [ ] Voice Outbox end-to-end: offline capture → reconnect → parse → confirm → commit; TTL and queue-cap behavior verified.
- [ ] Quota integrity: 1 command = 1 unit; retries idempotent (same UUID never double-charges); banked Stage 16 credits redeem FIFO; over-cap / breaker / provider-down degradation paths all exercised.
- [ ] Security: APK string scan clean; Edge Function rejects unauthenticated, over-quota, and oversized requests; prompt-injection red-team clips parsed as data (golden set).
- [ ] Cost telemetry live: per-call µ$ rows aggregate to the ops dashboard; breaker fires in a staging drill.
- [ ] Stage 17 budgets still green; §18.7 latency budget met on mid-range hardware.

---

### Stage 19: Enterprise Handoff — Documentation, Testing, Security Hardening & Email Infrastructure (Phase 2)

> [!NOTE]
> Formerly Stage 17 (v3.3) / Stage 15 (v3.0). Renumbered under **v3.4**. Absorbs transactional-email work as **§19.4**. Final Phase 2 gate.

**Goal:** Make Daftar transferable to a full-scale engineering team with zero tribal knowledge; guarantee absolute stability via multi-layered test + security; wire production transactional email. This is the final Phase 2 gate.

**Prerequisites:** Stages 8–18 feature-complete (including Stage 14 cutover, Stage 17 perf, Stage 18 AI).

#### 19.1 Enterprise Documentation Suite

- [ ] **System Architecture** — C4 diagrams, clean-architecture map, offline-first + sync data-flow.
- [ ] **API Contracts** — OpenAPI for every Edge Function; WhatsApp + AI voice provider contracts (Gemini primary, documented fallbacks per §18.3).
- [ ] **Database Schemas** — Drift + PostgreSQL ERDs, migration history, RLS catalogue.
- [ ] **Sync & Merge Protocol Spec** — op-log, LWW, safety rules, idempotency, snapshot bootstrap.
- [ ] **Deep-Link & Attribution Spec** — domain config, token lifecycle, Bridge attribution.
- [ ] **User Flows** — onboarding, voice, worker invite, B2C bind, reminders, ownership transfer, referral, Bridge, promo/payment.
- [ ] **Security & Threat Model** — STRIDE, prompt-injection, key management, RLS.
- [ ] **Compliance** — PDPL residency + consent; Yemen sanctions posture.
- [ ] **Cost & Quota Model** — verified 2026 economics + v3.4 zero-cost reward ladder.
- [ ] **Environment & Cutover Runbook** — Stage 14 secrets matrix, JWT notes, PITR drill.
- [ ] **ADRs**, **Runbooks**, **Design System handoff** (Khazna v3), **Dev Onboarding** (clone → build < 5 min; local Docker first).

#### 19.2 Multi-Layered Testing Strategy

- [ ] **Unit** — domain + application ≥ 80%.
- [ ] **Widget** — balance card, voice confirm, dashboard, lock screen, onboarding tips.
- [ ] **Integration** — CRUD, backup/restore-via-merge, sync + Merge Engine, AI (mocked), payments, promo atomicity, ownership transfer, Bridge attribution.
- [ ] **End-to-End** — multi-device merge, B2C install→bind, referral verify, voice entry, upgrade/payment, workspace deletion → receipts retained, onboarding < 90s.
- [ ] **Contract tests** — Edge Functions vs OpenAPI.
- [ ] **Performance / Load** — Stage 17 budgets + sync at scale + AI voice latency/quota budgets (§18.7).
- [ ] **Security testing** — pen test, RLS matrix, prompt-injection red-team, secret scanning, Play Integrity.
- [ ] **Localization / RTL** visual regression; **Accessibility**.
- [ ] **Chaos / offline resilience**.
- [ ] **Beta / UAT** — real MENA merchants; crash-free ≥ 99.5%.

#### 19.3 Security Hardening & Compliance Gate

- [ ] All AI/backend endpoints authenticated, rate-limited, server-side model selection, keys server-only.
- [ ] RLS verified; viewers read-only; removed workers lose access + local wipe (§8.6).
- [ ] Prompt-injection red-team passed.
- [ ] PDPL consent shipped; data in me-south-1; provider training retention disabled.
- [ ] Incident-response + secrets rotation (honour `BACKUP_AES_KEY` non-rotation).

#### 19.4 Transactional Email Infrastructure & Deliverability Hardening

> [!IMPORTANT]
> Relocated from former §8.7 `[Delayed]` / former §17.4. Stage 8 ships rate limits + `invite_send_queue` with **no SMTP**. This activates the email rail for production.

- [ ] Select transactional email provider — keys only in Edge secrets.
- [ ] **SPF / DKIM / DMARC** + bounce/complaint feedback loop + merchant auto-suspend on thresholds.
- [ ] **CAPTCHA / Play Integrity / DeviceCheck** step-up on suspicious velocity.
- [ ] Activate SMTP drain for `invite_send_queue`.
- [ ] **Stage 13 email enhancements (optional):** Factor 3 + reversal via email **in addition to** device path — never replace it.
- [ ] Tests: bounce suspend; CAPTCHA step-up; queue drains; ownership Factor 3 survives email outage.

#### 19.5 Localization Parity Gate (v3.4 forensic gap)

- [ ] CI ARB parity (from §14.9) covers all Phase 2 keys (onboarding, Bridge, analytics, AI, ownership).
- [ ] Manual RTL audit of every new Phase 2 screen.

#### Stage 19 Validation Gate

- [ ] A new engineer can build, understand the architecture, and ship a change using only the docs.
- [ ] All test layers green in CI; security + compliance checklist signed off.
- [ ] Transactional email deliverability checklist signed off — or explicitly waived if email rail remains unused.
- [ ] ARB parity gate green.

---

## Appendix: Cross-Cutting Concerns Tracked Across All Stages

| Concern | Enforcement Point | Notes |
| --- | --- | --- |
| **Free-tier limits** | Application layer (use cases) | 1 Ledger, 50 Contacts, 500 Transactions (raisable via Stage 16 rewards) |
| **Soft deletes** | Data layer (all repositories) | `isDeleted = true`, never hard delete in normal flow |
| **Audit logging** | Data layer (all write repositories) | Every CREATE/UPDATE/DELETE appended to `AuditLog` |
| **Arabic normalization** | Data layer (search queries), Core utils | Strip diacritics, normalize Alef/Taa variants |
| **Integer money** | Domain layer (`Money` value object) | All amounts in smallest currency unit |
| **UUID primary keys** | Domain layer (entity creation) | UUID v4, no auto-increment |
| **Sync-ready fields** | Drift schema (all mutable tables) | `syncVersion`, `updatedAt`, `isDeleted`, `deviceId` |
| **RTL layout** | Presentation layer (all screens) | Arabic-first, tested on every screen |
| **Offline-first** | All layers | Every feature must work with zero connectivity |
| **Min API 26** | Build config | `minSdkVersion 26` in `build.gradle` |
| **Analytics opt-out** | Settings + Firebase init (§0.3.2) | Respect `analyticsEnabled`; does not block transactional FCM |
| **Firebase / FCM** | Stage 0.3.2 + Stage 11.0 | Crashlytics + Analytics + zero-cost push rail for B2C / analytics / invites |
| **Google Drive backup** | Free for all tiers | Auth V2 shipped — persistence-first `AuthSessionBundle` + headless WorkManager sync |
| **CSV/Excel import** | Free for all tiers | No tier gate on import; workspace limits govern activation |
| **Merchant branding** | Pro/Pro+ / referral-unlocked `brandedPdf` (6.3 / 16.2) | PDF header: logo + store name + phone |
| **Onboarding & Delight** | Stage 9 | Auto-detect locale/currency; sticky tips; shared success primitive |
| **AI Voice (UNFROZEN)** | Pro+ + server quota (**Stage 18**) | **600/month** hard cap; single-call cloud architecture (v3.6); banked Stage 16 credits redeem here |
| **AI trial allowance** | Free 15 lifetime / Pro 60 per month (Stage 5) | `ai_usage_counters`; drives Pro+ upsell |
| **Banked AI credits** | Stage 16 → Stage 18 | No expiry before Voice launch; FIFO redeem |
| **Worker permissions** | Use-case + RLS (Stage 8.6) | Owner / Editor / Viewer; revoked-membership local wipe |
| **Merge Engine integrity** | Client op-log + server ordering (Stage 8.3) | Field-level LWW; balances recomputed, never transported |
| **Deep-link & attribution** | Own-domain App/Universal Links (Stage 8.5) | Shared by B2C (11) + Referral/Bridge (16) |
| **B2C Shared Accounts** | RLS SELECT-only binding (Stage 11.2) | Replaces web portal; FCM push updates |
| **B2C→B2B Bridge** | Stage 11 static CTA → Stage 16 attributed | Tiered removable; Free full footer, Pro compact, Pro+ removable |
| **Immutable receipts** | Stage 11.3 / 11.4 | Merchant deletion cannot erase customer receipts |
| **WhatsApp quota** | Pro+ 30 paid utility/month (Stage 11.1) | FCM + free service-window offload; plan $0.012/msg |
| **Ownership transfer** | Stage 13 | Trusted-device Factor 3; immediately before Stage 14 |
| **Prod Supabase cutover** | Stage 14 | Local Docker (8–13) → cloud gate |
| **Env / secrets matrix** | Stage 14.3 | Distinct JWT secrets; `BACKUP_AES_KEY` non-rotation |
| **CI / ARB parity** | Stage 14.9 + 19.5 | Analyze/test/build/Deno + ARB key parity |
| **Promo-code atomicity** | Stage 15.1 | Single-use 1-yr license; reuse impossible at DB level |
| **Downgrade semantics** | Stage 15.3 | Never hold data hostage; export + erasure |
| **Referral rewards** | Stage 16 | Zero-cost hybrid ladder; Pro+ trial cancelled |
| **Tier pricing** | Stage 15 | Free / Pro $24.99/yr / Pro+ $49.99/yr |
| **Extreme performance** | Stage 17 | 60fps, isolates, CI budgets; closes Stage 7.2 Delayed |
| **Transactional email** | Stage 19.4 | SPF/DKIM/DMARC + feedback loop + CAPTCHA step-up |
| **PDPL & data residency** | Stage 14.2 + 19.3 | me-south-1; SDAIA enforcement by 2027 |
| **Google Cloud preflight** | Stage 0.3.1 | Validated (Android); iOS pass pending |
| **Account rebind** | Auth V2 + Stage 13 | Prevents identity drift |
| **Ledger archiving** | Stage 6.7 + §8.1 | Pro/Pro+; optional Balance Carry Forward (§6.7.1) |
