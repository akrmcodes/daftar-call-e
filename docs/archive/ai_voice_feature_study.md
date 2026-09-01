> **Archived — not binding for All Things Agentic (Submission Period 3–31 Aug 2026).**
> Contest execution contract: `docs/roadmap_v2.md`.
> Original date retained for historical accuracy.

# Daftar — AI Voice Input Feature Study (v2.0)

> **Version:** 2.0 · **Date:** 2026-08-06 · **Supersedes:** the Stage 18 sections of `daftar_phase2_financial_study.md` (2026-05) and the AI model research embedded in roadmap v3.0 §§B–D (verified 2026-06-06).
>
> **Status:** Adopted. Roadmap v3.6 (Stage 18 + Financial Strategy §§B–D) is the operational distillation of this study.
>
> **Method:** Every price and capability claim below was re-verified against primary sources on **2026-08-06** (links in §10). Costs are computed for Daftar's actual workload (short Arabic voice commands, avg 8 s, hard 600/month cap), not for generic transcription hours.

---

## 1. Executive Summary

**Decision: retire the five-step on-device-first cascade. Ship a single-call architecture — the audio clip goes to one hardened Edge Function, Gemini 3.1 Flash-Lite returns a transcript plus schema-locked JSON in one metered call, deterministic validators cross-check it, and an editable Confirm Card is the only path to the ledger.**

| Question | Answer |
|---|---|
| Best value/performance model (Aug 2026) | **Gemini 3.1 Flash-Lite** — the only frontier-priced model that does Arabic STT + NLP + normalization in one call with schema-enforced JSON, at ~$0.0003–0.0005 per command |
| Worst-case cost per maxed Pro+ user | **≤ $3.60/yr** (zero caching, 600 cmds/mo) — ≤ 7.7% of Pro+ net revenue; expected ≈ $2.20/yr; realistic usage < $0.60/yr |
| Fleet ceiling at 100K users | **≈ $8K/yr** if every entitled user maxes every cap (never happens); realistic ≈ $1K/yr. Frozen-era estimate for uncapped usage was $104K/yr |
| Failure surfaces | 8 (old cascade) → **4** (mic → upload → parse call → validation/confirm) |
| On-device inference | **Rejected on physics** — Gemma 4 E4B needs ~5 GB RAM vs. Samsung A03-class target hardware (2–4 GB total); recorded as explicit non-goal with falsifiable revisit criteria (§8) |
| "Near-zero error rate" | Engineered at the **commit boundary**, not assumed from WER: schema-constrained decoding + deterministic amount/polarity cross-checks + local contact resolution + mandatory editable Confirm Card + a golden-set CI gate (polarity 100%, amount ≥ 98%) that must pass **before** GA |
| Offline-first | **Voice Outbox** — capture works fully offline, clips queue encrypted, parse on reconnect, user confirms then. Manual Quick-Add remains the always-offline entry path |

---

## 2. Scope, Constraints & Workload

Fixed product decisions (out of scope for this study — inherited from roadmap v3.0–v3.5 and Stage 5/16):

- Quotas: Pro+ **600 commands/month**; trial Free **15 lifetime** / Pro **60/month**; Stage 16 banked referral credits redeem here (FIFO, idempotent, no expiry before launch).
- Semantic contract: `عليه` ⇒ DEBT, `له` ⇒ PAYMENT; Arabic-Indic digits **٠١٢٣٤٥٦٧٨٩** and spelled-out numbers (خمس مئة = 500); optional currency; one or more items; contact resolution with duplicate/missing flows; archived-ledger contacts excluded (§6.7 invariant).
- UX: Voice FAB under the Lapis Law; success via Stage 9.6 Delight System; money never auto-commits.
- Security: Stage 8 Edge-proxy pattern, `ai_usage_counters`, §14.3 secrets procedure, §H prompt-injection mandate.

Engineering constraints that the previous study ignored:

