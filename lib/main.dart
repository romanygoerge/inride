// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/supabase_config.dart';
import 'core/localization/locale_controller.dart';
import 'generated/app_localizations.dart';

import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';

import 'core/state/global_state.dart';
import 'features/auth/presentation/pages/passenger_profile_setup_page.dart';
import 'features/driver_registration/presentation/pages/doc_upload_page.dart';
import 'features/passenger/presentation/pages/passenger_home_page.dart';
import 'features/driver_registration/presentation/pages/review_pending_page.dart';
import 'features/driver/presentation/pages/driver_home_page.dart';
import 'features/passenger/presentation/pages/passenger_ride_matching_page.dart';
import 'features/passenger/presentation/pages/passenger_ride_active_page.dart';
import 'features/driver/presentation/pages/driver_ride_active_page.dart';
import 'shared/widgets/no_internet_screen.dart';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:url_launcher/url_launcher.dart' as import_url;
import 'core/DI/injection_container.dart' as di;
import 'core/services/deep_link_service.dart';
import 'core/services/app_notification_service.dart';
import 'core/services/meta_analytics_service.dart';
import 'core/utils/app_logger.dart';
import 'features/common/maintenance_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma("vm:entry-point")
void overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedCode = prefs.getString('selected_language_code') ?? 'ar';
  final isAr = savedCode == 'ar';

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isAr ? 'inRide الكابتن' : 'inRide Captain',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await FlutterOverlayWindow.shareData('arrive_at_pickup');
                    await FlutterOverlayWindow.closeOverlay();
                  },
                  child: Text(isAr ? 'أنا وصلت للراكب' : 'Arrived at Pickup', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    await FlutterOverlayWindow.shareData('return_to_app');
                    await FlutterOverlayWindow.closeOverlay();
                  },
                  child: Text(isAr ? 'الرجوع للتطبيق' : 'Return to App', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleController.instance.init();

  // Register global Flutter error handler
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.error('FlutterError', details.exceptionAsString(), details.exception, details.stack);
  };

  // Register global platform dispatcher error handler for unhandled async errors
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.error('AsyncPlatformError', error.toString(), error, stack);
    return true; // Prevents app crash from unhandled async errors
  };

  // Global ErrorWidget builder to permanently prevent the Flutter grey screen (Grey Screen of Death)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final errStr = details.exceptionAsString();
    print('🚨 [CRITICAL_WIDGET_BUILD_ERROR]: $errStr\n${details.stack}');
    AppLogger.error('WidgetBuildError', errStr, details.exception, details.stack);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.white,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.mediumBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.sync_problem_rounded,
                        color: AppColors.mediumBlue,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'حدث خطأ غير متوقع أثناء تحميل الصفحة',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اضغط على إعادة المحاولة أو الرجوع لتسجيل الدخول',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  // Error details container for instant debugging transparency
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      errStr.length > 200 ? '${errStr.substring(0, 200)}...' : errStr,
                      style: GoogleFonts.outfit(fontSize: 11, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          GlobalState.instance.isAuthResolved = true;
                          GlobalState.instance.notify();
                          navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
                        },
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                        label: Text(
                          'إعادة المحاولة',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mediumBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await GlobalState.instance.performSafeLogout();
                          navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
                        },
                        icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                        label: Text(
                          'تسجيل الخروج',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.error),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  };

  try {
    await SupabaseConfig.init();
  } catch (e) {
    print("🚨 Supabase initialization failed: $e");
  }

  // 1. Initialize Dependency Injection BEFORE any other services are invoked
  try {
    await di.init();
    print("✓ Dependency Injection (sl) container initialized.");
  } catch (e) {
    print("🚨 DI initialization failed: $e");
  }

  // 2. Initialize Notification Service after DI is fully ready
  if (!kIsWeb) {
    try {
      await AppNotificationService.instance.initialize();
    } catch (e) {
      print("🚨 AppNotificationService initialization failed: $e");
    }
  }

  // 3. Initialize Analytics
  if (!kIsWeb) {
    try {
      await MetaAnalyticsService.instance.init();
    } catch (e) {
      print("🚨 MetaAnalyticsService initialization failed: $e");
    }
  }

  runApp(
    const ProviderScope(
      child: InRideApp(),
    ),
  );
}

