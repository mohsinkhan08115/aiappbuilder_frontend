import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:aiappbuilder/core/errors/app_error_handler.dart';
import 'package:aiappbuilder/data/services/api_service.dart';
import 'package:aiappbuilder/data/models/project.dart';
import 'package:aiappbuilder/data/repositories/project_repository.dart';
import 'package:aiappbuilder/features/projects/viewmodel/project_viewmodel.dart';

class FakeProjectRepository extends ProjectRepository {
  @override
  Future<List<Project>> listProjects() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeApiServiceSuccess extends ApiService {
  @override
  Future<Map<String, dynamic>> saveGithubToken(String token) async {
    return {
      'is_valid': true,
      'status': 'success',
      'username': 'octocat',
      'scopes': ['repo'],
      'repo_write_permission_verified': false,
      'permissions_note': 'User identity verified. Specific repository access unverified.',
      'message': 'GitHub token verified for "octocat" and saved successfully.'
    };
  }
}

class FakeApiServiceFailure extends ApiService {
  final String errorMessage;
  FakeApiServiceFailure(this.errorMessage);

  @override
  Future<Map<String, dynamic>> saveGithubToken(String token) async {
    throw Exception(errorMessage);
  }
}

void main() {
  group('AppErrorHandler GitHub Diagnostic Tests', () {
    test('Format validation tests for GitHub PAT prefixes', () {
      expect(AppErrorHandler.validateGithubToken(null), contains('cannot be empty'));
      expect(AppErrorHandler.validateGithubToken('   '), contains('cannot be empty'));
      expect(AppErrorHandler.validateGithubToken('ghp_short'), contains('too short'));
      expect(AppErrorHandler.validateGithubToken('invalid_prefix_1234567890abcdef'), contains('Suspicious token format'));

      expect(AppErrorHandler.validateGithubToken('ghp_1234567890abcdef1234567890abcdef1234'), isNull);
      expect(AppErrorHandler.validateGithubToken('github_pat_11ABCDEFGHIJKLM_01234567890abcdefghijklmnopqrstuvwxyz'), isNull);
    });

    test('Parses 401 Bad Credentials accurately without exposing token', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/api/auth/github-token'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/github-token'),
          statusCode: 401,
          data: {'detail': 'Invalid or expired GitHub Personal Access Token (bad credentials).'},
        ),
      );

      final message = AppErrorHandler.parseError(dioError);
      expect(message, contains('Invalid or expired'));
      expect(message, contains('repo'));
    });

    test('Parses 429 Rate Limit error accurately', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/api/auth/github-token'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/github-token'),
          statusCode: 429,
          data: {'detail': 'GitHub API rate limit exceeded.'},
        ),
      );

      final message = AppErrorHandler.parseError(dioError);
      expect(message, contains('rate limit exceeded'));
    });

    test('Parses 403 SAML / SSO forbidden error accurately', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/api/auth/github-token'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/github-token'),
          statusCode: 403,
          data: {'detail': 'Resource protected by organization SAML enforcement.'},
        ),
      );

      final message = AppErrorHandler.parseError(dioError);
      expect(message, contains('SAML SSO'));
    });

    test('Parses 502 / 504 Gateway Timeout error noting token preservation', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/api/auth/github-token'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/github-token'),
          statusCode: 502,
          data: {'detail': 'GitHub service timed out. Previously saved token preserved.'},
        ),
      );

      final message = AppErrorHandler.parseError(dioError);
      expect(message, contains('Previously saved token was preserved'));
    });

    test('Parses 500 Internal Server error noting token preservation', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/api/auth/github-token'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/github-token'),
          statusCode: 500,
          data: {},
        ),
      );

      final message = AppErrorHandler.parseError(dioError);
      expect(message, contains('Previously saved token was preserved'));
    });
  });

  group('ProjectViewModel GitHub Token Integration Tests', () {
    test('updateGitHubToken stores diagnostics on success', () async {
      final fakeRepo = FakeProjectRepository();
      final fakeApi = FakeApiServiceSuccess();
      final vm = ProjectViewModel(fakeRepo, fakeApi);

      expect(vm.isLoading, isFalse);
      expect(vm.githubDiagnostics, isNull);

      final res = await vm.updateGitHubToken('ghp_ValidTokenForVmTesting123456');

      expect(res, isNotNull);
      expect(res?['status'], equals('success'));
      expect(res?['username'], equals('octocat'));
      expect(vm.githubDiagnostics?['username'], equals('octocat'));
      expect(vm.githubDiagnostics?['repo_write_permission_verified'], isFalse);
      expect(vm.error, isNull);
      expect(vm.isLoading, isFalse);
    });

    test('updateGitHubToken sets error and nullifies diagnostics on failure', () async {
      final fakeRepo = FakeProjectRepository();
      final fakeApi = FakeApiServiceFailure('GitHub token validation failed: bad credentials.');
      final vm = ProjectViewModel(fakeRepo, fakeApi);

      final res = await vm.updateGitHubToken('ghp_InvalidCandidateToken1234');

      expect(res, isNull);
      expect(vm.githubDiagnostics, isNull);
      expect(vm.error, contains('bad credentials'));
      expect(vm.isLoading, isFalse);
    });
  });
}
