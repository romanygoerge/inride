import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

/// 1. شروط الاستخدام (Terms of Use)
class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalPageLayout(
      title: 'شروط الاستخدام',
      subtitle: 'القواعد والتعليمات الشاملة المُنظِمة لاستخدام تطبيق inRide',
      icon: Icons.gavel_rounded,
      lastUpdated: 'تاريخ آخر تحديث: 29 يوليو 2026',
      sections: const [
        _LegalSection(
          title: '1. مقدمة وقبول الشروط',
          content:
              'مرحباً بك في تطبيق inRide. تشكل هذه الشروط اتفاقية قانونية ملزمة بينك وبين تطبيق inRide.\n'
              'بمجرد تحميلك للتطبيق، أو إنشاء حساب، أو استخدامه بأي شكل، فإنك تقر وتوافق على الالتزام الكامل بشروط الاستخدام هذه وجميع التحديثات الصادرة عليها.\n'
              'إذا كنت لا توافق على أي بند من هذه الشروط، فيجب عليك التوقف فوراً عن استخدام التطبيق وحذفه من جهازك.',
        ),
        _LegalSection(
          title: '2. طبيعة المنصة والوساطة التقنية',
          content:
              '• تطبيق inRide هو منصة تقنية رقمية تعمل كأنشطة وساطة إلكترونية تربط بين الركاب والسائقين المستقلين (الكباتن).\n'
              '• المنصة لا تملك أي مركبات لنقل الأشخاص ولا تُعتبر شركة نقل بري أو ناقلاً عاماً، وإنما تقتصر مهمتها على توفير البيئة البرمجية لتسهيل طلب الرحلات وتتبعها والتواصل بين الطرفين.\n'
              '• يعتبر الكابتن مستقلاً ولا يربطه بالتطبيق أي علاقة عمل أو توظيف مباشر.',
        ),
        _LegalSection(
          title: '3. أهليـة الاستخدام وإنشاء الحساب',
          content:
              '• ينبغي أن تكون بعمر 18 عاماً أو أكثر وتمتلك الأهلية القانونية الكاملة لإبرام العقود.\n'
              '• يتم إنشاء الحساب باستخدام رقم الهاتف والتأكيد عبر رمز التحقق (OTP) المرسل عبر واتساب أو الرسائل النصية.\n'
              '• يتعهد المستخدم بتقديم بيانات دقيقة وحقيقية (الاسم الكامل، الصورة الشخصية) وتحديثها باستمرار.\n'
              '• يُحظر إنشاء أكثر من حساب شخصي واحد لكل مستخدم، كما يُمنع بيع الحساب أو التنازل عنه لآخرين.',
        ),
        _LegalSection(
          title: '4. الاستخدام المسموح والسلوك العام',
          content:
              '• يلتزم جميع مستخدمي inRide (ركاب وكباتن) بالتعامل باحترام وأخلاق عالية وعدم ممارسة أي سلوك عرق، تحرش، أو إساءة لفظية أو جسدية.\n'
              '• يُحظر نقل أي مواد غير قانونية، مخدرات، أسلحة، أو مواد خطرة أثناء الرحلات.\n'
              '• المحافظة على سلامة المركبة وعدم إتلاف أي محتويات داخلها.\n'
              '• الالتزام الكامل بقوانين المرور والتعليمات الأمنية السارية.',
        ),
        _LegalSection(
          title: '5. الاستخدام غير المسموح ومكافحة الاحتيال',
          content:
              'يُحظر منعاً باتاً ما يلي:\n'
              '1. استخدام محاكيات الأجهزة (Emulators) أو التطبيقات المعدلة للاحتيال على المنصة.\n'
              '2. إنشاء حسابات وهمية أو استخدام بيانات هويات مزيفة.\n'
              '3. التلاعب بموقع الـ GPS أو المسافات أو تقييمات الرحلات.\n'
              '4. استخدام المنصة لأي أغراض إجرامية أو تزييف المعاملات الماليـة.',
        ),
        _LegalSection(
          title: '6. تسعير الرحلات، الإلغاء، ورسوم الخدمة',
          content:
              '• يقدم التطبيق تقديرات استرشادية لسعر الرحلة بناءً على المسافة والوقت والطلب اللحظي.\n'
              '• يحق للطرفين الاتفاق والتفاوض التفاعلي على السعر داخل المنصة.\n'
              '• يحق للراكب أو الكابتن إلغاء الطلب طبقاً لضوابط الإلغاء، وقد يُلزم الراكب بدفع رسوم إلغاء في حال إلغاء الرحلة بعد قبول الكابتن وتوجهه لمكان الانطلاق.',
        ),
        _LegalSection(
          title: '7. إنهاء الخدمة وإيقاف الحسابات',
          content:
              'تتحفظ إدارة inRide بالحق في تجميد أو تعليق أو حظر حساب أي مستخدم بشكل دائم ودون إشعار مسبق في الحالات التالية:\n'
              '• خرق أي من شروط الاستخدام أو سياسة الخصوصية.\n'
              '• انخفاض معدل التقييم عن الحد الأدنى المقبول بشكل مستمر.\n'
              '• وجود بلاغات أو شكاوى أمنية أو سلوكية بحق المستخدم.\n'
              '• رصد محاولات احتيال أو تلاعب بنظام المنصة.',
        ),
        _LegalSection(
          title: '8. حذف الحساب (Account Deletion)',
          content:
              'يحق للمستخدم حذف حسابه نهائياً وفي أي وقت عبر الخيار المخصص داخل إعدادات الحساب بالتطبيق أو بالتواصل مع فريق الدعم، وسيتم مسح كافة البيانات الشخصية باستثناء السجلات المالية التي يفرض القانون حفظها.',
        ),
      ],
    );
  }
}

