import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/supabase_config.dart';
import 'core/localization/locale_controller.dart';
import 'generated/app_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';

import 'core/state/global_state.dart';
import 'features/auth/presentation/pages/passenger_profile_setup_page.dart';
import 'features/driver_registration/presentation/pages/doc_upload_page.dart';
import 'features/passenger/presentation/pages/passenger_home_page.dart';
import 'features/driver_registration/presentation/pages/review_pending_page.dart';
import 'features/driver/presentation/pages/driver_home_page.dart';
import 'features/passenger/presentation/pages/passenger_ride_matching_page.dart';
import 'features/driver/presentation/pages/driver_ride_active_page.dart';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:url_launcher/url_launcher.dart' as import_url;
import 'core/DI/injection_container.dart' as di;
import 'core/services/deep_link_service.dart';
import 'core/services/app_notification_service.dart';
import 'core/utils/app_logger.dart';

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

  try {
    await SupabaseConfig.init();
  } catch (e) {
    debugPrint("Supabase initialization failed: $e");
  }
  if (!kIsWeb) {
    try {
      await AppNotificationService.instance.initialize();
    } catch (e) {
      debugPrint("AppNotificationService initialization failed: $e");
    }
  }
  await di.init();
  runApp(const InRideApp());
}

class InRideApp extends StatelessWidget {
  const InRideApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      // Listen to overlay window messages
      FlutterOverlayWindow.overlayListener.listen((event) {
        if (event == 'arrive_at_pickup') {
          GlobalState.instance.arriveAtPickup();
        } else if (event == 'return_to_app') {
          import_url.launchUrl(Uri.parse('inride://confirm-delivery-location'));
        }
      });
    }
  }

  Future<void> _checkAuth() async {
    // Wait a very brief moment to allow Supabase Auth and GlobalState to resolve initial user session
    await Future.delayed(const Duration(milliseconds: 50));
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
          // Phone number linking bypassed as per user requirement (Gmail/Google auth only)
          if (state.currentRole == UserRole.rider) {
            if (!state.hasPassengerProfile) {
              return const PassengerProfileSetupPage();
            }
            if (state.rideStatus == RideStatus.searching ||
                state.rideStatus == RideStatus.driverOnWay ||
                state.rideStatus == RideStatus.arrived ||
                state.rideStatus == RideStatus.tripStarted) {
              return const PassengerRideMatchingPage();
            }
            return const PassengerHomePage();
          } else {
            if (state.verificationStatus == DriverVerificationStatus.verified) {
              if (state.rideStatus == RideStatus.driverOnWay ||
                  state.rideStatus == RideStatus.arrived ||
                  state.rideStatus == RideStatus.tripStarted) {
                return const DriverRideActivePage();
              }
              return const DriverHomePage();
            } else if (state.verificationStatus == DriverVerificationStatus.submitted) {
              return const ReviewPendingPage();
            } else {
              return const DocUploadPage();
            }
          }
        }

        return const LoginPage();
      },
    );
  }
}
