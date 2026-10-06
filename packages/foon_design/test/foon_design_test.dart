import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:foon_design/foon_design.dart';

void main() {
  // 1x1 transparent PNG so image widgets resolve without real assets.
  final MemoryImage stubImage = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    ),
  );

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: FoonTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('tokens', () {
    test('core palette matches the specification', () {
      expect(FoonColours.primary, const Color(0xFF393A3E));
      expect(FoonColours.secondary, const Color(0xFFF69520));
      expect(FoonColours.background, const Color(0xFF636363));
      expect(FoonColours.surface, const Color(0xFF808080));
      expect(FoonColours.success, const Color(0xFF2E7D32));
      expect(FoonColours.info, const Color(0xFF1565C0));
      expect(FoonColours.neutralLight, const Color(0xFFE0E0E0));
      expect(FoonColours.neutralText, const Color(0xFF757575));
    });

    test('scheme is light and built from the brand tokens', () {
      final scheme = FoonColours.colorScheme;
      expect(scheme.brightness, Brightness.light);
      expect(scheme.primary, FoonColours.primary);
      expect(scheme.secondary, FoonColours.secondary);
      expect(scheme.onSurface, FoonColours.onSurface);
    });
  });

  group('FoonPillButton', () {
    testWidgets('renders its label and reports taps', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(
          FoonPillButton(
            title: 'PAY',
            iconImage: null,
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.text('PAY'), findsOneWidget);
      await tester.tap(find.text('PAY'));
      expect(tapped, isTrue);
    });
  });

  group('FoonCtaButton', () {
    testWidgets('renders label and is 55 tall', (tester) async {
      await tester.pumpWidget(
        wrap(FoonCtaButton(label: 'AGREE & CONTINUE', onPressed: () {})),
      );

      final size = tester.getSize(find.text('AGREE & CONTINUE'));
      expect(find.text('AGREE & CONTINUE'), findsOneWidget);
      final buttonSize = tester.getSize(
        find.widgetWithText(ElevatedButton, 'AGREE & CONTINUE'),
      );
      expect(buttonSize.height, FoonSizes.ctaHeight);
      expect(size.height, greaterThan(0));
    });
  });

  group('FoonCard', () {
    testWidgets('shows title, value and the action strip', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(
          FoonCard(
            title: 'Balance',
            value: '50,69 EUR',
            actionLabel: 'TOP UP',
            actionIcon: FontAwesomeIcons.upLong,
            onAction: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Balance'), findsOneWidget);
      expect(find.text('50,69 EUR'), findsOneWidget);
      expect(find.text('TOP UP'), findsOneWidget);

      await tester.tap(find.text('TOP UP'));
      expect(tapped, isTrue);
    });
  });

  group('FoonTextField', () {
    testWidgets('accepts input', (tester) async {
      String? value;
      await tester.pumpWidget(
        wrap(
          FoonTextField(
            hintText: '7400 123456',
            onChanged: (v) => value = v,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '7400 123456');
      expect(value, '7400 123456');
      expect(find.byType(FoonTextField), findsOneWidget);
    });
  });

  group('FoonTopBar', () {
    testWidgets('shows the wordmark with a semantic label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FoonTheme.light(),
          home: Scaffold(
            appBar: FoonTopBar(
              logo: stubImage,
              semanticLabel: 'FoonMed',
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.semanticLabel, 'FoonMed');
    });
  });

  group('FoonBottomNav', () {
    testWidgets('reports the tapped destination', (tester) async {
      int? index;
      await tester.pumpWidget(
        wrap(
          FoonBottomNav(
            items: [
              FoonNavItem(label: 'Home', icon: stubImage),
              FoonNavItem(label: 'Transactions', icon: stubImage),
            ],
            currentIndex: 0,
            onTap: (i) => index = i,
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
      await tester.tap(find.text('Transactions'));
      expect(index, 1);
    });
  });

  group('FoonEmptyState', () {
    testWidgets('renders icon, title and message', (tester) async {
      await tester.pumpWidget(
        wrap(
          const FoonEmptyState(
            icon: Icons.error_outline,
            title: 'Scan failed',
            message: 'Try again',
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Scan failed'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
