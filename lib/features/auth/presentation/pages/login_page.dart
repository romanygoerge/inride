import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/utils/auth_error_handler.dart';
import '../../../../core/services/phone_auth_service.dart';
import 'otp_page.dart';
import 'passenger_profile_setup_page.dart';
import '../../../../features/passenger/presentation/pages/passenger_home_page.dart';
import '../../../../features/driver_registration/presentation/pages/doc_upload_page.dart';
import '../../../../features/driver_registration/presentation/pages/review_pending_page.dart';
import '../../../../features/driver/presentation/pages/driver_home_page.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../features/common/legal_pages.dart';
import '../../../../core/utils/snappy_page_route.dart';
import '../../../../generated/app_localizations.dart';
import '../../../../core/localization/locale_controller.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  UserRole _selectedRole = UserRole.rider;
  bool _isLoading = false;
  bool _isPhoneLoading = false;

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
    if (_isPhoneLoading || _isLoading) return;

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

  void _onGoogleSignInPressed() async {
    if (_isLoading || _isPhoneLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final state = GlobalState.instance;
      await state.loginWithGoogle(role: _selectedRole);
      
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _navigateToNextScreen();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (e.toString().contains('ERROR_ABORTED_BY_USER') || e.toString().contains('canceled')) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthErrorHandler.getErrorMessage(e), style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _navigateToNextScreen() {
    final state = GlobalState.instance;
    if (state.currentRole == UserRole.rider) {
      Widget targetPage;
      if (!state.hasPassengerProfile) {
        targetPage = const PassengerProfileSetupPage();
      } else {
        targetPage = const PassengerHomePage();
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => targetPage),
        (route) => false,
      );
    } else {
      Widget targetPage;
      if (state.verificationStatus == DriverVerificationStatus.unregistered) {
        targetPage = const DocUploadPage();
      } else if (state.verificationStatus == DriverVerificationStatus.submitted) {
        targetPage = const ReviewPendingPage();
      } else {
        targetPage = const DriverHomePage();
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => targetPage),
        (route) => false,
      );
    }
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
                          onPressed: (_isPhoneLoading || _isLoading) ? null : _onSendWhatsAppOtpPressed,
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

                const SizedBox(height: 24),

                // Separator (OR)
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      child: Text(
                        l10n.orSeparator,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                  ],
                ),

                const SizedBox(height: 24),

                // Google Sign-In Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _onGoogleSignInPressed,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: AppColors.mediumBlue,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                                height: 22,
                                width: 22,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.g_mobiledata_outlined,
                                  color: Colors.redAccent,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                l10n.loginWithGoogle,
                                style: GoogleFonts.cairo(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 14),

                // Instant Demo Passenger Mode Entry Button
                OutlinedButton.icon(
                  onPressed: () {
                    final state = GlobalState.instance;
                    state.currentRole = UserRole.rider;
                    state.passengerName = 'راكب تجريبي';
                    state.userName = 'راكب تجريبي';
                    state.update();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const PassengerHomePage()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.flash_on_rounded, color: AppColors.mediumBlue, size: 20),
                  label: Text(
                    LocaleController.instance.isArabic ? 'تصفح وضع الراكب / المحفظة والشحن 💳' : 'Explore Passenger Mode & Wallet 💳',
                    style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.mediumBlue),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: AppColors.mediumBlue, width: 1.5),
                  ),
                ),

                const SizedBox(height: 16),

                const SizedBox(height: 24),
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

