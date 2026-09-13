import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/utils/auth_error_handler.dart';
import '../../../../core/services/phone_auth_service.dart';
import 'package:inride_app/features/driver_registration/presentation/pages/doc_upload_page.dart';
import 'package:inride_app/features/driver_registration/presentation/pages/review_pending_page.dart';
import 'package:inride_app/features/driver/presentation/pages/driver_home_page.dart';
import 'package:inride_app/features/passenger/presentation/pages/passenger_home_page.dart';
import '../../../../generated/app_localizations.dart';
import 'passenger_profile_setup_page.dart';

class OtpPage extends StatefulWidget {
  final String phoneNumber;
  final String? verificationId;
  const OtpPage({super.key, required this.phoneNumber, this.verificationId});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> with WidgetsBindingObserver {
  final TextEditingController _otpController = TextEditingController();
  String _otp = '';
  int _secondsRemaining = 45;
  Timer? _timer;
  String? _lastProcessedClipboard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    _autoFillFromClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _autoFillFromClipboard();
    }
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

  void _navigateToNextScreen() {
    final state = GlobalState.instance;
    final isDemo = widget.phoneNumber.replaceAll(RegExp(r'[^\d]'), '').endsWith('000000000');

    if (state.currentRole == UserRole.rider) {
      Widget targetPage;
      if (!state.hasPassengerProfile && !isDemo) {
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
      if (isDemo || state.verificationStatus == DriverVerificationStatus.verified) {
        targetPage = const DriverHomePage();
      } else if (state.verificationStatus == DriverVerificationStatus.submitted) {
        targetPage = const ReviewPendingPage();
      } else {
        targetPage = const DocUploadPage();
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => targetPage),
        (route) => false,
      );
    }
  }

