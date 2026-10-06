import 'package:flutter/material.dart';

/// Spacing steps of the 4 dp grid (section 4 of the spec).
class FoonSpacing {
  FoonSpacing._();

  static const double xs = 4;
  static const double s = 8;
  static const double tight = 10;
  static const double m = 16;
  static const double group = 24;
  static const double gutter = 25;
  static const double cardMargin = 15;
  static const double section = 30;
  static const double sectionWide = 40;
  static const double hero = 50;
  static const double splashA = 75;
  static const double splashB = 100;

  /// Gap between siblings inside a group.
  static const SizedBox gap = SizedBox(height: tight);

  /// Gap between groups.
  static const SizedBox groupGap = SizedBox(height: group);
}

/// Corner radii (section 5 of the spec).
class FoonRadii {
  FoonRadii._();

  /// Cards, inputs, dialogs.
  static const double card = 10;

  /// Pill and rounded buttons.
  static const double pill = 30;

  /// Dense grid cells.
  static const double cell = 6;
}

/// Elevation levels (section 5 of the spec).
class FoonElevation {
  FoonElevation._();

  /// Raised pill buttons.
  static const double raised = 5;
}

/// Standard button geometry (section 4 of the spec).
class FoonSizes {
  FoonSizes._();

  /// Full-width CTA height.
  static const double ctaHeight = 55;

  /// Pill button size.
  static const double pillWidth = 250;
  static const double pillHeight = 50;

  /// Hero card size.
  static const double cardWidth = 350;
  static const double cardHeight = 200;

  /// Text field height.
  static const double fieldHeight = 55;

  /// Coloured action strip inside a card.
  static const double stripHeight = 50;

  /// Wordmark height inside the app bar.
  static const double logoHeight = 38;

  /// Empty-state / status icons.
  static const double iconStatus = 48;
}
