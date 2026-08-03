import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/state/global_state.dart';
import '../../shared/widgets/camera_capture_dialog.dart';
import '../../shared/widgets/skeleton_placeholder.dart';
import '../../generated/app_localizations.dart';
import '../../core/localization/locale_controller.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  bool _isLoadingTransactions = true;

  @override
  void initState() {
    super.initState();
    final state = GlobalState.instance;
    final isDriver = state.currentRole == UserRole.driver;
    if (isDriver) {
      state.selectedPaymentMethod = 'انستا باي';
    } else {
      if (state.selectedPaymentMethod != 'كاش' &&
          state.selectedPaymentMethod != 'انستا باي' &&
          state.selectedPaymentMethod != 'المحفظة') {
        state.selectedPaymentMethod = 'كاش';
      }
    }
    if (state.walletTransactions.isNotEmpty) {
      _isLoadingTransactions = false;
    }
    _loadTransactions();
  }

  void _loadTransactions() async {
    try {
      await GlobalState.instance.fetchWalletTransactions();
    } catch (e) {
      debugPrint('Error loading wallet transactions: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTransactions = false;
        });
      }
    }
  }

  void _showChargeDialog(BuildContext context, GlobalState state) {
    int currentStep = 1; // 1: Method, 2: Amount, 3: Details & Receipt Upload
    String selectedMethod = 'instapay';
    double selectedAmount = 100.0;
    final customAmountController = TextEditingController();
    bool isCustom = false;
    String? receiptImagePath;

    final isArabic = LocaleController.instance.isArabic;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final activeMethods = state.activePaymentMethods.where((pm) => pm['code'] != 'cash').toList();
            if (activeMethods.isEmpty) {
              activeMethods.addAll([
                {
                  'id': '1',
                  'name': 'إنستا باي (InstaPay)',
                  'code': 'instapay',
                  'account_details': '01204062941',
                  'is_active': true,
                },
                {
                  'id': '2',
                  'name': 'فودافون كاش',
                  'code': 'vodafone_cash',
                  'account_details': '01000000000',
                  'is_active': true,
                },
              ]);
            }

            final selectedMethodData = activeMethods.firstWhere(
              (m) => (m['code'] as String? ?? '').toLowerCase() == selectedMethod.toLowerCase(),
              orElse: () => activeMethods.first,
            );

            Widget buildStepContent() {
              if (currentStep == 1) {
                // Step 1: Choose Payment Method
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isArabic ? 'الخطوة ١ من ٣: اختر وسيلة الشحن' : 'Step 1 of 3: Choose Top-up Method',
                      style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ...activeMethods.map((pm) {
                      final code = pm['code'] as String? ?? 'instapay';
                      final name = pm['name'] as String? ?? 'إنستا باي';
                      final details = pm['account_details'] as String? ?? '';
                      final isSelected = selectedMethod.toLowerCase() == code.toLowerCase();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.mediumBlue.withValues(alpha: 0.08) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.mediumBlue : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: code == 'instapay'
                                ? Colors.purple
                                : (code == 'vodafone_cash' ? Colors.red : AppColors.mediumBlue),
                            child: Icon(
                              code == 'instapay'
                                  ? Icons.account_balance
                                  : (code == 'vodafone_cash' ? Icons.phone_android : Icons.credit_card),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            name,
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                          ),
                          subtitle: Text(
                            details.isNotEmpty
                                ? details
                                : (isArabic ? 'شحن فوري وآمن' : 'Instant & secure top-up'),
                            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          trailing: Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: isSelected ? AppColors.mediumBlue : AppColors.textSecondary,
                          ),
                          onTap: () {
                            setDialogState(() {
                              selectedMethod = code;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                );
              } else if (currentStep == 2) {
                // Step 2: Choose Amount
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isArabic ? 'الخطوة ٢ من ٣: حدد مبلغ الشحن' : 'Step 2 of 3: Select Top-up Amount',
                      style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (!isCustom)
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [50.0, 100.0, 200.0, 500.0].map((amount) {
                          bool isSelected = selectedAmount == amount;
                          return ChoiceChip(
                            label: Text('${amount.round()} ${isArabic ? "ج.م" : "EGP"}', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                            selected: isSelected,
                            selectedColor: AppColors.mediumBlue,
                            labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontSize: 13),
                            onSelected: (selected) {
                              if (selected) {
                                setDialogState(() {
                                  selectedAmount = amount;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    if (isCustom)
                      TextField(
                        controller: customAmountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'القيمة المطلوبة (ج.م)' : 'Custom Amount (EGP)',
                          labelStyle: GoogleFonts.cairo(fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.mediumBlue, width: 2),
                          ),
                        ),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setDialogState(() {
                          isCustom = !isCustom;
                        });
                      },
                      child: Text(
                        isCustom
                            ? (isArabic ? 'الرجوع للمبالغ الجاهزة' : 'Back to Preset Amounts')
                            : (isArabic ? 'إدخال قيمة مخصصة أخرى' : 'Enter Custom Amount'),
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.mediumBlue),
                      ),
                    ),
                  ],
                );
              } else {
                // Step 3: Method Details & Receipt Upload
                final finalAmt = isCustom ? (double.tryParse(customAmountController.text) ?? 0.0) : selectedAmount;
                final methodName = selectedMethodData['name'] as String? ?? 'إنستا باي';
                final accountNum = (selectedMethodData['account_details'] as String? ?? '').isNotEmpty
                    ? selectedMethodData['account_details'] as String
                    : '01204062941';

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isArabic ? 'الخطوة ٣ من ٣: تحويل المبلغ ورفع الإيصال' : 'Step 3 of 3: Transfer & Upload Receipt',
                      style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isArabic ? 'يرجى تحويل مبلغ $finalAmt ج.م لـ ($methodName):' : 'Please transfer $finalAmt EGP to ($methodName):',
                      style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    // Copy Address Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.mediumBlue.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () async {
                              await Clipboard.setData(ClipboardData(text: accountNum));
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isArabic ? 'تم نسخ الرقم: $accountNum' : 'Copied: $accountNum',
                                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor: AppColors.success,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.mediumBlue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.copy_rounded, color: Colors.white, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    isArabic ? 'نسخ' : 'Copy',
                                    style: GoogleFonts.cairo(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SelectableText(
                            accountNum,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.mediumBlue, letterSpacing: 1.2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isArabic ? 'بعد التحويل، التقط صورة للإيصال أو اختره من المعرض:' : 'After transfer, take a photo or pick receipt photo:',
                      style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Photo Picker Container
                    GestureDetector(
                      onTap: () async {
                        final source = await showModalBottomSheet<ImageSource>(
                          context: dialogContext,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                          builder: (sheetCtx) => Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isArabic ? 'اختر مصدر صورة الإيصال' : 'Select Receipt Source',
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => Navigator.pop(sheetCtx, ImageSource.camera),
                                      icon: const Icon(Icons.camera_alt),
                                      label: Text(isArabic ? 'الكاميرا' : 'Camera', style: GoogleFonts.cairo()),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.mediumBlue,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => Navigator.pop(sheetCtx, ImageSource.gallery),
                                      icon: const Icon(Icons.photo_library),
                                      label: Text(isArabic ? 'المعرض' : 'Gallery', style: GoogleFonts.cairo()),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.mediumBlue,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );

                        if (source == null) return;
                        if (!dialogContext.mounted) return;

                        if (source == ImageSource.camera) {
                          final photo = await showDialog<String>(
                            context: dialogContext,
                            builder: (ctx) => CameraCaptureDialog(
                              title: isArabic ? 'تصوير إيصال التحويل' : 'Capture Receipt Photo',
                              isPickup: true,
                              isReceipt: true,
                            ),
                          );
                          if (photo != null) {
                            setDialogState(() {
                              receiptImagePath = photo;
                            });
                          }
                        } else {
                          try {
                            final picker = ImagePicker();
                            final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                            if (image != null) {
                              setDialogState(() {
                                receiptImagePath = image.path;
                              });
                            }
                          } catch (e) {
                            debugPrint('Gallery pick error: $e');
                          }
                        }
                      },
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                        ),
                        child: receiptImagePath == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.camera_alt_outlined, size: 36, color: AppColors.textLight),
                                  const SizedBox(height: 8),
                                  Text(
                                    isArabic ? 'اضغط لتصوير أو اختيار إيصال التحويل 📸' : 'Tap to take or choose photo 📸',
                                    style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    receiptImagePath!.startsWith('http')
                                        ? Image.network(
                                            receiptImagePath!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: AppColors.mediumBlue.withValues(alpha: 0.1),
                                                alignment: Alignment.center,
                                                child: const Icon(Icons.receipt_long_rounded, color: AppColors.mediumBlue, size: 40),
                                              );
                                            },
                                          )
                                        : Image.file(
                                            File(receiptImagePath!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: AppColors.mediumBlue.withValues(alpha: 0.1),
                                                alignment: Alignment.center,
                                                child: const Icon(Icons.receipt_long_rounded, color: AppColors.mediumBlue, size: 40),
                                              );
                                            },
                                          ),
                                    Container(color: Colors.black26),
                                    const Center(
                                      child: Icon(Icons.check_circle, color: Colors.green, size: 36),
                                    ),
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                                        child: Text(
                                          isArabic ? 'تغيير الصورة' : 'Change Photo',
                                          style: GoogleFonts.cairo(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              }
            }

            final dialogTitleMethod = selectedMethodData['name'] as String? ?? (isArabic ? 'المحفظة' : 'Wallet');

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                isArabic ? 'شحن المحفظة ($dialogTitleMethod)' : 'Top Up Wallet ($dialogTitleMethod)',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 320,
                  child: buildStepContent(),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (currentStep > 1)
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            currentStep--;
                          });
                        },
                        child: Text(isArabic ? 'السابق' : 'Previous', style: GoogleFonts.cairo(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                          },
                          child: Text(isArabic ? 'إلغاء' : 'Cancel', style: GoogleFonts.cairo(color: Colors.red[600], fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mediumBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onPressed: () async {
                            if (currentStep < 3) {
                              setDialogState(() {
                                currentStep++;
                              });
                            } else {
                              // Final Step: Submit
                              final finalAmt = isCustom ? (double.tryParse(customAmountController.text) ?? 0.0) : selectedAmount;
                              if (finalAmt <= 0) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(content: Text(isArabic ? 'يرجى إدخال مبلغ صحيح' : 'Please enter a valid amount', style: GoogleFonts.cairo())),
                                );
                                return;
                              }
                              if (receiptImagePath == null) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(content: Text(isArabic ? 'يرجى تصوير أو اختيار صورة الإيصال للمتابعة' : 'Please select a receipt photo to proceed', style: GoogleFonts.cairo())),
                                );
                                return;
                              }

                              final scaffoldMsg = ScaffoldMessenger.of(context);
                              Navigator.pop(dialogContext); // Close step dialog

                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.mediumBlue)),
                              );

                              bool success = false;
                              try {
                                final methodCode = selectedMethodData['name'] as String? ?? 'InstaPay';
                                success = await state.chargeWalletPending(finalAmt, receiptImagePath!, methodCode);
                              } catch (e) {
                                debugPrint('chargeWalletPending error: $e');
                                success = false;
                              }

                              if (context.mounted) {
                                Navigator.of(context, rootNavigator: true).pop(); // Dismiss loader
                              }

                              if (success) {
                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) {
                                      return AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                        title: const Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              isArabic ? 'تم تقديم طلب الشحن بنجاح!' : 'Top-up request submitted successfully!',
                                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              isArabic
                                                  ? 'لقد استلمنا إيصال تحويل $dialogTitleMethod بقيمة $finalAmt ج.م. سيتم مراجعة الطلب وتفعيل الرصيد في محفظتك خلال دقائق قليلة.'
                                                  : 'We received your $dialogTitleMethod transfer receipt of $finalAmt EGP. It will be reviewed and activated in your wallet shortly.',
                                              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          Center(
                                            child: ElevatedButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.mediumBlue,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                              child: Text(isArabic ? 'حسناً' : 'OK', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }

                                _loadTransactions();
                              } else {
                                scaffoldMsg.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isArabic ? 'تعذر تقديم طلب الشحن حالياً، يرجى المحاولة مرة أخرى' : 'Failed to submit top-up request, please try again',
                                      style: GoogleFonts.cairo(),
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                          child: Text(
                            currentStep == 3 ? (isArabic ? 'إرسال الطلب' : 'Submit') : (isArabic ? 'التالي' : 'Next'),
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = GlobalState.instance;
    final isDriver = state.currentRole == UserRole.driver;
    final isArabic = LocaleController.instance.isArabic;
    final l10n = AppLocalizations.of(context);

    final walletTitleText = l10n?.wallet ?? (isArabic ? 'المحفظة والدفع' : 'Wallet & Payment');
    final walletBalanceTitleText = l10n?.walletBalance ?? (isArabic ? 'رصيد المحفظة' : 'Wallet Balance');
    final egpText = l10n?.egp ?? (isArabic ? 'ج.م' : 'EGP');
    final addFundsText = l10n?.addFunds ?? (isArabic ? 'شحن المحفظة' : 'Top Up Wallet');
    final paymentMethodsTitleText = l10n?.paymentMethods ?? (isArabic ? 'طرق الدفع' : 'Payment Methods');

    final List<Map<String, dynamic>> dynamicMethods = state.activePaymentMethods.map((pm) {
      final code = (pm['code'] ?? 'cash').toString();
      final name = (pm['name'] ?? (isArabic ? 'كاش' : 'Cash')).toString();
      final details = (pm['account_details'] ?? '').toString();
      IconData icon = Icons.payments_outlined;
      if (code == 'instapay') {
        icon = Icons.account_balance_outlined;
      } else if (code == 'vodafone_cash') {
        icon = Icons.phone_android_outlined;
      } else if (code == 'bank_transfer') {
        icon = Icons.account_balance_rounded;
      }

      return {
        'id': code,
        'title': name,
        'subtitle': details.isNotEmpty ? details : (isArabic ? 'وسيلة دفع مقبولة' : 'Accepted payment method'),
        'icon': icon,
      };
    }).toList();

    if (!isDriver && !dynamicMethods.any((m) => m['id'] == 'wallet')) {
      dynamicMethods.add({
        'id': 'wallet',
        'title': isArabic ? 'المحفظة' : 'Wallet',
        'subtitle': '${state.walletBalance.toStringAsFixed(2)} $egpText',
        'icon': Icons.account_balance_wallet_outlined,
      });
    }

    final List<Map<String, dynamic>> paymentMethods = dynamicMethods;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          walletTitleText,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Premium Wallet Balance Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: AppColors.blueGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.mediumBlue.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          walletBalanceTitleText,
                          style: GoogleFonts.cairo(fontSize: 14, color: Colors.white70),
                        ),
                        const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${state.walletBalance.toStringAsFixed(2)} $egpText',
                      style: GoogleFonts.outfit(
                        fontSize: 32, 
                        fontWeight: FontWeight.w900, 
                        color: state.walletBalance <= state.creditLimit + 10 ? const Color(0xFFFF5252) : Colors.white
                      ),
                    ),
                    if (state.currentRole == UserRole.driver) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${isArabic ? "الحد الائتماني" : "Credit Limit"}: ${state.creditLimit.toStringAsFixed(2)} $egpText',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showChargeDialog(context, state),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(
                              addFundsText,
                              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.mediumBlue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 2. Title Payment Methods
              Text(
                paymentMethodsTitleText,
                style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),

              // 3. Payment Methods List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: paymentMethods.length,
                itemBuilder: (context, index) {
                  final method = paymentMethods[index];
                  final titleText = (method['title'] ?? '').toString();
                  final subtitleText = (method['subtitle'] ?? '').toString();
                  final iconData = (method['icon'] is IconData) ? (method['icon'] as IconData) : Icons.payment;

                  bool isSelected = state.selectedPaymentMethod == titleText ||
                      (state.selectedPaymentMethod == 'كاش' && method['id'] == 'cash') ||
                      (state.selectedPaymentMethod == 'انستا باي' && method['id'] == 'instapay') ||
                      (state.selectedPaymentMethod == 'المحفظة' && method['id'] == 'wallet');

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? AppColors.mediumBlue : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.mediumBlue.withValues(alpha: 0.1) : AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(iconData, color: isSelected ? AppColors.mediumBlue : AppColors.textSecondary),
                      ),
                      title: Text(
                        titleText,
                        style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        subtitleText,
                        style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? AppColors.mediumBlue : AppColors.textSecondary,
                      ),
                      onTap: () {
                        setState(() {
                          state.selectedPaymentMethod = titleText;
                        });
                        state.update();
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
              
              // 4. Add Payment Method
              OutlinedButton.icon(
                onPressed: () => _showChargeDialog(context, state),
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  isArabic ? 'إضافة طريقة دفع / شحن جديدة' : 'Add Top Up Method',
                  style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: AppColors.mediumBlue),
                  foregroundColor: AppColors.mediumBlue,
                ),
              ),

              const SizedBox(height: 32),
              
              // Transactions Log Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic ? 'سجل المعاملات والخصومات' : 'Transactions & Deductions Log',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Icon(Icons.history_toggle_off, color: AppColors.mediumBlue, size: 20),
                ],
              ),
              const SizedBox(height: 12),

              _isLoadingTransactions
                  ? const TransactionsListSkeleton()
                  : (state.walletTransactions.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textLight),
                              const SizedBox(height: 10),
                              Text(
                                isArabic ? 'لا توجد معاملات مالية بعد' : 'No financial transactions yet',
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: state.walletTransactions.length,
                          itemBuilder: (context, index) {
                            final tx = state.walletTransactions[index];
                            final double amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                            final bool isDebit = amt < 0;
                            final bool isPending = tx['type'] == 'charge_pending';
                            final String rawDesc = (tx['description'] as String?) ?? (isArabic ? 'معاملة مالية' : 'Transaction');
                            final String desc = isArabic
                                ? rawDesc
                                : rawDesc
                                    .replaceAll('شحن رصيد معلق', 'Pending Top-up')
                                    .replaceAll('شحن رصيد بواسطة الأدمن', 'Admin Top-up')
                                    .replaceAll('خصم عمولة رحلة', 'Trip Fee Deduction')
                                    .replaceAll('مواكبة رصيد', 'Balance Adjustment');

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isPending
                                        ? Colors.orange.withValues(alpha: 0.1)
                                        : (isDebit
                                            ? Colors.red.withValues(alpha: 0.1)
                                            : Colors.green.withValues(alpha: 0.1)),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isPending
                                        ? Icons.access_time_filled_rounded
                                        : (isDebit ? Icons.arrow_downward : Icons.arrow_upward),
                                    color: isPending
                                        ? Colors.orange
                                        : (isDebit ? Colors.red : Colors.green),
                                    size: 18,
                                  ),
                                ),
                                title: Text(
                                  desc,
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  (tx['date'] as String?) ?? '',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: AppColors.textLight,
                                  ),
                                ),
                                trailing: Text(
                                  '${isPending ? "" : (isDebit ? "" : "+")}${amt.toStringAsFixed(2)} ${isArabic ? "ج.م" : "EGP"}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isPending
                                        ? Colors.orange
                                        : (isDebit ? Colors.red : Colors.green),
                                  ),
                                ),
                              ),
                            );
                          },
                        )),
            ],
          ),
        ),
      ),
    );
  }
}
