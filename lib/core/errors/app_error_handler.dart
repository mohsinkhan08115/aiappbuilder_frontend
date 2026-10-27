import 'package:dio/dio.dart';
import '../network/api_config.dart';

class AppErrorHandler {
  /// Cleanly translates any error or DioException into an actionable, user-friendly message.
  static String parseError(dynamic error) {
    if (error is DioException) {
      return _parseDioError(error);
    }
    if (error is String) {
      return error;
    }
    if (error is Exception) {
      final msg = error.toString();
      if (msg.startsWith('Exception: ')) {
        return msg.substring(11);
      }
      return msg;
    }
    return error?.toString() ?? 'An unexpected error occurred.';
  }

  static String _parseDioError(DioException error) {
    final cleanUrl = ApiConfig.baseUrl.replaceAll('/api', '');

    // 1. Connection & Network Level Failures
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Server connection timed out. Please check if backend is running on $cleanUrl.';
      case DioExceptionType.connectionError:
        return 'Cannot connect to AI App Builder server. Ensure FastAPI backend is active on $cleanUrl.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      default:
        break;
    }

    // 2. HTTP Status Code & Response Body Parsing
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    final path = error.requestOptions.path;

    // Check for specific GitHub or token issues
    final isGithubRelated = path.contains('github') || path.contains('github-token');

    if (statusCode == 429) {
      if (isGithubRelated || _dataContains(data, ['rate limit'])) {
        return 'GitHub API rate limit exceeded. Please wait before retrying.';
      }
      return 'Too many requests. Please slow down and try again.';
    }

    if (statusCode == 403) {
      if (isGithubRelated || _dataContains(data, ['saml', 'sso', 'forbidden'])) {
        return 'GitHub API access forbidden. The token may require SAML SSO authorization or organization approval.';
      }
      if (isGithubRelated && _dataContains(data, ['rate limit'])) {
        return 'GitHub API rate limit exceeded. Please wait before retrying.';
      }
      return 'Access denied. You do not have permission to perform this action.';
    }

    if (statusCode == 401) {
      if (isGithubRelated || _dataContains(data, ['bad credentials', 'token', 'unauthorized', 'credentials'])) {
        return 'Invalid or expired GitHub Personal Access Token. Please generate a token with "repo" scope at https://github.com/settings/tokens (classic "ghp_" or fine-grained "github_pat_").';
      }
      if (data is Map) {
        if (data.containsKey('detail') && data['detail'] is String && (data['detail'] as String).trim().isNotEmpty) {
          final detailStr = (data['detail'] as String).trim();
          if (!detailStr.contains('<html') && !detailStr.contains('Traceback')) {
            return detailStr;
          }
        }
        if (data.containsKey('error') && data['error'] is Map && data['error']['message'] != null) {
          final msg = data['error']['message'].toString().trim();
          if (msg.isNotEmpty && !msg.contains('<html') && !msg.contains('Traceback')) {
            return msg;
          }
        }
      }
      return 'Authentication required. Please sign in to continue.';
    }

    if (statusCode == 502 || statusCode == 504) {
      if (isGithubRelated) {
        return 'GitHub service is temporarily unavailable or timed out. Previously saved token was preserved.';
      }
      if (data is Map) {
        if (data.containsKey('error') && data['error'] is Map && data['error']['message'] != null) {
          final msg = data['error']['message'].toString().trim();
          if (msg.isNotEmpty) return msg;
        }
        if (data.containsKey('detail') && data['detail'] is String && (data['detail'] as String).trim().isNotEmpty) {
          return (data['detail'] as String).trim();
        }
      }
      return 'Bad gateway ($statusCode). Upstream service is temporarily unavailable.';
    }

    if (statusCode == 404) {
      if (path.contains('projects/')) {
        return 'Project not found. It may have been deleted or moved from workspace.';
      }
      return 'The requested server endpoint was not found (404).';
    }

    if (statusCode == 422) {
      // FastAPI / Pydantic validation error format
      if (data is Map && data.containsKey('detail')) {
        final detail = data['detail'];
        if (detail is List && detail.isNotEmpty) {
          final messages = detail.map((item) {
            if (item is Map) {
              final loc = item['loc'] is List ? (item['loc'] as List).last : 'Field';
              final msg = item['msg'] ?? 'is invalid';
              return '$loc: $msg';
            }
            return item.toString();
          }).join(', ');
          return 'Validation failed: $messages';
        } else if (detail is String) {
          return 'Validation error: $detail';
        }
      }
      return 'Submitted data was invalid or malformed.';
    }

    // Try extracting any server-provided error message
    if (data is Map) {
      if (data.containsKey('detail')) {
        final detail = data['detail'];
        if (detail is String && detail.isNotEmpty) {
          if (isGithubRelated && detail.toLowerCase().contains('bad credentials')) {
            return 'Invalid or expired GitHub Personal Access Token. Please generate a token with "repo" scope at https://github.com/settings/tokens.';
          }
          return detail;
        }
      }
      if (data.containsKey('error') && data['error'] is Map && data['error']['message'] != null) {
        return data['error']['message'].toString();
      }
    }

    if (statusCode != null) {
      if (statusCode >= 500) {
        if (isGithubRelated) {
          return 'GitHub service error ($statusCode). Previously saved token was preserved.';
        }
        return 'Server error ($statusCode). Please check backend logs or try again shortly.';
      }
      return 'Server returned status code $statusCode.';
    }

    return 'An unexpected network error occurred.';
  }

  static bool _dataContains(dynamic data, List<String> keywords) {
    if (data == null) return false;
    final str = data.toString().toLowerCase();
    return keywords.any((k) => str.contains(k.toLowerCase()));
  }

  /// GitHub Token Diagnostic Helpers
  static String? validateGithubToken(String? token) {
    if (token == null || token.trim().isEmpty) {
      return 'GitHub token cannot be empty.';
    }
    final clean = token.trim();
    if (clean.length < 20) {
      return 'Token is too short. GitHub personal access tokens are typically 36-93 characters.';
    }
    final isClassic = clean.startsWith('ghp_');
    final isFineGrained = clean.startsWith('github_pat_');
    final isOAuth = clean.startsWith('gho_') || clean.startsWith('ghu_');

    if (!isClassic && !isFineGrained && !isOAuth) {
      return 'Suspicious token format. Expected classic "ghp_..." or fine-grained "github_pat_...".';
    }
    return null;
  }
}
