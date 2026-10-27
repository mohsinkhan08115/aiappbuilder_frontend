import 'package:flutter_test/flutter_test.dart';
import 'package:aiappbuilder/app/app.dart';

void main() {
  testWidgets('App renders auth screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
  });
}