/// 2. الشروط والأحكام (Terms & Conditions)
class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalPageLayout(
      title: 'الشروط والأحكام',
      subtitle: 'العقد والالتزامات القانونية بين تطبيق inRide والمستخدمين والكباتن',
      icon: Icons.assignment_turned_in_rounded,
      lastUpdated: 'تاريخ آخر تحديث: 29 يوليو 2026',
      sections: const [
        _LegalSection(
          title: '1. العلاقة التعاقدية',
          content:
              'تحدد هذه الشروط والأحكام القواعد القانونية والتنظيمية التي تحكم العلاقة بين منصة inRide ومستخدميها (الركاب والكباتن).\n'
              'باستخدامك للتطبيق، فإنك تبرم اتفاقاً قانونياً غير حصري وقابلاً للإلغاء للاستفادة من منصة الوساطة الرقمية.',
        ),
        _LegalSection(
          title: '2. التزامات الكابتن (السائق)',
          content:
              'يتعهد الكابتن بالالتزام التام بالاشتراطات التالية:\n'
              '• تقديم رخصة قيادة سارية ورخصة تسيير المركبة وشهادة الفحص الفني وصحيفة الحالة الجنائية (الفيش والتشبيه).\n'
              '• صيانة المركبة بشكل دوري وضمان نظافتها وصلاحيتها الفنية والأمنية للنقل.\n'
              '• عدم مطالبة الراكب بأي مبالغ إضافية خارج قيمة الرحلة المحددة عبر التطبيق.\n'
              '• الالتزام بقواعد القيادة الآمنة وعدم استخدام الهاتف يدويّاً أثناء سياقة المركبة.',
        ),
        _LegalSection(
          title: '3. التزامات الراكب',
          content:
              '• الحضور في موقع الانطلاق المحدد وفي الوقت المتفق عليه.\n'
              '• سداد أجر الرحلة المتفق عليه كاملاً نقداً أو من خلال المحفظة الرقمية للتطبيق.\n'
              '• الحفاظ على نظافة سيارة الكابتن وتجنب أي تصرف قد يسبب ضرراً ماديّاً أو معنويّاً.',
        ),
        _LegalSection(
          title: '4. المحفظة الرقمية والمعاملات المالية',
          content:
              '• يوفر التطبيق نظام محفظة رقمية لشحن الرصيد وسداد قيمة الرحلات أو تحصيل العمولات.\n'
              '• يحق للتطبيق اقتطاع عمولة المنصة المحددة مسبقاً من رصيد محفظة الكابتن عن كل رحلة مكتملة.\n'
              '• في حال وجود نزاع مالي، يتم فحص سجلات الرحلات من قبل إدارة الدعم الفني وتطبيق إجراء التسوية العادلة.',
        ),
        _LegalSection(
          title: '5. تحديد المسؤولية وإخلاء المسؤولية',
          content:
              '• inRide منصة تقنية للربط والوساطة فقط، وهي غير مسؤولة ماديّاً أو قانونيّاً عن الحوادث، الأضرار المباشرة أو غير المباشرة، أو التأخيرات الناتجة عن الحركة المرورية أو الأسباب القاهرة.\n'
              '• المنصة غير مسؤولة عن المتعلقات المفقودة أو المتروكة داخل السيارات، ولكنها تقدم الدعم الفني والمساعدة والتنسيق بين الطرفين لإعادة المفقودات.\n'
              '• يُخلى جانب المنصة من أي نزاع شخصي أو جنائي ينشأ بين الكابتن والراكب خارج نطاق الخدمة التقنية.',
        ),
        _LegalSection(
          title: '6. حقوق الملكية الفكرية',
          content:
              '• كافة حقوق الملكية الفكرية الخاصة بتطبيق inRide (بما في ذلك العلامات التجارية، والشعارات، والرموز البرمجية، والتصاميم، وقواعد البيانات) هي ملك حصري لإدارة inRide.\n'
              '• يُحظر نسخ، أو تعديل، أو إعادة هندسة برمجية (Reverse Engineering)، أو استغلال أي جزء من التطبيق دون إذن كتابي مسبق.',
        ),
        _LegalSection(
          title: '7. القانون الواجب التطبيق وحل النزاعات',
          content:
              '• تخضع هذه الشروط والأحكام وتُفسر وفقاً للقوانين واللوائح التنظيمية المعمول بها في جمهورية مصر العربية.\n'
              '• في حال حدوث أي نزاع، يتم السعي أولاً لحله بطريقة ودية عن طريق إدارة الدعم الفني خلال 30 يوماً.\n'
              '• إذا تعذر الحل الودي، ينعقد الاختصاص القضائي الحصري للمحاكم المختصة بمصر.',
        ),
      ],
    );
  }
}

