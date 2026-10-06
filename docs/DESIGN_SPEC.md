# Foon Design Specification

**Version 1.0 · Applies to every Foon app (FoonCash, FoonMed, and future sectors)**
Implementation lives in `packages/foon_design` (this repo). Apps consume that package — this document is the visual and behavioural reference.

---

## 1. Brand

### 1.1 Wordmark

| | |
|---|---|
| Canonical asset | `assets/foonmed_logo_transparent.png` (890 × 631, RGBA, transparent) |
| Cash reference | `fooncash/assets/fooncash_logo_transparent.png` (3152 × 2234, RGBA, transparent) |
| Construction | Sector word (`Foon` + sector) set in brand **orange**, spork/cutlery motif in **grey**, no other hues |
| Format | Transparent PNG (SVG preferred if ever re-drawn). Never place the logo on a coloured plate — it is designed for light or mid-grey backgrounds |
| Minimum size | 24 px tall in-app (below this, use the sector name as text) |
| Clear space | ≥ 25 % of the logo's height on all sides |
| Don'ts | No recolouring, no stretching, no drop shadows, no rotating the spork, no outlines |

### 1.2 Declaration rule

Any Foon app using imagery **must** declare it, or the asset silently fails to load:

```yaml
# pubspec.yaml
flutter:
  uses-material-design: true
  assets:
    - assets/
```

### 1.3 Launcher icons

Source art must be square ≥ 1024 px. Generate all densities with `flutter_launcher_icons`
(`adaptive_icon_background` = `#F69520`, foreground = the spork/wordmark). Keep the stock
Flutter icon until square art exists — landscape logos get cropped by adaptive masks.

### 1.4 Naming

App name = `Foon` + lowercase sector (`fooncash`, `foonmed`, `foonlegal`…). Display name =
`Foon` + Capitalised sector (`FoonCash`, `FoonMed`).

---

## 2. Colour

**Strict single palette.** Every Foon app uses identical values — no sector variation, no
`colorSchemeSeed`, no ad-hoc `Colors.*` in screens.

### 2.1 Core tokens — `FoonColours`

| Token | Hex | Role |
|---|---|---|
| `primary` | `#393A3E` | Grey-black. Dark buttons, icon strips, emphasis text, bottom nav |
| `secondary` | `#F69520` | **Foon orange.** CTAs, selected nav, progress, accent text |
| `surface` | `#808080` | **Rendered page background.** M3 derives the scaffold and app bar from this token, so pages read as mid-grey |
| `background` | `#636363` | Legacy M2 page-background token — retained for parity, not rendered by default under M3 |
| `onBackground` | `#F69520` | Content colour on `background` |
| `onSecondary` | `#322942` | Content on orange (rare) |
| `onSurface` | `#241E30` | Body text |
| `error` / `onError` | `Colors.redAccent` | Errors, destructive actions |
| `onPrimary` | `Colors.redAccent` | Kept from the original FoonCash scheme (parity requirement) |

### 2.2 Semantic tokens — `FoonColours`

Fixed values, identical in all apps. Never hardcode a raw hue for state.

| Token | Hex | Use |
|---|---|---|
| `success` | `#2E7D32` | Positive state buttons/fills — **white** text (5.6:1) |
| `successContainer` | `#A5D6A7` | Light positive surface — dark text |
| `warning` | `#F9A825` | Caution fills — dark text |
| `info` | `#1565C0` | Neutral action buttons — **white** text (5.9:1) |
| `infoContainer` | `#42A5F5` | Highlighted/active cell or chip |
| `infoStrong` | `#0D47A1` | Borders and high-emphasis info |
| `neutralLight` | `#E0E0E0` | Empty cells, dividers, disabled fills |
| `neutralText` | `#757575` | Muted icons and secondary text |
| `onSemantic` | `#FFFFFF` | Text/icons on `success`/`info`/`primary` fills |

### 2.3 Gradient/alpha rules

- Heatmaps and intensity fills blend `success` (or any token) over white with
  `withValues(alpha: …)`, **capped at 0.60** whenever text sits on top, so black labels keep
  ≥ 4.5:1. Low end 0.15.
- Never blend two brand tokens together (orange × grey is forbidden).

### 2.4 Scheme construction (M2-style, kept as-is)

Foon apps pass an explicit `ColorScheme` — **not** `colorSchemeSeed`. The deprecated
`background`/`onBackground` members are part of the contract and are intentionally kept for
cross-app parity; the resulting `deprecated_member_use` infos are expected, not defects.

