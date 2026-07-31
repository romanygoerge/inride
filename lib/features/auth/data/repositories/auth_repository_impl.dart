import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/state/global_state.dart' show UserRole;
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl({AuthRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? AuthRemoteDataSource();

  @override
  User? get currentUser => _remoteDataSource.currentUser;

  @override
  Session? get currentSession => _remoteDataSource.currentSession;

  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) {
    return _remoteDataSource.signUpWithEmail(
      email: email,
      password: password,
      fullName: fullName,
      role: role,
    );
  }

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _remoteDataSource.signInWithEmail(email: email, password: password);
  }

  @override
  Future<void> resetPasswordForEmail(String email) {
    return _remoteDataSource.resetPasswordForEmail(email);
  }

  @override
  Future<void> signInWithPhone({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(Exception e) onVerificationFailed,
    required Function(dynamic credential) onVerificationCompleted,
  }) {
    return _remoteDataSource.signInWithPhone(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onVerificationFailed: onVerificationFailed,
      onVerificationCompleted: onVerificationCompleted,
    );
  }

  @override
  Future<AuthResponse> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) {
    return _remoteDataSource.verifyOTP(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  @override
  Future<AuthResponse> signInWithGoogle({UserRole role = UserRole.rider}) {
    return _remoteDataSource.signInWithGoogle(role: role);
  }

  @override
  Future<AuthResponse> signInAnonymously({UserRole role = UserRole.rider}) {
    return _remoteDataSource.signInAnonymously(role: role);
  }

  @override
  Future<UserModel> fetchOrCreateUserProfile(
    String uid,
    String phoneNumber,
    UserRole role, {
    String? fullNameOverride,
    String? emailOverride,
    String? avatarUrlOverride,
  }) {
    return _remoteDataSource.fetchOrCreateUserProfile(
      uid,
      phoneNumber,
      role,
      fullNameOverride: fullNameOverride,
      emailOverride: emailOverride,
      avatarUrlOverride: avatarUrlOverride,
    );
  }

  @override
  Future<void> signOut() {
    return _remoteDataSource.signOut();
  }
}
