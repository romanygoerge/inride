import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'support_chat_page.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final TextEditingController _complaintController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _complaintController.dispose();
    super.dispose();
  }

  void _submitComplaint() {
    if (_formKey.currentState!.validate()) {
      // Mock submitting to Supabase Support table
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إرسال شكواك/استفسارك بنجاح. سيقوم فريق الدعم الفني بمراجعتها والتواصل معك في أقرب وقت.',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );
      _complaintController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'مركز المساعدة والدعم',
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Help illustration card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.mediumBlue.withValues(alpha:0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.support_agent_outlined, color: AppColors.mediumBlue, size: 36),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'كيف يمكننا مساعدتك اليوم؟',
                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                            ),
                            Text(
                              'فريق دعم inRide متاح 24/7 لمساعدتك وحل أي مشكلة تواجهك في رحلاتك.',
                              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Complaint submission form
                Text(
                  'أرسل بلاغ أو استفسار مخصص',
                  style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _complaintController,
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى كتابة تفاصيل الاستفسار أو البلاغ';
                    }
                    if (value.trim().length < 10) {
                      return 'الرجاء كتابة تفاصيل واضحة ومقروءة';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'اكتب هنا ما حدث معك بالتفصيل (مثل: مشكلة في حساب الأرباح، شكوى ضد سائق/عميل، إلخ)...',
                    fillColor: Colors.white,
                  ),
                  style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 20),

                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: AppColors.blueGradient,
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: _submitComplaint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'إرسال البلاغ الآن',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // FAQ Quick Actions
                Text(
                  'روابط تواصل سريعة',
                  style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.help_outline, color: AppColors.mediumBlue),
                        title: Text('الأسئلة الشائعة FAQ', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.arrow_forward_ios_outlined, size: 12),
                        onTap: () {},
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      ListTile(
                        leading: const Icon(Icons.chat_bubble_outline_outlined, color: AppColors.mediumBlue),
                        title: Text('محادثة حية مع الدعم الفني', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.arrow_forward_ios_outlined, size: 12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SupportChatPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