| Constraint | Value | Source |
|---|---|---|
| Target hardware floor | Samsung A03-class: 2–4 GB RAM, entry Unisoc/Helio SoC | Stage 17.1 |
| App memory budget | **< 150 MB steady state** | Stage 17.4 / pricing matrix |
| APK budget | **< 30 MB per ABI** | Stage 17.5 |
| Network reality | Yemen: 2G/3G common, metered data, GB-class downloads hostile | Market context; §11 B2C design |
| Workload shape | Short commands: avg ~8 s, hard max 30 s; ≤ 600/mo/user | §D cap |
| Cold start | < 2 s | Stage 17.5 |

---

## 3. Why the Previous Study Is Retired (Gap Analysis)

The v3.0 study (roadmap §§B–D, verified 2026-06-06) selected: on-device **Gemma 4 E4B / Whisper.cpp** primary STT → **Soniox** cloud STT fallback → **regex-first** parser → on-device **Gemma 4** NLP → **Gemini 3.1 Flash-Lite** cloud NLP fallback. Seven defects, in order of severity:

1. **Hardware impossibility.** Gemma 4 E4B is a 2.5 GB mobile download requiring ~5 GB RAM at Q4 (~8 GB at Q8). The declared target device has 2–4 GB RAM *total*. Even Gemma 4 E2B (1.1 GB download, ~1.5–2 GB inference RAM) cannot coexist with the app's own **< 150 MB** steady-state budget. The primary path of the old plan could not run on the hardware the same roadmap optimizes for in Stage 17.
2. **Distribution blindness.** A 1.1–2.5 GB model download on metered Yemeni internet, next to a < 30 MB APK discipline, plus a model update/corruption/storage subsystem that the plan never budgeted.
3. **No Arabic evidence for the on-device anchor.** Google's own Gemma 4 audio evaluations (CoVoST S2TT, FLEURS ASR) cover en/ja/de/fr/es/it/ru/zh — **no Arabic at all**, let alone Yemeni dialect. whisper.cpp tiny/base/small are MSA-biased with dialect WER > 40%. The "on-device = $0 and private" tier had zero published evidence it could read a Yemeni merchant's speech.
4. **Complexity mispriced.** Five inference paths = 8 failure surfaces, each needing tests, telemetry, and lifecycle code — to save at most ~$2/user/yr against a cloud ceiling the 600/mo cap had *already* collapsed to a rounding error (§D). The study optimized the solved problem (cost) and spent the scarce ones (quality, simplicity, schedule).
5. **Dual quota semantics.** Only cascade steps [2] and [5] consumed quota, so identical user actions sometimes cost a credit and sometimes didn't — unpredictable UX, untestable billing, and an abuse surface (force-degrade to free paths).
6. **Incoherent degradation.** Offline + low on-device confidence ⇒ dead end (no transcript, no fallback); "over-cap ⇒ manual entry with transcript pre-filled" assumed a transcript that offline-over-cap paths could not produce. The privacy pitch ("on-device, private") also conceded that hard cases — the ones that matter — went to cloud anyway.
7. **No acceptance metric.** "Flawlessly parsed" was aspirational: no golden set, no per-field thresholds, no latency budget, no definition of *flawless*. Nothing gated GA.

**What the old plan got right (preserved verbatim):** the semantic contract table and عليه/له rule; the 600/40-day caps and banked-credit design; the Edge-proxy + server-side-secrets discipline; prompt-injection posture (§H); Lapis Law FAB + Delight System; archived-contact exclusion.

---

## 4. Market Scan — August 2026 (verified 2026-08-06)

### 4.1 Single-call multimodal (audio → structured JSON in one request)

| Model | Price (Aug 2026) | Effective per 8 s command | Arabic evidence | Verdict |
|---|---|---|---|---|
| **Gemini 3.1 Flash-Lite** | in $0.25/1M text · **$0.50/1M audio** (25 tok/s) · out $1.50/1M · cache $0.025–0.05/1M · Batch −50% | **~$0.0003–0.0005** | Language-general multimodal, strong Arabic family competence; dialect quality must pass §7 golden-set gate | ✅ **PRIMARY** |
| Gemini 3.5 Flash | $1.50/1M in · $9.00/1M out | ~$0.002–0.003 | Better reasoning — unneeded for a 10-field extraction | ❌ 6× price, no benefit |
| OpenAI GPT-4o-mini audio path | transcribe $0.003/min + text parse | ~$0.0005 (two calls) | Whisper-class multilingual | Vendor-diversity fallback |
| Voxtral Small (Mistral) | $0.004/min audio + $0.10/$0.40 per 1M text | ~$0.0006 | **13 languages, Arabic absent; zero Arabic output in 2026 Gulf production test** | ❌ no Arabic |

