import 'package:flutter/material.dart';

import '../colours.dart';
import '../spacing.dart';
import '../typography.dart';

/// Full-width call to action: 55 high, screen width minus the 25 gutter each
/// side, orange fill with grey-black label.
class FoonCtaButton extends StatelessWidget {
  const FoonCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.background = FoonColours.secondary,
    this.labelColour = FoonColours.primary,
    this.width,
    this.height = FoonSizes.ctaHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color background;
  final Color labelColour;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final double resolvedWidth =
        width ?? MediaQuery.sizeOf(context).width - (FoonSpacing.gutter * 2);

    return SizedBox(
      height: height,
      width: resolvedWidth,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: labelColour,
          padding: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FoonRadii.card),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: FoonTextStyles.heading.copyWith(color: labelColour),
        ),
      ),
    );
  }
}
