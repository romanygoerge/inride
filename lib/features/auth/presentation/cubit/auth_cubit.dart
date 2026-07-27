import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../../../core/repositories/auth_repository.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/state/global_state.dart' show DriverVerificationStatus, UserRole;
import '../../../../core/utils/auth_error_handler.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final SupabaseClient _supabase = Supabase.instance.client;

  AuthCubit(this._authRepository) : super(AuthInitial());

  Future<void> checkAuthSession() async {
    emit(AuthLoading());
    try {
      final currentUser = _authRepository.currentUser;
      if (currentUser != null) {
        await _loadUserProfile(currentUser.id, currentUser.phone ?? '', null);
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(AuthErrorHandler.getErrorMessage(e)));
    }
  }

  Future<void> signInWithGoogle(UserRole role) async {
    emit(AuthLoading());
    try {
      final authRes = await _authRepository.signInWithGoogle();
      final user = authRes.user ?? _authRepository.currentUser;
      if (user != null) {
        await _loadUserProfile(user.id, user.phone ?? '', role);
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(AuthErrorHandler.getErrorMessage(e)));
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    emit(AuthLoading());
    try {
      final authRes = await _authRepository.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
      );
      final user = authRes.user;
      if (user != null) {
        await _loadUserProfile(user.id, user.phone ?? '', role);
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(AuthErrorHandler.getErrorMessage(e)));
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    emit(AuthLoading());
    try {
      final authRes = await _authRepository.signInWithEmail(
        email: email,
        password: password,
      );
      final user = authRes.user;
      if (user != null) {
        await _loadUserProfile(user.id, user.phone ?? '', role);
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(AuthErrorHandler.getErrorMessage(e)));
    }
  }

  Future<void> resetPassword(String email) async {
    emit(AuthLoading());
    try {
      await _authRepository.resetPasswordForEmail(email);
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(AuthErrorHandler.getErrorMessage(e)));
    }
  }

  Future<void> signInWithPhone(String phoneNumber) async {
    emit(AuthLoading());
    try {
      await _authRepository.signInWithPhone(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          emit(AuthCodeSent(verificationId: verificationId, phoneNumber: phoneNumber));
        },
        onVerificationFailed: (e) {
          emit(AuthError(AuthErrorHandler.getErrorMessage(e)));
        },
        onVerificationCompleted: (credential) async {},
      );
    } catch (e) {
      emit(AuthError(AuthErrorHandler.getErrorMessage(e)));
    }
  }

  Future<void> verifyOTP(String verificationId, String smsCode, UserRole role) async {
    emit(AuthLoading());
    try {
      final authRes = await _authRepository.verifyOTP(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final user = authRes.user;
      if (user != null) {
        await _loadUserProfile(user.id, user.phone ?? '', role);
      } else {
        emit(const AuthError('فشل التحقق من الكود'));
      }
    } catch (e) {
      emit(AuthError(AuthErrorHandler.getErrorMessage(e)));
    }
  }

  Future<void> bypassLogin(String phone, UserRole role) async {
    emit(AuthLoading());
    try {
      final authRes = await _authRepository.signInAnonymously(role: role);
      final user = authRes.user;
      if (user != null) {
        await _loadUserProfile(user.id, phone, role);
      } else {
        final mockUser = UserModel(
          uid: '00000000-0000-4000-a000-000000000000',
          name: 'مستخدم تجريبي',
          phoneNumber: phone,
          email: '',
          role: role.name,
          rating: 5.0,
          walletBalance: 250.00,
          createdAt: DateTime.now(),
        );
        emit(Authenticated(user: mockUser, role: role, driverStatus: DriverVerificationStatus.unregistered));
      }
    } catch (e) {
      final mockUser = UserModel(
        uid: '00000000-0000-4000-a000-000000000000',
        name: 'مستخدم تجريبي (أوفلاين)',
        phoneNumber: phone,
        email: '',
        role: role.name,
        rating: 5.0,
        walletBalance: 250.00,
        createdAt: DateTime.now(),
      );
      emit(Authenticated(user: mockUser, role: role, driverStatus: DriverVerificationStatus.verified));
    }
  }

  Future<void> setupPassengerProfile(String uid, String name, String gender, String phoneNumber) async {
    emit(AuthLoading());
    try {
      await _supabase.from('users').upsert({
        'id': uid,
        'name': name,
        'phone_number': phoneNumber,
        'role': 'rider',
      });

      await _supabase.from('passengers').upsert({
        'id': uid,
        'name': name,
        'gender': gender,
        'created_at': DateTime.now().toIso8601String(),
      });

      final updatedUser = await _authRepository.fetchOrCreateUserProfile(uid, phoneNumber, UserRole.rider);
      emit(Authenticated(user: updatedUser, role: UserRole.rider));
    } catch (e) {
      emit(AuthError(AuthErrorHandler.getErrorMessage(e)));
    }
  }

  Future<void> _loadUserProfile(String uid, String phoneNumber, UserRole? fallbackRole) async {
    final userRes = await _supabase.from('users').select().eq('id', uid).maybeSingle();
    UserRole activeRole = fallbackRole ?? UserRole.rider;

    if (userRes != null) {
      final roleStr = userRes['role'];
      activeRole = (roleStr == 'driver' || roleStr == 'captain') ? UserRole.driver : UserRole.rider;
    }

    final userProfile = await _authRepository.fetchOrCreateUserProfile(uid, phoneNumber, activeRole);

    if (activeRole == UserRole.rider) {
      final passengerRes = await _supabase.from('passengers').select().eq('id', uid).maybeSingle();
      if (passengerRes == null || passengerRes['name'] == null) {
        emit(AuthProfileSetupRequired(uid: uid, phoneNumber: phoneNumber, role: UserRole.rider));
        return;
      }
      emit(Authenticated(user: userProfile, role: UserRole.rider));
    } else {
      final driverRes = await _supabase.from('drivers').select().eq('id', uid).maybeSingle();
      DriverVerificationStatus vStatus = DriverVerificationStatus.unregistered;
      
      if (driverRes != null) {
        final statusStr = driverRes['verification_status'] ?? driverRes['verificationStatus'] ?? 'unregistered';
        if (statusStr == 'verified') {
          vStatus = DriverVerificationStatus.verified;
        } else if (statusStr == 'submitted') {
          vStatus = DriverVerificationStatus.submitted;
        }
      }

      if (vStatus == DriverVerificationStatus.verified) {
        emit(Authenticated(user: userProfile, role: UserRole.driver, driverStatus: DriverVerificationStatus.verified));
      } else if (vStatus == DriverVerificationStatus.submitted) {
        emit(DriverReviewPending());
      } else {
        emit(DriverDocUploadRequired());
      }
    }
  }

  Future<void> selectRole(UserRole role) async {
    final state = this.state;
    if (state is Authenticated) {
      emit(AuthLoading());
      try {
        await _supabase.from('users').update({'role': role.name}).eq('id', state.user.uid);
        await _loadUserProfile(state.user.uid, state.user.phoneNumber, role);
      } catch (e) {
        emit(AuthError(AuthErrorHandler.getErrorMessage(e)));
      }
    }
  }

  Future<void> submitDriverDocuments({
    required String vehicleModel,
    required String licensePlate,
    required String driverName,
    required int driverAge,
    required String driverGender,
  }) async {
    final state = this.state;
    if (state is DriverDocUploadRequired || state is Authenticated) {
      final uid = _authRepository.currentUser?.id ?? '00000000-0000-4000-a000-000000000000';
      final phone = _authRepository.currentUser?.phone ?? '1012345678';
      
      emit(AuthLoading());
      try {
        final vehicleRes = await _supabase.from('vehicles').insert({
          'driver_id': uid,
          'model': vehicleModel,
          'number_plate': licensePlate,
          'color': 'فضي',
          'type': 'motorcycle',
        }).select('id').single();

        await _supabase.from('drivers').upsert({
          'id': uid,
          'verification_status': 'verified',
          'vehicle_id': vehicleRes['id'],
          'is_online': true,
          'is_available': true,
        });

        await _supabase.from('users').update({
          'name': driverName,
          'role': 'driver',
        }).eq('id', uid);

        await _loadUserProfile(uid, phone, UserRole.driver);
      } catch (e) {
        emit(AuthError(AuthErrorHandler.getErrorMessage(e)));
      }
    }
  }

  Future<void> logout() async {
    emit(AuthLoading());
    try {
      await _authRepository.signOut();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(AuthErrorHandler.getErrorMessage(e)));
    }
  }
}