### 4.2 STT-only (requires a second NLP call — "two-call" architectures)

| Provider | Price | Arabic-dialect evidence (2026) | Verdict |
|---|---|---|---|
| **Soniox async** | **$0.10/hr** ($1.50/1M audio tok + $3.50/1M text tok) | Best measured WER (**16.2%**) in the 2026 Gulf-Arabic production benchmark (voicearabic.com); 60+ languages | ✅ **Contingency of record** |
| OpenAI gpt-4o-mini-transcribe | $0.18/hr ($0.003/min) | Multilingual generalist; logprobs confidence available | Third option |
| Deepgram Nova-3 multilingual | $0.55/hr batch / $0.35/hr streaming | Excellent Gulf Arabic; fastest EOU (424 ms) — optimized for live agents, irrelevant to a confirm-card flow | ❌ 5× Soniox for our shape |
| Munsit-1/2 (CNTXT AI, UAE) | from $8–10/mo for ~100 STT min (≈ $4.8–6.0/hr effective) | **#1 on the Open Universal Arabic ASR Leaderboard** (avg WER ≈ 26.7% across SADA/Common Voice/MASC/Casablanca/MGB-2 vs Whisper ≈ 36.9%); 25+ dialects; sovereign/on-prem PDPL deployments | ❌ subscription floor + ~50× unit cost at our micro-volume; **revisit on any sovereign-deployment mandate** |
| ElevenLabs Scribe v2 | ~$0.22–0.40/hr | Arabic WER ≈ 32% (leaderboard); "not viable" in Gulf production test | ❌ |
| Groq Whisper large-v3 / turbo | $0.111 / $0.04 per hr | Cheapest raw STT; poor + inconsistent Arabic dialect output | ❌ |
| Google Chirp 3 (STT v2) | ~$0.96/hr | Excellent, broadest dialect coverage (incl. `ar-YE` locale) | ❌ 10× Soniox |
| Azure Speech | ~$1.00/hr | Arabic WER ≈ 41% (leaderboard) | ❌ |
| AssemblyAI | ~$0.21/hr | Universal-2 has Arabic; Universal-3 Pro dropped it | ❌ direction of travel |

### 4.3 On-device

| Option | Footprint | Arabic evidence | Verdict |
|---|---|---|---|
| Gemma 4 E4B (audio) | 2.5 GB mobile download · ~5 GB RAM (Q4) | None published (audio evals exclude Arabic) | ❌ exceeds target hardware outright |
| Gemma 4 E2B (audio) | 1.1 GB mobile download · ~1.5–2 GB RAM | None published | ❌ RAM + download + Stage 17 budgets |
| whisper.cpp tiny→small | 75–466 MB, CPU-heavy on A03 | MSA-biased; dialect WER > 40% | ❌ quality floor too low |
| Android system `SpeechRecognizer` | 0 MB (system service) | Device/vendor-dependent, no confidence contract, inconsistent Arabic packs | ❌ adds variance, not reliability |

**Reading of the evidence:** frontier Arabic *dialect* ASR still sits at ~16–27% WER on hard benchmarks in 2026. No model — cloud or local — delivers "near-zero" raw transcription error on dialectal speech. Therefore accuracy must be manufactured downstream of the model (§7), and the model choice should optimize **price, integration simplicity, and structured-output reliability** — which is precisely the single-call multimodal column.

---

## 5. Architecture Decision — One Call, One Confirm

### 5.1 Compared architectures

