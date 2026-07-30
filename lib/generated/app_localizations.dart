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
  /// **'جاري البحث عن كباتن...'**
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

  /// No description provided for @profile.
  ///
  /// In ar, this message translates to:
  /// **'الملف الشخصي'**
  String get profile;

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