```dart
final ColorScheme colorScheme = ColorScheme(
  primary: FoonColours.primary,
  secondary: FoonColours.secondary,
  background: Color(0xFF636363),
  surface: Color(0xFF808080),
  onBackground: FoonColours.secondary,
  error: Colors.redAccent,
  onError: Colors.redAccent,
  onPrimary: Colors.redAccent,
  onSecondary: Color(0xFF322942),
  onSurface: Color(0xFF241E30),
  brightness: Brightness.light,
);
```

Consumed exactly once, via:

```dart
MaterialApp(theme: FoonTheme.light(), home: …)
```

Dark mode is **out of scope** for v1 (spec'd later as `FoonTheme.dark()`).

> **Rendered result (verified on device):** with `useMaterial3: true`, the scaffold and the
> app bar both resolve from `surface` (`#808080`), `LinearProgressIndicator` and other
> accents from `secondary`, and buttons carry their explicit fills. Pages therefore read as
> mid-grey with orange accents — the same appearance as FoonCash.

### 2.5 Contrast requirements

| Foreground | Background | Min ratio |
|---|---|---|
| `#FFFFFF` | `success` / `info` | 4.5:1 (body), 3:1 (large ≥ 24 px) |
| `secondary` | `primary` / `background` | 3:1 (large labels), 4.5:1 body |
| `onSurface` | white card | 4.5:1 |
| black @ w600 | `success` @ α ≤ 0.60 | 4.5:1 |

If a pair fails, change the **surface**, not the brand hues.

---

## 3. Typography

Stock **Roboto** only (Material default). No custom fonts, no `GoogleFonts`, no `fontFamily`
overrides — cross-sector consistency beats novelty.

| Role | Size | Weight | Typical use |
|---|---|---|---|
| Display | 50 | bold | Hero values (balance, headline metric) |
| Title | 30 | bold | Screen titles, welcome headings |
| Heading | 22 | bold | Section titles, CTA labels |
| Subheading | 18 | bold | Card action labels |
| Body | 16 | normal/bold | Instructions, button text |
| Label | 14 | normal | Bottom-nav labels, secondary UI |
| Caption | 10 | bold | Card micro-labels ("Balance") |

Rules:
- Two weights only: `normal` and `bold`. (`w600` allowed for 11 px numeric cells.)
- Long-form legal text (TOS/SMS): 22 normal, `TextSpan` links underlined in `secondary`.
- Text colour comes from the scheme: `onSurface` on light cards, `secondary` for emphasis,
  `onSemantic` on dark/semantic fills.

---

## 4. Spacing & layout

4 dp base grid; use these steps only:

`4 · 8 · 10 · 16 · 24 · 30 · 40 · 50 · 75 · 100`

| Value | Meaning |
|---|---|
| 8 / 10 | Gap between siblings inside a group |
| 15 | Screen-level card margin |
| 16 | Default screen padding (dense/technical screens) |
| 24 | Gap between groups |
| 25 | Screen gutter (`FoonSpacing.gutter`) |
| 30 / 40 | Section separation |
| 50 | Major section break, hero spacing |
| 75 / 100 | Splash/welcome breathing room |

Fixed geometry:
- **CTA button:** `height 55`, `width = screenWidth − 50` (i.e. gutter 25 each side)
- **Pill button:** `250 × 50`, `padding vertical 16`
- **Card:** `350 × 200`
- **Text field:** `height 55`, inner padding 25
- Overflow rule: any scrollable content must sit in a `SingleChildScrollView` (or be
  `Expanded`/`Spacer`-balanced) — render overflow is a bug, not a cosmetic issue.

---

## 5. Shape & elevation

| Token | Value | Use |
|---|---|---|
| `FoonRadii.card` | 10 | Cards, inputs, dialogs |
| `FoonRadii.pill` | 30 | Pill/rounded buttons |
| `FoonRadii.cell` | 6 | Dense grid cells |
| `FoonElevation.raised` | 5 | Raised pill buttons |
| Strip | 0 (square) | Coloured action strips inside cards |

---

## 6. Iconography

Three approved sources, never emoji:

1. **Material `Icons`** — UI chrome, states, empty states.
   Sizes: 16 (in-row), 20 (active cell), 24 (default), 40 (nav/app-bar container), 48 (empty state).
2. **Font Awesome `font_awesome_flutter` ^11** — decorative feature glyphs only.
   **`FaIcon(...)` is mandatory.** Passing FA icons to `Icon(...)` breaks rendering in 11.x
   (`FaIconData` no longer implements `IconData`). Icons referenced as `FontAwesomeIcons.<name>`;
   deprecated aliases (e.g. `longArrowAltUp`) → use the current name (`upLong`).
3. **Hand-drawn PNG set** — 512 × 512, transparent, black outline style, for feature tiles and
   bottom-nav items (`pay`, `income`, `refund`, `home`, `transaction`, `location`…).
   Tint with `color:` rather than shipping recoloured files.

Rules: icons that carry meaning get a label (nav tiles, buttons); icons never carry meaning
alone — always pair with text or semantics.

---

## 7. Components

All ship in `package:foon_design`. Screens must not re-implement them.

### 7.1 `FoonPillButton`
Compact primary action (home tiles).
`250 × 50` · `Material(borderRadius: 30, elevation: 5, color: primary)` wrapping a
`TextButton` · background `secondary` · label 16 bold in `primary` · leading 512 px PNG icon
(padding `30/20/5/5`) · pressed: no splash splash (`transparent` highlight/hover/focus/splash).

### 7.2 `FoonCtaButton`
Full-width CTA. `height 55`, width `screen − 50` · `ElevatedButton` background `secondary` ·
label 22 bold in `primary` · shape radius 10 · disabled follows M3 defaults.

### 7.3 `FoonCard`
Info card (balance/hero metrics).
`350 × 200` white, `radius 10`, `margin 15`, content bottom-aligned:
- header: caption (10 bold, `primary`) left + optional trailing widget right, `Spacer` between
  (**never fixed-width gaps** — they overflow)
- hero value: 50 bold `secondary`, `maxLines: 1` inside a `FittedBox(scaleDown)` so long
  values shrink instead of wrapping and overflowing the fixed 200 height
- action strip: full-width `height 50`, background `primary`, `FaIcon` (30, `secondary`) +
  label (18 bold `secondary`), radius 10 bottom corners only.

### 7.4 `FoonTextField`
`height 55` · border `1 px primary`, `radius 10` · inner horizontal padding 25 ·
hint/label from theme, `InputBorder.none` inside the decorated box.

### 7.5 `FoonTopBar`
`AppBar` hosting the wordmark instead of a text title: logo `height 38`
(`Image(image: …, semanticLabel: 'Foon<sector>')`), left-aligned (Android default),
background follows the theme (`surface`, i.e. the same grey as the page — no divider).
Optional trailing actions via `FoonIconButton`. The screen's purpose stays in the semantic
label (e.g. `'FoonMed — Contact Vibration Scan'`).

### 7.6 `FoonIconButton`
App-bar action: 24 px glyph inside a **48 dp tap target** (accessibility minimum), sitting in
a 60 px slot so actions read as a 40 px box with 10 px breathing room. Default glyph colour
`onSemantic` (white); pass `colour: FoonColours.secondary` for emphasis.

### 7.7 `FoonBottomNav`
`BottomNavigationBar`: `type: fixed`, `backgroundColor: primary`,
`selectedItemColor: secondary`, `unselectedItemColor: white`, labels always visible at 14,
icons in 8 px padding, 512 px PNG sources. `selected/unselectedIconTheme` mirror the colours.

### 7.8 `FoonEmptyState`
Centred column: icon 48 `neutralText` · title (titleMedium) · message (centred body).
Used for aborted/error/placeholder states.

### 7.9 Buttons driven by state (app-local)
Flow actions that encode state (`START SCAN`, `CAPTURE BASELINE`, `COPY JSON`) use
`ElevatedButton` with **semantic** colours (`success` for start/continue, `info` for
step actions, `error` for destructive) and `onSemantic` text — never raw `Colors.green/blue`.

---

## 8. Motion

v1 baseline — subtle, never blocking:
- state change / colour: **150 ms**
- sheet/dialog entrance: **300 ms**
- curves: `Curves.easeInOut` (standard), `Curves.easeOut` (exits)
- haptics: `HapticFeedback.selectionClick()` on discrete step changes only
- no parallax, no looping animation on data screens; respect `disableAnimations`.

---

## 9. Accessibility

- Contrast per §2.5 — enforced for every text/surface pair.
- Minimum touch target **48 × 48 dp** (icon-only buttons must use `FoonIconButton`/`InkWell`).
- Never colour-only meaning: pair colour with an icon/label (e.g. green cell + ✓).
- Respect system text scaling; layouts must survive 130 % without overflow (see §4 overflow rule).
- Images of text are forbidden; logos get `Semantics` labels.

---

## 10. Engineering conventions

| Topic | Rule |
|---|---|
| Tokens | Import `package:foon_design/foon_design.dart`. **No raw hex in `lib/screens` or `lib/ui`** — add a token to the package instead |
| Naming | `FoonColours`, `FoonSpacing`, `FoonRadii`, `FoonTheme`, `FoonXxx` widgets (British spelling, matching the original constants) |
| Structure | `lib/ui` (or `lib/screens`) · `lib/components` only for app-specific widgets · shared widgets live in the package |
| State mgmt | `provider` (`ChangeNotifier` controllers) |
| Lints | `flutter_lints` (current major), `flutter analyze` = 0 errors |
| Fonts | none beyond Material defaults |
| Assets | `assets/` at app root, declared as `- assets/`, feature PNGs 512 × 512 transparent |
| Platform | minSdk 24 · target/compileSdk 36 · Material 3 components (`useMaterial3: true`) with the explicit `ColorScheme` from §2.4 |
| Tests | at least one widget smoke test per screen; package ships widget tests per component |
| Deps | `font_awesome_flutter ^11` (FaIcon only), `cupertino_icons`, `provider`, sector-specific packages |

**Do** reuse package components · keep orange for primary emphasis · keep grey-black for chrome.
**Don't** introduce a second accent hue · set `colorSchemeSeed` · use raw `Colors.*` in UI
files · pass FA icons to `Icon` · fixed-width spacers inside rows.

---

## 11. Adoption checklist (new sector app)

1. `flutter create --org <org> --project-name foon<sector> .`
2. Add dependency:
   ```yaml
   dependencies:
     foon_design:
       git: { url: <foonmed-repo-url>, path: packages/foon_design }
   ```
   (path dependency while iterating: `path: ../foonmed/packages/foon_design`)
3. `theme: FoonTheme.light()` in `MaterialApp` — delete any `colorSchemeSeed`.
4. `assets: - assets/` + drop the sector wordmark into `assets/`.
5. Swap app bar text title for `FoonTopBar(logo: AssetImage(...))`.
6. Replace every raw colour with `FoonColours` tokens (§2.2 for states).
7. Rebuild screens from §7 components; keep §4 geometry.
8. Regenerate launcher icons when square art exists (§1.3).
9. `flutter analyze && flutter test && flutter build apk --debug`, then verify on an emulator.

---

## Appendix A — FoonCash migration (pending)

FoonCash currently owns the reference constants but does not yet consume the package.

1. Add `foon_design` (git/path) to `fooncash/pubspec.yaml`.
2. Delete `lib/utilities/constants.dart`; replace `primaryColour`/`secondaryColour` with
   `FoonColours.primary`/`FoonColours.secondary`, `colorScheme` with
   `FoonColours.colorScheme`, `theme: ThemeData(colorScheme: colorScheme)` →
   `theme: FoonTheme.light()`.
3. Replace `HomeButton` → `FoonPillButton`, CTA `ElevatedButton` → `FoonCtaButton`,
   `BalanceCard` → `FoonCard`, bell/settings rows → `FoonIconButton`,
   `BottomNavigationBar` block → `FoonBottomNav`, AppBar logo → `FoonTopBar`.
4. Run the §11 checklist steps 6–9.

## Appendix B — FoonMed migration (applied)

| Before | After |
|---|---|
| `colorSchemeSeed: Colors.teal` | `FoonTheme.light()` |
| AppBar text `'Contact Vibration Scan'` | `FoonTopBar` with `assets/foonmed_logo_transparent.png` |
| `Colors.green` action buttons | `FoonColours.success` + `onSemantic` |
| `Colors.blue` step buttons | `FoonColours.info` + `onSemantic` |
| `blue.shade400` active cell | `FoonColours.infoContainer` (identical hex) |
| `blue.shade900` active border | `FoonColours.infoStrong` (identical hex) |
| `green.shade300` visited cell | `success @ α 0.45` |
| heatmap `green @ α` | `success @ α 0.15–0.60` (keeps labels ≥ 4.5:1) |
| `grey.shade300` empty cell | `FoonColours.neutralLight` (identical hex) |
| `grey.shade600` cell index | `FoonColours.neutralText` (identical hex) |
| `Colors.grey` empty-state icon | `FoonColours.neutralText` |
| local `_MessageView` | `FoonEmptyState` |