/// 3. سياسة الخصوصية (Privacy Policy)
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalPageLayout(
      title: 'سياسة الخصوصية',
      subtitle: 'كيف نجمع بياناتك الشخصية والمكانية ونحميها ونشاركها وفق أحدث معايير الأمان (GDPR)',
      icon: Icons.shield_rounded,
      lastUpdated: 'تاريخ آخر تحديث: 29 يوليو 2026',
      sections: const [
        _LegalSection(
          title: '1. مقدمة والتزام الخصوصية',
          content:
              'تلتزم منصة inRide بحماية خصوصية مستخدميها وأمان بياناتهم الشخصية. توضح هذه السياسة ماهية البيانات التي نجمعها، وكيفية استخدامها، وحقوقك في التحكم بها وفقاً لمعايير Google Play وApple App Store واللائحة العامة لحماية البيانات (GDPR).',
        ),
        _LegalSection(
          title: '2. البيانات التي نجمعها',
          content:
              'نجمع البيانات التالية لتقديم خدماتنا وتحسينها:\n'
              '• **بيانات التعريف**: الاسم، رقم الهاتف، البريد الإلكتروني، والصورة الشخصية.\n'
              '• **الموقع الجغرافي (GPS)**: نجمع موقعك دقيق التحديد أثناء استخدام التطبيق، وفي الخلفية (Background Location) للكباتن وأثناء تتبع الرحلة النشطة لضمان سلامة الوصول والدقة.\n'
              '• **بيانات الجهاز والاتصال**: نوع الجهاز، نظام التشغيل، المعرفات الفريدة، ومعرف الإشعارات (Push Notification Token).\n'
              '• **سجلات استخدام وسلوك التطبيق**: سجل الرحلات، التقييمات، وسجلات الأخطاء والانهيار (Crash Logs) لتحسين كفاءة النظام.',
        ),
        _LegalSection(
          title: '3. الأذونات المطلوبة (Permissions)',
          content:
              'يحتاج التطبيق للأذونات التالية:\n'
              '• **الموقع (Location)**: في الأمامية والخلفية لتحديد نقاط الانطلاق والوصول وتتبع المسار.\n'
              '• **الإشعارات (Notifications)**: لإرسال تحديثات حالة الرحلة والتنبيهات المباشرة.\n'
              '• **الكاميرا والمعرض (Camera & Gallery)**: لرفع وثائق الكابتن وصورة الملف الشخصي.\n'
              '• **الهاتف (Phone)**: لتسهيل الاتصال المباشر بين الكابتن والراكب عند الحاجة.',
        ),
        _LegalSection(
          title: '4. كيفية استخدام وتخزين البيانات',
          content:
              'تُستخدم البيانات لأغراض تشغيلية وحصرية تشمل:\n'
              '• ربط الركاب بالكباتن القريبين وتسهيل الملاحة والوصول.\n'
              '• احتساب المسافات والأسعار التقديرية بدقة.\n'
              '• توفير لوحة تحكم للإدارة لمتابعة الأمان وجودة الخدمة.\n'
              '• يتم تخزين البيانات على خوادم سحابية آمنة ومشفّرة باستخدام تقنيات SSL/TLS مع تطبيق أحدث معايير التشفير الأمني.',
        ),
        _LegalSection(
          title: '5. مدة الاحتفاظ بالبيانات (Data Retention)',
          content:
              'نحتفظ ببياناتك طوال فترة تفعيل حسابك على المنصة.\n'
              'في حال طلب حذف الحساب، نلتزم بمحوها نهائياً في غضون 30 يوماً، باستثناء السجلات المالية والمعاملات التي نلزم قانوناً بحفظها لفترة محددة وفقاً للتشريعات المالية والضريبية.',
        ),
        _LegalSection(
          title: '6. مشاركة البيانات والإفصاح القانوني',
          content:
              '• **لا نبيع أو نؤجر بياناتك الشخصية لأي أطراف ثالثة لأغراض تسويقية نهائياً.**\n'
              '• نكشف فقط عن الاسم والصورة والموقع الجغرافي للكابتن أو الراكب المُرتبط بالرحلة أثناء تنفيذ الرحلة النشطة.\n'
              '• قد نفصح عن البيانات للسلطات القضائية أو الجهات الحكومية المختصة عند وجود أمر قضائي رسمي أو التزام قانوني ملزم بجمهورية مصر العربية.',
        ),
        _LegalSection(
          title: '7. حماية الأطفال (Children Privacy)',
          content:
              'تطبيق inRide مخصص حصراً للأفراد بعمر 18 عاماً أو أكثر. نحن لا نجمع عن قصد أي بيانات شخصية من الأطفال أو القصر دون السن القانوني. وفي حال اكتشاف أي حساب لمن هم دون 18 عاماً، سيتم حذفه فوراً.',
        ),
        _LegalSection(
          title: '8. حقوقك في التحكم بالبيانات وتحديث السياسة',
          content:
              'تتمتع بالحقوق التالية:\n'
              '• الحق في الوصول إلى بياناتك الشخصية وتعديلها.\n'
              '• الحق في طلب مسح بياناتك وحذف الحساب نهائياً.\n'
              '• الحق في سحب الأذونات (مثل أذونات الموقع أو الكاميرا) من إعدادات جهازك.\n'
              '• قد نقوم بتحديث سياسة الخصوصية من وقت لآخر، وسيتم إخطارك بأي تغيير جوهري عبر إشعار داخل التطبيق.',
        ),
        _LegalSection(
          title: '9. التواصل معنا',
          content:
              'إذا كان لديك أي استفسارات أو طلبات تتعلق بخصوصية بياناتك أو ممارسة حقوقك، يمكنك التواصل مع مسؤول حماية البيانات عبر البريد الإلكتروني: support@inrideapp.com أو من خلال مركز المساعدة بالتطبيق.',
        ),
      ],
    );
  }
}

/// Layout component for all Legal & Policy pages
class _LegalPageLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String lastUpdated;
  final List<_LegalSection> sections;

  const _LegalPageLayout({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.lastUpdated,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          title,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: AppColors.blueGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.mediumBlue.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Icon(icon, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        lastUpdated,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Sections
              ...sections.map((section) => _buildSectionCard(section)),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  LocaleController.instance.isArabic ? 'inRide © 2026 - جميع الحقوق محفوظة' : 'inRide © 2026 - All Rights Reserved',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(_LegalSection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.mediumBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            section.content,
            style: GoogleFonts.cairo(
              fontSize: 13,
              height: 1.7,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSection {
  final String title;
  final String content;

  const _LegalSection({
    required this.title,
    required this.content,
  });
}
