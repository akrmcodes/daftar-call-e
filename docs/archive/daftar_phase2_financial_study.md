> **Archived — not binding for All Things Agentic (Submission Period 3–31 Aug 2026).**
> Contest execution contract: `docs/roadmap_v2.md`.
> Original date retained for historical accuracy.

# Daftar — Phase 2 Financial & Architectural Study

> **Date:** 2026-05-07 · **Scope:** 100K → 1M users · **Verdict:** $17/year is non-viable without radical AI cost control

---

## Pillar 1: Financial Modeling & Infrastructure Costs

### 1.1 Supabase / PostgreSQL Cost Model (100K Users)

**Data volume assumptions:**
- 100K users × 500 contacts × 200 txns/contact = **10 billion transactions**
- Avg row size (transactions table): ~250 bytes → **~2.5 TB raw data**
- With indexes, TOAST, and bloat (~2x overhead): **~5 TB effective storage**
- Supporting tables (contacts, balances, audit logs): **~500 GB additional**
- **Total DB footprint: ~5.5 TB**

| Resource | Requirement | Supabase Rate | Annual Cost |
|---|---|---|---|
| Database storage | 5,500 GB | $0.125/GB/mo (after 8 GB included) | **$8,235/yr** |
| Compute (XL minimum) | 4-core, 16 GB RAM | $210/mo | **$2,520/yr** |
| Realtime connections | 10K concurrent (10% of users) | Enterprise pricing ~$500/mo | **$6,000/yr** |
| Auth (MAUs) | 100K | Free up to 100K on Pro | **$0** |
| Daily backups | 5.5 TB | Included (7-day retention) | **$0** |
| **Supabase subtotal** | | | **$16,755/yr** |

> [!WARNING]
> At 5.5 TB, you have **outgrown Supabase's managed offering**. Their largest documented compute is 16XL (64-core, 256 GB RAM) at ~$3,500/mo. At this scale, you need **self-hosted PostgreSQL on AWS/GCP** or Supabase Enterprise ($$$). Realistic annual infra cost: **$25,000–$40,000/yr**.

**Realistic infrastructure estimate (self-hosted PostgreSQL on AWS):**

| Component | Spec | Monthly Cost | Annual |
|---|---|---|---|
| RDS PostgreSQL (db.r6g.2xlarge) | 8 vCPU, 64 GB RAM | $1,200 | $14,400 |
| Storage (gp3, 6 TB) | Provisioned IOPS | $550 | $6,600 |
| Read replica (scaling) | Same instance class | $1,200 | $14,400 |
| Supabase Auth + Realtime (keep managed) | — | $550 | $6,600 |
| **Total infra** | | | **$42,000/yr** |

### 1.2 Data Residency & PDPL Compliance

**Saudi PDPL (effective Sept 2024):**
- Personal data of Saudi residents **may be transferred** outside KSA only with adequate protections (contractual safeguards, adequacy decisions).
- **Sensitive data** (financial data qualifies) requires explicit consent for cross-border transfer.
- No blanket requirement for in-kingdom hosting — but a **strong regulatory preference** exists. SDAIA (the regulator) has signaled stricter enforcement by 2027.

**Cost impact of ME hosting:**

| Region | AWS Instance (r6g.2xlarge) | Premium vs US |
|---|---|---|
| us-east-1 (Virginia) | ~$0.83/hr | Baseline |
| eu-west-1 (Ireland) | ~$0.91/hr | +10% |
| me-south-1 (Bahrain) | ~$0.99/hr | **+19%** |
| me-central-1 (UAE) | ~$1.02/hr | **+23%** |

**Recommendation:** Host in **me-south-1 (Bahrain)** from day one. The 19% premium on a $42K base adds ~$8K/yr — cheap insurance against regulatory risk. Supabase does NOT offer ME regions; you must self-host or use their Enterprise plan with custom region deployment.

### 1.3 Network & Egress Costs

**Sync payload model (local-first, burst sync):**
- Average sync payload per user per day: ~50 KB (delta changes, not full DB)
- 100K users × 50 KB × 365 days = **~1.8 TB/yr egress**
- Cloud backup (full DB dump per user): avg 50 MB × 100K users × 2 backups/yr = **~10 TB/yr**

