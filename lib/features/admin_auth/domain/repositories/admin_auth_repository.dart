import '../models/admin_user.dart';

/// Repository interface for Admin Authentication
abstract class AdminAuthRepository {
  /// Authenticates admin user with email and password
  Future<AdminUser> login({
    required String email,
    required String password,
    bool rememberMe = true,
  });

  /// Signs out current admin
  Future<void> logout();

  /// Gets current active admin profile (session restoration)
  Future<AdminUser?> getCurrentAdmin();

  /// Gets saved email if Remember Me was selected
  Future<String?> getSavedEmail();
}
