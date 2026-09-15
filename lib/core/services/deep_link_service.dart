import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../features/passenger/presentation/pages/recipient_location_confirm_page.dart';
import '../../features/common/wallet_page.dart';
import '../../features/rewards/presentation/pages/earn_more_money_page.dart';
import '../../features/common/support_chat_page.dart';
import '../../features/common/profile_page.dart';
import '../../features/passenger/presentation/pages/passenger_delivery_booking_page.dart';
import '../../features/driver_registration/presentation/pages/doc_upload_page.dart';

class DeepLinkService {
  static final DeepLinkService instance = DeepLinkService._internal();
  factory DeepLinkService() => instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();

  void init() {
    if (kIsWeb) return;
    // Listen to incoming links when the app is running/backgrounded
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Deep Link Error: $err');
    });

    // Check if the app was opened by a deep link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Received Deep Link: $uri');
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    // 1. Confirm delivery location link
    if (path.contains('confirm-delivery-location') || (scheme == 'inride' && host == 'confirm-delivery-location')) {
      final requestId = uri.queryParameters['requestId'] ?? uri.queryParameters['request_id'];
      final token = uri.queryParameters['token'];
      if (requestId != null && requestId.isNotEmpty) {
        _navigateTo((context) => RecipientLocationConfirmPage(
              requestId: requestId,
              token: token,
            ));
      }
      return;
    }

    // 2. Wallet page (inride://wallet or https://inride.app/wallet)
    if (path.contains('wallet') || host == 'wallet') {
      _navigateTo((context) => const WalletPage());
      return;
    }

    // 3. Rewards & Missions page (inride://rewards or https://inride.app/rewards)
    if (path.contains('rewards') || host == 'rewards' || path.contains('earn') || host == 'earn') {
      _navigateTo((context) => const EarnMoreMoneyPage(initialTabIndex: 0));
      return;
    }

    // 4. Promo codes page (inride://promos or https://inride.app/promos)
    if (path.contains('promos') || host == 'promos' || path.contains('promo') || host == 'promo') {
      _navigateTo((context) => const EarnMoreMoneyPage(initialTabIndex: 1));
      return;
    }

    // 5. Support Chat page (inride://support or https://inride.app/support)
    if (path.contains('support') || host == 'support' || path.contains('chat') || host == 'chat') {
      _navigateTo((context) => const SupportChatPage());
      return;
    }

    // 6. Profile page (inride://profile or https://inride.app/profile)
    if (path.contains('profile') || host == 'profile') {
      _navigateTo((context) => const ProfilePage());
      return;
    }

    // 7. Delivery Booking page (inride://delivery or https://inride.app/delivery)
    if (path.contains('delivery') || host == 'delivery') {
      _navigateTo((context) => PassengerDeliveryBookingPage(
            onCancel: () {
              final ctx = navigatorKey.currentContext;
              if (ctx != null && Navigator.canPop(ctx)) {
                Navigator.pop(ctx);
              }
            },
          ));
      return;
    }

    // 8. Driver Registration / Document Submission (inride://driver-register or inride://driver/register)
    if (path.contains('driver-register') || host == 'driver-register' || path.contains('driver/register')) {
      _navigateTo((context) => const DocUploadPage());
      return;
    }
  }

  void _navigateTo(WidgetBuilder builder) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: builder),
        );
      }
    });
  }
}

