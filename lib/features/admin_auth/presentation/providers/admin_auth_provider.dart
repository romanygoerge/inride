import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/errors/admin_auth_exception.dart';
import '../../data/repositories/admin_auth_repository_impl.dart';
import '../../domain/models/admin_user.dart';
import '../../domain/repositories/admin_auth_repository.dart';

enum AdminAuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  accessDenied,
  error,
}

class AdminAuthState {
  final AdminAuthStatus status;
  final AdminUser? adminUser;
  final String? errorMessage;
  final bool isInitializing;
  final String? savedEmail;

  const AdminAuthState({
    required this.status,
    this.adminUser,
    this.errorMessage,
    this.isInitializing = false,
    this.savedEmail,
  });

  factory AdminAuthState.initial() {
    return const AdminAuthState(
      status: AdminAuthStatus.initial,
      isInitializing: true,
    );
  }

  AdminAuthState copyWith({
    AdminAuthStatus? status,
    AdminUser? adminUser,
    String? errorMessage,
    bool? isInitializing,
    String? savedEmail,
  }) {
    return AdminAuthState(
      status: status ?? this.status,
      adminUser: adminUser ?? this.adminUser,
      errorMessage: errorMessage,
      isInitializing: isInitializing ?? this.isInitializing,
      savedEmail: savedEmail ?? this.savedEmail,
    );
  }

  bool get isAuthenticated =>
      status == AdminAuthStatus.authenticated && adminUser != null && adminUser!.isActive;
}

/// Provider for AdminAuthRepository
final adminAuthRepositoryProvider = Provider<AdminAuthRepository>((ref) {
  return AdminAuthRepositoryImpl();
});

/// Riverpod ChangeNotifierProvider for AdminAuthNotifier
final adminAuthProvider = ChangeNotifierProvider<AdminAuthNotifier>((ref) {
  final repository = ref.watch(adminAuthRepositoryProvider);
  return AdminAuthNotifier(repository);
});

/// ChangeNotifier class managing admin state and notifying GoRouter
class AdminAuthNotifier extends ChangeNotifier {
  final AdminAuthRepository _repository;
  AdminAuthState _state = AdminAuthState.initial();

  AdminAuthState get state => _state;

  AdminAuthNotifier(this._repository) {
    _initializeSession();
  }

  /// Restores session on startup or browser refresh
  Future<void> _initializeSession() async {
    try {
      final savedEmail = await _repository.getSavedEmail();
      final currentAdmin = await _repository.getCurrentAdmin();

      if (currentAdmin != null && currentAdmin.isActive) {
        _state = AdminAuthState(
          status: AdminAuthStatus.authenticated,
          adminUser: currentAdmin,
          isInitializing: false,
          savedEmail: savedEmail,
        );
      } else {
        _state = AdminAuthState(
          status: AdminAuthStatus.unauthenticated,
          isInitializing: false,
          savedEmail: savedEmail,
        );
      }
    } catch (e) {
      _state = const AdminAuthState(
        status: AdminAuthStatus.unauthenticated,
        isInitializing: false,
      );
    } finally {
      notifyListeners();
    }
  }

  /// Handles Login action
  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    _state = _state.copyWith(
      status: AdminAuthStatus.loading,
      errorMessage: null,
    );
    notifyListeners();

    try {
      final adminUser = await _repository.login(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );

      _state = AdminAuthState(
        status: AdminAuthStatus.authenticated,
        adminUser: adminUser,
        isInitializing: false,
        savedEmail: rememberMe ? email.trim() : null,
      );
      notifyListeners();
      return true;
    } on AccessDeniedException catch (e) {
      _state = _state.copyWith(
        status: AdminAuthStatus.accessDenied,
        errorMessage: e.message,
      );
      notifyListeners();
      return false;
    } on InvalidCredentialsException catch (e) {
      _state = _state.copyWith(
        status: AdminAuthStatus.error,
        errorMessage: e.message,
      );
      notifyListeners();
      return false;
    } on AdminAuthException catch (e) {
      _state = _state.copyWith(
        status: AdminAuthStatus.error,
        errorMessage: e.message,
      );
      notifyListeners();
      return false;
    } catch (e) {
      _state = _state.copyWith(
        status: AdminAuthStatus.error,
        errorMessage: 'An unexpected authentication error occurred. Please try again.',
      );
      notifyListeners();
      return false;
    }
  }

  /// Handles Logout action
  Future<void> logout() async {
    _state = AdminAuthState(
      status: AdminAuthStatus.unauthenticated,
      adminUser: null,
      isInitializing: false,
      savedEmail: _state.savedEmail,
    );
    notifyListeners();

    try {
      await _repository.logout();
    } catch (e) {
      debugPrint('[AdminAuthNotifier] Logout error: $e');
    }
  }

  /// Resets error state after displaying snackbar
  void clearError() {
    if (_state.errorMessage != null) {
      _state = _state.copyWith(errorMessage: null);
      notifyListeners();
    }
  }
}
