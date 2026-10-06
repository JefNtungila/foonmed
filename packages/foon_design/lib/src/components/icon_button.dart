import 'package:flutter/material.dart';

import '../colours.dart';

/// App-bar action: 24 px glyph in a 40 px alignment box inside a 60 px slot,
/// with a 48 px tap target.
class FoonIconButton extends StatelessWidget {
  const FoonIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.colour,
    this.semanticLabel,
    this.iconSize = 24,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? colour;
  final String? semanticLabel;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: Center(
        child: IconButton(
          onPressed: onPressed,
          tooltip: semanticLabel,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          padding: EdgeInsets.zero,
          icon: Icon(
            icon,
            size: iconSize,
            color: colour ?? FoonColours.onSemantic,
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    );
  }
}
