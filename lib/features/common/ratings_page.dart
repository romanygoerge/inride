import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/rating_model.dart';
import '../../core/models/rating_stats_model.dart';
import '../../core/repositories/ratings_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../generated/app_localizations.dart';
import 'widgets/rating_breakdown_card.dart';

class RatingsPage extends StatefulWidget {
  final String userId;

  const RatingsPage({super.key, required this.userId});

  @override
  State<RatingsPage> createState() => _RatingsPageState();
}

class _RatingsPageState extends State<RatingsPage> {
  final RatingsRepository _ratingsRepository = RatingsRepositoryImpl();

  late Future<RatingStatsModel> _statsFuture;
  late Future<List<RatingModel>> _ratingsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _statsFuture = _ratingsRepository.getUserRatingStats(widget.userId);
    _ratingsFuture = _ratingsRepository.getUserRatings(userId: widget.userId, limit: 50);
  }

  Future<void> _refreshData() async {
    setState(() {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l10n.ratingsAndReviews,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.mediumBlue,
        child: FutureBuilder<RatingStatsModel>(
          future: _statsFuture,
          builder: (context, statsSnapshot) {
            final stats = statsSnapshot.data ?? const RatingStatsModel();

            return FutureBuilder<List<RatingModel>>(
              future: _ratingsFuture,
              builder: (context, ratingsSnapshot) {
                final isLoading =
                    statsSnapshot.connectionState == ConnectionState.waiting ||
                        ratingsSnapshot.connectionState == ConnectionState.waiting;
                final reviews = ratingsSnapshot.data ?? [];

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    children: [
                      RatingBreakdownCard(
                        stats: stats,
                        recentReviews: reviews,
                        isLoading: isLoading,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
