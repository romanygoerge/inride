import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';

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
    final avatarUrl = state.userAvatarUrl;
    final name = state.userName ??
        (state.currentRole == UserRole.rider
            ? (state.passengerName ?? 'مستخدم')
            : 'كابتن');
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
                    ? CachedNetworkImageProvider(avatarUrl) as ImageProvider
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
        ],
      ),
    );
  }
}
