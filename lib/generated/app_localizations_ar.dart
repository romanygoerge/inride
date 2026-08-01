// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'inRide';

  @override
  String get ok => 'موافق';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get edit => 'تعديل';

  @override
  String get delete => 'حذف';

  @override
  String get back => 'رجوع';

  @override
  String get loading => 'جاري التحميل...';

  @override
  String get success => 'نجاح';

  @override
  String get error => 'خطأ';

  @override
  String get warning => 'تنبيه';

  @override
  String get done => 'تم';

  @override
  String get confirm => 'تأكيد';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get search => 'بحث';

  @override
  String get filter => 'تصفية';

  @override
  String get share => 'مشاركة';

  @override
  String get close => 'إغلاق';

  @override
  String get next => 'التالي';

  @override
  String get previous => 'السابق';

  @override
  String get submit => 'إرسال';

  @override
  String get continueText => 'متابعة';

  @override
  String get skip => 'تخطي';

  @override
  String get apply => 'تطبيق';

  @override
  String get refresh => 'تحديث';

  @override
  String get copy => 'نسخ';

  @override
  String get viewDetails => 'عرض التفاصيل';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get authTitle => 'تسجيل الدخول';

  @override
  String get welcomeMessage => 'مرحباً بك في inRide';

  @override
  String get loginWithGoogle => 'المتابعة باستخدام Google';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get enterPhoneNumber => 'أدخل رقم الهاتف';

  @override
  String get fullName => 'الاسم بالكامل';

  @override
  String get enterFullName => 'أدخل اسمك بالكامل';

  @override
  String get acceptTerms => 'أوافق على الشروط والأحكام';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get register => 'إنشاء حساب جديد';

  @override
  String get enterPhonePrompt => 'يرجى إدخال رقم الهاتف';

  @override
  String get invalidPhoneFormat =>
      'يرجى إدخال رقم هاتف صحيح (مثال: 1012345678)';

  @override
  String get sendingOtp => 'جاري إرسال رمز التحقق...';

  @override
  String get otpSent => 'تم إرسال رمز التحقق بنجاح 📲';

  @override
  String get enterOtpCode => 'أدخل رمز التحقق (OTP)';

  @override
  String get resendCode => 'إعادة إرسال الرمز';

  @override
  String resendCodeTimer(int seconds) {
    return 'إعادة الإرسال خلال $seconds ثانية';
  }

  @override
  String get verifyOtp => 'تأكيد الرمز';

  @override
  String get invalidOtp => 'رمز التحقق غير صحيح، حاول مرة أخرى';

  @override
  String get termsAndConditionsText => 'الشروط والأحكام';

  @override
  String get privacyPolicyText => 'سياسة الخصوصية';

  @override
  String get forgotPassword => 'هل نسيت كلمة المرور؟';

  @override
  String get resetPassword => 'إعادة ضبط كلمة المرور';

  @override
  String get sendResetLink => 'إرسال رابط الضبط';

  @override
  String get emailAddress => 'البريد الإلكتروني';

  @override
  String get enterEmail => 'أدخل بريدك الإلكتروني';

  @override
  String get passwordsDoNotMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get driverRegistrationPrompt => 'هل تريد التسجيل ككابتن؟ اضغط هنا';

  @override
  String get passengerRole => 'راكب';

  @override
  String get driverRole => 'كابتن';

  @override
  String get selectService => 'اختر الخدمة';

  @override
  String get rideService => 'رحلة توصيل';

  @override
  String get deliveryService => 'توصيل طلبات (ديلفري)';

  @override
  String get heavyDeliveryService => 'نقل ثقيل';

  @override
  String get scooterService => 'توصيل سكوتر';

  @override
  String get pickupLocation => 'مكان الانطلاق';

  @override
  String get destinationLocation => 'مكان الوصول';

  @override
  String get selectDestination => 'حدد وجهتك على الخريطة';

  @override
  String get selectPickupOnMap => 'حدد نقطة الانطلاق على الخريطة';

  @override
  String get offeredFare => 'السعر المقترح';

  @override
  String get egp => 'ج.م';

  @override
  String get requestRide => 'اطلب رحلتك الآن';

  @override
  String get searchingForDrivers => 'جاري البحث عن كباتن بالقرب منك...';

  @override
  String get offersReceived => 'العروض المقدمة';

  @override
  String get acceptOffer => 'قبول العرض';

  @override
  String get declineOffer => 'رفض العرض';

  @override
  String get offerDetails => 'تفاصيل العرض';

  @override
  String get counterOffer => 'تقديم عرض مضاد';

  @override
  String get driverIsOnTheWay => 'الكابتن في طريقه إليك 🚗';

  @override
  String get driverArrived => 'وصل الكابتن إلى نقطة الانطلاق 📍';

  @override
  String get tripInProgress => 'الرحلة قيد التنفيذ الآن...';

  @override
  String get tripCompleted => 'تم إنهاء الرحلة بنجاح 🎉';

  @override
  String get tripCanceled => 'تم إلغاء الرحلة';

  @override
  String get cancelRide => 'إلغاء الرحلة';

  @override
  String get cancelReason => 'سبب الإلغاء';

  @override
  String get enterCounterOffer => 'أدخل السعر المقترح الجديد';

  @override
  String get estimatedTime => 'الوقت المتوقع';

  @override
  String get estimatedDistance => 'المسافة المتوقعة';

  @override
  String get fareBreakdown => 'تفاصيل الأجرة';

  @override
  String get baseFare => 'الأجرة الأساسية';

  @override
  String get totalFare => 'إجمالي الأجرة';

  @override
  String get driverDistance => 'المسافة عن الكابتن';

  @override
  String get vehicleCategory => 'نوع المركبة';

  @override
  String get selectVehicleCategory => 'اختر فئة السيارة';

  @override
  String get standardCar => 'اقتصادي';

  @override
  String get comfortCar => 'راحة';

  @override
  String get scooter => 'سكوتر';

  @override
  String get deliveryTruck => 'سيارة نقل';

  @override
  String get packageDescription => 'وصف الطرد';

  @override
  String get deliveryNotes => 'ملاحظات التوصيل';

  @override
  String get recipientPhone => 'رقم هاتف المستلم';

  @override
  String get recipientRegion => 'المنطقة / الشارع';

  @override
  String get orderDeliveryNow => 'اطلب ديلفري الآن';

  @override
  String get shareLocationLink => 'مشاركة رابط تحديد الموقع';

  @override
  String get linkCopied => 'تم نسخ رابط التحديد بنجاح! 📋';

  @override
  String get recipientName => 'اسم المستلم';

  @override
  String get enterRecipientName => 'أدخل اسم المستلم';

  @override
  String get enterPackageDetails => 'أدخل تفاصيل ومواصفات الشحنة';

  @override
  String get fragilePackage => 'طرد قابل للكسر';

  @override
  String get packageSize => 'حجم الطرد';

  @override
  String get confirmRecipientLocation => 'تأكيد موقع المستلم';

  @override
  String get driverOnline => 'أنت الآن متصل (جاهز لاستقبال الطلبات)';

  @override
  String get driverOffline => 'أنت الآن غير متصل';

  @override
  String get newRequestAvailable => 'طلب رحلة جديد قادم!';

  @override
  String get acceptRequest => 'قبول الطلب';

  @override
  String get rejectRequest => 'تجاهل';

  @override
  String get arrivedAtPickup => 'أنا وصلت للراكب';

  @override
  String get startTrip => 'بدء الرحلة';

  @override
  String get completeTrip => 'إنهاء الرحلة';

  @override
  String get passengerPhone => 'رقم هاتف الراكب';

  @override
  String get incomingOffer => 'عرض جديد من كابتن';

  @override
  String get earningsToday => 'أرباح اليوم';

  @override
  String get totalTrips => 'إجمالي الرحلات';

  @override
  String get captainDashboard => 'لوحة تحكم الكابتن';

  @override
  String get docUploadTitle => 'رفع مستندات الكابتن';

  @override
  String get docUploadSubtitle => 'يرجى رفع المستندات المطلوبة لتفعيل حسابك';

  @override
  String get driverLicense => 'رخصة القيادة';

  @override
  String get vehicleLicense => 'رخصة المركبة';

  @override
  String get nationalId => 'الرقم القومي (وجهان)';

  @override
  String get takePhoto => 'التقاط صورة بالكاميرا';

  @override
  String get uploadFromGallery => 'اختيار من معرض الصور';

  @override
  String get docSubmitted => 'تم رفع المستندات بنجاح!';

  @override
  String get reviewPendingTitle => 'حسابك قيد المراجعة';

  @override
  String get reviewPendingMessage =>
      'يقوم فريقنا بمراجعة مستنداتك حالياً. سيتم تفعيل حسابك خلال 24 ساعة.';

  @override
  String get underReview => 'قيد المراجعة';

  @override
  String get docPendingNote => 'يرجى الانتظار لحين اعتماد حسابك من قبل الإدارة';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'لغة التطبيق';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get changeLanguage => 'تغيير لغة التطبيق';

  @override
  String get appLanguage => 'لغة التطبيق';

  @override
  String get theme => 'المظهر';

  @override
  String get darkMode => 'الوضع الداكن';

  @override
  String get lightMode => 'الوضع الفاتح';

  @override
  String get accountSettings => 'إعدادات الحساب';

  @override
  String get changePhoneNumber => 'تغيير رقم الهاتف';

  @override
  String get emergencyContacts => 'جهات اتصال الطوارئ';

  @override
  String get savedAddresses => 'العناوين المحفوظة';

  @override
  String get homeAddress => 'المنزل';

  @override
  String get workAddress => 'العمل';

  @override
  String get wallet => 'المحفظة والدفع';

  @override
  String get walletBalance => 'رصيد المحفظة';

  @override
  String get addFunds => 'شحن المحفظة';

  @override
  String get withdrawFunds => 'سحب الرصيد';

  @override
  String get transactionHistory => 'سجل المعاملات';

  @override
  String get paymentMethods => 'طرق الدفع';

  @override
  String get cashPayment => 'دفع نقدي (كاش)';

  @override
  String get walletPayment => 'دفع بواسطة المحفظة';

  @override
  String get cardPayment => 'بطاقة ائتمان';

  @override
  String get depositSuccess => 'تم شحن المحفظة بنجاح!';

  @override
  String get insufficientBalance => 'رصيد المحفظة غير كافٍ';

  @override
  String get amount => 'المبلغ';

  @override
  String get enterAmount => 'أدخل المبلغ المطلوب';

  @override
  String get notificationsCenter => 'مركز الإشعارات';

  @override
  String get markAllRead => 'تعليم الكل كمقروء';

  @override
  String get deleteAllNotifications => 'حذف الكل';

  @override
  String get noNotifications => 'لا توجد إشعارات حالياً';

  @override
  String get chatTitle => 'المحادثة الفورية';

  @override
  String get typeMessage => 'اكتب رسالتك هنا...';

  @override
  String get send => 'إرسال';

  @override
  String get partnerTyping => 'يكتب الآن...';

  @override
  String get supportChat => 'الدعم الفني المباشر';

  @override
  String get messagesCenter => 'مركز الرسائل';

  @override
  String get callPartner => 'الاتصال الهاتفي';

  @override
  String get emergencySos => 'طوارئ SOS (122)';

  @override
  String get shareLiveLocation => 'مشاركة الموقع المباشر';

  @override
  String get emergencyError => 'تعذر إجراء اتصال الطوارئ بالرقم 122';

  @override
  String get emergencyDialNote => 'سيتم الاتصال مباشرة بشرطة النجدة 122';

  @override
  String get ratingsAndReviews => 'المراجعات والتقييمات';

  @override
  String get overallRating => 'التقييم العام';

  @override
  String get totalReviews => 'إجمالي الآراء';

  @override
  String get submitRating => 'إرسال التقييم';

  @override
  String get writeComment => 'اكتب تعليقك هنا...';

  @override
  String get noRatingsYet => 'لا توجد تقييمات أو مراجعات حالياً';

  @override
  String get rateDriver => 'تقييم الكابتن';

  @override
  String get ratePassenger => 'تقييم الراكب';

  @override
  String get howWasYourTrip => 'كيف كانت تجربتك في هذه الرحلة؟';

  @override
  String get starRating => 'التقييم بالنجوم';

  @override
  String get loadingMap => 'جاري تحميل الخريطة...';

  @override
  String get gpsDisabled => 'خدمة تحديد الموقع (GPS) غير مفعلة';

  @override
  String get permissionDenied => 'تم رفض إذن الوصول للموقع';

  @override
  String get locationPermissionTitle => 'إذن الوصول للموقع مطلوب';

  @override
  String get locationPermissionMsg =>
      'يحتاج التطبيق لاستخدام موقعك لتحديد نقطة الانطلاق والوصول بدقة.';

  @override
  String get grantPermission => 'منح الإذن';

  @override
  String get turnLeft => 'اتجه يساراً';

  @override
  String get turnRight => 'اتجه يميناً';

  @override
  String get goStraight => 'واصل السير مباشرة';

  @override
  String get arriveAtDestination => 'ستصل إلى وجهتك قريباً';

  @override
  String get recalculatingRoute => 'جاري إعادة حساب المسار...';

  @override
  String get recenterMap => 'إعادة ضبط الخريطة';

  @override
  String get simulationController => 'لوحة المحاكاة';

  @override
  String get requiredField => 'هذا الحقل مطلوب';

  @override
  String get invalidEmail => 'يرجى إدخال بريد إلكتروني صحيح';

  @override
  String get invalidPhone => 'يرجى إدخال رقم هاتف صحيح';

  @override
  String get passwordTooShort => 'كلمة المرور يجب ألا تقل عن 6 أحرف';

  @override
  String get networkError => 'خطأ في الاتصال بالشبكة، يرجى التحقق من الإنترنت';

  @override
  String get serverError => 'حدث خطأ في الخادم، يرجى المحاولة لاحقاً';

  @override
  String get unknownError => 'حدث خطأ غير متوقع';

  @override
  String get sessionExpired => 'انتهت الجلسة، يرجى تسجيل الدخول مجدداً';

  @override
  String get tryAgainLater => 'يرجى المحاولة مرة أخرى لاحقاً';

  @override
  String get locationRequired => 'يرجى تحديد الموقع على الخريطة أولاً';

  @override
  String get exitAppConfirmation => 'تأكيد الخروج';

  @override
  String get exitAppPrompt => 'هل أنت تأكد من رغبتك في الخروج من التطبيق؟';

  @override
  String get areYouSureExit => 'هل تريد الخروج حقاً؟';

  @override
  String welcomeUser(String name) {
    return 'مرحباً بك، $name';
  }

  @override
  String notificationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إشعار',
      many: '$count إشعاراً',
      few: '$count إشعارات',
      two: 'إشعاران',
      one: 'إشعار واحد',
      zero: 'لا توجد إشعارات',
    );
    return '$_temp0';
  }

  @override
  String distanceKm(String value) {
    return '$value كم';
  }

  @override
  String distanceMeters(String value) {
    return '$value متر';
  }

  @override
  String durationMinutes(int value) {
    return '$value دقيقة';
  }

  @override
  String durationHours(int value) {
    return '$value ساعة';
  }

  @override
  String get returnToApp => 'الرجوع للتطبيق';

  @override
  String get captainOverlayTitle => 'inRide الكابتن';

  @override
  String get historyTitle => 'سجل الرحلات';

  @override
  String get noHistoryTrips => 'لا توجد رحلات سابقة';

  @override
  String get tripDetails => 'تفاصيل الرحلة';

  @override
  String get rideHistory => 'رحلات السائق / الراكب';

  @override
  String get supportTitle => 'الدعم والمساعدة';

  @override
  String get supportSubtitle => 'نحن هنا لمساعدتك على مدار 24 ساعة';

  @override
  String get faqTitle => 'الأسئلة الشائعة';

  @override
  String get contactUs => 'تواصل معنا';

  @override
  String get callSupport => 'الاتصال بالدعم';

  @override
  String get emailSupport => 'مراسلة الدعم';

  @override
  String get version => 'الإصدار';

  @override
  String get legalTerms => 'الشروط والسياسات';

  @override
  String get aboutApp => 'عن التطبيق';

  @override
  String get orSeparator => 'أو';

  @override
  String switchToRole(String role) {
    return 'التبديل إلى وضع $role';
  }

  @override
  String get switchLanguage => 'English Language';

  @override
  String get exitPreventionRider =>
      'لديك رحلة نشطة، يجب إلغاء الرحلة أو إنهاؤها أولاً قبل الخروج من التطبيق.';

  @override
  String get exitPreventionDriver =>
      'أنت في وضع الأونلاين أو لديك رحلة نشطة، يرجى إيقاف الأونلاين أو إنهاء الرحلة أولاً قبل الخروج من التطبيق.';

  @override
  String get navDepart => 'ابدأ التحرك';

  @override
  String get navArriveLeft => 'وجهتك على اليسار';

  @override
  String get navArriveRight => 'وجهتك على اليمين';

  @override
  String get navArrived => 'وصلت إلى وجهتك';

  @override
  String get navContinue => 'استمر للأمام';

  @override
  String navRoundaboutExit(String exit) {
    return 'ادخل الدوار - المخرج $exit';
  }

  @override
  String get navRoundabout => 'ادخل الدوار';

  @override
  String get navMerge => 'اندمج في الطريق';

  @override
  String get navTurnLeft => 'انعطف يساراً';

  @override
  String get navTurnRight => 'انعطف يميناً';

  @override
  String get navSlightLeft => 'انحرف قليلاً لليسار';

  @override
  String get navSlightRight => 'انحرف قليلاً لليمين';

  @override
  String get navSharpLeft => 'انعطف بحدة لليسار';

  @override
  String get navSharpRight => 'انعطف بحدة لليمين';

  @override
  String get navUturn => 'قم بالدوران';

  @override
  String get navStraight => 'استمر مباشرة';

  @override
  String navAfterDistance(String distance) {
    return 'بعد $distance';
  }

  @override
  String navTowards(String street) {
    return 'نحو: $street';
  }

  @override
  String get navUnnamedRoad => 'طريق غير مسمى';

  @override
  String get navExitFirst => 'الأول';

  @override
  String get navExitSecond => 'الثاني';

  @override
  String get navExitThird => 'الثالث';

  @override
  String get navExitFourth => 'الرابع';

  @override
  String get navExitFifth => 'الخامس';

  @override
  String navExitNumber(int n) {
    return 'رقم $n';
  }

  @override
  String get editProfileImage => 'تعديل الصورة الشخصية';

  @override
  String get resetAction => 'إعادة ضبط';

  @override
  String zoomLevel(String scale) {
    return 'التكبير: ${scale}x';
  }

  @override
  String get rotate90 => 'تدوير 90°';

  @override
  String get savingImage => 'جاري الحفظ...';

  @override
  String get saveCircularImage => 'حفظ الصورة الكروية';

  @override
  String get imageProcessingError =>
      'حدث خطأ أثناء معالجة الصورة. يرجى المحاولة مرة أخرى.';

  @override
  String get simClosePanel => 'إغلاق المحاكي';

  @override
  String get simPanelTitle => 'لوحة المحاكاة التفاعلية';

  @override
  String get simToolsHeader => '🎛️ أدوات المحاكاة الفورية (للاختبار)';

  @override
  String simStatus(String status) {
    return 'الحالة: $status';
  }

  @override
  String get simSwitchToPassenger => 'التبديل لراكب 🚶';

  @override
  String get simSwitchToDriver => 'التبديل لسائق 🚗';

  @override
  String get simApproveDriver => 'اعتماد السائق فوراً ✅';

  @override
  String get simDriverApproved => 'تم تفعيل واعتماد حساب السائق بنجاح!';

  @override
  String get simRevokeVerification => 'إلغاء التوثيق ❌';

  @override
  String get simDriverRevoked => 'تم إلغاء اعتماد السائق (غير مسجل)';

  @override
  String get simGenerateOffers => 'توليد عروض أسائقين قريبة ⚡';

  @override
  String get simDriverArrival => 'محاكاة وصول السائق 🏁';

  @override
  String get simStartTrip => 'محاكاة بدء الرحلة 🚀';

  @override
  String get simCompleteTrip => 'محاكاة إنهاء الرحلة الدفع 💳';

  @override
  String get simResetRides => 'إعادة ضبط الرحلات 🔄';

  @override
  String get simRidesReset => 'تم إعادة تعيين كافة الطلبات النشطة.';

  @override
  String get simNote =>
      'ملاحظة: تتيح لك هذه اللوحة اختبار سيناريو الرحلة كاملاً (الطلب، المزايدة، القبول، التتبع، الوصول، الدفع) مباشرة دون الحاجة لأجهزة إضافية.';

  @override
  String get myCurrentLocation => 'موقعي الحالي';

  @override
  String get currentLocation => 'الموقع الحالي';

  @override
  String get whereFrom => 'من أين؟';

  @override
  String get whereTo => 'إلى أين؟';

  @override
  String get setPickupHint => 'حدد موقع الركوب...';

  @override
  String get searchDestinationHint => 'ابحث عن وجهة أو موقع...';

  @override
  String get whereToGo => 'إلى أين تريد الذهاب؟';

  @override
  String get whereToRide => 'من أين تريد الركوب؟';

  @override
  String get whereToGoShort => 'أين تريد الذهاب؟';

  @override
  String get locationPermissionRide =>
      'يرجى السماح بالوصول لموقعك الجغرافي لتتمكن من حجز رحلة.';

  @override
  String get selectDestinationFirst => 'يرجى تحديد وجهة أولاً للبدء';

  @override
  String get scooterComingSoon =>
      'عذراً، خدمة الاسكوتر ستتوفر قريباً! يرجى اختيار الموتوسيكل أو السيارة حالياً.';

  @override
  String get noInternetOffline => 'لا يوجد اتصال بالإنترنت - الوضع غير المتصل';

  @override
  String get requestCarRide => 'طلب رحلة ملاكي';

  @override
  String get requestBikeRide => 'طلب رحلة بايك';

  @override
  String get setDestinationToStart => 'حدد وجهتك للبدء في طلب رحلة';

  @override
  String get chooseDestinationFromSearch =>
      'اختر مكاناً تود الذهاب إليه من حقل البحث في الأعلى لمعرفة التكلفة والبدء في طلب الرحلة.';

  @override
  String get chooseFare => 'اختر سعر الرحلة المقترح';

  @override
  String get privateCar => 'سيارة ملاكي';

  @override
  String get motorcycleBike => 'موتوسيكل / بايك';

  @override
  String get motorcycle => 'موتوسيكل';

  @override
  String get passengerCount => 'عدد الأفراد / الركاب';

  @override
  String get requestRideNow => 'طلب رحلة الآن';

  @override
  String get dearCustomer => 'عميلنا العزيز';

  @override
  String get selectVehicleForRide => 'اختر نوع المركبة للرحلة';

  @override
  String get selectVehicleToStart => 'حدد نوع المركبة لبدء رحلتك';

  @override
  String get privateCarOption => 'سيارة ملاكي (Car)';

  @override
  String get privateCarDesc => 'رحلة مريحة وآمنة بالسيارة الملاكي الخاصة';

  @override
  String get bikeOption => 'بايك (Motorcycle)';

  @override
  String get bikeDesc => 'رحلة سريعة وآمنة لتفادي زحام المرور بالدراجة';

  @override
  String get chooseServiceToStart => 'اختر الخدمة للبدء فوراً';

  @override
  String get rideOption => 'رحلة (Ride)';

  @override
  String get rideDesc =>
      'رحلتك بالسيارة أو البايك سريعة وآمنة بأسعارك المقترحة';

  @override
  String get deliveryOption => 'ديلفري (Delivery)';

  @override
  String get deliveryDesc => 'أرسل طرودك وهداياك بضغطة زر مع بايكر سريع';

  @override
  String get setPickupAuto => 'تحديد موقع الركوب تلقائياً بناءً على موقعك';

  @override
  String get detectingLocation => 'جاري تحديد موقعك...';

  @override
  String noResultsFor(String query) {
    return 'لم نتمكن من العثور على \"$query\"';
  }

  @override
  String get scooterComingSoonShort => 'اسكوتر (قريباً)';

  @override
  String get enableLocationToWork => 'يرجى تفعيل صلاحيات الموقع للبدء بالعمل.';

  @override
  String get creditLimitReached =>
      'عفواً، لقد وصلت للحد الائتماني المسموح به. يرجى شحن محفظتك للاستمرار في استقبال الطلبات.';

  @override
  String errorSendingOffer(String error) {
    return 'خطأ في إرسال العرض: $error';
  }

  @override
  String get bookingRide => 'جاري حجز الرحلة وتأكيد القبول...';

  @override
  String get customPriceOffer => 'عرض سعر مخصص';

  @override
  String get sendOffer => 'إرسال العرض';

  @override
  String get onlineForWork => 'متصل للعمل';

  @override
  String get offlineStatus => 'غير متصل';

  @override
  String get availableRequestsAround => 'الطلبات المتاحة حولك';

  @override
  String get offlineMode => 'وضع عدم الاتصال';

  @override
  String get youAreInactive => 'أنت غير نشط حالياً';

  @override
  String get activateToReceive =>
      'قم بتفعيل الزر بالأعلى لتلقي إشعارات رحلات الركاب والبدء بالعمل.';

  @override
  String get requestsPaused => 'تم إيقاف تلقي الطلبات مؤقتاً';

  @override
  String get debtLimitMessage =>
      'لقد وصلت إلى الحد الأقصى للمديونية (-100 ج.م) بسبب نسب عمولة الرحلات السابقة. يرجى شحن رصيد المحفظة لتفعيل حسابك وتلقي طلبات الركاب مرة أخرى.';

  @override
  String get goToWallet => 'الانتقال للمحفظة للشحن';

  @override
  String get noRequestsInArea => 'لا توجد طلبات رحلات حالياً في منطقتك...';

  @override
  String get packageSender => 'مرسل الطرد';

  @override
  String get passenger => 'راكب';

  @override
  String get walletPaymentShort => '💳 المحفظة';

  @override
  String get cashPaymentShort => '💵 كاش';

  @override
  String timeRemaining(int seconds) {
    return 'باقي $seconds ث';
  }

  @override
  String get expired => 'منتهي';

  @override
  String get newUser => 'مستخدم جديد';

  @override
  String distanceToPassenger(String distText, String tripDist, String etaMin) {
    return 'المسافة إلى الراكب: $distText  •  مسافة الرحلة: $tripDist كم\nالوقت للوصول للعميل: $etaMin دقائق';
  }

  @override
  String get packageDetails => 'تفاصيل الطرد المرسل:';

  @override
  String packageContent(String content) {
    return 'محتوى الطرد: $content';
  }

  @override
  String get notSpecified => 'غير محدد';

  @override
  String deliveryInstructions(String notes) {
    return 'تعليمات التوصيل: $notes';
  }

  @override
  String get customerCounterOffer => 'عرض العميل المقترح';

  @override
  String get suggestedFare => 'الأجرة المقترحة';

  @override
  String customerSuggestedFare(int fare) {
    return 'اقترح العميل أجرة جديدة: $fare ج.م';
  }

  @override
  String get skipAction => 'تخطى';

  @override
  String get acceptNegotiation => 'قبول التفاوض';

  @override
  String get offerSentWaiting => 'تم إرسال عرض السعر بنجاح... بانتظار العميل';

  @override
  String get acceptFare => 'قبول الأجرة';

  @override
  String get cash => 'كاش';

  @override
  String get walletTopUpTitle => 'شحن رصيد المحفظة';

  @override
  String get cancelledByCustomer => 'تم الإلغاء بواسطة العميل';

  @override
  String get rideCancelled => 'تم إلغاء الرحلة';

  @override
  String get rideExpiredNoDrivers =>
      'انتهت صلاحية طلب التوصيل لعدم استجابة السائقين. يرجى إعادة المحاولة.';

  @override
  String get requestCancelledSuccess => 'تم إلغاء الطلب بنجاح';

  @override
  String get shareLocationInstall =>
      'لتحديد موقعك بسهولة، يُرجى التأكد من تثبيت التطبيق على جهازك.';

  @override
  String shareLocationMessage(String link) {
    return 'لتحديد موقعك بسهولة، يُرجى التأكد من تثبيت التطبيق على جهازك.\n\nمن فضلك اضغط على هذا الرابط لتحديد موقع تسليم الطرد الخاص بك على الخريطة لتسهيل التوصيل: $link';
  }

  @override
  String get recipientLocationTitle => 'تحديد موقع استلام الديلفري';

  @override
  String get recipientLocationGps => 'موقع المستلم (GPS)';

  @override
  String get loadingCoordinates => 'جاري تحديد إحداثيات الموقع... 📍';

  @override
  String get invalidLink => 'هذا الرابط غير صالح أو غير مصرح لك بالوصول ❌';

  @override
  String get linkExpired =>
      'انتهت صلاحية هذا الرابط لأن الطلب غير نشط أو مكتمل بالفعل ⚠️';

  @override
  String get locationAlreadyConfirmed =>
      'تم تحديد وتأكيد الموقع مسبقاً لهذا الطلب ✅';

  @override
  String get orderNotFound => 'عذراً، لم يتم العثور على تفاصيل هذا الطلب ❌';

  @override
  String get loadingError =>
      'حدث خطأ أثناء تحميل بيانات الطلب. يرجى التأكد من اتصالك بالإنترنت.';

  @override
  String get locationPermissionDenied =>
      'تم رفض صلاحية الوصول للموقع الجغرافي. يرجى تفعيل الصلاحية للمتابعة ⚠️';

  @override
  String get gpsAccuracyError =>
      'تعذر جلب موقعك الجغرافي بدقة عالية. يرجى التحقق من تفعيل GPS بجهازك أو التحديد يدوياً.';

  @override
  String get gpsAccuracyErrorAlt =>
      'فشل جلب موقعك الجغرافي بدقة عالية. يرجى التحقق من إعدادات GPS بجهازك أو تحديد موقعك يدوياً.';

  @override
  String get saveLocationError =>
      'حدث خطأ أثناء حفظ موقعك المحدد. يرجى المحاولة مرة أخرى.';

  @override
  String get savingAndNotifying => 'جاري تحديث النظام وإخطار الكابتن...';

  @override
  String get connectingToSystem => 'جاري الاتصال بالنظام...';

  @override
  String get unexpectedError => 'حدث خطأ غير متوقع. يرجى المحاولة مجدداً.';

  @override
  String get retryAction => 'إعادة المحاولة';

  @override
  String get closePage => 'إغلاق الصفحة';

  @override
  String senderWantsToSend(String sender) {
    return 'يريد ($sender) إرسال طرد إليك، اضغط على الزر بالأسفل لمشاركة موقعك الحالي وتسهيل مهمة الكابتن.';
  }

  @override
  String packageDescLabel(String desc) {
    return 'وصف الطرد: $desc';
  }

  @override
  String get useMyCurrentLocation => 'استخدام موقعي الحالي 📍';

  @override
  String get selectLocationManually => 'تحديد الموقع يدويًا على الخريطة';

  @override
  String get confirmLocation => 'تأكيد الموقع 📌';

  @override
  String get locationConfirmedSuccess => 'تم تحديد موقعك بنجاح! 🎉';

  @override
  String get locationConfirmedMessage =>
      'شكراً لك، تم حفظ إحداثيات التوصيل وتحديث التكلفة لدى الكابتن تلقائياً. السائق في طريقه إليك الآن.';

  @override
  String get driver => 'سائق';

  @override
  String get car => 'عربية';

  @override
  String get vehicleMotorcycleBike => 'موتوسيكل / بايك';

  @override
  String get vehicleScooter => 'اسكوتر';

  @override
  String get vehiclePrivateCar => 'سيارة ملاكي';

  @override
  String get authUnknownError => 'حدث خطأ غير معروف، يرجى المحاولة لاحقاً.';

  @override
  String get authNoInternet =>
      'لا يوجد اتصال بالإنترنت. يرجى التحقق من الشبكة وإعادة المحاولة.';

  @override
  String get authServerConnect =>
      'تعذر الاتصال بالسيرفر. يرجى التأكد من الاتصال بالإنترنت.';

  @override
  String get authInvalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get authAlreadyRegistered =>
      'هذا الحساب مسجل بالفعل، يرجى تسجيل الدخول.';

  @override
  String get authEmailNotConfirmed =>
      'البريد الإلكتروني غير مفعل، يرجى مراجعة بريدك الإلكتروني لتأكيده.';

  @override
  String get authWeakPassword =>
      'كلمة المرور ضعيفة. يجب أن تتكون من 6 أحرف على الأقل.';

  @override
  String get authInvalidEmail => 'البريد الإلكتروني غير صالح.';

  @override
  String get authRateLimit =>
      'تم تجاوز عدد المحاولات المسموح بها. يرجى الانتظار قليلاً ثم المحاولة لاحقاً.';

  @override
  String get authOtpExpired => 'رمز التحقق منتهي الصلاحية، يرجى طلب رمز جديد.';

  @override
  String get authInvalidOtp => 'رمز التحقق غير صحيح.';

  @override
  String get authCancelled => 'تم إلغاء العملية بواسطة المستخدم.';

  @override
  String authErrorPrefix(String error) {
    return 'حدث خطأ: $error';
  }
}