| | v3.0 cascade (retired) | **Single-call (adopted)** | Two-call (contingency) |
|---|---|---|---|
| Components | 5 inference paths + model lifecycle mgmt | 1 cloud call + deterministic validators | 2 cloud calls + validators |
| Failure surfaces | 8 | **4** | 5 |
| Quota semantics | Dual (steps 2/5 only) — unpredictable | **1 command = 1 unit** | 1 command = 1 unit |
| Marginal cost / command | "$0" claimed; real cost = quality + GB downloads + dead ends | ~$0.0003–0.0005 | ~$0.0003 |
| Worst-case $/user/yr | ~$3.04 (its own §D math) plus unpriced R&D | **≤ $3.60 (ceiling), ~$2.20 expected** | ~$2.60 |
| Latency (8 s clip, 3G) | 10 s+ on-device prefill on A03, thermal throttling | **~2–3 s p50** (upload ~25 KB + 1 call) | ~3–4 s p50 |
| Offline | Claimed, incoherent | Honest: Outbox capture, parse on reconnect | Same |
| APK / RAM impact | +GBs download, RAM blowout | **±0 (recorder only)** | ±0 |

The two-call pipeline is kept **pre-wired but unbuilt**: the Edge Function's provider adapter (`parse(audio, schema) → {transcript, entry, usage}`) can be flipped server-side from Gemini to Soniox+Flash-Lite-text with no app update. It is the escape hatch if the golden-set gate exposes a dialect weakness in Gemini's audio path that prompt iteration cannot fix.

### 5.2 The adopted pipeline

```
Capture (16 kHz mono Opus, ≤ 30 s, ~25 KB per 8 s)
   │ offline ──▶ Voice Outbox (encrypted local queue → auto-parse on reconnect)
   ▼ online
Edge Function `ai-voice-parse`      ← the ONLY AI endpoint; 1 call = 1 quota unit
   ├─ sync JWT · tier · quota · banked-credit FIFO (atomic, idempotent by command UUID)
   ├─ Gemini 3.1 Flash-Lite REST: inline base64 audio + fixed system prompt
   │  responseSchema (strict JSON) · temperature 0 · thinking 0 · paid tier only
   └─ telemetry row (audio s, tokens, cost µ$, outcome) — audio NEVER persisted
   ▼
Deterministic post-validation
   ├─ schema clamp: type ∈ {debt,payment} · int amount > 0 · currency ∈ ledger set
   ├─ Arabic number cross-parser re-derives amount from transcript (٠–٩, 0–9, spelled-out)
   ├─ polarity keyword guard: عليه/له must corroborate entry_type
   └─ contact resolution 100% LOCAL (normalized fuzzy match; duplicate → chooser;
      missing → create flow; archived ledgers excluded)
   ▼
Editable Confirm Card (mismatches pre-flagged) ──▶ Commit ──▶ Delight (§9.6)
```

### 5.3 Response schema (locked)

```json
{
  "transcript":       "string  — verbatim Arabic transcript",
  "entry_type":       "enum: debt | payment",
  "contact_name":     "string  — as spoken, no expansion",
  "amount":           "integer — major currency units exactly as spoken",
  "currency_hint":    "string | null — only if explicitly spoken",
  "items":            ["string"],
  "note":             "string | null",
  "ambiguous_fields": ["enum: entry_type | contact | amount | currency"]
}
```

Integer-money invariant: the model returns the **major-unit integer as spoken**; the client converts to minor units via the ledger currency's `decimalPlaces` before constructing `Money`. Spoken fractions (نص ريال) ⇒ `amount` flagged ambiguous — never rounded silently.

### 5.4 Why Gemini 3.1 Flash-Lite specifically

1. **One call replaces the entire cascade** — STT, dialect handling, Arabic-Indic digit and spelled-number normalization, entity extraction, and JSON shaping in a single request; every removed hop removes a failure mode and a latency term.
2. **Schema-enforced output** (`responseSchema`, enum/integer/required supported) — malformed JSON is impossible by construction, closing the largest LLM failure class before validation even runs.
3. **Cheapest structured audio→JSON on the market**: raw audio ingestion ≈ $0.045/hr-equivalent ($0.50/1M tok at 25 tok/s) — below even Soniox — and output tokens are bounded by the schema.
4. **Operationally boring:** plain REST from Deno Edge Functions (clip sent inline; < 20 MB request limit vs our ≤ ~100 KB), implicit/explicit caching for the fixed prompt, Batch tier (−50%) available for Outbox drains.
5. **Governable privacy:** paid tier is contractually not used for training (free tier is — **banned**); no audio retained server-side; the clip is the only user data that ever leaves the device.

