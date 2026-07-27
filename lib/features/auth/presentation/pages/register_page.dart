import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/utils/auth_error_handler.dart';
import 'passenger_profile_setup_page.dart';
import '../../../../features/passenger/presentation/pages/passenger_home_page.dart';
import '../../../../features/driver_registration/presentation/pages/doc_upload_page.dart';
import '../../../../features/driver_registration/presentation/pages/review_pending_page.dart';
import '../../../../features/driver/presentation/pages/driver_home_page.dart';
import 'package:flutter/gestures.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  UserRole _selectedRole = UserRole.rider;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedRole = GlobalState.instance.currentRole;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onEmailSignUpPressed() async {
    if (_isLoading) return;
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      setState(() {
        _isLoading = true;
      });

      try {
        final state = GlobalState.instance;
        await state.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          role: _selectedRole,
        );

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AuthErrorHandler.getErrorMessage(e), style: GoogleFonts.cairo()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _onGoogleSignUpPressed() async {
    if (_isLoading) return;
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
                          'سائق / كابتن',
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
                          'راكب / Passenger',
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'إنشاء حساب جديد',
                style: GoogleFonts.cairo(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'انضم إلى إن رايد وسجل بياناتك للبدء فوراً',
                style: GoogleFonts.cairo(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Role Selector
              _buildRoleSelector(),
              const SizedBox(height: 24),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'الاسم الكامل',
                        prefixIcon: const Icon(Icons.person_outline, color: AppColors.mediumBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'يرجى إدخال الاسم الكامل';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        hintText: 'example@gmail.com',
                        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.mediumBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                          return 'صيغة البريد الإلكتروني غير صحيحة';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.mediumBlue),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textSecondary),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'يرجى إدخال كلمة المرور';
                        if (val.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'تأكيد كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_clock_outlined, color: AppColors.mediumBlue),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textSecondary),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'يرجى تأكيد كلمة المرور';
                        if (val != _passwordController.text) return 'كلمتا المرور غير متطابقتين';
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _onEmailSignUpPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mediumBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text('إنشاء الحساب', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('أو التسجيل بواسطة', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),

              OutlinedButton(
                onPressed: _isLoading ? null : _onGoogleSignUpPressed,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.g_mobiledata_outlined, color: Colors.redAccent, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'التسجيل باستخدام Google',
                      style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Center(
                child: RichText(
                  text: TextSpan(
                    text: 'لديك حساب بالفعل؟ ',
                    style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondary),
                    children: [
                      TextSpan(
                        text: 'تسجيل الدخول',
                        style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.mediumBlue),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.pop(context);
                          },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
