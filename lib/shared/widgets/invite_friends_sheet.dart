import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../generated/app_localizations.dart';

class InviteFriendsSheet extends StatelessWidget {
  const InviteFriendsSheet({super.key});

  static const String androidUrl =
      'https://play.google.com/store/apps/details?id=com.inride.inride_app';
  static const String iosUrl =
      'https://apps.apple.com/eg/app/inride/id6806885855';

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const InviteFriendsSheet(),
    );
  }

  Future<void> _copyAndShare({
    required BuildContext context,
    required String urlToCopy,
    required String shareMessage,
    required String successNotice,
  }) async {
    // 1. Copy link to clipboard
    await Clipboard.setData(ClipboardData(text: urlToCopy));

    // 2. Show quick feedback snackbar
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  successNotice,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.mediumBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // 3. Open OS Share sheet (WhatsApp, Messenger, SMS, etc.)
    await SharePlus.instance.share(
      ShareParams(
        text: shareMessage,
        subject: 'inRide App',
      ),
    );
  }

  Future<void> _copyOnly({
    required BuildContext context,
    required String text,
    required String message,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final androidShareText =
        'حمّل تطبيق inRide الآن واستمتع بأفضل تجربة رحلات وتوصيل على أندرويد 🚗✨\nرابط التحميل: $androidUrl';
    final iosShareText =
        'حمّل تطبيق inRide الآن واستمتع بأفضل تجربة رحلات وتوصيل على آيفون 🚗✨\nرابط التحميل: $iosUrl';
    final bothShareText =
        'حمّل تطبيق inRide الآن لأفضل تجربة رحلات وتوصيل بأسعار عادلة! 🚗✨\n\n'
        '📱 رابط التحميل للأندرويد (Google Play):\n$androidUrl\n\n'
        '🍏 رابط التحميل للآيفون (App Store):\n$iosUrl';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 18),

          // Header Badge
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.blueGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.mediumBlue.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.group_add_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            l10n.inviteFriends,
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.inviteFriendsSubtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Google Play Store Button
          _buildStoreButton(
            context: context,
            backgroundColor: const Color(0xFF0F172A),
            borderColor: const Color(0xFF334155),
            iconWidget: const FaIcon(
              FontAwesomeIcons.googlePlay,
              color: Color(0xFF00E676),
              size: 28,
            ),
            subLabel: l10n.downloadAndroid,
            storeName: l10n.googlePlay,
            actionBadgeText: l10n.copyAndShare,
            onTapCard: () => _copyAndShare(
              context: context,
              urlToCopy: androidUrl,
              shareMessage: androidShareText,
              successNotice: l10n.copiedGooglePlaySuccess,
            ),
            onCopyPressed: () => _copyOnly(
              context: context,
              text: androidUrl,
              message: l10n.copiedGooglePlaySuccess,
            ),
          ),
          const SizedBox(height: 12),

          // App Store Button
          _buildStoreButton(
            context: context,
            backgroundColor: Colors.black,
            borderColor: const Color(0xFF27272A),
            iconWidget: const FaIcon(
              FontAwesomeIcons.apple,
              color: Colors.white,
              size: 32,
            ),
            subLabel: l10n.downloadIos,
            storeName: l10n.appStore,
            actionBadgeText: l10n.copyAndShare,
            onTapCard: () => _copyAndShare(
              context: context,
              urlToCopy: iosUrl,
              shareMessage: iosShareText,
              successNotice: l10n.copiedAppStoreSuccess,
            ),
            onCopyPressed: () => _copyOnly(
              context: context,
              text: iosUrl,
              message: l10n.copiedAppStoreSuccess,
            ),
          ),
          const SizedBox(height: 16),

          // Combined "Share Both Links" Button
          InkWell(
            onTap: () => _copyAndShare(
              context: context,
              urlToCopy: '$androidUrl\n$iosUrl',
              shareMessage: bothShareText,
              successNotice: l10n.copiedBothSuccess,
            ),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.blueGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.mediumBlue.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    l10n.shareBothLinks,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreButton({
    required BuildContext context,
    required Color backgroundColor,
    required Color borderColor,
    required Widget iconWidget,
    required String subLabel,
    required String storeName,
    required String actionBadgeText,
    required VoidCallback onTapCard,
    required VoidCallback onCopyPressed,
  }) {
    return InkWell(
      onTap: onTapCard,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Store Icon
            SizedBox(
              width: 36,
              height: 36,
              child: Center(child: iconWidget),
            ),
            const SizedBox(width: 14),

            // Store Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    subLabel.toUpperCase(),
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      letterSpacing: 0.4,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    storeName,
                    style: GoogleFonts.cairo(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // Direct Copy Icon Button
            IconButton(
              onPressed: onCopyPressed,
              tooltip: 'نسخ الرابط',
              icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            ),

            const SizedBox(width: 4),

            // Action Badge (Copy & Share)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.share_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    actionBadgeText,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
