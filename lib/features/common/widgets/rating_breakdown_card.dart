import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/rating_model.dart';
import '../../../core/models/rating_stats_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/locale_controller.dart';

class RatingBreakdownCard extends StatelessWidget {
  final RatingStatsModel stats;
  final List<RatingModel> recentReviews;
  final bool isLoading;

  const RatingBreakdownCard({
    super.key,
    required this.stats,
    this.recentReviews = const [],
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = LocaleController.instance.isArabic;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAr ? 'التقييمات والمراجعات' : 'Ratings & Reviews',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: stats.isNewUser
                      ? Colors.blue.shade50
                      : const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  stats.formatDisplayRating(),
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: stats.isNewUser
                        ? AppColors.mediumBlue
                        : const Color(0xFFE65100),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            // Main Rating + Distribution Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Big Rating Number
                Column(
                  children: [
                    Text(
                      stats.ratingCount > 0 ? stats.averageRating.toStringAsFixed(1) : '—',
                      style: GoogleFonts.outfit(
                        fontSize: stats.ratingCount > 0 ? 44 : 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: List.generate(5, (index) {
                        final starVal = index + 1;
                        final isFilled = stats.ratingCount > 0 && starVal <= stats.averageRating.round();
                        return Icon(
                          isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: isFilled ? const Color(0xFFFFB300) : AppColors.textSecondary,
                          size: 16,
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stats.ratingCount > 0
                          ? (isAr ? '${stats.ratingCount} تقييم' : '${stats.ratingCount} ratings')
                          : (isAr ? 'جديد (بدون تقييم)' : 'New (No ratings)'),
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),

                // Star Percentage Distribution Bars
                Expanded(
                  child: Column(
                    children: List.generate(5, (index) {
                      final star = 5 - index;
                      final pct = stats.getStarPercentage(star);
                      return _buildStarDistributionRow(star, pct);
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),

            // Recent Comments List with Verified Trip Badge
            if (recentReviews.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                isAr ? 'أحدث أراء وتعليقات المستخدمين' : 'Latest User Reviews',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ...recentReviews.take(4).map((review) => _buildReviewItem(review, isAr)),
            ] else ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  isAr ? 'لا توجد تعليقات مكتوبة حتى الآن.' : 'No written reviews yet.',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStarDistributionRow(int star, double pct) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$star',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.star_rounded, size: 10, color: Color(0xFFFFB300)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100.0,
                minHeight: 6,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(
                  star >= 4
                      ? Colors.green.shade600
                      : (star == 3 ? Colors.orange : Colors.red.shade400),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '${pct.toStringAsFixed(0)}%',
              textAlign: TextAlign.end,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(RatingModel review, bool isAr) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    isAr ? 'مستخدم التطبيق' : 'App User',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Verified Trip Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, size: 10, color: Colors.green),
                        const SizedBox(width: 2),
                        Text(
                          isAr ? 'رحلة موثقة' : 'Verified Trip',
                          style: GoogleFonts.cairo(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index + 1 <= review.rating.toInt()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFFFB300),
                    size: 14,
                  );
                }),
              ),
            ],
          ),
          if (review.hasComment) ...[
            const SizedBox(height: 6),
            Text(
              review.comment!,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
