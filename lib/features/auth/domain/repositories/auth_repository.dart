import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/state/global_state.dart' show UserRole;

abstract class IAuthRepository {
  User? get currentUser;
  Session? get currentSession;

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  });

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> resetPasswordForEmail(String email);

  Future<void> signInWithPhone({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(Exception e) onVerificationFailed,
    required Function(dynamic credential) onVerificationCompleted,
  });

  Future<AuthResponse> verifyOTP({
    required String verificationId,
    required String smsCode,
  });

  Future<AuthResponse> signInWithGoogle({UserRole role = UserRole.rider});

  Future<AuthResponse> signInAnonymously({UserRole role = UserRole.rider});

  Future<UserModel> fetchOrCreateUserProfile(
    String uid,
    String phoneNumber,
    UserRole role, {
    String? fullNameOverride,
    String? emailOverride,
    String? avatarUrlOverride,
  });

  Future<void> signOut();
}
