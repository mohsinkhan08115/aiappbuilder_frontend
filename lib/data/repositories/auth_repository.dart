import '../services/api_service.dart';

abstract class AuthRepository {
  bool get isAuthenticated;
  Future<void> register(String email, String password);
  Future<void> login(String email, String password);
  void logout();
  Future<Map<String, dynamic>> saveGithubToken(String token);
}

class AuthRepositoryImpl implements AuthRepository {
  final ApiService _apiService;

  AuthRepositoryImpl(this._apiService);

  @override
  bool get isAuthenticated => _apiService.isAuthenticated;

  @override
  Future<void> register(String email, String password) =>
      _apiService.register(email, password);

  @override
  Future<void> login(String email, String password) =>
      _apiService.login(email, password);

  @override
  void logout() => _apiService.logout();

  @override
  Future<Map<String, dynamic>> saveGithubToken(String token) =>
      _apiService.saveGithubToken(token);
}
