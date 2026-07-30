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
  String get pickupLocation => 'Pickup Location';

  @override
  String get destinationLocation => 'Destination Location';

  @override
  String get selectDestination => 'Set destination on map';

  @override
  String get offeredFare => 'Offered Fare';

  @override
  String get egp => 'EGP';

  @override
  String get requestRide => 'Request Ride Now';

  @override
  String get searchingForDrivers => 'Searching for drivers...';

  @override
  String get offersReceived => 'Received Offers';

  @override
  String get acceptOffer => 'Accept Offer';

  @override
  String get declineOffer => 'Decline Offer';

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
  String get notificationsCenter => 'Notification Center';

  @override
  String get markAllRead => 'Mark All Read';

  @override
  String get deleteAllNotifications => 'Delete All';

  @override
  String get noNotifications => 'No notifications right now';

  @override
  String get emergencySos => 'Emergency SOS (122)';

  @override
  String get shareLiveLocation => 'Share Live Location';

  @override
  String get emergencyError => 'Unable to place emergency call to 122';

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
  String get profile => 'Profile';

  @override
  String get wallet => 'Wallet & Payment';

  @override
  String get walletBalance => 'Wallet Balance';

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
}
