import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/utils/auth_error_handler.dart';

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => const ForgotPasswordDialog(),
    );
  }

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onResetPressed() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      setState(() {
        _isLoading = true;
      });

      try {
        await GlobalState.instance.resetPassword(
          email: _emailController.text.trim(),
        );

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني بنجاح.',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AuthErrorHandler.getErrorMessage(e),
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Text(
        'إعادة تعيين كلمة المرور',
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: AppColors.textPrimary,
        ),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'أدخل بريدك الإلكتروني وسيتم إرسال رابط لاستعادة كلمة المرور الخاص بحسابك.',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  labelStyle: GoogleFonts.cairo(fontSize: 13),
                  hintText: 'example@gmail.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.mediumBlue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'يرجى إدخال البريد الإلكتروني';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                    return 'البريد الإلكتروني غير صحيح';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(
            'إلغاء',
            style: GoogleFonts.cairo(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _onResetPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.mediumBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  'إرسال',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
                ),
        ),
      ],
    );
  }
}