---

## 6. Cost Model (Daftar workload, verified prices)

Per command (8 s average clip, fixed prompt budgeted at ≤ 800 tokens, ~120 output tokens):

| Line | Math | Cost |
|---|---|---|
| Audio in | 8 s × 25 tok/s = 200 tok × $0.50/1M | $0.000100 |
| Prompt | ≤ 800 tok — cached $0.025/1M ↔ uncached $0.25/1M | $0.000020–0.000200 |
| Output (transcript + JSON) | ~120 tok × $1.50/1M | $0.000180 |
| **Total per command** | | **$0.00030–0.00048 → planning rate $0.0005** |

Per user per year:

| Scenario | Commands | Cost/yr | % of Pro+ net ($46.99) |
|---|---|---|---|
| Pro+ maxed, zero cache hits (7,200 × $0.0005 planning rate) | 7,200 | **$3.60** | 7.7% |
| Pro+ maxed, normal caching | 7,200 | ~$2.20 | 4.7% |
| Pro+ realistic (~25% of cap) | ~1,800 | **< $0.60** | 1.2% |
| Pro trial maxed | 720 | ~$0.36 | — |
| Free lifetime trial | 15 total | ~$0.008 one-time | — |

Fleet at 100K users (1,500 Pro+ · 5,000 Pro · rest Free):

| Scenario | Annual cost |
|---|---|
| Everyone maxes every cap simultaneously (impossible) | ≈ **$8K** ($5.4K Pro+ + $1.8K Pro + Free trickle) |
| Realistic utilization | ≈ **$1K** |
| Frozen-era estimate (uncapped, for contrast) | $104K |

Enforced ceilings (roadmap §G): 600/mo hard cap · ≤ 40 commands/day · **≤ 90 audio-min/month** (new — bounds the token ceiling independent of command count) · ≤ 30 s/clip · org-wide monthly budget breaker (default **$250/mo** ≈ 3× realistic fleet cost) that auto-pauses voice with a status banner while manual entry continues untouched.

---

## 7. Error Containment — how "near-zero" is actually achieved

Raw dialect WER (16–27% at the 2026 frontier) makes "flawless transcription" an unprofessional promise. The engineering target is instead **near-zero *committed* errors** — a wrong number or polarity reaching the ledger — achieved by five independent layers:

1. **Constrained decoding** — `responseSchema` + temperature 0 + thinking 0: output is always well-formed, typed, and enum-bound. A hallucinated field name or free-text amount is structurally impossible.
2. **Deterministic cross-validation** — `arabic_number_parser.dart` (pure Dart, ≥ 100-case unit table) independently re-derives the amount from the returned transcript (Arabic-Indic ٠–٩, Western digits, spelled-out numbers and compounds: خمسمية، ألف وميتين وخمسين); the عليه/له keyword guard corroborates polarity. Any disagreement flags the field — a silent wrong value requires the model *and* the independent parser to make the *same* mistake.
3. **Local entity resolution** — contact matching runs on-device against the Drift store with the existing Arabic normalization (Alef/Taa/diacritics). No auto-create, no auto-pick on ambiguity, archived contacts excluded.
4. **Human confirm boundary** — the editable Confirm Card is mandatory; flagged fields arrive pre-highlighted. Money never auto-commits (existing invariant, now load-bearing).
5. **Measured, gated accuracy** — a ≥ 150-clip Yemeni/Saudi golden set (canonical 4 phrases + digits/spelled/compound/multi-item/noise/hesitation variants) replayed in CI against the staging Edge Function. **GA thresholds: polarity 100% · amount exact ≥ 98% · contact top-1 ≥ 95% · commit-ready-with-zero-edits ≥ 90% · flagged-or-correct ≥ 99.5%.** Post-launch, the Confirm Card **field-edit rate** is the live accuracy metric and regression alarm.

---

## 8. Risks, Mitigations & Revisit Triggers

