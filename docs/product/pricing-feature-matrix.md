# Daftar Pricing Feature Matrix

> **Not judging.** Product pricing study. Closing Agent uses existing Free / Pro / Pro+ tiers as substrate only. Judges: [`README.md`](../../README.md).
>
> **Version:** 2.1 · **Date:** 2026-08-06 · **Supersedes:** v2.0 — AI rows updated to product roadmap v3.6 (capped unfreeze; study now in `docs/archive/ai_voice_feature_study.md`); all non-AI economics unchanged. v2.0 (2026-05-14) superseded v1.0.
>
> **Contest note:** Closing Agent uses existing Free / Pro / Pro+ tiers as substrate. Product Stage 18 AI voice study is archived; contest AI is Gemini **3.5+** Closing Agent per [`docs/roadmap_v2.md`](../roadmap_v2.md).

Inclusive model: Pro includes everything in Free, and Pro+ includes everything in Pro. Pro is priced at $24.99/year. Pro+ is priced at $49.99/year.

## Strategic Decisions & Math

### 1) Pricing Pivot Rationale

The previous pricing ($17/yr Pro, $79/yr Pro+) was revised based on the Phase 2 financial study:

- **$17/yr was non-viable** without 85K+ users due to fixed infrastructure costs.
- **AI features were FROZEN at the time of the pricing decision** — at 50–100 daily transactions per user, uncapped cloud AI costs ($104K/yr at 100K users) erase all margin, so the $24.99/$49.99 price points were set assuming zero AI cost. *(v2.1: AI voice is now unfrozen under hard caps whose worst case preserves these margins — see §7.)*
- **Pro raised to $24.99/yr** — still under $2.10/month, affordable for MENA merchants. Raises break-even from 85K to ~32K users.
- **Pro+ set at $49.99/yr** — captures multi-device sync and WhatsApp automation value without overpricing. The ~2x price jump from Pro makes Pro look like an impulse buy.

### 2) Authentication & Backup Cost Elimination

Two major cost pivots enable near-zero marginal cost per user:

- **Phone OTP → Google Sign-In:** Saves $0.02–$0.05/SMS. At 100K users, 2 OTPs/month = $48K–$120K/yr saved. Google Sign-In is free at any scale.
- **Supabase Storage → Google Drive:** Backup files stored in user's own 15GB Google Drive quota via `drive.appdata` scope. Zero storage and bandwidth cost to us.

Combined effect: Phase 1 infrastructure cost per user drops to effectively $0.

### 3) CSV / Excel Import Strategy

Best strategy: cap active live entries, not import volume.

- CSV and Excel import stay 100% Free.
- Imported rows land in an archive-first state.
- Free users can activate only 1 live ledger, 50 live contacts, and 500 live transactions.
- Pro unlocks unlimited activation of imported history into the live workspace.
- Pro+ inherits the same unlimited activation and adds sync, automation, and portal scale.

Why this works:

- It steals users from competitors with zero-friction migration.
- It avoids punishing large imports, including a 2,000-contact migration.
- It preserves a strong upgrade hook: turning archived history into a live, editable, multi-ledger workspace.

### 4) Pro Tier Unit Economics

Assumptions:

