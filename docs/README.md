# Documentation

**Hackathon:** [CALL-E: Your Code Is Calling](https://call-e.devpost.com/) · prize aim **Most Practical Use Case**  
**Official deadline:** **14 Sep 2026 23:45 SGT**. Binding: [`roadmap_v3.md`](roadmap_v3.md) **v3.5**. Heritage (do not execute): [`roadmap_v2.md`](roadmap_v2.md) **v2.8**.

Start at the **root [`README.md`](../README.md)**. This folder holds the judging pack plus owner, product, and archive material — use the lists below.

## Judges (start here)

Read in this order:

| Order | Document | What it proves |
| --- | --- | --- |
| 1 | [`README.md`](../README.md) | CALL-E claims, dual rail, Proof of Action (`task_completed` ≠ paid; poll ≠ webhook theater; SMTP `250` ≠ delivered), Singapore residency, Callcentric / Linphone |
| 2 | [`CONTEST_DISCLOSURE.md`](CONTEST_DISCLOSURE.md) | Substrate vs Agentic prior work vs CALL-E-new |
| 3 | [`architecture/contest_architecture.md`](architecture/contest_architecture.md) | Sibling mermaid + PNG + HITL Validate / Create / Poll |
| 4 | [`roadmap_v3.md`](roadmap_v3.md) | Binding v3.5 execution contract |
| 5 | [`qa/flutter_env.template.md`](qa/flutter_env.template.md) | Gitignored `.env` keys — no secrets in git |

Wire contract: [`agent/openapi.yaml`](../agent/openapi.yaml) · deploy: [`agent/scripts/deploy_daftar_call_e.sh`](../agent/scripts/deploy_daftar_call_e.sh) (never `adk deploy`). Skill dry-run: [`skills/ledger-collections-call/`](skills/ledger-collections-call/).

## Owner / submit

Not required for a first-pass score.

| Document | Role |
| --- | --- |
| [`roadmap_v3.md`](roadmap_v3.md) **v3.5** | **Binding** CALL-E contract |
| [`roadmap_v2.md`](roadmap_v2.md) **v2.8** | Frozen All Things Agentic heritage — **do not execute** |
| [`qa/calle_live_dial_window.md`](qa/calle_live_dial_window.md) | Film-day arm / disarm on `daftar-call-e` only |
| [`qa/`](qa/) | Pre-film scenarios, env template, rehearsal |
| [`contest/`](contest/) | Orientation plan, freeze snapshot, Stage 0 owner-ops |
| [`contest_demo.md`](contest_demo.md) | **Heritage** Agentic ≤4:00 SMTP bible — not the CALL-E film. Beat sheet is v3.5 §6.3 |

## Product (deferred)

Do **not** execute during the Submission Period.

| Document | Role |
| --- | --- |
| [`product/roadmap.md`](product/roadmap.md) | Phase 2 stub — deferred after submit |
| [`product/pricing-feature-matrix.md`](product/pricing-feature-matrix.md) | Product pricing study |

## Substrate specs

Not the contest architecture or eligibility story. Folder index: [`architecture/README.md`](architecture/README.md).

| Document | Role |
| --- | --- |
| [`design_system.md`](design_system.md) | Khazna UI tokens (substrate + agent UI must comply) |
| [`architecture/BACKUP_SPEC.md`](architecture/BACKUP_SPEC.md) | `.daftar` backup format |
| [`architecture/GOOGLE_DRIVE_BACKUP_SPEC.md`](architecture/GOOGLE_DRIVE_BACKUP_SPEC.md) | Drive **backup**, not multi-device sync |
| [`architecture/MONETIZATION_SPEC.md`](architecture/MONETIZATION_SPEC.md) | Tiers / activation |

## Journal / archive

| Document | Role |
| --- | --- |
| [`project_log.md`](project_log.md) | Append-only engineering journal |
| [`archive/`](archive/) | Historical studies and old roadmaps |