class InRideApp extends ConsumerWidget {
  const InRideApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'inRide',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          
          locale: LocaleController.instance.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          
          initialRoute: '/',
          routes: {
            '/': (context) => const AuthGate(),
          },
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            // Strictly clamp text scale factor between 0.85 and 1.0 to permanently prevent UI breakage,
            // word overlapping, and container collisions when users enable extra-large system fonts on their devices
            final clampedScaler = mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.0,
            );
            return MediaQuery(
              data: mediaQuery.copyWith(textScaler: clampedScaler),
              child: ListenableBuilder(
                listenable: GlobalState.instance,
                builder: (context, _) {
                  final state = GlobalState.instance;
                  if (state.isMaintenanceMode && !state.isAdmin) {
                    return const MaintenancePage();
                  }
                  return child ?? const SizedBox.shrink();
                },
              ),
            );
          },
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    DeepLinkService.instance.init();
    
    if (!kIsWeb) {
      // Listen to overlay window messages safely
      try {
        FlutterOverlayWindow.overlayListener.listen((event) {
          if (event == 'arrive_at_pickup') {
            GlobalState.instance.arriveAtPickup();
          } else if (event == 'return_to_app') {
            import_url.launchUrl(Uri.parse('inride://confirm-delivery-location'));
          }
        }, onError: (e) {
          debugPrint('[AuthGate] Overlay listener error: $e');
        });
      } catch (e) {
        debugPrint('[AuthGate] Error attaching overlay listener: $e');
      }
    }
  }

  Future<void> _checkAuth() async {
    // Safety fallback: Never allow the app to be stuck on loading spinner for more than 2 seconds
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && (!GlobalState.instance.isAuthResolved || !_initialized)) {
        debugPrint('[AuthGate] Safety fallback timer triggered: forcing auth resolved');
        GlobalState.instance.isAuthResolved = true;
        setState(() {
          _initialized = true;
        });
      }
    });

    // Wait a brief moment to allow Supabase Auth and GlobalState to resolve initial user session
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() {
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GlobalState.instance,
      builder: (context, _) {
        final state = GlobalState.instance;
        if (state.isMaintenanceMode && !state.isAdmin) {
          return const MaintenancePage();
        }
        if (!_initialized || !state.isAuthResolved) {
          // Minimal loading indicator while initial state resolves
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.mediumBlue,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          );
        }

        if (state.isLoggedIn && state.userUid != null) {
          final isDemo = state.phoneNumber?.replaceAll(RegExp(r'[^\d]'), '').endsWith('000000000') == true;

          // User authenticated via Phone Number (WhatsApp OTP)
          if (state.currentRole == UserRole.rider) {
            if (!state.hasPassengerProfile && !isDemo) {
              if (state.isOffline) {
                return const NoInternetScreen();
              }
              return const PassengerProfileSetupPage();
            }
            if (state.rideStatus == RideStatus.searching || state.rideStatus == RideStatus.driverBidding) {
              return const PassengerRideMatchingPage();
            }
            if (state.rideStatus == RideStatus.driverOnWay ||
                state.rideStatus == RideStatus.arrived ||
                state.rideStatus == RideStatus.tripStarted ||
                state.rideStatus == RideStatus.completed) {
              return const PassengerRideActivePage();
            }
            return const PassengerHomePage();
          } else {
            if (isDemo || state.verificationStatus == DriverVerificationStatus.verified) {
              if (state.rideStatus == RideStatus.driverOnWay ||
                  state.rideStatus == RideStatus.arrived ||
                  state.rideStatus == RideStatus.tripStarted) {
                return const DriverRideActivePage();
              }
              return const DriverHomePage();
            } else if (state.verificationStatus == DriverVerificationStatus.submitted) {
              return const ReviewPendingPage();
            } else {
              if (state.isOffline && !state.hasDriverProfile) {
                return const NoInternetScreen();
              }
              return const DocUploadPage();
            }
          }
        }

        return const LoginPage();
      },
    );
  }
}
