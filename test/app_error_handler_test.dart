import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiappbuilder/core/errors/app_error_handler.dart';

void main() {
  group('AppErrorHandler Tests', () {
    test('translates connection error to FastAPI server instruction', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/api/projects'),
        type: DioExceptionType.connectionError,
        message: 'Connection refused',
      );

      final result = AppErrorHandler.parseError(error);
      expect(result, contains('Cannot connect to AI App Builder server'));
      expect(result, contains('FastAPI backend is active'));
    });

    test('translates timeout errors cleanly', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/api/v1/chat'),
        type: DioExceptionType.receiveTimeout,
      );

      final result = AppErrorHandler.parseError(error);
      expect(result, contains('Server connection timed out'));
    });

    test('translates GitHub 401 / bad credentials to actionable PAT advice', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/api/projects/proj-1/github'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/projects/proj-1/github'),
          statusCode: 401,
          data: {'detail': 'Bad credentials'},
        ),
      );

      final result = AppErrorHandler.parseError(error);
      expect(result, contains('Invalid or expired GitHub Personal Access Token'));
      expect(result, contains('"repo" scope'));
      expect(result, contains('https://github.com/settings/tokens'));
    });

    test('translates 401 response with explicit detail message (e.g. Incorrect email or password)', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/api/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/login'),
          statusCode: 401,
          data: {'detail': 'Incorrect email or password'},
        ),
      );

      final result = AppErrorHandler.parseError(error);
      expect(result, equals('Incorrect email or password'));
    });

    test('translates 401 response with nested error.message', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/api/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/login'),
          statusCode: 401,
          data: {
            'error': {'message': 'Account is disabled'}
          },
        ),
      );

      final result = AppErrorHandler.parseError(error);
      expect(result, equals('Account is disabled'));
    });

    test('translates 401 response without usable detail to generic fallback', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/api/projects'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/projects'),
          statusCode: 401,
          data: null,
        ),
      );

      final result = AppErrorHandler.parseError(error);
      expect(result, equals('Authentication required. Please sign in to continue.'));
    });

    test('translates 404 on project route to project missing guidance', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/api/projects/proj-999'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/projects/proj-999'),
          statusCode: 404,
        ),
      );

      final result = AppErrorHandler.parseError(error);
      expect(result, contains('Project not found'));
    });

    test('translates 422 FastAPI validation errors with specific field messages', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/api/projects'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/projects'),
          statusCode: 422,
          data: {
            'detail': [
              {
                'loc': ['body', 'name'],
                'msg': 'Field required',
                'type': 'value_error.missing'
              }
            ]
          },
        ),
      );

      final result = AppErrorHandler.parseError(error);
      expect(result, contains('Validation failed'));
      expect(result, contains('name: Field required'));
    });

    test('validates GitHub token format correctly', () {
      // Empty
      expect(AppErrorHandler.validateGithubToken(''), contains('cannot be empty'));

      // Too short
      expect(AppErrorHandler.validateGithubToken('ghp_short'), contains('too short'));

      // Invalid format prefix
      expect(AppErrorHandler.validateGithubToken('invalid_token_12345678901234567890'), contains('Suspicious token format'));

      // Valid classic token
      expect(AppErrorHandler.validateGithubToken('ghp_123456789012345678901234567890123456'), isNull);

      // Valid fine-grained token
      expect(AppErrorHandler.validateGithubToken('github_pat_11A2345678901234567890123456789012345678901234567890'), isNull);
    });

    test('cleans generic Exception prefix', () {
      final err = Exception('Database locked');
      expect(AppErrorHandler.parseError(err), 'Database locked');
    });

    test('extracts backend error message on 502 Bad Gateway', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/api/v1/chat'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/chat'),
          statusCode: 502,
          data: {
            'success': false,
            'error': {
              'code': 'AI_PROVIDER_ERROR',
              'message': 'The AI service is temporarily experiencing high demand. Please try again shortly.',
            },
          },
        ),
      );

      final result = AppErrorHandler.parseError(error);
      expect(result, 'The AI service is temporarily experiencing high demand. Please try again shortly.');
    });

    test('falls back to generic Bad gateway message on 502 when body has no message', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/api/v1/chat'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/chat'),
          statusCode: 502,
          data: null,
        ),
      );

      final result = AppErrorHandler.parseError(error);
      expect(result, 'Bad gateway (502). Upstream service is temporarily unavailable.');
    });
  });
}
