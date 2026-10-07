

# Foon Design Specification

**Version 1.1 · Applies to every Foon app (FoonCash, FoonMed, and future sectors)**
Implementation lives in `packages/foon_design` (this repo). Apps consume that package — this document is the visual and behavioural reference.

---

## 1. Brand

### 1.1 Wordmark

|  |  |
| --- | --- |
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
| --- | --- | --- |
| `primary` | `#393A3E` | Grey-black. Dark buttons, icon strips, emphasis text, bottom nav |
| `secondary` | `#F69520` | **Foon orange.** CTAs, selected nav, progress, accent text |
| `surface` | `#FFFFFF` | **Rendered page background (light mode).** M3 derives the scaffold, app bar, canvas, cards and dialogs from this token, so pages read as white |
| `background` | `#636363` | Legacy M2 page-background token — retained for parity, not rendered by default under M3 |
| `onBackground` | `#F69520` | Content colour on `background` |
| `onSecondary` | `#322942` | Content on orange (rare) |
| `onSurface` | `#241E30` | Body text |
| `error` / `onError` | `Colors.redAccent` | Errors, destructive actions |
| `onPrimary` | `Colors.redAccent` | Kept from the original FoonCash scheme (parity requirement) |

### 2.2 Neutral tokens — `FoonColours`

Fixed values, identical in all apps. Never hardcode a raw hue for state.

| Token | Hex | Use |
| --- | --- | --- |
| `neutralLight` | `#E0E0E0` | Empty cells, dividers, disabled fills |
| `neutralText` | `#757575` | Muted icons and secondary text |
| `onSemantic` | `#FFFFFF` | Text/icons on `primary` fills |

> **v1.1 — green/blue removed.** The previous semantic fills (`success`, `successContainer`,
> `warning`, `info`, `infoContainer`, `infoStrong`) are **deleted from `FoonColours`**.
> Controls, progress, nav and data cells use core brand tokens only (`secondary` orange,
> `primary` grey-black, plus the neutrals above). State is carried by the label, icon and
> copy — never by hue.

### 2.3 Gradient/alpha rules

* Intensity fills blend `secondary` **into their base fill** — `neutralLight` for grid cells —
  with `Color.lerp` (or `withValues(alpha: …)` over a page/card), **capped at 0.60** whenever
  text sits on top, so labels keep ≥ 9:1. Low end 0.15. The ramp must stay *darker or more
  saturated* than its base: a measured cell may never read lighter than an empty one.
* Never cross-fade brand hues into a decorative gradient (orange × grey gradients are
  forbidden); the intensity ramp above is the only sanctioned blend.

### 2.4 Scheme construction (M2-style, kept as-is)

Foon apps pass an explicit `ColorScheme` — **not** `colorSchemeSeed`. The deprecated
`background`/`onBackground` members are part of the contract and are intentionally kept for
cross-app parity; the resulting `deprecated_member_use` infos are expected, not defects.

```dart
final ColorScheme colorScheme = ColorScheme(
  primary: FoonColours.primary,
  secondary: FoonColours.secondary,
  background: Color(0xFF636363),
  surface: Color(0xFFFFFFFF),
  onBackground: FoonColours.secondary,
  error: Colors.redAccent,
  onError: Colors.redAccent,
  onPrimary: Colors.redAccent,
  onSecondary: Color(0xFF322942),
  onSurface: Color(0xFF241E30),
  outline: FoonColours.primary,
  outlineVariant: FoonColours.neutralLight,
  brightness: Brightness.light,
);

```

Consumed exactly once, via:

```dart
MaterialApp(theme: FoonTheme.light(), home: …)

```

