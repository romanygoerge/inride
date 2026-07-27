import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/repositories/auth_repository.dart';

class LinkPhonePage extends StatefulWidget {
  const LinkPhonePage({super.key});

  @override
  State<LinkPhonePage> createState() => _LinkPhonePageState();
}

class _LinkPhonePageState extends State<LinkPhonePage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  bool _isOtpSent = false;
  bool _isLoading = false;
  String _fullPhoneNumber = '';
  int _secondsRemaining = 45;
  Timer? _timer;
  bool _isGoogleUser = false;

  @override
  void initState() {
    super.initState();
    _checkGoogleUser();
  }

  void _checkGoogleUser() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      if (user.appMetadata['provider'] == 'google' || (user.identities?.any((i) => i.provider == 'google') ?? false)) {
        setState(() {
          _isGoogleUser = true;
        });
      }
    }
  }

  void _savePhoneWithoutVerification() async {
    if (_phoneFormKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      String rawPhone = _phoneController.text.trim().replaceAll(RegExp(r'\s+|-'), '');
      if (rawPhone.startsWith('0')) {
        rawPhone = rawPhone.substring(1);
      }
      _fullPhoneNumber = '+20$rawPhone';

      try {
        final state = GlobalState.instance;
        state.phoneNumber = _fullPhoneNumber;
        if (state.userUid != null) {
          await Supabase.instance.client.from('users').update({
            'phone_number': _fullPhoneNumber,
          }).eq('id', state.userUid!);
        }
        state.update();
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showSnackBar('حدث خطأ في حفظ رقم الهاتف: $e', isError: true);
        }
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = 45;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _timer?.cancel();
          }
        });
      }
    });
  }

  void _sendVerificationCode() async {
    if (_phoneFormKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      String rawPhone = _phoneController.text.trim().replaceAll(RegExp(r'\s+|-'), '');
      if (rawPhone.startsWith('0')) {
        rawPhone = rawPhone.substring(1);
      }
      _fullPhoneNumber = '+20$rawPhone';

      try {
        await AuthRepository.instance.signInWithPhone(
          phoneNumber: _fullPhoneNumber,
          onCodeSent: (verificationId, resendToken) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isOtpSent = true;
              });
              _startTimer();
            }
          },
          onVerificationFailed: (e) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              _showSnackBar('حدث خطأ في الإرسال: ${e.toString()}', isError: true);
            }
          },
          onVerificationCompleted: (credential) async {},
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showSnackBar('حدث خطأ غير متوقع: $e', isError: true);
        }
      }
    }
  }

  void _verifyOtp(String smsCode) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await AuthRepository.instance.verifyOTP(
        verificationId: _fullPhoneNumber,
        smsCode: smsCode,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('كود التحقق غير صحيح، يرجى المحاولة مرة أخرى.', isError: true);
      }
    }
  }

  void _onVerifyPressed() {
    if (_otpFormKey.currentState!.validate()) {
      _verifyOtp(_otpController.text.trim());
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.cairo(fontSize: 13, height: 1.5),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.mediumBlue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () {
            GlobalState.instance.reset();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isOtpSent ? _buildOtpForm() : _buildPhoneForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneForm() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Text(
            'ربط رقم الهاتف',
            style: GoogleFonts.cairo(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'يرجى تأكيد رقم الهاتف الخاص بك لإنشاء حسابك وتأمين الرحلات.',
            style: GoogleFonts.cairo(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'رقم الهاتف',
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Text('🇪🇬', style: GoogleFonts.cairo(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      '+20',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى إدخال رقم الهاتف';
                      }
                      if (value.startsWith('0')) {
                        return 'الرجاء كتابة الرقم بدون صفر البداية';
                      }
                      if (value.length < 10) {
                        return 'رقم الهاتف غير صالح';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: '10 1234 5678',
                      fillColor: AppColors.background,
                      filled: true,
                      prefixIcon: const Icon(Icons.phone_iphone_outlined, color: AppColors.textLight),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.mediumBlue, width: 2),
                      ),
                    ),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: AppColors.blueGradient,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mediumBlue.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading 
                  ? null 
                  : (_isGoogleUser ? _savePhoneWithoutVerification : _sendVerificationCode),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      _isGoogleUser ? 'تأكيد رقم الهاتف' : 'أرسل رمز التحقق',
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
    );
  }

  Widget _buildOtpForm() {
    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Text(
            'رمز التحقق',
            style: GoogleFonts.cairo(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'تم إرسال كود التحقق إلى الرقم $_fullPhoneNumber. يرجى إدخال الكود المكون من 6 أرقام للمتابعة.',
            style: GoogleFonts.cairo(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال كود التحقق';
              }
              if (value.length < 6) {
                return 'الكود يجب أن يتكون من 6 أرقام';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: '• • • • • •',
              fillColor: AppColors.background,
              filled: true,
              hintStyle: GoogleFonts.outfit(fontSize: 24, letterSpacing: 8, color: AppColors.textLight),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.mediumBlue, width: 2),
              ),
            ),
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'لم يصلك الرمز؟ ',
                style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 14),
              ),
              GestureDetector(
                onTap: _secondsRemaining > 0 ? null : _sendVerificationCode,
                child: Text(
                  _secondsRemaining > 0 ? 'إعادة الإرسال بعد $_secondsRemaining ثانية' : 'إعادة إرسال الرمز',
                  style: GoogleFonts.cairo(
                    color: _secondsRemaining > 0 ? AppColors.textLight : AppColors.mediumBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: AppColors.blueGradient,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mediumBlue.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _onVerifyPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'تأكيد وربط الحساب',
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
    );
  }
}
