import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import 'review_pending_page.dart';

class DocUploadPage extends StatefulWidget {
  const DocUploadPage({super.key});

  @override
  State<DocUploadPage> createState() => _DocUploadPageState();
}

class _DocUploadPageState extends State<DocUploadPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _vehicleNameController = TextEditingController();
  final TextEditingController _vehicleNumberController = TextEditingController();
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _driverAgeController = TextEditingController();
  final TextEditingController _driverPhoneController = TextEditingController();
  String _driverGender = 'ذكر';
  String _vehicleCategory = 'motorcycle'; // 'motorcycle' or 'private_car'
  bool _hasAC = false;
  int _maxPassengers = 4;

  // Uploaded URLs on Supabase
  String? _idCardFrontUrl;
  String? _idCardBackUrl;
  String? _driverLicenseFrontUrl;
  String? _driverLicenseBackUrl;
  String? _vehicleLicenseFrontUrl;
  String? _vehicleLicenseBackUrl;
  final List<String> _vehicleImagesUrls = []; // up to 4

  // Local file paths for instant thumbnail preview
  String? _idCardFrontPath;
  String? _idCardBackPath;
  String? _driverLicenseFrontPath;
  String? _driverLicenseBackPath;
  String? _vehicleLicenseFrontPath;
  String? _vehicleLicenseBackPath;
  final List<String> _vehicleImagesPaths = []; // up to 4

  // Upload status flags
  bool _uploadingIdFront = false;
  bool _uploadingIdBack = false;
  bool _uploadingLicenseFront = false;
  bool _uploadingLicenseBack = false;
  bool _uploadingVehicleLicenseFront = false;
  bool _uploadingVehicleLicenseBack = false;
  final List<bool> _uploadingVehicleImages = [false, false, false, false];

  @override
  void initState() {
    super.initState();
    final state = GlobalState.instance;
    if (state.userName != null && state.userName!.isNotEmpty) {
      _driverNameController.text = state.userName!;
    } else if (state.passengerName != null && state.passengerName!.isNotEmpty) {
      _driverNameController.text = state.passengerName!;
    }
    if (state.phoneNumber != null && state.phoneNumber!.isNotEmpty) {
      _driverPhoneController.text = state.phoneNumber!;
    }
  }

  @override
  void dispose() {
    _vehicleNameController.dispose();
    _vehicleNumberController.dispose();
    _driverNameController.dispose();
    _driverAgeController.dispose();
    _driverPhoneController.dispose();
    super.dispose();
  }

  bool _isAllDocumentsUploaded() {
    return _idCardFrontUrl != null &&
        _idCardBackUrl != null &&
        _driverLicenseFrontUrl != null &&
        _driverLicenseBackUrl != null &&
        _vehicleLicenseFrontUrl != null &&
        _vehicleLicenseBackUrl != null &&
        _vehicleImagesUrls.length >= 4;
  }

  Future<void> _pickAndUploadImage({
    required String fieldKey,
    int? vehicleImageIndex,
  }) async {
    final ImagePicker picker = ImagePicker();

    // Show selection bottom sheet
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'اختر مصدر الصورة',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.mediumBlue),
              title: Text('التقاط صورة بالكاميرا', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const Divider(color: AppColors.border, height: 1),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.mediumBlue),
              title: Text('اختيار من معرض الصور', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (image == null) return;

      // Set uploading flags & save local path
      setState(() {
        if (fieldKey == 'idCardFront') {
          _idCardFrontPath = image.path;
          _uploadingIdFront = true;
        } else if (fieldKey == 'idCardBack') {
          _idCardBackPath = image.path;
          _uploadingIdBack = true;
        } else if (fieldKey == 'driverLicenseFront') {
          _driverLicenseFrontPath = image.path;
          _uploadingLicenseFront = true;
        } else if (fieldKey == 'driverLicenseBack') {
          _driverLicenseBackPath = image.path;
          _uploadingLicenseBack = true;
        } else if (fieldKey == 'vehicleLicenseFront') {
          _vehicleLicenseFrontPath = image.path;
          _uploadingVehicleLicenseFront = true;
        } else if (fieldKey == 'vehicleLicenseBack') {
          _vehicleLicenseBackPath = image.path;
          _uploadingVehicleLicenseBack = true;
        } else if (fieldKey == 'vehicleImage' && vehicleImageIndex != null) {
          if (_vehicleImagesPaths.length > vehicleImageIndex) {
            _vehicleImagesPaths[vehicleImageIndex] = image.path;
          } else {
            _vehicleImagesPaths.add(image.path);
          }
          _uploadingVehicleImages[vehicleImageIndex] = true;
        }
      });

      // Upload to Supabase Storage
      final String folderName = fieldKey.replaceAll(RegExp(r'Front|Back'), '');
      final String fileName = vehicleImageIndex == null ? fieldKey : '${fieldKey}_$vehicleImageIndex';

      final String downloadUrl = await GlobalState.instance.uploadDriverDocument(
        localPath: image.path,
        folderName: folderName,
        fileName: fileName,
      );

      setState(() {
        if (fieldKey == 'idCardFront') {
          _idCardFrontUrl = downloadUrl;
        } else if (fieldKey == 'idCardBack') {
          _idCardBackUrl = downloadUrl;
        } else if (fieldKey == 'driverLicenseFront') {
          _driverLicenseFrontUrl = downloadUrl;
        } else if (fieldKey == 'driverLicenseBack') {
          _driverLicenseBackUrl = downloadUrl;
        } else if (fieldKey == 'vehicleLicenseFront') {
          _vehicleLicenseFrontUrl = downloadUrl;
        } else if (fieldKey == 'vehicleLicenseBack') {
          _vehicleLicenseBackUrl = downloadUrl;
        } else if (fieldKey == 'vehicleImage' && vehicleImageIndex != null) {
          if (_vehicleImagesUrls.length > vehicleImageIndex) {
            _vehicleImagesUrls[vehicleImageIndex] = downloadUrl;
          } else {
            _vehicleImagesUrls.add(downloadUrl);
          }
        }
      });
    } catch (e) {
      debugPrint("Error picking/uploading image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل رفع المستند: $e', style: GoogleFonts.cairo()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (fieldKey == 'idCardFront') _uploadingIdFront = false;
          if (fieldKey == 'idCardBack') _uploadingIdBack = false;
          if (fieldKey == 'driverLicenseFront') _uploadingLicenseFront = false;
          if (fieldKey == 'driverLicenseBack') _uploadingLicenseBack = false;
          if (fieldKey == 'vehicleLicenseFront') _uploadingVehicleLicenseFront = false;
          if (fieldKey == 'vehicleLicenseBack') _uploadingVehicleLicenseBack = false;
          if (fieldKey == 'vehicleImage' && vehicleImageIndex != null) {
            _uploadingVehicleImages[vehicleImageIndex] = false;
          }
        });
      }
    }
  }

  void _onSubmit() {
    if (_formKey.currentState!.validate()) {
      if (!_isAllDocumentsUploaded()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'يرجى تحميل جميع المستندات المطلوبة (10 صور) للاستمرار',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      GlobalState.instance.submitDriverDocuments(
        name: _vehicleNameController.text.trim(),
        number: _vehicleNumberController.text.trim(),
        idCardFrontUrl: _idCardFrontUrl!,
        idCardBackUrl: _idCardBackUrl!,
        driverLicenseFrontUrl: _driverLicenseFrontUrl!,
        driverLicenseBackUrl: _driverLicenseBackUrl!,
        vehicleLicenseFrontUrl: _vehicleLicenseFrontUrl!,
        vehicleLicenseBackUrl: _vehicleLicenseBackUrl!,
        vehicleImages: _vehicleImagesUrls,
        driverName: _driverNameController.text.trim(),
        driverAge: int.tryParse(_driverAgeController.text.trim()) ?? 0,
        driverGender: _driverGender,
        phone: _driverPhoneController.text.trim(),
        vehicleCategory: _vehicleCategory,
        hasAC: _hasAC,
        maxPassengers: _maxPassengers,
      );

      // Route to review pending page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ReviewPendingPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'تسجيل السائق ومستنداته',
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'خطوة واحدة وتصبح سائقاً معنا!',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'يرجى ملء البيانات التالية ورفع المستندات الرسمية لمراجعتها واعتماد حسابك.',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Driver Info
                Text(
                  'البيانات الشخصية',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _driverNameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال اسمك الرباعي';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'الاسم الرباعي',
                    prefixIcon: Icon(Icons.person_outline, color: AppColors.textLight),
                    fillColor: AppColors.background,
                  ),
                  style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _driverPhoneController,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال رقم الهاتف الجوال للتواصل';
                    }
                    if (value.trim().length < 10) {
                      return 'يرجى إدخال رقم هاتف صحيح';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'رقم الهاتف الجوال للتواصل',
                    prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textLight),
                    fillColor: AppColors.background,
                  ),
                  style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _driverAgeController,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'أدخل العمر';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          hintText: 'العمر',
                          prefixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.textLight),
                          fillColor: AppColors.background,
                        ),
                        style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        initialValue: _driverGender,
                        items: const [
                          DropdownMenuItem(value: 'ذكر', child: Text('ذكر')),
                          DropdownMenuItem(value: 'أنثى', child: Text('أنثى')),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _driverGender = val!;
                          });
                        },
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.wc_outlined, color: AppColors.textLight),
                          fillColor: AppColors.background,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Vehicle Info
                Text(
                  'بيانات المركبة',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vehicleNameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال ماركة وموديل السيارة (مثال: هيونداي إلنترا)';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'ماركة وموديل السيارة (مثال: تويوتا كورولا 2023)',
                    prefixIcon: Icon(Icons.directions_car_filled_outlined, color: AppColors.textLight),
                    fillColor: AppColors.background,
                  ),
                  style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vehicleNumberController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال أرقام وحروف اللوحة المعدنية';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'رقم اللوحة المعدنية (مثال: أ ب ج 1234)',
                    prefixIcon: Icon(Icons.tag, color: AppColors.textLight),
                    fillColor: AppColors.background,
                  ),
                  style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),

                // Vehicle Category Selector
                Text(
                  'نوع المركبة',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Stack(
                    children: [
                      AnimatedAlign(
                        alignment: _vehicleCategory == 'private_car'
                            ? AlignmentDirectional.centerEnd
                            : AlignmentDirectional.centerStart,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: FractionallySizedBox(
                          widthFactor: 0.5,
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: AppColors.blueGradient,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.mediumBlue.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _vehicleCategory = 'motorcycle';
                                  _hasAC = false;
                                });
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.two_wheeler,
                                      size: 18,
                                      color: _vehicleCategory == 'motorcycle' ? Colors.white : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'دراجة نارية',
                                      style: GoogleFonts.cairo(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _vehicleCategory == 'motorcycle' ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _vehicleCategory = 'private_car';
                                });
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.directions_car,
                                      size: 18,
                                      color: _vehicleCategory == 'private_car' ? Colors.white : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'سيارة ملاكي',
                                      style: GoogleFonts.cairo(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _vehicleCategory == 'private_car' ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Private Car Extra Fields
                if (_vehicleCategory == 'private_car') ...[
                  const SizedBox(height: 16),
                  // AC Switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.ac_unit, color: _hasAC ? AppColors.mediumBlue : AppColors.textLight, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'السيارة مكيفة؟',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Switch(
                          activeThumbColor: AppColors.mediumBlue,
                          value: _hasAC,
                          onChanged: (val) {
                            setState(() {
                              _hasAC = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Max Passengers
                  DropdownButtonFormField<int>(
                    initialValue: _maxPassengers,
                    items: List.generate(7, (i) => i + 1).map((count) {
                      return DropdownMenuItem(value: count, child: Text('$count راكب'));
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _maxPassengers = val ?? 4;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'عدد الركاب المسموح',
                      labelStyle: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.people_outline, color: AppColors.textLight),
                      fillColor: AppColors.background,
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Documents Upload Section
                Text(
                  'المستندات المطلوبة (10 صور)',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // National ID Front & Back side-by-side
                Text(
                  'صورة البطاقة الشخصية (وجهين)',
                  style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _buildUploadCard(
                        title: 'الوجه (الرئيسي)',
                        localPath: _idCardFrontPath,
                        isUploading: _uploadingIdFront,
                        isUploaded: _idCardFrontUrl != null,
                        onTap: () => _pickAndUploadImage(fieldKey: 'idCardFront'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildUploadCard(
                        title: 'الظهر (الخلفي)',
                        localPath: _idCardBackPath,
                        isUploading: _uploadingIdBack,
                        isUploaded: _idCardBackUrl != null,
                        onTap: () => _pickAndUploadImage(fieldKey: 'idCardBack'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Driver License Front & Back side-by-side
                Text(
                  'رخصة القيادة السارية (وجهين)',
                  style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _buildUploadCard(
                        title: 'رخصة القيادة - الوجه',
                        localPath: _driverLicenseFrontPath,
                        isUploading: _uploadingLicenseFront,
                        isUploaded: _driverLicenseFrontUrl != null,
                        onTap: () => _pickAndUploadImage(fieldKey: 'driverLicenseFront'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildUploadCard(
                        title: 'رخصة القيادة - الظهر',
                        localPath: _driverLicenseBackPath,
                        isUploading: _uploadingLicenseBack,
                        isUploaded: _driverLicenseBackUrl != null,
                        onTap: () => _pickAndUploadImage(fieldKey: 'driverLicenseBack'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Vehicle or Motorcycle License (وش وضهر)
                Text(
                  'رخصة السيارة أو الدراجة النارية (وجهين)',
                  style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _buildUploadCard(
                        title: 'الرخصة - الوجه',
                        localPath: _vehicleLicenseFrontPath,
                        isUploading: _uploadingVehicleLicenseFront,
                        isUploaded: _vehicleLicenseFrontUrl != null,
                        onTap: () => _pickAndUploadImage(fieldKey: 'vehicleLicenseFront'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildUploadCard(
                        title: 'الرخصة - الظهر',
                        localPath: _vehicleLicenseBackPath,
                        isUploading: _uploadingVehicleLicenseBack,
                        isUploaded: _vehicleLicenseBackUrl != null,
                        onTap: () => _pickAndUploadImage(fieldKey: 'vehicleLicenseBack'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Vehicle images (outside and inside, min 4)
                Text(
                  'صورة المركبة من الخارج ومن الداخل (4 صور)',
                  style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    final hasLocalPath = _vehicleImagesPaths.length > index;
                    final hasUrl = _vehicleImagesUrls.length > index;
                    return _buildUploadCard(
                      title: 'صورة المركبة ${index + 1}',
                      localPath: hasLocalPath ? _vehicleImagesPaths[index] : null,
                      isUploading: _uploadingVehicleImages[index],
                      isUploaded: hasUrl,
                      onTap: () => _pickAndUploadImage(fieldKey: 'vehicleImage', vehicleImageIndex: index),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Submit Button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: _isAllDocumentsUploaded()
                          ? AppColors.blueGradient
                          : [Colors.grey.shade400, Colors.grey.shade400],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: _isAllDocumentsUploaded()
                        ? [
                            BoxShadow(
                              color: AppColors.mediumBlue.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: ElevatedButton(
                    onPressed: _isAllDocumentsUploaded() ? _onSubmit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      disabledForegroundColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'إرسال المستندات للمراجعة',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String? localPath,
    required bool isUploading,
    required bool isUploaded,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: isUploaded ? AppColors.mediumBlue.withValues(alpha: 0.02) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUploaded ? AppColors.mediumBlue.withValues(alpha: 0.3) : AppColors.border,
            width: isUploaded ? 1.5 : 1,
          ),
        ),
        child: isUploading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.mediumBlue),
                  ),
                ),
              )
            : localPath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(localPath),
                          fit: BoxFit.cover,
                        ),
                        // Black overlay at bottom for title
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.5),
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: Text(
                              title,
                              style: GoogleFonts.cairo(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        // Success Badge
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: 10,
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_upload_outlined,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'اضغط للرفع',
                        style: GoogleFonts.cairo(
                          fontSize: 9,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
