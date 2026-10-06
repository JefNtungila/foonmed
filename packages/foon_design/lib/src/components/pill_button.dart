import 'package:flutter/material.dart';

import '../colours.dart';
import '../spacing.dart';
import '../typography.dart';

/// Compact primary action (home tiles): 250 x 50, elevation 5, pill shape.
///
/// Mirrors the original FoonCash `HomeButton`.
class FoonPillButton extends StatelessWidget {
  const FoonPillButton({
    super.key,
    required this.title,
    required this.onPressed,
    this.iconImage,
    this.background = FoonColours.secondary,
    this.shadowColour = FoonColours.primary,
    this.labelColour = FoonColours.primary,
  });

  final String title;
  final VoidCallback onPressed;
  final ImageProvider? iconImage;
  final Color background;
  final Color shadowColour;
  final Color labelColour;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        height: FoonSizes.pillHeight,
        width: FoonSizes.pillWidth,
        child: Material(
          elevation: FoonElevation.raised,
          color: shadowColour,
          borderRadius: BorderRadius.circular(FoonRadii.pill),
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              backgroundColor: background,
              foregroundColor: labelColour,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FoonRadii.pill),
              ),
              textStyle: FoonTextStyles.bodyBold,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (iconImage != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 30,
                      right: 20,
                      top: 5,
                      bottom: 5,
                    ),
                    child: Image(image: iconImage!),
                  ),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: FoonTextStyles.bodyBold.copyWith(
                      color: labelColour,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