  void _onConfirmPressed() async {
    final l10n = AppLocalizations.of(context)!;
    if (_otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.enterOtpCode,
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: AppColors.mediumBlue)),
    );

    try {
      final state = GlobalState.instance;
      final targetPhone = widget.phoneNumber;

      if (targetPhone.isEmpty) {
        throw Exception(l10n.invalidPhoneFormat);
      }

      await state.loginWithOTP(
        verificationId: targetPhone,
        smsCode: _otp,
        role: state.currentRole,
        phoneNumber: widget.phoneNumber,
      );

      if (!mounted) return;
      Navigator.pop(context); // Pop loading dialog

      _navigateToNextScreen();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Pop loading dialog

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
    final l10n = AppLocalizations.of(context)!;
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
                          l10n.verifyOtp,
                          style: GoogleFonts.cairo(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${l10n.otpSent}\n${widget.phoneNumber}',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),

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

                        // Tip message under the OTP input boxes
                        _buildPasteTipWidget(),
                        const SizedBox(height: 24),

                        // Timer / Resend Code
                        Center(
                          child: _secondsRemaining > 0
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      l10n.resendCodeTimer(_secondsRemaining),
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
                                    try {
                                       await PhoneAuthService.instance
                                           .sendOtp(phoneNumber: widget.phoneNumber);
                                       if (!mounted) return;
                                       messenger.showSnackBar(
                                         SnackBar(
                                           content: Text(
                                             l10n.otpSent,
                                             style: GoogleFonts.cairo(),
                                           ),
                                           backgroundColor: AppColors.mediumBlue,
                                           duration: const Duration(seconds: 4),
                                         ),
                                       );
                                    } catch (e) {
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
                                    l10n.resendCode,
                                    style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.mediumBlue,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),

                        // WhatsApp Quick Support Actions
                        _buildWhatsAppSupportSection(),
                        const SizedBox(height: 32),

                        // Confirm button
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
                              l10n.confirm,
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

  /// Helpful message under the OTP input boxes
  Widget _buildPasteTipWidget() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.mediumBlue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'لو الرمز اللي بتدخله خاطئ، تأكد من كتابة رمز التحقق المكون من 6 أرقام كما وصلك',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Smartly extracts a 6-digit OTP code from any copied WhatsApp message,
  /// ignoring timestamps (12:30), dates (2026), phone numbers (010xxxxxxxx), and Arabic text.
  static String? extractOtpCode(String text) {
    if (text.trim().isEmpty) return null;

    // 1. Normalize Eastern Arabic (Hindi) numerals (٠-٩) to standard English digits (0-9)
    String normalized = text;
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < 10; i++) {
      normalized = normalized.replaceAll(arabicDigits[i], '$i');
    }

    // 2. High-priority contextual pattern: 6 digits directly following keywords
    // E.g. "رمز التحقق الخاص بك في تطبيق inRide هو: 582914" or "code: 582914"
    final contextualRegex = RegExp(
      r'(?:رمز|كود|تحقق|تأكيد|هو|code|otp|inride)[\s:=-]*(\d{6})(?!\d)',
      caseSensitive: false,
    );
    final contextualMatch = contextualRegex.firstMatch(normalized);
    if (contextualMatch != null && contextualMatch.groupCount >= 1) {
      return contextualMatch.group(1);
    }

    // 3. Strict standalone 6-digit pattern: exactly 6 digits not surrounded by other digits
    // - Filters out 11-digit phone numbers (e.g. 01012345678)
    // - Filters out 4-digit years (e.g. 2026)
    // - Filters out 1-2 digit minutes/hours (e.g. 12:30, 5 دقائق)
    final standaloneRegex = RegExp(r'(?<!\d)(\d{6})(?!\d)');
    final matches = standaloneRegex.allMatches(normalized).map((m) => m.group(1)!).toList();
    if (matches.isNotEmpty) {
      return matches.first;
    }

    // 4. Raw digits fallback: if clipboard has only 6 digits
    final onlyDigits = normalized.replaceAll(RegExp(r'[^\d]'), '');
    if (onlyDigits.length == 6) {
      return onlyDigits;
    }

    return null;
  }

  /// Automatically checks clipboard for 6-digit OTP when returning from WhatsApp or notification
  Future<void> _autoFillFromClipboard() async {
    if (_otp.length == 6) return;

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty || text == _lastProcessedClipboard) return;

      final code = extractOtpCode(text);

      if (code != null && code.length == 6 && mounted) {
        _lastProcessedClipboard = text;
        setState(() {
          _otpController.text = code;
          _otp = code;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تم التعرف على رمز التحقق تلقائياً ($code)',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        _onConfirmPressed();
      }
    } catch (_) {}
  }

  /// WhatsApp Quick Support Actions ("الرمز لم يصل" & "لما بسجل الرمز بيقولي خطأ")
  Widget _buildWhatsAppSupportSection() {
    return ListenableBuilder(
      listenable: GlobalState.instance,
      builder: (context, _) {
        final whatsappNumber = GlobalState.instance.otpSupportWhatsApp;

        return Container(
          margin: const EdgeInsets.only(top: 8),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildWhatsAppActionChip(
                text: 'الرمز لم يصل',
                icon: FontAwesomeIcons.whatsapp,
                whatsappNumber: whatsappNumber,
                message: 'الرمز لم يصل\nرقم الهاتف: ${widget.phoneNumber}',
                color: const Color(0xFF16A34A),
                bgColor: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFBBF7D0),
              ),
              _buildWhatsAppActionChip(
                text: 'لما بسجل الرمز بيقولي خطأ',
                icon: FontAwesomeIcons.whatsapp,
                whatsappNumber: whatsappNumber,
                message: 'لما بسجل الرمز بيقولي خطأ\nرقم الهاتف: ${widget.phoneNumber}',
                color: const Color(0xFFEA580C),
                bgColor: const Color(0xFFFFF7ED),
                borderColor: const Color(0xFFFED7AA),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWhatsAppActionChip({
    required String text,
    required IconData icon,
    required String whatsappNumber,
    required String message,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return InkWell(
      onTap: () => _openWhatsApp(phone: whatsappNumber, message: message),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              text,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWhatsApp({required String phone, required String message}) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '2$cleanPhone';
    } else if (!cleanPhone.startsWith('20') && cleanPhone.length == 10) {
      cleanPhone = '20$cleanPhone';
    }

    final encodedMessage = Uri.encodeComponent(message);
    final appUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMessage');
    final webUri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح تطبيق واتساب ($cleanPhone)', style: GoogleFonts.cairo()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

