import 'package:flutter/foundation.dart';
import '../../domain/models/admin_user.dart';
import '../../domain/repositories/admin_auth_repository.dart';
import '../services/admin_auth_service.dart';

/// Concrete Repository implementation for Admin Auth
class AdminAuthRepositoryImpl implements AdminAuthRepository {
  final AdminAuthService _authService;

  AdminAuthRepositoryImpl({AdminAuthService? authService})
      : _authService = authService ?? AdminAuthService();

  @override
  Future<AdminUser> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    try {
      return await _authService.signInAdmin(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );
    } catch (e, stackTrace) {
      debugPrint('[AdminAuthRepositoryImpl] Login error: $e\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _authService.signOutAdmin();
    } catch (e) {
      debugPrint('[AdminAuthRepositoryImpl] Logout error: $e');
    }
  }

  @override
  Future<AdminUser?> getCurrentAdmin() async {
    try {
      return await _authService.getCurrentAdminProfile();
    } catch (e) {
      debugPrint('[AdminAuthRepositoryImpl] getCurrentAdmin error: $e');
      return null;
    }
  }

  @override
  Future<String?> getSavedEmail() async {
    try {
      return await _authService.getSavedEmail();
    } catch (e) {
      return null;
    }
  }
}
