import 'package:flutter/material.dart';

import '../colours.dart';
import '../spacing.dart';

/// Centred icon + title + message, for aborted, error and placeholder states.
class FoonEmptyState extends StatelessWidget {
  const FoonEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.iconColour = FoonColours.neutralText,
    this.iconSize = FoonSizes.iconStatus,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color iconColour;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: iconColour),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
