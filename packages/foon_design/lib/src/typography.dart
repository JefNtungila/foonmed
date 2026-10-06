import 'package:flutter/material.dart';

import 'colours.dart';

/// Stock Roboto role scale - two weights only (normal and bold).
///
/// See `docs/DESIGN_SPEC.md` section 3.
class FoonTextStyles {
  FoonTextStyles._();

  /// Hero values (balance, headline metric) - 50 bold.
  static const TextStyle display = TextStyle(
    fontSize: 50,
    fontWeight: FontWeight.bold,
    color: FoonColours.secondary,
  );

  /// Screen titles, welcome headings - 30 bold.
  static const TextStyle title = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.bold,
  );

  /// Section titles and CTA labels - 22 bold.
  static const TextStyle heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  /// Card action labels - 18 bold.
  static const TextStyle subheading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  /// Instructions and button text - 16.
  static const TextStyle body = TextStyle(fontSize: 16);

  /// Body text in bold (pill buttons).
  static const TextStyle bodyBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  /// Bottom-nav labels and secondary UI - 14.
  static const TextStyle label = TextStyle(fontSize: 14);

  /// Card micro-labels ("Balance") - 10 bold.
  static const TextStyle caption = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    color: FoonColours.primary,
  );
}
