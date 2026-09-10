# Architecture

## Contest (judges)

| Document | Role |
| --- | --- |
| [`contest_architecture.md`](contest_architecture.md) | CALL-E judge **glance** (TB mermaid first): sibling FastAPI on `daftar-call-e`, plan-batch → run-batch → Developer API create/get, SMTP dual rail, HITL Validate / Create / Poll |
| [`contest_architecture.png`](contest_architecture.png) | Owner export of the TB mermaid for Devpost (overwrite heritage Agentic PNG; do not generate in-agent) |

Judges: start at the root [`README.md`](../../README.md).

## Substrate (not judging)

Backup, Drive, and monetization specs for the disclosed ledger. Not the contest architecture contract.

| Document | Role |
| --- | --- |
| [`BACKUP_SPEC.md`](BACKUP_SPEC.md) | `.daftar` V1 backup format |
| [`GOOGLE_DRIVE_BACKUP_SPEC.md`](GOOGLE_DRIVE_BACKUP_SPEC.md) | Drive `appDataFolder` **backup** — not Stage 8 sync |
| [`MONETIZATION_SPEC.md`](MONETIZATION_SPEC.md) | Tiers / activation |
