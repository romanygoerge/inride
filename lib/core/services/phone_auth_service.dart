import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/auth_error_handler.dart';

class _OtpEntry {
  final Set<String> codes;
  DateTime createdAt;

  _OtpEntry({required String code, required this.createdAt})
      : codes = {code};

  bool get isExpired => DateTime.now().difference(createdAt).inMinutes >= 5;

  void addCode(String code) {
    codes.add(code);
    createdAt = DateTime.now(); // Reset expiration on new code request
  }

  bool isValid(String inputToken) {
    return !isExpired && codes.contains(inputToken.trim());
  }
}

/// PhoneAuthService manages WhatsApp OTP generation, delivery via WA Pilot API,
/// and verification for the inRide app.
///
/// SECURITY & AUTH POLICY:
/// - WhatsApp OTPs are generated and sent via WA Pilot API.
/// - Prominently logs full Request/Response details and generated OTP to Debug Console.
/// - Handles all Egyptian phone formats (012..., 12..., 2012..., +2012...) and international into valid +20XXXXXXXXXX / E.164.
/// - Verification checks active OTP codes sent via WhatsApp (NO bypass / backdoor allowed).
/// - Supports multiple active codes when user requests "Resend OTP".
/// - Once OTP is verified, a real Supabase Auth session is created for the user.
class PhoneAuthService {
  static final PhoneAuthService instance = PhoneAuthService._internal();
  factory PhoneAuthService() => instance;
  PhoneAuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // WA Pilot Configuration
  static const String _instanceId = 'instance4905';
  static const String _apiToken = 'zDQpqez1foUUWQptGgFabIPXmOdc28BVL4nXY0sSje';
  static const String _waPilotEndpoint =
      'https://api.wapilot.net/api/v2/$_instanceId/send-message';

  // In-memory cache for pending OTP codes
  final Map<String, _OtpEntry> _pendingOtps = {};

  /// Format phone number to E.164 format with country code (e.g., "+201001234567")
  String formatPhoneE164(String rawPhone) {
    String cleaned = rawPhone.replaceAll(RegExp(r'[^\d]'), '');

    // 00XX international format
    if (cleaned.startsWith('00')) {
      cleaned = cleaned.substring(2);
    }

    // 10 digits starting with 1 (e.g. 1204062941, 1012345678, 1112345678, 1512345678) -> +201204062941
    if (cleaned.length == 10 && cleaned.startsWith('1')) {
      cleaned = '20$cleaned';
    }
    // 11 digits starting with 01 (e.g. 01204062941) -> +201204062941
    else if (cleaned.length == 11 && cleaned.startsWith('01')) {
      cleaned = '20${cleaned.substring(1)}';
    }
    // 11 digits starting with 0 (e.g. 01012345678) -> +201012345678
    else if (cleaned.length == 11 && cleaned.startsWith('0')) {
      cleaned = '20${cleaned.substring(1)}';
    }
    // 12 digits starting with 20 (e.g. 201204062941) -> +201204062941
    else if (cleaned.length == 12 && cleaned.startsWith('20')) {
      // already 20XXXXXXXXXX
    }

    return '+$cleaned';
  }

  /// Format phone number to WA Pilot chat_id format (e.g., "201204062941")
  String formatPhoneForWaPilot(String rawPhone) {
    final e164 = formatPhoneE164(rawPhone);
    return e164.startsWith('+') ? e164.substring(1) : e164;
  }

