import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/state/global_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _pushNotifications = true;
  bool _soundEffects = true;
  bool _darkMode = false;
  String _language = 'ar';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'إعدادات التطبيق',
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
                'التفضيلات العامة',
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
                        title: 'إشعارات الرحلات والعروض',
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
                        title: 'الأصوات والتنبيهات الصوتية',
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
                        title: 'الوضع الليلي (تلقائي)',
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
                'اللغة والدولة',
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
                    'لغة التطبيق الافتراضية',
                    style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    _language == 'ar' ? 'العربية (مصر)' : 'English',
                    style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_outlined, color: AppColors.textLight, size: 14),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text('اختر اللغة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: const Text('العربية'),
                                trailing: _language == 'ar' ? const Icon(Icons.check, color: AppColors.mediumBlue) : null,
                                onTap: () {
                                  setState(() => _language = 'ar');
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                title: const Text('English'),
                                trailing: _language == 'en' ? const Icon(Icons.check, color: AppColors.mediumBlue) : null,
                                onTap: () {
                                  setState(() => _language = 'en');
                                  Navigator.pop(context);
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
              const SizedBox(height: 32),

              // 3. Danger Zone / Actions
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
                  'تسجيل الخروج من الحساب',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'إصدار التطبيق 1.0.0 (بناء 2026)',
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
