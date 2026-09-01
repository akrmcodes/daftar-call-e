---
trigger: always_on
description: Core project identity, architecture law, tech stack mandates, and money handling rules. Loaded on every interaction.
globs:
alwaysApply: true
---

# Daftar (دفتر) — Project Foundation

<context>
Daftar is an offline-first Flutter application that replaces paper ledgers (كشكول) used by grocery shop owners and local merchants in Yemen and the MENA region. It digitizes debt tracking with multi-currency support, WhatsApp PDF statements, credit limit warnings, and encrypted backup/restore.
</context>

<strategic_invariants>
These principles override ALL other considerations. Violating any of these is a critical defect:

1. OFFLINE-FIRST — Every feature MUST function with zero internet connectivity. Network is a luxury, never a requirement.
2. ONE-HANDED, SUB-SECOND UX — Every core action (add debt, record payment) achievable in ≤ 3 taps. All primary actions within the bottom 60% of the screen.
3. ARABIC-FIRST RTL — Arabic is the default locale and the primary design target. RTL is not an afterthought.
4. FINANCIAL-GRADE DATA INTEGRITY — Integer-only money, ACID transactions, audit logging, soft deletes. Zero tolerance for rounding errors, silent data loss, or inconsistent balances.
5. KHAZNA v3 LAPIS LUX UI — Monochrome canvas (Onyx/Bone) + semantic debt/payment colors only. Lapis (#0356C5) is LIGHT ONLY (glows + borders), NEVER fill. See `docs/design_system.md`.
</strategic_invariants>

<khazna_v3_lapis_lux>
Design system codename: Khazna v3 — Lapis Lux. Canonical: docs/design_system.md.

THE LAPIS LAW (CRITICAL DEFECT IF VIOLATED):
  Lapis is light, not paint.

NEVER use AppColors.lapis400 / lapis500 as backgroundColor, fill, or gradient on:
  Card, Button, FAB, Chip, Container, FilledButton, ElevatedButton.

Lapis is EXCLUSIVELY for:
  - AppGlows box shadows (glowMd, khazaFloat, ctaRest, etc.)
  - 0.5px or 1.5px BorderSide(color: lapis400)
  - Focus rings, 2dp tab/bottom-nav indicator stripes
  - Info banner backgrounds ONLY (lapis800 / lapis50)

Primary CTAs: monochrome fill (surface2 / surface1Light) + lapis border + glowMd halo.
NOT blue rectangles.

BANNED forever in UI: Khazna Gold, teal accent, darkPrimary gold semantics, Material blue FilledButtons.

Theme tokens: app_colors.dart, app_glows.dart, app_text_styles.dart, app_motion.dart, HapticService.
Primitives: DaftarButton, DaftarCard, DaftarTextField in lib/presentation/shared/widgets/.
</khazna_v3_lapis_lux>

<platforms>
- Android: Min API 26 (Android 8.0). Primary platform.
- iOS: Min deployment target 15.0. Secondary platform.
</platforms>

## Architecture Law — Clean Architecture (4 Layers)

<dependency_rule>
Presentation → Application → Domain ← Data

The arrow means "depends on." No layer may depend on a layer above it. The Domain layer depends on NOTHING.

- Domain: ZERO external package imports. Pure Dart only. Permitted: dart:core, equatable, freezed_annotation, fpdart.
- Application: May import domain/ only. Contains use cases. Never import Flutter, Drift, or Presentation.
- Data: Implements domain interfaces. May import domain/ (interfaces only). Never import Presentation or Application.
- Presentation: May import domain/ and application/. Never import Drift, data sources, or data models directly.

CRITICAL: Providers call Use Cases — NEVER call repositories directly.
</dependency_rule>

<directory_layout>
lib/
├── main.dart, bootstrap.dart
├── app/ — app.dart, router/, theme/
├── core/ — constants/, errors/, extensions/, utils/, l10n/
├── domain/ — entities/, enums/, repositories/, value_objects/
├── application/ — ledger/, contact/, transaction/, backup/, import/
├── data/ — models/, mappers/, datasources/local/, datasources/remote/, repositories/
└── presentation/ — providers/, screens/{feature}/, shared/widgets/, shared/animations/
</directory_layout>

## Mandatory Tech Stack

<approved_technologies>
| Layer | Technology |
|---|---|
| Language | Dart 3.x (null-safety enforced) |
| Framework | Flutter 3.x |
| State Management | Riverpod 2.x + riverpod_generator |
| Local Database | Drift (SQLite) |
| Routing | go_router |
| Entities | Freezed + freezed_annotation |
| Functional Types | fpdart |
| Networking | Dio + Retrofit + retrofit_generator |
| Local Auth | local_auth |
| Secure Storage | flutter_secure_storage |
| PDF Generation | pdf (dart package) |
| Localization | ARB files + slang |
| Notifications | flutter_local_notifications |
| Cloud Storage | Supabase (Storage + Auth) |
| Analytics | Firebase Analytics + Crashlytics |
</approved_technologies>

<banned_technologies>
PERMANENTLY BANNED — Never suggest, import, or reference:
- State: Bloc, Provider, GetX, MobX, Cubit → Use Riverpod only
- Database: Isar, Hive, Floor, sqflite, SharedPreferences (for domain data), ObjectBox → Use Drift only
- DI: get_it, injectable, kiwi → Riverpod IS the DI container
- Routing: auto_route, Navigator 1.0 pushes → Use go_router only
- Functional: dartz → Use fpdart
- Networking: http package directly → Use Dio + Retrofit
- Money types: double, num, Decimal for monetary values → Use int only
</banned_technologies>

## Money Handling — NON-NEGOTIABLE

<money_rules>
ALL monetary amounts are stored as int — the smallest unit of the currency.
  - 1500 = 15.00 YER (2 decimal places)
  - 350  = 3.50 SAR  (2 decimal places)
  - 100  = 1.00 USD  (2 decimal places)

NEVER use double, num, or Decimal for any monetary value.
NEVER store money as a String.
NEVER perform arithmetic on display-formatted values.

Use the Money value object from lib/domain/value_objects/money.dart for all monetary operations.
Display conversion uses Currency.decimalPlaces to convert int → formatted display string.
Cross-currency operations are FORBIDDEN — no auto-conversion. Each currency maintains a separate balance.
</money_rules>

## File & Naming Conventions

<naming>
| Element | Convention | Example |
|---|---|---|
| Files | snake_case.dart | create_ledger_use_case.dart |
| Classes | PascalCase | CreateLedgerUseCase |
| Variables/Functions | camelCase | contactBalance |
| Constants | camelCase | maxFreeContacts (NOT SCREAMING_CASE) |
| Private members | _prefix | _repository |
| Providers | {name}Provider (auto-generated) | ledgersProvider |
| Drift tables | Plural PascalCase | Ledgers, Contacts |
| Enums | PascalCase type, camelCase values | LedgerType.customers |
| Test files | {source_file}_test.dart | money_test.dart |
</naming>

<imports>
- Always use absolute imports: import 'package:daftar/domain/entities/ledger.dart';
- Never use relative imports.
- No barrel files. Import the specific file you need.
- Import ordering: (1) dart: (2) package:flutter/ (3) package: third-party (4) package:daftar/
- Separate each group with a blank line.
</imports>

## Schema Design Principles

<schema_rules>
Every Drift table and domain entity must follow:
1. Integer Money — All monetary amounts as int in smallest currency unit
2. UUID Primary Keys — UUID v4 for all PKs, no auto-increment (offline-safe)
3. Soft Deletes — isDeleted flag on all entities. Never hard-delete in normal flow
4. Sync-Ready — syncVersion, updatedAt on all mutable entities
5. Denormalized Balances — ContactBalance table updated atomically with every transaction write
6. Audit Logging — Every CREATE/UPDATE/DELETE appends to AuditLog table
7. Atomic Writes — Multi-table mutations wrapped in Drift transaction()
8. Indexed Queries — Every filterable/sortable column has an explicit Drift index
9. Timestamps — createdAt and updatedAt on every entity, UTC DateTime
</schema_rules>

## Generated Files

<codegen>
- *.g.dart, *.freezed.dart files are in .gitignore. Never manually edit them.
- Regenerate with: dart run build_runner build --delete-conflicting-outputs
- After modifying any annotated class (Drift, Freezed, Riverpod), run build_runner.
- After any code change, run: flutter analyze — zero warnings required.
</codegen>
