import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../driver/presentation/widgets/driver_daily_mission_card.dart';

/// EarnMoreMoneyPage ("اكسب فلوس أكتر")
///
/// Refined inRide-branded rewards, captain bonus missions,
/// referral code sharing, and promo code redemption screen.
class EarnMoreMoneyPage extends StatefulWidget {
  final int initialTabIndex;
  const EarnMoreMoneyPage({super.key, this.initialTabIndex = 0});

  static const String androidUrl =
      'https://play.google.com/store/apps/details?id=com.inride.inride_app';
  static const String iosUrl =
      'https://apps.apple.com/eg/app/inride/id6806885855';

  @override
  State<EarnMoreMoneyPage> createState() => _EarnMoreMoneyPageState();
}

class _EarnMoreMoneyPageState extends State<EarnMoreMoneyPage>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _promoController = TextEditingController();

  late TabController _tabController;
  bool _isLoading = true;
  bool _isApplyingPromo = false;

  // Referral / Rewards State
  String? _myReferralCode;
  int _totalInvites = 0;
  int _completedInvites = 0;
  double _totalEarned = 0.0;
  bool _isReferralActive = true;
  double _driverReferralBonus = 100.0;
  double _driverWelcomeBonus = 50.0;
  double _riderReferralBonus = 20.0;
  double _riderWelcomeBonus = 15.0;

  // Redeemed referral status for current user
  bool _hasRedeemedCode = false;
  String? _redeemedCode;
  String _redeemedStatus = 'none';
  double _redeemedWelcomeBonus = 0.0;

  @override
  void initState() {
    super.initState();
    final isDriver = GlobalState.instance.currentRole == UserRole.driver;
    final tabCount = isDriver ? 3 : 2;
    final initialIndex = widget.initialTabIndex.clamp(0, tabCount - 1);
    _tabController = TabController(
      length: tabCount,
      vsync: this,
      initialIndex: initialIndex,
    );
    _loadAllRewardsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _loadAllRewardsData() async {
    final state = GlobalState.instance;
    final uid = state.userUid ?? _supabase.auth.currentUser?.id;

    if (state.referralCode != null && state.referralCode!.isNotEmpty) {
      _myReferralCode = state.referralCode;
    }

    try {
      // 1. Fetch system rewards settings
      try {
        final settingsRes = await _supabase
            .from('rewards_settings')
            .select()
            .eq('id', 'default')
            .maybeSingle();

        if (settingsRes != null && mounted) {
          _isReferralActive = settingsRes['is_referral_active'] ?? true;
          _driverReferralBonus = (settingsRes['driver_referral_bonus'] is num)
              ? (settingsRes['driver_referral_bonus'] as num).toDouble()
              : (double.tryParse(settingsRes['driver_referral_bonus']?.toString() ?? '100') ?? 100.0);
          _driverWelcomeBonus = (settingsRes['driver_welcome_bonus'] is num)
              ? (settingsRes['driver_welcome_bonus'] as num).toDouble()
              : (double.tryParse(settingsRes['driver_welcome_bonus']?.toString() ?? '50') ?? 50.0);
          _riderReferralBonus = (settingsRes['rider_referral_bonus'] is num)
              ? (settingsRes['rider_referral_bonus'] as num).toDouble()
              : (double.tryParse(settingsRes['rider_referral_bonus']?.toString() ?? '20') ?? 20.0);
          _riderWelcomeBonus = (settingsRes['rider_welcome_bonus'] is num)
              ? (settingsRes['rider_welcome_bonus'] as num).toDouble()
              : (double.tryParse(settingsRes['rider_welcome_bonus']?.toString() ?? '15') ?? 15.0);
        }
      } catch (err) {
        debugPrint('[EarnMoreMoney] settings fetch notice: $err');
      }

      // 2. Fetch user referral summary RPC
      if (uid != null) {
        try {
          final summaryRes = await _supabase.rpc('get_user_referral_summary', params: {
            'p_user_id': uid,
          });

          if (summaryRes != null && summaryRes is Map && mounted) {
            _myReferralCode = summaryRes['referral_code']?.toString() ?? _myReferralCode;
            state.referralCode = _myReferralCode;
            _totalInvites = (summaryRes['total_invites'] as num?)?.toInt() ?? 0;
            _completedInvites = (summaryRes['completed_invites'] as num?)?.toInt() ?? 0;
            _totalEarned = (summaryRes['total_earned'] as num?)?.toDouble() ?? 0.0;
            _hasRedeemedCode = summaryRes['has_redeemed_code'] == true;
            _redeemedCode = summaryRes['redeemed_code']?.toString();
            _redeemedStatus = summaryRes['redeemed_status']?.toString() ?? 'none';
            _redeemedWelcomeBonus = (summaryRes['redeemed_welcome_bonus'] as num?)?.toDouble() ?? 0.0;
          }
        } catch (rpcErr) {
          debugPrint('[EarnMoreMoney] summary RPC notice: $rpcErr');
        }

        // Fallback: check referrals table directly if RPC didn't populate redeemed
        if (!_hasRedeemedCode) {
          try {
            final redeemedRes = await _supabase
                .from('referrals')
                .select('referral_code, status, welcome_bonus_amount')
                .eq('referred_id', uid)
                .maybeSingle();

            if (redeemedRes != null && mounted) {
              _hasRedeemedCode = true;
              _redeemedCode = redeemedRes['referral_code']?.toString();
              _redeemedStatus = redeemedRes['status']?.toString() ?? 'pending';
              _redeemedWelcomeBonus = (redeemedRes['welcome_bonus_amount'] as num?)?.toDouble() ?? 0.0;
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[EarnMoreMoney] Error loading rewards data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showCustomSnackBar('يرجى كتابة كود الدعوة أو البرومو كود أولاً', isError: true);
      return;
    }

    final uid = GlobalState.instance.userUid ?? _supabase.auth.currentUser?.id;
    if (uid == null) {
      _showCustomSnackBar('يرجى تسجيل الدخول أولاً لتطبيق الكود', isError: true);
      return;
    }

    if (code == _myReferralCode?.toUpperCase()) {
      _showCustomSnackBar('لا يمكنك استخدام كود الدعوة الخاص بك', isError: true);
      return;
    }

    setState(() => _isApplyingPromo = true);
    FocusManager.instance.primaryFocus?.unfocus();

    try {
      final isDriver = GlobalState.instance.currentRole == UserRole.driver;
      final res = await _supabase.rpc('apply_referral_code', params: {
        'p_referred_id': uid,
        'p_code': code,
        'p_user_type': isDriver ? 'driver' : 'rider',
      });

      if (!mounted) return;

      if (res != null && res is Map) {
        final isSuccess = res['success'] == true;
        final msg = res['message']?.toString() ??
            (isSuccess ? 'تم تفعيل الكود بنجاح!' : 'تعذر تطبيق الكود');

        if (isSuccess) {
          _promoController.clear();
          _showCustomSnackBar(msg, isError: false);
          await _loadAllRewardsData();
        } else {
          _showCustomSnackBar(msg, isError: true);
        }
      } else {
        _showCustomSnackBar('تم إرسال الطلب، يرجى التحديث', isError: false);
        await _loadAllRewardsData();
      }
    } catch (e) {
      debugPrint('[EarnMoreMoney] apply_referral_code error: $e');
      _showCustomSnackBar('حدث خطأ أثناء تفعيل الكود: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isApplyingPromo = false);
    }
  }

  Future<void> _copyCodeToClipboard() async {
    final code = _myReferralCode ?? 'INRIDE';
    await Clipboard.setData(ClipboardData(text: code));
    _showCustomSnackBar('تم نسخ كود الدعوة بنجاح: $code ✅', isError: false);
  }

  Future<void> _shareOnWhatsApp() async {
    final code = _myReferralCode ?? 'INRIDE';
    final isDriver = GlobalState.instance.currentRole == UserRole.driver;
    final rewardText = isDriver ? '$_driverReferralBonus ج.م' : '$_riderReferralBonus ج.م';

    final text = '🚀 حمّل تطبيق inRide واستخدم كود الدعوة الخاص بي ($code) للحصول على رصيد مجاني ترحيبي ($rewardText) في محفظتك فوراً! 🎁\n\n'
        '🚗 أسعار عادلة ورحلات سريعة في مدينة السادات بدون استغلال.\n\n'
        '📱 للأندرويد: ${EarnMoreMoneyPage.androidUrl}\n'
        '🍏 للآيفون: ${EarnMoreMoneyPage.iosUrl}';

    await Clipboard.setData(ClipboardData(text: code));
    await SharePlus.instance.share(ShareParams(text: text, subject: 'inRide Rewards'));
  }

  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.error : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = GlobalState.instance.currentRole == UserRole.driver;
    final isAr = LocaleController.instance.isArabic;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            isAr ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_ios_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isAr ? 'اكسب فلوس أكتر' : 'Earn More Money',
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.mediumBlue),
            tooltip: 'تحديث',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadAllRewardsData();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.mediumBlue,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.mediumBlue.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: isDriver
                  ? const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.emoji_events_rounded, size: 17),
                            SizedBox(width: 5),
                            Text('تحديات البونص'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.card_giftcard_rounded, size: 17),
                            SizedBox(width: 5),
                            Text('كود الدعوة'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_offer_rounded, size: 17),
                            SizedBox(width: 5),
                            Text('إدخال كود'),
                          ],
                        ),
                      ),
                    ]
                  : const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.card_giftcard_rounded, size: 17),
                            SizedBox(width: 5),
                            Text('كود الدعوة'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_offer_rounded, size: 17),
                            SizedBox(width: 5),
                            Text('إدخال كود'),
                          ],
                        ),
                      ),
                    ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.mediumBlue),
            )
          : RefreshIndicator(
              color: AppColors.mediumBlue,
              onRefresh: _loadAllRewardsData,
              child: TabBarView(
                controller: _tabController,
                children: isDriver
                    ? [
                        _buildMissionsTab(),
                        _buildReferralsTab(),
                        _buildPromoCodeTab(),
                      ]
                    : [
                        _buildReferralsTab(),
                        _buildPromoCodeTab(),
                      ],
              ),
            ),
    );
  }

  // ===========================================================================
  // TAB 1: Driver Daily Missions & Shifts
  // ===========================================================================
  Widget _buildMissionsTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'تحدي اليوم المباشر',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Centerpiece: The Live Mission Card
          const DriverDailyMissionCard(),

          const SizedBox(height: 14),

          // Sadat City Shift Times Guide
          _buildBonusShiftsScheduleCard(),

          const SizedBox(height: 14),

          // How missions work card
          _buildHowItWorksCard(
            title: 'كيف تكسب بونص الرحلات؟',
            steps: [
              {
                'icon': Icons.online_prediction_rounded,
                'title': 'اتصل للعمل في الفترات المحددة',
                'desc': 'قم بتفعيل زر "متصل للعمل" بالخريطة أثناء فترات البونص.',
              },
              {
                'icon': Icons.directions_car_filled_rounded,
                'title': 'اقبل وأكمل الرحلات المطلوبة',
                'desc': 'أنجز عدد الرحلات المطلوب قبل انتهاء وقت التحدي المحدد.',
              },
              {
                'icon': Icons.account_balance_wallet_rounded,
                'title': 'استلم البونص فوراً في المحفظة',
                'desc': 'تتم إضافة قيمة البونص كاش مباشرة لمحفظتك فور إتمام الهدف.',
              },
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: Referral Code & Sharing
  // ===========================================================================
  Widget _buildReferralsTab() {
    final isDriver = GlobalState.instance.currentRole == UserRole.driver;
    final referralReward = isDriver ? _driverReferralBonus : _riderReferralBonus;
    final code = _myReferralCode ?? 'INRIDE';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isReferralActive) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE047)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'نظام الإحالات متوقف مؤقتاً للتحديثات وسيعود قريباً.',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // inRide Signature Blue Gradient Header
          _buildBrandedEarningsBanner(referralReward),

          const SizedBox(height: 14),

          // Referral Code Card (Clean, High-Contrast)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'كود الدعوة الخاص بك',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),

                // Clean Blue Code Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        code,
                        style: GoogleFonts.cairo(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.darkBlue,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(width: 14),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: AppColors.mediumBlue, size: 22),
                        tooltip: 'نسخ الكود',
                        onPressed: _copyCodeToClipboard,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // WhatsApp Sharing Button (Crisp & Official)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _shareOnWhatsApp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 19),
                    label: Text(
                      'مشاركة كود الدعوة عبر واتساب',
                      style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // General Share Outlined Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final text = 'حمّل تطبيق inRide واستخدم كود الدعوة ($code) للحصول على رصيد مجاني ترحيبي! 🚗🎁\n'
                          '📱 للأندرويد: ${EarnMoreMoneyPage.androidUrl}\n'
                          '🍏 للآيفون: ${EarnMoreMoneyPage.iosUrl}';
                      SharePlus.instance.share(ShareParams(text: text));
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.mediumBlue,
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 17),
                    label: Text(
                      'مشاركة عبر تطبيقات أخرى',
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Reward Rates Cards
          _buildRewardRatesRow(),

          const SizedBox(height: 14),

          // How it Works Steps
          _buildHowItWorksCard(
            title: 'كيف يعمل نظام الدعوات؟',
            steps: [
              {
                'icon': Icons.send_rounded,
                'title': 'شارك كودك ورابط التطبيق',
                'desc': 'أرسل كود الدعوة لأصدقائك عبر الواتساب ومواقع التواصل.',
              },
              {
                'icon': Icons.person_add_alt_1_rounded,
                'title': 'يسجل صديقك باستخدام الكود',
                'desc': 'يُدخل صديقك الكود عند التسجيل أو من صفحة "إدخال كود".',
              },
              {
                'icon': Icons.check_circle_rounded,
                'title': 'احصل على البونص فور إتمام رحلته',
                'desc': 'فور إتمام صديقك أول رحلة، يُضاف البونص لمحفظتك ومحفظته.',
              },
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 3: Enter Promo Code
  // ===========================================================================
  Widget _buildPromoCodeTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_hasRedeemedCode) ...[
            // Status Card for already redeemed referral code
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: Color(0xFF059669), size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'تم تفعيل كود الإحالة بنجاح!',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF065F46),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Text(
                      _redeemedCode ?? "",
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF15803D),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _redeemedStatus == 'rewarded'
                        ? 'تم صرف المكافأة الترحيبية (${_redeemedWelcomeBonus.toStringAsFixed(0)} ج.م) وإيداعها في محفظتك بنجاح ✅'
                        : 'ستحصل على رصيدك الترحيبي الإضافي (${_redeemedWelcomeBonus > 0 ? "${_redeemedWelcomeBonus.toStringAsFixed(0)} ج.م" : "فوري"}) فور إتمام أول رحلة بنجاح 🚗✨',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: const Color(0xFF166534),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Input Form Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.mediumBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_offer_rounded, color: AppColors.mediumBlue, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'هل دعاك صديق أو تملك برومو كود؟',
                              style: GoogleFonts.cairo(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'أدخل الكود لتفعيل رصيدك الترحيبي في محفظتك',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Text Field
                  TextField(
                    controller: _promoController,
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'اكتب الكود هنا (مثال: IN1234)',
                      hintStyle: GoogleFonts.cairo(
                        fontSize: 13.5,
                        letterSpacing: 0,
                        color: AppColors.textLight,
                      ),
                      prefixIcon: const Icon(Icons.confirmation_number_outlined, color: AppColors.mediumBlue, size: 20),
                      suffixIcon: _promoController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => setState(() => _promoController.clear()),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.mediumBlue, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (val) => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // High-Contrast Branded Blue Submit Button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isApplyingPromo ? null : _applyPromoCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mediumBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isApplyingPromo
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'تطبيق الكود وتأكيد المكافأة',
                                  style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Notes
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.mediumBlue, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'ملاحظات هامة حول البرومو كود',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• يمكنك تفعيل كود دعوة واحد فقط لكل حساب.\n'
                  '• تُصرف المكافأة الترحيبية فور إتمام رحلتك الأولى بنجاح.\n'
                  '• الخدمة متاحة داخل مدينة السادات والمناطق المعتمدة.',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ===========================================================================
  // BRANDED REUSABLE WIDGETS (Matching inRide Design Language)
  // ===========================================================================

  Widget _buildBrandedEarningsBanner(double referralReward) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إجمالي أرباحك من الدعوات',
                    style: GoogleFonts.cairo(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  Text(
                    '${_totalEarned.toStringAsFixed(2)} ج.م',
                    style: GoogleFonts.cairo(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Color(0xFFFDE047), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '+${referralReward.toStringAsFixed(0)} ج.م / دعوة',
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBannerMiniStat('الأصدقاء المسجلين', '$_totalInvites'),
                Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.2)),
                _buildBannerMiniStat('الرحلات المكتملة', '$_completedInvites'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerMiniStat(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.cairo(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildRewardRatesRow() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_car_rounded, color: AppColors.mediumBlue, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'دعوة كابتن',
                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '+${_driverReferralBonus.toStringAsFixed(0)} ج.م',
                  style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
                ),
                Text(
                  '(ترحيب: ${_driverWelcomeBonus.toStringAsFixed(0)} ج.م)',
                  style: GoogleFonts.cairo(fontSize: 10.5, color: AppColors.textLight),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_rounded, color: AppColors.mediumBlue, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'دعوة راكب',
                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '+${_riderReferralBonus.toStringAsFixed(0)} ج.م',
                  style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
                ),
                Text(
                  '(ترحيب: ${_riderWelcomeBonus.toStringAsFixed(0)} ج.م)',
                  style: GoogleFonts.cairo(fontSize: 10.5, color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBonusShiftsScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: AppColors.mediumBlue, size: 18),
              const SizedBox(width: 6),
              Text(
                'فترات بونص مدينة السادات',
                style: GoogleFonts.cairo(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildShiftRow(name: 'فترة الصباح ☀️', time: '07:00 ص - 11:59 ص', bonus: '+40 ج.م', isActive: false),
          const Divider(height: 14),
          _buildShiftRow(name: 'فترة المساء 🌆', time: '06:00 م - 11:59 م', bonus: '+60 ج.م', isActive: true),
          const Divider(height: 14),
          _buildShiftRow(name: 'فترة السهرة 🌙', time: '12:00 ص - 04:00 ص', bonus: '+50 ج.م', isActive: false),
        ],
      ),
    );
  }

  Widget _buildShiftRow({
    required String name,
    required String time,
    required String bonus,
    required bool isActive,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  name,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'نشط الآن',
                      style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF166534)),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              time,
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textLight),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            bonus,
            style: GoogleFonts.cairo(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF92400E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHowItWorksCard({
    required String title,
    required List<Map<String, dynamic>> steps,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded, color: AppColors.mediumBlue, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final step = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$idx',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mediumBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['title'] as String,
                          style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          step['desc'] as String,
                          style: GoogleFonts.cairo(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
