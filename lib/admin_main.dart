import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/supabase_config.dart';
import 'core/localization/locale_controller.dart';
import 'core/router/admin_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';
import 'generated/app_localizations.dart';

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
    return true;
  };

  try {
    await SupabaseConfig.init();
  } catch (e) {
    debugPrint("Supabase initialization failed: $e");
  }

  runApp(
    const ProviderScope(
      child: InRideAdminApp(),
    ),
  );
}

class InRideAdminApp extends ConsumerWidget {
  const InRideAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(adminRouterProvider);

    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        return MaterialApp.router(
          routerConfig: router,
          title: 'inRide Admin Dashboard',
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
        );
      },
    );
  }
}
