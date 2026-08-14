import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/locale_controller.dart';

class DriverStatusHeader extends StatelessWidget {
  final bool isOnline;
  final ValueChanged<bool> onToggleOnline;
  final VoidCallback onOpenDrawer;

  const DriverStatusHeader({
    super.key,
    required this.isOnline,
    required this.onToggleOnline,
    required this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = LocaleController.instance.isArabic;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textPrimary),
              onPressed: onOpenDrawer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isOnline 
                        ? (isArabic ? 'أنت متصل وجاهز للعمل 🟢' : 'You are Online 🟢')
                        : (isArabic ? 'أنت غير متصل 🔴' : 'You are Offline 🔴'),
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isOnline ? Colors.green.shade700 : AppColors.error,
                    ),
                  ),
                  Text(
                    isOnline
                        ? (isArabic ? 'تلقي طلبات الرحلات والتوصيل' : 'Receiving ride & delivery requests')
                        : (isArabic ? 'قم بالتفعيل لبدء استقبال الطلبات' : 'Go online to receive request offers'),
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: isOnline,
              activeTrackColor: Colors.green,
              onChanged: onToggleOnline,
            ),
          ],
        ),
      ),
    );
  }
}
