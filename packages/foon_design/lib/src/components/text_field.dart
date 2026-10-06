import 'package:flutter/material.dart';

import '../colours.dart';
import '../spacing.dart';

/// Outlined text field: 55 high, 1 px grey-black border, radius 10, generous
/// inner padding.
class FoonTextField extends StatelessWidget {
  const FoonTextField({
    super.key,
    this.hintText,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.height = FoonSizes.fieldHeight,
  });

  final String? hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border.all(width: 1, color: FoonColours.primary),
        borderRadius: BorderRadius.circular(FoonRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 25, right: 25),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hintText,
          ),
        ),
      ),
    );
  }
}
