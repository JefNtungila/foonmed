import 'package:flutter/material.dart';

import '../spacing.dart';

/// App bar hosting the sector wordmark instead of a text title.
///
/// The screen purpose remains available to assistive technology through the
/// image's semantic label.
class FoonTopBar extends StatelessWidget implements PreferredSizeWidget {
  const FoonTopBar({
    super.key,
    required this.logo,
    this.semanticLabel = 'Foon',
    this.actions = const [],
    this.logoHeight = FoonSizes.logoHeight,
  });

  /// Wordmark source, e.g. `AssetImage('assets/foonmed_logo_transparent.png')`.
  final ImageProvider logo;

  /// Announced by screen readers.
  final String semanticLabel;

  final List<Widget> actions;
  final double logoHeight;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Image(
        image: logo,
        height: logoHeight,
        semanticLabel: semanticLabel,
      ),
      actions: actions,
    );
  }
}
