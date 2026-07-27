import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/state/global_state.dart';
import '../../shared/widgets/skeleton_placeholder.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (GlobalState.instance.tripHistory.isNotEmpty) {
      _isLoading = false;
    }
    _loadHistory();
  }

  void _loadHistory() async {
    await GlobalState.instance.fetchTripHistory();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = GlobalState.instance;
    final trips = state.tripHistory;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'رحلاتي السابقة',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const HistoryListSkeleton()
            : (trips.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history_outlined, size: 64, color: AppColors.textLight),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد رحلات سابقة',
                          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        Text(
                          'عند قيامك برحلتك الأولى، ستظهر تفاصيلها هنا.',
                          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: trips.length,
                    itemBuilder: (context, index) {
                      final trip = trips[index];
                      bool isCompleted = trip['status'] == 'مكتملة';

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              // Top Timestamp & Status
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    trip['date'] as String,
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      color: AppColors.textLight,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isCompleted
                                          ? AppColors.success.withValues(alpha: 0.1)
                                          : AppColors.error.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      trip['status'] as String,
                                      style: GoogleFonts.cairo(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isCompleted ? AppColors.success : AppColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20, color: AppColors.border),
                              
                              // Pickup / Dropoff details
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppColors.mediumBlue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Container(width: 1, height: 16, color: AppColors.border),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppColors.darkBlue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          trip['from'] as String,
                                          style: GoogleFonts.cairo(
                                            fontSize: 13,
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          trip['to'] as String,
                                          style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20, color: AppColors.border),

                              // Vehicle and Fare Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.airport_shuttle_outlined, color: AppColors.textSecondary, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        trip['vehicle'] as String,
                                        style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${(trip['price'] as double).round()} ج.م',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: isCompleted ? AppColors.mediumBlue : AppColors.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )),
      ),
    );
  }
}
