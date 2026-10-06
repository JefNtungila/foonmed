import 'package:flutter/material.dart';

import 'colours.dart';

/// The single Foon theme.
///
/// Material 3 components driven by the explicit M2-style [FoonColours.colorScheme]
/// (never `colorSchemeSeed`).
class FoonTheme {
  FoonTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: FoonColours.colorScheme,
    );
  }
}
