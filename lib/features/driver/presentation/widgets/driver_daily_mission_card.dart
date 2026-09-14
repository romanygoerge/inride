import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/state/global_state.dart';

class DriverDailyMissionCard extends StatefulWidget {
  const DriverDailyMissionCard({super.key});

  @override
  State<DriverDailyMissionCard> createState() => _DriverDailyMissionCardState();
}

class _DriverDailyMissionCardState extends State<DriverDailyMissionCard> with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isStarting = false;
  bool _isMissionsActive = true;
  bool _hasActiveMission = true;
  bool _isUpcoming = false;
  String _countdownText = '';
  String _startTimeFormatted = '';
  String _title = 'تحدي اليوم 🚀';
  String _timeWindowText = 'طوال اليوم';
  int _targetTrips = 5;
  double _rewardAmount = 50.0;
  int _completedTrips = 0;
  int _remainingTrips = 5;
  bool _isCompleted = false;
  bool _isStarted = false;
  bool _isRewarded = false;
  bool _isShift = false;

  Timer? _countdownTimer;
  RealtimeChannel? _progressChannel;
  RealtimeChannel? _settingsChannel;
  RealtimeChannel? _shiftsChannel;

  @override
  void initState() {
    super.initState();
    _loadMissionData();
    _setupRealtime();
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        _loadMissionData();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _progressChannel?.unsubscribe();
    _settingsChannel?.unsubscribe();
    _shiftsChannel?.unsubscribe();
    super.dispose();
  }

  String _formatTimeSimple(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--';
    try {
      final parts = timeStr.split(':');
      int hour = int.tryParse(parts[0]) ?? 0;
      final min = parts.length > 1 ? parts[1] : '00';
      if (hour >= 23 && (int.tryParse(min) ?? 0) >= 59) {
        return '12:00 منتصف الليل';
      }
      final isPm = hour >= 12;
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      final ampm = isPm ? 'م' : 'ص';
      return '${hour.toString().padLeft(2, '0')}:$min $ampm';
    } catch (_) {
      return timeStr;
    }
  }

  String _buildCountdownText(String? startTimeStr) {
    if (startTimeStr == null || startTimeStr.isEmpty) return '';
    try {
      final now = DateTime.now().toUtc().add(const Duration(hours: 3));
      final currentMinutes = now.hour * 60 + now.minute;
      final parts = startTimeStr.split(':');
      final startMin = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);

      int diff = startMin - currentMinutes;
      if (diff <= 0) {
        diff += 24 * 60; // Next day
      }

      final hours = diff ~/ 60;
      final mins = diff % 60;

      if (hours > 0 && mins > 0) {
        if (hours == 1) return 'يبدأ التحدي بعد ساعة و $mins دقيقة';
        if (hours == 2) return 'يبدأ التحدي بعد ساعتين و $mins دقيقة';
        if (hours >= 3 && hours <= 10) return 'يبدأ التحدي بعد $hours ساعات و $mins دقيقة';
        return 'يبدأ التحدي بعد $hours ساعة و $mins دقيقة';
      } else if (hours > 0) {
        if (hours == 1) return 'يبدأ التحدي بعد ساعة واحدة';
        if (hours == 2) return 'يبدأ التحدي بعد ساعتين';
        if (hours >= 3 && hours <= 10) return 'يبدأ التحدي بعد $hours ساعات';
        return 'يبدأ التحدي بعد $hours ساعة';
      } else if (mins > 0) {
        return 'يبدأ التحدي بعد $mins دقيقة';
      } else {
        return 'يبدأ التحدي خلال أقل من دقيقة';
      }
    } catch (_) {
      return '';
    }
  }

  Future<void> _loadMissionData() async {
    final uid = GlobalState.instance.userUid ?? _supabase.auth.currentUser?.id;

    try {
      final res = await _supabase.rpc('get_active_driver_mission', params: {
        'p_driver_id': uid,
      });

      if (!mounted) return;

      if (res != null && res is Map) {
        final isMissionsActive = res['is_missions_active'] != false;
        final hasActive = res['has_active_mission'] == true;

        if (!isMissionsActive || !hasActive) {
          setState(() {
            _isMissionsActive = false;
            _hasActiveMission = false;
            _isLoading = false;
          });
          return;
        }

        final isUpcoming = res['is_upcoming'] == true;
        final countdown = res['countdown_text']?.toString() ?? '';
        final startStr = res['start_time']?.toString() ?? '';
        final target = (res['target_trips'] as num?)?.toInt() ?? 5;
        final done = (res['completed_trips'] as num?)?.toInt() ?? 0;
        final rawRew = res['reward_amount'];
        final reward = (rawRew is num)
            ? rawRew.toDouble()
            : (double.tryParse(rawRew?.toString() ?? '50') ?? 50.0);
        final rem = (res['remaining_trips'] as num?)?.toInt() ?? (target - done).clamp(0, target);
        final completed = res['is_completed'] == true || done >= target;
        final started = res['is_started'] == true || done > 0;
        final rewarded = res['is_rewarded'] == true;
        final titleStr = (res['title'] as String?)?.isNotEmpty == true
            ? res['title'] as String
            : 'تحدي اليوم 🚀';

        String timeWindow = (res['time_window_text'] as String?)?.isNotEmpty == true
            ? res['time_window_text'] as String
            : '';
        if (timeWindow.isEmpty && (res['start_time'] != null || res['end_time'] != null)) {
          timeWindow = 'من ${_formatTimeSimple(res['start_time']?.toString())} إلى ${_formatTimeSimple(res['end_time']?.toString())}';
        }
        if (timeWindow.isEmpty) {
          timeWindow = 'طوال اليوم';
        }

        setState(() {
          _isMissionsActive = true;
          _hasActiveMission = true;
          _isUpcoming = isUpcoming;
          _countdownText = countdown.isNotEmpty ? countdown : _buildCountdownText(res['start_time']?.toString());
          _startTimeFormatted = startStr;
          _title = titleStr;
          _timeWindowText = timeWindow;
          _targetTrips = target > 0 ? target : 5;
          _rewardAmount = reward;
          _completedTrips = done;
          _remainingTrips = rem;
          _isCompleted = completed;
          _isStarted = started;
          _isRewarded = rewarded;
          _isShift = res['is_shift'] == true;
          _isLoading = false;
        });
        return;
      }

      // Fallback 1: Query rewards_settings directly
      try {
        final settingsRes = await _supabase
            .from('rewards_settings')
            .select()
            .eq('id', 'default')
            .maybeSingle();
        if (settingsRes != null && settingsRes['is_missions_active'] != true) {
          if (mounted) {
            setState(() {
              _isMissionsActive = false;
              _hasActiveMission = false;
              _isLoading = false;
            });
          }
          return;
        }
      } catch (err) {
        debugPrint('[DriverDailyMissionCard] Fallback settings query notice: $err');
      }

      // Fallback 2: Query active shifts directly
      List<dynamic> shifts = [];
      try {
        shifts = await _supabase
            .from('driver_mission_shifts')
            .select()
            .eq('is_active', true)
            .order('start_time', ascending: true);
      } catch (e) {
        debugPrint('[DriverDailyMissionCard] Error querying shifts directly: $e');
      }

      if (shifts.isEmpty) {
        if (mounted) {
          setState(() {
            _isMissionsActive = false;
            _hasActiveMission = false;
            _isLoading = false;
          });
        }
        return;
      }

      final now = DateTime.now().toUtc().add(const Duration(hours: 3)); // Cairo Time
      final currentMinutes = now.hour * 60 + now.minute;

      Map<String, dynamic>? activeShift;
      for (final s in shifts) {
        final startParts = (s['start_time'] as String? ?? '00:00').split(':');
        final endParts = (s['end_time'] as String? ?? '00:00').split(':');
        final startMin = (int.tryParse(startParts[0]) ?? 0) * 60 + (int.tryParse(startParts[1]) ?? 0);
        final endMin = (int.tryParse(endParts[0]) ?? 0) * 60 + (int.tryParse(endParts[1]) ?? 0);
        if (startMin <= endMin) {
          if (currentMinutes >= startMin && currentMinutes <= endMin) {
            activeShift = s as Map<String, dynamic>;
            break;
          }
        } else {
          if (currentMinutes >= startMin || currentMinutes <= endMin) {
            activeShift = s as Map<String, dynamic>;
            break;
          }
        }
      }

      bool isUpcoming = false;
      String countdown = '';

      if (activeShift != null) {
        isUpcoming = false;
      } else {
        isUpcoming = true;

        for (final s in shifts) {
          final parts = (s['start_time'] as String? ?? '00:00').split(':');
          final min = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
          if (min > currentMinutes) {
            activeShift = s as Map<String, dynamic>;
            break;
          }
        }
        activeShift ??= shifts.first as Map<String, dynamic>;
        countdown = _buildCountdownText(activeShift['start_time']?.toString());
      }

      final target = (activeShift['target_trips'] as num?)?.toInt() ?? 5;
      final rawRew = activeShift['reward_amount'];
      final reward = (rawRew is num)
          ? rawRew.toDouble()
          : (double.tryParse(rawRew?.toString() ?? '50') ?? 50.0);
      final title = activeShift['title']?.toString() ?? 'فترة التحدي 🚀';
      final startFmt = _formatTimeSimple(activeShift['start_time']?.toString());
      final endFmt = _formatTimeSimple(activeShift['end_time']?.toString());
      final timeWindow = isUpcoming ? 'الفترة القادمة: من $startFmt إلى $endFmt' : 'من $startFmt إلى $endFmt';

      int done = 0;
      bool isStarted = false;
      bool isRewarded = false;
      if (uid != null) {
        try {
          final todayStr = DateTime.now().toIso8601String().split('T')[0];
          final progRes = await _supabase
              .from('driver_mission_progress')
              .select()
              .eq('driver_id', uid)
              .eq('mission_date', todayStr)
              .maybeSingle();
          if (progRes != null) {
            done = (progRes['completed_trips'] as num?)?.toInt() ?? 0;
            isRewarded = progRes['is_rewarded'] == true;
            isStarted = progRes['is_started'] == true || done > 0;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isMissionsActive = true;
          _hasActiveMission = true;
          _isUpcoming = isUpcoming;
          _countdownText = countdown;
          _startTimeFormatted = startFmt;
          _title = title;
          _timeWindowText = timeWindow;
          _targetTrips = target > 0 ? target : 5;
          _rewardAmount = reward;
          _completedTrips = done;
          _remainingTrips = (target - done).clamp(0, target);
          _isCompleted = done >= target;
          _isStarted = isStarted;
          _isRewarded = isRewarded;
          _isShift = true;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('[DriverDailyMissionCard] Error loading active mission: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startMission() async {
    final uid = GlobalState.instance.userUid ?? _supabase.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            'يرجى تسجيل الدخول أولاً لبدء التحدي',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      );
      return;
    }

    setState(() => _isStarting = true);
    try {
      final res = await _supabase.rpc('start_driver_mission', params: {
        'p_driver_id': uid,
      });

      if (!mounted) return;

      if (res != null && res is Map) {
        final target = (res['target_trips'] as num?)?.toInt() ?? _targetTrips;
        final done = (res['completed_trips'] as num?)?.toInt() ?? 0;
        final rem = (res['remaining_trips'] as num?)?.toInt() ?? (target - done).clamp(0, target);

        setState(() {
          _isStarted = true;
          _targetTrips = target;
          _completedTrips = done;
          _remainingTrips = rem;
          _isStarting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D47A1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.rocket_launch_rounded, color: Color(0xFFFDE047)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تم بدء التحدي بنجاح! انطلق وحقق الهدف يا كابتن 🚀',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        setState(() {
          _isStarted = true;
          _isStarting = false;
        });
      }
    } catch (e) {
      debugPrint('[DriverDailyMissionCard] Error starting mission: $e');
      if (mounted) {
        setState(() {
          _isStarted = true;
          _isStarting = false;
        });
      }
    }
  }

  void _setupRealtime() {
    final uid = GlobalState.instance.userUid ?? _supabase.auth.currentUser?.id;

    try {
      if (uid != null) {
        _progressChannel = _supabase
            .channel('public:driver_mission_card_$uid')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'driver_mission_progress',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'driver_id',
                value: uid,
              ),
              callback: (_) => _loadMissionData(),
            )
            .subscribe();
      }

      _settingsChannel = _supabase
          .channel('public:rewards_settings_mission_card')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'rewards_settings',
            callback: (_) => _loadMissionData(),
          )
          .subscribe();

      _shiftsChannel = _supabase
          .channel('public:driver_shifts_mission_card')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'driver_mission_shifts',
            callback: (_) => _loadMissionData(),
          )
          .subscribe();
    } catch (e) {
      debugPrint('[DriverDailyMissionCard] Realtime setup error: $e');
    }
  }

  Widget _buildPausedMissionCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF64748B), width: 1.5),
                    ),
                    child: const Center(
                      child: Icon(Icons.pause_circle_outline_rounded, color: Color(0xFF94A3B8), size: 26),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تحديات وبونص الرحلات',
                        style: GoogleFonts.cairo(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'متوقفة حالياً بقرار من الإدارة',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF475569)),
                ),
                child: Text(
                  'متوقف ⚪',
                  style: GoogleFonts.cairo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تم إيقاف تفعيل فترات التحدي والبونص مؤقتاً عبر الداش بورد. تابع الإشعارات للتعرف على مواعيد انطلاق التحديات القادمة!',
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFCBD5E1),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingMissionCard() {
    final int target = _targetTrips > 0 ? _targetTrips : 5;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF1E3A8A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFDE047),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.hourglass_top_rounded,
                          color: Color(0xFFFDE047),
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 2,
                            children: [
                              Text(
                                _title,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFFBBF24),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  'يبدأ قريباً ⏳',
                                  style: GoogleFonts.cairo(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFFDE047),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time_filled_rounded, color: Color(0xFF93C5FD), size: 12),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _timeWindowText,
                                    style: GoogleFonts.cairo(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFBFDBFE),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Reward Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFDE047), Color(0xFFF59E0B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '+${_rewardAmount.toInt()} ج.م',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'بونص كاش',
                      style: GoogleFonts.cairo(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Countdown Info Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.alarm_on_rounded, color: Color(0xFFFDE047), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _countdownText.isNotEmpty
                            ? '$_countdownText ⏰'
                            : 'سيبدأ التحدي القادم قريباً ⏰',
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFFDE047),
                        ),
                      ),
                      Text(
                        'الهدف: إنجاز $target رحلات خلال الفترة للحصول على ${_rewardAmount.toInt()} ج.م كاش بمحفظتك.',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Disabled Waiting Button
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_clock_rounded, size: 18, color: Color(0xFFCBD5E1)),
                const SizedBox(width: 8),
                Text(
                  _startTimeFormatted.isNotEmpty
                      ? 'يبدأ التحدي عند الساعة $_startTimeFormatted'
                      : 'سيبدأ التحدي عند انطلاق الفترة',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 90,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E88E5), strokeWidth: 2.5),
        ),
      );
    }

    // 1. If missions are disabled or no active mission available:
    if (!_isMissionsActive || !_hasActiveMission) {
      return _buildPausedMissionCard();
    }

    // 2. If outside shift hours (Upcoming shift):
    if (_isUpcoming) {
      return _buildUpcomingMissionCard();
    }

    final int target = _targetTrips > 0 ? _targetTrips : 10;
    final int done = _completedTrips;
    final double progress = (done / target).clamp(0.0, 1.0);
    final bool reached = done >= target || _isCompleted;
    final int remaining = _remainingTrips;

    // Card Colors based on state
    final gradientColors = reached
        ? [const Color(0xFF064E3B), const Color(0xFF059669)]
        : (_isShift
            ? [const Color(0xFF0A192F), const Color(0xFF153A7B), const Color(0xFF1E4E9E)]
            : [const Color(0xFF0D47A1), const Color(0xFF1976D2), const Color(0xFF42A5F5)]);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: reached ? const Color(0xFF34D399) : Colors.white.withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (reached ? const Color(0xFF059669) : const Color(0xFF1E4E9E)).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFDE047),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          reached
                              ? Icons.military_tech_rounded
                              : (_isShift ? Icons.schedule_rounded : Icons.emoji_events_rounded),
                          color: const Color(0xFFFDE047),
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 2,
                            children: [
                              Text(
                                reached
                                    ? (_isRewarded ? '$_title (تم الصرف) 🏆' : '$_title (مكتمل) 🏆')
                                    : _title,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: reached
                                      ? (_isRewarded ? const Color(0xFF047857) : const Color(0xFFD97706))
                                      : const Color(0xFF10B981).withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: reached
                                        ? (_isRewarded ? const Color(0xFF34D399) : const Color(0xFFFBBF24))
                                        : const Color(0xFF34D399),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  reached
                                      ? (_isRewarded ? 'تم الصرف 🏆' : 'بانتظار الإرسال ⏳')
                                      : 'نشط الآن 🟢',
                                  style: GoogleFonts.cairo(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time_filled_rounded, color: Color(0xFFFDE047), size: 12),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _timeWindowText,
                                    style: GoogleFonts.cairo(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFFDE047),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Reward Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFDE047), Color(0xFFF59E0B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '+${_rewardAmount.toInt()} ج.م',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'بونص كاش',
                      style: GoogleFonts.cairo(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // User not started yet -> Show invitation with "بدء التحدي الآن" button
          if (!_isStarted && !reached) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF93C5FD), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'أكمل $target رحلات خلال المواعيد المحددة واحصل على ${_rewardAmount.toInt()} ج.م في محفظتك!',
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ElevatedButton(
                onPressed: _isStarting ? null : _startMission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDE047),
                  foregroundColor: const Color(0xFF0A192F),
                  elevation: 4,
                  shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: _isStarting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0A192F)),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow_rounded, size: 22, color: Color(0xFF0A192F)),
                          const SizedBox(width: 6),
                          Text(
                            'بدء التحدي الآن 🎯',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0A192F),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ] else ...[
            // Live Progress Box: "أنجز كذا وفاضل كذا"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: reached
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(
                    reached ? Icons.check_circle_rounded : Icons.flag_rounded,
                    color: reached ? const Color(0xFFFDE047) : const Color(0xFF60A5FA),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reached
                          ? (_isRewarded
                              ? 'تهانينا يا كابتن! حققت التحدي وتم إيداع المكافأة في محفظتك بنجاح 🎉'
                              : 'تهانينا يا كابتن! حققت تارجت التحدي بنجاح 🏆 — جاري مراجعة وصرف البونص إلى محفظتك من قِبل الإدارة!')
                          : 'أنجزت $done من $target رحلات — باقي $remaining رحلات للحصول على البونص! 🚀',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                valueColor: AlwaysStoppedAnimation<Color>(
                  reached ? const Color(0xFFFDE047) : const Color(0xFF38BDF8),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Progress Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  reached ? '100% تم الإنجاز 🏆' : '${(progress * 100).round()}% من الهدف',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                Text(
                  '$done / $target رحلة مكتملة',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
