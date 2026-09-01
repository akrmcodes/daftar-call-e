# Khazna v3 — The Lapis Lux Design System

> **Not judging / substrate.** UI token spec for the ledger and Closing Agent chrome. Judges: start at [`README.md`](../README.md). This is not the contest architecture contract.
>
> **Version:** 3.0 · **Codename:** Khazna · **Palette:** Lapis Lux · **Status:** Canonical
> **Scope:** All visual, motion, interaction, accessibility, and localization specifications for the Daftar Merchant Ledger application (MVP substrate + Closing Agent UI). Product Phase 2 UI work is deferred after contest — see [`docs/product/roadmap.md`](product/roadmap.md).
> **Audience:** Product designers, Flutter engineers, QA, and external review partners.
> **Doctrine:** This document supersedes any contradictory ad-hoc pattern. Every screen, component, and asset in the Daftar codebase MUST resolve to a token, rule, or pattern defined here.

---

## Table of Contents

1. [Philosophy & Identity](#1--philosophy--identity)
2. [Foundations — Color](#2--foundations--color)
3. [Foundations — Typography](#3--foundations--typography)
4. [Foundations — Spacing, Grid & Layout](#4--foundations--spacing-grid--layout)
5. [Foundations — Shape, Surface & Elevation (The Lapis Glow Architecture)](#5--foundations--shape-surface--elevation-the-lapis-glow-architecture)
6. [Iconography](#6--iconography)
7. [Motion & Haptics](#7--motion--haptics)
8. [Component Architecture & States](#8--component-architecture--states)
9. [Forms, Inputs & The Amount Pad](#9--forms-inputs--the-amount-pad)
10. [Data Visualization & Lists](#10--data-visualization--lists)
11. [Feedback — Skeletons, Toasts, Banners, Dialogs](#11--feedback--skeletons-toasts-banners-dialogs)
12. [RTL & Bilingual Adaptation](#12--rtl--bilingual-adaptation)
13. [Accessibility (A11y)](#13--accessibility-a11y)
14. [Edge Cases & Defensive Design](#14--edge-cases--defensive-design)
15. [Microcopy & Voice](#15--microcopy--voice)
16. [Premium / Trust Markers (Glow as Currency)](#16--premium--trust-markers-glow-as-currency)
17. [Quality Gates — Rejection Criteria](#17--quality-gates--rejection-criteria)
18. [Token Reference (Quick Lookup)](#18--token-reference-quick-lookup)

---

## 1 · Philosophy & Identity

### 1.1 Design Language Name — "Khazna · Lapis Lux"

`Khazna` (خزنة) means "the vault" in Arabic — a place that holds value safely. The name encodes the brand promise: a merchant's ledger is sacred capital, and the app is the strongbox.

The palette is called **Lapis Lux** — Latin for "blue light." It is built on one radical constraint: **the entire interface is monochrome — except for two semantic colors and one luminous accent that exists only as light, never as paint**.

### 1.2 The Lapis Lux Doctrine — The Single Constraint That Defines Everything

> **Lapis is light, not paint.**
>
> Every appearance of the brand blue (`#0356C5`) in the system must be a `BoxShadow`, a `Border`, an outline, a focus ring, or a tab-indicator stripe.
> Never a `BackgroundColor`. Never a `Fill`. Never a gradient that touches a content area.

This single rule enforces the entire aesthetic. It produces banking authority instead of crypto-gaming. It gives premium-tier markers a place to live (intensified glow). It lets the semantic red/green become the only competing chroma on screen — so the merchant's actual data becomes the brightest object visible.

### 1.3 Four Core Principles

> **Every design decision is judged against these four. A violation of any one is a defect.**

1. **تَحقِيق · Tahqīq — Trust through Clarity.**
   A ledger entry must be impossible to misread. Numerals are tabular. Debt is red, payment is green, no exceptions. Negative space is generous. Hierarchy is unambiguous.

2. **وَقَار · Waqār — Luxury through Restraint.**
   Premium is the absence of noise. One brand color used as light. One canvas (black or bone). Two semantic colors. No gradients on content. No decoration. The palette is closed — additions are contraband.

3. **سَلاسَة · Salāsa — Depth through Light.**
   Cards do not float via shadow on dark — they emit via stepped surface tints + inner top highlights + ambient `glowAmbient`. Light is the depth mechanism, never grey blur.

4. **إِحكَام · Iḥkām — Confidence through Craft.**
   Every pixel is on the 4pt sub-grid. Every tap target ≥ 48dp. Every async state has a skeleton. Every error has a retry. RTL is geometrically perfect. The lapis glow appears exactly where specified — no more, no less.

### 1.4 Aesthetic Reference Coordinates

| Source | What we take | What we reject |
|---|---|---|
| **Stripe Dashboard (dark mode)** | Stepped surface tints, +6 luminance per level | Their indigo brand — too consumer |
| **Mercury / Brex / Ramp** | Monochrome dominance, single accent rarity | Their cream-and-pink warmth — we are colder |
| **Linear** | Information density, keyboard-precision feel, hairline borders | Their faint indigo wallpaper |
| **Bloomberg Terminal** | Amber lives only on data, never on chrome | Their amber chroma — we use lapis instead |
| **Goldman Marcus** | One thin metallic rule per page | Their literal gold — we use lapis as light |
| **Modern OLED finance dark mode** | True `#000000` canvas, luminous CTA glow | Their crypto/gaming overuse of blue as fill |
| **PS5 / luxury hardware UI** | The single-point glowing accent technique | All other chroma; the gaming aesthetic |

### 1.5 The Khazna Mood

| Adjective | YES | NO |
|---|---|---|
| Quiet | Monochrome canvas, single luminous accent | Multi-color palettes |
| Architectural | 8pt grid, hairline borders, rectilinear alignment | Organic blobs, hand-drawn |
| Tactile | Spring sheets, haptic anchors, scale-press, glow breath | Flat un-reactive surfaces |
| Trustworthy | Tabular numerals, exact decimal alignment, ledger metaphors | Playful icons, comic energy |
| Arabic-native | Noto Kufi Arabic primary, RTL-correct geometry | English layouts mirrored as afterthought |
| Luminous | Lapis as glow, never fill | Lapis as background or content color |

---

## 2 · Foundations — Color

### 2.1 The Three Color Citizens

The entire Khazna v3 system is reduced to three citizens that own well-defined territory:

| Citizen | Role | Share of Screen Real Estate |
|---|---|---|
| **Monochrome (Onyx / Bone)** | Canvas, surfaces, text, icons, chrome, dividers, chips | ~95% |
| **Luminous Lapis** `#0356C5` | Glow halos, 0.5px borders, focus rings, 2dp indicator stripes, info banners | ~3% (as light only) |
| **Semantic Red / Green** | Debt amounts, payment amounts, success/error confirmations | ~2% |

Any color outside this triad — including gold, brass, teal, indigo, amber, purple, and all other hues — is **categorically banned**.

### 2.2 Monochrome Scale — Onyx (Dark, Default)

True OLED canvas with surgically tinted elevation steps. Each step is approximately +6 luminance over the previous — the Stripe Dashboard formula — providing depth perception without color shift.

| Token | Hex | Role | Contrast vs `inkPrimary` (#F5F5F5) |
|---|---|---|---|
| `surface0` | `#000000` | Scaffold (true OLED black) | 21:1 |
| `surface1` | `#0A0A0A` | Beneath sheets, primary canvas | 19.4:1 |
| `surface2` | `#121214` | **Card / list tile surface** | 17.8:1 |
| `surface3` | `#18181C` | Raised card, sheet body | 16.2:1 |
| `surface4` | `#1F1F24` | Active row, selected card | 14.6:1 |
| `surface5` | `#26262C` | Input field, chip background | 13.1:1 |
| `surface6` | `#33333A` | Pressed state on surface5 | 10.7:1 |
| `inkPrimary` | `#F5F5F5` | Primary text/icon | — |
| `inkSecondary` | `#A8A8AE` | Secondary text, labels | 7.6:1 |
| `inkMuted` | `#6E6E76` | Timestamps, placeholders | 4.6:1 |
| `inkDisabled` | `#3A3A40` | Disabled text/icon | 2.1:1 (disabled-only) |
| `borderSubtle` | `#26262C` | Hairline dividers (0.5px) | — |
| `borderStrong` | `#3A3A40` | Card outlines | — |
| `scrim` | `rgba(0,0,0,0.78)` | Modal backdrop | — |
| `glassFill` | `rgba(18,18,20,0.62)` | Glass sheet body | — |
| `glassBorder` | `rgba(255,255,255,0.06)` | 0.5px glass edge | — |

**Important nuance:** `surface2` is `#121214` (not `#121212`) — a single-bit blue undertone that primes the eye for the lapis glow without becoming chromatic itself.

### 2.3 Monochrome Scale — Bone Parchment (Light)

Warm off-white evoking the texture of a leather-bound ledger. NOT clinical white. NOT cool grey.

| Token | Hex | Role |
|---|---|---|
| `surface0` | `#F8F7F4` | Scaffold (Bone Parchment) |
| `surface1` | `#FFFFFF` | Card / list tile |
| `surface2` | `#F2F0EC` | Raised card, sheet body |
| `surface3` | `#E8E5DE` | Input field, chip background |
| `surface4` | `#DAD6CB` | Pressed state |
| `inkPrimary` | `#0A0A0C` | Primary text/icon |
| `inkSecondary` | `#5C5C62` | Secondary text |
| `inkMuted` | `#9A9A9F` | Placeholders |
| `inkDisabled` | `#C2C2C7` | Disabled |
| `borderSubtle` | `#E5E2DC` | Hairline (0.5px) |
| `borderStrong` | `#C7C2B6` | Card outlines |
| `scrim` | `rgba(20,18,12,0.52)` | Modal scrim |
| `glassFill` | `rgba(255,255,255,0.72)` | Glass sheet body |
| `glassBorder` | `rgba(0,0,0,0.06)` | Glass edge |

### 2.4 Luminous Lapis — The Soul Token

This is the **single brand color** of the entire system. It comes from the exact gradient `#02060E → #0356C5` — the color of museum lapis lazuli illuminated from within. It is used ONLY as light. Never as paint.

| Token | Hex | Where it MAY appear |
|---|---|---|
| `lapis50` | `#E6EEFB` | (light mode only) ultra-faint container tint behind info banner copy |
| `lapis100` | `#BBD0F4` | (light mode only) premium card subtle wash |
| `lapis200` | `#86A8EA` | Disabled lapis border |
| `lapis300` | `#4A7DDC` | Hover lapis border on light |
| `lapis400` | `#0356C5` | **THE LAPIS** — primary glow, primary CTA border, focus ring |
| `lapis500` | `#0247A8` | Pressed lapis |
| `lapis600` | `#02398A` | Long-form lapis text on light tint |
| `lapis700` | `#022B6B` | — |
| `lapis800` | `#021D4D` | Lapis container fill (info banner background only) |
| `lapis900` | `#02060E` | Abyssal lapis — base color of `glowAmbient` shadow |
| `lapisLumen` (dark only) | `#2D78F0` | Lifted lapis for dark-mode-OLED CTA visibility variant |

#### Where Luminous Lapis MAY be used

1. **CTA glowing border** — primary buttons get a `0.5px lapis400` border + `glowMd` outer halo.
2. **Focus ring** — `1.5px lapis400` ring with `2dp` inset around focused inputs / interactive elements.
3. **Active state indicator** — bottom-nav active tab gets a 2dp top stripe in `lapis400`. Tab underline indicator is 2dp `lapis400`.
4. **Selected state hairline** — selected list items get a `0.5px lapis400` 4dp-tall bar at the `start` edge.
5. **Lock screen / Splash hero glow** — single ambient `glowXl` behind the brand mark.
6. **Premium tier markers** — Pro features inherit `glowSm`, Pro+ features inherit `glowMd` (see §16).
7. **Info banner** — info-variant banners use `lapis800` (dark) / `lapis50` (light) as background, the ONE allowed lapis fill, because info banners are the brand voice speaking directly.
8. **Toast success edge** — successful confirmations get a `glowMd` halo around the toast container.

#### Where Luminous Lapis is CATEGORICALLY FORBIDDEN

- ❌ As a fill color on ANY card, sheet, button, FAB, chip, or content surface (info banners excepted per above)
- ❌ As text color (except inside info banners, ≤ 1 instance per screen)
- ❌ As an icon color outside info banners (icons remain monochrome)
- ❌ As a chart series fill (lapis may be a stroke, never a fill)
- ❌ As a tab indicator background (only as a 2dp stripe)
- ❌ As a gradient across content
- ❌ On more than ONE prominent element per visible screen simultaneously
- ❌ As the colour of monetary amounts (those belong to red/green semantic system only)

### 2.5 Luminous Glow Tokens — The Crown Jewels of Khazna v3

This is where the system's signature visual identity lives. Each glow is a multi-layer shadow that emits soft lapis light around an element. They are **the only place** lapis-colored shadows are used in the system.

| Token | Spec | Use |
|---|---|---|
| `glowXs` | `0 0 4 rgba(3, 86, 197, 0.20)` | Hairline hover hint |
| `glowSm` | `0 0 8 rgba(3, 86, 197, 0.28)` | Premium card resting halo (Pro tier) |
| `glowMd` | `0 0 16 rgba(3, 86, 197, 0.36)` | Primary CTA resting halo; Pro+ tier card |
| `glowLg` | `0 0 24 rgba(3, 86, 197, 0.44)` | Primary CTA pressed / focused |
| `glowXl` | `0 0 48 rgba(3, 86, 197, 0.36)` | Hero brand mark (splash, lock screen, onboarding) |
| `glowAmbient` | `0 8 32 rgba(2, 6, 14, 0.72)` | Deep neumorphic shadow for floating cards (dark mode only) |
| `glowBreath` (animated) | Pulses between `glowSm` and `glowMd` over 2.4s ease-in-out | Awaiting-action state (e.g., onboarding CTA, empty-state CTA) |

#### Glow application contract

The halo is achieved via `BoxShadow` with `blurRadius`, `spreadRadius: 0`, `offset: Offset.zero`, and `color` set to the lapis token at the specified alpha. It is **never** achieved via a `BoxDecoration.gradient`, a stacked `Container`, or an outer `Container` with a tinted background.

### 2.6 Semantic Palette — The Only Other Colors That Exist

The Daftar Semantic Law is unchanged and absolute: **red = debt (money owed TO the merchant)**, **green = payment (money received BY the merchant)**. Both retuned for harmony with the new monochrome canvas.

| Role | Dark | Dark Container | On-Color (Dark) | Light | Light Container | On-Color (Light) | Use |
|---|---|---|---|---|---|---|---|
| **debt** | `#FF5757` | `#2E0E0E` | `#FFEBEB` | `#C8281C` | `#FFEBED` | `#5C0A05` | Debt entries (عليه), errors |
| **payment** | `#4ADE80` | `#0B2E1A` | `#E8FCEF` | `#15803D` | `#E6F7EC` | `#0A3D1E` | Payment entries (له), success |
| **warning** | `#F5A623` | `#2E2410` | `#FFF3DC` | `#B45309` | `#FFF6E5` | `#5C3300` | 80% limits, caution states |
| **info** | `#0356C5` (= lapis400) | `#021D4D` | `#E6EEFB` | `#0247A8` | `#E6EEFB` | `#021D4D` | Informational banners (the brand voice) |
| **success** | `#4ADE80` (= payment) | `#0B2E1A` | `#E8FCEF` | `#15803D` | `#E6F7EC` | `#0A3D1E` | Confirmations |
| **error** | `#FF5757` (= debt) | `#2E0E0E` | `#FFEBEB` | `#C8281C` | `#FFEBED` | `#5C0A05` | Validation, system errors |

#### Tuning notes

- `debt` is brightened to `#FF5757` (from MVP `#EF5350`) for stronger OLED pop against pure black.
- `payment` shifts to `#4ADE80` — modern fintech mint, "P&L positive" coded. Deliberately distinct from any Islamic-flag green association.
- `info` IS the lapis color — the only place lapis appears as fill, and only because info banners ARE the brand voice speaking directly.
- `warning` retained as a controlled amber. Warning is the only "third" color in the system and is used sparingly (limit banners, conflict resolution) — it never appears on CTAs or chrome.

### 2.7 Opacity Tokens

Inline `withOpacity()` calls with arbitrary decimals are **banned**. Use only these named alpha steps:

| Token | Value | Purpose |
|---|---|---|
| `alphaHairline` | `0.04` | Glass edge highlight, inner top card highlight |
| `alphaWhisper` | `0.06` | Subtle surface tints, glass borders |
| `alphaSubtle` | `0.08` | Hover overlays on dark |
| `alphaSoft` | `0.12` | Pressed overlays, container tints |
| `alphaMedium` | `0.24` | Disabled foregrounds |
| `alphaStrong` | `0.48` | Scrims (light mode), shimmer mid-points |
| `alphaScrim` | `0.78` | Modal scrim (dark mode) |
| `alphaOpaque` | `1.00` | Default |

### 2.8 Avatar Color Set

The avatar set is the ONE place desaturated chromatic color is permitted — because human identity is the use case, not money. The 10 colors are intentionally **muted and uniform-saturated** so no single avatar competes with the lapis brand glow or the semantic red/green.

`Indigo #5C6BC0` · `Slate Teal #4A9D94` · `Muted Red #C95757` · `Dusty Purple #8E64A8` · `Steel Blue #5586C2` · `Burnt Amber #C68E4A` · `Sage Green #6FA973` · `Antique Rose #C97091` · `Cocoa Brown #8D6E63` · `Graphite #78909C`

White initials on these backgrounds maintain ≥ 4.5:1 contrast across both themes.

### 2.9 Forbidden Color Patterns

- ❌ Any inline `Color(0xFF…)` in `presentation/`.
- ❌ `withOpacity()` with non-token alpha values.
- ❌ **Lapis as a FILL color anywhere** (info banner background is the sole exemption).
- ❌ Any chromatic color outside lapis, debt-red, payment-green, warning-amber, and the avatar set.
- ❌ Drop shadows in dark mode (use border + inner highlight + `glowAmbient` only).
- ❌ Gold, brass, teal, indigo, amber-yellow, or any past MVP brand color.
- ❌ More than ONE lapis-glow moment per visible screen.
- ❌ Reversing debt/payment color semantics for any reason.
- ❌ Pure `#FFFFFF` text on pure `#000000` (use `inkPrimary` `#F5F5F5` for eye comfort).
- ❌ Gradients on any content surface (the lapis vignette on the Hero Balance Card is the sole exemption — and it is sub-perceptible).

---

## 3 · Foundations — Typography

### 3.1 Type Doctrine

The Daftar typography system is **bilingual by birth**: Arabic and Latin scripts are co-equal citizens. Two font families. Tabular numerals everywhere money lives. Inter for numbers; Noto Kufi Arabic for words.

### 3.2 Font Families

| Family | Source | Used For | Weights Bundled |
|---|---|---|---|
| **Noto Kufi Arabic** | Bundled in `assets/fonts/` | All Arabic UI text — headings, body, labels | 400, 500, 600, 700 |
| **Inter** | Bundled in `assets/fonts/` | All Latin text, **all numerals** (amounts, dates, IDs, phone numbers, PIN) | 400, 500, 600, 700 |
| **Inter — tabular figures** | Same file, `FontFeature.tabularFigures()` | Any column or list of monetary amounts | — |

> **Runtime font downloads are FORBIDDEN.** No `google_fonts` package — it breaks offline-first.

### 3.3 Numeral Rendering — The Tabular Mandate

Every monetary amount, balance, transaction count, percentage, page count, or PIN digit MUST render with tabular figures. This guarantees vertical decimal alignment in lists — the single visual cue that separates "fintech" from "consumer app."

**Implementation contract (Flutter):**

```dart
TextStyle baseAmount = TextStyle(
  fontFamily: 'Inter',
  fontFeatures: const [
    FontFeature.tabularFigures(),  // tnum — equal-width digits
    FontFeature.liningFigures(),   // lnum — uppercase-aligned numerals
  ],
);
```

Currency symbols (`﷼`, official SAR SVG / U+20C1, `$`) inherit the locale-appropriate font or custom glyph asset — NOT Inter for Arabic currency marks.

### 3.4 Type Scale (Full Spec)

All values are in `sp` (scalable pixels) and respect `MediaQuery.textScaleFactor` up to 1.5× without breaking.

#### Arabic Scale (`fontFamily: NotoKufiArabic`)

| Token | Size | Weight | Line Height | Letter Spacing | Use |
|---|---|---|---|---|---|
| `displayLarge` | 34 | 700 | 1.40 | 0 | Hero balance amount (paired with Arabic label) |
| `displayMedium` | 28 | 600 | 1.40 | 0 | Screen titles, onboarding heroes |
| `displaySmall` | 24 | 600 | 1.40 | 0 | Card titles, sheet hero text |
| `headlineLarge` | 22 | 700 | 1.40 | 0 | Section headers |
| `headlineMedium` | 20 | 500 | 1.40 | 0 | List primary text |
| `titleLarge` | 18 | 600 | 1.50 | 0 | Sheet/dialog titles |
| `titleMedium` | 16 | 500 | 1.50 | 0.15 | List item titles |
| `titleSmall` | 14 | 500 | 1.50 | 0.10 | Chip labels, tab labels |
| `bodyLarge` | 16 | 400 | 1.60 | 0.50 | Primary body |
| `bodyMedium` | 14 | 400 | 1.60 | 0.25 | Secondary body |
| `bodySmall` | 12 | 400 | 1.50 | 0.40 | Captions, metadata |
| `labelLarge` | 14 | 600 | 1.50 | 0.10 | Button labels, actions |
| `labelMedium` | 12 | 500 | 1.50 | 0.50 | Small buttons |
| `labelSmall` | 11 | 500 | 1.50 | 0.50 | Overlines, micro-labels |

#### Numeral Scale (`fontFamily: Inter`, tabular)

| Token | Size | Weight | Line Height | Letter Spacing | Use |
|---|---|---|---|---|---|
| `amountHero` | 40 | 700 | 1.15 | -0.8 | Onboarding/empty-state hero amount |
| `amountLarge` | 32 | 700 | 1.20 | -0.5 | Balance card primary amount |
| `amountMedium` | 18 | 600 | 1.30 | 0 | Transaction list amounts |
| `amountSmall` | 14 | 500 | 1.30 | 0 | Chip amounts, inline references |
| `amountMicro` | 12 | 500 | 1.30 | 0.10 | Sub-amounts, "of total" hints |
| `numeralInput` | 28 | 400 | 1.30 | 4 | PIN digits, amount-pad display |
| `numeralCaption` | 11 | 500 | 1.40 | 0.30 | Timestamps, audit IDs |

#### Mixed-Direction Rule

Amounts and numerals ALWAYS render LTR — even inside RTL containers. Wrap inline amounts with `Directionality(textDirection: TextDirection.ltr, ...)`. Phone numbers, dates, and IDs follow the same rule.

### 3.5 Hierarchy Pairing

Hierarchy comes from **size + weight + ink-color step**, never from chromatic decoration. Recommended pairings:

| Context | Primary | Secondary | Tertiary |
|---|---|---|---|
| Balance card | `amountLarge` + `inkPrimary` | `labelMedium` + `inkSecondary` | `numeralCaption` + `inkMuted` |
| Contact list tile | `titleMedium` + `inkPrimary` | `amountSmall` + semantic color (debt/payment) | `bodySmall` + `inkMuted` |
| Transaction row | `titleMedium` + `inkPrimary` | `amountMedium` + semantic color | `numeralCaption` + `inkMuted` |
| Sheet header | `titleLarge` + `inkPrimary` | `bodyMedium` + `inkSecondary` | — |
| Empty state | `headlineLarge` + `inkPrimary` | `bodyMedium` + `inkSecondary` | `labelLarge` + `inkPrimary` (CTA — glow does the brand work, not color) |

> Note the absence of "primary color text" in this table. In Khazna v3, primary text is **always monochrome**. The brand identity lives in the glow around the CTA, not in the text color.

### 3.6 Type Forbidden Patterns

- ❌ Inline `TextStyle(...)` outside `AppTextStyles`.
- ❌ Underline as emphasis (reserved for links inside info banners only).
- ❌ ALL-CAPS Arabic text (Arabic has no case — looks broken).
- ❌ Italic Arabic (Noto Kufi has no italic — never synthesize).
- ❌ Numbers rendered in Noto Kufi Arabic in financial contexts (always Inter tabular).
- ❌ Hardcoded line-height values that diverge from the scale (1.4 / 1.5 / 1.6).
- ❌ Letter-spacing on Arabic text > 0.5 (it shatters word coherence).
- ❌ **Lapis-colored text outside info banners.**

---

## 4 · Foundations — Spacing, Grid & Layout

### 4.1 The 4pt Sub-Grid / 8pt Primary Grid

Daftar uses an **8pt primary grid** with a **4pt sub-grid** for micro-adjustments inside components. Every spacing value must resolve to a multiple of 4.

| Token | Value | Use |
|---|---|---|
| `spacingXxs` | 2 | Icon-to-label inner gap (sub-grid escape hatch) |
| `spacingXs` | 4 | Adjacent same-group elements |
| `spacingSm` | 8 | Related elements within a card |
| `spacingMd` | 12 | List-item internal vertical |
| `spacingLg` | 16 | **Page horizontal/vertical padding, card padding** |
| `spacingXl` | 20 | Bottom sheet content padding |
| `spacingXxl` | 24 | Section gap |
| `spacing3xl` | 32 | Major section gap, hero margins |
| `spacing4xl` | 40 | Empty state vertical rhythm |
| `spacing5xl` | 48 | Onboarding hero spacing |
| `spacing6xl` | 64 | Top hero spacing on splash/onboarding |

### 4.2 Grid & Breakpoints

Daftar is **phone-first** (target devices: Samsung A03, Redmi 9A, iPhone SE). Tablet is supported but treated as a stretched phone layout.

| Breakpoint | Width | Columns | Gutter | Outer Margin |
|---|---|---|---|---|
| **Compact** (phone, default) | < 600 dp | 4 | 16 | 16 |
| **Medium** (large phone, small tablet portrait) | 600–840 dp | 8 | 20 | 24 |
| **Expanded** (tablet landscape) | ≥ 840 dp | 12 | 24 | 32 (max content width 720) |

**Tablet doctrine:** On Medium/Expanded, the content column is capped at 720 dp and centered. Lists become two-pane (master/detail) for ledger → contact. The bottom sheet pattern remains primary — sheets do not transform into side panels.

### 4.3 Density

Two density modes — Comfortable (default) and Compact (opt-in for power users via Settings):

| Element | Comfortable | Compact |
|---|---|---|
| List tile height | 64 | 56 |
| List tile vertical padding | 12 | 8 |
| Section gap | 24 | 16 |
| Card padding | 16 | 12 |

Density does NOT change tap-target minimums — only visual padding. Compact mode retains 48dp invisible hit areas around tap targets.

### 4.4 One-Handed Reachability Zone

All primary actions live within the **bottom 60%** of the screen height.

| Zone | Range | Allowed |
|---|---|---|
| **Glance** | 0–40% | Hero headings, balance summary, timestamps |
| **Content** | 40–60% | Primary list / data |
| **Action** | 60–92% | FABs, primary buttons, sheet actions |
| **System** | 92–100% | Reserved — never place tappable elements here |

### 4.5 Safe Areas

- All screens wrap in `SafeArea`. Sheets escape `SafeArea` only for backdrop blur, never for content.
- The bottom-nav respects gesture insets (≥ 24dp clearance from system bar on Android 12+).
- Floating action buttons sit at `bottom: SafeArea.bottom + 16, end: 16`.

---

## 5 · Foundations — Shape, Surface & Elevation (The Lapis Glow Architecture)

This is the section where Khazna v3's visual identity is most distinctly defined. Read it carefully — most rejections in code review trace back here.

### 5.1 Radius Scale

| Token | Value | Use |
|---|---|---|
| `radiusXs` | 4 | Small chips, tags, micro-badges |
| `radiusSm` | 8 | Buttons, text inputs |
| `radiusMd` | 12 | Cards (default), dialogs |
| `radiusLg` | 16 | Bottom sheets, hero cards, FAB |
| `radiusXl` | 24 | Full-screen modal top corners |
| `radius2xl` | 32 | Onboarding illustration containers |
| `radiusCircular` | 999 | Avatars, round icon buttons, pill chips |

**Rule:** Nested radii follow concentric reduction — a child element inside a `radiusLg` card uses `radiusMd`. Never use the same radius for parent and child.

### 5.2 Surface Hierarchy — Stepped Monochrome Depth

Surfaces communicate elevation through **tinted monochrome steps**, never through drop shadows on dark mode. Each step is approximately +6 luminance over the previous.

```
┌─────────────────────────────────────┐
│  surface0 #000000 (scaffold)        │  ← 0dp visual
│  ┌─────────────────────────────┐    │
│  │  surface2 #121214 (card)    │    │  ← 2dp visual (+ inner top highlight)
│  │  ┌──────────────────────┐   │    │
│  │  │ surface3 #18181C     │   │    │  ← 4dp visual
│  │  │  ┌────────────────┐  │   │    │
│  │  │  │ surface5       │  │   │    │  ← 6dp visual
│  │  │  │ #26262C (input)│  │   │    │
│  │  │  └────────────────┘  │   │    │
│  │  └──────────────────────┘   │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

Cards do not "float" via grey shadow on dark — they **emit** via inner top highlight + ambient lapis-tinted shadow. This is the signature.

### 5.3 Elevation — The Khazna Float (The Signature Technique)

Khazna v3 uses **two depth mechanisms**, mode-dependent, never both at once.

#### Dark Mode — The Floating Card Technique

A "floating" card on dark mode uses THREE layered effects to achieve premium depth. **No Material drop-shadow ever appears on dark mode.**

| # | Layer | Spec | Purpose |
|---|---|---|---|
| 1 | Outer ambient shadow | `glowAmbient` → `0 8 32 rgba(2,6,14,0.72)` | Soft, deeply black-blue ambient depth |
| 2 | Outer border | `0.5px borderSubtle` (`#26262C`) | Crisp edge definition |
| 3 | Inner top highlight | `inset 0 1 0 rgba(255,255,255,0.04)` | Simulates light hitting the top edge |

Combined effect: a card that appears **suspended in front of the canvas, lit from above by ambient light**. No bottom shadow. No grey blur. This is what separates Khazna v3 from every Material-default fintech clone.

#### Light Mode — Paired Soft Shadows

Light mode uses two-layer physically-modeled paired shadows for depth without muddiness. **No lapis glow at rest** — only on the single CTA / focused element per screen.

| Token | Layer 1 (ambient) | Layer 2 (key) | Use |
|---|---|---|---|
| `shadowSoft` | `0 1 3 rgba(0,0,0,0.04)` | `0 1 2 rgba(0,0,0,0.03)` | List tiles |
| `shadowFloat` | `0 4 16 rgba(0,0,0,0.06)` | `0 2 4 rgba(0,0,0,0.04)` | Cards |
| `shadowElevated` | `0 12 32 rgba(0,0,0,0.10)` | `0 4 8 rgba(0,0,0,0.06)` | FABs, sheets |
| `shadowDeep` | `0 24 64 rgba(0,0,0,0.14)` | `0 8 16 rgba(0,0,0,0.08)` | Tooltips, popovers |

### 5.4 The Lapis Glow Border — The Signature Element

The primary CTA, the focused input, the selected list item, and the brand mark are the **only** elements that wear the Lapis glow. The glow has a precise anatomy:

```
   ┌──────────  Outer ambient halo (glowMd)
   │            0 0 16 rgba(3,86,197,0.36)
   ▼
┌─────────────────────────────────────────┐
│  · · ·  soft lapis luminescence · · ·   │
│  · ┌─────────────────────────────────┐ ·│  ← 0.5px lapis400 border
│  · │                                 │ ·│
│  · │      [Primary CTA Label]        │ ·│  ← surface2 fill, monochrome text
│  · │                                 │ ·│
│  · └─────────────────────────────────┘ ·│
│  · · · · · · · · · · · · · · · · · · ·  │
└─────────────────────────────────────────┘
```

#### Glow application matrix (state-by-state)

| Element | Rest State | Hover State | Pressed State | Focused State |
|---|---|---|---|---|
| Primary CTA | `0.5px lapis400` border + `glowMd` halo | brighten halo to `glowLg` | drop to `glowSm` + scale 0.97 + `mediumImpact` haptic | `1.5px lapis400` ring inset 2dp |
| Focused Input | `surface5` fill, no border | — | — | `1.5px lapis400` ring outside |
| Selected list item | `0.5px lapis400` start-edge bar (4dp tall, 70% of tile height) | — | — | — |
| Premium card (Pro) | `glowSm` halo (subtle) | `glowMd` | — | — |
| Premium card (Pro+) | `glowMd` halo + 0.5px `lapis400` start-edge | brighten to `glowLg` | — | — |
| Hero brand mark | `glowXl` halo (large diffuse) | — | — | — |
| Bottom-nav active tab | 2dp `lapis400` top stripe + icon `inkPrimary` | — | — | — |
| Tab bar active | 2dp `lapis400` underline (animated slide) | — | — | — |
| Toast (success) | `glowMd` outer halo | — | — | — |

The halo is achieved via `BoxShadow` with `blurRadius` and `color` set to the lapis token at the specified alpha. `spreadRadius: 0`, `offset: Offset.zero`. It is NEVER achieved via `BoxDecoration.gradient` or stacked containers.

### 5.5 The Khazna Card — The Reference Component

Every card in the system follows this composition:

| Property | Dark | Light |
|---|---|---|
| Fill | `surface2` (`#121214`) | `surface1` (`#FFFFFF`) |
| Radius | `radiusMd` (12) | `radiusMd` (12) |
| Border | `0.5px borderSubtle` | none |
| Outer shadow | `glowAmbient` | `shadowFloat` |
| Inner top highlight | `inset 0 1 0 rgba(255,255,255,0.04)` | none |
| Padding | 16 (cardPadding) | 16 |
| Press state | scale 0.99 + `surface3` fill | scale 0.99 + `surface2` fill |

#### Hero Card (Balance Summary)

The Balance Card extends the standard card with ONE additional element: an extremely faint lapis vignette at the top edge — the only allowed gradient on a content surface.

| Property | Spec |
|---|---|
| Top-edge linear gradient | `linear-gradient(180deg, rgba(3,86,197,0.06) 0%, transparent 80%)` |
| Height of gradient region | 40% of card height |
| Effect | A sub-perceptible "horizon glow" that primes the balance number visually |

This appears on exactly ONE card per screen — the hero balance card. Never on standard cards.

#### Premium Card (Pro / Pro+ features)

Premium cards inherit the standard composition + a lapis glow halo. See §16 for full tier specification.

### 5.6 Glassmorphism — Restricted Use

Glass surfaces are **reserved for four contexts only**:

1. **Lock screen backdrop** (over blurred snapshot of previous state)
2. **Bottom sheet hero header** (subtle glass blur over screen behind)
3. **Toast / Snackbar containers** (glass over scrolling content for readability)
4. **Closing Agent studio** — floating composer dock (`BackdropFilter` σ=16, one per screen) and idle intent satellites (`KhaznaSpecularPanel`, **no** `BackdropFilter`)

**Ambient well vs CTA halo:** The Closing Agent radial light-well (`AppGlows.glowWell` + `glowXl`) is **scene illumination** (Salāsa depth), not a control glow. It does not count toward the one-lapis-glow-per-screen rule. The single CTA halo remains on Send (idle) or Confirm / ritual primary actions (ready phases) via `AppGlows.ctaRest`.

**Specification:**

| Property | Dark | Light |
|---|---|---|
| `backdropFilter` blur | `sigmaX: 24, sigmaY: 24` | `sigmaX: 20, sigmaY: 20` |
| Fill | `rgba(18,18,20,0.62)` | `rgba(255,255,255,0.72)` |
| Border | `0.5px rgba(255,255,255,0.06)` | `0.5px rgba(0,0,0,0.06)` |
| Inner top highlight | `inset 0 1 0 rgba(255,255,255,0.06)` | `inset 0 1 0 rgba(255,255,255,0.5)` |

**Performance rule:** Glass surfaces use `BackdropFilter` wrapped in `RepaintBoundary`. Never apply glass to scrolling list items (catastrophic FPS). Closing Agent satellites use fake glass (`glassFill` + specular rim painter) — never `BackdropFilter` on orbiting or scrolling children. At most **one** `BackdropFilter` per Closing Agent route (the composer dock).

### 5.7 Borders

| Token | Width | Color | Use |
|---|---|---|---|
| `borderHairline` | 0.5 | `borderSubtle` | Dividers, card edge (dark mode) |
| `borderDefault` | 1.0 | `borderStrong` | Card outlines (rare) |
| `borderLapisHairline` | 0.5 | `lapis400` (full opacity) | Primary CTA edge, premium card hairline |
| `borderLapisFocus` | 1.5 | `lapis400` | Active focus ring (2dp inset) |
| `borderError` | 1.5 | `error` | Invalid input |
| `borderSuccess` | 1.5 | `success` | Validated input (1.5s briefly, then revert) |
| `borderGlass` | 0.5 | `glassBorder` | Glassmorphic edges |

**Divider rule:** All dividers are `0.5px`, full-bleed inside cards, inset 16dp inside list groups.

---

## 6 · Iconography

### 6.1 Icon System

Daftar uses a **dual-icon strategy**:

| Set | Source | Use |
|---|---|---|
| **Material Symbols Rounded** (Weight 400, Fill 0) | Flutter built-in `Icons` (Material Symbols subset) | Default UI iconography — navigation, actions, list affordances |
| **Phosphor Icons (Duotone, Bold)** | Bundled SVG set | Empty states, onboarding illustrations, premium feature markers |
| **Custom SVGs** | `assets/icons/` | Brand-specific (Daftar wordmark, currency glyphs, ledger-type illustrations) |

**Weight & fill consistency:** Within a single screen, all icons MUST share the same weight (400) and fill (outlined). Mixing filled and outlined Material icons in the same view is a defect.

### 6.2 Sizes

| Token | Size | Use |
|---|---|---|
| `iconXs` | 12 | Inline within text (`amountSmall` companion) |
| `iconSm` | 16 | Inline within labels, badge content |
| `iconMd` | 24 | **Default** — list trailing, button leading, app bar |
| `iconLg` | 32 | Tab icons, card heroes |
| `iconXl` | 48 | Empty state, onboarding |
| `iconHero` | 96 | Splash, success animations |

### 6.3 RTL Mirroring Rules

Icons split into three classes — only Class A flips in RTL.

| Class | Examples | RTL Behavior |
|---|---|---|
| **A — Directional** | `arrow_back`, `chevron_right`, `swipe_left`, `format_align_right` | **Mirror** via `Transform.scale(scaleX: -1)` |
| **B — Symmetric** | `add`, `close`, `search`, `settings`, `home`, `star`, `heart` | **Never mirror** |
| **C — Glyph-anchored** | Brand marks, currency symbols, flags, character-shaped icons | **Never mirror** |

### 6.4 Icon Color Rules

- Icons inherit `IconTheme.color` — never hardcode.
- Default icon color is monochrome: `inkPrimary` (active) / `inkSecondary` (passive) / `inkMuted` (disabled hint) / `inkDisabled` (truly disabled).
- On debt/payment colored fills (e.g., debt amount), icons use the matching semantic color.
- **Lapis-colored icons are forbidden** — except inside info banners (which are the brand voice).
- Disabled icons use `inkDisabled` — **never** a faded brand color.

### 6.5 Brand Iconography

| Symbol | Use |
|---|---|
| **Daftar wordmark** (دفتر) | App icon, splash, lock screen, onboarding |
| **Khazna vault glyph** | Premium tier markers, secure-backup screens |
| **Crescent + dinar** | Empty state for new ledgers (cultural anchor) |

Brand iconography is monochrome on its own surface; the lapis appears only as the surrounding `glowXl` halo on the hero brand mark.

---

## 7 · Motion & Haptics

### 7.1 Motion Doctrine

Every animation in Daftar serves one of four purposes:

1. **Causality** — show the user that their action produced this result.
2. **Hierarchy** — emphasize what just changed.
3. **Continuity** — bridge screens so the user never loses orientation.
4. **Personality** — the spring overshoot on a toggle, the breathing glow on an awaiting CTA, confirms the Khazna brand feel.

**Animations that serve none of the above are decorative noise and must be cut.**

### 7.2 Duration Tokens

| Token | Duration | Use |
|---|---|---|
| `animationInstant` | 80 ms | Micro-bounces, toggle ticks |
| `animationFast` | 150 ms | Button press, icon morph, checkbox |
| `animationMedium` | 300 ms | State transitions, expand/collapse, tab switch |
| `animationSlow` | 450 ms | Page transitions, bottom sheet enter/exit |
| `animationXSlow` | 600 ms | Number count-up, balance card reveal |
| `animationOnboard` | 900 ms | Onboarding hero animations, success celebrations |
| `animationBreath` | 2400 ms | Lapis glow breathing pulse on awaiting CTAs |

### 7.3 Curve Tokens

> **`Curves.linear` is BANNED** for UI motion — it feels mechanical. The only acceptable exceptions are scroll-linked physics.

| Token | Flutter Curve | Use |
|---|---|---|
| `curveEnter` | `Curves.easeOutCubic` | Entering elements |
| `curveExit` | `Curves.easeInCubic` | Exiting elements |
| `curveStandard` | `Curves.easeInOutCubic` | Bidirectional transitions |
| `curveEmphasized` | `Curves.easeOutExpo` | Hero number count-up, balance reveal |
| `curveSpring` | `Curves.elasticOut` (clamped 0.6 overshoot) | Toggles, save confirmations |
| `curveAnticipate` | Custom cubic-bezier `(0.4, 0.0, 0.6, -0.6)` | Subtle wind-up before primary CTA confirm |
| `curveSheetSpring` | `SpringSimulation` (mass: 1, stiffness: 280, damping: 24) | Bottom sheet drag-snap |
| `curveBreath` | `Curves.easeInOut` (loop) | Glow breathing pulse |

### 7.4 Signature Motion Patterns

#### Lapis Glow Breath
Whenever the primary CTA on a screen has not been interacted with for ≥ 3 seconds (e.g., empty-state CTA, onboarding "Get Started"), its halo breathes:
- Halo alpha animates between `glowSm` (0.28) and `glowMd` (0.36) over 2.4s `curveBreath`, looping.
- On any user input event anywhere on screen, breath pauses; resumes after 3s of inactivity.
- On dark mode only — light mode does not breathe (paired shadows don't pulse well in physics).

#### Bottom Sheet Enter
1. Backdrop scrim fades in over 200ms (`curveEnter`).
2. Sheet slides up from `y: 100%` to `y: 0%` over 450ms with `curveSheetSpring`.
3. Sheet content fades in 100ms after sheet motion begins (60ms duration, `curveEnter`).

#### Number Count-Up (Balance Card)
- On any balance change, animate from previous value to new value over 600ms (`curveEmphasized`).
- Decimal digits are interpolated as a unit (don't animate the decimal place — only the integer part).
- Currency symbol does not animate.
- **The balance card's lapis vignette intensifies by +20% alpha during the count-up animation**, then returns to rest — a "the number is changing" cue.

#### Transaction Save Success
1. Save button enters loading state — spinner replaces label, button width preserved (200ms morph).
2. On success: spinner morphs to checkmark; the lapis halo briefly expands from `glowMd` → `glowLg` over 250ms with `mediumImpact` haptic.
3. Sheet dismisses (sheet exit, 450ms).
4. New transaction row enters list with slide-in + fade (300ms `curveEnter`).
5. Balance card number counts up to new value (600ms `curveEmphasized`).

#### List Stagger Entrance
- Items 1–8 fade + slide in from `y: +12` to `y: 0`.
- Stagger: 30ms per item. Items 9+ render instantly.
- Trigger only on first paint or after explicit refresh.

#### Swipe-to-Delete
- Row tracks finger 1:1 horizontally up to threshold (33% width).
- At threshold cross: haptic `selectionClick`, action icon scales `0.9 → 1.0`.
- On release past threshold: row width collapses to 0 over 250ms (`curveExit`), then snackbar with Undo enters.

#### Page Transitions
- **Push (forward):** Incoming page slides from `start` (right→left in LTR, left→right in RTL), 350ms `curveStandard`. Outgoing page parallaxes -25%.
- **Pop:** Reverse.
- **Hero transitions:** Contact avatar in list → enlarged avatar on detail screen, 400ms `curveStandard`.

#### Pull-to-Refresh — The Lapis Arc
- Pull threshold: 80dp.
- At 60dp: lapis-stroked circular arc indicator (2dp `lapis400`) appears, growing with pull distance.
- At threshold: haptic `mediumImpact`, indicator fully formed.
- During refresh: indicator spins with `glowSm` halo around it — the lapis arc is the only direct lapis usage on the refresh interaction.

### 7.5 Haptic Feedback Map

> **Haptics are not optional flourish — they are interaction confirmation. Missing haptics on any row below is a defect.**

| Action | Haptic | Rationale |
|---|---|---|
| Transaction saved (debt or payment) | `mediumImpact` | Confirms financial operation |
| Delete confirmed | `heavyImpact` | Weight of destructive action |
| Undo tapped | `lightImpact` | Quick acknowledgment |
| PIN button press | `selectionClick` | Tactile keypad feel |
| Amount-pad digit press | `selectionClick` | Tactile keypad feel |
| Amount-pad delete press | `lightImpact` | Distinguish from digits |
| Bottom sheet snap-to-position | `lightImpact` | Physical anchor |
| Pull-to-refresh threshold crossed | `mediumImpact` | Commit point |
| Swipe threshold crossed | `selectionClick` | Commitment point |
| Toggle switch flipped | `lightImpact` | State change |
| Button press (primary CTA, on press-down) | `lightImpact` | Touch confirmation |
| Long-press triggered | `mediumImpact` | Mode shift |
| Validation error appears | `heavyImpact` | Demand attention |
| Save success animation | `mediumImpact` | Pair with checkmark + glow burst |
| Lock screen unlock success | `lightImpact` | Subtle reassurance |
| Lock screen unlock failure | `heavyImpact` | Alarm |
| Reorder drag pick-up | `mediumImpact` | Mode entry |
| Reorder drop | `lightImpact` | Mode exit |
| Tier upgrade success | `heavyImpact` + `lightImpact` 200ms later | Reward (paired with glow expansion) |

### 7.6 Reduced Motion

When `MediaQuery.disableAnimations` is true (or user enabled "Reduce Motion" at OS level):

- All durations clamp to ≤ 100ms.
- Spring physics replaced with linear interpolation.
- Number count-up replaced with instant jump.
- Stagger entrance replaced with simultaneous fade.
- Hero transitions become cross-fades.
- Parallax and decorative micro-bounces disabled entirely.
- **Lapis glow breath halts** (static `glowMd`).

**Haptics are NEVER reduced** — they're a separate accessibility channel.

---

## 8 · Component Architecture & States

### 8.1 Component State Matrix

Every interactive component implements these states. **A component missing any applicable state is incomplete.**

| State | Trigger | Visual Treatment |
|---|---|---|
| **Default** | Idle | Token-defined surface + monochrome text |
| **Hover** | Pointer hover (web/tablet) | Surface tint +1 step; if CTA, halo brightens |
| **Focused** | Keyboard/accessibility focus | `1.5px lapis400` ring, 2dp inset |
| **Pressed** | Active touch | Scale 0.97, surface tint +2 steps; if CTA, halo drops to `glowSm` |
| **Loading** | Async operation in flight | Inline spinner replaces label, interaction disabled, original width preserved |
| **Disabled** | Unavailable | `inkDisabled` text, `alphaMedium` icon, no press feedback, no haptic, no halo |
| **Error** | Validation failure | `1.5px borderError`, error icon, helper text in `error` color |
| **Success** | Validated/confirmed | `1.5px borderSuccess` briefly (1.5s), checkmark icon, then revert |
| **Selected** | Multi-select / radio active | Surface tint +1, `0.5px lapis400` start-edge bar |
| **Empty** | No data to display | Branded empty state — see §11.4 |

### 8.2 Button — `DaftarButton`

#### Variants

| Variant | Fill | Border | Halo (Rest) | Text | Use |
|---|---|---|---|---|---|
| **Primary** | `surface2` (dark) / `surface1` (light) | `0.5px lapis400` | `glowMd` | `inkPrimary` | One per screen — main CTA |
| **Secondary** | `surface3` | `0.5px borderSubtle` | none | `inkPrimary` | Secondary action |
| **Tertiary / Ghost** | Transparent | none | none | `inkPrimary` | Inline / dismissive |
| **Destructive** | `error` (`#FF5757`/`#C8281C`) | none | none | `onError` | Delete, sign out |
| **Destructive Outlined** | Transparent | `1.5px error` | none | `error` | Destructive secondary in cancel/delete pairs |
| **Premium (Pro/Pro+)** | same as Primary | `0.5px lapis400` | `glowLg` (Pro+) / `glowMd` (Pro) | `inkPrimary` | Premium-tier CTA emphasis |

> **Important:** The Primary variant in Khazna v3 is **not** a gold or lapis fill — it's a monochrome surface wrapped in a lapis glow + border. The brand identity lives in the light around the button, not in the button itself.

#### Sizes

| Size | Height | Horizontal Padding | Min Width | Label Style |
|---|---|---|---|---|
| `small` | 36 | 12 | 64 | `labelMedium` |
| `medium` (default) | 48 | 16 | 96 | `labelLarge` |
| `large` | 56 | 20 | 128 | `labelLarge` |
| `xlarge` (sheet primary) | 64 | 24 | full-width | `labelLarge` 16sp |

#### Behavior
- Press-down: scale `0.97`, halo drops to `glowSm` (Primary), haptic `lightImpact`, duration `animationFast`.
- Loading: label fades, spinner fades in (`inkPrimary` color), width preserved.
- Success morph: spinner → checkmark (200ms), halo expands `glowMd → glowLg` over 250ms then returns, haptic `mediumImpact`.
- Icon-only buttons (square 48×48): `radiusCircular` fill, same state machine.

### 8.3 Card — `DaftarCard`

See §5.5 for the full reference composition.

Sub-variants:
- **Hero card** (balance summary): `radiusLg` (16), 4% lapis vignette overlay at top, Khazna float
- **Compact card** (chip-like): `radiusSm`, no padding override, `bodyMedium` text
- **Selectable card**: ships with selected state (see §8.1)
- **Premium card** (Pro / Pro+): see §16.2

### 8.4 List Tile — Custom Composition

> **Material `ListTile` is BANNED.** All list rows are custom-composed.

#### Anatomy

```
┌────────────────────────────────────────────────┐
│ [Leading]   [Title              ]   [Trailing] │  ← 64dp tall (comfortable)
│             [Subtitle           ]              │
│             [Metadata           ]              │
└────────────────────────────────────────────────┘
   ↑                ↑                     ↑
   48dp        flex content        intrinsic
```

- Horizontal padding: 16
- Vertical padding: 12 (comfortable) / 8 (compact)
- Leading slot: avatar / icon, 36–48dp
- Title: `titleMedium`, 1 line, ellipsis
- Subtitle: `bodySmall`, 1 line, `inkSecondary`
- Trailing: amount (Inter tabular) + chevron, or single chevron, or icon-only

#### Color Coding (Semantic Edge)
For transaction tiles only:
- **Debt:** 4dp `start`-edge bar in `debt`, vertical-center 70% of tile height
- **Payment:** Same, but `payment`

Selected transaction (rare — Phase 2 multi-select): same 4dp `start`-edge bar but in `lapis400`.

### 8.5 Bottom Sheet — `DaftarBottomSheet`

#### Anatomy
- Top corners: `radiusXl` (24)
- Drag handle: 4×40dp pill, `inkMuted`, centered, 12dp top margin
- Header padding: 20dp (`bottomSheetPadding`)
- Content padding: 20dp horizontal, 16dp vertical
- Background: `surface3` (dark) / `surface1` (light) with `glassFill` glass header
- Backdrop: `scrim` with `BackdropFilter(sigma: 8)`

#### Behavior
- Enter: `curveSheetSpring`, 450ms
- Drag-to-dismiss: tracks finger; release with velocity > 700px/s OR drag past 40% → dismiss
- Snap points: default `[0.5, 0.95]`; configurable
- Inner scroll: sheet content scrolls within if it overflows; drag handle stationary
- Close: tap scrim or swipe down — haptic `lightImpact` on snap

#### Sheet Taxonomy

| Sheet Type | Use | Default Snap |
|---|---|---|
| **Action Sheet** | 2–4 actions | 0.5 |
| **Form Sheet** | Add transaction, add contact, edit ledger | 0.85 |
| **Selector Sheet** | Currency picker, sort options, date picker | 0.5 |
| **Detail Sheet** | Transaction detail preview | 0.6 |
| **Full-Screen Sheet** | Onboarding step, PDF preview | 0.95 |
| **Confirmation Sheet** | Replaces `AlertDialog` everywhere | wrap-content |

### 8.6 FAB

- Position: `bottom: SafeArea.bottom + 16, end: 16`
- Size: `largeTapTarget` (64) for primary, `comfortableTapTarget` (56) for mini
- Fill: `surface2` (dark) / `surface1` (light)
- Border: `0.5px lapis400`
- Halo: `glowMd` at rest, `glowLg` on hover, `glowSm` on press
- Icon: `inkPrimary`, 24dp
- Press: scale `0.95`, haptic `mediumImpact`
- Extended FAB: icon + `labelLarge` text, height 56, horizontal padding 20

### 8.7 Chips

| Variant | Fill | Border | Use |
|---|---|---|---|
| **Filter chip** (inactive) | Transparent | `borderSubtle` | Sort/filter options |
| **Filter chip** (active) | `surface4` | `0.5px lapis400` | Selected filter |
| **Currency chip** | `surface3` | none | Currency selector |
| **Tag chip** | `surface5` | none | Read-only metadata |
| **Badge chip** (Pro) | `surface3` | `0.5px lapis400` + `glowXs` | "Pro" tier marker |
| **Badge chip** (Pro+) | `surface3` | `0.5px lapis400` + `glowSm` | "Pro+" tier marker |

Height: 32dp. Padding: 12 horizontal, 6 vertical. Label: `titleSmall` `inkPrimary`.

### 8.8 Tabs

- Indicator: 2dp `lapis400` underline, animated slide between tabs (`animationMedium` `curveStandard`)
- Inactive: `inkSecondary`. Active: `inkPrimary`
- Label: `titleSmall`
- Tabs are scrollable (`isScrollable: true`) when label widths vary between locales

### 8.9 Bottom Navigation

- Height: 64dp + safe area
- Background: `surface2` (dark) / `surface1` (light), border-top `borderHairline`
- Items: max 4. Icon 24dp, label `labelSmall` below
- Active: icon + label `inkPrimary`, 2dp top stripe `lapis400`
- Inactive: `inkSecondary`
- Tap: haptic `selectionClick`, icon scale bounce `1.0 → 0.92 → 1.0` (180ms)

### 8.10 Switches & Toggles

- Track: 32×52dp. Thumb: 28dp
- Off state: track `surface5`, thumb `inkSecondary`
- On state: track `surface3`, thumb `inkPrimary`, **0.5px lapis400 border around track + `glowXs` halo**
- Animation: spring overshoot (`curveSpring`, 250ms)
- Haptic: `lightImpact` on every state change

The active switch is the only place lapis appears on a toggle — and only as a hairline border + faint halo, never as track fill.

---

## 9 · Forms, Inputs & The Amount Pad

### 9.1 Text Input — `DaftarTextField`

#### Anatomy

```
┌────────────────────────────────────────────┐
│ [Floating Label]                           │  ← `labelSmall`, animated
│ [Icon] [Input text                  ] [X]  │  ← `bodyLarge`
└────────────────────────────────────────────┘
 [Helper text or error]                          ← `bodySmall`
```

#### Behavior

- Background: `surface5` (dark) / `surface3` (light), radius `radiusSm`
- Border: 1px `transparent` default; on focus: `1.5px lapis400` ring; on error: `1.5px borderError`
- Floating label: starts as placeholder at `bodyLarge`. On focus or non-empty, animates to top — 200ms `curveStandard`. Color: `inkSecondary` default → `lapis400` on focus → `error` on error
- Clear button: appears when non-empty, 24dp tap target with 12dp icon
- Helper text: 4dp below input, `bodySmall`, `inkSecondary`. Replaced by error text in `error` color
- Character counter: when `maxLength` set, displays at `end` of helper row
- Height: 56dp (input only) + helper text row
- Padding: 16 horizontal, 12 vertical

#### States

| State | Border | Background | Label | Icon |
|---|---|---|---|---|
| Default | none | `surface5` | `inkSecondary` | `inkMuted` |
| Focused | `1.5px lapis400` | `surface5` | `lapis400` (light) / `lapis300` (dark for contrast) | `inkPrimary` |
| Filled | none | `surface5` | `inkSecondary` | `inkPrimary` |
| Error | `1.5px error` | `surface5` | `error` | `error` |
| Disabled | none | `surface3` | `inkDisabled` | `inkDisabled` |
| Read-only | none | `surface3` | `inkSecondary` | `inkMuted` |

### 9.2 Search Bar

- Height: 48dp, radius `radiusCircular` (pill)
- Background: `surface3` (dark) / `surface2` (light)
- Leading: search icon 24dp, `inkMuted`
- Input: `bodyLarge`
- Trailing: animated clear button (only when non-empty) — fades in 150ms
- Focused state: `1.5px lapis400` ring + `glowXs` halo
- Behavior: debounced input (250ms after last keystroke) before triggering search
- RTL: search icon stays at `start`, clear button at `end` — geometry flips automatically

### 9.3 The Amount Pad — Daftar's Signature Component

The amount pad is the heart of transaction entry. Large, tactile, and visually unmistakable.

#### Anatomy

```
┌─────────────────────────────────────┐
│   [Debt عليه ]   [Payment له]       │  ← Type toggle (segmented, 48dp)
│                                     │
│       ┌───────────────────────┐     │
│       │       1,250.00 ر.ي    │     │  ← Display (Inter tabular, 40sp)
│       └───────────────────────┘     │       Color: debt-red or payment-green
│                                     │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐    │
│  │  1  │ │  2  │ │  3  │ │ ⌫  │    │  ← 4-col grid
│  ├─────┤ ├─────┤ ├─────┤ ├─────┤    │
│  │  4  │ │  5  │ │  6  │ │     │    │
│  ├─────┤ ├─────┤ ├─────┤ │ر.ي. │    │  ← Currency selector (spans 2 rows)
│  │  7  │ │  8  │ │  9  │ │     │    │
│  ├─────┤ ├─────┤ ├─────┤ ├─────┤    │
│  │  .  │ │  0  │ │ 000 │ │  ⏎ │    │  ← Submit key: lapis glow border
│  └─────┘ └─────┘ └─────┘ └─────┘    │
└─────────────────────────────────────┘
```

#### Specs
- Keys: 56–64dp square, `radiusMd`, surface `surface3`, label `numeralInput`
- Press: scale `0.95`, haptic `selectionClick`, surface tint +2 steps (150ms)
- Backspace: `lightImpact` haptic, repeats on long-press (after 400ms hold, every 80ms)
- Display: `amountHero` (40sp), color matches type toggle (debt-red or payment-green)
- Currency selector: tap opens a half-sheet of active currencies
- "000" key: power-user shortcut for thousands
- Decimal key: disabled when currency has 0 decimal places (e.g., YER)
- **Submit key (⏎):** the ONE key on the pad with the lapis treatment — `0.5px lapis400` border + `glowSm` halo. Becomes the primary CTA visual focus

#### Type Toggle (Segmented Control)
- Two segments: Debt (عليه) / Payment (له)
- Inactive segment: `surface3` fill, `inkSecondary` text
- Active segment: `surface5` fill, `inkPrimary` text, **0.5px semantic color border** (debt = red border, payment = green border) — NOT lapis. The semantic color anchors the user's intent

#### RTL Handling
- Keypad layout DOES NOT mirror — numerals read LTR universally
- Backspace icon flips per RTL rules (Class A — directional)
- The amount display stays LTR even within an RTL screen

### 9.4 Date Picker

- Replaces native `showDatePicker` with custom bottom sheet
- Calendar grid: 7 columns, day labels at top
- Today: `surface5` fill, **0.5px lapis400 border + `glowXs` halo**
- Selected: `surface3` fill, **1.5px lapis400 border + `glowSm` halo**
- Disabled (future when not allowed): `inkDisabled`
- Months: swipe horizontally, snap with spring physics

### 9.5 Validation Doctrine

- **Inline validation:** Fields validate on blur (not on every keystroke).
- **Submit validation:** All fields re-validated on submit; first invalid field gets focus.
- **Error display:** Helper-text slot below field — animated in (slide-down + fade, 200ms).
- **Error microcopy:** Always actionable. Not "Invalid input" — "Amount must be greater than zero."
- **Localized:** All validation strings from ARB keys.
- **No alert dialogs for validation** — always inline.

---

## 10 · Data Visualization & Lists

### 10.1 Transaction List

- `ListView.builder` with `findChildIndexCallback` for stable identity
- Date grouping headers: sticky during scroll, `labelLarge` text, `inkSecondary` color, 12dp vertical padding, 16dp horizontal
- Date group labels are localized & relative:
  - `Today` / `اليوم`
  - `Yesterday` / `أمس`
  - `This Week` / `هذا الأسبوع`
  - `Last Week` / `الأسبوع الماضي`
  - `[Month Year]` for older
- Each transaction tile shows: type-color edge bar (4dp `start`), title (item or description), amount (right-aligned LTR, semantic color), date+time micro-caption, running balance (italic, `inkMuted`)
- Pagination: 20 per page; infinite scroll triggers at 80% scroll position; loading row shows 3 shimmer skeletons at end

### 10.2 Balance Card (Hero)

See §5.5 — uses the Khazna Float + the lapis vignette overlay.

- Net balance large (`amountLarge`), per-currency breakdown chips below
- Net balance color:
  - Positive (merchant is owed): `debt` color
  - Negative (merchant owes): `payment` color
  - Zero: `inkSecondary`
- Animated count-up on every value change (see §7.4)
- During count-up: vignette intensifies briefly (+20% alpha) then returns
- Tap to expand: reveals per-currency detail breakdown — spring expand animation

### 10.3 Charts (Phase 2 — Advanced Analytics)

Visual specification for `fl_chart` or `syncfusion_charts` integration. The chart palette obeys the same Lapis Lux doctrine — monochrome + lapis stroke + semantic red/green.

#### Color Palette (chart series — strict order)

1. **Primary metric stroke:** `lapis400` (2dp line, lapis stroke ONLY, no fill)
2. **Secondary metric stroke:** `inkPrimary` (2dp line)
3. **Debt series:** `debt` (filled bars OK — debt earns its color)
4. **Payment series:** `payment` (filled bars OK)
5. **Comparison/baseline:** `inkMuted` (1dp dashed line)
6. **Projection / forecast:** `lapis300` (2dp dashed line)

#### Chart Rules
- **Axis lines:** `borderHairline` `borderSubtle`. Never default Material grey
- **Gridlines:** 0.5px `borderSubtle`, dashed pattern `[4, 4]`
- **Tooltips:** glass surface, `radiusMd`, `labelMedium` text, 8dp padding, appears with 150ms fade. Uses `glowMd` halo on dark mode
- **Sparkline strokes:** 2dp, rounded line caps. Lapis sparkline gets a `linear-gradient(0.0, lapis400 0.18, transparent)` area fill (sub-perceptible) — the ONE allowed lapis "fill" because it's gradient-to-transparent
- **Empty chart state:** branded empty state, NOT a zero-line chart
- **Tabular axis labels:** all numeric axes use Inter tabular figures
- **Animation:** chart bars/lines draw in on first render — 800ms staggered (`curveEmphasized`)

### 10.4 Empty States

Empty states are FIRST IMPRESSIONS. They are illustrated, animated, actionable.

| Context | Illustration | Headline | Body | CTA |
|---|---|---|---|---|
| No ledgers (first run) | Crescent + open book (monochrome SVG) | "ابدأ أول دفتر" | "نظّم ديونك ومدفوعاتك في مكان واحد آمن" | "إنشاء دفتر" (Primary CTA — breathes) |
| No contacts in ledger | Phonebook silhouette | "أضف أول عميل" | "كل عميل له سجل خاص" | "إضافة عميل" |
| No transactions for contact | Empty scroll/ledger sheet | "لا توجد حركات بعد" | "سجّل أول دين أو دفعة" | "تسجيل حركة" |
| No backups | Cloud + lock | "لا توجد نسخ احتياطية" | "حافظ على بياناتك آمنة" | "إنشاء نسخة احتياطية" |
| Search no results | Magnifying glass + empty | "لا توجد نتائج" | "جرّب كلمات مختلفة" | "مسح" (Tertiary) |
| Offline mode (Drive) | Cloud + wifi-off | "لا يوجد إنترنت" | "ستتم المزامنة عند توفّر الاتصال" | none |
| All caught up (success) | Checkmark in circle | "كل شيء محدّث" | none | none |

**Entrance:** SVG/Lottie illustration scales `0.92 → 1.0` (300ms `curveEmphasized`), then headline fades in (200ms delay, 200ms duration), then body fades in (100ms delay), then CTA scales in (`curveSpring`, 100ms delay).

**The empty-state CTA on first-run screens uses `glowBreath`** — the lapis halo pulses to draw the new merchant's attention.

### 10.5 List Affordances

- **Swipe-to-delete:** Available on transactions, contacts. Swipe from `end` direction. Threshold: 33% width
- **Swipe-to-edit:** Available on transactions only. Swipe from `start` direction. Reveals lapis-bordered edit action
- **Long-press:** Enters multi-select mode (Phase 2). Haptic `mediumImpact`
- **Pull-to-refresh:** Lapis arc indicator (see §7.4)

---

## 11 · Feedback — Skeletons, Toasts, Banners, Dialogs

### 11.1 Skeleton Loading — The Daftar Standard

**Spinners are FORBIDDEN as primary loading states.** Every async list, card, or screen MUST use shape-matched shimmer skeletons.

#### Skeleton Specs

- Use `skeletonizer` package — wrap real widgets with `Skeletonizer(enabled: isLoading)`
- Shimmer base: `surface3` (dark) / `surface2` (light)
- Shimmer highlight: `surface5` (dark) / `surface3` (light)
- Sweep direction: always `start → end` (locale-aware)
- Animation: 1.4s loop, ease-in-out
- Skeleton radius matches real element radius exactly

> Note: Skeleton shimmer in Khazna v3 remains strictly monochrome. Lapis NEVER appears in shimmer (it would distract from genuine UI focus).

#### Skeleton Patterns

| Pattern | Use |
|---|---|
| List skeleton | 6 list-tile shapes stacked with divider gaps |
| Card skeleton | One large rect + 2 small rects below |
| Balance card skeleton | Hero amount rect + 3 chip-shaped rects below |
| Empty container skeleton | Generic 16-line text skeleton |

**Spinner permitted only in:** inline button loading state, pull-to-refresh active indicator, file upload progress (with progress bar).

### 11.2 Toast / Snackbar — `DaftarSnackbar`

#### Specs

- Position: bottom, 16dp above safe area (or above FAB if present, 80dp)
- Width: full minus 16dp horizontal margin, max 600dp
- Background: `glassFill` with `BackdropFilter` blur
- Radius: `radiusMd`
- Padding: 16 horizontal, 12 vertical
- Border: `0.5px glassBorder`

#### Variants

| Variant | Icon | Icon Color | Text Color | Halo |
|---|---|---|---|---|
| Default | `info` icon | `inkPrimary` | `inkPrimary` | none |
| Success | `check_circle` | `success` | `inkPrimary` | `glowMd` (the success glow moment) |
| Warning | `warning` | `warning` | `inkPrimary` | none |
| Error | `error` | `error` | `inkPrimary` | none |

The success toast is the only feedback widget that wears the lapis halo by default — confirming "your action succeeded" in the brand voice.

#### Behavior
- Enter: slide up from bottom + fade, 300ms `curveEnter`
- Exit: slide down + fade, 200ms `curveExit`
- Duration: 4s default; 6s with action; auto-extend if cursor remains over toast
- Optional action button: `labelLarge` `inkPrimary`, 8dp `start` margin from text
- Optional progress bar: 2dp thick, `lapis400`, runs from full to 0 across duration

### 11.3 Banners (Inline, Non-Modal)

Persistent inline banners at top of screens for offline status, limit warnings, premium upsells, and info messages.

#### Specs
- Background: semantic container color (`warningContainer`, `lapis800` for info, etc.)
- Height: ≥ 56dp
- Padding: 16 all around
- Layout: leading icon (24) + text (flex) + trailing action button (text-only)
- Dismissible: optional X icon at `end`
- Entrance: slide down from top of content area (300ms `curveEnter`)

**Info banner (lapis container):** This is the SOLE exemption from the "no lapis as fill" rule. The info banner uses `lapis800` (dark) / `lapis50` (light) as background, with `lapis400` icon and `lapis50` / `lapis800` text respectively. Use it when the brand voice is speaking directly to the merchant (educational content, important reminders).

### 11.4 Dialogs / Confirmations

**Material `AlertDialog` is FORBIDDEN.** All confirmations use bottom sheets.

#### Confirmation Sheet Pattern
- Title (`titleLarge`, center-aligned)
- Body description (`bodyMedium`, `inkSecondary`, center-aligned, max 3 lines)
- Action button stack (vertical for ≥ 2 buttons):
  1. Primary action (Primary or Destructive variant)
  2. Cancel (Tertiary variant — text only)
- Padding: 24 all around
- Buttons full-width on mobile

### 11.5 Progress Indicators

| Type | Use | Style |
|---|---|---|
| **Linear progress** | File upload, backup progress | 4dp thick, `lapis400` fill on `surface5` track |
| **Determinate circular** | PDF generation, batch operations | 4dp stroke, lapis arc on `surface5` track, optional `glowSm` halo |
| **Indeterminate circular** | Button loading only | 2dp stroke, matches button text color, 16dp diameter |
| **Step indicator** | Onboarding, multi-step forms | Dots, 8dp, active = `lapis400` with `glowXs`, inactive = `surface5` |

---

## 12 · RTL & Bilingual Adaptation

### 12.1 The RTL Geometric Law

Arabic (RTL) is the **default locale**. RTL is the canonical geometry. English (LTR) is a mirror — equally polished but not the reference.

### 12.2 Mandatory Directionality APIs

> **Forbidden APIs:** `EdgeInsets.left/right`, `Positioned(left:, right:)`, `Alignment.centerLeft/centerRight`, `TextAlign.left/right`.

| ❌ Banned | ✅ Required |
|---|---|
| `EdgeInsets.only(left: x, right: y)` | `EdgeInsetsDirectional.only(start: x, end: y)` |
| `Positioned(left:, right:)` | `PositionedDirectional(start:, end:)` |
| `Alignment.centerLeft` | `AlignmentDirectional.centerStart` |
| `TextAlign.left` | `TextAlign.start` |
| `Row` with manual ordering | Always defer to `Directionality.of(context)` |

### 12.3 What Flips, What Doesn't

| Element | Flips in RTL | Why |
|---|---|---|
| Layout direction | ✅ Yes | `Directionality` handles automatically |
| Text alignment | ✅ Yes | `TextAlign.start` resolves to right in RTL |
| Directional icons (chevron, arrow) | ✅ Yes | See §6.3 Class A |
| Symmetric icons (close, add, search) | ❌ No | Glyph is direction-neutral |
| Brand glyphs, currency symbols, flags | ❌ No | Glyph identity preserved |
| Numerals (amounts, dates, phones) | ❌ No (always LTR) | Math reads left-to-right |
| Swipe directions | ✅ Yes | Swipe-to-delete from `end` direction |
| Page transitions | ✅ Yes | New page enters from `start` direction |
| Drag handles in bottom sheets | ❌ No (centered) | Centered, no direction |
| Progress bars | ✅ Yes | Fill direction follows reading direction |
| Lapis 2dp tab indicator | ❌ No | Indicator under active tab — direction-agnostic |
| List tile start-edge color bar (debt/payment) | ✅ Yes | "Start" resolves correctly |

### 12.4 Locale Switching

- Toggle in Settings: Arabic / English
- Locale change is **immediate** — no app restart
- RTL/LTR transition uses a 250ms cross-fade to prevent jarring re-layout
- Active locale persists to `AppSettings` via `SettingsRepository`

### 12.5 Mixed-Content Patterns

Arabic UI containing English data (e.g., a USD amount) requires explicit directionality:

```
Container (Directionality.rtl)
  └─ Row (Arabic label + Amount widget)
       ├─ Text "الرصيد"   ← inherits RTL
       └─ Directionality.ltr
            └─ Text "$1,500.00"   ← forced LTR for numeric reading
```

### 12.6 Translation Stress Tests

Before any screen is accepted, perform these tests:

1. **Length doubling:** Replace all Arabic text with its English equivalent (or vice versa). Does anything truncate, overflow, or break layout?
2. **Direction flip:** Swap locale. Are all margins, alignments, icons, and swipes correct?
3. **Numeric purity:** In Arabic mode, do all amounts/dates/phones render in Western Arabic numerals (1, 2, 3) — never Eastern Arabic-Indic (١، ٢، ٣) — to match Inter tabular formatting?
4. **Mixed content:** Are inline Arabic+English strings properly bidirectional (no digit reordering)?
5. **Glow geometry:** Does the lapis glow render symmetrically around the CTA in both directions?

### 12.7 Numeric System Choice

Daftar uses **Western Arabic numerals** (0–9) universally — even in Arabic UI.

- MENA merchants are pervasively familiar with Western numerals
- Tabular figures only exist in Latin fonts (Inter) — Eastern Arabic-Indic loses alignment
- Reduces visual switching cost for cross-locale users

---

## 13 · Accessibility (A11y)

### 13.1 Contrast (WCAG AAA for Financial Text)

| Text Class | Required Ratio | Token Pairs (Dark) |
|---|---|---|
| Body text (≥ 14sp) | 7:1 (AAA) | `inkPrimary` on `surface2` = 17.8:1 ✅ |
| Large text (≥ 18sp or ≥ 14sp bold) | 4.5:1 (AAA) | `inkSecondary` on `surface2` = 7.6:1 ✅ |
| Non-text UI (icons, focus rings, borders) | 3:1 (AA+) | `lapis400` on `surface2` = 4.8:1 ✅ |
| Disabled text | No minimum (deliberately reduced) | `inkDisabled` on `surface2` = 2.1:1 (allowed for disabled only) |
| Status text (debt/payment) | 4.5:1 minimum | `debt` on `surface2` = 5.1:1 ✅ / `payment` on `surface2` = 6.7:1 ✅ |
| Lapis on glow (for info banner content) | 4.5:1 | `lapis50` on `lapis800` = 12.3:1 ✅ |

**Validation:** All token pairs must be re-verified after any palette change using WebAIM Contrast Checker.

### 13.2 Tap Targets

- Minimum: **48×48dp** (WCAG 2.5.5, Material Guidelines)
- Comfortable: 56dp
- Large: 64dp
- Compact mode (§4.3) reduces visual padding but NOT hit areas — invisible hit zones extend to 48dp
- Adjacent tappable elements must have ≥ 8dp gap between hit zones

### 13.3 Focus Order

- Logical reading order: top → bottom, `start` → `end` (locale-aware)
- Focus ring: `1.5px lapis400` with 2dp inset
- Focus never traps inside modals — Escape / back gesture always exits
- Programmatic focus: form errors auto-focus first invalid field

### 13.4 Semantics

- Every interactive widget has a `Semantics(label:)` from ARB
- Balance amounts: full semantic label includes amount + currency in natural language
- Icons-only buttons: required `tooltip` + `Semantics.label`
- **Status colors NEVER alone:** debt/payment distinction always paired with text symbol (+/-) AND/OR direction icon

### 13.5 Text Scaling

- Layouts must survive `MediaQuery.textScaleFactor` up to **1.5×** without:
  - Truncating user-essential content
  - Breaking alignment
  - Cropping tap targets
- Use `Flexible` and `Expanded` generously inside `Row`/`Column`
- Use `FittedBox(fit: BoxFit.scaleDown)` for display-level numerals that must fit fixed containers

### 13.6 Screen Reader Support

- TalkBack (Android) and VoiceOver (iOS) tested per release
- Balance changes announce via `Semantics(liveRegion: true)`
- Form validation errors announce automatically on appearance
- Navigation announces new screen titles
- **The lapis glow is decorative-only to screen readers** — it does not announce. The semantic relationship is conveyed by element role and label

### 13.7 Motion Sensitivity

See §7.6 — Reduce Motion fully respected. Lapis glow breath halts under reduced motion.

### 13.8 Color-Blind Considerations

- Debt/payment distinction NEVER relies on color alone — always paired with:
  - Direction icon (`arrow_downward` for debt, `arrow_upward` for payment)
  - `+` / `-` prefix on amounts
  - Color-edge bar AND amount color
- Lapis is intentionally a **mid-luminance blue** — distinguishable to all common color-vision deficiencies (deuteranopia, protanopia, tritanopia). The glow halo provides additional non-color depth cue

---

## 14 · Edge Cases & Defensive Design

### 14.1 Empty Database (First Run)
- Onboarding overlays guide the user through: language → currency → first ledger → first contact
- All home screens show illustrated empty states with breathing lapis-glow CTAs

### 14.2 Massive Numbers
- Amounts > 999,999,999.99 truncate with abbreviation tooltip: `1.2B` with full value on long-press
- Balance card uses `FittedBox(scaleDown)` to prevent overflow

### 14.3 Tiny Amounts
- Sub-decimal amounts (0.01) always show full precision per currency `decimalPlaces`
- Currencies with 0 decimals (YER) never show `.00`

### 14.4 Free-Tier Limit Reached
- Inline banner above the action button: warning container, upgrade CTA
- Action remains visible but disabled with helper text
- Never a blocking modal

### 14.5 Connectivity Loss
- Subtle pill banner top of screen: "وضع عدم الاتصال — Offline" with info styling (lapis container)
- All offline-capable actions remain functional
- Cloud-only actions (Drive backup) queue automatically with retry indicator

### 14.6 Long Contact Names
- Truncate with ellipsis at 1 line in lists, 2 lines on detail screens
- Full name accessible via long-press tooltip / Semantics

### 14.7 Long Transaction Lists (10,000+)
- Pagination at 20 per page
- `findChildIndexCallback` for stable scroll
- `RepaintBoundary` on each row

### 14.8 Storage Full
- Pre-flight warning at < 100MB available
- Block backup creation at < 50MB available
- User-friendly message with action: "Free up space"

### 14.9 Crashed Restore
- After failed restore: offer "Restore from last backup" or "Start fresh (data lost)"

### 14.10 Locked Out (Forgotten PIN)
- PIN-only recovery (no destructive wipe — deferred)
- Subtle help link: "Contact Support" (deep-link to WhatsApp)

### 14.11 Currency Mismatch
- When a contact has balances in multiple currencies, the balance card shows per-currency chips
- Sum across currencies is NEVER computed

### 14.12 Time-Zone Edge Cases
- All timestamps stored in UTC; displayed in user's local time zone
- Date grouping headers use local time zone semantics

---

## 15 · Microcopy & Voice

### 15.1 Voice Pillars

| Trait | Yes | No |
|---|---|---|
| **Plain** | "أضف ديناً جديداً" | "Initialize new debit instrument" |
| **Direct** | "حذف؟" | "Are you sure you want to delete this item?" |
| **Warm** | "بياناتك آمنة على Google Drive" | "Backup operation successful" |
| **Action-led** | "إنشاء دفتر" | "Ledger Management" |
| **Merchant-native** | "عليه" / "له" | "Receivable" / "Payable" |

### 15.2 Localization Rules

- All strings live in ARB (`app_ar.arb` primary, `app_en.arb` mirror)
- Keys are camelCase: `createLedger`, `confirmDeleteContact`
- ICU pluralization for counts
- Never concatenate translated strings — interpolate parameters
- Never abbreviate critical financial terms

### 15.3 Error Messages

- Always actionable. Tell the user what went wrong AND what to do
- ❌ "Network error"
- ✅ "تعذّر الاتصال بـ Google Drive. تأكد من الإنترنت وحاول مجدداً."

### 15.4 Confirmation Copy

- Destructive actions: "حذف؟" + body explaining what's lost + "حذف" / "إلغاء" buttons
- Never trivialize loss. Be specific: "سيتم حذف 17 حركة. هذا الإجراء لا يمكن التراجع عنه."

---

## 16 · Premium / Trust Markers (Glow as Currency)

### 16.1 The Glow-as-Currency Doctrine

In Khazna v3, premium-tier markers do not require a new color (gold/brass eliminated). The **lapis glow itself becomes the premium currency**. The merchant literally sees their data glow when they upgrade.

| Tier | Card Treatment | Card Border | Card Halo | Bottom-Nav Active |
|---|---|---|---|---|
| **Free** | Standard `glowAmbient` (dark) / `shadowFloat` (light) | `0.5px borderSubtle` | none | 2dp `lapis400` stripe (the tab is the brand touch) |
| **Pro** | Standard + `glowSm` lapis halo | `0.5px borderSubtle` | `glowSm` | (same) |
| **Pro+** | Standard + `glowMd` lapis halo + start-edge hairline | `0.5px lapis400` at start edge | `glowMd` | (same) |

The price tier becomes **visually obvious** — Pro users see a quiet sapphire breath around their balance card; Pro+ users see a full lapis luminescence.

### 16.2 Pro / Pro+ Feature Markers

When a feature is gated behind a tier, the marker appears on the feature's icon/label:

| Marker | Spec | Appears On |
|---|---|---|
| **Pro badge** | Pill chip: `surface3` fill + `0.5px lapis400` border + `glowXs` halo + label "Pro" `titleSmall` `inkPrimary` | Feature labels in Settings, paywall comparison |
| **Pro+ badge** | Pill chip: `surface3` fill + `0.5px lapis400` border + `glowSm` halo + label "Pro+" `titleSmall` `inkPrimary` | Feature labels in Settings, paywall comparison |

### 16.3 Trust Signals (Security Copy)

Place explicit trust signals on screens where users entrust data. Lapis is used as text color ONLY inside these info banners (it is the brand voice).

- **Backup screens:** "🔒 مشفّر بـ AES-256 على جهازك"
- **Cloud backup:** "📁 يُحفظ في مجلد Daftar الخاص في Google Drive — لا يطّلع عليه أحد غيرك."
- **PIN screens:** "🛡️ يُستخدم محلياً فقط — لا يُرسل إلى أي خادم."

These appear inside info banners — lapis container background + lapis icon + lapis text + lapis hairline.

### 16.4 Onboarding First Impression

- **Splash:** pure `surface0` (true black), centered Khazna wordmark fades in over 400ms with `glowXl` halo (the single hero glow moment of the entire app's lifetime)
- **Onboarding 3 screens:** each shows ONE benefit with a monochrome illustration, headline, body, single Primary CTA with breathing lapis glow. Skippable
  1. "نظّم ديونك بسهولة"
  2. "نسخ احتياطي على Google Drive"
  3. "شارك كشف الحساب عبر WhatsApp"

### 16.5 Tier Upgrade Celebration

When a merchant activates Pro / Pro+:

1. Success bottom sheet appears with full-width Primary CTA
2. `heavyImpact` haptic
3. The entire balance card on Home now wears the new glow tier — animated transition: previous halo `glowAmbient` only → new halo includes `glowSm`/`glowMd` lapis layer (600ms `curveEmphasized`)
4. `lightImpact` haptic at 200ms (paired with halo expansion peak)
5. Optional snackbar: "أهلاً بك في Pro+ — استمتع بكل المزايا" (Welcome to Pro+ — enjoy all features)

This is the single most theatrical moment in the app. The merchant experiences the upgrade as *the world becoming luminous*.

---

## 17 · Quality Gates — Rejection Criteria

A screen, component, or PR MUST be rejected if any of the following is true:

| # | Defect |
|---|---|
| 1 | Hardcoded `Color(0xFF…)` outside `AppColors` |
| 2 | Inline `TextStyle(...)` outside `AppTextStyles` |
| 3 | Inline `EdgeInsets.left/right`, `Alignment.centerLeft/Right`, `TextAlign.left/right` |
| 4 | Missing tabular figure rendering on a monetary amount |
| 5 | Missing shimmer skeleton for any async data load |
| 6 | A blank screen during initial load |
| 7 | `CircularProgressIndicator()` as primary loading state |
| 8 | Hardcoded user-facing string not from ARB |
| 9 | Missing haptic feedback on save / delete / PIN / amount-pad |
| 10 | Tap target < 48dp |
| 11 | Missing entrance animation on list screens |
| 12 | Default Material `Card`, `ListTile`, `AlertDialog`, `SnackBar` |
| 13 | Repository called directly from a provider (bypassing Use Case) |
| 14 | `drift` import in `presentation/` |
| 15 | Non-directional icon that should flip in RTL is not flipping |
| 16 | Symmetric icon (e.g., `close`, `search`) being flipped in RTL |
| 17 | Balance amount rendered in Noto Kufi Arabic font |
| 18 | Missing empty state when data list is empty |
| 19 | Missing error state with retry action for fallible operations |
| 20 | `ListView(children: [...])` for any dynamic list |
| 21 | Missing `const` constructor where supported |
| 22 | Non-token `withOpacity(…)` value |
| 23 | Drop shadows on dark-mode surfaces |
| 24 | `Curves.linear` for any UI motion |
| 25 | Color used as the sole indicator of state |
| 26 | Debt/payment color semantics reversed |
| 27 | Sub-grid violation (e.g., 7dp, 13dp, 21dp padding) |
| 28 | **Lapis used as a fill color** (background of any card/sheet/button/chip — info banner excepted) |
| 29 | More than ONE lapis-glow moment on a single visible screen |
| 30 | RTL geometry broken (verify with Translation Stress Tests §12.6) |
| 31 | Screen reader semantics missing on a financial-critical element |
| 32 | **Any chromatic color other than lapis, debt-red, payment-green, warning-amber, or avatar-set** |
| 33 | **Gold, brass, teal, indigo, or any past brand color in any form** |
| 34 | **Floating card without inner top highlight on dark mode** |
| 35 | **Lapis glow applied to chart fills (only strokes + sparkline gradient-to-transparent allowed)** |
| 36 | **Lapis-colored text outside info banners** |
| 37 | Gradient on a content surface (Hero Balance Card vignette excepted) |
| 38 | **`glowAmbient` paired with a Material drop-shadow on dark mode** (mutually exclusive techniques) |

---

## 18 · Token Reference (Quick Lookup)

### 18.1 Color

```
Monochrome (Onyx — dark):
  surface0..6 → black, +6 luminance per step
  inkPrimary | Secondary | Muted | Disabled
  borderSubtle | borderStrong
  scrim (0.78) | glassFill | glassBorder

Monochrome (Bone — light):
  surface0..4 → bone parchment, gradually deeper
  inkPrimary | Secondary | Muted | Disabled
  borderSubtle | borderStrong
  scrim (0.52) | glassFill | glassBorder

Luminous Lapis (light, NEVER paint):
  lapis50..900 + lapis400 (THE LAPIS) + lapisLumen (dark CTA variant)

Semantic (the only other chroma):
  debt | payment | warning | info | success | error
  + container variants + on-color variants

Alpha (named opacities):
  alphaHairline (0.04) → alphaOpaque (1.00)
```

### 18.2 Glow Tokens (The Crown Jewels)

```
glowXs (0 0 4 0.20) → hairline hover
glowSm (0 0 8 0.28) → Pro card resting
glowMd (0 0 16 0.36) → Primary CTA resting, Pro+ card
glowLg (0 0 24 0.44) → CTA focused/pressed
glowXl (0 0 48 0.36) → Hero brand mark
glowAmbient (0 8 32 lapis900 @ 0.72) → Floating card on dark
glowBreath (animated Sm ↔ Md, 2.4s) → Awaiting CTAs
```

### 18.3 Spacing (4pt sub-grid / 8pt primary)

```
spacingXxs (2) | Xs (4) | Sm (8) | Md (12) | Lg (16) | Xl (20) | Xxl (24)
spacing3xl (32) | 4xl (40) | 5xl (48) | 6xl (64)
```

### 18.4 Radius

```
radiusXs (4) | Sm (8) | Md (12) | Lg (16) | Xl (24) | 2xl (32) | Circular (999)
```

### 18.5 Shadow (light mode only)

```
shadowSoft | shadowFloat | shadowElevated | shadowDeep
```

### 18.6 Tap Targets

```
minTapTarget (48) | comfortableTapTarget (56) | largeTapTarget (64)
```

### 18.7 Icons

```
iconXs (12) | Sm (16) | Md (24) | Lg (32) | Xl (48) | Hero (96)
```

### 18.8 Motion

```
Duration: animationInstant (80) | Fast (150) | Medium (300) | Slow (450)
          | XSlow (600) | Onboard (900) | Breath (2400)
Curve:    curveEnter | curveExit | curveStandard | curveEmphasized
          | curveSpring | curveAnticipate | curveSheetSpring | curveBreath
```

### 18.9 Type Scale (sp)

```
Arabic:   display{L,M,S} (34/28/24) | headline{L,M} (22/20)
          title{L,M,S} (18/16/14) | body{L,M,S} (16/14/12) | label{L,M,S} (14/12/11)
Numerals: amount{Hero,Large,Medium,Small,Micro} (40/32/18/14/12)
          numeralInput (28) | numeralCaption (11)
```

### 18.10 Font Features (Numerals)

```
FontFeature.tabularFigures()    // tnum
FontFeature.liningFigures()     // lnum
```

### 18.11 Haptics

```
HapticFeedback.lightImpact() | mediumImpact() | heavyImpact() | selectionClick()
```

### 18.12 Borders

```
borderHairline (0.5) | borderDefault (1.0)
borderLapisHairline (0.5 lapis400) | borderLapisFocus (1.5 lapis400)
borderError (1.5) | borderSuccess (1.5)
borderGlass (0.5)
```

---

## Appendix A · Implementation Mapping (Existing Tokens)

This document is the source of truth. The existing Dart token files map as follows:

| Document Section | Dart File | Status |
|---|---|---|
| §2 Color (monochrome + lapis + semantic) | `lib/app/theme/app_colors.dart` | 🔄 **Major rewrite required** (remove gold/teal scale, add monochrome scale, add lapis scale, add `inkPrimary..Disabled`) |
| §3 Typography | `lib/app/theme/app_text_styles.dart` | 🔄 Add `amountHero` (40), `amountMicro` (12), `numeralCaption` (11), `FontFeature.tabularFigures` to all numeral styles |
| §4 Spacing / §5.1 Radius / §6.2 Icons / §7.2 Motion Durations | `lib/app/theme/app_dimensions.dart` | 🔄 Add `animationInstant` (80), `animationOnboard` (900), `animationBreath` (2400) |
| §5.3 Light shadows | New file `lib/app/theme/app_shadows.dart` | 🆕 To add |
| §2.5 Lapis glow tokens | New file `lib/app/theme/app_glows.dart` | 🆕 To add |
| §7.3 Curves | New file `lib/app/theme/app_motion.dart` | 🆕 To add |
| §7.5 Haptics | New helper `lib/core/utils/haptic_service.dart` | 🆕 To add |

> **Implementation note for future PRs:** Any new design token added to the codebase MUST first be added here, then to the relevant Dart file. Tokens cannot exist in code without specification in this document.

---

## Appendix B · Glossary

| Term | Meaning |
|---|---|
| **Khazna** (خزنة) | Codename of the Daftar design system — "the vault" |
| **Lapis Lux** | The Khazna v3 palette — "blue light" — monochrome canvas + luminous lapis accent |
| **Tahqīq** (تَحقِيق) | Trust through clarity — Khazna principle #1 |
| **Waqār** (وَقَار) | Luxury through restraint — principle #2 |
| **Salāsa** (سَلاسَة) | Depth through light — principle #3 |
| **Iḥkām** (إِحكَام) | Confidence through craft — principle #4 |
| **Onyx** | Dark neutral scale (`surface0–6`) |
| **Bone Parchment** | Light neutral scale (`surface0–4` in light mode) |
| **Luminous Lapis** | The single brand color (`lapis400` = `#0356C5`) — used ONLY as light |
| **Khazna Float** | The three-layer floating-card technique (glowAmbient + border + inner highlight) on dark mode |
| **Lapis Glow Border** | A `0.5px lapis400` border + lapis halo around the single primary CTA per screen |
| **Glow as Currency** | The Pro/Pro+ tier visual differentiation system — glow intensity = tier |
| **Tabular figures** | Equal-width digit rendering (`FontFeature.tabularFigures()`) |
| **Glass surface** | Translucent surface with `BackdropFilter` blur — see §5.6 |
| **Sub-grid** | The 4pt micro-grid nested within the 8pt primary grid |
| **Stress test** | Mandatory pre-acceptance check (translation length, locale flip, scale 1.5×, glow geometry) |

---

> **END OF DOCUMENT**
>
> This is a living specification. Record design-system changes in [`docs/project_log.md`](project_log.md).
