import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aiappbuilder/features/auth/view/auth_screen.dart';
import 'package:aiappbuilder/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:aiappbuilder/data/repositories/auth_repository.dart';
import 'package:aiappbuilder/data/services/api_service.dart';

class MockApiService extends ApiService {
  @override
  bool get isAuthenticated => false;

  @override
  Future<void> login(String email, String password) async {}

  @override
  Future<void> register(String email, String password) async {}
}

Widget createAuthScreenTestWidget({AuthViewModel? authVm}) {
  final apiService = MockApiService();
  final repo = AuthRepositoryImpl(apiService);
  final vm = authVm ?? AuthViewModel(repo);

  return MaterialApp(
    home: ChangeNotifierProvider<AuthViewModel>.value(
      value: vm,
      child: const AuthScreen(),
    ),
  );
}

void main() {
  group('AuthScreen Password Visibility Toggle', () {
    testWidgets('Password field defaults to hidden (obscureText = true)',
        (WidgetTester tester) async {
      await tester.pumpWidget(createAuthScreenTestWidget());
      await tester.pumpAndSettle();

      final passwordFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Password',
      );
      expect(passwordFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(passwordFieldFinder);
      expect(textField.obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    });

    testWidgets('Tapping eye icon toggles obscureText and preserves password text',
        (WidgetTester tester) async {
      await tester.pumpWidget(createAuthScreenTestWidget());
      await tester.pumpAndSettle();

      final passwordFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Password',
      );

      // Enter a password
      await tester.enterText(passwordFieldFinder, 'SuperSecret123!');
      await tester.pump();

      // Verify text is entered and still obscured
      var textField = tester.widget<TextField>(passwordFieldFinder);
      expect(textField.controller?.text, 'SuperSecret123!');
      expect(textField.obscureText, isTrue);

      // Tap toggle icon to reveal password
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      // Verify password is now visible and text is preserved
      textField = tester.widget<TextField>(passwordFieldFinder);
      expect(textField.obscureText, isFalse);
      expect(textField.controller?.text, 'SuperSecret123!');
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);

      // Tap toggle icon again to re-hide password
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      // Verify password is obscured again and text is intact
      textField = tester.widget<TextField>(passwordFieldFinder);
      expect(textField.obscureText, isTrue);
      expect(textField.controller?.text, 'SuperSecret123!');
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    });

    testWidgets('Form validation and toggle between Login and Sign Up works with visibility toggle',
        (WidgetTester tester) async {
      await tester.pumpWidget(createAuthScreenTestWidget());
      await tester.pumpAndSettle();

      // Switch to Sign Up
      await tester.tap(find.text('New user? Create an account'));
      await tester.pumpAndSettle();

      expect(find.text('Create an account to start building.'), findsOneWidget);

      final passwordFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Password',
      );
      expect(passwordFieldFinder, findsOneWidget);

      // Enter short password and trigger validation error
      await tester.enterText(passwordFieldFinder, '123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 6 characters'), findsOneWidget);

      // Toggle visibility on Sign Up screen
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      final textField = tester.widget<TextField>(passwordFieldFinder);
      expect(textField.obscureText, isFalse);
      expect(textField.controller?.text, '123');
    });
  });
}