| Risk | Mitigation |
|---|---|
| Gemini underperforms on Yemeni dialect | Golden-set gate blocks GA; prompt/schema iteration first; adapter flip to Soniox+Flash-Lite text (server-side, no app update) second |
| Google reprices or deprecates Flash-Lite (2.0-era precedent) | Provider adapter + documented OpenAI third option; prices re-verified each release; org budget breaker caps blast radius at ~$250/mo |
| PDPL / data-residency mandate hardens | Vertex regional endpoints (+10% list) as drop-in; Munsit sovereign/on-prem as the Arabic-specialist alternative — both recorded, neither needed at launch |
| Provider outage | Structured `provider-down` failure → retry-later + manual entry; Outbox clips wait; no data loss |
| Quota abuse (long clips, replay, farming) | 30 s clip cap, 90 audio-min/mo, 40/day, per-user+device+IP rate buckets (§8.7), idempotent command UUIDs, server-authoritative counters |
| Prompt injection via spoken content | Fixed system prompt; transcript is data; schema-bound output; no tool access; red-team phrases in the golden set |

**On-device revisit criteria (falsifiable, all three required):** a model ≤ 500 MB download demonstrates ≤ 15% WER on *our* golden set, inferring in ≤ 3 s on Samsung A03-class hardware within a ≤ 300 MB peak-RAM envelope. Until then, on-device inference is an explicit non-goal — re-evaluate at most once per year or when such a model is credibly announced.

---

## 9. What Changes in the Docs

- **Roadmap v3.6:** §§B–D rewritten (this study distilled); §F worst-case margin updated (voice $3.60 ceiling → Pro+ worst-case 82.2%, realistic ~94.7%); §G gains the audio-minutes ceiling and loses "degrade to on-device/regex"; §H data-minimization line rewritten; Stage 18 rebuilt around the single-call architecture with the golden-set harness as §18.1; appendix/Stage 14/Stage 19 cross-references updated.
- **Pricing matrix v2.1:** "AI FROZEN" rows replaced by the capped Stage 18 quotas (they contradicted roadmap v3.0+ since June); Pro+ unit economics gain the AI line; closing rationale updated.

---

## 10. References (all accessed 2026-08-06)

1. Gemini API pricing (3.1 Flash-Lite: $0.25/$0.50 audio/$1.50; caching; Batch; 25 tok/s audio; free-tier training disclosure) — https://ai.google.dev/gemini-api/docs/pricing
2. Gemini structured outputs (JSON Schema types, `response_format`) — https://ai.google.dev/gemini-api/docs/structured-output
3. Gemini audio understanding (inline audio ≤ 20 MB request, formats) — https://ai.google.dev/gemini-api/docs/generate-content/audio
4. Vertex AI Gemini pricing (regional/non-global +10%) — https://cloud.google.com/gemini-enterprise-agent-platform/generative-ai/pricing
5. Soniox pricing ($0.10/hr async, token model) — https://soniox.com/pricing
6. 2026 Gulf-Arabic production STT benchmark (Deepgram 424 ms EOU; Soniox 16.2% WER; Scribe/Groq/Voxtral failures) — https://voicearabic.com/en/guides/best-arabic-stt-api-2026
7. Munsit / Open Universal Arabic ASR Leaderboard standings + pricing — https://munsit.com/pricing · https://munsit.com/blog/arabic-speech-to-text-api
8. Mistral Voxtral pricing + 13-language scope — https://mistral.ai/pricing/api/ · https://docs.mistral.ai/studio-api/audio/overview
9. OpenAI transcription models + pricing ($0.003/min mini) — https://developers.openai.com/api/reference/resources/audio/subresources/transcriptions/methods/create · https://costgoat.com/pricing/openai-transcription
10. Deepgram Nova-3 pricing — https://deepgram.com/pricing
11. Gemma 4 model sizes (E2B 1.1 GB / E4B 2.5 GB mobile; RAM classes) + model card (audio on E2B/E4B/12B, 30 s max) + technical report (audio evals: no Arabic) — https://ai.google.dev/gemma/docs/core · https://ai.google.dev/gemma/docs/core/model_card_4 · https://arxiv.org/html/2607.02770
12. Supabase Edge Functions limits (256 MB memory; request size; wall clock) — https://supabase.com/docs/guides/functions/limits
