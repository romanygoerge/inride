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
          ? 'سياساتنا وإجراءاتنا بشأن جمع معلوماتك واستخدامها وحمايتها والإفصاح عنها عند استخدام التطبيق'
          : 'Our policies and procedures on the collection, use, protection, and disclosure of your information',
      icon: Icons.shield_rounded,
      lastUpdated: isAr ? 'تاريخ آخر تحديث: 18 أغسطس 2026' : 'Last Updated: August 18, 2026',
      sections: isAr
          ? const [
              _LegalSection(
                title: '1. مقدمة والأساس القانوني',
                content:
                    'تصف سياسة الخصوصية هذه سياساتنا وإجراءاتنا المتعلقة بجمع معلوماتك واستخدامها والإفصاح عنها عند استخدامك للخدمة، وتوضح لك حقوق الخصوصية الخاصة بك وكيفية حماية القانون لك.\n\nنستخدم بياناتك الشخصية لتقديم الخدمة وتحسينها. نقوم بجمع معلوماتك واستخدامها والإفصاح عنها وفقاً لما هو موضح في هذه السياسة وفقط عند وجود أساس قانوني صحيح يشمل موافقتك الصريحة حيثما يلزم.',
              ),
              _LegalSection(
                title: '2. التعريفات والتفسير',
                content:
                    'لأغراض سياسة الخصوصية هذه:\n'
                    '• **التطبيق (Application)**: يشير إلى برنامج inRide المقدم من قِبل الشركة.\n'
                    '• **الشركة (Company)**: يُشار إليها بـ ("نحن" أو "لنا" أو "الشركة") وتشير إلى منصة inRide بجمهورية مصر العربية.\n'
                    '• **الحساب (Account)**: حساب فريد يتم إنشاؤه لك للوصول إلى خدمتنا أو أجزاء منها.\n'
                    '• **الجهاز (Device)**: أي جهاز يمكنه الوصول إلى الخدمة مثل الهاتف المحمول أو الحاسوب اللوحي.\n'
                    '• **البيانات الشخصية (Personal Data)**: أي معلومات تتعلق بفرد محدد الهوية أو يمكن تحديد هويته.\n'
                    '• **مزوّد الخدمة (Service Provider)**: أي شخص طبيعي أو اعتباري يعالج البيانات نيابة عن الشركة.\n'
                    '• **بيانات الاستخدام (Usage Data)**: البيانات التي يتم جمعها تلقائياً، والناتجة عن استخدام الخدمة أو بنيتها التحتية.\n'
                    '• **أنت (You)**: الفرد الذي يصل إلى الخدمة أو يستخدمها.',
              ),
              _LegalSection(
                title: '3. أنواع البيانات التي نجمعها',
                content:
                    '• **البيانات الشخصية**: أثناء استخدام خدمتنا، نطلب منك تزويدنا بمعلومات تعريفية قابلة للتواصل وتحديد الهوية، بما في ذلك رقم الهاتف والاسم ومعلومات الحساب.\n'
                    '• **بيانات الاستخدام**: تُجمع تلقائياً وتشمل عنوان بروتوكول الإنترنت (IP)، المعرفات الفريدة للجهاز، نظام التشغيل، نوع المتصفح، وسجلات الأخطاء والتشخيص الفنية.\n'
                    '• **بيانات الموقع الجغرافي (GPS)**: بإذن مسبق منك، نجمع معلومات موقعك الجغرافي الدقيق (في الواجهة الأمامية والخلفية أثناء الرحلات النشطة) لتقديم ميزات الخدمة، وتسهيل نقاط الانطلاق والوصول، وتخصيص الخدمة وتحسينها. يمكنك تفعيل أو تعطيل إذن الوصول للموقع في أي وقت عبر إعدادات جهازك.',
              ),
              _LegalSection(
                title: '4. استخدام بياناتك الشخصية',
                content:
                    'قد تستخدم الشركة البيانات الشخصية للأغراض التالية:\n'
                    '• تقديم الخدمة وصيانتها ومراقبة كفاءة استخدامها.\n'
                    '• إدارة حسابك وتسجيلك كمستخدم للخدمة وإتاحة ميزاتها المخصصة.\n'
                    '• تنفيذ العقود والالتزامات (خدمات النقل والرحلات المتعاقد عليها).\n'
                    '• التواصل معك: عبر المكالمات الهاتفية، الرسائل النصية القصيرة (SMS)، الواتساب، أو الإشعارات اللحظية (Push Notifications) بشأن التحديثات أو التنبيهات الأمنية والخدمية.\n'
                    '• تزويدك بالعروض الخاصة والمعلومات العامة عن الخدمات والفعاليات المماثلة.\n'
                    '• إدارة طلباتك ومتابعة استفسارات الدعم الفني.\n'
                    '• تقييم الأعمال، تحليل البيانات، دراسة اتجاهات الاستخدام، وتطوير تجربة المستخدم.',
              ),
              _LegalSection(
                title: '5. مشاركة البيانات والإفصاح عنها',
                content:
                    'قد نشارك بياناتك الشخصية في الحالات التالية:\n'
                    '• **مع مزوّدي الخدمات**: لمراقبة وتحليل استخدام الخدمة وتسهيل عمليات التشغيل والدعم.\n'
                    '• **مع المستخدمين الآخرين**: مشاركة اسم وصورة وموقع الكابتن أو الراكب حصرياً أثناء تنفيذ وتتبع الرحلة النشطة.\n'
                    '• **في معاملات نقل الملكية والأعمال**: في حال الاندماج أو بيع أصول الشركة أو تمويلها.\n'
                    '• **الامتثال للجهات القانونية**: الإفصاح عن البيانات عند وجود التزام قانوني ملزم أو أمر قضائي صادر من السلطات الرسمية بجمهورية مصر العربية.\n'
                    '• **بموافقتك الصريحة**: لأي غرض آخر بعد الحصول على موافقتك.',
              ),
              _LegalSection(
                title: '6. مدة الاحتفاظ بالبيانات وحذفها',
                content:
                    '• **معلومات الحساب**: نحتفظ بها طوال فترة علاقة حسابك بالإضافة إلى فترة تصل إلى 24 شهراً بعد إغلاق الحساب للتعامل مع أي نزاعات أو متطلبات قانونية.\n'
                    '• **بيانات الاستخدام والسجلات**: تُحفظ لمدة تصل إلى 24 شهراً لأغراض المراقبة الأمنية والتحسينات التشخيصية.\n'
                    '• **الإتلاف والتجهيل الآمن**: عند انتهاء فترات الاحتفاظ، نقوم بحذف البيانات نهائياً أو إزالتها من النسخ الاحتياطية أو تجهيلها إحصائياً بشكل لا يمكن ربطه بك.',
              ),
              _LegalSection(
                title: '7. نقل البيانات دولياً',
                content:
                    'تتم معالجة معلوماتك وحفظها على خوادم سحابية آمنة. نتخذ جميع الخطوات المعقولة لضمان التعامل مع بياناتك بأمان ووفقاً لمعايير التشفير والحماية الصارمة لسياسة الخصوصية هذه ولا يتم نقلها دون وجود ضوابط أمنية كافية.',
              ),
              _LegalSection(
                title: '8. حقوقك في التحكم ببياناتك وحذف الحساب',
                content:
                    '• يحق لك الوصول إلى بياناتك الشخصية وتعديلها أو تصحيحها أو حذفها في أي وقت من خلال إعدادات الحساب بالتطبيق.\n'
                    '• يمكنك طلب حذف حسابك وبياناتك نهائياً بالتواصل مع فريق الدعم الفني.\n'
                    '• نلتزم بمعالجة طلبات الحذف على الفور مع استثناء السجلات التي يلزمنا القانون بالاحتفاظ بها.',
              ),
              _LegalSection(
                title: '9. أمان بياناتك الشخصية',
                content:
                    'يُعد أمان بياناتك أولويتنا القصوى. نحن نطبق أحدث معايير التشفير (SSL/TLS) وبروتوكولات الحماية التقنية لحماية بياناتك، مع العلم بأنه لا توجد وسيلة نقل عبر الإنترنت أو تخزين إلكتروني آمنة بنسبة 100%.',
              ),
              _LegalSection(
                title: '10. حماية الأطفال والقُصّر',
                content:
                    'الخدمة غير موجهة لأي شخص يقل عمره عن 16 عاماً (و18 عاماً لخدمات نقل الركاب والقيادة). نحن لا نجمع عن علم أي معلومات شخصية من القُصّر، وسيتم حذف أي بيانات تخص القُصّر فور علمنا بها.',
              ),
              _LegalSection(
                title: '11. الروابط الخارجية للمواقع الأخرى',
                content:
                    'قد تحتوي خدمتنا على روابط لمواقع خارجية لا نقوم بتشغيلها. ننصحك بشدة بمراجعة سياسة الخصوصية لكل موقع تزوره حيث لا نتحمل أي مسؤولية عن محتوى أو ممارسات أي أطراف ثالثة.',
              ),
              _LegalSection(
                title: '12. التعديلات على سياسة الخصوصية',
                content:
                    'قد نقوم بتحديث سياسة الخصوصية من وقت لآخر. سنقوم بإخطارك بأي تغييرات عبر نشر السياسة الجديدة على هذه الصفحة وتحديث تاريخ "آخر تحديث" أعلى السياسة.',
              ),
              _LegalSection(
                title: '13. اتصل بنا وتواصل الدعم',
                content:
                    'إذا كان لديك أي أسئلة أو استفسارات حول سياسة الخصوصية، يمكنك التواصل معنا عبر:\n'
                    '• **الهاتف / الواتساب**: 89379958 12 20+\n'
                    '• **البريد الإلكتروني**: support@inrideapp.com',
              ),
            ]
          : const [
              _LegalSection(
                title: '1. Introduction & Legal Basis',
                content:
                    'This Privacy Policy describes Our policies and procedures on the collection, use and disclosure of Your information when You use the Service and tells You about Your privacy rights and how the law protects You.\n\nWe use Your Personal Data to provide and improve the Service. We collect, use, and disclose Your information as described in this Privacy Policy only where We have a valid legal basis to do so, including Your consent where required.',
              ),
              _LegalSection(
                title: '2. Interpretation & Definitions',
                content:
                    'For the purposes of this Privacy Policy:\n'
                    '• **Application**: refers to inRide, the software program provided by the Company.\n'
                    '• **Company** ("We", "Us", or "Our"): refers to inRide (Egypt).\n'
                    '• **Account**: means a unique account created for You to access Our Service or parts of Our Service.\n'
                    '• **Device**: means any device that can access the Service (e.g. smartphone, tablet, computer).\n'
                    '• **Personal Data**: any information that relates to an identified or identifiable individual.\n'
                    '• **Service Provider**: any natural or legal person who processes data on behalf of the Company.\n'
                    '• **Usage Data**: data collected automatically, generated by the use of the Service or its infrastructure.\n'
                    '• **You**: the individual accessing or using the Service.',
              ),
              _LegalSection(
                title: '3. Types of Data Collected',
                content:
                    '• **Personal Data**: While using Our Service, We may ask You to provide Us with certain personally identifiable information, including your Phone number, Name, and Profile Details.\n'
                    '• **Usage Data**: Collected automatically and includes device IP address, unique device identifiers, operating system, mobile browser type, and diagnostic data.\n'
                    '• **Location Data**: With Your prior permission, We collect information regarding Your location (precise GPS coordinates in foreground and background during active trips) to provide features, facilitate pickups and drop-offs, and improve/customize Our Service. You can enable or disable location access at any time via Your Device settings.',
              ),
              _LegalSection(
                title: '4. Use of Your Personal Data',
                content:
                    'The Company may use Personal Data for the following purposes:\n'
                    '• To provide, maintain, and monitor the usage of Our Service.\n'
                    '• To manage Your Account and registration as a user.\n'
                    '• For the performance of a contract (ride services and fulfillment).\n'
                    '• To contact You: by telephone calls, SMS, WhatsApp, or Push Notifications regarding updates, security alerts, and service information.\n'
                    '• To provide news, special offers, and general information about services similar to those you have used.\n'
                    '• To attend to and manage your support requests.\n'
                    '• For business evaluation, analytics, identifying usage trends, and system enhancements.',
              ),
              _LegalSection(
                title: '5. Sharing & Disclosure of Personal Data',
                content:
                    'We may share Your Personal Data in the following situations:\n'
                    '• **With Service Providers**: to monitor and analyze service usage and facilitate operations.\n'
                    '• **With Other Users**: sharing captain and passenger details (name, photo, location) strictly to complete active rides.\n'
                    '• **For Business Transfers**: in connection with any merger, sale of company assets, or financing.\n'
                    '• **Law Enforcement & Legal Obligations**: under statutory requirements, valid court orders, or governmental requests in the Arab Republic of Egypt.\n'
                    '• **With Your Consent**: for any other specific purpose with your explicit permission.',
              ),
              _LegalSection(
                title: '6. Retention & Deletion of Personal Data',
                content:
                    '• **User Accounts**: Retained for the duration of Your Account relationship plus up to 24 months after account closure to resolve post-termination issues or disputes.\n'
                    '• **Usage Data & Logs**: Retained for up to 24 months for analytics, security monitoring, and troubleshooting.\n'
                    '• **Secure Disposal**: When retention periods expire, data is securely deleted, purged from backups, or irreversibly anonymized for analytical use.',
              ),
              _LegalSection(
                title: '7. International Data Transfer',
                content:
                    'Your information may be processed and stored on cloud servers outside your state or country. We take all necessary steps to ensure that your data is treated securely with adequate security controls in accordance with this Privacy Policy.',
              ),
              _LegalSection(
                title: '8. User Rights & Deleting Your Data',
                content:
                    '• You have the right to access, correct, or delete Your Personal Data at any time through the in-app account settings.\n'
                    '• You can request permanent account and data deletion by contacting our support team.\n'
                    '• We fulfill deletion requests promptly, retaining only records required by legal or financial obligations.',
              ),
              _LegalSection(
                title: '9. Security of Your Personal Data',
                content:
                    'The security of Your Personal Data is paramount. We employ modern cryptographic standards (SSL/TLS encryption) and robust technical safeguards to protect your information, though no internet transmission is 100% immune.',
              ),
              _LegalSection(
                title: '10. Children\'s and Minors\' Privacy',
                content:
                    'The Service is not directed to anyone under the age of 16 (and 18 for ride transport services). We do not knowingly collect personal information from minors. Any discovered minor data is deleted promptly.',
              ),
              _LegalSection(
                title: '11. Links to Other Websites',
                content:
                    'Our Service may contain links to third-party websites. We have no control over and assume no responsibility for the content, privacy policies, or practices of any third-party sites.',
              ),
              _LegalSection(
                title: '12. Changes to this Privacy Policy',
                content:
                    'We may update Our Privacy Policy from time to time. We will notify You of changes by posting the revised policy on this page and updating the "Last updated" date.',
              ),
              _LegalSection(
                title: '13. Contact Us',
                content:
                    'If You have any questions about this Privacy Policy, You can contact Us:\n'
                    '• **Phone / WhatsApp**: +20 12 89379958\n'
                    '• **Email**: support@inrideapp.com',
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
