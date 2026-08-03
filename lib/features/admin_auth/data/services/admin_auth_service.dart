import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/errors/admin_auth_exception.dart';
import '../../domain/models/admin_user.dart';

/// Data Service responsible for low-level interaction with Supabase Auth & Database
class AdminAuthService {
  final SupabaseClient _client;

  AdminAuthService({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  /// Returns the current Supabase Auth User if active session exists
  User? get currentAuthUser => _client.auth.currentUser;

  /// Returns current Supabase Auth Session
  Session? get currentSession => _client.auth.currentSession;

  /// Stream of Supabase Auth state changes (login, logout, token refreshed)
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Authenticates admin user with email and password via Supabase Auth.
  /// Validates presence and active status in the `admins` table.
  /// Updates `last_login` timestamp upon verification.
  Future<AdminUser> signInAdmin({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    try {
      // 1. Authenticate with Supabase Auth
      final AuthResponse authResponse = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = authResponse.user;
      if (user == null) {
        throw const InvalidCredentialsException('Authentication failed. User session is null.');
      }

      final cleanEmail = email.trim().toLowerCase();
      final List<Map<String, dynamic>> response = await _client
          .from('admins')
          .select()
          .or('auth_user_id.eq.${user.id},email.eq.$cleanEmail')
          .limit(1);

      // 3. Verify user exists in `admins` table
      if (response.isEmpty) {
        // Immediately sign out unauthorized user
        await signOutAdmin();
        throw const AccessDeniedException(
          'Access Denied: Your account is not registered as an administrator.',
        );
      }

      final adminData = response.first;
      final adminUser = AdminUser.fromJson(adminData);

      // 4. Verify account active status (`is_active = true`)
      if (!adminUser.isActive) {
        await signOutAdmin();
        throw const AccessDeniedException(
          'Access Denied: Your admin account has been deactivated. Please contact Super Admin.',
        );
      }

      // 5. Update `last_login` timestamp in `admins` table
      final now = DateTime.now().toUtc().toIso8601String();
      try {
        await _client
            .from('admins')
            .update({'last_login': now})
            .eq('id', adminUser.id);
      } catch (e) {
        debugPrint('[AdminAuthService] Non-critical error updating last_login: $e');
      }

      // 6. Save Remember Me state to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('admin_remember_me', rememberMe);
      if (rememberMe) {
        await prefs.setString('admin_saved_email', email.trim());
      } else {
        await prefs.remove('admin_saved_email');
      }

      return adminUser.copyWith(lastLogin: DateTime.parse(now));
    } on AuthException catch (e) {
      debugPrint('[AdminAuthService] Supabase AuthException: ${e.message}');
      if (e.message.contains('Invalid login credentials') || e.code == 'invalid_credentials') {
        throw const InvalidCredentialsException();
      }
      throw AdminAuthException(e.message, code: e.code);
    } on AdminAuthException {
      rethrow;
    } catch (e) {
      debugPrint('[AdminAuthService] Unexpected error during signInAdmin: $e');
      throw AdminAuthException('Failed to complete admin sign-in: ${e.toString()}');
    }
  }

  /// Restores session and validates if current user is an active admin
  Future<AdminUser?> getCurrentAdminProfile() async {
    try {
      final user = currentAuthUser;
      if (user == null) return null;

      final List<Map<String, dynamic>> response = await _client
          .from('admins')
          .select()
          .eq('auth_user_id', user.id)
          .limit(1);

      if (response.isEmpty) {
        await signOutAdmin();
        return null;
      }

      final adminUser = AdminUser.fromJson(response.first);
      if (!adminUser.isActive) {
        await signOutAdmin();
        return null;
      }

      return adminUser;
    } catch (e) {
      debugPrint('[AdminAuthService] Error fetching admin profile: $e');
      return null;
    }
  }

  /// Signs out from Supabase Auth and clears local session cache
  Future<void> signOutAdmin() async {
    try {
      await _client.auth.signOut(scope: SignOutScope.global);
    } catch (e) {
      try {
        await _client.auth.signOut(scope: SignOutScope.local);
      } catch (err) {
        debugPrint('[AdminAuthService] Fallback signOut error: $err');
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('admin_remember_me') ?? false;
      if (!rememberMe) {
        await prefs.remove('admin_saved_email');
      }
    } catch (e) {
      debugPrint('[AdminAuthService] SharedPreferences clear error: $e');
    }
  }

  /// Retrieves saved email if Remember Me was selected
  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('admin_remember_me') ?? false;
    if (rememberMe) {
      return prefs.getString('admin_saved_email');
    }
    return null;
  }
}
