import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../localization/locale_controller.dart';

class AuthErrorHandler {
  static String getErrorMessage(dynamic error) {
    final isAr = LocaleController.instance.isArabic;
    if (error == null) {
      return isAr ? 'حدث خطأ غير معروف، يرجى المحاولة لاحقاً.' : 'An unknown error occurred, please try again later.';
    }

    if (error is SocketException) {
      return isAr
          ? 'لا يوجد اتصال بالإنترنت. يرجى التحقق من الشبكة وإعادة المحاولة.'
          : 'No internet connection. Please check your network and try again.';
    }

    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') || errorStr.contains('socketexception') || errorStr.contains('failed to host lookup')) {
      return isAr
          ? 'تعذر الاتصال بالسيرفر. يرجى التأكد من الاتصال بالإنترنت.'
          : 'Unable to connect to server. Please check internet connection.';
    }

    if (error is AuthException) {
      final message = error.message.toLowerCase();
      final code = error.statusCode;

      if (message.contains('invalid login credentials') || message.contains('invalid_credentials')) {
        return isAr ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة.' : 'Invalid login credentials.';
      }
      if (message.contains('user already registered') || message.contains('user_already_exists')) {
        return isAr ? 'هذا الحساب مسجل بالفعل، يرجى تسجيل الدخول.' : 'This account is already registered, please log in.';
      }
      if (message.contains('email not confirmed')) {
        return isAr ? 'البريد الإلكتروني غير مفعل، يرجى مراجعة بريدك الإلكتروني لتأكيده.' : 'Email not confirmed, please check your inbox.';
      }
      if (message.contains('password should be at least')) {
        return isAr ? 'كلمة المرور ضعيفة. يجب أن تتكون من 6 أحرف على الأقل.' : 'Password should be at least 6 characters.';
      }
      if (message.contains('invalid email')) {
        return isAr ? 'البريد الإلكتروني غير صالح.' : 'Invalid email address.';
      }
      if (message.contains('rate limit') || code == '429') {
        return isAr ? 'تم تجاوز عدد المحاولات المسموح بها. يرجى الانتظار قليلاً ثم المحاولة لاحقاً.' : 'Rate limit exceeded. Please wait and try again later.';
      }
      if (message.contains('token is expired') || message.contains('otp_expired')) {
        return isAr ? 'رمز التحقق منتهي الصلاحية، يرجى طلب رمز جديد.' : 'Verification code expired, please request a new one.';
      }
      if (message.contains('invalid otp') || message.contains('otp_invalid')) {
        return isAr ? 'رمز التحقق غير صحيح.' : 'Invalid verification code.';
      }
      return error.message;
    }

    if (errorStr.contains('canceled') || errorStr.contains('aborted')) {
      return isAr ? 'تم إلغاء العملية بواسطة المستخدم.' : 'Operation canceled by user.';
    }

    return isAr ? 'حدث خطأ: ${error.toString()}' : 'An error occurred: ${error.toString()}';
  }
}
