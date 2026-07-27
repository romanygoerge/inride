import '../../../../core/models/user_model.dart';
import '../../../../core/state/global_state.dart' show DriverVerificationStatus, UserRole;

abstract class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthCodeSent extends AuthState {
  final String verificationId;
  final String phoneNumber;

  const AuthCodeSent({required this.verificationId, required this.phoneNumber});
}

class AuthProfileSetupRequired extends AuthState {
  final String uid;
  final String phoneNumber;
  final UserRole role;

  const AuthProfileSetupRequired({
    required this.uid,
    required this.phoneNumber,
    required this.role,
  });
}

class DriverReviewPending extends AuthState {}

class DriverDocUploadRequired extends AuthState {}

class Authenticated extends AuthState {
  final UserModel user;
  final UserRole role;
  final DriverVerificationStatus driverStatus;

  const Authenticated({
    required this.user,
    required this.role,
    this.driverStatus = DriverVerificationStatus.unregistered,
  });
}

class Unauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);
}
