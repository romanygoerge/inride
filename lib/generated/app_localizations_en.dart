// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'inRide';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get back => 'Back';

  @override
  String get loading => 'Loading...';

  @override
  String get success => 'Success';

  @override
  String get error => 'Error';

  @override
  String get warning => 'Warning';

  @override
  String get done => 'Done';

  @override
  String get confirm => 'Confirm';

  @override
  String get retry => 'Retry';

  @override
  String get search => 'Search';

  @override
  String get filter => 'Filter';

  @override
  String get share => 'Share';

  @override
  String get close => 'Close';

  @override
  String get next => 'Next';

  @override
  String get previous => 'Previous';

  @override
  String get submit => 'Submit';

  @override
  String get continueText => 'Continue';

  @override
  String get skip => 'Skip';

  @override
  String get apply => 'Apply';

  @override
  String get refresh => 'Refresh';

  @override
  String get copy => 'Copy';

  @override
  String get viewDetails => 'View Details';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get authTitle => 'Sign In';

  @override
  String get welcomeMessage => 'Welcome to inRide';

  @override
  String get loginWithGoogle => 'Continue with Google';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get enterPhoneNumber => 'Enter your phone number';

  @override
  String get fullName => 'Full Name';

  @override
  String get enterFullName => 'Enter your full name';

  @override
  String get acceptTerms => 'I agree to Terms & Conditions';

  @override
  String get logout => 'Log Out';

  @override
  String get login => 'Sign In';

  @override
  String get register => 'Create New Account';

  @override
  String get enterPhonePrompt => 'Please enter your phone number';

  @override
  String get invalidPhoneFormat =>
      'Please enter a valid phone number (e.g. 1012345678)';

  @override
  String get sendingOtp => 'Sending verification code...';

  @override
  String get otpSent => 'Verification code sent successfully 📲';

  @override
  String get enterOtpCode => 'Enter Verification Code (OTP)';

  @override
  String get resendCode => 'Resend Code';

  @override
  String resendCodeTimer(int seconds) {
    return 'Resend in $seconds seconds';
  }

  @override
  String get verifyOtp => 'Verify Code';

  @override
  String get invalidOtp => 'Invalid verification code. Please try again';

  @override
  String get termsAndConditionsText => 'Terms & Conditions';

  @override
  String get privacyPolicyText => 'Privacy Policy';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get sendResetLink => 'Send Reset Link';

  @override
  String get emailAddress => 'Email Address';

  @override
  String get enterEmail => 'Enter your email address';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get driverRegistrationPrompt =>
      'Want to register as a Captain? Click here';

  @override
  String get passengerRole => 'Passenger';

  @override
  String get driverRole => 'Driver';

  @override
  String get selectService => 'Select Service';

  @override
  String get rideService => 'Ride Share';

  @override
  String get deliveryService => 'Package Delivery';

  @override
  String get heavyDeliveryService => 'Heavy Cargo';

  @override
  String get scooterService => 'Scooter Delivery';

  @override
  String get pickupLocation => 'Pickup Location';

  @override
  String get destinationLocation => 'Destination Location';

  @override
  String get selectDestination => 'Set destination on map';

  @override
  String get selectPickupOnMap => 'Set pickup location on map';

  @override
  String get offeredFare => 'Offered Fare';

  @override
  String get egp => 'EGP';

  @override
  String get requestRide => 'Request Ride Now';

  @override
  String get searchingForDrivers => 'Searching for nearby drivers...';

  @override
  String get offersReceived => 'Received Offers';

  @override
  String get acceptOffer => 'Accept Offer';

  @override
  String get declineOffer => 'Decline Offer';

  @override
  String get offerDetails => 'Offer Details';

  @override
  String get counterOffer => 'Make Counter Offer';

  @override
  String get driverIsOnTheWay => 'Driver is on the way 🚗';

  @override
  String get driverArrived => 'Driver arrived at pickup 📍';

  @override
  String get tripInProgress => 'Trip is currently in progress...';

  @override
  String get tripCompleted => 'Trip completed successfully 🎉';

  @override
  String get tripCanceled => 'Trip Canceled';

  @override
  String get cancelRide => 'Cancel Ride';

  @override
  String get cancelReason => 'Cancellation Reason';

  @override
  String get enterCounterOffer => 'Enter new offered fare';

  @override
  String get estimatedTime => 'Estimated Time';

  @override
  String get estimatedDistance => 'Estimated Distance';

  @override
  String get fareBreakdown => 'Fare Breakdown';

  @override
  String get baseFare => 'Base Fare';

  @override
  String get totalFare => 'Total Fare';

  @override
  String get driverDistance => 'Driver Distance';

  @override
  String get vehicleCategory => 'Vehicle Type';

  @override
  String get selectVehicleCategory => 'Select Vehicle Category';

  @override
  String get standardCar => 'Economy';

  @override
  String get comfortCar => 'Comfort';

  @override
  String get scooter => 'Scooter';

  @override
  String get deliveryTruck => 'Delivery Truck';

  @override
  String get packageDescription => 'Package Description';

  @override
  String get deliveryNotes => 'Delivery Notes';

  @override
  String get recipientPhone => 'Recipient Phone Number';

  @override
  String get recipientRegion => 'Region / Street';

  @override
  String get orderDeliveryNow => 'Order Delivery Now';

  @override
  String get shareLocationLink => 'Share Location Link';

  @override
  String get linkCopied => 'Location link copied successfully! 📋';

  @override
  String get recipientName => 'Recipient Name';

  @override
  String get enterRecipientName => 'Enter recipient name';

  @override
  String get enterPackageDetails => 'Enter package details and specifications';

  @override
  String get fragilePackage => 'Fragile Package';

  @override
  String get packageSize => 'Package Size';

  @override
  String get confirmRecipientLocation => 'Confirm Recipient Location';

  @override
  String get driverOnline => 'You are Online (Ready for requests)';

  @override
  String get driverOffline => 'You are Offline';

  @override
  String get newRequestAvailable => 'New ride request incoming!';

  @override
  String get acceptRequest => 'Accept Request';

  @override
  String get rejectRequest => 'Ignore';

  @override
  String get arrivedAtPickup => 'I\'ve arrived at pickup';

  @override
  String get startTrip => 'Start Trip';

  @override
  String get completeTrip => 'Complete Trip';

  @override
  String get passengerPhone => 'Passenger Phone Number';

  @override
  String get incomingOffer => 'New Offer from Driver';

  @override
  String get earningsToday => 'Today\'s Earnings';

  @override
  String get totalTrips => 'Total Trips';

  @override
  String get captainDashboard => 'Captain Dashboard';

  @override
  String get docUploadTitle => 'Upload Driver Documents';

  @override
  String get docUploadSubtitle =>
      'Please upload required documents to activate your account';

  @override
  String get driverLicense => 'Driver\'s License';

  @override
  String get vehicleLicense => 'Vehicle License';

  @override
  String get nationalId => 'National ID (Both Sides)';

  @override
  String get takePhoto => 'Take Photo with Camera';

  @override
  String get uploadFromGallery => 'Choose from Gallery';

  @override
  String get docSubmitted => 'Documents uploaded successfully!';

  @override
  String get reviewPendingTitle => 'Account Under Review';

  @override
  String get reviewPendingMessage =>
      'Our team is reviewing your documents. Your account will be activated within 24 hours.';

  @override
  String get underReview => 'Under Review';

  @override
  String get docPendingNote =>
      'Please wait for account approval by administration';

  @override
  String get profile => 'Profile';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'App Language';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get changeLanguage => 'Change App Language';

  @override
  String get appLanguage => 'App Language';

  @override
  String get theme => 'Appearance';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get accountSettings => 'Account Settings';

  @override
  String get changePhoneNumber => 'Change Phone Number';

  @override
  String get emergencyContacts => 'Emergency Contacts';

  @override
  String get savedAddresses => 'Saved Addresses';

  @override
  String get homeAddress => 'Home';

  @override
  String get workAddress => 'Work';

  @override
  String get wallet => 'Wallet & Payment';

  @override
  String get walletBalance => 'Wallet Balance';

  @override
  String get addFunds => 'Top Up Wallet';

  @override
  String get withdrawFunds => 'Withdraw Funds';

  @override
  String get transactionHistory => 'Transaction History';

  @override
  String get paymentMethods => 'Payment Methods';

  @override
  String get cashPayment => 'Cash Payment';

  @override
  String get walletPayment => 'Pay via Wallet';

  @override
  String get cardPayment => 'Credit Card';

  @override
  String get depositSuccess => 'Wallet topped up successfully!';

  @override
  String get insufficientBalance => 'Insufficient wallet balance';

  @override
  String get amount => 'Amount';

  @override
  String get enterAmount => 'Enter required amount';

  @override
  String get notificationsCenter => 'Notification Center';

  @override
  String get markAllRead => 'Mark All Read';

  @override
  String get deleteAllNotifications => 'Delete All';

  @override
  String get noNotifications => 'No notifications right now';

  @override
  String get chatTitle => 'Instant Chat';

  @override
  String get typeMessage => 'Type your message here...';

  @override
  String get send => 'Send';

  @override
  String get partnerTyping => 'Typing...';

  @override
  String get supportChat => 'Live Technical Support';

  @override
  String get messagesCenter => 'Messages Center';

  @override
  String get callPartner => 'Phone Call';

  @override
  String get emergencySos => 'Emergency SOS (122)';

  @override
  String get shareLiveLocation => 'Share Live Location';

  @override
  String get emergencyError => 'Unable to place emergency call to 122';

  @override
  String get emergencyDialNote => 'Direct emergency call will be made to 122';

  @override
  String get ratingsAndReviews => 'Ratings & Reviews';

  @override
  String get overallRating => 'Overall Rating';

  @override
  String get totalReviews => 'Total Reviews';

  @override
  String get submitRating => 'Submit Rating';

  @override
  String get writeComment => 'Write your feedback here...';

  @override
  String get noRatingsYet => 'No ratings or reviews yet';

  @override
  String get rateDriver => 'Rate Driver';

  @override
  String get ratePassenger => 'Rate Passenger';

  @override
  String get howWasYourTrip => 'How was your trip experience?';

  @override
  String get starRating => 'Star Rating';

  @override
  String get loadingMap => 'Loading map...';

  @override
  String get gpsDisabled => 'Location service (GPS) is disabled';

  @override
  String get permissionDenied => 'Location permission denied';

  @override
  String get locationPermissionTitle => 'Location Permission Required';

  @override
  String get locationPermissionMsg =>
      'The app requires location access to set pickup and destination points accurately.';

  @override
  String get grantPermission => 'Grant Permission';

  @override
  String get turnLeft => 'Turn Left';

  @override
  String get turnRight => 'Turn Right';

  @override
  String get goStraight => 'Continue Straight';

  @override
  String get arriveAtDestination => 'You will arrive at destination soon';

  @override
  String get recalculatingRoute => 'Recalculating route...';

  @override
  String get recenterMap => 'Recenter Map';

  @override
  String get simulationController => 'Simulation Panel';

  @override
  String get requiredField => 'This field is required';

  @override
  String get invalidEmail => 'Please enter a valid email address';

  @override
  String get invalidPhone => 'Please enter a valid phone number';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get networkError =>
      'Network error, please check your internet connection';

  @override
  String get serverError => 'Server error occurred, please try again later';

  @override
  String get unknownError => 'An unexpected error occurred';

  @override
  String get sessionExpired => 'Session expired, please sign in again';

  @override
  String get tryAgainLater => 'Please try again later';

  @override
  String get locationRequired => 'Please select a location on the map first';

  @override
  String get exitAppConfirmation => 'Confirm Exit';

  @override
  String get exitAppPrompt => 'Are you sure you want to exit the application?';

  @override
  String get areYouSureExit => 'Do you really want to exit?';

  @override
  String welcomeUser(String name) {
    return 'Welcome, $name';
  }

  @override
  String notificationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications',
      one: '1 notification',
      zero: 'No notifications',
    );
    return '$_temp0';
  }

  @override
  String distanceKm(String value) {
    return '$value km';
  }

  @override
  String distanceMeters(String value) {
    return '$value m';
  }

  @override
  String durationMinutes(int value) {
    return '$value min';
  }

  @override
  String durationHours(int value) {
    return '$value hr';
  }

  @override
  String get returnToApp => 'Return to App';

  @override
  String get captainOverlayTitle => 'inRide Captain';

  @override
  String get historyTitle => 'Trip History';

  @override
  String get noHistoryTrips => 'No previous trips found';

  @override
  String get tripDetails => 'Trip Details';

  @override
  String get rideHistory => 'Driver / Passenger Trips';

  @override
  String get supportTitle => 'Support & Help';

  @override
  String get supportSubtitle => 'We are here to help you 24/7';

  @override
  String get faqTitle => 'Frequently Asked Questions';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get callSupport => 'Call Support';

  @override
  String get emailSupport => 'Email Support';

  @override
  String get version => 'Version';

  @override
  String get legalTerms => 'Terms & Policies';

  @override
  String get aboutApp => 'About App';

  @override
  String get orSeparator => 'OR';

  @override
  String switchToRole(String role) {
    return 'Switch to $role';
  }

  @override
  String get switchLanguage => 'اللغة العربية';

  @override
  String get exitPreventionRider =>
      'You have an active trip. Please complete or cancel it first before exiting.';

  @override
  String get exitPreventionDriver =>
      'You are currently online or have an active trip. Please go offline or finish the trip first before exiting.';

  @override
  String get navDepart => 'Start moving';

  @override
  String get navArriveLeft => 'Destination on your left';

  @override
  String get navArriveRight => 'Destination on your right';

  @override
  String get navArrived => 'You have arrived';

  @override
  String get navContinue => 'Continue ahead';

  @override
  String navRoundaboutExit(String exit) {
    return 'Enter roundabout - Exit $exit';
  }

  @override
  String get navRoundabout => 'Enter roundabout';

  @override
  String get navMerge => 'Merge onto road';

  @override
  String get navTurnLeft => 'Turn left';

  @override
  String get navTurnRight => 'Turn right';

  @override
  String get navSlightLeft => 'Keep slightly left';

  @override
  String get navSlightRight => 'Keep slightly right';

  @override
  String get navSharpLeft => 'Sharp left turn';

  @override
  String get navSharpRight => 'Sharp right turn';

  @override
  String get navUturn => 'Make a U-turn';

  @override
  String get navStraight => 'Continue straight';

  @override
  String navAfterDistance(String distance) {
    return 'In $distance';
  }

  @override
  String navTowards(String street) {
    return 'Towards: $street';
  }

  @override
  String get navUnnamedRoad => 'Unnamed road';

  @override
  String get navExitFirst => '1st';

  @override
  String get navExitSecond => '2nd';

  @override
  String get navExitThird => '3rd';

  @override
  String get navExitFourth => '4th';

  @override
  String get navExitFifth => '5th';

  @override
  String navExitNumber(int n) {
    return 'No. $n';
  }

  @override
  String get editProfileImage => 'Edit Profile Photo';

  @override
  String get resetAction => 'Reset';

  @override
  String zoomLevel(String scale) {
    return 'Zoom: ${scale}x';
  }

  @override
  String get rotate90 => 'Rotate 90°';

  @override
  String get savingImage => 'Saving...';

  @override
  String get saveCircularImage => 'Save Circular Photo';

  @override
  String get imageProcessingError =>
      'An error occurred while processing the image. Please try again.';

  @override
  String get simClosePanel => 'Close Simulator';

  @override
  String get simPanelTitle => 'Interactive Simulation Panel';

  @override
  String get simToolsHeader => '🎛️ Instant Simulation Tools (Testing)';

  @override
  String simStatus(String status) {
    return 'Status: $status';
  }

  @override
  String get simSwitchToPassenger => 'Switch to Passenger 🚶';

  @override
  String get simSwitchToDriver => 'Switch to Driver 🚗';

  @override
  String get simApproveDriver => 'Approve Driver Instantly ✅';

  @override
  String get simDriverApproved => 'Driver account verified and approved!';

  @override
  String get simRevokeVerification => 'Revoke Verification ❌';

  @override
  String get simDriverRevoked => 'Driver verification revoked (unregistered)';

  @override
  String get simGenerateOffers => 'Generate Nearby Driver Offers ⚡';

  @override
  String get simDriverArrival => 'Simulate Driver Arrival 🏁';

  @override
  String get simStartTrip => 'Simulate Trip Start 🚀';

  @override
  String get simCompleteTrip => 'Simulate Trip Completion 💳';

  @override
  String get simResetRides => 'Reset Rides 🔄';

  @override
  String get simRidesReset => 'All active requests have been reset.';

  @override
  String get simNote =>
      'Note: This panel allows you to test the full ride scenario (request, bidding, accept, tracking, arrival, payment) directly without additional devices.';

  @override
  String get myCurrentLocation => 'My Current Location';

  @override
  String get currentLocation => 'Current Location';

  @override
  String get whereFrom => 'From where?';

  @override
  String get whereTo => 'Where to?';

  @override
  String get setPickupHint => 'Set pickup location...';

  @override
  String get searchDestinationHint => 'Search for destination or place...';

  @override
  String get whereToGo => 'Where do you want to go?';

  @override
  String get whereToRide => 'Where would you like to be picked up?';

  @override
  String get whereToGoShort => 'Where are you going?';

  @override
  String get locationPermissionRide =>
      'Please allow location access to book a ride.';

  @override
  String get selectDestinationFirst => 'Please select a destination first';

  @override
  String get scooterComingSoon =>
      'Sorry, scooter service is coming soon! Please choose motorcycle or car for now.';

  @override
  String get noInternetOffline => 'No internet connection - Offline mode';

  @override
  String get requestCarRide => 'Request Car Ride';

  @override
  String get requestBikeRide => 'Request Bike Ride';

  @override
  String get setDestinationToStart => 'Set your destination to request a ride';

  @override
  String get chooseDestinationFromSearch =>
      'Choose a place from the search field above to see the cost and start booking your ride.';

  @override
  String get chooseFare => 'Choose your offered fare';

  @override
  String get privateCar => 'Private Car';

  @override
  String get motorcycleBike => 'Motorcycle / Bike';

  @override
  String get motorcycle => 'Motorcycle';

  @override
  String get passengerCount => 'Number of Passengers';

  @override
  String get requestRideNow => 'Request Ride Now';

  @override
  String get dearCustomer => 'Dear Customer';

  @override
  String get selectVehicleForRide => 'Select vehicle type for ride';

  @override
  String get selectVehicleToStart => 'Select vehicle type to start your ride';

  @override
  String get privateCarOption => 'Private Car';

  @override
  String get privateCarDesc => 'Comfortable and safe ride in a private car';

  @override
  String get bikeOption => 'Motorcycle';

  @override
  String get bikeDesc => 'Fast and safe ride to avoid traffic jams';

  @override
  String get chooseServiceToStart => 'Choose service to get started';

  @override
  String get rideOption => 'Ride';

  @override
  String get rideDesc =>
      'Your car or bike ride is fast and safe at your suggested price';

  @override
  String get deliveryOption => 'Delivery';

  @override
  String get deliveryDesc =>
      'Send your packages with a quick biker at the tap of a button';

  @override
  String get setPickupAuto =>
      'Set pickup location automatically based on your location';

  @override
  String get detectingLocation => 'Detecting your location...';

  @override
  String noResultsFor(String query) {
    return 'No results found for \"$query\"';
  }

  @override
  String get scooterComingSoonShort => 'Scooter (Coming Soon)';

  @override
  String get enableLocationToWork =>
      'Please enable location permissions to start working.';

  @override
  String get creditLimitReached =>
      'Sorry, you have reached your credit limit. Please top up your wallet to continue receiving requests.';

  @override
  String errorSendingOffer(String error) {
    return 'Error sending offer: $error';
  }

  @override
  String get bookingRide => 'Booking ride and confirming acceptance...';

  @override
  String get customPriceOffer => 'Custom Price Offer';

  @override
  String get sendOffer => 'Send Offer';

  @override
  String get onlineForWork => 'Online for Work';

  @override
  String get offlineStatus => 'Offline';

  @override
  String get availableRequestsAround => 'Available Requests Around You';

  @override
  String get offlineMode => 'Offline Mode';

  @override
  String get youAreInactive => 'You are currently inactive';

  @override
  String get activateToReceive =>
      'Activate the button above to receive ride notifications and start working.';

  @override
  String get requestsPaused => 'Receiving requests is temporarily paused';

  @override
  String get debtLimitMessage =>
      'You have reached the maximum debt limit (-100 EGP) due to commission rates from previous trips. Please top up your wallet to reactivate your account and receive passenger requests again.';

  @override
  String get goToWallet => 'Go to Wallet to Top Up';

  @override
  String get noRequestsInArea => 'No ride requests in your area right now...';

  @override
  String get packageSender => 'Package Sender';

  @override
  String get passenger => 'Passenger';

  @override
  String get walletPaymentShort => '💳 Wallet';

  @override
  String get cashPaymentShort => '💵 Cash';

  @override
  String timeRemaining(int seconds) {
    return '${seconds}s left';
  }

  @override
  String get expired => 'Expired';

  @override
  String get newUser => 'New User';

  @override
  String distanceToPassenger(String distText, String tripDist, String etaMin) {
    return 'Distance to passenger: $distText  •  Trip distance: $tripDist km\nTime to customer: $etaMin min';
  }

  @override
  String get packageDetails => 'Sent Package Details:';

  @override
  String packageContent(String content) {
    return 'Package content: $content';
  }

  @override
  String get notSpecified => 'Not specified';

  @override
  String deliveryInstructions(String notes) {
    return 'Delivery instructions: $notes';
  }

  @override
  String get customerCounterOffer => 'Customer\'s Counter Offer';

  @override
  String get suggestedFare => 'Suggested Fare';

  @override
  String customerSuggestedFare(int fare) {
    return 'Customer suggested a new fare: $fare EGP';
  }

  @override
  String get skipAction => 'Skip';

  @override
  String get acceptNegotiation => 'Accept Negotiation';

  @override
  String get offerSentWaiting =>
      'Price offer sent successfully... Waiting for customer';

  @override
  String get acceptFare => 'Accept Fare';

  @override
  String get cash => 'Cash';

  @override
  String get walletTopUpTitle => 'Wallet Top Up';

  @override
  String get cancelledByCustomer => 'Cancelled by customer';

  @override
  String get rideCancelled => 'Ride Cancelled';

  @override
  String get rideExpiredNoDrivers =>
      'Ride request expired due to no driver response. Please try again.';

  @override
  String get requestCancelledSuccess => 'Request cancelled successfully';

  @override
  String get shareLocationInstall =>
      'To easily locate you, please make sure the app is installed on your device.';

  @override
  String shareLocationMessage(String link) {
    return 'To easily locate you, please make sure the app is installed on your device.\n\nPlease click this link to set your delivery location on the map: $link';
  }

  @override
  String get recipientLocationTitle => 'Set Delivery Pickup Location';

  @override
  String get recipientLocationGps => 'Recipient Location (GPS)';

  @override
  String get loadingCoordinates => 'Determining location coordinates... 📍';

  @override
  String get invalidLink => 'This link is invalid or you are not authorized ❌';

  @override
  String get linkExpired =>
      'This link has expired because the order is inactive or already completed ⚠️';

  @override
  String get locationAlreadyConfirmed =>
      'Location has already been confirmed for this order ✅';

  @override
  String get orderNotFound => 'Sorry, order details not found ❌';

  @override
  String get loadingError =>
      'An error occurred while loading order data. Please check your internet connection.';

  @override
  String get locationPermissionDenied =>
      'Location permission denied. Please enable it to continue ⚠️';

  @override
  String get gpsAccuracyError =>
      'Unable to get your location with high accuracy. Please check GPS settings or select manually.';

  @override
  String get gpsAccuracyErrorAlt =>
      'Failed to get your location with high accuracy. Please check GPS settings or select manually.';

  @override
  String get saveLocationError =>
      'An error occurred while saving your location. Please try again.';

  @override
  String get savingAndNotifying => 'Updating system and notifying driver...';

  @override
  String get connectingToSystem => 'Connecting to system...';

  @override
  String get unexpectedError =>
      'An unexpected error occurred. Please try again.';

  @override
  String get retryAction => 'Retry';

  @override
  String get closePage => 'Close Page';

  @override
  String senderWantsToSend(String sender) {
    return '($sender) wants to send you a package. Press the button below to share your location and help the driver.';
  }

  @override
  String packageDescLabel(String desc) {
    return 'Package description: $desc';
  }

  @override
  String get useMyCurrentLocation => 'Use My Current Location 📍';

  @override
  String get selectLocationManually => 'Select location manually on map';

  @override
  String get confirmLocation => 'Confirm Location 📌';

  @override
  String get locationConfirmedSuccess => 'Location confirmed successfully! 🎉';

  @override
  String get locationConfirmedMessage =>
      'Thank you! Delivery coordinates saved and driver has been notified. The driver is on the way.';

  @override
  String get driver => 'Driver';

  @override
  String get car => 'Car';

  @override
  String get vehicleMotorcycleBike => 'Motorcycle / Bike';

  @override
  String get vehicleScooter => 'Scooter';

  @override
  String get vehiclePrivateCar => 'Private Car';

  @override
  String get authUnknownError =>
      'An unknown error occurred, please try again later.';

  @override
  String get authNoInternet =>
      'No internet connection. Please check your network and try again.';

  @override
  String get authServerConnect =>
      'Unable to connect to server. Please check internet connection.';

  @override
  String get authInvalidCredentials => 'Invalid login credentials.';

  @override
  String get authAlreadyRegistered =>
      'This account is already registered, please log in.';

  @override
  String get authEmailNotConfirmed =>
      'Email not confirmed, please check your inbox.';

  @override
  String get authWeakPassword => 'Password should be at least 6 characters.';

  @override
  String get authInvalidEmail => 'Invalid email address.';

  @override
  String get authRateLimit =>
      'Rate limit exceeded. Please wait and try again later.';

  @override
  String get authOtpExpired =>
      'Verification code expired, please request a new one.';

  @override
  String get authInvalidOtp => 'Invalid verification code.';

  @override
  String get authCancelled => 'Operation canceled by user.';

  @override
  String authErrorPrefix(String error) {
    return 'An error occurred: $error';
  }
}