| Egress Type | Volume/yr | Rate | Annual Cost |
|---|---|---|---|
| Sync (delta) | 1.8 TB | $0.09/GB (AWS) | **$162** |
| Cloud backup upload | 10 TB | $0 (ingress free) | **$0** |
| Cloud backup download | 5 TB (50% restore) | $0.09/GB | **$450** |
| Supabase Realtime | Included in plan | — | **$0** |
| **Egress subtotal** | | | **~$612/yr** |

Egress is negligible. The local-first architecture is your biggest cost advantage.

### 1.4 WhatsApp Business API Costs

**Post-July 2025 pricing (per-message model):**

| Message Type | MENA Rate (est.) | Use Case |
|---|---|---|
| Utility (template) | ~$0.02–$0.04/msg | Payment reminders, balance updates |
| Marketing | ~$0.05–$0.08/msg | Re-engagement, promotions |
| Customer-initiated reply | Free (24-hr window) | — |

**Volume estimate (automated reminders):**
- 20% of 100K users activate reminders = 20K users
- Avg 4 reminders/month per user = 80K messages/month = 960K/yr
- At $0.03/msg average: **$28,800/yr**
- BSP platform fee (Twilio/360dialog): ~$200/mo = **$2,400/yr**

**Total WhatsApp cost: ~$31,200/yr**

> [!CAUTION]
> WhatsApp costs scale linearly and are **uncontrollable** — Meta sets the price. At $31K/yr this is your **second-largest line item** after infra. Gate this aggressively behind Pro+ tier only.

---

## Pillar 2: AI Integration & Costs

### 2.1 Speech-to-Text (STT) Annual Cost

**Scenario:** 100K users × 50 audio inputs/day × 365 days

**Assumptions:**
- Average audio clip duration: 8 seconds (short merchant dictation)
- Total audio minutes/day: 100K × 50 × (8/60) = **666,667 minutes/day**
- Annual: **243.3 million minutes/year**

| STT Provider | Rate/min | Annual Cost | Arabic Dialect Quality |
|---|---|---|---|
| OpenAI Whisper API | $0.006/min | **$1,460,000** | Good (MSA + Gulf) |
| GPT-4o Mini Transcribe | $0.003/min | **$730,000** | Good |
| Deepgram Nova-3 | ~$0.0043/min | **$1,046,000** | Moderate (needs testing) |
| **On-device Whisper.cpp** | **$0** | **$0** | Good (but slower on low-end) |

> [!IMPORTANT]
> **Cloud STT at this scale is financially catastrophic.** Even the cheapest option (GPT-4o Mini Transcribe) costs **$730K/yr** — more than 40× your total infrastructure cost. **On-device Whisper.cpp is the only viable path.** Use cloud as a fallback for failed on-device attempts only (<5% of requests).

**Recommended architecture:**
1. **Primary:** On-device Whisper (tiny/base model via `whisper_flutter_new`) — $0 marginal cost
2. **Fallback:** Cloud STT for low-confidence results (~5% of inputs) = ~$36,500/yr
3. **Total STT cost: ~$36,500/yr** (vs $730K+ for full cloud)

### 2.2 LLM Parsing — Model Recommendation

**Task:** Extract structured JSON from transcribed Arabic text.

Example input: `"محمد احمد الزبيري عليه خمس مئه ريال سكر و حليب شاهي"`

Expected output:
```json
{"contact": "محمد احمد الزبيري", "type": "debt", "amount": 500, "currency": "YER", "items": ["سكر", "حليب", "شاهي"]}
```

**Token estimate per request:** ~150 input + ~80 output = ~230 tokens

| Model | Input $/1M | Output $/1M | Cost/request | Annual (1.825B req) | Accuracy | Latency |
|---|---|---|---|---|---|---|
| Gemini 2.0 Flash-Lite | $0.075 | $0.30 | $0.000035 | **$63,875** | Good | ~200ms |
| Gemini 1.5 Flash | $0.10 | $0.40 | $0.000047 | **$85,775** | Good | ~300ms |
| GPT-4o-mini | $0.15 | $0.60 | $0.000071 | **$129,575** | Very Good | ~400ms |
| Claude 3.5 Haiku | $1.00 | $5.00 | $0.00055 | **$1,003,750** | Excellent | ~500ms |

**Winner: Gemini 2.0 Flash-Lite** — cheapest at $64K/yr with acceptable Arabic parsing quality.

