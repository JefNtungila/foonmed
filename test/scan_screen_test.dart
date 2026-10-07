import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foon_design/foon_design.dart';
import 'package:foonmed/controllers/vibration_grid_scan_controller.dart';
import 'package:foonmed/services/vibrator_port.dart';
import 'package:foonmed/ui/scan_screen.dart';
import 'package:provider/provider.dart';

class _FakeVibrator implements VibratorPort {
  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> start({required int durationMs}) async {}

  @override
  Future<void> stop() async {}
}

const Set<WidgetState> _enabled = <WidgetState>{};

Future<VibrationGridScanController> pumpScreen(WidgetTester tester) async {
  final controller = VibrationGridScanController(vibrator: _FakeVibrator());
  await tester.pumpWidget(
    ChangeNotifierProvider<VibrationGridScanController>.value(
      value: controller,
      child: MaterialApp(
        theme: FoonTheme.light(),
        home: const ScanScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Color? ctaColour(WidgetTester tester, String label) {
  final button = tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, label),
  );
  return button.style?.backgroundColor?.resolve(_enabled);
}

void main() {
  testWidgets('idle CTA is Foon orange', (tester) async {
    await pumpScreen(tester);

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'START SCAN'),
    );
    expect(ctaColour(tester, 'START SCAN'), FoonColours.secondary);
    expect(
      button.style?.foregroundColor?.resolve(_enabled),
      FoonColours.primary,
    );
    expect(
      tester.getSize(find.widgetWithText(ElevatedButton, 'START SCAN')).height,
      FoonSizes.ctaHeight,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('baseline CTA is orange, text action is dark', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'START SCAN'));
    await tester.pumpAndSettle();

    expect(find.text('CAPTURE BASELINE'), findsOneWidget);
    expect(ctaColour(tester, 'CAPTURE BASELINE'), FoonColours.secondary);

    final cancel = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Cancel'),
    );
    expect(
      cancel.style?.foregroundColor?.resolve(_enabled),
      FoonColours.onSurface,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('abort shows empty state and START OVER CTA', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'START SCAN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(FoonEmptyState), findsOneWidget);
    expect(find.text('Scan aborted'), findsOneWidget);
    expect(ctaColour(tester, 'START OVER'), FoonColours.secondary);
    expect(tester.takeException(), isNull);
  });
}
