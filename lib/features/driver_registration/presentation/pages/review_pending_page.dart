import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';


class ReviewPendingPage extends StatefulWidget {
  const ReviewPendingPage({super.key});

  @override
  State<ReviewPendingPage> createState() => _ReviewPendingPageState();
}

class _ReviewPendingPageState extends State<ReviewPendingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'حالة الحساب',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.logout_outlined, color: AppColors.error),
          onPressed: () {
            GlobalState.instance.reset();
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Hourglass / Status Illustration
              Center(
                child: Container(
                  height: 140,
                  width: 140,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulsing circle
                      Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Icon
                      const Icon(
                        Icons.pending_actions_outlined,
                        size: 56,
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Status text
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
                'نشكرك على التسجيل في inRide! تم استلام مستنداتك بنجاح وجاري فحصها من قبل فريق الدعم الفني وتفعيل حسابك خلال 24 ساعة كحد أقصى.',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Visual Workflow Card
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
              const Spacer(),
              const SizedBox(height: 10),
            ],
          ),
        ),
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
