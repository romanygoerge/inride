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

class _DriverDailyMissionCardState extends State<DriverDailyMissionCard> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isMissionsActive = false;
  int _targetTrips = 8;
  double _rewardAmount = 80.0;
  int _completedTrips = 0;
  bool _isCompleted = false;
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadMissionData();
    _setupRealtime();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadMissionData() async {
    final uid = GlobalState.instance.userUid ?? _supabase.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Fetch system settings
      final settingsRes = await _supabase
          .from('rewards_settings')
          .select()
          .eq('id', 'default')
          .maybeSingle();

      if (settingsRes != null) {
        _isMissionsActive = settingsRes['is_missions_active'] ?? false;
        _targetTrips = settingsRes['daily_mission_trips'] ?? 8;
        final rawRew = settingsRes['daily_mission_reward'];
        _rewardAmount = (rawRew is num)
            ? rawRew.toDouble()
            : (double.tryParse(rawRew?.toString() ?? '80') ?? 80.0);
      }

      if (!_isMissionsActive) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. Fetch today's mission progress
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final missionRes = await _supabase
          .from('driver_mission_progress')
          .select()
          .eq('driver_id', uid)
          .eq('mission_date', todayStr)
          .maybeSingle();

      if (missionRes != null) {
        _completedTrips = missionRes['completed_trips'] ?? 0;
        _isCompleted = missionRes['is_completed'] ?? (_completedTrips >= _targetTrips);
      } else {
        _completedTrips = 0;
        _isCompleted = false;
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[DriverDailyMission] Error loading mission: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupRealtime() {
    final uid = GlobalState.instance.userUid ?? _supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      _realtimeChannel = _supabase
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
            callback: (payload) {
              _loadMissionData();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'rewards_settings',
            callback: (payload) {
              _loadMissionData();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[DriverDailyMission] Realtime error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_isMissionsActive) {
      return const SizedBox.shrink();
    }

    final int target = _targetTrips > 0 ? _targetTrips : 8;
    final int done = _completedTrips;
    final double progress = (done / target).clamp(0.0, 1.0);
    final bool reached = done >= target || _isCompleted;
    final int remaining = (target - done).clamp(0, target);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: reached
              ? [
                  const Color(0xFF064E3B),
                  const Color(0xFF059669),
                ]
              : [
                  const Color(0xFF1E3A8A),
                  const Color(0xFF2563EB),
                ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (reached ? const Color(0xFF059669) : const Color(0xFF2563EB))
                .withValues(alpha: 0.3),
            blurRadius: 14,
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
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        reached ? Icons.military_tech_rounded : Icons.emoji_events_rounded,
                        color: const Color(0xFFFDE047),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reached ? 'تحدي اليوم مكتمل 🎉' : 'تحدي اليوم 🚀',
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        reached
                            ? 'تم إضافة المكافأة لمحفظتك بنجاح'
                            : 'أكمل $target رحلات اليوم واحصل على البونص',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Bonus Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: reached
                      ? const Color(0xFFFDE047)
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${_rewardAmount.toInt()} ج.م',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: reached ? const Color(0xFF064E3B) : Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation<Color>(
                reached ? const Color(0xFFFDE047) : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Progress text footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                reached
                    ? '100% تم الإنجاز 🏆'
                    : 'متبقي $remaining رحلات على البونص',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Text(
                '$done / $target رحلة',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
