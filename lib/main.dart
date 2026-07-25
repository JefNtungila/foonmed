import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:foonmed/controllers/scan_controller.dart';
import 'package:foonmed/ui/scan_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ScanController(),
      child: const AcousticScannerApp(),
    ),
  );
}

class AcousticScannerApp extends StatelessWidget {
  const AcousticScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Acoustic Hand Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ScanScreen(),
    );
  }
}