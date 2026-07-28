import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/skeleton_placeholder.dart';

class RatingsPage extends StatefulWidget {
  final String userId;

  const RatingsPage({super.key, required this.userId});

  @override
  State<RatingsPage> createState() => _RatingsPageState();
}

class _RatingsPageState extends State<RatingsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, Future<Map<String, dynamic>?>> _senderFutures = {};
  
  int _limit = 10;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  late ScrollController _scrollController;

  late final Stream<List<Map<String, dynamic>>> _userStream;
  late final Stream<List<Map<String, dynamic>>> _ratingsStream;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    
    _userStream = _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', widget.userId);
        
    _ratingsStream = _supabase
        .from('ratings')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', widget.userId);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (!_isLoadingMore && _hasMore) {
      setState(() {
        _isLoadingMore = true;
        _limit += 10;
      });
    }
  }

  Future<Map<String, dynamic>?> _getSenderFuture(String senderId) {
    return _senderFutures.putIfAbsent(
      senderId,
      () => _supabase.from('users').select().eq('id', senderId).maybeSingle(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'المراجعات والتقييمات',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _userStream,
        builder: (context, userSnapshot) {
          double overallAverageRating = 0.0;
          if (userSnapshot.hasData && userSnapshot.data!.isNotEmpty) {
            final userData = userSnapshot.data!.first;
            overallAverageRating = ((userData['rating'] as num?) ?? 0.0).toDouble();
          }

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _ratingsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const RatingsListSkeleton();
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'حدث خطأ أثناء تحميل التقييمات',
                    style: GoogleFonts.cairo(color: AppColors.error),
                  ),
                );
              }

              final allDocs = List<Map<String, dynamic>>.from(snapshot.data ?? []);
              if (allDocs.isNotEmpty) {
                final double sum = allDocs.fold(0.0, (acc, item) => acc + ((item['rating'] as num?)?.toDouble() ?? 0.0));
                overallAverageRating = double.parse((sum / allDocs.length).toStringAsFixed(1));
              }
              
              allDocs.sort((a, b) {
                final aTime = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
                final bTime = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
                return bTime.compareTo(aTime);
              });

              final docs = allDocs.take(_limit).toList();
              
              _isLoadingMore = false;
              _hasMore = allDocs.length > _limit;

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_outline, size: 64, color: AppColors.textLight),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد تقييمات أو مراجعات حالياً',
                        style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.blueGradient,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.mediumBlue.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              overallAverageRating.toStringAsFixed(1),
                              style: GoogleFonts.outfit(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Row(
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < overallAverageRating.round() ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 20,
                                );
                              }),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 60, color: Colors.white24),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إجمالي الآراء',
                              style: GoogleFonts.cairo(fontSize: 14, color: Colors.white70),
                            ),
                            Text(
                              '${docs.length}${_hasMore ? "+" : ""} تقييم',
                              style: GoogleFonts.cairo(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: docs.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == docs.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: CircularProgressIndicator(color: AppColors.mediumBlue),
                            ),
                          );
                        }

                        final data = docs[index];
                        final double rating = ((data['rating'] as num?) ?? 5.0).toDouble();
                        final String comment = data['comment'] ?? 'بدون تعليق';
                        final String senderId = data['sender_id'] ?? data['senderId'] ?? '';
                        final date = DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now();
                        final formattedDate = '${date.year}/${date.month}/${date.day}';

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final String? name = data['sender_name'] ?? data['senderName'];
                                        if (name != null && name.isNotEmpty) {
                                          return Text(
                                            name,
                                            style: GoogleFonts.cairo(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          );
                                        }

                                        return FutureBuilder<Map<String, dynamic>?>(
                                          future: _getSenderFuture(senderId),
                                          builder: (context, snapshot) {
                                            String fallbackName = 'مستخدم';
                                            if (snapshot.hasData && snapshot.data != null) {
                                              fallbackName = snapshot.data!['name'] ?? 'مستخدم';
                                            }
                                            return Text(
                                              fallbackName,
                                              style: GoogleFonts.cairo(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    Text(
                                      formattedDate,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      index < rating ? Icons.star : Icons.star_border,
                                      color: Colors.orange,
                                      size: 14,
                                    );
                                  }),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  comment,
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
