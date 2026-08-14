import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/locale_controller.dart';

/// 1. شروط الاستخدام (Terms of Use)
class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = LocaleController.instance.isArabic;
    return _LegalPageLayout(
      title: isAr ? 'شروط الاستخدام' : 'Terms of Use',
      subtitle: isAr
          ? 'القواعد والتعليمات الشاملة المُنظِمة لاستخدام تطبيق inRide'
          : 'Comprehensive rules and guidelines governing the use of inRide app',
      icon: Icons.gavel_rounded,
      lastUpdated: isAr ? 'تاريخ آخر تحديث: 29 يوليو 2026' : 'Last Updated: July 29, 2026',
      sections: isAr
          ? const [
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
            ]
          : const [
              _LegalSection(
                title: '1. Introduction & Acceptance of Terms',
                content:
                    'Welcome to the inRide application. These terms constitute a legally binding agreement between you and inRide.\n'
                    'By downloading, registering, or using the application in any manner, you acknowledge and agree to be fully bound by these Terms of Use and any updates issued.\n'
                    'If you do not agree to any provision of these terms, you must immediately cease using the application and uninstall it from your device.',
              ),
              _LegalSection(
                title: '2. Platform Nature & Technical Mediation',
                content:
                    '• The inRide application is a digital technology platform acting as an electronic mediation service connecting passengers with independent drivers (captains).\n'
                    '• The platform does not own passenger transport vehicles and is not a motor carrier or public transporter; its role is strictly limited to providing the software environment for ride requests, tracking, and communication.\n'
                    '• Captains operate independently without any employment or labor relationship with the platform.',
              ),
              _LegalSection(
                title: '3. Eligibility & Account Creation',
                content:
                    '• You must be 18 years of age or older and possess full legal capacity to enter into binding contracts.\n'
                    '• Accounts are registered using phone numbers verified via One-Time Password (OTP) sent via WhatsApp or SMS.\n'
                    '• Users pledge to provide accurate, truthful personal details (full name, profile photo) and keep them updated.\n'
                    '• Creating more than one personal account per user is strictly prohibited, as is selling or transferring accounts.',
              ),
              _LegalSection(
                title: '4. Permitted Use & General Conduct',
                content:
                    '• All inRide users (passengers and captains) commit to respectful, ethical conduct free of discrimination, harassment, or verbal/physical abuse.\n'
                    '• Transporting illegal goods, drugs, weapons, or hazardous materials during rides is strictly prohibited.\n'
                    '• Maintaining vehicle safety and avoiding damage to interior components.\n'
                    '• Full compliance with applicable traffic laws and security guidelines.',
              ),
              _LegalSection(
                title: '5. Prohibited Conduct & Fraud Prevention',
                content:
                    'The following actions are strictly prohibited:\n'
                    '1. Using device emulators or modified applications to defraud the platform.\n'
                    '2. Creating fake accounts or using fraudulent identity details.\n'
                    '3. Manipulating GPS location, distance tracking, or trip rating metrics.\n'
                    '4. Using the platform for criminal purposes or financial fraud.',
              ),
              _LegalSection(
                title: '6. Fare Estimation, Cancellation & Service Fees',
                content:
                    '• The app provides estimated fares based on distance, duration, and real-time demand.\n'
                    '• Both parties retain the right to negotiate fares interactively within the platform.\n'
                    '• Passengers or captains may cancel requests subject to cancellation guidelines. Cancellation fees may apply if cancelled after captain acceptance and dispatch.',
              ),
              _LegalSection(
                title: '7. Service Termination & Account Suspension',
                content:
                    'inRide management reserves the right to freeze, suspend, or permanently ban any user account without prior notice in the following cases:\n'
                    '• Breach of any Terms of Use or Privacy Policy.\n'
                    '• User ratings consistently dropping below minimum thresholds.\n'
                    '• Security or behavioral complaints filed against the user.\n'
                    '• Detection of fraud or manipulation attempts against system logic.',
              ),
              _LegalSection(
                title: '8. Account Deletion',
                content:
                    'Users retain the right to permanently delete their account at any time via the dedicated option in account settings or by contacting customer support. Personal data will be erased except for financial records required by law.',
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
    final isAr = LocaleController.instance.isArabic;
    return _LegalPageLayout(
      title: isAr ? 'الشروط والأحكام' : 'Terms & Conditions',
      subtitle: isAr
          ? 'العقد والالتزامات القانونية بين تطبيق inRide والمستخدمين والكباتن'
          : 'Legal contract and obligations between inRide app, passengers, and captains',
      icon: Icons.assignment_turned_in_rounded,
      lastUpdated: isAr ? 'تاريخ آخر تحديث: 29 يوليو 2026' : 'Last Updated: July 29, 2026',
      sections: isAr
          ? const [
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
            ]
          : const [
              _LegalSection(
                title: '1. Contractual Relationship',
                content:
                    'These Terms & Conditions define the legal and regulatory rules governing the relationship between inRide platform and its users (passengers and captains).\n'
                    'By using the app, you enter into a non-exclusive, revocable legal agreement to utilize the digital mediation platform.',
              ),
              _LegalSection(
                title: '2. Captain (Driver) Obligations',
                content:
                    'Captains agree to adhere strictly to the following requirements:\n'
                    '• Provide a valid driver’s license, vehicle registration, technical inspection certificate, and criminal background check.\n'
                    '• Perform regular vehicle maintenance and ensure cleanliness, technical safety, and roadworthiness.\n'
                    '• Refrain from demanding any additional payments from passengers outside the app-specified fare.\n'
                    '• Adhere to safe driving practices and avoid manual phone use while driving.',
              ),
              _LegalSection(
                title: '3. Passenger Obligations',
                content:
                    '• Arrive at the designated pickup location at the agreed time.\n'
                    '• Pay the agreed ride fare in full via cash or app digital wallet.\n'
                    '• Maintain captain vehicle cleanliness and avoid any actions causing physical or moral harm.',
              ),
              _LegalSection(
                title: '4. Digital Wallet & Financial Transactions',
                content:
                    '• The app provides a digital wallet system to top up balance, pay ride fares, or collect service commissions.\n'
                    '• The app reserves the right to deduct pre-determined platform commission from captain wallet balance for each completed ride.\n'
                    '• In case of financial disputes, trip logs will be reviewed by support for fair resolution.',
              ),
              _LegalSection(
                title: '5. Limitation & Disclaimer of Liability',
                content:
                    '• inRide is a digital connection & mediation platform only; it is not legally or financially liable for accidents, direct/indirect damages, or delays due to traffic or force majeure.\n'
                    '• The platform is not responsible for items left in vehicles, but provides support to coordinate returning lost property.\n'
                    '• The platform is indemnified against personal or criminal disputes between captains and passengers outside technical service boundaries.',
              ),
              _LegalSection(
                title: '6. Intellectual Property Rights',
                content:
                    '• All intellectual property rights of inRide (including trademarks, logos, code, designs, databases) are exclusive property of inRide management.\n'
                    '• Copying, modifying, reverse engineering, or exploiting any part of the app without prior written permission is prohibited.',
              ),
              _LegalSection(
                title: '7. Governing Law & Dispute Resolution',
                content:
                    '• These Terms & Conditions are governed by and construed in accordance with the laws of the Arab Republic of Egypt.\n'
                    '• Disputes will first seek amicable resolution through customer support within 30 days.\n'
                    '• If unresolved, exclusive jurisdiction is granted to competent courts in Egypt.',
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
    final isAr = LocaleController.instance.isArabic;
    return _LegalPageLayout(
      title: isAr ? 'سياسة الخصوصية' : 'Privacy Policy',
      subtitle: isAr
          ? 'كيف نجمع بياناتك الشخصية والمكانية ونحميها ونشاركها وفق أحدث معايير الأمان (GDPR)'
          : 'How we collect, protect, and share your personal and location data according to security standards (GDPR)',
      icon: Icons.shield_rounded,
      lastUpdated: isAr ? 'تاريخ آخر تحديث: 29 يوليو 2026' : 'Last Updated: July 29, 2026',
      sections: isAr
          ? const [
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
            ]
          : const [
              _LegalSection(
                title: '1. Introduction & Privacy Commitment',
                content:
                    'inRide platform is committed to protecting user privacy and securing personal data. This policy outlines what data we collect, how it is used, and your rights under Google Play, Apple App Store, and GDPR standards.',
              ),
              _LegalSection(
                title: '2. Data We Collect',
                content:
                    'We collect the following data to provide and improve services:\n'
                    '• **Identity Data**: Name, phone number, email address, and profile photo.\n'
                    '• **Geographic Location (GPS)**: Precise location while using the app, and background location for captains during active trips to ensure safety and accuracy.\n'
                    '• **Device & Connection Data**: Device model, OS version, unique identifiers, and Push Notification Token.\n'
                    '• **Usage & Log Data**: Trip history, ratings, error & crash logs to enhance system performance.',
              ),
              _LegalSection(
                title: '3. Required Permissions',
                content:
                    'The app requests the following permissions:\n'
                    '• **Location**: Foreground and background for pickup/drop-off points and route tracking.\n'
                    '• **Notifications**: For trip status updates and live alerts.\n'
                    '• **Camera & Gallery**: For uploading captain documentation and profile photo.\n'
                    '• **Phone**: To facilitate direct calls between captain and passenger when needed.',
              ),
              _LegalSection(
                title: '4. Data Usage & Storage',
                content:
                    'Data is used strictly for operational purposes including:\n'
                    '• Connecting passengers with nearby captains and facilitating navigation.\n'
                    '• Calculating distances and estimated fares accurately.\n'
                    '• Providing administrative management dashboard for safety and service quality.\n'
                    '• Data is stored on secure cloud servers encrypted using SSL/TLS protocols.',
              ),
              _LegalSection(
                title: '5. Data Retention',
                content:
                    'We retain your data for as long as your account is active.\n'
                    'Upon account deletion requests, data is permanently purged within 30 days, except financial records required by tax and financial laws.',
              ),
              _LegalSection(
                title: '6. Data Sharing & Legal Disclosure',
                content:
                    '• **We never sell or rent your personal data to third parties for marketing purposes.**\n'
                    '• We disclose captain/passenger name, photo, and live location only to parties connected to an active trip.\n'
                    '• Data may be disclosed to judicial or government authorities upon official legal order in Egypt.',
              ),
              _LegalSection(
                title: '7. Children Privacy',
                content:
                    'inRide app is intended strictly for individuals aged 18 or older. We do not knowingly collect personal data from minors. Any account identified as belonging to an under-18 user will be deleted immediately.',
              ),
              _LegalSection(
                title: '8. Data Control Rights & Policy Updates',
                content:
                    'You have the right to:\n'
                    '• Access and update your personal data.\n'
                    '• Request data erasure and permanent account deletion.\n'
                    '• Revoke permissions (location, camera) from device settings.\n'
                    '• We may update this policy periodically and will notify you of material changes via in-app notification.',
              ),
              _LegalSection(
                title: '9. Contact Us',
                content:
                    'For inquiries or privacy requests, contact our Data Protection Officer at: support@inrideapp.com or via in-app help center.',
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
