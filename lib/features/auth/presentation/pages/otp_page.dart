import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/utils/auth_error_handler.dart';
import '../../../../core/services/phone_auth_service.dart';
import 'package:inride_app/features/driver_registration/presentation/pages/doc_upload_page.dart';
import 'package:inride_app/features/driver_registration/presentation/pages/review_pending_page.dart';
import 'package:inride_app/features/driver/presentation/pages/driver_home_page.dart';
import 'package:inride_app/features/passenger/presentation/pages/passenger_home_page.dart';
import 'passenger_profile_setup_page.dart';

class OtpPage extends StatefulWidget {
  final String phoneNumber;
  final String? verificationId;
  const OtpPage({super.key, required this.phoneNumber, this.verificationId});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController _otpController = TextEditingController();
  String _otp = '';
  int _secondsRemaining = 45;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = 45;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  /// Navigate to the appropriate next screen ONLY after successful OTP verification.
  /// This method is ONLY called after Supabase returns a valid session + user.
  void _navigateToNextScreen() {
    final state = GlobalState.instance;
    debugPrint('[OtpPage] ▶ _navigateToNextScreen — role: ${state.currentRole}, passengerName: ${state.passengerName}');

    if (state.currentRole == UserRole.rider) {
      Widget targetPage;
      if (!state.hasPassengerProfile) {
        debugPrint('[OtpPage] → Navigating to PassengerProfileSetupPage (new user)');
        targetPage = const PassengerProfileSetupPage();
      } else {
        debugPrint('[OtpPage] → Navigating to PassengerHomePage (existing user)');
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
        debugPrint('[OtpPage] → Navigating to DocUploadPage (unregistered driver)');
        targetPage = const DocUploadPage();
      } else if (state.verificationStatus == DriverVerificationStatus.submitted) {
        debugPrint('[OtpPage] → Navigating to ReviewPendingPage (submitted driver)');
        targetPage = const ReviewPendingPage();
      } else {
        debugPrint('[OtpPage] → Navigating to DriverHomePage (verified driver)');
        targetPage = const DriverHomePage();
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => targetPage),
        (route) => false,
      );
    }
  }

  void _onConfirmPressed() async {
    if (_otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى إدخال كود التحقق المكون من 6 أرقام',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: AppColors.mediumBlue)),
    );

    try {
      final state = GlobalState.instance;

      // Use the phone number passed to this page as verificationId.
      // PhoneAuthService will format it to E.164 internally.
      final targetPhone = widget.phoneNumber;

      debugPrint('[OtpPage] ▶ Submitting OTP for phone: $targetPhone, token: $_otp');

      if (targetPhone.isEmpty) {
        throw Exception('رقم الهاتف غير صالح، يرجى إعادة المحاولة.');
      }

      // SECURITY: loginWithOTP will throw an Exception if:
      //   - The OTP code is wrong
      //   - Supabase returns no session
      //   - Any other auth failure
      // It will NOT silently succeed. Navigation happens ONLY on success.
      await state.loginWithOTP(
        verificationId: targetPhone,
        smsCode: _otp,
        role: state.currentRole,
        phoneNumber: widget.phoneNumber,
      );

      debugPrint('[OtpPage] ✓ OTP verification succeeded — proceeding to next screen');

      if (!mounted) return;
      Navigator.pop(context); // Pop loading dialog

      // ONLY navigate after confirmed successful OTP verification
      _navigateToNextScreen();
    } catch (e) {
      debugPrint('[OtpPage] ✗ OTP verification failed: $e');

      if (!mounted) return;
      Navigator.pop(context); // Pop loading dialog

      // Show clear error message — user stays on OTP screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AuthErrorHandler.getErrorMessage(e),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );

      // Clear the entered OTP so user can try again
      setState(() {
        _otp = '';
        _otpController.clear();
      });
    }
  }

  Widget _buildPinRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        String char = '';
        if (_otp.length > index) {
          char = _otp[index];
        }
        final isCurrent = _otp.length == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 56,
          decoration: BoxDecoration(
            color: isCurrent ? Colors.white : AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrent ? AppColors.mediumBlue : AppColors.border,
              width: isCurrent ? 2.2 : 1.0,
            ),
            boxShadow: [
              if (isCurrent)
                BoxShadow(
                  color: AppColors.mediumBlue.withValues(alpha: 0.12),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.01),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            char,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedTime = '00:${_secondsRemaining.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 16),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative background blobs
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.mediumBlue.withValues(alpha: 0.02),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          'تأكيد رقم الهاتف',
                          style: GoogleFonts.cairo(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'تم إرسال كود التحقق إلى حسابك على الواتساب\n${widget.phoneNumber}',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),

                        // Styled PIN input utilizing Stack and transparent TextField
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            _buildPinRow(),
                            Opacity(
                              opacity: 0.0,
                              child: TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                decoration: const InputDecoration(
                                  counterText: '',
                                ),
                                style: const TextStyle(fontSize: 24),
                                onChanged: (val) {
                                  setState(() {
                                    _otp = val;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),

                        // Timer / Resend Code
                        Center(
                          child: _secondsRemaining > 0
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'إعادة إرسال الكود خلال ',
                                      style: GoogleFonts.cairo(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      formattedTime,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.mediumBlue,
                                      ),
                                    ),
                                  ],
                                )
                              : TextButton(
                                  onPressed: () async {
                                    _startTimer();
                                    final messenger = ScaffoldMessenger.of(context);
                                    debugPrint('[OtpPage] ▶ Resending OTP for ${widget.phoneNumber}');
                                    try {
                                       await PhoneAuthService.instance
                                           .sendOtp(phoneNumber: widget.phoneNumber);
                                       final latestOtp = PhoneAuthService.instance.getLatestOtp(widget.phoneNumber);
                                       debugPrint('[OtpPage] ✓ OTP resent successfully (code: $latestOtp)');
                                       if (!mounted) return;
                                       messenger.showSnackBar(
                                         SnackBar(
                                           content: Text(
                                             'تم إعادة إرسال كود التحقق عبر الواتساب',
                                             style: GoogleFonts.cairo(),
                                           ),
                                           backgroundColor: AppColors.mediumBlue,
                                           duration: const Duration(seconds: 4),
                                         ),
                                       );
                                    } catch (e) {
                                      debugPrint('[OtpPage] ✗ Resend OTP failed: $e');
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            AuthErrorHandler.getErrorMessage(e),
                                            style: GoogleFonts.cairo(),
                                          ),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    'إعادة إرسال الكود عبر الواتساب',
                                    style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.mediumBlue,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 48),

                        // Confirm button with Blue Gradient & Shadow
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: AppColors.blueGradient,
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.mediumBlue.withValues(alpha: 0.3),
                                blurRadius: 16,
                                spreadRadius: 1,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _onConfirmPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'تأكيد',
                              style: GoogleFonts.cairo(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
