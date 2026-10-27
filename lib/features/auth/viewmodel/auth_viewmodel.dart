import 'package:flutter/material.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../core/errors/app_error_handler.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;

  bool _isLoading = false;
  String? _error;
  String? _currentUserEmail;

  AuthViewModel(this._authRepository);

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated =>
      _authRepository.isAuthenticated ||
      (_currentUserEmail != null && _currentUserEmail!.isNotEmpty);
  String? get currentUserEmail => _currentUserEmail;

  void setCurrentUserEmail(String? email) {
    _currentUserEmail = email;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authRepository.login(email, password);
      _currentUserEmail = email;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = AppErrorHandler.parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authRepository.register(email, password);
      _currentUserEmail = email;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = AppErrorHandler.parseError(e);
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _authRepository.logout();
    _currentUserEmail = null;
    _error = null;
    notifyListeners();
  }
}
