// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/services/delete_account_service.dart';
import '../../../shared/widgets/in_app_notification.dart';

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DeleteAccountDialog(),
    );
  }

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  bool _isLoading = true;
  bool _hasDriverAccount = false;
  String _selectedScope = 'both'; // 'driver', 'rider', 'both'
  bool _isDeleting = false;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAccounts();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _checkAccounts() async {
    final hasDriver = await DeleteAccountService.instance.hasDriverAccount();
    if (mounted) {
      setState(() {
        _hasDriverAccount = hasDriver;
        // Default selection: if user is driver + rider, default to driver only to protect rider account, or both
        _selectedScope = hasDriver ? 'driver' : 'both';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDelete() async {
    final isArabic = LocaleController.instance.isArabic;
    setState(() {
      _isDeleting = true;
    });

    final result = await DeleteAccountService.instance.deleteAccount(
      isArabic: isArabic,
      scope: _hasDriverAccount ? _selectedScope : 'both',
      reason: _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null,
    );

    if (!mounted) return;

    setState(() {
      _isDeleting = false;
    });

    if (result.success) {
      Navigator.of(context, rootNavigator: true).pop();

      if (result.scope == 'driver') {
        // Driver deleted only: user is still a rider!
        InAppNotificationWidget.show(
          context,
          title: isArabic ? 'تم حذف حساب الكابتن' : 'Driver Account Deleted',
          body: result.message,
          type: 'success',
          onTap: () {},
        );
        // Navigate back to rider home if we were in driver mode
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      } else if (result.scope == 'rider') {
        InAppNotificationWidget.show(
          context,
          title: isArabic ? 'تم حذف بيانات الراكب' : 'Rider Data Deleted',
          body: result.message,
          type: 'success',
          onTap: () {},
        );
      } else {
        // Full account deleted
        InAppNotificationWidget.show(
          context,
          title: isArabic ? 'تم حذف الحساب نهائياً' : 'Account Deleted',
          body: result.message,
          type: 'success',
          onTap: () {},
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } else {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                result.isActiveTrip ? Icons.directions_car_rounded : Icons.error_outline_rounded,
                color: AppColors.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'تعذر حذف الحساب' : 'Deletion Failed',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Text(
            result.message,
            style: GoogleFonts.cairo(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                isArabic ? 'حسناً' : 'OK',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildScopeOption({
    required String scopeKey,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedScope == scopeKey;

    return InkWell(
      onTap: _isDeleting ? null : () {
        setState(() {
          _selectedScope = scopeKey;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: isSelected ? color : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: scopeKey,
              groupValue: _selectedScope,
              activeColor: color,
              onChanged: _isDeleting ? null : (val) {
                if (val != null) setState(() => _selectedScope = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = LocaleController.instance.isArabic;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.delete_forever_rounded, color: Colors.red.shade700, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isArabic ? 'حذف الحساب' : 'Delete Account',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.red.shade800,
              ),
            ),
          ),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_hasDriverAccount) ...[
                    Text(
                      isArabic
                          ? 'أنت تمتلك حساب كابتن وحساب راكب مسجلين معاً. يرجى اختيار الحساب المراد حذفه:'
                          : 'You have both a driver account and a rider account. Please select which account to delete:',
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildScopeOption(
                      scopeKey: 'driver',
                      title: isArabic ? 'حذف حساب الكابتن فقط' : 'Delete Driver Account Only',
                      description: isArabic
                          ? 'حذف بياناتك ككابتن وسياراتك ومستنداتك وتصفير محفظة الكابتن. سيظل حسابك متاحاً لطلب الرحلات كراكب.'
                          : 'Removes driver profile, vehicle documents, and resets driver balance. Rider account stays active for booking trips.',
                      icon: Icons.local_taxi_rounded,
                      color: Colors.amber.shade800,
                    ),
                    _buildScopeOption(
                      scopeKey: 'rider',
                      title: isArabic ? 'حذف بيانات الراكب فقط' : 'Delete Rider Data Only',
                      description: isArabic
                          ? 'تصفير محفظة الراكب وعناوينه المسجلة، مع استمرار حسابك ككابتن لاستقبال الرحلات.'
                          : 'Resets rider wallet balance and saved addresses while keeping driver account active to take rides.',
                      icon: Icons.person_outline_rounded,
                      color: Colors.blue.shade700,
                    ),
                    _buildScopeOption(
                      scopeKey: 'both',
                      title: isArabic ? 'حذف كلا الحسابين نهائياً (الحساب بالكامل)' : 'Delete Both Accounts Permanently',
                      description: isArabic
                          ? 'حذف نهائي وشامل لكافة البيانات ككابتن وراكب ومسح الحساب بالكامل من النظام وتسجيل خروجك.'
                          : 'Permanently deletes all data for both driver and rider. Your account is erased completely from the system.',
                      icon: Icons.delete_forever_rounded,
                      color: Colors.red.shade700,
                    ),
                  ] else ...[
                    Text(
                      isArabic
                          ? 'سيتم حذف حسابك وجميع بياناتك الشخصية ومحفظتك بشكل نهائي من النظام، ولا يمكن التراجع عن هذا الإجراء.'
                          : 'Your account, wallet, and all personal data will be permanently erased. This action cannot be undone.',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reasonController,
                    maxLines: 2,
                    style: GoogleFonts.cairo(fontSize: 12),
                    decoration: InputDecoration(
                      labelText: isArabic ? 'سبب الحذف (اختياري)' : 'Reason for deletion (optional)',
                      labelStyle: GoogleFonts.cairo(fontSize: 12),
                      hintText: isArabic ? 'مثال: لم أعد بحاجة للخدمة...' : 'e.g. No longer needed...',
                      hintStyle: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          child: Text(
            isArabic ? 'إلغاء' : 'Cancel',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: (_isDeleting || _isLoading) ? null : _handleDelete,
          child: _isDeleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  isArabic ? 'تأكيد الحذف' : 'Confirm Delete',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
