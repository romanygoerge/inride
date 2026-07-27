import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error == null) return 'حدث خطأ غير معروف، يرجى المحاولة لاحقاً.';

    if (error is SocketException) {
      return 'لا يوجد اتصال بالإنترنت. يرجى التحقق من الشبكة وإعادة المحاولة.';
    }

    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') || errorStr.contains('socketexception') || errorStr.contains('failed to host lookup')) {
      return 'تعذر الاتصال بالسيرفر. يرجى التأكد من الاتصال بالإنترنت.';
    }

    if (error is AuthException) {
      final message = error.message.toLowerCase();
      final code = error.statusCode;

      if (message.contains('invalid login credentials') || message.contains('invalid_credentials')) {
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      }
      if (message.contains('user already registered') || message.contains('user_already_exists')) {
        return 'هذا الحساب مسجل بالفعل، يرجى تسجيل الدخول.';
      }
      if (message.contains('email not confirmed')) {
        return 'البريد الإلكتروني غير مفعل، يرجى مراجعة بريدك الإلكتروني لتأكيده.';
      }
      if (message.contains('password should be at least')) {
        return 'كلمة المرور ضعيفة. يجب أن تتكون من 6 أحرف على الأقل.';
      }
      if (message.contains('invalid email')) {
        return 'البريد الإلكتروني غير صالح.';
      }
      if (message.contains('rate limit') || code == '429') {
        return 'تم تجاوز عدد المحاولات المسموح بها. يرجى الانتظار قليلاً ثم المحاولة لاحقاً.';
      }
      if (message.contains('token is expired') || message.contains('otp_expired')) {
        return 'رمز التحقق منتهي الصلاحية، يرجى طلب رمز جديد.';
      }
      if (message.contains('invalid otp') || message.contains('otp_invalid')) {
        return 'رمز التحقق غير صحيح.';
      }
      return error.message;
    }

    if (errorStr.contains('canceled') || errorStr.contains('aborted')) {
      return 'تم إلغاء العملية بواسطة المستخدم.';
    }

    return 'حدث خطأ: ${error.toString()}';
  }
}
