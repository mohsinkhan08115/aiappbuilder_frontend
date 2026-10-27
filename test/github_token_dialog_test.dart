import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aiappbuilder/core/components/github_token_dialog.dart';
import 'package:aiappbuilder/features/projects/viewmodel/project_viewmodel.dart';
import 'package:aiappbuilder/data/services/api_service.dart';
import 'package:aiappbuilder/data/models/project.dart';
import 'package:aiappbuilder/data/repositories/project_repository.dart';

class MockProjectRepository extends ProjectRepository {
  @override
  Future<List<Project>> listProjects() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockApiServiceSuccess extends ApiService {
  @override
  Future<Map<String, dynamic>> saveGithubToken(String token) async {
    return {
      'is_valid': true,
      'status': 'success',
      'username': 'octocat',
      'scopes': ['repo'],
      'repo_write_permission_verified': false,
      'permissions_note': 'User identity verified.',
      'message': 'GitHub token verified for "octocat" and saved successfully.'
    };
  }
}

class MockApiServiceSlow extends ApiService {
  @override
  Future<Map<String, dynamic>> saveGithubToken(String token) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'is_valid': true,
      'status': 'success',
      'username': 'octocat',
      'scopes': ['repo'],
      'repo_write_permission_verified': false,
      'permissions_note': 'User identity verified.',
      'message': 'Saved'
    };
  }
}

Widget buildTestableWidget({
  required Widget child,
  ApiService? apiService,
}) {
  final api = apiService ?? MockApiServiceSuccess();
  final repo = MockProjectRepository();
  final vm = ProjectViewModel(repo, api);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ProjectViewModel>.value(value: vm),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  group('GitHubTokenDialog Widget Tests', () {
    testWidgets('Renders GitHub Token Dialog with masked input and requirements', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: const GitHubTokenDialog(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GitHub Token Config'), findsOneWidget);
      expect(find.text('Token Requirements:'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);
    });

    testWidgets('Local rejection for invalid_tok_123 displays format error without network call', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: const GitHubTokenDialog(),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      await tester.enterText(textFieldFinder, 'invalid_tok_123');
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(ElevatedButton, 'Save');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Check that errorText is displayed on the field
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.decoration?.errorText, isNotNull);
      expect(textField.decoration!.errorText, contains('Token is too short'));

      // Dialog should remain open
      expect(find.text('GitHub Token Config'), findsOneWidget);
    });

    testWidgets('Shows loading indicator when submitting valid token format', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          apiService: MockApiServiceSlow(),
          child: const GitHubTokenDialog(),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      await tester.enterText(
        textFieldFinder,
        'ghp_1234567890abcdef1234567890abcdef1234',
      );
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(ElevatedButton, 'Save');
      await tester.tap(saveButton);
      await tester.pump(); // Advance one frame to show progress indicator

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 600)); // Finish delay
      await tester.pumpAndSettle();
    });

    testWidgets('Calls onSuccess callback and closes upon successful validation', (tester) async {
      String? verifiedUser;

      await tester.pumpWidget(
        buildTestableWidget(
          apiService: MockApiServiceSuccess(),
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: ctx,
                  builder: (_) => GitHubTokenDialog(
                    onSuccess: (u) => verifiedUser = u,
                  ),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('GitHub Token Config'), findsOneWidget);

      // Enter valid format token
      await tester.enterText(
        find.byType(TextField),
        'ghp_1234567890abcdef1234567890abcdef1234',
      );
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      // Dialog should close
      expect(find.text('GitHub Token Config'), findsNothing);
      expect(verifiedUser, equals('octocat'));
    });
  });
}