- Zero recurring cloud compute per Pro user (local-first, Google Drive = user's quota).
- Merchant branding is a local feature (PDF generated on-device).

For Pro at $24.99/year:

- MoR fee (Paddle 5% + $0.50): −$1.75
- Net revenue (via MoR): $23.24
- Net revenue (local activation code): $24.99
- Marginal infrastructure cost: ~$0.00/user/yr
- **Gross margin (MoR): 99.9%**

The Pro tier is the most profitable tier because it requires zero cloud resources beyond what the user already has (their own Google account).

### 5) Pro+ Tier Unit Economics

Assumptions:

- WhatsApp utility message cost: $0.03/message midpoint.
- Sync infra share: $0.42/user/yr (Supabase compute + storage amortized).
- AI voice (v2.1, Stage 18): single-call architecture, hard 600/month cap — realistic −$0.60/user/yr; absolute ceiling −$3.60/user/yr enforced by quota + audio caps (roadmap §§B–D).

For Pro+ at $49.99/year:

- MoR fee (Paddle 5% + $0.50): −$3.00
- Net revenue (via MoR): $46.99
- WhatsApp (4 msgs/month × $0.03 × 12): −$1.44/yr
- Sync infrastructure share: −$0.42/yr
- AI voice (600/mo cap, realistic utilization): −$0.60/yr
- Total marginal cost: −$2.46/yr
- **Gross margin (MoR): 94.8%** (worst case with every AI cap maxed at zero cache: −$5.46/yr → **88.4%** — still comfortably profitable)

### 6) Break-Even Analysis

At 100K total users with 5% Pro conversion and 1.5% Pro+ conversion:

| Line Item | Amount |
|---|---|
| Pro revenue (5,000 × $23.24) | $116,200/yr |
| Pro+ revenue (1,500 × $46.99) | $70,485/yr |
| **Total revenue** | **$186,685/yr** |
| Infrastructure (Supabase managed, sync only) | −$16,755/yr |
| WhatsApp API (Pro+ users only) | −$31,200/yr |
| MoR fees | −$12,500/yr |
| **Total costs** | **−$60,455/yr** |
| **Net profit** | **$126,230/yr** |
| **Net margin** | **67.6%** |
| **Break-even** | **~32K total users** |

> **v2.1 AI adjustment:** capped AI voice adds ≈ $1K/yr realistic (≤ $5.4K/yr if every entitled user maxed every cap simultaneously) at 100K users — net profit ≈ $121K–125K; break-even unchanged at ~32K users.

### 7) AI Freeze → Capped Unfreeze (v2.1, August 2026)

The original freeze was correct **for its assumptions**: at 50–100 *uncapped* cloud calls per user per day, cloud AI cost ~$104K/yr at 100K users and erased all margin. Two things changed:

- **Roadmap v3.0** changed the assumptions — a hard **600 commands/month** Pro+ cap (voice is the convenience path, not the bulk-entry path).
- **Roadmap v3.6** changed the architecture — one metered Gemini 3.1 Flash-Lite call per command (audio → schema-locked JSON) at **~$0.0003–0.0005/command**, verified 2026-08-06 (`docs/archive/ai_voice_feature_study.md`).

Resulting economics:

- Worst-case **≤ $3.60/Pro+ user/yr** (7.7% of net revenue); realistic **< $0.60** (1.2%).
- Fleet ceiling ≈ **$8K/yr** at 100K users with every cap maxed simultaneously; realistic ≈ **$1K/yr** — vs the $104K uncapped estimate.
- Cost variance is structurally bounded: server-authoritative quotas (600/mo · 40/day · 90 audio-min/mo · 30 s/clip) plus an org-wide budget breaker (default $250/mo) that pauses the feature before it can lose money, while manual entry continues untouched.
- AI voice becomes the flagship Pro+ differentiator, with a Free (15 lifetime) / Pro (60/month) trial that drives upsell — instead of a deleted line item.

## Feature Matrix

| Feature / Capability | Free | Pro ($24.99/year) | Pro+ ($49.99/year) |
| --- | --- | --- | --- |
| **Limits, Migration, and Plan Hooks** | | | |
| Live ledger slots | 1 active ledger | Unlimited | Unlimited |
| Starter ledger templates | 3 templates, 1 active at a time | 3 templates, all active | 3 templates, all active |
| Custom ledgers | 0 | Unlimited | Unlimited |
| Live contacts | 50 active contacts | Unlimited | Unlimited |
| Live transactions | 500 active transactions | Unlimited | Unlimited |
| Imported archive mode | Unlimited CSV / Excel import, archive-first state | Unlimited activation into live workspace | Unlimited activation into live workspace plus sync |
| Free-tier warning threshold | 40 contacts, 400 transactions | Not needed | Not needed |
| Free-tier upgrade CTA | Included | Not needed | Not needed |
| **Core Ledger, Contact, and Transaction Ops** | | | |
| Ledger customization | Name, icon, color, sort order | Included | Included |
| Ledger reordering | Drag-and-drop | Included | Included |
| Ledger archiving (Archive Vault) | Not available (upgrade CTA) | Archive unlimited ledgers to read-only vault, global balance exclusion, full browse and PDF export | Included |
| Contact fields | Name, optional phone, notes, initials avatar, avatar color | Included | Included |
| Contact uniqueness within a ledger | Included | Included | Included |
| Contact list presentation | Name, net balance, last activity date | Included | Included |
| Contact sorting | Alphabetical, balance, recent activity | Included | Included |
| Arabic-normalized contact search | Debounced search bar, clear button, FTS5, diacritics and Alef/Taa Marbuta normalization | Included | Included |
| WhatsApp deep-link from contact | Included | Included | Included |
| Call button from contact | Included | Included | Included |
| Quick action entry surface | Central docked FAB and bottom-sheet flows | Included | Included |
| Transaction lifecycle | Add debt, record payment, edit, soft-delete, undo, backdate | Included | Included |
| Undo window | 5 seconds | Included | Included |
| Transaction date handling | Date picker plus Today, Yesterday, This Week grouping | Included | Included |
| Running balance after each transaction | Included | Included | Included |
| Transaction list presentation | Type indicator, amount, item name, description, date, running balance | Included | Included |
| Transaction pagination | 20 per page | Included | Included |
| History-based autocomplete | Recent item names, last price, frequent contacts, no ML | Included | Included |
| Global recent-item search | Recent item names across active transactions | Included | Included |
| **Money, Currency, and Balance Intelligence** | | | |
| Integer money model | Smallest currency unit only | Included | Included |
| Money value object | Amount plus currency code | Included | Included |
| Built-in currencies | YER, SAR, USD seeded on first launch | Included | Included |
| Custom currencies | Included | Included | Included |
| Currency display formatting | decimalPlaces-based conversion | Included | Included |
| Per-contact per-currency balances | Included | Included | Included |
| No auto-conversion across currencies | Included | Included | Included |
| Dynamic balance card | Owed vs owes summary, per-currency chips, count-up, tap-to-expand | Included | Included |
| Denormalized ContactBalance | O(1) reads with atomic recalculation on writes | Included | Included |
| Credit limits and warnings | Included, with 80% and 100% alerts plus in-app banner | Included | Included |
| Local notifications for limit warnings | Included | Included | Included |
| **Statements, Sharing, and Reports** | | | |
| PDF statement generation | Basic statement PDF (app name header only) | Branded statement PDF (merchant logo, store name, phone in header) | Branded statement PDF plus batch export |
| Merchant branding setup | Not available (fields visible but disabled, upgrade CTA) | Logo upload, store name, store phone, PDF preview | Included |
| Arabic RTL PDF layout | Included | Included | Included |
| Multi-currency PDF sections | Included | Included | Included |
| PDF generation in isolate | Included | Included | Included |
| PDF text sanitization (bidi marks stripped, non-breaking spaces normalized) | Included | Included | Included |
| Statement date range selector | Included | Included | Included |
| Share statement via WhatsApp | Deep-link plus share sheet fallback | Deep-link plus share sheet fallback | Deep-link plus share sheet fallback |
| Share statement button | Included | Included | Included |
| **Import, Merge, and Portability** | | | |
| CSV import | Unlimited rows, column mapping, preview, UTF-8 and Windows-1256 support | Unlimited rows | Unlimited rows |
| Excel import | Unlimited rows, sheet selector, column mapping, Arabic text handling | Unlimited rows | Unlimited rows |
| Duplicate detection during import | Same name plus phone merge-or-skip flow | Included | Included |
| Smart merge on restore | Not available | Exact phone match, Arabic similarity >85%, transaction duplicates within ±60s, merge / keep both / skip | Included |
| PDF import | Not available | Not available | Typed Arabic PDFs only, no OCR, beta |
| Import summary | Imported contacts, imported transactions, skipped rows with reasons | Included | Included |
| **Backup and Cloud Storage** | | | |
| Local encrypted .daftar backup export | Included | Included | Included |
| Local restore from file | File picker, overwrite confirmation, replace DB, restart | Included | Included |
| Restore on integrity failure | Offer restore when startup integrity check fails | Included | Included |
| AES-256 backup encryption | App-bound key via envied, checksum validation, versioning header | Included | Included |
| Backup history metadata | Date, size, file path, checksum | Included | Included |
| Auto-backup reminders | Weekly or monthly | Weekly or monthly | Weekly or monthly |
| Google Drive backup | 1 linked Google account, unlimited backup and restore, stored in user's Drive appdata folder, zero cost | 1 linked Google account | 1 linked Google account |
| Merchant logo in backup | Not available | Logo bundled in .daftar file for cross-device branding preservation | Included |
| Backup storage guardrail | Block backup when free disk is under 50MB | Included | Included |
| Drive quota error handling | Detect 403 storageQuotaExceeded, user-friendly message, delete old backups from within app | Included | Included |
| Cloud progress and error handling | Progress percentage, retry with exponential backoff, offline-to-online recovery | Included | Included |
| **Authentication** | | | |
| Google Sign-In | Included (required for Google Drive backup) | Included | Included |
| Silent sign-in for returning users | Included | Included | Included |
| Sign-out option | Included | Included | Included |
| Offline app usage without sign-in | Fully functional (local backup only, no Drive access) | Fully functional | Fully functional |
| **Security, Settings, and Monetization** | | | |
| PIN lock | Included | Included | Included |
| Biometric unlock | Included | Included | Included |
| PIN hashing | SHA-256 plus salt in secure storage only | Included | Included |
| Auto-lock timeout | Immediate, 1 minute, 5 minutes, 15 minutes | Included | Included |
| App resume lock | Included | Included | Included |
| Forgot PIN recovery | Requires backup restore | Included | Included |
| Language selector | Arabic default, English, RTL / LTR switching | Included | Included |
| Theme selector | Dark, light, system, dark default, dynamic tokens | Included | Included |
| Default currency selector | Included | Included | Included |
| Analytics opt-out | Included | Included | Included |
| Support, about, and rate-app links | WhatsApp support link, version info, rate-app link | Included | Included |
| Google account display in settings | Signed-in email or sign-in prompt | Included | Included |
| Plan status and entitlement screen | Upgrade prompt only | Active plan display, unlock code redemption, tier comparison | Active plan display, unlock code redemption, tier comparison |
| Offline premium token | Not available | Signed token in secure storage, expiry, local validity check, 7-day grace on revocation | Signed token in secure storage, expiry, local validity check, 7-day grace on revocation |
| Manage subscription section | Not available | Included | Included |
| **Automation and Communications** | | | |
| Automated WhatsApp reminders | 0 per month | 0 per month | 30 per month, weekly and monthly templates, reminder history, background scheduling |
| Battery optimization wizard | Not available | Not available | Included |
| Reminder history log | Not available | Not available | Included |
| **Sync, Multi-device, and Customer Portal** | | | |
| Multi-device sync | 0 devices | 0 devices | 10 active devices, 50,000 sync events per month |
| Sync status and manual sync now | Not available | Not available | Included |
| Automatic sync on connectivity change | Not available | Not available | Included |
| Conflict resolution | Not available | Not available | Field-level merge, last-write-wins by timestamp, modification wins over deletion, duplicates kept for manual review |
| Operation log replay | Not available | Not available | Included |
| Server timestamps and clock-skew handling | Not available | Not available | Included |
| Multiple workers per shop account | Not available | Not available | Included |
| Customer portal | 0 links | 0 links | 500 active links, 50,000 views per month, short URLs, expiry, revocation, Arabic RTL web layout |
| **Analytics, Support Tiers, and Growth** | | | |
| Advanced analytics | Not available | Not available | Debt aging buckets 0, 30, 60, 90+, payment patterns, cash flow projections, charts, date-range filtering, PDF export with merchant branding |
| Priority support | Not available | Not available | Included |
| **AI Voice Input (Stage 18 — hard-capped, v2.1)** | | | |
| AI voice transaction entry (Arabic dialects, single-call parse, editable Confirm Card — money never auto-commits) | 15 lifetime trial commands | 60 trial commands per month | 600 commands per month (hard cap; ≤ 40/day, ≤ 90 audio-min/month) |
| Banked referral AI credits (Stage 16 ladder — 3 per verified invite) | Earnable; redeem at Stage 18 launch (FIFO, no expiry pre-launch) | Earnable; redeem at Stage 18 launch | Included in quota pool |
| Voice Outbox (offline capture, auto-parse on reconnect) | Included while trial credits remain | Included | Included |
| **UX, RTL, and Performance** | | | |
| One-handed RTL UX | Bottom-sheet-centric flows, large tap targets, bottom 60% reachability, haptics | Included | Included |
| Loading polish | Skeleton loading, pull-to-refresh animations, fade-slide transitions | Included | Included |
| Typography | Noto Kufi Arabic plus Inter | Included | Included |
| RTL visual polish | Alignment, icons, swipe direction, Arabic-first layouts | Included | Included |
| Page and sheet motion | Shared-element transitions, spring bottom sheets | Included | Included |
| Local operation latency | Under 100ms | Included | Included |
| Cold start target | Under 2 seconds | Included | Included |
| Transaction list scroll target | 60 fps on 1000+ transactions | Included | Included |
| PDF generation target | 500 transactions under 5 seconds in isolate | Included | Included |
| Memory target | Under 150MB | Included | Included |
| APK size target | Under 30MB per ABI | Included | Included |
| Crash-free target | 99.5% or better | Included | Included |
| Platform support | Android API 26+, iOS 15+ | Included | Included |
| **Data Integrity and Search Infrastructure** | | | |
| UUID v4 primary keys | Included | Included | Included |
| Soft deletes everywhere | Included | Included | Included |
| Audit logging | Every CREATE, UPDATE, DELETE appended to AuditLog | Included | Included |
| Sync-ready mutable schema | syncVersion, updatedAt, deviceId on all mutable entities | Included | Included |
| Explicit migrations | Step-by-step, non-destructive schema upgrades | Included | Included |
| Indexed query columns | Included | Included | Included |
| FTS5 Arabic contact search | Included | Included | Included |
| Arabic text normalization | Strip diacritics, normalize Alef and Taa Marbuta variants | Included | Included |
| SQLite WAL and integrity checks | Included | Included | Included |
| Fail-closed count queries | Included | Included | Included |
| Parent preflight validation | Prevent children under soft-deleted parents | Included | Included |
| Atomic multi-table writes | Included | Included | Included |

## Tier Positioning Summary

**Pro ($24.99/yr)** is the local power-user tier: it removes workspace caps and adds merchant branding for professional PDF statements. It has zero recurring cloud cost per user, making it the highest-margin tier. The $24.99 price point is under $2.10/month — equivalent to a single cup of coffee — designed as an impulse buy for merchants who have experienced the app's value during the free trial window (~2-3 months at 50 contacts/500 transactions).

**Pro+ ($49.99/yr)** is the scale tier: it monetizes shops that need multi-device collaboration, automated WhatsApp reminders, customer-facing balance portals, and deeper analytics. The ~2x price jump from Pro creates clear price anchoring — Pro looks cheap by comparison, driving higher Pro conversion rates.

**Google Drive backup and Google Sign-In are free for all tiers** because they cost $0 in infrastructure, build massive user trust (data stays in their own Google account), and serve as the app's sole authentication path. Gating them would reduce adoption with no cost justification.

**AI voice is included as a hard-capped feature, not an open tap** (v2.1). The original exclusion was a cost-discipline decision under uncapped assumptions (50–100 AI calls/day would be non-viable). Roadmap v3.6's single-call architecture with server-authoritative quotas bounds the worst case to ≤ $3.60/Pro+ user/yr (realistic < $0.60), with an org-wide budget breaker as the final backstop — preserving the margin story above while giving Pro+ its most demonstrable differentiator and Free/Pro a taste that drives upgrades. Voice is positioned as the *convenience* path; unlimited manual entry remains the bulk path at every tier.
