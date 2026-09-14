import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/state/global_state.dart';
import '../../core/theme/app_theme.dart';
import '../../generated/app_localizations.dart';

class InviteFriendsSheet extends StatefulWidget {
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

  @override
  State<InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends State<InviteFriendsSheet> {
  String? _referralCode;
  int _totalInvites = 0;
  double _totalEarnedBonus = 0.0;
  bool _isLoadingStats = true;
  double _referralBonusAmount = 100.0;
  bool _isReferralSystemActive = true;

  @override
  void initState() {
    super.initState();
    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    final state = GlobalState.instance;
    final uid = state.userUid ?? Supabase.instance.client.auth.currentUser?.id;

    if (state.referralCode != null && state.referralCode!.isNotEmpty) {
      _referralCode = state.referralCode;
    }

    try {
      final supabase = Supabase.instance.client;

      // 1. Fetch system settings
      try {
        final settingsRes = await supabase
            .from('rewards_settings')
            .select()
            .eq('id', 'default')
            .maybeSingle();

        if (settingsRes != null && mounted) {
          setState(() {
            _isReferralSystemActive = settingsRes['is_referral_active'] ?? true;
            final isDriver = state.currentRole == UserRole.driver;
            final rawBonus = isDriver
                ? settingsRes['driver_referral_bonus']
                : settingsRes['rider_referral_bonus'];
            _referralBonusAmount = (rawBonus is num)
                ? rawBonus.toDouble()
                : (double.tryParse(rawBonus?.toString() ?? '100') ?? 100.0);
          });
        }
      } catch (_) {}

      // 2. Fetch user's referral code if not in state
      if (uid != null) {
        if (_referralCode == null || _referralCode!.isEmpty) {
          final userRes = await supabase
              .from('users')
              .select('referral_code')
              .eq('id', uid)
              .maybeSingle();

          if (userRes != null && userRes['referral_code'] != null) {
            _referralCode = userRes['referral_code'].toString();
            state.referralCode = _referralCode;
          }
        }

        // 3. Fetch user's invite statistics
        final refList = await supabase
            .from('referrals')
            .select('status, reward_amount')
            .eq('referrer_id', uid);

        int count = 0;
        double totalEarned = 0.0;

        for (final item in (refList as List)) {
          count++;
          if (item['status'] == 'rewarded') {
            final amt = item['reward_amount'];
            totalEarned += (amt is num)
                ? amt.toDouble()
                : (double.tryParse(amt?.toString() ?? '0') ?? 0.0);
          }
        }

        if (mounted) {
          setState(() {
            _totalInvites = count;
            _totalEarnedBonus = totalEarned;
            _isLoadingStats = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingStats = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[InviteFriends] Error loading referral data: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  Future<void> _copyAndShare({
    required BuildContext context,
    required String urlToCopy,
    required String shareMessage,
    required String successNotice,
  }) async {
    await Clipboard.setData(ClipboardData(text: urlToCopy));

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
    final code = _referralCode ?? 'INRIDE';

    final smartInviteText =
        'حمّل تطبيق inRide لطلب الرحلات والتوصيل بأسعار عادلة! 🚗✨\n'
        'استخدم كود الدعوة الخاص بي ($code) للحصول على رصيد مجاني ترحيبي في محفظتك فور إتمام رحلتك الأولى بنجاح! 🎁\n\n'
        '📱 للأندرويد: ${InviteFriendsSheet.androidUrl}\n'
        '🍏 للآيفون: ${InviteFriendsSheet.iosUrl}';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 16),

            // Top Icon
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
                Icons.card_giftcard_rounded,
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
            const SizedBox(height: 4),

            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _isReferralSystemActive
                    ? 'شارك كود الدعوة الخاص بك مع أصدقائك: فور إتمام صديقك لرحلته الأولى، يحصل على رصيد مجاني وتحصل أنت على ${_referralBonusAmount.toInt()} ج.م في محفظتك!'
                    : l10n.inviteFriendsSubtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Referral Code Box (Highlighted Card)
            if (_referralCode != null && _referralCode!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E3A8A).withValues(alpha: 0.06),
                      AppColors.mediumBlue.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.mediumBlue.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'كود الدعوة الخاص بك',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mediumBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _referralCode!,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _copyOnly(
                              context: context,
                              text: _referralCode!,
                              message: 'تم نسخ كود الدعوة بنجاح 📋',
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.mediumBlue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'نسخ',
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
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
                    ),
                    const SizedBox(height: 12),

                    // User Personal Referral Stats
                    if (!_isLoadingStats)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.people_outline_rounded, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                'الدعوات: $_totalInvites',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 16, color: Colors.grey.shade300),
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Text(
                                'أرباحك: ${_totalEarnedBonus.toInt()} ج.م',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Quick Share Button with Code (WhatsApp/All apps)
            ElevatedButton(
              onPressed: () => _copyAndShare(
                context: context,
                urlToCopy: code,
                shareMessage: smartInviteText,
                successNotice: 'تم نسخ كود الدعوة ورابط التطبيق! 🚀',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FaIcon(FontAwesomeIcons.whatsapp, size: 20, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    'مشاركة كود الدعوة عبر واتساب',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Store Direct Links Divider
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade200)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'أو مشاركة روابط المتاجر مباشرة',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade200)),
              ],
            ),
            const SizedBox(height: 14),

            // Google Play Store Button
            _buildStoreButton(
              context: context,
              backgroundColor: const Color(0xFF0F172A),
              borderColor: const Color(0xFF334155),
              iconWidget: const FaIcon(
                FontAwesomeIcons.googlePlay,
                color: Color(0xFF00E676),
                size: 26,
              ),
              subLabel: l10n.downloadAndroid,
              storeName: l10n.googlePlay,
              actionBadgeText: l10n.copyAndShare,
              onTapCard: () => _copyAndShare(
                context: context,
                urlToCopy: InviteFriendsSheet.androidUrl,
                shareMessage: smartInviteText,
                successNotice: l10n.copiedGooglePlaySuccess,
              ),
              onCopyPressed: () => _copyOnly(
                context: context,
                text: InviteFriendsSheet.androidUrl,
                message: l10n.copiedGooglePlaySuccess,
              ),
            ),
            const SizedBox(height: 10),

            // App Store Button
            _buildStoreButton(
              context: context,
              backgroundColor: Colors.black,
              borderColor: const Color(0xFF27272A),
              iconWidget: const FaIcon(
                FontAwesomeIcons.apple,
                color: Colors.white,
                size: 28,
              ),
              subLabel: l10n.downloadIos,
              storeName: l10n.appStore,
              actionBadgeText: l10n.copyAndShare,
              onTapCard: () => _copyAndShare(
                context: context,
                urlToCopy: InviteFriendsSheet.iosUrl,
                shareMessage: smartInviteText,
                successNotice: l10n.copiedAppStoreSuccess,
              ),
              onCopyPressed: () => _copyOnly(
                context: context,
                text: InviteFriendsSheet.iosUrl,
                message: l10n.copiedAppStoreSuccess,
              ),
            ),
          ],
        ),
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
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTapCard,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Center(child: iconWidget),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subLabel,
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    Text(
                      storeName,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onCopyPressed,
                icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
                tooltip: 'نسخ الرابط',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
