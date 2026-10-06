import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../colours.dart';
import '../spacing.dart';
import '../typography.dart';

/// Hero info card (balance/health metric): white card, radius 10, bottom
/// aligned content and a dark action strip.
///
/// Nominal geometry 350 x 200; it centres itself and shrinks on narrow screens
/// instead of overflowing.
class FoonCard extends StatelessWidget {
  const FoonCard({
    super.key,
    required this.title,
    required this.value,
    this.trailing,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.valueColour = FoonColours.secondary,
    this.width = FoonSizes.cardWidth,
    this.height = FoonSizes.cardHeight,
  });

  /// Micro-label above the value ("Balance").
  final String title;

  /// Hero value ("50,69 EUR").
  final String value;

  /// Optional widget on the right of the header row (e.g. a visibility toggle).
  final Widget? trailing;

  /// Label of the bottom action strip; hides the strip when null.
  final String? actionLabel;

  /// Font Awesome glyph in the action strip.
  final FaIconData? actionIcon;

  final VoidCallback? onAction;

  final Color valueColour;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FoonSpacing.cardMargin),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: Container(
            height: height,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(FoonRadii.card)),
            ),
            alignment: Alignment.bottomCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20),
                  child: Row(
                    children: [
                      Text(title, style: FoonTextStyles.caption),
                      const Spacer(),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ),
                const SizedBox(height: FoonSpacing.tight),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: FoonTextStyles.display.copyWith(color: valueColour),
                  ),
                ),
                const SizedBox(height: FoonSpacing.section),
                if (actionLabel != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(FoonRadii.card),
                      bottomRight: Radius.circular(FoonRadii.card),
                    ),
                    child: Material(
                      color: FoonColours.primary,
                      child: InkWell(
                        onTap: onAction,
                        child: SizedBox(
                          height: FoonSizes.stripHeight,
                          width: double.infinity,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (actionIcon != null)
                                FaIcon(
                                  actionIcon,
                                  size: 30,
                                  color: FoonColours.secondary,
                                ),
                              if (actionIcon != null)
                                const SizedBox(width: FoonSpacing.section),
                              Text(
                                actionLabel!,
                                style: FoonTextStyles.subheading.copyWith(
                                  color: FoonColours.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
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
