# Product roadmap (deferred)

> **Not judging.** Product Phase 2 — deferred until after All Things Agentic submit (Submission Period 3–31 Aug 2026).  
> **Binding execution contract now:** [`docs/roadmap_v2.md`](../roadmap_v2.md) — Daftar Closing Agent (Taskmaster).

## What this file used to be

The full product Phase 1–2 execution plan (v3.6, Stages 0–19: multi-device sync, onboarding Delight, viral, RevenueCat, AI Voice Stage 18, enterprise handoff, etc.) lived here. It is **archived**, not deleted:

- **Archive:** [`docs/archive/product_roadmap_phase2_v3.6.md`](../archive/product_roadmap_phase2_v3.6.md)
- **Archive index:** [`docs/archive/README.md`](../archive/README.md)

## Contest vs product Phase 2

| Track | Doc | Binding? |
| --- | --- | --- |
| Closing Agent (contest) | [`roadmap_v2.md`](../roadmap_v2.md) | **Yes** — sole checklist owner |
| Product Phase 2 (Stages 8–19) | Archive v3.6 + this stub | **No** — deferred after contest |

## Deferred after contest submit

Do **not** execute during the Submission Period:

- Multi-device sync / collaboration (already quarantined for contest)
- Viral referral, Shipaton / RevenueCat polish
- Product Stage 18 AI voice as previously studied (Gemini 3.1 cascade) — contest uses Gemini **3.5+** Closing Agent instead
- Enterprise handoff and related Phase 2 mega-stages
- **APK slim (optional):** drop zero-import UI packages if still unused — `lottie`, `motor`, `wolt_modal_sheet`, `slang`, `flutter_slidable`, `custom_refresh_indicator` (and likely `cupertino_icons`). Do **not** remove `supabase_flutter` without a compile-safe `SyncRemoteDs` stub. Do **not** excise `supabase/`, Hybrid E, or `propose_whatsapp_drafts` (frozen catalog).

## Related architecture notes (active, not Phase 2 drivers)

- [`docs/design_system.md`](../design_system.md) — Khazna / Lapis Law (agent UI must comply)
- [`docs/architecture/BACKUP_SPEC.md`](../architecture/BACKUP_SPEC.md) — `.daftar` backup format
- [`docs/architecture/GOOGLE_DRIVE_BACKUP_SPEC.md`](../architecture/GOOGLE_DRIVE_BACKUP_SPEC.md) — **Drive backup** (≠ multi-device sync)
- [`docs/CONTEST_DISCLOSURE.md`](../CONTEST_DISCLOSURE.md) — substrate eligibility
