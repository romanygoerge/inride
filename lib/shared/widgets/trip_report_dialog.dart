import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/models/trip_report_model.dart';
import '../../core/services/trip_report_service.dart';
import '../../core/theme/app_theme.dart';

class TripReportDialog extends StatefulWidget {
  final String? tripId;
  final String reporterId;
  final String reporterRole; // 'passenger' | 'driver'
  final String? reportedId;
  final String? reportedName;
  final String? passengerId;
  final String? passengerName;
  final String? passengerPhone;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String tripStatus; // 'in_progress' | 'completed' | 'cancelled'
  final String? pickupAddress;
  final String? destinationAddress;
  final double? fare;

  const TripReportDialog({
    super.key,
    this.tripId,
    required this.reporterId,
    required this.reporterRole,
    this.reportedId,
    this.reportedName,
    this.passengerId,
    this.passengerName,
    this.passengerPhone,
    this.driverId,
    this.driverName,
    this.driverPhone,
    required this.tripStatus,
    this.pickupAddress,
    this.destinationAddress,
    this.fare,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? tripId,
    required String reporterId,
    required String reporterRole,
    String? reportedId,
    String? reportedName,
    String? passengerId,
    String? passengerName,
    String? passengerPhone,
    String? driverId,
    String? driverName,
    String? driverPhone,
    required String tripStatus,
    String? pickupAddress,
    String? destinationAddress,
    double? fare,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TripReportDialog(
        tripId: tripId,
        reporterId: reporterId,
        reporterRole: reporterRole,
        reportedId: reportedId,
        reportedName: reportedName,
        passengerId: passengerId,
        passengerName: passengerName,
        passengerPhone: passengerPhone,
        driverId: driverId,
        driverName: driverName,
        driverPhone: driverPhone,
        tripStatus: tripStatus,
        pickupAddress: pickupAddress,
        destinationAddress: destinationAddress,
        fare: fare,
      ),
    );
  }

  @override
  State<TripReportDialog> createState() => _TripReportDialogState();
}

class _TripReportDialogState extends State<TripReportDialog> {
  final TextEditingController _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedReason;
  bool _isSubmitting = false;

  List<String> get _reasons {
    final isArabic = LocaleController.instance.isArabic;
    if (widget.reporterRole == 'passenger') {
      return isArabic
          ? [
              'سلوك غير لائق أو غير محترم',
              'طلب مبالغ إضافية عن الأجرة',
              'عدم الالتزام بمسار الرحلة',
              'قيادة متهورة أو غير آمنة',
              'المركبة غير مطابقة للبيانات',
              'تأخر شديد في الوصول',
              'مشكلة أمنية أو طارئة',
              'سبب آخر',
            ]
          : [
              'Inappropriate or disrespectful behavior',
              'Demanding extra fare above the app',
              'Not following the route',
              'Reckless or unsafe driving',
              'Vehicle mismatch with app profile',
              'Excessive delay in arrival',
              'Safety or emergency issue',
              'Other reason',
            ];
    } else {
      return isArabic
          ? [
              'سلوك غير لائق أو إهانة',
              'تأخر شديد في النزول / عدم الحضور',
              'رفض دفع الأجرة المحددة',
              'طلب مسار مخالف أو خطر',
              'إلحاق ضرر أو اتساخ بالمركبة',
              'ركاب أو حمولة مخالفة',
              'مشكلة أمنية أو نزاع',
              'سبب آخر',
            ]
          : [
              'Inappropriate behavior or disrespect',
              'Excessive delay / No show',
              'Refusing to pay specified fare',
              'Demanding illegal or hazardous route',
              'Vehicle damage or mess',
              'Unauthorized passengers/luggage',
              'Security issue or dispute',
              'Other reason',
            ];
    }
  }