### 2.3 Total AI Pipeline Cost

| Component | Annual Cost |
|---|---|
| On-device STT (primary) | $0 |
| Cloud STT fallback (5%) | $36,500 |
| LLM parsing (Gemini Flash-Lite) | $63,875 |
| Edge function compute (Supabase) | ~$3,600 |
| **Total AI cost** | **~$104,000/yr** |

### 2.4 AI Pipeline Architecture

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌──────────┐
│  Microphone  │───▶│ On-Device    │───▶│ Regex Parser│───▶│  App DB  │
│  (Flutter)   │    │ Whisper.cpp  │    │ (Local)     │    │ (Drift)  │
└─────────────┘    └──────┬───────┘    └──────┬──────┘    └──────────┘
                          │ <5% fallback      │ Ambiguous
                          ▼                   ▼
                   ┌──────────────┐    ┌─────────────┐
                   │ Cloud STT    │    │ LLM (Gemini │
                   │ (Edge Func)  │    │ Flash-Lite) │
                   └──────────────┘    └─────────────┘
```

**Key design decisions:**
1. **Privacy:** Audio never leaves device unless on-device STT fails
2. **Cost control:** Hard daily cap per user (50 cloud fallbacks/day max)
3. **Latency:** On-device STT ~1.5s on mid-range device; cloud fallback ~2.5s
4. **Regex-first:** ~70% of merchant phrases match structured patterns — no LLM needed
5. **LLM budget circuit-breaker:** Monthly spend cap with auto-disable at threshold

---

## Pillar 3: Monetization & Tiering

### 3.1 Tier Design

| Feature | Free | Pro ($17/yr) | Pro+ ($49/yr) |
|---|---|---|---|
| Ledgers | 1 | Unlimited | Unlimited |
| Contacts | 50 | Unlimited | Unlimited |
| Transactions | 500 | Unlimited | Unlimited |
| Local backup | ✅ | ✅ | ✅ |
| Cloud backup | ❌ | ✅ | ✅ |
| CSV/Excel import | ❌ | ✅ | ✅ |
| Credit limits | ❌ | ✅ | ✅ |
| PDF statements | Basic | Branded | Branded |
| AI voice input | ❌ | 10/day | 50/day |
| Multi-device sync | ❌ | ❌ | ✅ |
| WhatsApp automation | ❌ | ❌ | ✅ |
| Advanced analytics | ❌ | ❌ | ✅ |
| Customer portal | ❌ | ❌ | ✅ |
| Priority support | ❌ | ❌ | ✅ |

**Rationale:** AI and sync are the most expensive features — they go in Pro+. Pro is the "local power user" tier with zero recurring cloud costs per user.

### 3.2 Net Revenue Per User — $17/yr Pro Tier

| Line Item | Amount | Notes |
|---|---|---|
| Gross revenue | $17.00 | Annual subscription |
| MoR fee (Paddle: 5% + $0.50) | −$1.35 | Per transaction |
| App Store/Play Store (15% for small devs) | −$2.55 | Only if sold via IAP |
| **Net revenue (via MoR, no app store)** | **$15.65** | Web checkout |
| **Net revenue (via app store)** | **$13.10** | Native IAP |
| **Net revenue (local activation code)** | **$17.00** | Zero fees |

**Per-user infrastructure cost (Pro tier, no AI, no sync):**

| Cost Component | Annual Per-User |
|---|---|
| Supabase cloud backup storage (~50 MB) | $0.013 |
| Auth (included up to 100K MAU) | $0.00 |
| Egress (2 backups/yr) | $0.009 |
| **Total marginal infra cost** | **~$0.02/user/yr** |

**Pro tier gross margin: ~$15.63/user/yr (99.9%) — extremely healthy.**

The Pro tier is profitable because it uses zero recurring cloud compute — it's purely a feature unlock on a local-first app. Cloud backup storage is negligible.

### 3.3 Net Revenue Per User — $49/yr Pro+ Tier

| Line Item | Amount |
|---|---|
| Gross revenue | $49.00 |
| MoR fee (5% + $0.50) | −$2.95 |
| **Net revenue (MoR)** | **$46.05** |

**Per-user cost (Pro+ with AI + sync + WhatsApp):**

| Cost Component | Annual Per-User |
|---|---|
| Cloud STT fallback (5% of 10 inputs/day) | $0.33 |
| LLM parsing (50 req/day × 365) | $0.64 |
| Sync infra (DB storage + compute share) | $0.42 |
| WhatsApp messages (4/month) | $1.44 |
| **Total marginal cost** | **~$2.83/user/yr** |

**Pro+ gross margin: ~$43.22/user/yr (93.8%) — very healthy.**

### 3.4 Unit Economics & LTV:CAC Analysis

**Assumptions for MENA merchant demographic:**

| Metric | Estimate | Rationale |
|---|---|---|
| Free-to-Pro conversion | 5% | Conservative for utility apps in emerging markets |
| Free-to-Pro+ conversion | 1.5% | Only power users with multiple employees |
| Annual churn (Pro) | 25% | High for price-sensitive MENA SMBs |
| Annual churn (Pro+) | 15% | Higher stickiness due to sync/AI lock-in |
| CAC (organic + word-of-mouth) | $2.00 | MENA WhatsApp-viral distribution |
| CAC (paid acquisition) | $8.00 | Facebook/Instagram ads in MENA |
| Blended CAC | $4.00 | 50/50 organic/paid mix |

**Customer Lifetime Value (LTV):**

```
LTV = ARPU / Churn Rate

