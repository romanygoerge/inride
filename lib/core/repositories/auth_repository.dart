import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../models/driver_model.dart';
import '../services/phone_auth_service.dart';
import '../state/global_state.dart' show UserRole;


class AuthRepository {
  static final AuthRepository instance = AuthRepository._internal();
  factory AuthRepository() => instance;
  AuthRepository._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final PhoneAuthService _phoneAuthService = PhoneAuthService.instance;

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;

  /// Sign Up with Email and Password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'role': role == UserRole.driver ? 'captain' : 'user',
      },
    );

    if (response.user != null) {
      await fetchOrCreateUserProfile(
        response.user!.id,
        response.user!.phone ?? '',
        role,
        fullNameOverride: fullName.trim(),
        emailOverride: email.trim(),
      );
    }
    return response;
  }

  /// Sign In with Email and Password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Reset Password via Email
  Future<void> resetPasswordForEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email.trim(),
    );
  }

  /// Trigger Supabase Phone Authentication (OTP)
  Future<void> signInWithPhone({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(Exception e) onVerificationFailed,
    required Function(dynamic credential) onVerificationCompleted,
  }) async {
    try {
      await _phoneAuthService.sendOtp(phoneNumber: phoneNumber);
      onCodeSent(phoneNumber, null);
    } catch (e) {
      debugPrint('[AuthRepository] signInWithPhone failed: $e');
      onVerificationFailed(e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Verify OTP and Sign in. Afterwards, fetch or initialize Supabase user profile.
  Future<AuthResponse> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    return await _phoneAuthService.verifyOtp(
      phoneNumber: verificationId,
      token: smsCode,
    );
  }

  /// Sign in with Google using native GoogleSignIn SDK on mobile (verifying ID token)
  /// and browser-based OAuth redirect flow on Web.
  Future<AuthResponse> signInWithGoogle({UserRole role = UserRole.rider}) async {
    try {
      const googleWebClientId = '562418460475-ha1n442q4d21h1mdhrega86gkja89h1b.apps.googleusercontent.com';

      if (kIsWeb) {
        final bool redirected = await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
        );
        if (!redirected) {
          throw const AuthException('لم يتم استكمال عملية تسجيل الدخول عبر متصفح الويب');
        }
        return AuthResponse(
          session: _supabase.auth.currentSession,
          user: _supabase.auth.currentUser,
        );
      }

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: googleWebClientId,
        clientId: kIsWeb ? googleWebClientId : null,
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw const AuthException('تم إلغاء عملية تسجيل الدخول بواسطة المستخدم');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        // Fallback to browser-based OAuth if ID Token is null
        const String redirectUrl = 'com.inride.inride_app://login-callback';
        final bool redirected = await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectUrl,
        );
        if (!redirected) {
          throw const AuthException('لم يتم الحصول على معرف Google ID Token');
        }
        return AuthResponse(
          session: _supabase.auth.currentSession,
          user: _supabase.auth.currentUser,
        );
      }

      final authResponse = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = authResponse.user ?? _supabase.auth.currentUser;
      if (user != null) {
        final fullName = googleUser.displayName ?? user.userMetadata?['full_name'] ?? 'مستخدم جوجل';
        final avatarUrl = googleUser.photoUrl ?? user.userMetadata?['avatar_url'];
        await fetchOrCreateUserProfile(
          user.id,
          user.phone ?? '',
          role,
          fullNameOverride: fullName,
          emailOverride: googleUser.email,
          avatarUrlOverride: avatarUrl,
        );
      }

      return authResponse;
    } catch (e) {
      debugPrint('[AuthRepository] signInWithGoogle failed: $e');
      rethrow;
    }
  }


  /// Alternative sign-in for testing/development (Web/Simulator)
  Future<AuthResponse> signInAnonymously({UserRole role = UserRole.rider}) async {
    final email = role == UserRole.driver ? 'dev_driver@inride.app' : 'dev_rider@inride.app';
    const password = 'DevPassword123!';
    try {
      return await _supabase.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      try {
        final res = await _supabase.auth.signUp(email: email, password: password);
        if (res.session != null) {
          return res;
        }
        try {
          return await _supabase.auth.signInWithPassword(email: email, password: password);
        } catch (_) {
          return res;
        }
      } catch (signUpErr) {
        try {
          return await _supabase.auth.signInAnonymously();
        } catch (_) {
          return AuthResponse(
            session: _supabase.auth.currentSession,
            user: _supabase.auth.currentUser,
          );
        }
      }
    }
  }

  /// Fetch user profile from Supabase. Creates/upserts a profile in `profiles` and `users` tables.
  Future<UserModel> fetchOrCreateUserProfile(
    String uid,
    String phoneNumber,
    UserRole role, {
    String? fullNameOverride,
    String? emailOverride,
    String? avatarUrlOverride,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    final email = emailOverride ?? currentUser?.email ?? '';
    final rawName = fullNameOverride ?? currentUser?.userMetadata?['full_name'] ?? currentUser?.userMetadata?['name'] ?? 'مستخدم جديد';
    final avatarUrl = avatarUrlOverride ?? currentUser?.userMetadata?['avatar_url'] ?? currentUser?.userMetadata?['picture'];

    // Fetch existing user record first to see if they already exist and have a role
    final response = await _supabase.from('users').select().eq('id', uid).maybeSingle();

    // Determine active role: prioritize existing database role to preserve settings/profile types
    UserRole activeRole = role;
    if (response != null) {
      final String? existingRoleStr = response['role'] as String?;
      if (existingRoleStr == 'driver') {
        activeRole = UserRole.driver;
      } else if (existingRoleStr == 'rider') {
        activeRole = UserRole.rider;
      }
    }

    final dbRole = activeRole == UserRole.driver ? 'captain' : 'user';

    // 1. Ensure `profiles` table contains the user record
    try {
      final nowIso = DateTime.now().toIso8601String();
      await _supabase.from('profiles').upsert({
        'id': uid,
        'full_name': rawName,
        'email': email,
        'phone': phoneNumber.isNotEmpty ? phoneNumber : currentUser?.phone,
        'role': dbRole,
        'created_at': nowIso,
        'updated_at': nowIso,
      });
    } catch (e) {
      debugPrint('[AuthRepository] Profile sync notice: $e');
    }

    UserModel newUser;
    if (response != null) {
      newUser = UserModel.fromMap(Map<String, dynamic>.from(response), uid);
      
      // Update existing record if it has default placeholder values or other updates
      final updates = <String, dynamic>{};
      if (newUser.name == 'مستخدم جديد' && rawName != 'مستخدم جديد') {
        updates['name'] = rawName;
        newUser = newUser.copyWith(name: rawName);
      }
      if ((newUser.phoneNumber.isEmpty || newUser.phoneNumber.startsWith('+20 10 1234 5678')) && phoneNumber.isNotEmpty) {
        updates['phone_number'] = phoneNumber;
        newUser = newUser.copyWith(phoneNumber: phoneNumber);
      }
      if (avatarUrl != null && response['avatar_url'] != avatarUrl) {
        updates['avatar_url'] = avatarUrl;
      }
      
      if (updates.isNotEmpty) {
        await _supabase.from('users').update(updates).eq('id', uid);
        debugPrint('[AuthRepository] Updated existing user $uid with: $updates');
      }
    } else {
      newUser = UserModel(
        uid: uid,
        name: rawName,
        phoneNumber: phoneNumber.isEmpty ? (currentUser?.phone ?? '+20 10 1234 5678') : phoneNumber,
        email: email,
        role: activeRole.name,
        rating: 5.0,
        walletBalance: 250.00,
        createdAt: DateTime.now(),
      );

      final userMap = newUser.toMap();
      userMap['id'] = uid;
      if (avatarUrl != null) userMap['avatar_url'] = avatarUrl;
      await _supabase.from('users').upsert(userMap);
      debugPrint('[AuthRepository] Created new user record for $uid');
    }

    // 3. Ensure role-specific tables are populated
    if (activeRole == UserRole.rider) {
      await _supabase.from('passengers').upsert({
        'id': uid,
        'name': newUser.name,
        'phone': newUser.phoneNumber,
        'email': newUser.email,
        'rating': 5.0,
        'total_trips': 0,
      });
      debugPrint('[AuthRepository] Synced passenger profile for $uid');
    } else if (activeRole == UserRole.driver) {
      final driverRes = await _supabase.from('drivers').select().eq('id', uid).maybeSingle();
      final Map<String, dynamic> driverData;
      
      if (driverRes != null) {
        driverData = Map<String, dynamic>.from(driverRes);
      } else {
        driverData = DriverModel(
          uid: uid,
          isOnline: false,
          isAvailable: false,
          verificationStatus: 'unregistered',
        ).toDatabaseMap();
      }
      
      await _supabase.from('drivers').upsert(driverData);
      debugPrint('[AuthRepository] Synced driver profile for $uid');
    }

    return newUser;
  }

  /// Sign out the current user completely
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      debugPrint('[AuthRepository] Supabase auth.signOut succeeded');
    } catch (e) {
      debugPrint('[AuthRepository] Supabase signOut error: $e');
    }
    try {
      if (kIsWeb) {
        await GoogleSignIn(
          clientId: '562418460475-ha1n442q4d21h1mdhrega86gkja89h1b.apps.googleusercontent.com',
        ).signOut();
      } else {
        await GoogleSignIn().signOut();
      }
    } catch (e) {
      debugPrint('[AuthRepository] GoogleSignIn signOut error: $e');
    }
  }


  /// Link current user with Phone Number
  Future<UserResponse> linkWithPhone({
    required String verificationId,
    required String smsCode,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('لا يوجد مستخدم نشط للربط');
    }
    return await _supabase.auth.updateUser(
      UserAttributes(phone: verificationId),
    );
  }
}
