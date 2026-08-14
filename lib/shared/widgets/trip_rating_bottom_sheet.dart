import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/repositories/ratings_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/locale_controller.dart';

class TripRatingBottomSheet extends StatefulWidget {
  final String tripId;
  final String targetUserId;
  final String targetUserName;
  final String? targetUserAvatar;
  final String role; // 'driver' or 'passenger' / 'rider'

  const TripRatingBottomSheet({
    super.key,
    required this.tripId,
    required this.targetUserId,
    required this.targetUserName,
    this.targetUserAvatar,
    required this.role,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String tripId,
    required String targetUserId,
    required String targetUserName,
    String? targetUserAvatar,
    required String role,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TripRatingBottomSheet(
          tripId: tripId,
          targetUserId: targetUserId,
          targetUserName: targetUserName,
          targetUserAvatar: targetUserAvatar,
          role: role,
        ),
      ),
    );
  }

  @override
  State<TripRatingBottomSheet> createState() => _TripRatingBottomSheetState();
}

class _TripRatingBottomSheetState extends State<TripRatingBottomSheet>
    with SingleTickerProviderStateMixin {
  final RatingsRepository _ratingsRepository = RatingsRepositoryImpl();
  final TextEditingController _reviewController = TextEditingController();

  int _selectedRating = 5;
  bool _isSubmitting = false;
  bool _isSuccess = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_isSubmitting || _isSuccess) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    HapticFeedback.mediumImpact();

    try {
      final success = await _ratingsRepository.submitTripRating(
        tripId: widget.tripId,
        toUserId: widget.targetUserId,
        rating: _selectedRating,
        review: _reviewController.text.trim().isEmpty ? null : _reviewController.text.trim(),
        role: widget.role,
        receiverName: widget.targetUserName,
      );

      if (mounted) {
        if (success) {
          setState(() {
            _isSubmitting = false;
            _isSuccess = true;
          });
          HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 1200));
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        } else {
          setState(() {
            _isSubmitting = false;
            _errorMessage = LocaleController.instance.isArabic 
                ? 'تعذر تسجيل التقييم، يرجى المحاولة مرة أخرى.'
                : 'Failed to submit rating, please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final isArabic = LocaleController.instance.isArabic;
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().contains('already')
              ? (isArabic ? 'لقد قمت بتقييم هذه الرحلة مسبقاً.' : 'You have already rated this trip.')
              : (isArabic ? 'حدث خطأ أثناء التقييم: $e' : 'Rating error: $e');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = widget.role == 'driver';
    final isArabic = LocaleController.instance.isArabic;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Grab Bar
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            if (_isSuccess) ...[
              // Success Screen View
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF2E7D32),
                    size: 64,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isArabic ? 'شكراً لك على تقييمك!' : 'Thank you for your rating!',
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isArabic 
                    ? 'ملاحظاتك تساعدنا على تحسين جودة الخدمة باستمرار.' 
                    : 'Your feedback helps us continuously improve our service quality.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              // Rating Input Screen View
              Text(
                isDriver 
                    ? (isArabic ? 'تقييم الكابتن' : 'Rate Captain')
                    : (isArabic ? 'تقييم الراكب' : 'Rate Passenger'),
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mediumBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isArabic
                    ? 'كيف كانت تجربتك مع ${widget.targetUserName}؟'
                    : 'How was your experience with ${widget.targetUserName}?',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Animated Star Selector Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  final isSelected = starIndex <= _selectedRating;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedRating = starIndex;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: AnimatedScale(
                        scale: isSelected ? 1.15 : 0.95,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: isSelected ? const Color(0xFFFFB300) : Colors.grey.shade300,
                          size: 42,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),

              // Rating Text Label
              Text(
                _getRatingTextLabel(_selectedRating, isArabic),
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFB300),
                ),
              ),
              const SizedBox(height: 20),

              // Review Text Field
              TextField(
                controller: _reviewController,
                maxLength: 500,
                maxLines: 3,
                style: GoogleFonts.cairo(fontSize: 14),
                decoration: InputDecoration(
                  hintText: isDriver
                      ? (isArabic ? 'اكتب تعليقك على أداء وتأثير الكابتن (اختياري)...' : 'Write comments about captain (optional)...')
                      : (isArabic ? 'اكتب ملاحظاتك عن الراكب (اختياري)...' : 'Write comments about passenger (optional)...'),
                  hintStyle: GoogleFonts.cairo(fontSize: 13, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.mediumBlue, width: 1.5),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRating,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mediumBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          isArabic ? 'إرسال التقييم' : 'Submit Rating',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getRatingTextLabel(int star, bool isArabic) {
    switch (star) {
      case 5:
        return isArabic ? 'ممتاز جـداً 🌟🌟🌟🌟🌟' : 'Excellent 🌟🌟🌟🌟🌟';
      case 4:
        return isArabic ? 'جيد جـداً 👍' : 'Very Good 👍';
      case 3:
        return isArabic ? 'مقبول 😐' : 'Good 😐';
      case 2:
        return isArabic ? 'ضعيف 👎' : 'Fair 👎';
      case 1:
        return isArabic ? 'سيء جداً ⚠️' : 'Poor ⚠️';
      default:
        return '';
    }
  }
}
