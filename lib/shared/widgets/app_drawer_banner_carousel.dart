import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/models/app_banner_model.dart';
import '../../core/state/global_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snappy_page_route.dart';
import '../../features/common/wallet_page.dart';
import '../../generated/app_localizations.dart';
import 'invite_friends_sheet.dart';

/// Professional animated banner carousel for the AppDrawer.
/// Houses the permanent primary Wallet card + up to 2 promotional banners
/// fetched and updated in real-time from Supabase database.
class AppDrawerBannerCarousel extends StatefulWidget {
  const AppDrawerBannerCarousel({super.key});

  @override
  State<AppDrawerBannerCarousel> createState() => _AppDrawerBannerCarouselState();
}

class _AppDrawerBannerCarouselState extends State<AppDrawerBannerCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;
  List<AppBanner> _activeBanners = [];
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _setupAutoScrollTimer(int totalCards) {
    _autoScrollTimer?.cancel();
    if (totalCards <= 1) return;

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || _isInteracting || !_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % totalCards;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onUserInteractionStart() {
    _isInteracting = true;
    _autoScrollTimer?.cancel();
  }

  void _onUserInteractionEnd(int totalCards) {
    _isInteracting = false;
    _setupAutoScrollTimer(totalCards);
  }

  Future<void> _handleBannerAction(BuildContext context, AppBanner banner) async {
    final action = banner.actionType.toLowerCase().trim();
    final value = banner.actionValue?.trim() ?? '';

    switch (action) {
      case 'coupon':
        if (value.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: value));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تم نسخ كود الخصم: $value بنجاح! 🎉',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.mediumBlue,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
        break;

      case 'invite':
        Navigator.pop(context); // Close drawer
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => const InviteFriendsSheet(),
        );
        break;

      case 'wallet':
        Navigator.pop(context); // Close drawer
        Navigator.push(context, SnappyPageRoute(page: const WalletPage()));
        break;

      case 'url':
        if (value.isNotEmpty) {
          final uri = Uri.tryParse(value);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
        break;

      case 'whatsapp':
        final phone = value.isNotEmpty ? value : '01204062941';
        final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
        final waUrl = Uri.parse('https://wa.me/$cleanPhone');
        if (await canLaunchUrl(waUrl)) {
          await launchUrl(waUrl, mode: LaunchMode.externalApplication);
        }
        break;

      case 'trip':
      case 'book':
        Navigator.pop(context); // Return to home/booking
        break;

      default:
        // Optional tap without action
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = GlobalState.instance;
    final l10n = AppLocalizations.of(context);

    // Stream from Supabase Realtime table 'app_banners'
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('app_banners')
          .stream(primaryKey: ['id'])
          .order('display_order', ascending: true),
      builder: (context, snapshot) {
        // Extract up to 2 active banners from database stream
        if (snapshot.hasData && snapshot.data != null) {
          final userRole = state.currentRole == UserRole.driver ? 'driver' : 'rider';
          _activeBanners = snapshot.data!
              .map((map) => AppBanner.fromMap(map))
              .where((b) => b.isActive && (b.targetRole == 'all' || b.targetRole == userRole))
              .take(2)
              .toList();
        }

        final totalCards = 1 + _activeBanners.length;

        // Manage timer when card count changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_autoScrollTimer == null && totalCards > 1) {
            _setupAutoScrollTimer(totalCards);
          } else if (totalCards <= 1 && _autoScrollTimer != null) {
            _autoScrollTimer?.cancel();
            _autoScrollTimer = null;
          }
        });

        // If only the wallet card exists, render cleanly without slider overhead
        if (totalCards == 1) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: _buildWalletCard(context, state, l10n),
          );
        }

        // Multi-card slider with Wallet + Ad Banners
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Listener(
                onPointerDown: (_) => _onUserInteractionStart(),
                onPointerUp: (_) => _onUserInteractionEnd(totalCards),
                onPointerCancel: (_) => _onUserInteractionEnd(totalCards),
                child: SizedBox(
                  height: 98,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: totalCards,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Slide 0 is ALWAYS the permanent Wallet Card
                        return _buildWalletCard(context, state, l10n);
                      } else {
                        // Slide 1..N are Ad Banners
                        final banner = _activeBanners[index - 1];
                        return _buildAdBannerCard(context, banner);
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Elegant Animated Indicators Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalCards, (index) {
                  final isSelected = _currentPage == index;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 5,
                      width: isSelected ? 18 : 6,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.mediumBlue : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.mediumBlue.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Permanent Core Wallet Card
  Widget _buildWalletCard(BuildContext context, GlobalState state, AppLocalizations? l10n) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final walletText = l10n?.wallet ?? (isArabic ? 'المحفظة والدفع' : 'Wallet & Payment');
    final addFundsText = l10n?.addFunds ?? (isArabic ? 'شحن المحفظة' : 'Top Up');
    final currencyText = l10n?.egp ?? (isArabic ? 'ج.م' : 'EGP');

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, SnappyPageRoute(page: const WalletPage()));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 98,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: AppColors.blueGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.mediumBlue.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        walletText,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${state.walletBalance.toStringAsFixed(2)} $currencyText',
                    style: GoogleFonts.outfit(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, SnappyPageRoute(page: const WalletPage()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_circle_outline_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    addFundsText,
                    style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ad Promotional Banner Card (Matching exact dimensions, radius, and style)
  Widget _buildAdBannerCard(BuildContext context, AppBanner banner) {
    final hasImage = banner.imageUrl != null && banner.imageUrl!.trim().isNotEmpty;

    return InkWell(
      onTap: () => _handleBannerAction(context, banner),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 98,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: hasImage
              ? null
              : LinearGradient(
                  colors: [banner.gradientStart, banner.gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          image: hasImage
              ? DecorationImage(
                  image: CachedNetworkImageProvider(banner.imageUrl!.trim()),
                  fit: BoxFit.cover,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: (hasImage ? Colors.black : banner.gradientStart).withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: hasImage
                ? LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.78),
                      Colors.black.withValues(alpha: 0.35),
                    ],
                    begin: Alignment.bottomRight,
                    end: Alignment.topLeft,
                  )
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Details Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (banner.badgeText != null && banner.badgeText!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        banner.badgeText!,
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    banner.title,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (banner.subtitle != null && banner.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      banner.subtitle!,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Action Button
            ElevatedButton(
              onPressed: () => _handleBannerAction(context, banner),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.24),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                banner.actionButtonText,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
