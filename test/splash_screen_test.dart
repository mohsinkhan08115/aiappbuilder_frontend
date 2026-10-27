import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiappbuilder/core/components/splash_screen.dart';

void main() {
  group('SplashScreenOverlay Widget Tests', () {
    testWidgets('renders splash screen and displays brand logo and enter studio button',
        (WidgetTester tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SplashScreenOverlay(
              duration: const Duration(milliseconds: 1000),
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      // Verify key brand elements
      expect(find.text('AI-POWERED FULL-STACK STUDIO'), findsOneWidget);
      expect(find.text('Plan · Build · Verify · Ship'), findsOneWidget);
      expect(find.text('Enter studio'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(dismissed, isFalse);
    });

    testWidgets('calls onDismiss immediately when Skip / Enter studio is tapped',
        (WidgetTester tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SplashScreenOverlay(
              duration: const Duration(seconds: 10),
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(dismissed, isFalse);

      final skipButton = find.text('Enter studio');
      expect(skipButton, findsOneWidget);
      await tester.tap(skipButton);
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('automatically calls onDismiss when duration timer completes',
        (WidgetTester tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SplashScreenOverlay(
              duration: const Duration(milliseconds: 500),
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(dismissed, isFalse);

      await tester.pump(const Duration(milliseconds: 600));

      expect(dismissed, isTrue);
    });

    testWidgets('renders properly with animations disabled (reduced motion)',
        (WidgetTester tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: SplashScreenOverlay(
                duration: const Duration(milliseconds: 500),
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('AI-POWERED FULL-STACK STUDIO'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(dismissed, isTrue);
    });
  });
}
