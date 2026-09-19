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
  String _title = 'تحدي اليوم';
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
        final rawTitle = (res['title'] as String?)?.isNotEmpty == true
            ? res['title'] as String
            : 'تحدي اليوم';
        final titleStr = rawTitle.replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}|🚀|🏆|🔥|⭐|⏳|⏰]', unicode: true), '').trim();

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

  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildPausedMissionCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تحديات وبونص الرحلات',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'متوقفة حالياً بقرار من الإدارة',
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'متوقف مؤقتاً',
                    style: GoogleFonts.cairo(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تم إيقاف تفعيل فترات التحدي والبونص مؤقتاً. تابع الإشعارات لمواعيد الانطلاق.',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
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
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row (Responsive with flexible wrapping and scale down)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _title.replaceAll('🚀', '').trim(),
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        '+${_rewardAmount.toInt()} ج.م',
                        style: GoogleFonts.cairo(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(maxWidth: 165),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule_rounded, color: Color(0xFFFDE047), size: 15),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'الفترة القادمة • $target رحلات',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Bottom Stats Container (Responsive with Expanded items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem('الموعد', _timeWindowText.isNotEmpty ? _timeWindowText : 'طوال اليوم'),
                  ),
                  VerticalDivider(
                    width: 16,
                    thickness: 1,
                    color: Colors.white.withValues(alpha: 0.2),
                    indent: 4,
                    endIndent: 4,
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'الانطلاق',
                      _countdownText.isNotEmpty
                          ? _countdownText.replaceAll('⏰', '').trim()
                          : (_startTimeFormatted.isNotEmpty ? 'الساعة $_startTimeFormatted' : 'قريباً'),
                    ),
                  ),
                ],
              ),
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
          borderRadius: BorderRadius.circular(18),
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

    final int target = _targetTrips > 0 ? _targetTrips : 5;
    final int done = _completedTrips;
    final bool reached = done >= target || _isCompleted;
    final int remaining = _remainingTrips;

    // Card Gradient based on completion status
    final gradientColors = reached
        ? [const Color(0xFF059669), const Color(0xFF064E3B)]
        : [const Color(0xFF1E88E5), const Color(0xFF0D47A1)];

    return Container(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (reached ? const Color(0xFF059669) : const Color(0xFF1E88E5)).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row (Responsive)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _title.replaceAll('🚀', '').trim(),
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        '+${_rewardAmount.toInt()} ج.م',
                        style: GoogleFonts.cairo(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(maxWidth: 165),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      reached
                          ? Icons.check_circle_rounded
                          : (_isShift ? Icons.schedule_rounded : Icons.stars_rounded),
                      color: reached ? const Color(0xFF34D399) : const Color(0xFFFDE047),
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        reached
                            ? (_isRewarded ? 'تم الصرف' : 'مكتمل')
                            : 'نشط الآن • $target رحلات',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Bottom Stats Container (Responsive with Expanded items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem('الرحلات المكتملة', '$done / $target'),
                  ),
                  VerticalDivider(
                    width: 16,
                    thickness: 1,
                    color: Colors.white.withValues(alpha: 0.2),
                    indent: 4,
                    endIndent: 4,
                  ),
                  Expanded(
                    child: _buildStatItem(
                      reached ? 'حالة التحدي' : 'المتبقي للهدف',
                      reached ? 'مكتمل بنجاح' : '$remaining رحلات',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // If user has not started yet -> Clean, sleek start action button
          if (!_isStarted && !reached) ...[
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isStarting ? null : _startMission,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: _isStarting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_arrow_rounded, color: Color(0xFFFDE047), size: 18),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'بدء التحدي واحتساب الرحلات',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
