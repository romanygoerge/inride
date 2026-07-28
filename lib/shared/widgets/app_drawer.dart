import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/state/global_state.dart';
import '../../features/common/wallet_page.dart';
import '../../features/common/history_page.dart';
import '../../features/common/profile_page.dart';
import '../../features/driver_registration/presentation/pages/doc_upload_page.dart';
import '../../features/driver_registration/presentation/pages/review_pending_page.dart';
import '../../features/driver/presentation/pages/driver_home_page.dart';
import '../../features/passenger/presentation/pages/passenger_home_page.dart';
import '../../features/common/support_page.dart';
import '../../features/common/notifications_page.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../core/utils/snappy_page_route.dart';
import 'exit_prevention_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _switchRole(BuildContext context, GlobalState state) async {
    if (!state.canExitApplication()) {
      Navigator.pop(context); // Close drawer
      showExitPreventionAlert(context);
      return;
    }
    Navigator.pop(context); // Close drawer

    if (state.currentRole == UserRole.rider) {
      final isSearching = state.rideStatus == RideStatus.searching || state.rideStatus == RideStatus.driverBidding;
      final hasActiveTrip = state.rideStatus == RideStatus.driverOnWay || 
                            state.rideStatus == RideStatus.arrived || 
                            state.rideStatus == RideStatus.tripStarted;
      if (isSearching || hasActiveTrip) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
        await state.cancelRide(cancelledBy: state.currentRole == UserRole.driver ? 'driver' : 'passenger');
        if (context.mounted) {
          Navigator.pop(context); // Dismiss loading dialog
        }
      }

      if (!context.mounted) return;

      // Switching to Driver
      if (state.verificationStatus == DriverVerificationStatus.unregistered) {
        Navigator.push(context, SnappyPageRoute(page: const DocUploadPage()));
      } else if (state.verificationStatus == DriverVerificationStatus.submitted) {
        Navigator.push(context, SnappyPageRoute(page: const ReviewPendingPage()));
      } else {
        state.selectRole(UserRole.driver);
        Navigator.pushReplacement(context, SnappyPageRoute(page: const DriverHomePage()));
      }
    } else {
      // Switching to Rider
      await state.ensurePassengerProfileExists();
      state.selectRole(UserRole.rider);
      if (!context.mounted) return;
      Navigator.pushReplacement(context, SnappyPageRoute(page: const PassengerHomePage()));
    }
  }

  Future<void> _launchURL(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildSocialIcon({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = GlobalState.instance;
    final isRider = state.currentRole == UserRole.rider;
    final otherRoleText = isRider ? 'كابتن' : 'راكب';

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drawer Header with Profile (Clickable to go to Profile Page)
          GestureDetector(
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(context, SnappyPageRoute(page: const ProfilePage()));
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      state.userAvatarUrl != null && state.userAvatarUrl!.isNotEmpty
                          ? CircleAvatar(
                              radius: 30,
                              backgroundImage: CachedNetworkImageProvider(state.userAvatarUrl!),
                              backgroundColor: AppColors.background,
                            )
                          : CircleAvatar(
                              radius: 30,
                              backgroundColor: AppColors.mediumBlue.withValues(alpha: 0.1),
                              child: Text(
                                (state.userName ?? (isRider ? (state.passengerName ?? '') : 'كابتن'))
                                    .trim()
                                    .characters
                                    .firstOrNull
                                    ?.toUpperCase() ?? '?',
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.mediumBlue,
                                ),
                              ),
                            ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.userName ?? (isRider ? (state.passengerName ?? 'راكب') : 'كابتن'),
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.orange, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  isRider ? '4.8 (راكب)' : '4.9 (كابتن)',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            if (state.hasDualRole) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '⭐ حساب مزدوج (كابتن وراكب)',
                                  style: GoogleFonts.cairo(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Wallet Balance Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: AppColors.blueGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.mediumBlue.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المحفظة',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        '${state.walletBalance.toStringAsFixed(2)} ج.م',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, SnappyPageRoute(page: const WalletPage()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'شحن',
                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Switch Role Tile (Vibrant Blue Background to highlight)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: InkWell(
              onTap: () => _switchRole(context, state),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.mediumBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.mediumBlue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isRider ? Icons.directions_car_outlined : Icons.person_pin_circle_outlined,
                      color: AppColors.mediumBlue,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'التبديل إلى وضع $otherRoleText',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mediumBlue,
                        ),
                      ),
                    ),
                    const Icon(Icons.swap_horiz, color: AppColors.mediumBlue),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 24, color: AppColors.border),

          // Menu List Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.history_outlined,
                  title: 'رحلاتي',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, SnappyPageRoute(page: const HistoryPage()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.notifications_none_outlined,
                  title: 'مركز الإشعارات',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, SnappyPageRoute(page: const NotificationsPage()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.help_outline_outlined,
                  title: 'مركز المساعدة',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, SnappyPageRoute(page: const SupportPage()));
                  },
                ),
              ],
            ),
          ),

          // Social Media Icons
          const Divider(color: AppColors.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSocialIcon(
                icon: FontAwesomeIcons.facebook,
                color: const Color(0xFF1877F2),
                onTap: () => _launchURL('https://www.facebook.com/profile.php?id=61592010896445&locale=ar_AR'),
              ),
              const SizedBox(width: 12),
              _buildSocialIcon(
                icon: FontAwesomeIcons.youtube,
                color: const Color(0xFFFF0000),
                onTap: () => _launchURL('https://www.youtube.com/@inRide2026'),
              ),
              const SizedBox(width: 12),
              _buildSocialIcon(
                icon: FontAwesomeIcons.instagram,
                color: const Color(0xFFE1306C),
                onTap: () => _launchURL('https://www.instagram.com/inride_app/?hl=en'),
              ),
              const SizedBox(width: 12),
              _buildSocialIcon(
                icon: FontAwesomeIcons.tiktok,
                color: const Color(0xFF000000),
                onTap: () => _launchURL('https://www.tiktok.com/@inride_app'),
              ),
              const SizedBox(width: 12),
              _buildSocialIcon(
                icon: FontAwesomeIcons.whatsapp,
                color: const Color(0xFF25D366),
                onTap: () => _launchURL('https://wa.me/201289379958'),
              ),
            ],
          ),
          const SizedBox(height: 12),



          // Logout Item
          const Divider(color: AppColors.border),
          _buildDrawerItem(
            context,
            icon: Icons.logout_outlined,
            title: 'تسجيل الخروج',
            textColor: AppColors.error,
            iconColor: AppColors.error,
            onTap: () async {
              Navigator.pop(context); // Close drawer
              final isSearching = state.rideStatus == RideStatus.searching || state.rideStatus == RideStatus.driverBidding;
              final hasActiveTrip = state.rideStatus == RideStatus.driverOnWay || 
                                    state.rideStatus == RideStatus.arrived || 
                                    state.rideStatus == RideStatus.tripStarted;
              if (state.currentRole == UserRole.rider && (isSearching || hasActiveTrip)) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
                await state.cancelRide(cancelledBy: state.currentRole == UserRole.driver ? 'driver' : 'passenger');
                if (context.mounted) {
                  Navigator.pop(context); // Dismiss loading
                }
              } else if (state.currentRole == UserRole.driver) {
                await state.stopDriverLocationTracking();
              }
              if (context.mounted) {
                await state.performSafeLogout(context);
              }
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color textColor = AppColors.textPrimary,
    Color iconColor = AppColors.textSecondary,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      onTap: onTap,
      dense: true,
    );
  }
}
