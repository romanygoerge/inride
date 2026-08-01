import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../generated/app_localizations.dart';

class PassengerLocationBar extends StatelessWidget {
  final String fromAddress;
  final String toAddress;
  final VoidCallback onTapFrom;
  final VoidCallback onTapTo;

  const PassengerLocationBar({
    super.key,
    required this.fromAddress,
    required this.toAddress,
    required this.onTapFrom,
    required this.onTapTo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          InkWell(
            onTap: onTapFrom,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                const Icon(Icons.circle, color: Colors.green, size: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fromAddress.isEmpty ? AppLocalizations.of(context)!.myCurrentLocation : fromAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: AppColors.border),
          ),
          InkWell(
            onTap: onTapTo,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primary, size: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    toAddress.isEmpty ? AppLocalizations.of(context)!.whereToGo : toAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: toAddress.isEmpty ? FontWeight.normal : FontWeight.bold,
                      color: toAddress.isEmpty ? AppColors.textSecondary : AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(Icons.search, color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