Dark mode is **out of scope** for v1 (spec'd later as `FoonTheme.dark()`).

> **Rendered result (verified on screen):** with `useMaterial3: true`, the scaffold, app bar,
> canvas and dialogs all resolve from `surface` (`#FFFFFF`), the `LinearProgressIndicator`
> track from `secondary` with its fill from `primary`, and buttons carry their explicit fills.
> Pages therefore read as **white with orange accents — light mode** — with grey-black chrome
> (`primary`) and no second hue anywhere.

`outline`/`outlineVariant` are set explicitly (grey-black / `neutralLight`) because their
implicit fallbacks derive from `onBackground`, which would put **orange** hairlines and
dividers on the white page.

### 2.5 Contrast requirements

| Foreground | Background | Min ratio |
| --- | --- | --- |
| `primary` | `secondary` (CTA label on orange) | 5.0:1 |
| `secondary` | `primary` (strip/emphasis on grey-black) | 5.0:1 |
| `onSemantic` | `primary` (chrome, nav, strips) | 11.4:1 |
| `onSurface` | white page / white card | 16.2:1 |
| `primary` | `neutralLight` cell (index numbers) | 8.6:1 |
| `onSurface` @ w600 | `secondary` ramp over `neutralLight`, t 0.15–0.60 | ≥ 9:1 |
| `neutralText` | white page (muted icons, secondary labels) | 4.6:1 |

If a pair fails, change the **surface**, not the brand hues.

> `secondary` is a **fill / label-on-dark** token: orange text on the white page is
> 2.3:1 and is forbidden below 24 px. The single sanctioned exception is the §7.3 hero value
> (50 bold on a white card), which always ships with a `primary` caption. Elsewhere use
> `onSurface` (body) or `neutralText` (muted); orange appears as button fills, strips,
> progress and large emphasis on `primary`.
> A white control on the white page always needs an edge — a `neutralLight` hairline
> (`FoonCard`) or a dark label fill (CTA, action strip).

---

## 3. Typography

Stock **Roboto** only (Material default). No custom fonts, no `GoogleFonts`, no `fontFamily`
overrides — cross-sector consistency beats novelty.

| Role | Size | Weight | Typical use |
| --- | --- | --- | --- |
| Display | 50 | bold | Hero values (balance, headline metric) |
| Title | 30 | bold | Screen titles, welcome headings |
| Heading | 22 | bold | Section titles, CTA labels |
| Subheading | 18 | bold | Card action labels |
| Body | 16 | normal/bold | Instructions, button text |
| Label | 14 | normal | Bottom-nav labels, secondary UI |
| Caption | 10 | bold | Card micro-labels ("Balance") |

Rules:

* Two weights only: `normal` and `bold`. (`w600` allowed for 11 px numeric cells.)
* Long-form legal text (TOS/SMS): 22 normal, `TextSpan` links underlined in `secondary`.
* Text colour comes from the scheme: `onSurface` on light cards, `secondary` for emphasis,
  `onSemantic` on dark/semantic fills.

---

## 4. Spacing & layout

4 dp base grid; use these steps only:

`4 · 8 · 10 · 16 · 24 · 30 · 40 · 50 · 75 · 100`

| Value | Meaning |
| --- | --- |
| 8 / 10 | Gap between siblings inside a group |
| 15 | Screen-level card margin |
| 16 | Default screen padding (dense/technical screens) |
| 24 | Gap between groups |
| 25 | Screen gutter (`FoonSpacing.gutter`) |
| 30 / 40 | Section separation |
| 50 | Major section break, hero spacing |
| 75 / 100 | Splash/welcome breathing room |

Fixed geometry:

* **CTA button:** `height 55`, `width = screenWidth − 50` (i.e. gutter 25 each side)
* **Pill button:** `250 × 50`, `padding vertical 16`
* **Card:** `350 × 200`
* **Text field:** `height 55`, inner padding 25
* Overflow rule: any scrollable content must sit in a `SingleChildScrollView` (or be
  `Expanded`/`Spacer`-balanced) — render overflow is a bug, not a cosmetic issue.

---

## 5. Shape & elevation

| Token | Value | Use |
| --- | --- | --- |
| `FoonRadii.card` | 10 | Cards, inputs, dialogs |
| `FoonRadii.pill` | 30 | Pill/rounded buttons |
| `FoonRadii.cell` | 6 | Dense grid cells |
| `FoonElevation.raised` | 5 | Raised pill buttons |
| Strip | 0 (square) | Coloured action strips inside cards |

---

## 6. Iconography

Three approved sources, never emoji:

1. **Material `Icons**` — UI chrome, states, empty states.
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

* **Dimensions:** `250 × 50`
* **Container & Surface:** `Material(borderRadius: FoonRadii.pill (30), elevation: FoonElevation.raised (5), color: FoonColours.secondary)`
* **Background Fill:** `FoonColours.secondary` (`#F69520` — Foon orange)
* **Label Text:** Size 16 bold, explicitly colored `FoonColours.primary` (`#393A3E` — grey-black)
* **Icon:** Leading 512 px PNG icon (padding `30/20/5/5`), explicitly tinted using `color: FoonColours.primary` (`#393A3E`)
* **Interaction:** No splash effect (`transparent` highlight, hover, focus, and splash colors).

### 7.2 `FoonCtaButton`

Full-width CTA action button.

* **Dimensions:** `height 55`, width `screenWidth − 50` (gutter 25 each side)
* **Container & Surface:** `ElevatedButton` with `borderRadius: FoonRadii.card (10)`
* **Background Fill:** Explicitly set to `FoonColours.secondary` (`#F69520` — Foon orange) via `styleFrom(backgroundColor: FoonColours.secondary)`
* **Label Text:** Size 22 bold, explicitly colored `FoonColours.primary` (`#393A3E` — grey-black) via `foregroundColor: FoonColours.primary`
* **Disabled State:** Follows standard M3 disabled defaults.

### 7.3 `FoonCard`

Info card (balance/hero metrics).
`350 × 200` white, `radius 10`, `margin 15`, **1 px `neutralLight` border** (the page is white
too, so the card needs an edge), content bottom-aligned:

* header: caption (10 bold, `primary`) left + optional trailing widget right, `Spacer` between
  (**never fixed-width gaps** — they overflow)
* hero value: 50 bold `secondary`, `maxLines: 1` inside a `FittedBox(scaleDown)` so long
  values shrink instead of wrapping and overflowing the fixed 200 height
* action strip: full-width `height 50`, background `primary`, `FaIcon` (30, `secondary`) +
  label (18 bold `secondary`), radius 10 bottom corners only.

### 7.4 `FoonTextField`

`height 55` · border `1 px primary`, `radius 10` · inner horizontal padding 25 ·
hint/label from theme, `InputBorder.none` inside the decorated box.

### 7.5 `FoonTopBar`

`AppBar` hosting the wordmark instead of a text title: logo `height 38`
(`Image(image: …, semanticLabel: 'Foon<sector>')`), left-aligned (Android default),
background follows the theme (`surface`, i.e. the same white as the page — no divider, no
elevation shadow). Optional trailing actions via `FoonIconButton`. The screen's purpose stays
in the semantic label (e.g. `'FoonMed — Contact Vibration Scan'`).

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

Flow actions that encode state (`START SCAN`, `CAPTURE BASELINE`, `MEASURE CELL`,
`COPY JSON`, `NEW SCAN`, `START OVER`) are `FoonCtaButton` instances — **orange fill,
grey-black 22-bold label** (§7.2) — whatever the step. State is carried by the label and
the surrounding copy, never by hue: **no green, blue or red control fills** (state-hue
coding does not exist in v1).

Secondary / cancel actions (`Cancel`, `Abort`, `Retake last`) are `TextButton` with an
explicit `foregroundColor: FoonColours.onSurface` and `textStyle: FoonTextStyles.body` —
never a raw `Colors.*` and never a bare M3 default. A destructive action that genuinely
needs emphasis uses `FoonColours.error`.

---

## 8. Motion

v1 baseline — subtle, never blocking:

* state change / colour: **150 ms**
* sheet/dialog entrance: **300 ms**
* curves: `Curves.easeInOut` (standard), `Curves.easeOut` (exits)
* haptics: `HapticFeedback.selectionClick()` on discrete step changes only
* no parallax, no looping animation on data screens; respect `disableAnimations`.

---

## 9. Accessibility

* Contrast per §2.5 — enforced for every text/surface pair.
* Minimum touch target **48 × 48 dp** (icon-only buttons must use `FoonIconButton`/`InkWell`).
* Never colour-only meaning: pair colour with an icon/label (e.g. orange cell + ✓).
* Respect system text scaling; layouts must survive 130 % without overflow (see §4 overflow rule).
* Images of text are forbidden; logos get `Semantics` labels.

---

## 10. Engineering conventions

| Topic | Rule |
| --- | --- |
| Tokens | Import `package:foon_design/foon_design.dart`. **No raw hex in `lib/screens` or `lib/ui**` — add a token to the package instead |
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
**Don't** introduce a second accent hue · colour-code state green/blue/red · set `colorSchemeSeed` · use raw `Colors.*` in UI
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
6. Replace every raw colour with `FoonColours` tokens (§2.2 for neutrals; never hue-code state — §7.9).
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
| --- | --- |
| `colorSchemeSeed: Colors.teal` | `FoonTheme.light()` |
| AppBar text `'Contact Vibration Scan'` | `FoonTopBar` with `assets/foonmed_logo_transparent.png` |
| `Colors.green` action buttons | `FoonCtaButton` (orange fill, grey-black label) |
| `Colors.blue` step buttons | `FoonCtaButton` (same orange — steps are not hue-coded) |
| `blue.shade400` active cell | `FoonColours.secondary` fill |
| `blue.shade900` active border | `FoonColours.primary` |
| `green.shade300` visited cell | `Color.lerp(neutralLight, secondary, 0.45)` |
| heatmap `green @ α` | `Color.lerp(neutralLight, secondary, t)`, t 0.15–0.60 (labels ≥ 9:1) |
| `grey.shade300` empty cell | `FoonColours.neutralLight` (identical hex) |
| `grey.shade600` cell index | `FoonColours.primary` (8.6:1 on the cell; was `neutralText` at 3.5:1) |
| `Colors.grey` empty-state icon | `FoonColours.neutralText` |
| `surface` page `#808080` (mid-grey) | `surface` `#FFFFFF` — white page, light mode |
| white card with no edge | 1 px `FoonColours.neutralLight` border on `FoonCard` |
| local `_MessageView` | `FoonEmptyState` |
| raw hex / bare M3 button defaults | explicit `FoonColours` / `FoonTextStyles` styles |

> Intermediate step (superseded): `Colors.green`/`Colors.blue` were first migrated to
> `FoonColours.success`/`info`. **v1.1 deleted those tokens** — the flow is now orange
> throughout, per §2.2 and §7.9. v1.1 also moved the page from mid-grey to white (§2.1),
> so every measured cell is blended into `neutralLight` rather than composited over the
> page. |