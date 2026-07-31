import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../state/global_state.dart' show UserRole;
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';

class AuthRepository implements IAuthRepository {
  static final AuthRepository instance = AuthRepository._internal();
  factory AuthRepository() => instance;
  AuthRepository._internal() : _impl = AuthRepositoryImpl();

  final AuthRepositoryImpl _impl;

  @override
  User? get currentUser => _impl.currentUser;

  @override
  Session? get currentSession => _impl.currentSession;

  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) =>
      _impl.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
      );

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _impl.signInWithEmail(email: email, password: password);

  @override
  Future<void> resetPasswordForEmail(String email) =>
      _impl.resetPasswordForEmail(email);

  @override
  Future<void> signInWithPhone({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(Exception e) onVerificationFailed,
    required Function(dynamic credential) onVerificationCompleted,
  }) =>
      _impl.signInWithPhone(
        phoneNumber: phoneNumber,
        onCodeSent: onCodeSent,
        onVerificationFailed: onVerificationFailed,
        onVerificationCompleted: onVerificationCompleted,
      );

  @override
  Future<AuthResponse> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) =>
      _impl.verifyOTP(verificationId: verificationId, smsCode: smsCode);

  @override
  Future<AuthResponse> signInWithGoogle({UserRole role = UserRole.rider}) =>
      _impl.signInWithGoogle(role: role);

  @override
  Future<AuthResponse> signInAnonymously({UserRole role = UserRole.rider}) =>
      _impl.signInAnonymously(role: role);

  @override
  Future<UserModel> fetchOrCreateUserProfile(
    String uid,
    String phoneNumber,
    UserRole role, {
    String? fullNameOverride,
    String? emailOverride,
    String? avatarUrlOverride,
  }) =>
      _impl.fetchOrCreateUserProfile(
        uid,
        phoneNumber,
        role,
        fullNameOverride: fullNameOverride,
        emailOverride: emailOverride,
        avatarUrlOverride: avatarUrlOverride,
      );

  @override
  Future<void> signOut() => _impl.signOut();
}
