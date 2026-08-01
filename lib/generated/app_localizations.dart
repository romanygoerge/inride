import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'inRide'**
  String get appTitle;

  /// No description provided for @ok.
  ///
  /// In ar, this message translates to:
  /// **'موافق'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// No description provided for @loading.
  ///
  /// In ar, this message translates to:
  /// **'جاري التحميل...'**
  String get loading;

  /// No description provided for @success.
  ///
  /// In ar, this message translates to:
  /// **'نجاح'**
  String get success;

  /// No description provided for @error.
  ///
  /// In ar, this message translates to:
  /// **'خطأ'**
  String get error;

  /// No description provided for @warning.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه'**
  String get warning;

  /// No description provided for @done.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get done;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @search.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get search;

  /// No description provided for @filter.
  ///
  /// In ar, this message translates to:
  /// **'تصفية'**
  String get filter;

  /// No description provided for @share.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get share;

  /// No description provided for @close.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get close;

  /// No description provided for @next.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get next;

  /// No description provided for @previous.
  ///
  /// In ar, this message translates to:
  /// **'السابق'**
  String get previous;

  /// No description provided for @submit.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get submit;

  /// No description provided for @continueText.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get continueText;

  /// No description provided for @skip.
  ///
  /// In ar, this message translates to:
  /// **'تخطي'**
  String get skip;

  /// No description provided for @apply.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق'**
  String get apply;

  /// No description provided for @refresh.
  ///
  /// In ar, this message translates to:
  /// **'تحديث'**
  String get refresh;

  /// No description provided for @copy.
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get copy;

  /// No description provided for @viewDetails.
  ///
  /// In ar, this message translates to:
  /// **'عرض التفاصيل'**
  String get viewDetails;

  /// No description provided for @yes.
  ///
  /// In ar, this message translates to:
  /// **'نعم'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In ar, this message translates to:
  /// **'لا'**
  String get no;

  /// No description provided for @authTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get authTitle;

  /// No description provided for @welcomeMessage.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً بك في inRide'**
  String get welcomeMessage;

  /// No description provided for @loginWithGoogle.
  ///
  /// In ar, this message translates to:
  /// **'المتابعة باستخدام Google'**
  String get loginWithGoogle;

  /// No description provided for @phoneNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phoneNumber;

  /// No description provided for @enterPhoneNumber.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم الهاتف'**
  String get enterPhoneNumber;

  /// No description provided for @fullName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم بالكامل'**
  String get fullName;

  /// No description provided for @enterFullName.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسمك بالكامل'**
  String get enterFullName;

  /// No description provided for @acceptTerms.
  ///
  /// In ar, this message translates to:
  /// **'أوافق على الشروط والأحكام'**
  String get acceptTerms;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @login.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get login;

  /// No description provided for @register.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب جديد'**
  String get register;

  /// No description provided for @enterPhonePrompt.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال رقم الهاتف'**
  String get enterPhonePrompt;

  /// No description provided for @invalidPhoneFormat.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال رقم هاتف صحيح (مثال: 1012345678)'**
  String get invalidPhoneFormat;

  /// No description provided for @sendingOtp.
  ///
  /// In ar, this message translates to:
  /// **'جاري إرسال رمز التحقق...'**
  String get sendingOtp;

  /// No description provided for @otpSent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال رمز التحقق بنجاح 📲'**
  String get otpSent;

  /// No description provided for @enterOtpCode.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز التحقق (OTP)'**
  String get enterOtpCode;

  /// No description provided for @resendCode.
  ///
  /// In ar, this message translates to:
  /// **'إعادة إرسال الرمز'**
  String get resendCode;

  /// No description provided for @resendCodeTimer.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الإرسال خلال {seconds} ثانية'**
  String resendCodeTimer(int seconds);

  /// No description provided for @verifyOtp.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الرمز'**
  String get verifyOtp;

  /// No description provided for @invalidOtp.
  ///
  /// In ar, this message translates to:
  /// **'رمز التحقق غير صحيح، حاول مرة أخرى'**
  String get invalidOtp;

  /// No description provided for @termsAndConditionsText.
  ///
  /// In ar, this message translates to:
  /// **'الشروط والأحكام'**
  String get termsAndConditionsText;

  /// No description provided for @privacyPolicyText.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get privacyPolicyText;

  /// No description provided for @forgotPassword.
  ///
  /// In ar, this message translates to:
  /// **'هل نسيت كلمة المرور؟'**
  String get forgotPassword;

  /// No description provided for @resetPassword.
  ///
  /// In ar, this message translates to:
  /// **'إعادة ضبط كلمة المرور'**
  String get resetPassword;

  /// No description provided for @sendResetLink.
  ///
  /// In ar, this message translates to:
  /// **'إرسال رابط الضبط'**
  String get sendResetLink;

  /// No description provided for @emailAddress.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get emailAddress;

  /// No description provided for @enterEmail.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بريدك الإلكتروني'**
  String get enterEmail;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In ar, this message translates to:
  /// **'كلمتا المرور غير متطابقتين'**
  String get passwordsDoNotMatch;

  /// No description provided for @driverRegistrationPrompt.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد التسجيل ككابتن؟ اضغط هنا'**
  String get driverRegistrationPrompt;

  /// No description provided for @passengerRole.
  ///
  /// In ar, this message translates to:
  /// **'راكب'**
  String get passengerRole;

  /// No description provided for @driverRole.
  ///
  /// In ar, this message translates to:
  /// **'كابتن'**
  String get driverRole;

  /// No description provided for @selectService.
  ///
  /// In ar, this message translates to:
  /// **'اختر الخدمة'**
  String get selectService;

  /// No description provided for @rideService.
  ///
  /// In ar, this message translates to:
  /// **'رحلة توصيل'**
  String get rideService;

  /// No description provided for @deliveryService.
  ///
  /// In ar, this message translates to:
  /// **'توصيل طلبات (ديلفري)'**
  String get deliveryService;

  /// No description provided for @heavyDeliveryService.
  ///
  /// In ar, this message translates to:
  /// **'نقل ثقيل'**
  String get heavyDeliveryService;

  /// No description provided for @scooterService.
  ///
  /// In ar, this message translates to:
  /// **'توصيل سكوتر'**
  String get scooterService;

  /// No description provided for @pickupLocation.
  ///
  /// In ar, this message translates to:
  /// **'مكان الانطلاق'**
  String get pickupLocation;

  /// No description provided for @destinationLocation.
  ///
  /// In ar, this message translates to:
  /// **'مكان الوصول'**
  String get destinationLocation;

  /// No description provided for @selectDestination.
  ///
  /// In ar, this message translates to:
  /// **'حدد وجهتك على الخريطة'**
  String get selectDestination;

  /// No description provided for @selectPickupOnMap.
  ///
  /// In ar, this message translates to:
  /// **'حدد نقطة الانطلاق على الخريطة'**
  String get selectPickupOnMap;

  /// No description provided for @offeredFare.
  ///
  /// In ar, this message translates to:
  /// **'السعر المقترح'**
  String get offeredFare;

  /// No description provided for @egp.
  ///
  /// In ar, this message translates to:
  /// **'ج.م'**
  String get egp;

  /// No description provided for @requestRide.
  ///
  /// In ar, this message translates to:
  /// **'اطلب رحلتك الآن'**
  String get requestRide;

  /// No description provided for @searchingForDrivers.
  ///
  /// In ar, this message translates to:
  /// **'جاري البحث عن كباتن بالقرب منك...'**
  String get searchingForDrivers;

  /// No description provided for @offersReceived.
  ///
  /// In ar, this message translates to:
  /// **'العروض المقدمة'**
  String get offersReceived;

  /// No description provided for @acceptOffer.
  ///
  /// In ar, this message translates to:
  /// **'قبول العرض'**
  String get acceptOffer;

  /// No description provided for @declineOffer.
  ///
  /// In ar, this message translates to:
  /// **'رفض العرض'**
  String get declineOffer;

  /// No description provided for @offerDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل العرض'**
  String get offerDetails;

  /// No description provided for @counterOffer.
  ///
  /// In ar, this message translates to:
  /// **'تقديم عرض مضاد'**
  String get counterOffer;

  /// No description provided for @driverIsOnTheWay.
  ///
  /// In ar, this message translates to:
  /// **'الكابتن في طريقه إليك 🚗'**
  String get driverIsOnTheWay;

  /// No description provided for @driverArrived.
  ///
  /// In ar, this message translates to:
  /// **'وصل الكابتن إلى نقطة الانطلاق 📍'**
  String get driverArrived;

  /// No description provided for @tripInProgress.
  ///
  /// In ar, this message translates to:
  /// **'الرحلة قيد التنفيذ الآن...'**
  String get tripInProgress;

  /// No description provided for @tripCompleted.
  ///
  /// In ar, this message translates to:
  /// **'تم إنهاء الرحلة بنجاح 🎉'**
  String get tripCompleted;

  /// No description provided for @tripCanceled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الرحلة'**
  String get tripCanceled;

  /// No description provided for @cancelRide.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الرحلة'**
  String get cancelRide;

  /// No description provided for @cancelReason.
  ///
  /// In ar, this message translates to:
  /// **'سبب الإلغاء'**
  String get cancelReason;

  /// No description provided for @enterCounterOffer.
  ///
  /// In ar, this message translates to:
  /// **'أدخل السعر المقترح الجديد'**
  String get enterCounterOffer;

  /// No description provided for @estimatedTime.
  ///
  /// In ar, this message translates to:
  /// **'الوقت المتوقع'**
  String get estimatedTime;

  /// No description provided for @estimatedDistance.
  ///
  /// In ar, this message translates to:
  /// **'المسافة المتوقعة'**
  String get estimatedDistance;

  /// No description provided for @fareBreakdown.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الأجرة'**
  String get fareBreakdown;

  /// No description provided for @baseFare.
  ///
  /// In ar, this message translates to:
  /// **'الأجرة الأساسية'**
  String get baseFare;

  /// No description provided for @totalFare.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الأجرة'**
  String get totalFare;

  /// No description provided for @driverDistance.
  ///
  /// In ar, this message translates to:
  /// **'المسافة عن الكابتن'**
  String get driverDistance;

  /// No description provided for @vehicleCategory.
  ///
  /// In ar, this message translates to:
  /// **'نوع المركبة'**
  String get vehicleCategory;

  /// No description provided for @selectVehicleCategory.
  ///
  /// In ar, this message translates to:
  /// **'اختر فئة السيارة'**
  String get selectVehicleCategory;

  /// No description provided for @standardCar.
  ///
  /// In ar, this message translates to:
  /// **'اقتصادي'**
  String get standardCar;

  /// No description provided for @comfortCar.
  ///
  /// In ar, this message translates to:
  /// **'راحة'**
  String get comfortCar;

  /// No description provided for @scooter.
  ///
  /// In ar, this message translates to:
  /// **'سكوتر'**
  String get scooter;

  /// No description provided for @deliveryTruck.
  ///
  /// In ar, this message translates to:
  /// **'سيارة نقل'**
  String get deliveryTruck;

  /// No description provided for @packageDescription.
  ///
  /// In ar, this message translates to:
  /// **'وصف الطرد'**
  String get packageDescription;

  /// No description provided for @deliveryNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات التوصيل'**
  String get deliveryNotes;

  /// No description provided for @recipientPhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم هاتف المستلم'**
  String get recipientPhone;

  /// No description provided for @recipientRegion.
  ///
  /// In ar, this message translates to:
  /// **'المنطقة / الشارع'**
  String get recipientRegion;

  /// No description provided for @orderDeliveryNow.
  ///
  /// In ar, this message translates to:
  /// **'اطلب ديلفري الآن'**
  String get orderDeliveryNow;

  /// No description provided for @shareLocationLink.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة رابط تحديد الموقع'**
  String get shareLocationLink;

  /// No description provided for @linkCopied.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ رابط التحديد بنجاح! 📋'**
  String get linkCopied;

  /// No description provided for @recipientName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستلم'**
  String get recipientName;

  /// No description provided for @enterRecipientName.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم المستلم'**
  String get enterRecipientName;

  /// No description provided for @enterPackageDetails.
  ///
  /// In ar, this message translates to:
  /// **'أدخل تفاصيل ومواصفات الشحنة'**
  String get enterPackageDetails;

  /// No description provided for @fragilePackage.
  ///
  /// In ar, this message translates to:
  /// **'طرد قابل للكسر'**
  String get fragilePackage;

  /// No description provided for @packageSize.
  ///
  /// In ar, this message translates to:
  /// **'حجم الطرد'**
  String get packageSize;

  /// No description provided for @confirmRecipientLocation.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد موقع المستلم'**
  String get confirmRecipientLocation;

  /// No description provided for @driverOnline.
  ///
  /// In ar, this message translates to:
  /// **'أنت الآن متصل (جاهز لاستقبال الطلبات)'**
  String get driverOnline;

  /// No description provided for @driverOffline.
  ///
  /// In ar, this message translates to:
  /// **'أنت الآن غير متصل'**
  String get driverOffline;

  /// No description provided for @newRequestAvailable.
  ///
  /// In ar, this message translates to:
  /// **'طلب رحلة جديد قادم!'**
  String get newRequestAvailable;

  /// No description provided for @acceptRequest.
  ///
  /// In ar, this message translates to:
  /// **'قبول الطلب'**
  String get acceptRequest;

  /// No description provided for @rejectRequest.
  ///
  /// In ar, this message translates to:
  /// **'تجاهل'**
  String get rejectRequest;

  /// No description provided for @arrivedAtPickup.
  ///
  /// In ar, this message translates to:
  /// **'أنا وصلت للراكب'**
  String get arrivedAtPickup;

  /// No description provided for @startTrip.
  ///
  /// In ar, this message translates to:
  /// **'بدء الرحلة'**
  String get startTrip;

  /// No description provided for @completeTrip.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء الرحلة'**
  String get completeTrip;

  /// No description provided for @passengerPhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم هاتف الراكب'**
  String get passengerPhone;

  /// No description provided for @incomingOffer.
  ///
  /// In ar, this message translates to:
  /// **'عرض جديد من كابتن'**
  String get incomingOffer;

  /// No description provided for @earningsToday.
  ///
  /// In ar, this message translates to:
  /// **'أرباح اليوم'**
  String get earningsToday;

  /// No description provided for @totalTrips.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الرحلات'**
  String get totalTrips;

  /// No description provided for @captainDashboard.
  ///
  /// In ar, this message translates to:
  /// **'لوحة تحكم الكابتن'**
  String get captainDashboard;

  /// No description provided for @docUploadTitle.
  ///
  /// In ar, this message translates to:
  /// **'رفع مستندات الكابتن'**
  String get docUploadTitle;

  /// No description provided for @docUploadSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'يرجى رفع المستندات المطلوبة لتفعيل حسابك'**
  String get docUploadSubtitle;

  /// No description provided for @driverLicense.
  ///
  /// In ar, this message translates to:
  /// **'رخصة القيادة'**
  String get driverLicense;

  /// No description provided for @vehicleLicense.
  ///
  /// In ar, this message translates to:
  /// **'رخصة المركبة'**
  String get vehicleLicense;

  /// No description provided for @nationalId.
  ///
  /// In ar, this message translates to:
  /// **'الرقم القومي (وجهان)'**
  String get nationalId;

  /// No description provided for @takePhoto.
  ///
  /// In ar, this message translates to:
  /// **'التقاط صورة بالكاميرا'**
  String get takePhoto;

  /// No description provided for @uploadFromGallery.
  ///
  /// In ar, this message translates to:
  /// **'اختيار من معرض الصور'**
  String get uploadFromGallery;

  /// No description provided for @docSubmitted.
  ///
  /// In ar, this message translates to:
  /// **'تم رفع المستندات بنجاح!'**
  String get docSubmitted;

  /// No description provided for @reviewPendingTitle.
  ///
  /// In ar, this message translates to:
  /// **'حسابك قيد المراجعة'**
  String get reviewPendingTitle;

  /// No description provided for @reviewPendingMessage.
  ///
  /// In ar, this message translates to:
  /// **'يقوم فريقنا بمراجعة مستنداتك حالياً. سيتم تفعيل حسابك خلال 24 ساعة.'**
  String get reviewPendingMessage;

  /// No description provided for @underReview.
  ///
  /// In ar, this message translates to:
  /// **'قيد المراجعة'**
  String get underReview;

  /// No description provided for @docPendingNote.
  ///
  /// In ar, this message translates to:
  /// **'يرجى الانتظار لحين اعتماد حسابك من قبل الإدارة'**
  String get docPendingNote;

  /// No description provided for @profile.
  ///
  /// In ar, this message translates to:
  /// **'الملف الشخصي'**
  String get profile;

  /// No description provided for @editProfile.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الملف الشخصي'**
  String get editProfile;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'لغة التطبيق'**
  String get language;

  /// No description provided for @arabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @changeLanguage.
  ///
  /// In ar, this message translates to:
  /// **'تغيير لغة التطبيق'**
  String get changeLanguage;

  /// No description provided for @appLanguage.
  ///
  /// In ar, this message translates to:
  /// **'لغة التطبيق'**
  String get appLanguage;

  /// No description provided for @theme.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get theme;

  /// No description provided for @darkMode.
  ///
  /// In ar, this message translates to:
  /// **'الوضع الداكن'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In ar, this message translates to:
  /// **'الوضع الفاتح'**
  String get lightMode;

  /// No description provided for @accountSettings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الحساب'**
  String get accountSettings;

  /// No description provided for @changePhoneNumber.
  ///
  /// In ar, this message translates to:
  /// **'تغيير رقم الهاتف'**
  String get changePhoneNumber;

  /// No description provided for @emergencyContacts.
  ///
  /// In ar, this message translates to:
  /// **'جهات اتصال الطوارئ'**
  String get emergencyContacts;

  /// No description provided for @savedAddresses.
  ///
  /// In ar, this message translates to:
  /// **'العناوين المحفوظة'**
  String get savedAddresses;

  /// No description provided for @homeAddress.
  ///
  /// In ar, this message translates to:
  /// **'المنزل'**
  String get homeAddress;

  /// No description provided for @workAddress.
  ///
  /// In ar, this message translates to:
  /// **'العمل'**
  String get workAddress;

  /// No description provided for @wallet.
  ///
  /// In ar, this message translates to:
  /// **'المحفظة والدفع'**
  String get wallet;

  /// No description provided for @walletBalance.
  ///
  /// In ar, this message translates to:
  /// **'رصيد المحفظة'**
  String get walletBalance;

  /// No description provided for @addFunds.
  ///
  /// In ar, this message translates to:
  /// **'شحن المحفظة'**
  String get addFunds;

  /// No description provided for @withdrawFunds.
  ///
  /// In ar, this message translates to:
  /// **'سحب الرصيد'**
  String get withdrawFunds;

  /// No description provided for @transactionHistory.
  ///
  /// In ar, this message translates to:
  /// **'سجل المعاملات'**
  String get transactionHistory;

  /// No description provided for @paymentMethods.
  ///
  /// In ar, this message translates to:
  /// **'طرق الدفع'**
  String get paymentMethods;

  /// No description provided for @cashPayment.
  ///
  /// In ar, this message translates to:
  /// **'دفع نقدي (كاش)'**
  String get cashPayment;

  /// No description provided for @walletPayment.
  ///
  /// In ar, this message translates to:
  /// **'دفع بواسطة المحفظة'**
  String get walletPayment;

  /// No description provided for @cardPayment.
  ///
  /// In ar, this message translates to:
  /// **'بطاقة ائتمان'**
  String get cardPayment;

  /// No description provided for @depositSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم شحن المحفظة بنجاح!'**
  String get depositSuccess;

  /// No description provided for @insufficientBalance.
  ///
  /// In ar, this message translates to:
  /// **'رصيد المحفظة غير كافٍ'**
  String get insufficientBalance;

  /// No description provided for @amount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get amount;

  /// No description provided for @enterAmount.
  ///
  /// In ar, this message translates to:
  /// **'أدخل المبلغ المطلوب'**
  String get enterAmount;

  /// No description provided for @notificationsCenter.
  ///
  /// In ar, this message translates to:
  /// **'مركز الإشعارات'**
  String get notificationsCenter;

  /// No description provided for @markAllRead.
  ///
  /// In ar, this message translates to:
  /// **'تعليم الكل كمقروء'**
  String get markAllRead;

  /// No description provided for @deleteAllNotifications.
  ///
  /// In ar, this message translates to:
  /// **'حذف الكل'**
  String get deleteAllNotifications;

  /// No description provided for @noNotifications.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إشعارات حالياً'**
  String get noNotifications;

  /// No description provided for @chatTitle.
  ///
  /// In ar, this message translates to:
  /// **'المحادثة الفورية'**
  String get chatTitle;

  /// No description provided for @typeMessage.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالتك هنا...'**
  String get typeMessage;

  /// No description provided for @send.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get send;

  /// No description provided for @partnerTyping.
  ///
  /// In ar, this message translates to:
  /// **'يكتب الآن...'**
  String get partnerTyping;

  /// No description provided for @supportChat.
  ///
  /// In ar, this message translates to:
  /// **'الدعم الفني المباشر'**
  String get supportChat;

  /// No description provided for @messagesCenter.
  ///
  /// In ar, this message translates to:
  /// **'مركز الرسائل'**
  String get messagesCenter;

  /// No description provided for @callPartner.
  ///
  /// In ar, this message translates to:
  /// **'الاتصال الهاتفي'**
  String get callPartner;

  /// No description provided for @emergencySos.
  ///
  /// In ar, this message translates to:
  /// **'طوارئ SOS (122)'**
  String get emergencySos;

  /// No description provided for @shareLiveLocation.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة الموقع المباشر'**
  String get shareLiveLocation;

  /// No description provided for @emergencyError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر إجراء اتصال الطوارئ بالرقم 122'**
  String get emergencyError;

  /// No description provided for @emergencyDialNote.
  ///
  /// In ar, this message translates to:
  /// **'سيتم الاتصال مباشرة بشرطة النجدة 122'**
  String get emergencyDialNote;

  /// No description provided for @ratingsAndReviews.
  ///
  /// In ar, this message translates to:
  /// **'المراجعات والتقييمات'**
  String get ratingsAndReviews;

  /// No description provided for @overallRating.
  ///
  /// In ar, this message translates to:
  /// **'التقييم العام'**
  String get overallRating;

  /// No description provided for @totalReviews.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الآراء'**
  String get totalReviews;

  /// No description provided for @submitRating.
  ///
  /// In ar, this message translates to:
  /// **'إرسال التقييم'**
  String get submitRating;

  /// No description provided for @writeComment.
  ///
  /// In ar, this message translates to:
  /// **'اكتب تعليقك هنا...'**
  String get writeComment;

  /// No description provided for @noRatingsYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد تقييمات أو مراجعات حالياً'**
  String get noRatingsYet;

  /// No description provided for @rateDriver.
  ///
  /// In ar, this message translates to:
  /// **'تقييم الكابتن'**
  String get rateDriver;

  /// No description provided for @ratePassenger.
  ///
  /// In ar, this message translates to:
  /// **'تقييم الراكب'**
  String get ratePassenger;

  /// No description provided for @howWasYourTrip.
  ///
  /// In ar, this message translates to:
  /// **'كيف كانت تجربتك في هذه الرحلة؟'**
  String get howWasYourTrip;

  /// No description provided for @starRating.
  ///
  /// In ar, this message translates to:
  /// **'التقييم بالنجوم'**
  String get starRating;

  /// No description provided for @loadingMap.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحميل الخريطة...'**
  String get loadingMap;

  /// No description provided for @gpsDisabled.
  ///
  /// In ar, this message translates to:
  /// **'خدمة تحديد الموقع (GPS) غير مفعلة'**
  String get gpsDisabled;

  /// No description provided for @permissionDenied.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض إذن الوصول للموقع'**
  String get permissionDenied;

  /// No description provided for @locationPermissionTitle.
  ///
  /// In ar, this message translates to:
  /// **'إذن الوصول للموقع مطلوب'**
  String get locationPermissionTitle;

  /// No description provided for @locationPermissionMsg.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج التطبيق لاستخدام موقعك لتحديد نقطة الانطلاق والوصول بدقة.'**
  String get locationPermissionMsg;

  /// No description provided for @grantPermission.
  ///
  /// In ar, this message translates to:
  /// **'منح الإذن'**
  String get grantPermission;

  /// No description provided for @turnLeft.
  ///
  /// In ar, this message translates to:
  /// **'اتجه يساراً'**
  String get turnLeft;

  /// No description provided for @turnRight.
  ///
  /// In ar, this message translates to:
  /// **'اتجه يميناً'**
  String get turnRight;

  /// No description provided for @goStraight.
  ///
  /// In ar, this message translates to:
  /// **'واصل السير مباشرة'**
  String get goStraight;

  /// No description provided for @arriveAtDestination.
  ///
  /// In ar, this message translates to:
  /// **'ستصل إلى وجهتك قريباً'**
  String get arriveAtDestination;

  /// No description provided for @recalculatingRoute.
  ///
  /// In ar, this message translates to:
  /// **'جاري إعادة حساب المسار...'**
  String get recalculatingRoute;

  /// No description provided for @recenterMap.
  ///
  /// In ar, this message translates to:
  /// **'إعادة ضبط الخريطة'**
  String get recenterMap;

  /// No description provided for @simulationController.
  ///
  /// In ar, this message translates to:
  /// **'لوحة المحاكاة'**
  String get simulationController;

  /// No description provided for @requiredField.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحقل مطلوب'**
  String get requiredField;

  /// No description provided for @invalidEmail.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال بريد إلكتروني صحيح'**
  String get invalidEmail;

  /// No description provided for @invalidPhone.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال رقم هاتف صحيح'**
  String get invalidPhone;

  /// No description provided for @passwordTooShort.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور يجب ألا تقل عن 6 أحرف'**
  String get passwordTooShort;

  /// No description provided for @networkError.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في الاتصال بالشبكة، يرجى التحقق من الإنترنت'**
  String get networkError;

  /// No description provided for @serverError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في الخادم، يرجى المحاولة لاحقاً'**
  String get serverError;

  /// No description provided for @unknownError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع'**
  String get unknownError;

  /// No description provided for @sessionExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الجلسة، يرجى تسجيل الدخول مجدداً'**
  String get sessionExpired;

  /// No description provided for @tryAgainLater.
  ///
  /// In ar, this message translates to:
  /// **'يرجى المحاولة مرة أخرى لاحقاً'**
  String get tryAgainLater;

  /// No description provided for @locationRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تحديد الموقع على الخريطة أولاً'**
  String get locationRequired;

  /// No description provided for @exitAppConfirmation.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الخروج'**
  String get exitAppConfirmation;

  /// No description provided for @exitAppPrompt.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت تأكد من رغبتك في الخروج من التطبيق؟'**
  String get exitAppPrompt;

  /// No description provided for @areYouSureExit.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد الخروج حقاً؟'**
  String get areYouSureExit;

  /// No description provided for @welcomeUser.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً بك، {name}'**
  String welcomeUser(String name);

  /// No description provided for @notificationsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا توجد إشعارات} =1{إشعار واحد} =2{إشعاران} few{{count} إشعارات} many{{count} إشعاراً} other{{count} إشعار}}'**
  String notificationsCount(int count);

  /// No description provided for @distanceKm.
  ///
  /// In ar, this message translates to:
  /// **'{value} كم'**
  String distanceKm(String value);

  /// No description provided for @distanceMeters.
  ///
  /// In ar, this message translates to:
  /// **'{value} متر'**
  String distanceMeters(String value);

  /// No description provided for @durationMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{value} دقيقة'**
  String durationMinutes(int value);

  /// No description provided for @durationHours.
  ///
  /// In ar, this message translates to:
  /// **'{value} ساعة'**
  String durationHours(int value);

  /// No description provided for @returnToApp.
  ///
  /// In ar, this message translates to:
  /// **'الرجوع للتطبيق'**
  String get returnToApp;

  /// No description provided for @captainOverlayTitle.
  ///
  /// In ar, this message translates to:
  /// **'inRide الكابتن'**
  String get captainOverlayTitle;

  /// No description provided for @historyTitle.
  ///
  /// In ar, this message translates to:
  /// **'سجل الرحلات'**
  String get historyTitle;

  /// No description provided for @noHistoryTrips.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رحلات سابقة'**
  String get noHistoryTrips;

  /// No description provided for @tripDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الرحلة'**
  String get tripDetails;

  /// No description provided for @rideHistory.
  ///
  /// In ar, this message translates to:
  /// **'رحلات السائق / الراكب'**
  String get rideHistory;

  /// No description provided for @supportTitle.
  ///
  /// In ar, this message translates to:
  /// **'الدعم والمساعدة'**
  String get supportTitle;

  /// No description provided for @supportSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'نحن هنا لمساعدتك على مدار 24 ساعة'**
  String get supportSubtitle;

  /// No description provided for @faqTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأسئلة الشائعة'**
  String get faqTitle;

  /// No description provided for @contactUs.
  ///
  /// In ar, this message translates to:
  /// **'تواصل معنا'**
  String get contactUs;

  /// No description provided for @callSupport.
  ///
  /// In ar, this message translates to:
  /// **'الاتصال بالدعم'**
  String get callSupport;

  /// No description provided for @emailSupport.
  ///
  /// In ar, this message translates to:
  /// **'مراسلة الدعم'**
  String get emailSupport;

  /// No description provided for @version.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار'**
  String get version;

  /// No description provided for @legalTerms.
  ///
  /// In ar, this message translates to:
  /// **'الشروط والسياسات'**
  String get legalTerms;

  /// No description provided for @aboutApp.
  ///
  /// In ar, this message translates to:
  /// **'عن التطبيق'**
  String get aboutApp;

  /// No description provided for @orSeparator.
  ///
  /// In ar, this message translates to:
  /// **'أو'**
  String get orSeparator;

  /// No description provided for @switchToRole.
  ///
  /// In ar, this message translates to:
  /// **'التبديل إلى وضع {role}'**
  String switchToRole(String role);

  /// No description provided for @switchLanguage.
  ///
  /// In ar, this message translates to:
  /// **'English Language'**
  String get switchLanguage;

  /// No description provided for @exitPreventionRider.
  ///
  /// In ar, this message translates to:
  /// **'لديك رحلة نشطة، يجب إلغاء الرحلة أو إنهاؤها أولاً قبل الخروج من التطبيق.'**
  String get exitPreventionRider;

  /// No description provided for @exitPreventionDriver.
  ///
  /// In ar, this message translates to:
  /// **'أنت في وضع الأونلاين أو لديك رحلة نشطة، يرجى إيقاف الأونلاين أو إنهاء الرحلة أولاً قبل الخروج من التطبيق.'**
  String get exitPreventionDriver;

  /// No description provided for @navDepart.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ التحرك'**
  String get navDepart;

  /// No description provided for @navArriveLeft.
  ///
  /// In ar, this message translates to:
  /// **'وجهتك على اليسار'**
  String get navArriveLeft;

  /// No description provided for @navArriveRight.
  ///
  /// In ar, this message translates to:
  /// **'وجهتك على اليمين'**
  String get navArriveRight;

  /// No description provided for @navArrived.
  ///
  /// In ar, this message translates to:
  /// **'وصلت إلى وجهتك'**
  String get navArrived;

  /// No description provided for @navContinue.
  ///
  /// In ar, this message translates to:
  /// **'استمر للأمام'**
  String get navContinue;

  /// No description provided for @navRoundaboutExit.
  ///
  /// In ar, this message translates to:
  /// **'ادخل الدوار - المخرج {exit}'**
  String navRoundaboutExit(String exit);

  /// No description provided for @navRoundabout.
  ///
  /// In ar, this message translates to:
  /// **'ادخل الدوار'**
  String get navRoundabout;

  /// No description provided for @navMerge.
  ///
  /// In ar, this message translates to:
  /// **'اندمج في الطريق'**
  String get navMerge;

  /// No description provided for @navTurnLeft.
  ///
  /// In ar, this message translates to:
  /// **'انعطف يساراً'**
  String get navTurnLeft;

  /// No description provided for @navTurnRight.
  ///
  /// In ar, this message translates to:
  /// **'انعطف يميناً'**
  String get navTurnRight;

  /// No description provided for @navSlightLeft.
  ///
  /// In ar, this message translates to:
  /// **'انحرف قليلاً لليسار'**
  String get navSlightLeft;

  /// No description provided for @navSlightRight.
  ///
  /// In ar, this message translates to:
  /// **'انحرف قليلاً لليمين'**
  String get navSlightRight;

  /// No description provided for @navSharpLeft.
  ///
  /// In ar, this message translates to:
  /// **'انعطف بحدة لليسار'**
  String get navSharpLeft;

  /// No description provided for @navSharpRight.
  ///
  /// In ar, this message translates to:
  /// **'انعطف بحدة لليمين'**
  String get navSharpRight;

  /// No description provided for @navUturn.
  ///
  /// In ar, this message translates to:
  /// **'قم بالدوران'**
  String get navUturn;

  /// No description provided for @navStraight.
  ///
  /// In ar, this message translates to:
  /// **'استمر مباشرة'**
  String get navStraight;

  /// No description provided for @navAfterDistance.
  ///
  /// In ar, this message translates to:
  /// **'بعد {distance}'**
  String navAfterDistance(String distance);

  /// No description provided for @navTowards.
  ///
  /// In ar, this message translates to:
  /// **'نحو: {street}'**
  String navTowards(String street);

  /// No description provided for @navUnnamedRoad.
  ///
  /// In ar, this message translates to:
  /// **'طريق غير مسمى'**
  String get navUnnamedRoad;

  /// No description provided for @navExitFirst.
  ///
  /// In ar, this message translates to:
  /// **'الأول'**
  String get navExitFirst;

  /// No description provided for @navExitSecond.
  ///
  /// In ar, this message translates to:
  /// **'الثاني'**
  String get navExitSecond;

  /// No description provided for @navExitThird.
  ///
  /// In ar, this message translates to:
  /// **'الثالث'**
  String get navExitThird;

  /// No description provided for @navExitFourth.
  ///
  /// In ar, this message translates to:
  /// **'الرابع'**
  String get navExitFourth;

  /// No description provided for @navExitFifth.
  ///
  /// In ar, this message translates to:
  /// **'الخامس'**
  String get navExitFifth;

  /// No description provided for @navExitNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم {n}'**
  String navExitNumber(int n);

  /// No description provided for @editProfileImage.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الصورة الشخصية'**
  String get editProfileImage;

  /// No description provided for @resetAction.
  ///
  /// In ar, this message translates to:
  /// **'إعادة ضبط'**
  String get resetAction;

  /// No description provided for @zoomLevel.
  ///
  /// In ar, this message translates to:
  /// **'التكبير: {scale}x'**
  String zoomLevel(String scale);

  /// No description provided for @rotate90.
  ///
  /// In ar, this message translates to:
  /// **'تدوير 90°'**
  String get rotate90;

  /// No description provided for @savingImage.
  ///
  /// In ar, this message translates to:
  /// **'جاري الحفظ...'**
  String get savingImage;

  /// No description provided for @saveCircularImage.
  ///
  /// In ar, this message translates to:
  /// **'حفظ الصورة الكروية'**
  String get saveCircularImage;

  /// No description provided for @imageProcessingError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء معالجة الصورة. يرجى المحاولة مرة أخرى.'**
  String get imageProcessingError;

  /// No description provided for @simClosePanel.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق المحاكي'**
  String get simClosePanel;

  /// No description provided for @simPanelTitle.
  ///
  /// In ar, this message translates to:
  /// **'لوحة المحاكاة التفاعلية'**
  String get simPanelTitle;

  /// No description provided for @simToolsHeader.
  ///
  /// In ar, this message translates to:
  /// **'🎛️ أدوات المحاكاة الفورية (للاختبار)'**
  String get simToolsHeader;

  /// No description provided for @simStatus.
  ///
  /// In ar, this message translates to:
  /// **'الحالة: {status}'**
  String simStatus(String status);

  /// No description provided for @simSwitchToPassenger.
  ///
  /// In ar, this message translates to:
  /// **'التبديل لراكب 🚶'**
  String get simSwitchToPassenger;

  /// No description provided for @simSwitchToDriver.
  ///
  /// In ar, this message translates to:
  /// **'التبديل لسائق 🚗'**
  String get simSwitchToDriver;

  /// No description provided for @simApproveDriver.
  ///
  /// In ar, this message translates to:
  /// **'اعتماد السائق فوراً ✅'**
  String get simApproveDriver;

  /// No description provided for @simDriverApproved.
  ///
  /// In ar, this message translates to:
  /// **'تم تفعيل واعتماد حساب السائق بنجاح!'**
  String get simDriverApproved;

  /// No description provided for @simRevokeVerification.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التوثيق ❌'**
  String get simRevokeVerification;

  /// No description provided for @simDriverRevoked.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء اعتماد السائق (غير مسجل)'**
  String get simDriverRevoked;

  /// No description provided for @simGenerateOffers.
  ///
  /// In ar, this message translates to:
  /// **'توليد عروض أسائقين قريبة ⚡'**
  String get simGenerateOffers;

  /// No description provided for @simDriverArrival.
  ///
  /// In ar, this message translates to:
  /// **'محاكاة وصول السائق 🏁'**
  String get simDriverArrival;

  /// No description provided for @simStartTrip.
  ///
  /// In ar, this message translates to:
  /// **'محاكاة بدء الرحلة 🚀'**
  String get simStartTrip;

  /// No description provided for @simCompleteTrip.
  ///
  /// In ar, this message translates to:
  /// **'محاكاة إنهاء الرحلة الدفع 💳'**
  String get simCompleteTrip;

  /// No description provided for @simResetRides.
  ///
  /// In ar, this message translates to:
  /// **'إعادة ضبط الرحلات 🔄'**
  String get simResetRides;

  /// No description provided for @simRidesReset.
  ///
  /// In ar, this message translates to:
  /// **'تم إعادة تعيين كافة الطلبات النشطة.'**
  String get simRidesReset;

  /// No description provided for @simNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة: تتيح لك هذه اللوحة اختبار سيناريو الرحلة كاملاً (الطلب، المزايدة، القبول، التتبع، الوصول، الدفع) مباشرة دون الحاجة لأجهزة إضافية.'**
  String get simNote;

  /// No description provided for @myCurrentLocation.
  ///
  /// In ar, this message translates to:
  /// **'موقعي الحالي'**
  String get myCurrentLocation;

  /// No description provided for @currentLocation.
  ///
  /// In ar, this message translates to:
  /// **'الموقع الحالي'**
  String get currentLocation;

  /// No description provided for @whereFrom.
  ///
  /// In ar, this message translates to:
  /// **'من أين؟'**
  String get whereFrom;

  /// No description provided for @whereTo.
  ///
  /// In ar, this message translates to:
  /// **'إلى أين؟'**
  String get whereTo;

  /// No description provided for @setPickupHint.
  ///
  /// In ar, this message translates to:
  /// **'حدد موقع الركوب...'**
  String get setPickupHint;

  /// No description provided for @searchDestinationHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن وجهة أو موقع...'**
  String get searchDestinationHint;

  /// No description provided for @whereToGo.
  ///
  /// In ar, this message translates to:
  /// **'إلى أين تريد الذهاب؟'**
  String get whereToGo;

  /// No description provided for @whereToRide.
  ///
  /// In ar, this message translates to:
  /// **'من أين تريد الركوب؟'**
  String get whereToRide;

  /// No description provided for @whereToGoShort.
  ///
  /// In ar, this message translates to:
  /// **'أين تريد الذهاب؟'**
  String get whereToGoShort;

  /// No description provided for @locationPermissionRide.
  ///
  /// In ar, this message translates to:
  /// **'يرجى السماح بالوصول لموقعك الجغرافي لتتمكن من حجز رحلة.'**
  String get locationPermissionRide;

  /// No description provided for @selectDestinationFirst.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تحديد وجهة أولاً للبدء'**
  String get selectDestinationFirst;

  /// No description provided for @scooterComingSoon.
  ///
  /// In ar, this message translates to:
  /// **'عذراً، خدمة الاسكوتر ستتوفر قريباً! يرجى اختيار الموتوسيكل أو السيارة حالياً.'**
  String get scooterComingSoon;

  /// No description provided for @noInternetOffline.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال بالإنترنت - الوضع غير المتصل'**
  String get noInternetOffline;

  /// No description provided for @requestCarRide.
  ///
  /// In ar, this message translates to:
  /// **'طلب رحلة ملاكي'**
  String get requestCarRide;

  /// No description provided for @requestBikeRide.
  ///
  /// In ar, this message translates to:
  /// **'طلب رحلة بايك'**
  String get requestBikeRide;

  /// No description provided for @setDestinationToStart.
  ///
  /// In ar, this message translates to:
  /// **'حدد وجهتك للبدء في طلب رحلة'**
  String get setDestinationToStart;

  /// No description provided for @chooseDestinationFromSearch.
  ///
  /// In ar, this message translates to:
  /// **'اختر مكاناً تود الذهاب إليه من حقل البحث في الأعلى لمعرفة التكلفة والبدء في طلب الرحلة.'**
  String get chooseDestinationFromSearch;

  /// No description provided for @chooseFare.
  ///
  /// In ar, this message translates to:
  /// **'اختر سعر الرحلة المقترح'**
  String get chooseFare;

  /// No description provided for @privateCar.
  ///
  /// In ar, this message translates to:
  /// **'سيارة ملاكي'**
  String get privateCar;

  /// No description provided for @motorcycleBike.
  ///
  /// In ar, this message translates to:
  /// **'موتوسيكل / بايك'**
  String get motorcycleBike;

  /// No description provided for @motorcycle.
  ///
  /// In ar, this message translates to:
  /// **'موتوسيكل'**
  String get motorcycle;

  /// No description provided for @passengerCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد الأفراد / الركاب'**
  String get passengerCount;

  /// No description provided for @requestRideNow.
  ///
  /// In ar, this message translates to:
  /// **'طلب رحلة الآن'**
  String get requestRideNow;

  /// No description provided for @dearCustomer.
  ///
  /// In ar, this message translates to:
  /// **'عميلنا العزيز'**
  String get dearCustomer;

  /// No description provided for @selectVehicleForRide.
  ///
  /// In ar, this message translates to:
  /// **'اختر نوع المركبة للرحلة'**
  String get selectVehicleForRide;

  /// No description provided for @selectVehicleToStart.
  ///
  /// In ar, this message translates to:
  /// **'حدد نوع المركبة لبدء رحلتك'**
  String get selectVehicleToStart;

  /// No description provided for @privateCarOption.
  ///
  /// In ar, this message translates to:
  /// **'سيارة ملاكي (Car)'**
  String get privateCarOption;

  /// No description provided for @privateCarDesc.
  ///
  /// In ar, this message translates to:
  /// **'رحلة مريحة وآمنة بالسيارة الملاكي الخاصة'**
  String get privateCarDesc;

  /// No description provided for @bikeOption.
  ///
  /// In ar, this message translates to:
  /// **'بايك (Motorcycle)'**
  String get bikeOption;

  /// No description provided for @bikeDesc.
  ///
  /// In ar, this message translates to:
  /// **'رحلة سريعة وآمنة لتفادي زحام المرور بالدراجة'**
  String get bikeDesc;

  /// No description provided for @chooseServiceToStart.
  ///
  /// In ar, this message translates to:
  /// **'اختر الخدمة للبدء فوراً'**
  String get chooseServiceToStart;

  /// No description provided for @rideOption.
  ///
  /// In ar, this message translates to:
  /// **'رحلة (Ride)'**
  String get rideOption;

  /// No description provided for @rideDesc.
  ///
  /// In ar, this message translates to:
  /// **'رحلتك بالسيارة أو البايك سريعة وآمنة بأسعارك المقترحة'**
  String get rideDesc;

  /// No description provided for @deliveryOption.
  ///
  /// In ar, this message translates to:
  /// **'ديلفري (Delivery)'**
  String get deliveryOption;

  /// No description provided for @deliveryDesc.
  ///
  /// In ar, this message translates to:
  /// **'أرسل طرودك وهداياك بضغطة زر مع بايكر سريع'**
  String get deliveryDesc;

  /// No description provided for @setPickupAuto.
  ///
  /// In ar, this message translates to:
  /// **'تحديد موقع الركوب تلقائياً بناءً على موقعك'**
  String get setPickupAuto;

  /// No description provided for @detectingLocation.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحديد موقعك...'**
  String get detectingLocation;

  /// No description provided for @noResultsFor.
  ///
  /// In ar, this message translates to:
  /// **'لم نتمكن من العثور على \"{query}\"'**
  String noResultsFor(String query);

  /// No description provided for @scooterComingSoonShort.
  ///
  /// In ar, this message translates to:
  /// **'اسكوتر (قريباً)'**
  String get scooterComingSoonShort;

  /// No description provided for @enableLocationToWork.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تفعيل صلاحيات الموقع للبدء بالعمل.'**
  String get enableLocationToWork;

  /// No description provided for @creditLimitReached.
  ///
  /// In ar, this message translates to:
  /// **'عفواً، لقد وصلت للحد الائتماني المسموح به. يرجى شحن محفظتك للاستمرار في استقبال الطلبات.'**
  String get creditLimitReached;

  /// No description provided for @errorSendingOffer.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في إرسال العرض: {error}'**
  String errorSendingOffer(String error);

  /// No description provided for @bookingRide.
  ///
  /// In ar, this message translates to:
  /// **'جاري حجز الرحلة وتأكيد القبول...'**
  String get bookingRide;

  /// No description provided for @customPriceOffer.
  ///
  /// In ar, this message translates to:
  /// **'عرض سعر مخصص'**
  String get customPriceOffer;

  /// No description provided for @sendOffer.
  ///
  /// In ar, this message translates to:
  /// **'إرسال العرض'**
  String get sendOffer;

  /// No description provided for @onlineForWork.
  ///
  /// In ar, this message translates to:
  /// **'متصل للعمل'**
  String get onlineForWork;

  /// No description provided for @offlineStatus.
  ///
  /// In ar, this message translates to:
  /// **'غير متصل'**
  String get offlineStatus;

  /// No description provided for @availableRequestsAround.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات المتاحة حولك'**
  String get availableRequestsAround;

  /// No description provided for @offlineMode.
  ///
  /// In ar, this message translates to:
  /// **'وضع عدم الاتصال'**
  String get offlineMode;

  /// No description provided for @youAreInactive.
  ///
  /// In ar, this message translates to:
  /// **'أنت غير نشط حالياً'**
  String get youAreInactive;

  /// No description provided for @activateToReceive.
  ///
  /// In ar, this message translates to:
  /// **'قم بتفعيل الزر بالأعلى لتلقي إشعارات رحلات الركاب والبدء بالعمل.'**
  String get activateToReceive;

  /// No description provided for @requestsPaused.
  ///
  /// In ar, this message translates to:
  /// **'تم إيقاف تلقي الطلبات مؤقتاً'**
  String get requestsPaused;

  /// No description provided for @debtLimitMessage.
  ///
  /// In ar, this message translates to:
  /// **'لقد وصلت إلى الحد الأقصى للمديونية (-100 ج.م) بسبب نسب عمولة الرحلات السابقة. يرجى شحن رصيد المحفظة لتفعيل حسابك وتلقي طلبات الركاب مرة أخرى.'**
  String get debtLimitMessage;

  /// No description provided for @goToWallet.
  ///
  /// In ar, this message translates to:
  /// **'الانتقال للمحفظة للشحن'**
  String get goToWallet;

  /// No description provided for @noRequestsInArea.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات رحلات حالياً في منطقتك...'**
  String get noRequestsInArea;

  /// No description provided for @packageSender.
  ///
  /// In ar, this message translates to:
  /// **'مرسل الطرد'**
  String get packageSender;

  /// No description provided for @passenger.
  ///
  /// In ar, this message translates to:
  /// **'راكب'**
  String get passenger;

  /// No description provided for @walletPaymentShort.
  ///
  /// In ar, this message translates to:
  /// **'💳 المحفظة'**
  String get walletPaymentShort;

  /// No description provided for @cashPaymentShort.
  ///
  /// In ar, this message translates to:
  /// **'💵 كاش'**
  String get cashPaymentShort;

  /// No description provided for @timeRemaining.
  ///
  /// In ar, this message translates to:
  /// **'باقي {seconds} ث'**
  String timeRemaining(int seconds);

  /// No description provided for @expired.
  ///
  /// In ar, this message translates to:
  /// **'منتهي'**
  String get expired;

  /// No description provided for @newUser.
  ///
  /// In ar, this message translates to:
  /// **'مستخدم جديد'**
  String get newUser;

  /// No description provided for @distanceToPassenger.
  ///
  /// In ar, this message translates to:
  /// **'المسافة إلى الراكب: {distText}  •  مسافة الرحلة: {tripDist} كم\nالوقت للوصول للعميل: {etaMin} دقائق'**
  String distanceToPassenger(String distText, String tripDist, String etaMin);

  /// No description provided for @packageDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الطرد المرسل:'**
  String get packageDetails;

  /// No description provided for @packageContent.
  ///
  /// In ar, this message translates to:
  /// **'محتوى الطرد: {content}'**
  String packageContent(String content);

  /// No description provided for @notSpecified.
  ///
  /// In ar, this message translates to:
  /// **'غير محدد'**
  String get notSpecified;

  /// No description provided for @deliveryInstructions.
  ///
  /// In ar, this message translates to:
  /// **'تعليمات التوصيل: {notes}'**
  String deliveryInstructions(String notes);

  /// No description provided for @customerCounterOffer.
  ///
  /// In ar, this message translates to:
  /// **'عرض العميل المقترح'**
  String get customerCounterOffer;

  /// No description provided for @suggestedFare.
  ///
  /// In ar, this message translates to:
  /// **'الأجرة المقترحة'**
  String get suggestedFare;

  /// No description provided for @customerSuggestedFare.
  ///
  /// In ar, this message translates to:
  /// **'اقترح العميل أجرة جديدة: {fare} ج.م'**
  String customerSuggestedFare(int fare);

  /// No description provided for @skipAction.
  ///
  /// In ar, this message translates to:
  /// **'تخطى'**
  String get skipAction;

  /// No description provided for @acceptNegotiation.
  ///
  /// In ar, this message translates to:
  /// **'قبول التفاوض'**
  String get acceptNegotiation;

  /// No description provided for @offerSentWaiting.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال عرض السعر بنجاح... بانتظار العميل'**
  String get offerSentWaiting;

  /// No description provided for @acceptFare.
  ///
  /// In ar, this message translates to:
  /// **'قبول الأجرة'**
  String get acceptFare;

  /// No description provided for @cash.
  ///
  /// In ar, this message translates to:
  /// **'كاش'**
  String get cash;

  /// No description provided for @walletTopUpTitle.
  ///
  /// In ar, this message translates to:
  /// **'شحن رصيد المحفظة'**
  String get walletTopUpTitle;

  /// No description provided for @cancelledByCustomer.
  ///
  /// In ar, this message translates to:
  /// **'تم الإلغاء بواسطة العميل'**
  String get cancelledByCustomer;

  /// No description provided for @rideCancelled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الرحلة'**
  String get rideCancelled;

  /// No description provided for @rideExpiredNoDrivers.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية طلب التوصيل لعدم استجابة السائقين. يرجى إعادة المحاولة.'**
  String get rideExpiredNoDrivers;

  /// No description provided for @requestCancelledSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الطلب بنجاح'**
  String get requestCancelledSuccess;

  /// No description provided for @shareLocationInstall.
  ///
  /// In ar, this message translates to:
  /// **'لتحديد موقعك بسهولة، يُرجى التأكد من تثبيت التطبيق على جهازك.'**
  String get shareLocationInstall;

  /// No description provided for @shareLocationMessage.
  ///
  /// In ar, this message translates to:
  /// **'لتحديد موقعك بسهولة، يُرجى التأكد من تثبيت التطبيق على جهازك.\n\nمن فضلك اضغط على هذا الرابط لتحديد موقع تسليم الطرد الخاص بك على الخريطة لتسهيل التوصيل: {link}'**
  String shareLocationMessage(String link);

  /// No description provided for @recipientLocationTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحديد موقع استلام الديلفري'**
  String get recipientLocationTitle;

  /// No description provided for @recipientLocationGps.
  ///
  /// In ar, this message translates to:
  /// **'موقع المستلم (GPS)'**
  String get recipientLocationGps;

  /// No description provided for @loadingCoordinates.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحديد إحداثيات الموقع... 📍'**
  String get loadingCoordinates;

  /// No description provided for @invalidLink.
  ///
  /// In ar, this message translates to:
  /// **'هذا الرابط غير صالح أو غير مصرح لك بالوصول ❌'**
  String get invalidLink;

  /// No description provided for @linkExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية هذا الرابط لأن الطلب غير نشط أو مكتمل بالفعل ⚠️'**
  String get linkExpired;

  /// No description provided for @locationAlreadyConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديد وتأكيد الموقع مسبقاً لهذا الطلب ✅'**
  String get locationAlreadyConfirmed;

  /// No description provided for @orderNotFound.
  ///
  /// In ar, this message translates to:
  /// **'عذراً، لم يتم العثور على تفاصيل هذا الطلب ❌'**
  String get orderNotFound;

  /// No description provided for @loadingError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء تحميل بيانات الطلب. يرجى التأكد من اتصالك بالإنترنت.'**
  String get loadingError;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض صلاحية الوصول للموقع الجغرافي. يرجى تفعيل الصلاحية للمتابعة ⚠️'**
  String get locationPermissionDenied;

  /// No description provided for @gpsAccuracyError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر جلب موقعك الجغرافي بدقة عالية. يرجى التحقق من تفعيل GPS بجهازك أو التحديد يدوياً.'**
  String get gpsAccuracyError;

  /// No description provided for @gpsAccuracyErrorAlt.
  ///
  /// In ar, this message translates to:
  /// **'فشل جلب موقعك الجغرافي بدقة عالية. يرجى التحقق من إعدادات GPS بجهازك أو تحديد موقعك يدوياً.'**
  String get gpsAccuracyErrorAlt;

  /// No description provided for @saveLocationError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء حفظ موقعك المحدد. يرجى المحاولة مرة أخرى.'**
  String get saveLocationError;

  /// No description provided for @savingAndNotifying.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحديث النظام وإخطار الكابتن...'**
  String get savingAndNotifying;

  /// No description provided for @connectingToSystem.
  ///
  /// In ar, this message translates to:
  /// **'جاري الاتصال بالنظام...'**
  String get connectingToSystem;

  /// No description provided for @unexpectedError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع. يرجى المحاولة مجدداً.'**
  String get unexpectedError;

  /// No description provided for @retryAction.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retryAction;

  /// No description provided for @closePage.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق الصفحة'**
  String get closePage;

  /// No description provided for @senderWantsToSend.
  ///
  /// In ar, this message translates to:
  /// **'يريد ({sender}) إرسال طرد إليك، اضغط على الزر بالأسفل لمشاركة موقعك الحالي وتسهيل مهمة الكابتن.'**
  String senderWantsToSend(String sender);

  /// No description provided for @packageDescLabel.
  ///
  /// In ar, this message translates to:
  /// **'وصف الطرد: {desc}'**
  String packageDescLabel(String desc);

  /// No description provided for @useMyCurrentLocation.
  ///
  /// In ar, this message translates to:
  /// **'استخدام موقعي الحالي 📍'**
  String get useMyCurrentLocation;

  /// No description provided for @selectLocationManually.
  ///
  /// In ar, this message translates to:
  /// **'تحديد الموقع يدويًا على الخريطة'**
  String get selectLocationManually;

  /// No description provided for @confirmLocation.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الموقع 📌'**
  String get confirmLocation;

  /// No description provided for @locationConfirmedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديد موقعك بنجاح! 🎉'**
  String get locationConfirmedSuccess;

  /// No description provided for @locationConfirmedMessage.
  ///
  /// In ar, this message translates to:
  /// **'شكراً لك، تم حفظ إحداثيات التوصيل وتحديث التكلفة لدى الكابتن تلقائياً. السائق في طريقه إليك الآن.'**
  String get locationConfirmedMessage;

  /// No description provided for @driver.
  ///
  /// In ar, this message translates to:
  /// **'سائق'**
  String get driver;

  /// No description provided for @car.
  ///
  /// In ar, this message translates to:
  /// **'عربية'**
  String get car;

  /// No description provided for @vehicleMotorcycleBike.
  ///
  /// In ar, this message translates to:
  /// **'موتوسيكل / بايك'**
  String get vehicleMotorcycleBike;

  /// No description provided for @vehicleScooter.
  ///
  /// In ar, this message translates to:
  /// **'اسكوتر'**
  String get vehicleScooter;

  /// No description provided for @vehiclePrivateCar.
  ///
  /// In ar, this message translates to:
  /// **'سيارة ملاكي'**
  String get vehiclePrivateCar;

  /// No description provided for @authUnknownError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير معروف، يرجى المحاولة لاحقاً.'**
  String get authUnknownError;

  /// No description provided for @authNoInternet.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال بالإنترنت. يرجى التحقق من الشبكة وإعادة المحاولة.'**
  String get authNoInternet;

  /// No description provided for @authServerConnect.
  ///
  /// In ar, this message translates to:
  /// **'تعذر الاتصال بالسيرفر. يرجى التأكد من الاتصال بالإنترنت.'**
  String get authServerConnect;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني أو كلمة المرور غير صحيحة.'**
  String get authInvalidCredentials;

  /// No description provided for @authAlreadyRegistered.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحساب مسجل بالفعل، يرجى تسجيل الدخول.'**
  String get authAlreadyRegistered;

  /// No description provided for @authEmailNotConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني غير مفعل، يرجى مراجعة بريدك الإلكتروني لتأكيده.'**
  String get authEmailNotConfirmed;

  /// No description provided for @authWeakPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور ضعيفة. يجب أن تتكون من 6 أحرف على الأقل.'**
  String get authWeakPassword;

  /// No description provided for @authInvalidEmail.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني غير صالح.'**
  String get authInvalidEmail;

  /// No description provided for @authRateLimit.
  ///
  /// In ar, this message translates to:
  /// **'تم تجاوز عدد المحاولات المسموح بها. يرجى الانتظار قليلاً ثم المحاولة لاحقاً.'**
  String get authRateLimit;

  /// No description provided for @authOtpExpired.
  ///
  /// In ar, this message translates to:
  /// **'رمز التحقق منتهي الصلاحية، يرجى طلب رمز جديد.'**
  String get authOtpExpired;

  /// No description provided for @authInvalidOtp.
  ///
  /// In ar, this message translates to:
  /// **'رمز التحقق غير صحيح.'**
  String get authInvalidOtp;

  /// No description provided for @authCancelled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء العملية بواسطة المستخدم.'**
  String get authCancelled;

  /// No description provided for @authErrorPrefix.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ: {error}'**
  String authErrorPrefix(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
