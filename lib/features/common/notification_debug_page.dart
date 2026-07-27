import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/state/global_state.dart';
import '../../core/config/onesignal_config.dart';
import '../../core/services/notification_service.dart';

class NotificationDebugPage extends StatefulWidget {
  const NotificationDebugPage({super.key});

  @override
  State<NotificationDebugPage> createState() => _NotificationDebugPageState();
}

class _NotificationDebugPageState extends State<NotificationDebugPage> {
  bool _isLoading = false;
  String _onesignalSubscriptionId = 'جاري التحميل...';
  bool _optedIn = false;

  @override
  void initState() {
    super.initState();
    _loadOneSignalInfo();
  }

  Future<void> _loadOneSignalInfo() async {
    final subId = OneSignal.User.pushSubscription.id ?? 'غير متوفر';
    final optedIn = OneSignal.User.pushSubscription.optedIn ?? false;
    setState(() {
      _onesignalSubscriptionId = subId;
      _optedIn = optedIn;
    });
  }

  Future<void> _testTripNotification() async {
    setState(() { _isLoading = true; });
    final state = GlobalState.instance;
    final currentUserId = state.userUid ?? 'test_user_uid';
    final targetId = currentUserId; // Target self for instant live test

    await NotificationService.instance.sendNotification(
      recipientId: targetId,
      title: '🚗 محاكاة إشعار الرحلة (Test Trip)',
      body: 'تم قبول طلب الرحلة! الكابتن محمد في الطريق إليك الآن.',
      type: 'trip_accepted',
      data: {
        'tripId': 'TEST_TRIP_${DateTime.now().millisecondsSinceEpoch}',
        'driverName': 'محمد علي (تجريبي)',
        'status': 'accepted',
        'timestamp': DateTime.now().toIso8601String(),
      },
      forceSelf: true,
    );

    await _loadOneSignalInfo();
    setState(() { _isLoading = false; });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال محاكاة إشعار الرحلة بنجاح!', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _testChatNotification() async {
    setState(() { _isLoading = true; });
    final state = GlobalState.instance;
    final currentUserId = state.userUid ?? 'test_user_uid';
    final targetId = currentUserId; // Target self for instant live test

    await NotificationService.instance.sendNotification(
      recipientId: targetId,
      title: '💬 رسالة جديدة من الكابتن (Test Chat)',
      body: 'أنا وصلت للموقع والموتوسيكل واقف قدام البوابة الرئيسية.',
      type: 'chat_message',
      data: {
        'senderId': 'driver_demo_id',
        'senderName': 'الكابتن أحمد',
        'text': 'أنا وصلت للموقع والموتوسيكل واقف قدام البوابة الرئيسية.',
        'timestamp': DateTime.now().toIso8601String(),
      },
      forceSelf: true,
    );

    await _loadOneSignalInfo();
    setState(() { _isLoading = false; });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال محاكاة إشعار الرسالة بنجاح!', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = GlobalState.instance;
    final logs = NotificationService.instance.debugLogs;
    final lastSent = NotificationService.instance.lastPushSent;
    final lastError = NotificationService.instance.lastError;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'فحص وإشعارات OneSignal (Debug)',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.mediumBlue),
            onPressed: () {
              _loadOneSignalInfo();
              setState(() {});
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. OneSignal Configuration & Status Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sensors, color: AppColors.mediumBlue, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'حالة OneSignal والنظام',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: OneSignalConfig.isConfigured ? Colors.green.shade100 : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              OneSignalConfig.isConfigured ? 'مهيأ ومفعل ✅' : 'غير مكتمل ❌',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: OneSignalConfig.isConfigured ? Colors.green.shade900 : Colors.red.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildDetailRow('OneSignal App ID:', OneSignalConfig.appId),
                      _buildDetailRow('User UID (External ID):', state.userUid ?? 'غير مسجل الدخول'),
                      _buildDetailRow('Subscription ID / Player ID:', _onesignalSubscriptionId),
                      _buildDetailRow('إذن الإشعارات Opted-In:', _optedIn ? 'مسموح ✅' : 'غير مسموح ⚠️'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. Interactive Simulation Buttons
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اختبارات الإشعارات الحية (Test Notifications)',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _testTripNotification,
                              icon: const Icon(Icons.directions_car, size: 16),
                              label: Text(
                                'Test Trip Notification',
                                style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.mediumBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _testChatNotification,
                              icon: const Icon(Icons.chat_bubble_outline, size: 16),
                              label: Text(
                                'Test Chat Notification',
                                style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.darkBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. Last Response / Last Error Section
              if (lastSent != null || lastError != null) ...[
                Card(
                  elevation: 0,
                  color: lastError != null ? Colors.red.shade50 : Colors.green.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: lastError != null ? Colors.red.shade200 : Colors.green.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lastError != null ? '⚠️ آخر خطأ في الإشعارات:' : '✅ آخر استجابة ناجحة من OneSignal:',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: lastError != null ? Colors.red.shade900 : Colors.green.shade900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          lastError ?? jsonEncode(lastSent),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: lastError != null ? Colors.red.shade800 : Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 4. Detailed Live Push Logs Stream
              Text(
                'سجل العمليات الحية (Live Push Logs - ${logs.length})',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),

              logs.isEmpty
                  ? Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'لا توجد سجلات بعد. اضغط على أزرار الاختيار أعلاه لتنفيذ محاكاة إشعار.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: logs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final isSuccess = log['success'] == true;
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSuccess ? Colors.green.shade300 : Colors.red.shade300,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isSuccess ? Icons.check_circle : Icons.error,
                                      color: isSuccess ? Colors.green : Colors.red,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${log['type'] ?? 'Push Event'} - HTTP ${log['statusCode'] ?? 0}',
                                      style: GoogleFonts.cairo(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      log['timestamp'] ?? '',
                                      style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'العنوان: ${log['title']}',
                                  style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'المحتوى: ${log['body']}',
                                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Recipient UID: ${log['recipientId']}',
                                  style: GoogleFonts.outfit(fontSize: 10, color: AppColors.mediumBlue),
                                ),
                                if (log['responseBody'] != null) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Response: ${log['responseBody']}',
                                      style: GoogleFonts.outfit(fontSize: 10, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
