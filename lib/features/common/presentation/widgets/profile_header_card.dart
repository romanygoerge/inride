import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/localization/locale_controller.dart';

class ProfileHeaderCard extends StatelessWidget {
  final GlobalState state;
  final VoidCallback onChangeAvatar;

  const ProfileHeaderCard({
    super.key,
    required this.state,
    required this.onChangeAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = LocaleController.instance.isArabic;
    final avatarUrl = state.userAvatarUrl;
    final name = state.userName ??
        (state.currentRole == UserRole.rider
            ? (state.passengerName ?? (isAr ? 'مستخدم' : 'User'))
            : (isAr ? 'كابتن' : 'Captain'));
    final phone = state.phoneNumber ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primary.withAlpha(25),
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? CachedNetworkImageProvider(avatarUrl, maxWidth: 300, maxHeight: 300) as ImageProvider
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? const Icon(
                        Icons.person,
                        size: 44,
                        color: AppColors.primary,
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onChangeAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                phone,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: (state.userTotalRatingsCount > 0 ? Colors.amber : Colors.blueGrey).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (state.userTotalRatingsCount > 0 ? Colors.amber : Colors.blueGrey).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  state.userTotalRatingsCount > 0 ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: state.userTotalRatingsCount > 0 ? Colors.amber : AppColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  state.userTotalRatingsCount > 0
                      ? (isAr
                          ? '${state.userRating.toStringAsFixed(1)} (${state.userTotalRatingsCount} تقييم • ${state.userCompletedTripsCount} رحلة)'
                          : '${state.userRating.toStringAsFixed(1)} (${state.userTotalRatingsCount} ratings • ${state.userCompletedTripsCount} trips)')
                      : (isAr
                          ? 'جديد (بدون تقييم • ${state.userCompletedTripsCount} رحلة)'
                          : 'New (No ratings • ${state.userCompletedTripsCount} trips)'),
                  style: GoogleFonts.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
