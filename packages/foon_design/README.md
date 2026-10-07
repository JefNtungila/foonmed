# foon_design

The Foon design system as code: colour tokens, theme, typography, spacing and
shared components. Every Foon app (FoonCash, FoonMed, future sectors) consumes
this package so the brand stays identical across sectors.

Full specification: [`docs/DESIGN_SPEC.md`](../../docs/DESIGN_SPEC.md).

## Install

```yaml
# pubspec.yaml (path dependency while developing)
dependencies:
  foon_design:
    path: ../foonmed/packages/foon_design

# or via git once published
dependencies:
  foon_design:
    git: { url: <foonmed-repo-url>, path: packages/foon_design }
```

## Quick start

```dart
import 'package:foon_design/foon_design.dart';

MaterialApp(
  theme: FoonTheme.light(),
  home: const MyHome(),
);
```

## What's inside

| Export | Contents |
|---|---|
| `FoonColours` | Core brand tokens + neutral tokens + the M2-style `ColorScheme` |
| `FoonTheme` | `FoonTheme.light()` |
| `FoonTextStyles` | Display/title/heading/body/label/caption roles |
| `FoonSpacing` `FoonRadii` `FoonElevation` `FoonSizes` | Layout geometry |
| `FoonPillButton` | 250 x 50 pill action (home tiles) |
| `FoonCtaButton` | Full-width 55-high CTA |
| `FoonCard` | Hero info card with action strip |
| `FoonTextField` | Outlined 55-high field |
| `FoonTopBar` | Wordmark app bar |
| `FoonIconButton` | App-bar action (48 dp target) |
| `FoonBottomNav` | Labelled dark bottom navigation |
| `FoonEmptyState` | Icon + title + message placeholder |

Rules that must not be broken: no raw hex in screens, no `colorSchemeSeed`, no green/blue
control fills (state is never hue-coded), Font Awesome icons only through `FaIcon`,
no fixed-width spacers inside rows.
