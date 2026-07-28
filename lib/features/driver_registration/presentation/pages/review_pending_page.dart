import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../features/driver/presentation/pages/driver_home_page.dart';
import 'doc_upload_page.dart';

class ReviewPendingPage extends StatefulWidget {
  const ReviewPendingPage({super.key});

  @override
  State<ReviewPendingPage> createState() => _ReviewPendingPageState();
}

class _ReviewPendingPageState extends State<ReviewPendingPage> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GlobalState.instance,
      builder: (context, _) {
        final state = GlobalState.instance;
        final status = state.verificationStatus;
        final rejectionReason = state.driverRejectionReason;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(
              'حالة حساب السائق',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 18,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.logout_outlined, color: AppColors.error),
              onPressed: () {
                GlobalState.instance.performSafeLogout(context);
              },
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dynamic Status Indicator Button / Header
                  _buildStatusHeader(status),
                  const SizedBox(height: 24),

                  if (status == DriverVerificationStatus.rejected) ...[
                    // Rejected State Content
                    Center(
                      child: Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cancel_outlined,
                          size: 64,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'تم رفض طلب السائق',
                      style: GoogleFonts.cairo(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      (rejectionReason != null && rejectionReason.trim().isNotEmpty)
                          ? 'سبب الرفض: $rejectionReason'
                          : 'يرجى التأكد من وضوح كافة المستندات وصحة البيانات وتصوير الترخيص بشكل واضح.',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mediumBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const DocUploadPage()),
                        );
                      },
                      icon: const Icon(Icons.upload_file_outlined, color: Colors.white),
                      label: Text(
                        'إعادة رفع المستندات والتراخيص',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ] else if (status == DriverVerificationStatus.verified) ...[
                    // Approved State Content
                    Center(
                      child: Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          size: 64,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'تهانينا! تم اعتماد حسابك كسائق',
                      style: GoogleFonts.cairo(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'تم التحقق من مستنداتك وتفعيل حسابك بنجاح. يمكنك الآن البدء في استقبال وتوصيل الرحلات.',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const DriverHomePage()),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: Text(
                        'الانتقال للرئيسية واستقبال الرحلات',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ] else ...[
                    // Under Review State Content
                    Center(
                      child: Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.pending_actions_outlined,
                          size: 64,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'مستنداتك قيد المراجعة',
                      style: GoogleFonts.cairo(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'تم استلام طلبك ومستنداتك بنجاح! يتم فحص البيانات وتفعيل حسابك عبر الدعم الفني، وسيتم إخطارك بالإشعارات فور اعتماد الحساب.',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    Card(
                      color: AppColors.background,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            _buildWorkflowStep(
                              index: 1,
                              title: 'استلام المستندات وصور المركبة',
                              statusText: 'مكتمل',
                              status: StepStatus.completed,
                            ),
                            _buildDivider(),
                            _buildWorkflowStep(
                              index: 2,
                              title: 'التحقق من الهوية وصحة التراخيص',
                              statusText: 'جاري المراجعة الآن',
                              status: StepStatus.active,
                            ),
                            _buildDivider(),
                            _buildWorkflowStep(
                              index: 3,
                              title: 'فحص المركبة وتنشيط الحساب',
                              statusText: 'في الانتظار',
                              status: StepStatus.pending,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader(DriverVerificationStatus status) {
    String label;
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case DriverVerificationStatus.verified:
        label = 'مقبول ومعتمد (Approved)';
        bgColor = AppColors.success.withValues(alpha: 0.12);
        textColor = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case DriverVerificationStatus.rejected:
        label = 'مرفوض (Rejected)';
        bgColor = AppColors.error.withValues(alpha: 0.12);
        textColor = AppColors.error;
        icon = Icons.cancel_rounded;
        break;
      case DriverVerificationStatus.submitted:
      default:
        label = 'قيد المراجعة (Under Review)';
        bgColor = AppColors.warning.withValues(alpha: 0.12);
        textColor = AppColors.warning;
        icon = Icons.hourglass_top_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(right: 18.0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 2,
          height: 20,
          color: AppColors.border,
        ),
      ),
    );
  }

  Widget _buildWorkflowStep({
    required int index,
    required String title,
    required String statusText,
    required StepStatus status,
  }) {
    IconData icon;
    Color iconColor;
    TextStyle titleStyle;

    switch (status) {
      case StepStatus.completed:
        icon = Icons.check_circle_rounded;
        iconColor = AppColors.success;
        titleStyle = GoogleFonts.cairo(
          fontSize: 14,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.lineThrough,
        );
        break;
      case StepStatus.active:
        icon = Icons.radio_button_checked_rounded;
        iconColor = AppColors.warning;
        titleStyle = GoogleFonts.cairo(
          fontSize: 14,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        );
        break;
      case StepStatus.pending:
        icon = Icons.radio_button_off_rounded;
        iconColor = AppColors.textLight;
        titleStyle = GoogleFonts.cairo(
          fontSize: 14,
          color: AppColors.textSecondary,
        );
        break;
    }

    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: titleStyle),
              Text(
                statusText,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: status == StepStatus.active ? AppColors.warning : AppColors.textLight,
                  fontWeight: status == StepStatus.active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum StepStatus { completed, active, pending }

