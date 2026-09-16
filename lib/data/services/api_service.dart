import 'package:dio/dio.dart';
import '../../core/network/api_config.dart';
import '../../core/utils/selected_file.dart';
import '../models/project.dart';
import '../models/log_entry.dart';
import '../models/build_job.dart';
import '../models/project_file.dart';

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 5),
    ),
  );

  String? _token;

  ApiService() {
    // Interceptor to inject JWT token into all requests
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  bool get isAuthenticated => _token != null;
  String? get token => _token;

  // --- Auth API ---

  Future<void> register(String email, String password) async {
    try {
      await _dio.post(
        '/api/auth/register',
        data: {'email': email, 'password': password},
      );
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: FormData.fromMap({'username': email, 'password': password}),
      );
      _token = response.data['access_token'] as String;
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  void logout() {
    _token = null;
  }

  // --- Projects API ---

  Future<List<Project>> listProjects() async {
    try {
      final response = await _dio.get('/api/projects');
      final list = response.data as List;
      return list
          .map((item) => Project.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<Project> createProject(
    String name,
    String? description, {
    bool initializeFlutter = false,
  }) async {
    try {
      final response = await _dio.post(
        '/api/projects',
        data: {
          'name': name,
          'description': description,
          'initialize_flutter': initializeFlutter,
        },
      );
      return Project.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<Project> getProject(String projectId) async {
    try {
      final response = await _dio.get('/api/projects/$projectId');
      return Project.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<void> deleteProject(String projectId) async {
    try {
      await _dio.delete('/api/projects/$projectId');
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<Project> uploadFolder(
    String folderName,
    List<SelectedFile> files, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final formData = FormData();
      formData.fields.add(MapEntry('folder_name', folderName));
      for (final f in files) {
        formData.files.add(
          MapEntry(
            'files',
            MultipartFile.fromBytes(f.bytes, filename: f.relativePath),
          ),
        );
      }
      final response = await _dio.post(
        '/api/projects/upload-folder',
        data: formData,
        onSendProgress: onSendProgress,
      );
      return Project.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<Project> generateProject(String projectId, String prompt) async {
    try {
      final response = await _dio.post(
        '/api/projects/$projectId/generate',
        data: {'prompt': prompt},
      );
      return Project.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<List<LogEntry>> getLogs(String projectId) async {
    try {
      final response = await _dio.get('/api/projects/$projectId/logs');
      final list = response.data as List;
      return list
          .map((item) => LogEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<void> saveGithubToken(String token) async {
    try {
      await _dio.post('/api/auth/github-token', data: {'github_token': token});
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<BuildJob> buildProject(String projectId, String platform) async {
    try {
      final response = await _dio.post(
        '/api/projects/$projectId/build',
        data: {'target_platform': platform},
      );
      return BuildJob.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<List<BuildJob>> getBuilds(String projectId) async {
    try {
      final response = await _dio.get('/api/projects/$projectId/builds');
      final list = response.data as List;
      return list
          .map((item) => BuildJob.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<void> pushToGithub(
    String projectId,
    String repoName,
    bool isPrivate,
  ) async {
    try {
      await _dio.post(
        '/api/projects/$projectId/github',
        data: {'repo_name': repoName, 'private': isPrivate},
      );
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<List<ProjectFile>> fetchProjectFiles(String projectId) async {
    try {
      final response = await _dio.get('/api/projects/$projectId/files');
      final list = response.data as List;
      return list
          .map((item) => ProjectFile.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<String> getFileContent(String projectId, String filePath) async {
    try {
      final response = await _dio.get(
        '/api/projects/$projectId/files/$filePath',
      );
      return response.data['content'] as String;
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<void> saveFileContent(
    String projectId,
    String filePath,
    String content,
  ) async {
    try {
      await _dio.put(
        '/api/projects/$projectId/files/$filePath',
        data: {'content': content},
      );
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<void> importProjectZip(
    String projectId,
    List<int> zipBytes,
    String fileName, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(zipBytes, filename: fileName),
      });
      await _dio.post(
        '/api/projects/$projectId/import',
        data: formData,
        onSendProgress: onSendProgress,
      );
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<Project> modifyProject(String projectId, String prompt) async {
    try {
      final response = await _dio.post(
        '/api/projects/$projectId/modify',
        data: {'prompt': prompt},
      );
      return Project.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<Map<String, dynamic>> getAIProposal(
    String projectId,
    String prompt,
    String? activeFilePath,
  ) async {
    try {
      final response = await _dio.post(
        '/api/projects/$projectId/ai/update',
        data: {'prompt': prompt},
        queryParameters: activeFilePath != null
            ? {'active_file_path': activeFilePath}
            : null,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<Project> applyAIProposal(
    String projectId,
    List<String> dependenciesToAdd,
    List<Map<String, dynamic>> filesToUpdate,
  ) async {
    try {
      final response = await _dio.post(
        '/api/projects/$projectId/ai/apply',
        data: {
          'dependencies_to_add': dependenciesToAdd,
          'files_to_update': filesToUpdate,
        },
      );
      return Project.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<String> getAIAnalysis(
    String projectId,
    String prompt,
    String? filePath,
  ) async {
    try {
      final response = await _dio.post(
        '/api/projects/$projectId/ai/analyze',
        data: {'prompt': prompt, 'file_path': filePath},
      );
      return response.data['analysis'] as String;
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<Project> uploadProjectZip(
    String name,
    String? description,
    List<int> zipBytes,
    String fileName, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(zipBytes, filename: fileName),
      });
      final response = await _dio.post(
        '/api/projects/upload',
        data: formData,
        queryParameters: {'name': name, 'description': ?description},
        onSendProgress: onSendProgress,
      );
      return Project.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<void> exportProject(String projectId, String destinationPath) async {
    try {
      await _dio.download('/api/projects/$projectId/export', destinationPath);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // --- Error Parsing Helper ---

  String _parseError(DioException error) {
    if (error.response != null && error.response!.data != null) {
      final data = error.response!.data;
      if (data is Map && data.containsKey('detail')) {
        return data['detail'].toString();
      }
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Server connection timed out. Please check if backend is running.';
      case DioExceptionType.badResponse:
        return 'Server error (Status ${error.response?.statusCode}).';
      case DioExceptionType.connectionError:
        final cleanUrl = ApiConfig.baseUrl.replaceAll('/api', '');
        return 'Cannot reach the server. Make sure FastAPI backend is active on $cleanUrl.';
      default:
        return 'An unexpected network error occurred.';
    }
  }
}
