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
  bool _hasActiveMission = false;
  String _title = 'تحدي اليوم 🚀';
  String _timeWindowText = 'طوال اليوم';
  int _targetTrips = 5;
  double _rewardAmount = 50.0;
  int _completedTrips = 0;
  int _remainingTrips = 5;
  bool _isCompleted = false;
  bool _isStarted = false;
  bool _isShift = false;

  RealtimeChannel? _progressChannel;
  RealtimeChannel? _settingsChannel;
  RealtimeChannel? _shiftsChannel;

  @override
  void initState() {
    super.initState();
    _loadMissionData();
    _setupRealtime();
  }

  @override
  void dispose() {
    _progressChannel?.unsubscribe();
    _settingsChannel?.unsubscribe();
    _shiftsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadMissionData() async {
    final uid = GlobalState.instance.userUid ?? _supabase.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final res = await _supabase.rpc('get_active_driver_mission', params: {
        'p_driver_id': uid,
      });

      if (!mounted) return;

      if (res != null && res is Map) {
        final isActive = res['is_active'] == true;
        final hasActive = res['has_active_mission'] == true;

        if (isActive && hasActive) {
          final target = (res['target_trips'] as num?)?.toInt() ?? 5;
          final done = (res['completed_trips'] as num?)?.toInt() ?? 0;
          final rawRew = res['reward_amount'];
          final reward = (rawRew is num)
              ? rawRew.toDouble()
              : (double.tryParse(rawRew?.toString() ?? '50') ?? 50.0);
          final rem = (res['remaining_trips'] as num?)?.toInt() ?? (target - done).clamp(0, target);
          final completed = res['is_completed'] == true || done >= target;
          final started = res['is_started'] == true || done > 0;

          setState(() {
            _hasActiveMission = true;
            _title = (res['title'] as String?)?.isNotEmpty == true ? res['title'] : 'تحدي اليوم 🚀';
            _timeWindowText = (res['time_window_text'] as String?)?.isNotEmpty == true
                ? res['time_window_text']
                : 'طوال اليوم (حتى 11:59 م)';
            _targetTrips = target > 0 ? target : 5;
            _rewardAmount = reward;
            _completedTrips = done;
            _remainingTrips = rem;
            _isCompleted = completed;
            _isStarted = started;
            _isShift = res['is_shift'] == true;
            _isLoading = false;
          });
          return;
        }
      }

      if (mounted) {
        setState(() {
          _hasActiveMission = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[DriverDailyMissionCard] Error loading active mission: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startMission() async {
    final uid = GlobalState.instance.userUid ?? _supabase.auth.currentUser?.id;
    if (uid == null) return;

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
    if (uid == null) return;

    try {
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_hasActiveMission) {
      return const SizedBox.shrink();
    }

    final int target = _targetTrips > 0 ? _targetTrips : 5;
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
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  reached ? '$_title (مكتمل) 🏆' : _title,
                                  style: GoogleFonts.cairo(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: reached
                                      ? const Color(0xFF047857)
                                      : const Color(0xFF10B981).withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF34D399), width: 0.8),
                                ),
                                child: Text(
                                  reached ? 'تم الصرف 🏆' : 'نشط الآن 🟢',
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
                          ? 'تهانينا يا كابتن! حققت التحدي وتم إيداع المكافأة في محفظتك 🎉'
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
