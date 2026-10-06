import 'package:flutter/material.dart';
import 'package:foon_design/foon_design.dart';
import 'package:provider/provider.dart';

import 'controllers/vibration_grid_scan_controller.dart';
import 'ui/scan_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => VibrationGridScanController(),
      child: const ContactScanApp(),
    ),
  );
}

class ContactScanApp extends StatelessWidget {
  const ContactScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoonMed',
      theme: FoonTheme.light(),
      home: const ScanScreen(),
    );
  }
}