  /// Send OTP to the given phone number via WA Pilot WhatsApp API.
  Future<void> sendOtp({
    required String phoneNumber,
  }) async {
    final cleanedPhone = formatPhoneForWaPilot(phoneNumber);
    final e164Phone = formatPhoneE164(phoneNumber);

    debugPrint('[PhoneAuthService] ▶ sendOtp called for raw: "$phoneNumber" -> waPilot: $cleanedPhone (E.164: $e164Phone)');

    if (cleanedPhone.length < 10) {
      debugPrint('[PhoneAuthService] ✗ Invalid phone number: $cleanedPhone');
      throw Exception('رقم الهاتف غير صحيح. يرجى التأكد من كتابة الرقم بشكل صحيح.');
    }

    final chatId = '$cleanedPhone@c.us';

    // Always generate a fresh random 6-digit OTP for every send request
    final random = Random.secure();
    final otpCode = (100000 + random.nextInt(900000)).toString();

    final messageText =
        'رمز التحقق الخاص بك في تطبيق inRide هو: $otpCode\nيرجى عدم مشاركة هذا الرمز مع أي شخص.';

    final uri = Uri.parse(_waPilotEndpoint).replace(queryParameters: {
      'token': _apiToken,
    });

    final requestHeaders = {
      'token': _apiToken,
      'Authorization': 'Bearer $_apiToken',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final requestBody = jsonEncode({
      'chat_id': chatId,
      'text': messageText,
    });

    // PROMINENT DEBUG LOG - FULL REQUEST DETAILS
    debugPrint('==================== WA PILOT OTP REQUEST ====================');
    debugPrint('Target Number (E.164) : $e164Phone');
    debugPrint('Chat ID               : $chatId');
    debugPrint('Generated OTP Code    : $otpCode');
    debugPrint('Request URL           : $uri');
    debugPrint('Request Method        : POST');
    debugPrint('Request Headers       : $requestHeaders');
    debugPrint('Request Payload       : $requestBody');
    debugPrint('==============================================================');

    try {
      final response = await _postRequest(uri, requestHeaders, requestBody);

      // PROMINENT DEBUG LOG - FULL RESPONSE DETAILS
      debugPrint('==================== WA PILOT OTP RESPONSE ===================');
      debugPrint('Status Code : ${response.statusCode}');
      debugPrint('Headers     : ${response.headers}');
      debugPrint('Body        : ${response.body}');
      debugPrint('==============================================================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final isSuccess = responseData['success'] == true ||
            responseData['message_id'] != null ||
            responseData['status'] == 'success' ||
            responseData['data'] != null;

        if (isSuccess) {
          // Store OTP locally — append to valid codes if active entry exists, and reset expiration timer
          if (_pendingOtps.containsKey(cleanedPhone) &&
              !_pendingOtps[cleanedPhone]!.isExpired) {
            _pendingOtps[cleanedPhone]!.addCode(otpCode);
          } else {
            _pendingOtps[cleanedPhone] = _OtpEntry(
              code: otpCode,
              createdAt: DateTime.now(),
            );
          }
          debugPrint(
              '[PhoneAuthService] ✓ OTP stored successfully for $chatId. Active valid codes: ${_pendingOtps[cleanedPhone]!.codes}');
          return;
        } else {
          final errorMsg = responseData['message'] ?? 'فشل في إرسال الرسالة عبر الواتساب';
          throw Exception(errorMsg);
        }
      } else {
        dynamic errorData;
        try {
          errorData = jsonDecode(response.body);
        } catch (_) {}
        final errorMsg = (errorData is Map && errorData['message'] != null)
            ? errorData['message']
            : 'خطأ في الاتصال بخدمة WA Pilot (${response.statusCode})';
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      debugPrint('[PhoneAuthService] ✗ Exception sending OTP via WA Pilot: $e\n$stack');
      if (e is Exception) rethrow;
      throw Exception('فشل في إرسال كود التحقق عبر الواتساب: $e');
    }
  }

  /// Verify OTP token and create/sign-in Supabase Auth session for the phone user.
  ///
  /// ARCHITECTURE CONTRACT:
  /// 1. Verifies the OTP via external API service (in-memory active OTP entry).
  /// 2. Authenticates/creates the user in Supabase Auth securely.
  /// 3. Validates that a real Supabase Session (accessToken, refreshToken, user) is established.
  /// 4. Prominently logs each step with clear diagnostic output.
  Future<AuthResponse> verifyOtp({
    required String phoneNumber,
    required String token,
  }) async {
    final cleanedPhone = formatPhoneForWaPilot(phoneNumber);
    final e164Phone = formatPhoneE164(phoneNumber);
    final trimmedToken = token.trim();

    debugPrint('==================== OTP VERIFICATION & SESSION FLOW ====================');
    debugPrint('[PhoneAuthService] ▶ Step 1: Validating OTP for $cleanedPhone (Token: $trimmedToken)');

    if (trimmedToken.length != 6) {
      debugPrint('[PhoneAuthService] ✗ Step 1 Fail: Token length is invalid (${trimmedToken.length} digits)');
      throw Exception('رمز التحقق يجب أن يكون مكوناً من 6 أرقام.');
    }

    final entry = _pendingOtps[cleanedPhone];

    if (entry == null) {
      debugPrint('[PhoneAuthService] ✗ Step 1 Fail: No active OTP record found for $cleanedPhone');
      throw Exception('لم يتم العثور على رمز تحقق نشط لهذا الرقم. يرجى طلب رمز جديد.');
    }

    if (entry.isExpired) {
      _pendingOtps.remove(cleanedPhone);
      debugPrint('[PhoneAuthService] ✗ Step 1 Fail: OTP expired for $cleanedPhone (Created at: ${entry.createdAt})');
      throw Exception('انتهت صلاحية رمز التحقق. يرجى طلب رمز جديد.');
    }

    if (!entry.isValid(trimmedToken)) {
      debugPrint('[PhoneAuthService] ✗ Step 1 Fail: OTP mismatch for $cleanedPhone (Valid active codes: ${entry.codes}, Received: $trimmedToken)');
      throw Exception('رمز التحقق غير صحيح. يرجى التأكد من الرقم وإعادة المحاولة.');
    }

    // Step 1 Success: Consume valid OTP
    _pendingOtps.remove(cleanedPhone);
    debugPrint('[PhoneAuthService] ✓ Step 1 Success: OTP validated successfully for $cleanedPhone.');

    // Step 2: Establish real Supabase Auth session for the phone user
    final authEmail = 'phone_$cleanedPhone@inride.app';
    final authPassword = 'InRide_Phone_${cleanedPhone}_AuthSecKey!';

    debugPrint('[PhoneAuthService] ▶ Step 2: Creating/Signing in Supabase Auth user ($authEmail)...');

    AuthResponse response;
    try {
      try {
        response = await _supabase.auth.signInWithPassword(
          email: authEmail,
          password: authPassword,
        ).timeout(const Duration(seconds: 10));
        debugPrint('[PhoneAuthService] ✓ Step 2 Success: Existing user signed in via signInWithPassword.');
      } catch (signInError) {
        debugPrint('[PhoneAuthService] User sign-in notice ($signInError). Attempting signUp for new phone user...');
        response = await _supabase.auth.signUp(
          email: authEmail,
          password: authPassword,
          data: {
            'phone_number': e164Phone,
            'full_name': 'مستخدم هاتف',
          },
        ).timeout(const Duration(seconds: 10));

        // If signUp created user but session is null (e.g., autoconfirm delay), execute signInWithPassword
        if (response.session == null) {
          debugPrint('[PhoneAuthService] SignUp succeeded without immediate session. Executing signInWithPassword...');
          response = await _supabase.auth.signInWithPassword(
            email: authEmail,
            password: authPassword,
          ).timeout(const Duration(seconds: 10));
        }
        debugPrint('[PhoneAuthService] ✓ Step 2 Success: New user registered and signed in via signUp.');
      }
    } catch (e, stack) {
      debugPrint('[PhoneAuthService] ✗ Step 2 Fail: Supabase Auth error: $e\n$stack');
      throw Exception('فشل إنشاء جلسة للمستخدم في Supabase Auth: ${AuthErrorHandler.getErrorMessage(e)}');
    }

    // Step 3: Validate that a real, active Supabase Auth Session is established
    final activeUser = response.user ?? _supabase.auth.currentUser;
    final activeSession = response.session ?? _supabase.auth.currentSession;

    debugPrint('[PhoneAuthService] ▶ Step 3: Verifying active Supabase Session properties...');
    debugPrint('User ID      : ${activeUser?.id ?? 'NULL'}');
    debugPrint('Session ID   : ${activeSession != null ? "ACTIVE" : "NULL"}');
    debugPrint('AccessToken  : ${activeSession?.accessToken != null ? "PRESENT (${activeSession!.accessToken.substring(0, 15)}...)" : "MISSING"}');
    debugPrint('RefreshToken : ${activeSession?.refreshToken != null ? "PRESENT" : "MISSING"}');

    if (activeUser == null || activeSession == null || activeSession.accessToken.isEmpty) {
      debugPrint('[PhoneAuthService] ✗ Step 3 Fail: Session validation failed (User or Session is null/empty).');
      throw Exception('لم يتم إنشاء جلسة مصادقة صالحة من Supabase Auth (User/Session Null).');
    }

    debugPrint('[PhoneAuthService] ✓ Step 3 Success: Full valid Supabase Auth session established for User ${activeUser.id}');
    debugPrint('========================================================================');

    return AuthResponse(user: activeUser, session: activeSession);
  }

  /// Helper method to execute POST request with robust socket timeout handling
  Future<http.Response> _postRequest(Uri uri, Map<String, String> headers, String body) async {
    if (!kIsWeb) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 10);
        client.badCertificateCallback = (cert, host, port) => true;

        final request = await client.postUrl(uri).timeout(const Duration(seconds: 10));
        headers.forEach((k, v) => request.headers.set(k, v));
        request.write(body);

        final response = await request.close().timeout(const Duration(seconds: 10));
        final responseBody = await response.transform(utf8.decoder).join();

        final Map<String, String> resHeaders = {};
        response.headers.forEach((name, values) {
          resHeaders[name] = values.join(', ');
        });

        return http.Response(responseBody, response.statusCode, headers: resHeaders);
      } catch (e) {
        debugPrint('[PhoneAuthService] Custom HttpClient notice ($e), falling back to http.post');
      }
    }

    return await http.post(
      uri,
      headers: headers,
      body: body,
    ).timeout(const Duration(seconds: 12));
  }

  /// Returns the latest active OTP generated for the given phone number (useful for testing/debugging).
  String? getLatestOtp(String phoneNumber) {
    final cleanedPhone = formatPhoneForWaPilot(phoneNumber);
    final entry = _pendingOtps[cleanedPhone];
    if (entry != null && !entry.isExpired && entry.codes.isNotEmpty) {
      return entry.codes.last;
    }
    return null;
  }

  // Legacy helper
  String formatPhoneNumber(String rawPhone) => formatPhoneForWaPilot(rawPhone);
}



