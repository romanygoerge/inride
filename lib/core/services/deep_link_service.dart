import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../features/passenger/presentation/pages/recipient_location_confirm_page.dart';

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
    // Handle both https://inride.app/confirm-delivery-location and inride://confirm-delivery-location
    if (uri.path.contains('confirm-delivery-location') || (uri.scheme == 'inride' && uri.host == 'confirm-delivery-location')) {
      final requestId = uri.queryParameters['requestId'];
      final token = uri.queryParameters['token'];
      if (requestId != null && requestId.isNotEmpty) {
        _navigateToConfirmPage(requestId, token);
      }
    }
  }

  void _navigateToConfirmPage(String requestId, String? token) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipientLocationConfirmPage(
              requestId: requestId,
              token: token,
            ),
          ),
        );
      }
    });
  }
}