  Future<void> _submit() async {
    final isArabic = LocaleController.instance.isArabic;
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'يرجى اختيار سبب البلاغ أولاً' : 'Please select a reason first',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final targetReportedRole = widget.reporterRole == 'passenger' ? 'driver' : 'passenger';
    final targetReportedId = widget.reportedId ??
        (widget.reporterRole == 'passenger' ? widget.driverId : widget.passengerId);

    final report = TripReportModel(
      tripId: widget.tripId,
      reporterId: widget.reporterId,
      reporterRole: widget.reporterRole,
      reportedId: targetReportedId,
      reportedRole: targetReportedRole,
      passengerId: widget.passengerId,
      passengerName: widget.passengerName,
      passengerPhone: widget.passengerPhone,
      driverId: widget.driverId,
      driverName: widget.driverName,
      driverPhone: widget.driverPhone,
      tripStatus: widget.tripStatus,
      pickupAddress: widget.pickupAddress,
      destinationAddress: widget.destinationAddress,
      fare: widget.fare,
      reason: _selectedReason!,
      description: _descController.text.trim(),
    );

    final success = await TripReportService.instance.submitReport(report);

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'تم إرسال البلاغ بنجاح! سيقوم فريق الإدارة بمراجعته فوراً.'
                        : 'Report submitted successfully! The admin team will review it immediately.',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic ? 'حدث خطأ أثناء إرسال البلاغ. يرجى المحاولة مرة أخرى.' : 'Error submitting report. Please try again.',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = LocaleController.instance.isArabic;
    final isPassengerReporting = widget.reporterRole == 'passenger';
    final targetLabel = isPassengerReporting
        ? (isArabic ? 'الكابتن' : 'Captain')
        : (isArabic ? 'الراكب' : 'Passenger');
    final targetName = widget.reportedName ??
        (isPassengerReporting ? widget.driverName : widget.passengerName);

    String statusText;
    if (widget.tripStatus == 'in_progress') {
      statusText = isArabic ? 'أثناء الرحلة' : 'In Progress';
    } else if (widget.tripStatus == 'completed') {
      statusText = isArabic ? 'رحلة مكتملة' : 'Completed';
    } else {
      statusText = isArabic ? 'رحلة ملغاة' : 'Cancelled';
    }

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppColors.error, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'إبلاغ عن $targetLabel' : 'Report $targetLabel',
                          style: GoogleFonts.cairo(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (targetName != null && targetName.isNotEmpty)
                          Text(
                            targetName,
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mediumBlue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Trip Summary Mini Card
              if (widget.pickupAddress != null || widget.destinationAddress != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      if (widget.pickupAddress != null && widget.pickupAddress!.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.circle, color: AppColors.mediumBlue, size: 10),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.pickupAddress!,
                                style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      if (widget.destinationAddress != null && widget.destinationAddress!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: AppColors.darkBlue, size: 12),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.destinationAddress!,
                                style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (widget.fare != null) ...[
                        const Divider(height: 14, color: AppColors.border),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isArabic ? 'قيمة الرحلة:' : 'Trip Fare:',
                              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textLight),
                            ),
                            Text(
                              '${widget.fare!.round()} ${isArabic ? "ج.م" : "EGP"}',
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.mediumBlue),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Reason selection title
              Text(
                isArabic ? 'ما المشكلة التي واجهتك؟' : 'What issue did you encounter?',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Chips for reasons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _reasons.map((reason) {
                  final isSelected = _selectedReason == reason;
                  return ChoiceChip(
                    label: Text(
                      reason,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.error,
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? AppColors.error : AppColors.border,
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedReason = selected ? reason : null;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Detailed comment text field
              Text(
                isArabic ? 'تفاصيل البلاغ والرسالة:' : 'Report Details & Message:',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().length < 5) {
                    return isArabic ? 'يرجى كتابة تفاصيل البلاغ (٥ أحرف على الأقل)' : 'Please enter report details (at least 5 characters)';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: isArabic
                      ? 'يرجى توضيح ما حدث بدقة لنتمكن من مساعدتك ومراجعة المشكلة...'
                      : 'Please explain what happened accurately so we can assist you...',
                  hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.textLight),
                  fillColor: AppColors.background,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                style: GoogleFonts.cairo(fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Submit button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            isArabic ? 'إرسال البلاغ للإدارة' : 'Submit Report to Admin',
                            style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
