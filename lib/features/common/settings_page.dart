import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/state/global_state.dart';
import '../../core/localization/locale_controller.dart';
import '../../generated/app_localizations.dart';
import 'legal_pages.dart';
import '../../core/utils/snappy_page_route.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _pushNotifications = true;
  bool _soundEffects = true;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l10n.settings,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. General Preferences
              Text(
                l10n.accountSettings,
                style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      _buildSwitchTile(
                        icon: Icons.notifications_active_outlined,
                        title: l10n.notificationsCenter,
                        value: _pushNotifications,
                        onChanged: (val) {
                          setState(() {
                            _pushNotifications = val;
                          });
                        },
                      ),
                      const Divider(color: AppColors.border, height: 16),
                      _buildSwitchTile(
                        icon: Icons.volume_up_outlined,
                        title: l10n.supportTitle,
                        value: _soundEffects,
                        onChanged: (val) {
                          setState(() {
                            _soundEffects = val;
                          });
                        },
                      ),
                      const Divider(color: AppColors.border, height: 16),
                      _buildSwitchTile(
                        icon: Icons.dark_mode_outlined,
                        title: l10n.darkMode,
                        value: _darkMode,
                        onChanged: (val) {
                          setState(() {
                            _darkMode = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 2. Language Preferences
              Text(
                l10n.language,
                style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: ListTile(
                  leading: const Icon(Icons.language_outlined, color: AppColors.textSecondary),
                  title: Text(
                    l10n.language,
                    style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    LocaleController.instance.isArabic ? l10n.arabic : l10n.english,
                    style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_outlined, color: AppColors.textLight, size: 14),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text(l10n.changeLanguage, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: Text(l10n.arabic),
                                trailing: LocaleController.instance.isArabic ? const Icon(Icons.check, color: AppColors.mediumBlue) : null,
                                onTap: () async {
                                  await LocaleController.instance.setLocale(const Locale('ar', 'EG'));
                                  if (context.mounted) Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                title: Text(l10n.english),
                                trailing: LocaleController.instance.isEnglish ? const Icon(Icons.check, color: AppColors.mediumBlue) : null,
                                onTap: () async {
                                  await LocaleController.instance.setLocale(const Locale('en', 'US'));
                                  if (context.mounted) Navigator.pop(context);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // 3. Legal & Policy Information
              Text(
                l10n.legalTerms,
                style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.description_outlined, color: AppColors.mediumBlue),
                      title: Text(l10n.legalTerms, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.arrow_forward_ios_outlined, color: AppColors.textLight, size: 14),
                      onTap: () => Navigator.push(context, SnappyPageRoute(page: const TermsOfUsePage())),
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    ListTile(
                      leading: const Icon(Icons.assignment_outlined, color: AppColors.mediumBlue),
                      title: Text(l10n.termsAndConditionsText, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.arrow_forward_ios_outlined, color: AppColors.textLight, size: 14),
                      onTap: () => Navigator.push(context, SnappyPageRoute(page: const TermsAndConditionsPage())),
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.mediumBlue),
                      title: Text(l10n.privacyPolicyText, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.arrow_forward_ios_outlined, color: AppColors.textLight, size: 14),
                      onTap: () => Navigator.push(context, SnappyPageRoute(page: const PrivacyPolicyPage())),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 4. Danger Zone / Actions
              ElevatedButton(
                onPressed: () {
                  GlobalState.instance.reset();
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error.withValues(alpha:0.05),
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  l10n.logout,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  final isArabic = LocaleController.instance.isArabic;
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isArabic ? 'حذف الحساب نهائياً' : 'Delete Account Permanently',
                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                      content: Text(
                        isArabic
                            ? 'هل أنت تأكد من رغبتك في حذف حسابك؟ وسيؤدي هذا إلى إلغاء جميع بياناتك وسجلات رحلاتك ورصيد محفظتك نهائياً طبقاً لسياسات الخصوصية.'
                            : 'Are you sure you want to delete your account? This will permanently delete your profile, trip history, and wallet balance in accordance with store privacy policies.',
                        style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textPrimary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(isArabic ? 'إلغاء' : 'Cancel', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            try {
                              final uid = GlobalState.instance.userUid;
                              if (uid != null) {
                                await GlobalState.instance.deleteUserAccount();
                              }
                            } catch (_) {}
                            GlobalState.instance.reset();
                            if (context.mounted) {
                              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(isArabic ? 'تأكيد الحذف' : 'Confirm Delete', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_forever_outlined, color: AppColors.error, size: 18),
                label: Text(
                  LocaleController.instance.isArabic ? 'حذف الحساب والبيانات' : 'Delete Account & Data',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '${l10n.version} 1.0.0 (2026)',
                  style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [

        Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 14),
            Text(
              title,
              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ],
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.mediumBlue,
        ),
      ],
    );
  }
}

