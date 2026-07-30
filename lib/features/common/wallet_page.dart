import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/state/global_state.dart';
import '../../shared/widgets/camera_capture_dialog.dart';
import '../../shared/widgets/skeleton_placeholder.dart';

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
    await GlobalState.instance.fetchWalletTransactions();
    if (mounted) {
      setState(() {
        _isLoadingTransactions = false;
      });
    }
  }

  void _showChargeDialog(BuildContext context, GlobalState state) {
    int currentStep = 1; // 1: Method, 2: Amount, 3: InstaPay Details & Receipt Upload
    String selectedMethod = 'InstaPay';
    double selectedAmount = 100.0;
    final customAmountController = TextEditingController();
    bool isCustom = false;
    String? receiptImagePath;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildStepContent() {
              if (currentStep == 1) {
                // Step 1: Choose Payment Method
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'الخطوة ١ من ٣: اختر وسيلة الشحن',
                      style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // InstaPay Option
                    Container(
                      decoration: BoxDecoration(
                        color: selectedMethod == 'InstaPay' ? AppColors.mediumBlue.withValues(alpha: 0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selectedMethod == 'InstaPay' ? AppColors.mediumBlue : AppColors.border,
                          width: selectedMethod == 'InstaPay' ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.purple,
                          child: Icon(Icons.account_balance, color: Colors.white, size: 20),
                        ),
                        title: Text(
                          'انستا باي (InstaPay)',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          'شحن يدوي سريع وآمن بلقطة شاشة الإيصال',
                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        trailing: Icon(
                          selectedMethod == 'InstaPay' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: selectedMethod == 'InstaPay' ? AppColors.mediumBlue : AppColors.textSecondary,
                        ),
                        onTap: () {
                          setDialogState(() {
                            selectedMethod = 'InstaPay';
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Credit Card Option (Disabled / Coming Soon)
                    Opacity(
                      opacity: 0.5,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.blueGrey,
                            child: Icon(Icons.credit_card, color: Colors.white, size: 20),
                          ),
                          title: Text(
                            'بطاقة ائتمان (قريباً)',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                          ),
                          subtitle: Text(
                            'فيزا، ماستركارد، ميزة',
                            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          trailing: const Icon(Icons.lock_outline, size: 18),
                          onTap: () {},
                        ),
                      ),
                    ),
                  ],
                );
              } else if (currentStep == 2) {
                // Step 2: Choose Amount
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'الخطوة ٢ من ٣: حدد مبلغ الشحن',
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
                            label: Text('${amount.round()} ج.م', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
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
                          labelText: 'القيمة المطلوبة (ج.م)',
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
                        isCustom ? 'الرجوع للمبالغ الجاهزة' : 'إدخال قيمة مخصصة أخرى',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.mediumBlue),
                      ),
                    ),
                  ],
                );
              } else {
                // Step 3: InstaPay Details & Camera Capture
                final finalAmt = isCustom ? (double.tryParse(customAmountController.text) ?? 0.0) : selectedAmount;
                const instapayAddr = 'inride@instapay';

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'الخطوة ٣ من ٣: تحويل المبلغ ورفع الإيصال',
                      style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'يرجى تحويل مبلغ $finalAmt ج.م للعنوان التالي:',
                      style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    // Copy Address Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: AppColors.mediumBlue, size: 20),
                            onPressed: () async {
                              await Clipboard.setData(const ClipboardData(text: instapayAddr));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('تم نسخ عنوان انستا باي: $instapayAddr', style: GoogleFonts.cairo()),
                                    backgroundColor: AppColors.success,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                          Text(
                            instapayAddr,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'بعد التحويل، التقط صورة للإيصال لتأكيد العملية:',
                      style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Photo Picker Container
                    GestureDetector(
                      onTap: () async {
                        final photo = await showDialog<String>(
                          context: context,
                          builder: (context) => const CameraCaptureDialog(
                            title: 'تصوير إيصال التحويل',
                            isPickup: true,
                            isReceipt: true,
                          ),
                        );
                        if (photo != null) {
                          setDialogState(() {
                            receiptImagePath = photo;
                          });
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
                                    'اضغط لتصوير إيصال التحويل 📸',
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
                                                child: const Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.receipt_long_rounded, color: AppColors.mediumBlue, size: 40),
                                                  ],
                                                ),
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
                                                child: const Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.receipt_long_rounded, color: AppColors.mediumBlue, size: 40),
                                                  ],
                                                ),
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
                                          'تغيير الصورة',
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

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                'شحن المحفظة (انستا باي)',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              content: SizedBox(
                width: 320,
                child: buildStepContent(),
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
                        child: Text('السابق', style: GoogleFonts.cairo(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.red[600], fontWeight: FontWeight.bold)),
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('يرجى إدخال مبلغ صحيح', style: GoogleFonts.cairo())),
                                );
                                return;
                              }
                              if (receiptImagePath == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('يرجى تصوير إيصال التحويل للمتابعة', style: GoogleFonts.cairo())),
                                );
                                return;
                              }

                              Navigator.pop(context); // Close dialog

                              // Show loading spinner
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.mediumBlue)),
                              );

                              // Submit pending
                              await state.chargeWalletPending(finalAmt, receiptImagePath!, 'InstaPay');

                              if (context.mounted) {
                                Navigator.pop(context); // Close loading spinner
                                
                                // Show Success Overlay
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                      title: const Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'تم تقديم طلب الشحن بنجاح!',
                                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'لقد استلمنا إيصال تحويل InstaPay الخاص بك بقيمة $finalAmt ج.م. سيتم مراجعة الطلب وتفعيل الرصيد في محفظتك خلال دقائق قليلة.',
                                            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        Center(
                                          child: ElevatedButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.mediumBlue,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            child: Text('حسناً', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                // Reload history
                                _loadTransactions();
                              }
                            }
                          },
                          child: Text(
                            currentStep == 3 ? 'إرسال الطلب' : 'التالي',
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

    final List<Map<String, dynamic>> paymentMethods = isDriver
        ? [
            {
              'id': 'instapay',
              'title': 'انستا باي',
              'subtitle': 'الدفع الفوري عبر تطبيق انستا باي',
              'icon': Icons.account_balance_outlined,
            },
          ]
        : [
            {
              'id': 'cash',
              'title': 'كاش',
              'subtitle': 'الدفع نقداً عند الوصول',
              'icon': Icons.payments_outlined,
            },
            {
              'id': 'instapay',
              'title': 'انستا باي',
              'subtitle': 'الدفع الفوري عبر تطبيق انستا باي',
              'icon': Icons.account_balance_outlined,
            },
            {
              'id': 'wallet',
              'title': 'المحفظة',
              'subtitle': '${state.walletBalance.toStringAsFixed(2)} ج.م',
              'icon': Icons.account_balance_wallet_outlined,
            },
          ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'المحفظة وطرق الدفع',
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
                          'الرصيد المتاح',
                          style: GoogleFonts.cairo(fontSize: 14, color: Colors.white70),
                        ),
                        const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${state.walletBalance.toStringAsFixed(2)} ج.م',
                      style: GoogleFonts.outfit(
                        fontSize: 32, 
                        fontWeight: FontWeight.w900, 
                        color: state.walletBalance <= state.creditLimit + 10 ? const Color(0xFFFF5252) : Colors.white
                      ),
                    ),
                    if (state.currentRole == UserRole.driver) ...[
                      const SizedBox(height: 4),
                      Text(
                        'الحد الائتماني: ${state.creditLimit.toStringAsFixed(2)} ج.م',
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
                              'شحن الرصيد',
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
                'طرق الدفع المفضلة',
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
                  bool isSelected = state.selectedPaymentMethod == method['title'];

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
                        child: Icon(method['icon'] as IconData, color: isSelected ? AppColors.mediumBlue : AppColors.textSecondary),
                      ),
                      title: Text(
                        method['title'] as String,
                        style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        method['subtitle'] as String,
                        style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? AppColors.mediumBlue : AppColors.textSecondary,
                      ),
                      onTap: () {
                        setState(() {
                          state.selectedPaymentMethod = method['title'] as String;
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
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  'إضافة طريقة دفع جديدة',
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
                    'سجل المعاملات والخصومات',
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
                                'لا توجد معاملات مالية بعد',
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
                            final double amt = tx['amount'] as double;
                            final bool isDebit = amt < 0;
                            final bool isPending = tx['type'] == 'charge_pending';

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
                                  tx['description'] as String,
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  tx['date'] as String,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: AppColors.textLight,
                                  ),
                                ),
                                trailing: Text(
                                  '${isPending ? "" : (isDebit ? "" : "+")}${amt.toStringAsFixed(2)} ج.م',
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
