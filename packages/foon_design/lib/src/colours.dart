import 'package:flutter/material.dart';

/// The strict, single Foon palette.
///
/// Identical values are used in every Foon app - no sector variation and no
/// raw hex values in screen code. See `docs/DESIGN_SPEC.md` section 2.
class FoonColours {
  FoonColours._();

  // Core brand tokens -----------------------------------------------------
  /// Grey-black chrome: app bars, dark strips, emphasis text.
  static const Color primary = Color(0xFF393A3E);

  /// Foon orange: CTAs, selected navigation, progress, accent text.
  static const Color secondary = Color(0xFFF69520);

  /// Legacy M2 page-background token - retained for cross-app parity.
  /// Never rendered under M3; the page colour comes from [surface].
  static const Color background = Color(0xFF636363);

  /// Rendered page background (light mode): scaffold, app bar, canvas,
  /// dialogs and sheets all resolve from this token.
  static const Color surface = Color(0xFFFFFFFF);

  /// Content on [background].
  static const Color onBackground = secondary;

  /// Content on orange.
  static const Color onSecondary = Color(0xFF322942);

  /// Body text.
  static const Color onSurface = Color(0xFF241E30);

  /// Errors and destructive actions.
  static const Color error = Colors.redAccent;

  /// Content on [error].
  static const Color onError = Colors.redAccent;

  /// Content on [primary] (kept from the original FoonCash scheme).
  static const Color onPrimary = Colors.redAccent;

  // Neutral tokens --------------------------------------------------------
  /// Empty cells, dividers, disabled fills.
  static const Color neutralLight = Color(0xFFE0E0E0);

  /// Muted icons and secondary text.
  static const Color neutralText = Color(0xFF757575);

  /// Text/icons on [primary] fills.
  static const Color onSemantic = Colors.white;

  /// The M2-style scheme used by every Foon app.
  ///
  /// Built explicitly (never via `colorSchemeSeed`); the deprecated
  /// `background`/`onBackground` members are part of the contract and are
  /// intentionally kept for cross-app parity.
  static const ColorScheme colorScheme = ColorScheme(
    primary: primary,
    secondary: secondary,
    // Deprecated M2 members kept intentionally for cross-app parity (spec 2.4).
    // ignore: deprecated_member_use
    background: background,
    surface: surface,
    // ignore: deprecated_member_use
    onBackground: onBackground,
    error: error,
    onError: onError,
    onPrimary: onPrimary,
    onSecondary: onSecondary,
    onSurface: onSurface,
    // Hairlines, dividers and outlined borders: the implicit fallback for
    // `outlineVariant` is `onBackground` (orange), which is wrong on white.
    outline: primary,
    outlineVariant: neutralLight,
    brightness: Brightness.light,
  );
}
