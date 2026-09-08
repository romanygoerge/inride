import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/utils/auth_error_handler.dart';
import '../../../../core/services/phone_auth_service.dart';
import 'otp_page.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../features/common/legal_pages.dart';
import '../../../../core/utils/snappy_page_route.dart';
import '../../../../generated/app_localizations.dart';
import '../../../../features/driver/presentation/pages/driver_home_page.dart';
import '../../../../features/passenger/presentation/pages/passenger_home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  UserRole _selectedRole = UserRole.rider;
  bool _isPhoneLoading = false;
  bool _isDemoLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = GlobalState.instance.currentRole;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onSendWhatsAppOtpPressed() async {
    if (_isPhoneLoading) return;

    final rawInput = _phoneController.text.trim();
    final l10n = AppLocalizations.of(context)!;
    if (rawInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.enterPhonePrompt, style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Clean and validate the phone number
    // The prefix +20 is shown in the UI — user enters the rest (e.g., 1012345678)
    // We build the full local number: if user typed without leading 0, add it.
    String cleaned = rawInput.replaceAll(RegExp(r'[^\d]'), '');
    // If user typed 10 digits starting with 1 (e.g., 1012345678), prepend 0
    if (cleaned.length == 10 && cleaned.startsWith('1')) {
      cleaned = '0$cleaned';
    }
    // Now cleaned should be 11 digits starting with 01
    if (cleaned.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.invalidPhoneFormat, style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    debugPrint('[LoginPage] ▶ Sending WhatsApp OTP to: $cleaned (raw input: $rawInput)');

    final messenger = ScaffoldMessenger.of(context);
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isPhoneLoading = true;
    });

    try {
      final state = GlobalState.instance;
      state.selectRole(_selectedRole);

      await PhoneAuthService.instance.sendOtp(phoneNumber: cleaned);
      final latestOtp = PhoneAuthService.instance.getLatestOtp(cleaned);

      debugPrint('[LoginPage] ✓ OTP sent — navigating to OtpPage for: $cleaned (code: $latestOtp)');

      if (!mounted) return;
      setState(() {
        _isPhoneLoading = false;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.otpSent,
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );

      // Pass the cleaned local phone number to OtpPage.
      // PhoneAuthService will convert it to E.164 for Supabase internally.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpPage(
            phoneNumber: cleaned,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[LoginPage] ✗ sendOtp failed: $e');
      if (!mounted) return;
      setState(() {
        _isPhoneLoading = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(AuthErrorHandler.getErrorMessage(e), style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _onQuickDemoLoginPressed() async {
    if (_isDemoLoading || _isPhoneLoading) return;

    setState(() {
      _isDemoLoading = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final targetRole = _selectedRole;
    final isDriver = targetRole == UserRole.driver;

    try {
      await GlobalState.instance.loginAsDemo(role: targetRole);

      if (!mounted) return;
      setState(() {
        _isDemoLoading = false;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isDriver
                ? '✅ تم الدخول الفوري بحساب كابتن تجريبي (معتمد ومفعل بالكامل)!'
                : '✅ تم الدخول الفوري بحساب راكب تجريبي بنجاح!',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );

      final targetPage = isDriver ? const DriverHomePage() : const PassengerHomePage();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => targetPage),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDemoLoading = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('فشل الدخول بالحساب التجريبي: ${AuthErrorHandler.getErrorMessage(e)}', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildDemoLoginSection() {
    final isDriver = _selectedRole == UserRole.driver;
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF86EFAC)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flash_on_rounded, color: Color(0xFF16A34A), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'وضع الحساب التجريبي الفوري (Demo Mode)',
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                    Text(
                      isDriver
                          ? 'دخول فوري ككابتن معتمد مباشرة (بدون مراجعة أو كود)'
                          : 'دخول فوري كراكب لتجربة طلب وتتبع الرحلات',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: const Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: (_isDemoLoading || _isPhoneLoading) ? null : _onQuickDemoLoginPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isDemoLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isDriver ? Icons.directions_car : Icons.person_pin_circle,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isDriver ? 'دخول فوري ككابتن تجريبي 🚀' : 'دخول فوري كراكب تجريبي 🚀',
                        style: GoogleFonts.cairo(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: _selectedRole == UserRole.rider ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.blueGradient),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.mediumBlue.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRole = UserRole.driver;
                    });
                    GlobalState.instance.selectRole(UserRole.driver);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions_car_outlined,
                          size: 18,
                          color: _selectedRole == UserRole.driver ? Colors.white : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppLocalizations.of(context)?.driverRole ?? 'سائق / كابتن',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _selectedRole == UserRole.driver ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRole = UserRole.rider;
                    });
                    GlobalState.instance.selectRole(UserRole.rider);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_pin_circle_outlined,
                          size: 18,
                          color: _selectedRole == UserRole.rider ? Colors.white : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppLocalizations.of(context)?.passengerRole ?? 'راكب / Passenger',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _selectedRole == UserRole.rider ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Title Header
                Center(
                  child: Column(
                    children: [
                      const AppLogo(
                        size: 100,
                        isCircle: true,
                        padding: EdgeInsets.all(16),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'inRide',
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.welcomeMessage,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Role Selector Label
                Text(
                  l10n.authTitle,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                _buildRoleSelector(),
                const SizedBox(height: 32),

                // WhatsApp / Phone Sign-In Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            l10n.enterPhoneNumber,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: '1012345678',
                            hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
                            prefixIcon: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(
                                border: Border(right: BorderSide(color: AppColors.border)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '🇪🇬 +20',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.mediumBlue, width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Send WhatsApp Code Button
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF25D366).withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isPhoneLoading ? null : _onSendWhatsAppOtpPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isPhoneLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n.verifyOtp,
                                      style: GoogleFonts.cairo(
                                        fontSize: 14.5,
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

                ListenableBuilder(
                  listenable: GlobalState.instance,
                  builder: (context, _) {
                    final isDriver = _selectedRole == UserRole.driver;
                    final isEnabled = isDriver
                        ? GlobalState.instance.isDemoDriverEnabled
                        : GlobalState.instance.isDemoPassengerEnabled;
                    if (!isEnabled) {
                      return const SizedBox.shrink();
                    }
                    return _buildDemoLoginSection();
                  },
                ),

                const SizedBox(height: 32),
                // Footer with interactive legal links
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l10n.acceptTerms,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, SnappyPageRoute(page: const TermsOfUsePage()));
                      },
                      child: Text(
                        ' ${l10n.termsAndConditionsText}',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mediumBlue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Text(
                      ' & ',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, SnappyPageRoute(page: const PrivacyPolicyPage()));
                      },
                      child: Text(
                        l10n.privacyPolicyText,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mediumBlue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

