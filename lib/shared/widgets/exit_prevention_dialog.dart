import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/state/global_state.dart';

/// Shows a professional premium bottom sheet preventing the user from exiting the app
void showExitPreventionAlert(BuildContext context) {
  final isRider = GlobalState.instance.currentRole == UserRole.rider;

  final message = isRider
      ? 'لديك رحلة نشطة، يجب إلغاء الرحلة أو إنهاؤها أولاً قبل الخروج من التطبيق.'
      : 'أنت في وضع الأونلاين أو لديك رحلة نشطة، يرجى إيقاف الأونلاين أو إنهاء الرحلة أولاً قبل الخروج من التطبيق.';

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Icon with soft warning background
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              'تنبيه هام',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Message
            Text(
              message,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Action button
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mediumBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              child: Text(
                'حسناً، فهمت',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
