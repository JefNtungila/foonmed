import 'package:flutter/material.dart';

import '../colours.dart';

/// One destination in a [FoonBottomNav].
class FoonNavItem {
  const FoonNavItem({required this.label, required this.icon});

  /// Always visible label ("Home", "Transactions").
  final String label;

  /// 512 x 512 transparent PNG source.
  final ImageProvider icon;
}

/// Bottom navigation: dark strip, always-visible labels, orange selection.
class FoonBottomNav extends StatelessWidget {
  const FoonBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<FoonNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: FoonColours.primary,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
      unselectedItemColor: FoonColours.onSemantic,
      unselectedFontSize: 14,
      selectedItemColor: FoonColours.secondary,
      selectedFontSize: 14,
      selectedIconTheme: const IconThemeData(color: FoonColours.secondary),
      unselectedIconTheme: const IconThemeData(color: FoonColours.onSemantic),
      currentIndex: currentIndex,
      onTap: onTap,
      items: [
        for (final item in items)
          BottomNavigationBarItem(
            icon: Padding(
              padding: const EdgeInsets.all(8),
              child: ImageIcon(item.icon),
            ),
            label: item.label,
          ),
      ],
    );
  }
}