Pro:  LTV = $15.65 / 0.25 = $62.60
Pro+: LTV = $46.05 / 0.15 = $307.00
```

**Blended LTV (weighted by tier mix: 77% Pro, 23% Pro+):**
```
Blended LTV = (0.77 × $62.60) + (0.23 × $307.00) = $48.20 + $70.61 = $118.81
```

**LTV:CAC Ratios:**

| Scenario | LTV | CAC | LTV:CAC | Verdict |
|---|---|---|---|---|
| Pro (organic) | $62.60 | $2.00 | **31:1** | 🟢 Excellent |
| Pro (paid) | $62.60 | $8.00 | **7.8:1** | 🟢 Good |
| Pro+ (organic) | $307.00 | $2.00 | **153:1** | 🟢 Exceptional |
| Blended | $118.81 | $4.00 | **29.7:1** | 🟢 Excellent |

> [!IMPORTANT]
> **The $17/year Pro tier is viable** — but only because the local-first architecture means near-zero marginal infrastructure cost per Pro user. The danger is if you try to include AI or sync in this tier — that immediately destroys margins.

**The real risk is not price — it's conversion rate.** At 5% conversion with 100K users:
- 5,000 Pro users × $15.65 = $78,250/yr
- 1,500 Pro+ users × $46.05 = $69,075/yr
- **Total annual revenue: ~$147,325/yr**
- **Total annual costs (infra + AI + WhatsApp): ~$177,200/yr**

> [!CAUTION]
> **At 100K total users with 6.5% paid conversion, you are operating at a ~$30K/yr loss.** You need either (a) higher conversion (>8%), (b) higher ARPU, or (c) 150K+ total users to break even. The $17/year price is viable per-unit but requires **volume** to cover fixed infrastructure costs.

**Break-even analysis:**

| Scenario | Users Needed | Pro Conv. | Pro+ Conv. |
|---|---|---|---|
| Current pricing | **~130K total** | 5% | 1.5% |
| Pro at $24/yr | ~100K total | 5% | 1.5% |
| Pro at $17/yr, Pro+ at $69/yr | ~105K total | 5% | 1.5% |

---

## Pillar 4: Scalability & Maintainability

### 4.1 What Breaks First at 1M Users

| Component | Breaking Point | Failure Mode | Mitigation |
|---|---|---|---|
| **PostgreSQL single-writer** | ~500K users | Write contention on ContactBalances table during sync bursts | Horizontal sharding by user_id (Citus extension) or write-ahead queue |
| **Supabase Realtime** | ~50K concurrent | Channel subscription limits exceeded | Migrate to self-hosted Supabase or dedicated WebSocket server |
| **Supavisor connection pooling** | ~100K concurrent | Pool exhaustion even in transaction mode | Dedicated PgBouncer + read replicas; geographic routing |
| **AI Edge Functions** | ~200K daily AI users | Cold start latency + concurrent execution limits | Dedicated inference server (GPU instance) or managed endpoint (Vertex AI) |
| **Audit log table** | ~50B rows | Unbounded append-only table causes vacuum bloat | Time-partitioned tables; archive to cold storage monthly |
| **FTS5 (local Drift)** | ~10K contacts/device | N/A — local only, scales per-device | No issue — local-first wins again |

**Priority remediation order:**
1. **Audit log partitioning** — implement before 100K users (Stage 8)
2. **Read replicas** — add at 200K users
3. **Connection pooling upgrade** — at 300K users
4. **Write sharding** — at 500K+ users (significant engineering)

### 4.2 Connection Pooling Deep-Dive

**At 100K users with 10% daily concurrent sync:**

- 10K concurrent connections via Supavisor (transaction mode)
- Each connection borrows a backend slot for ~50ms per transaction
- Throughput: 10K × (1000ms/50ms) = 200K transactions/second capacity
- Required backend pool: ~200 connections (XL compute supports ~250)

**This is tight but feasible** on Supabase XL compute. At 1M users (100K concurrent), you need:
- 2,000 backend connections → multiple PostgreSQL instances with geographic routing
- Cost: ~$15K/mo ($180K/yr) for a multi-node cluster

### 4.3 Maintainability with a Small Team

**Current stack complexity score (1-10):**

| Component | Complexity | Team Skill Required |
|---|---|---|
| Flutter + Riverpod + Drift | 7/10 | Senior Flutter developer |
| Supabase (managed) | 3/10 | Basic DevOps |
| Self-hosted PostgreSQL | 8/10 | DBA or DevOps engineer |
| AI pipeline (Whisper + LLM) | 6/10 | ML engineer (part-time) |
| Sync engine (CRDT-lite) | 9/10 | Senior backend engineer |
| WhatsApp Business API | 4/10 | Integration developer |

**Recommended minimum team for Phase 2:**
- 1 Senior Flutter developer (full-time)
- 1 Backend/DevOps engineer (full-time)
- 1 ML engineer (part-time / contractor)
- Total: **2.5 FTE**

**Architectural simplifications to reduce maintenance:**

1. **Delay multi-device sync** — it's the highest-complexity, highest-cost feature. Keep cloud backup as the "sync" mechanism until you hit clear PMF signals.
2. **Use Supabase managed** as long as possible — delay self-hosting until storage exceeds 1 TB.
3. **Batch LLM calls** — use Gemini Batch API (50% discount) for non-real-time parsing.
4. **Avoid custom WebSocket servers** — use Supabase Realtime until it breaks.

---

## Pillar 5: Blind Spots & Optimizations

### 5.1 Critical Blind Spots

#### 🔴 Blind Spot #1: Yemen Sanctions & Payment Processing

Yemen is under partial US/EU sanctions. Paddle and Lemon Squeezy **may refuse** to process payments from/for Yemeni merchants. Your "local activation code" rail exists for this reason, but:
- You need a **legal entity** in a non-sanctioned country (UAE, Saudi, Egypt) to operate the MoR rail.
- Hawala-based code distribution is legally grey — consult a MENA fintech lawyer.

#### 🔴 Blind Spot #2: PDPL Is Not Optional (Post-2027)

Your roadmap (RAD-005) says: *"No complex GDPR consent gates for the initial MENA release."* This is **dangerous** for Phase 2:
- Saudi PDPL fines: up to **5M SAR (~$1.3M)** per violation.
- If you store Saudi merchants' customer data (names, phone numbers, debt amounts) in a non-ME region, you are at risk.
- **Action:** Add PDPL consent flow before Phase 2 sync launch. Budget 2 weeks of development.

#### 🟡 Blind Spot #3: WhatsApp Business API Approval

Getting approved for WhatsApp Business API is **not automatic**. Meta requires:
- Verified business entity
- Privacy policy
- Use-case approval (debt collection messages may be flagged as "spam/harassment")
- **Risk:** Meta may reject or rate-limit debt reminder messages.
- **Mitigation:** Frame messages as "account statements" not "debt collection."

#### 🟡 Blind Spot #4: OEM Battery Kill (Android)

Your roadmap acknowledges this but underestimates severity. In MENA:
- 60%+ of devices are Xiaomi, Huawei, Samsung, or Oppo
- ALL of these aggressively kill background processes
- WorkManager / AlarmManager reliability: **~40-60%** on these OEMs
- WhatsApp automation reminders **will not fire** for most users without manual battery optimization whitelisting
- **This will generate support tickets and 1-star reviews**

#### 🟡 Blind Spot #5: No Offline AI Fallback Architecture

If on-device Whisper.cpp fails (unsupported device, low memory), and cloud is unreachable (offline-first promise), the AI feature is dead. You need a **graceful degradation path**:
- Offline: Show manual entry form with smart autocomplete (existing feature)
- Semi-offline: Queue audio for cloud processing when connectivity returns

#### 🟢 Blind Spot #6: Currency Volatility (YER)

The Yemeni Rial has extreme volatility (dual exchange rate regime). Your integer money storage is correct, but:
- Users may need to record the **same transaction in multiple currencies** (e.g., priced in SAR, paid in YER)
- This is not supported in your current schema (one currency per transaction)
- **Consider:** Add optional `originalCurrency` + `originalAmount` fields for Phase 2

### 5.2 Cost Optimization Strategies

| Strategy | Savings | Effort | Impact |
|---|---|---|---|
| **On-device STT (Whisper.cpp)** | $693K/yr vs full cloud | High (1-2 weeks) | 🟢 Critical — non-negotiable |
| **Regex-first NLP parser** | ~$45K/yr (eliminates 70% of LLM calls) | Medium (1 week) | 🟢 High |
| **Gemini Batch API** for non-real-time | ~$32K/yr (50% off) | Low (2 days) | 🟢 Medium |
| **Prompt caching** for LLM | ~$10K/yr (90% off cached tokens) | Low (1 day) | 🟡 Medium |
| **Gate WhatsApp behind Pro+** | $31K/yr saved vs offering to all | Zero | 🟢 High |
| **Delay self-hosted Postgres** | ~$20K/yr (stay on managed) | Zero | 🟡 Medium |
| **Archive audit logs >90 days** | ~$3K/yr storage savings | Low (1 day) | 🟢 Low |
| **CDN for static assets** | ~$500/yr | Low | 🟡 Low |

**Total potential savings: ~$135K/yr** (from $177K → $42K operating cost)

### 5.3 Optimized P&L Projection (100K Users)

| Line Item | Before Optimization | After Optimization |
|---|---|---|
| **Revenue** | $147,325 | $147,325 |
| Infrastructure (Supabase managed) | $42,000 | $16,755 (stay managed longer) |
| AI pipeline | $104,000 | $22,000 (on-device + regex + batch) |
| WhatsApp API | $31,200 | $31,200 (Pro+ only, fewer users) |
| MoR fees | ~$9,500 | ~$9,500 |
| **Total costs** | **$186,700** | **$79,455** |
| **Net profit** | **−$39,375** | **+$67,870** |
| **Net margin** | **−26.7%** | **+46.1%** |

> [!TIP]
> **With aggressive optimization, $17/year is viable at 100K users.** The single most important optimization is on-device STT — it alone swings the P&L from a $39K loss to profitability.

---

## Summary Verdict

| Question | Answer |
|---|---|
| Is $17/yr viable? | **Yes, but only with on-device AI and aggressive cost gating** |
| Can the architecture handle 100K users? | **Yes, with Supabase Pro + XL compute** |
| Can it handle 1M users? | **Not without sharding, read replicas, and self-hosted Postgres (~$180K/yr infra)** |
| Biggest financial risk? | **Cloud AI costs if on-device STT fails** |
| Biggest legal risk? | **PDPL non-compliance + Yemen sanctions** |
| Biggest technical risk? | **Sync engine complexity (CRDT-lite) for a small team** |
| Recommended first Phase 2 feature? | **Cloud backup sync (not real-time sync)** — lowest risk, highest user value |
| Break-even user count? | **~85K total users (after optimization)** |

### Recommended Pricing Revision

| Tier | Price | Positioning |
|---|---|---|
| **Free** | $0 | 1 ledger, 50 contacts, 500 txns |
| **Pro** | **$24/yr ($2/mo)** | Unlimited everything, cloud backup, CSV import, 10 AI/day |
| **Pro+** | **$59/yr ($5/mo)** | Multi-device sync, WhatsApp automation, 50 AI/day, analytics, portal |

This raises blended ARPU by ~35% and moves break-even from 85K to ~65K users while remaining affordable for MENA merchants (equivalent to ~2 cups of coffee per month).
