enum DriverVerificationStatus { unregistered, submitted, verified, rejected }

/// Module responsible for driver document upload and verification state.
class DriverVerificationModule {
  DriverVerificationStatus verificationStatus = DriverVerificationStatus.unregistered;
  String? driverAddress;
  String? driverRejectionReason;
  String? driverIdCardPath;
  String? driverLicensePath;
  String? vehicleRegistrationPath;
  String? vehicleName;
  String? vehicleNumber;

  // Vehicle details
  String? driverVehicleCategory; // 'motorcycle' or 'private_car'
  bool driverHasAC = false;
  int driverMaxPassengers = 4;
  String? driverNationalIdUrl;
  String? driverLicenseUrl;
  String? driverVehicleFrontUrl;
  List<String> driverVehicleImages = [];

  bool get hasDriverProfile =>
      verificationStatus == DriverVerificationStatus.verified ||
      verificationStatus == DriverVerificationStatus.submitted ||
      driverNationalIdUrl != null;

  void reset() {
    verificationStatus = DriverVerificationStatus.unregistered;
    driverAddress = null;
    driverRejectionReason = null;
    driverIdCardPath = null;
    driverLicensePath = null;
    vehicleRegistrationPath = null;
    vehicleName = null;
    vehicleNumber = null;
    driverVehicleCategory = null;
    driverHasAC = false;
    driverMaxPassengers = 4;
    driverNationalIdUrl = null;
    driverLicenseUrl = null;
    driverVehicleFrontUrl = null;
    driverVehicleImages = [];
  }
}
