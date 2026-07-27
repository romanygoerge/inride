import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/state/global_state.dart';
import '../../shared/widgets/profile_image_editor.dart';
import '../../core/utils/snappy_page_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'ratings_page.dart';
import '../driver_registration/presentation/pages/doc_upload_page.dart';
import '../driver_registration/presentation/pages/review_pending_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditingName = false;
  late TextEditingController _nameController;

  // Advertising & App Options toggles
  bool _receivePromos = true;
  bool _personalizedAds = true;
  bool _partnerAlerts = false;

  final List<String> avatarPresets = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=200',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=200',
    'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?q=80&w=200',
  ];

  @override
  void initState() {
    super.initState();
    final state = GlobalState.instance;
    _nameController = TextEditingController(
      text: state.userName ?? (state.currentRole == UserRole.rider ? (state.passengerName ?? 'راكب') : 'كابتن'),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.mediumBlue),
              const SizedBox(height: 20),
              Text(
                'جاري رفع الصورة الشخصية...',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'يرجى عدم إغلاق التطبيق',
                style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onPickImage(ImageSource source, GlobalState state) async {
    Navigator.pop(context); // Close selection sheet

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 90,
      );

      if (image == null) return;

      if (mounted) {
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);

        final String? croppedPath = await navigator.push<String>(
          SnappyPageRoute(page: ProfileImageEditor(imagePath: image.path),
          ),
        );

        if (croppedPath != null && mounted) {
          _showLoadingDialog();

          try {
            await state.uploadAndSetProfileImage(croppedPath);
            if (mounted) {
              navigator.pop(); // Dismiss loading
              messenger.showSnackBar(
                SnackBar(
                  content: Text('تم تحديث الصورة الشخصية بنجاح!', style: GoogleFonts.cairo()),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              navigator.pop(); // Dismiss loading
              messenger.showSnackBar(
                SnackBar(
                  content: Text('فشل رفع الصورة: $e', style: GoogleFonts.cairo()),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ProfilePage._onPickImage] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء التقاط الصورة. يرجى التأكد من الصلاحيات والوصول.', style: GoogleFonts.cairo()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showAvatarSelector(BuildContext context, GlobalState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final hasAvatar = state.userAvatarUrl != null && state.userAvatarUrl!.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'الصورة الشخصية',
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
                onTap: () => _onPickImage(ImageSource.camera, state),
              ),
              const Divider(color: AppColors.border, height: 1),

              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.mediumBlue),
                title: Text('اختيار من معرض الصور', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                onTap: () => _onPickImage(ImageSource.gallery, state),
              ),

              if (hasAvatar) ...[
                const Divider(color: AppColors.border, height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.error),
                  title: Text('حذف الصورة الحالية', style: GoogleFonts.cairo(fontWeight: FontWeight.w600, color: AppColors.error)),
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    navigator.pop(); // Close bottom sheet
                    _showLoadingDialog();
                    try {
                      await state.deleteProfileImage();
                      if (mounted) {
                        navigator.pop(); // Dismiss loading dialog
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('تم حذف الصورة الشخصية بنجاح.', style: GoogleFonts.cairo()),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        navigator.pop(); // Dismiss loading dialog
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('فشل حذف الصورة: $e', style: GoogleFonts.cairo()),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarWidget(GlobalState state, {double radius = 46}) {
    final hasAvatar = state.userAvatarUrl != null && state.userAvatarUrl!.isNotEmpty;
    final displayName = state.userName ?? (state.currentRole == UserRole.rider ? (state.passengerName ?? '') : 'كابتن');
    
    if (hasAvatar) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(state.userAvatarUrl!),
        backgroundColor: AppColors.background,
      );
    } else {
      final firstLetter = displayName.isNotEmpty ? displayName.trim().characters.first.toUpperCase() : '?';
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.mediumBlue.withValues(alpha: 0.1),
        child: Text(
          firstLetter,
          style: GoogleFonts.outfit(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
            color: AppColors.mediumBlue,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = GlobalState.instance;
    final isRider = state.currentRole == UserRole.rider;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'الملف الشخصي',
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
              // 1. Profile Picture Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Avatar
                      GestureDetector(
                        onTap: () => _showAvatarSelector(context, state),
                        child: Stack(
                          alignment: Alignment.bottomLeft,
                          children: [
                            _buildAvatarWidget(state, radius: 46),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.mediumBlue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Name Section with Inline Editor
                      if (!_isEditingName)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              state.userName ?? (isRider ? (state.passengerName ?? 'راكب') : 'كابتن'),
                              style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isEditingName = true;
                                });
                              },
                              child: const Icon(Icons.edit, size: 18, color: AppColors.mediumBlue),
                            ),
                          ],
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: () async {
                                  final newName = _nameController.text.trim();
                                  if (newName.isNotEmpty) {
                                    await state.updateName(newName);
                                    setState(() {
                                      _isEditingName = false;
                                    });
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _nameController.text = state.userName ?? (isRider ? (state.passengerName ?? 'راكب') : 'كابتن');
                                    _isEditingName = false;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            SnappyPageRoute(page: RatingsPage(userId: state.userUid ?? ''),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star, color: Colors.orange, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${state.userRating.toStringAsFixed(1)} ${isRider ? "تقييم الراكب" : "تقييم الكابتن"} (عرض المراجعات ↗)',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                color: AppColors.mediumBlue,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Dual Role & Account Status Card
              _buildDualRoleCard(context, state),

              const SizedBox(height: 20),

              // 2. Personal Information Heading
              Text(
                'البيانات الشخصية',
                style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),

              // Info Items
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      _buildInfoTile(
                        icon: Icons.phone_android_outlined,
                        label: 'رقم الهاتف المعرّف (مغلق)',
                        value: state.phoneNumber ?? '+20 10 1234 5678',
                      ),
                      const Divider(color: AppColors.border, height: 16),
                      _buildInfoTile(
                        icon: Icons.badge_outlined,
                        label: 'حالة الحساب الرسمي',
                        value: 'نشط',
                        valueColor: AppColors.success,
                      ),
                      if (!isRider && state.vehicleName != null) ...[
                        const Divider(color: AppColors.border, height: 16),
                        _buildInfoTile(
                          icon: Icons.directions_car_filled_outlined,
                          label: 'المركبة المسجلة للعمل',
                          value: '${state.vehicleName} (${state.vehicleNumber})',
                        ),
                      ],
                      if (!isRider && state.driverVehicleCategory != null) ...[
                        const Divider(color: AppColors.border, height: 16),
                        _buildInfoTile(
                          icon: state.driverVehicleCategory == 'motorcycle' ? Icons.two_wheeler : Icons.directions_car,
                          label: 'نوع المركبة',
                          value: state.driverVehicleCategory == 'motorcycle' ? 'دراجة نارية' : 'سيارة ملاكي',
                        ),
                        if (state.driverVehicleCategory == 'private_car') ...[
                          const Divider(color: AppColors.border, height: 16),
                          _buildInfoTile(
                            icon: Icons.ac_unit,
                            label: 'التكييف',
                            value: state.driverHasAC ? 'نعم - مكيفة ❄️' : 'لا',
                            valueColor: state.driverHasAC ? AppColors.mediumBlue : null,
                          ),
                          const Divider(color: AppColors.border, height: 16),
                          _buildInfoTile(
                            icon: Icons.people_outline,
                            label: 'عدد الركاب المسموح',
                            value: '${state.driverMaxPassengers} راكب',
                          ),
                        ],
                      ],
                      if (isRider) ...[
                        const Divider(color: AppColors.border, height: 16),
                        _buildInfoTile(
                          icon: Icons.wc_outlined,
                          label: 'النوع (الجنس)',
                          value: state.passengerGender ?? 'ذكر',
                        ),
                        const Divider(color: AppColors.border, height: 16),
                        _buildInfoTile(
                          icon: Icons.home_outlined,
                          label: 'العنوان المفضل',
                          value: state.passengerAddress ?? 'القاهرة، مصر',
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Driver Documents Section
              if (!isRider && (state.driverNationalIdUrl != null || state.driverLicenseUrl != null || state.driverVehicleFrontUrl != null)) ...[
                const SizedBox(height: 24),
                Text(
                  'المستندات والرخص',
                  style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Document thumbnails grid
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (state.driverNationalIdUrl != null)
                              _buildDocThumbnail(
                                label: 'البطاقة الشخصية',
                                url: state.driverNationalIdUrl!,
                                icon: Icons.badge_outlined,
                              ),
                            if (state.driverLicenseUrl != null)
                              _buildDocThumbnail(
                                label: 'رخصة القيادة',
                                url: state.driverLicenseUrl!,
                                icon: Icons.card_membership_outlined,
                              ),
                            if (state.driverVehicleFrontUrl != null)
                              _buildDocThumbnail(
                                label: 'رخصة المركبة',
                                url: state.driverVehicleFrontUrl!,
                                icon: Icons.description_outlined,
                              ),
                            ...state.driverVehicleImages.asMap().entries.map((entry) =>
                              _buildDocThumbnail(
                                label: 'صورة المركبة ${entry.key + 1}',
                                url: entry.value,
                                icon: Icons.photo_camera_outlined,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Vehicle Update Section for existing drivers
              if (!isRider && state.verificationStatus == DriverVerificationStatus.verified && state.driverVehicleCategory == null) ...[
                const SizedBox(height: 24),
                _buildVehicleUpdateCard(state),
              ],
              const SizedBox(height: 24),

              // 3. Settings / Options / Ads
              Text(
                'خيارات التطبيق والإعلان',
                style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                    _buildSettingsTile(
                      icon: Icons.language_outlined,
                      title: 'لغة التطبيق',
                      trailing: 'العربية',
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    _buildSettingsTile(
                      icon: Icons.notifications_none_outlined,
                      title: 'إعدادات الإشعارات',
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    _buildSettingsTile(
                      icon: Icons.verified_user_outlined,
                      title: 'الأمان والخصوصية',
                    ),
                    if (isRider) ...[
                      const Divider(color: AppColors.border, height: 1),
                      SwitchListTile(
                        activeTrackColor: AppColors.mediumBlue.withValues(alpha: 0.3),
                        activeThumbColor: AppColors.mediumBlue,
                        title: Text(
                          'تلقي العروض الترويجية والإعلانات',
                          style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          'تلقي إشعارات بالخصومات والعروض الحصرية',
                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        value: _receivePromos,
                        onChanged: (val) {
                          setState(() {
                            _receivePromos = val;
                          });
                        },
                      ),
                      const Divider(color: AppColors.border, height: 1),
                      SwitchListTile(
                        activeTrackColor: AppColors.mediumBlue.withValues(alpha: 0.3),
                        activeThumbColor: AppColors.mediumBlue,
                        title: Text(
                          'إعلانات مخصصة حسب اهتماماتك',
                          style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          'تحسين تجربة الإعلانات لتلائم احتياجاتك',
                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        value: _personalizedAds,
                        onChanged: (val) {
                          setState(() {
                            _personalizedAds = val;
                          });
                        },
                      ),
                      const Divider(color: AppColors.border, height: 1),
                      SwitchListTile(
                        activeTrackColor: AppColors.mediumBlue.withValues(alpha: 0.3),
                        activeThumbColor: AppColors.mediumBlue,
                        title: Text(
                          'إشعارات وتنبيهات الشركاء',
                          style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          'تلقي إعلانات وتحديثات من شركائنا الموثوقين',
                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        value: _partnerAlerts,
                        onChanged: (val) {
                          setState(() {
                            _partnerAlerts = val;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textLight, size: 20),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
              ),
              Text(
                value,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 20),
      title: Text(
        title,
        style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) ...[
            Text(
              trailing,
              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textLight),
            ),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.arrow_forward_ios_outlined, color: AppColors.textLight, size: 12),
        ],
      ),
      dense: true,
      onTap: () {},
    );
  }

  Widget _buildDocThumbnail({
    required String label,
    required String url,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () => _showDocPreview(label, url),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          color: AppColors.background,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: url,
                width: 60,
                height: 50,
                fit: BoxFit.cover,
                placeholder: (context, url) => const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mediumBlue),
                ),
                errorWidget: (context, url, error) => Icon(icon, color: AppColors.textLight, size: 28),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.cairo(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showDocPreview(String label, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(label, style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppColors.mediumBlue),
                ),
                errorWidget: (context, url, error) => Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      const Icon(Icons.broken_image_outlined, size: 48, color: AppColors.textLight),
                      const SizedBox(height: 8),
                      Text('فشل تحميل الصورة', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _vehicleUpdateCategory = 'motorcycle';
  bool _vehicleUpdateHasAC = false;
  int _vehicleUpdateMaxPassengers = 4;
  bool _isSavingVehicleUpdate = false;

  Widget _buildVehicleUpdateCard(GlobalState state) {
    return StatefulBuilder(
      builder: (context, setCardState) {
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.orange.shade300),
          ),
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تحديث بيانات المركبة مطلوب',
                        style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'يرجى تحديد نوع مركبتك وبيانات إضافية لتحسين تجربة الركاب.',
                  style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),

                // Category selector
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Stack(
                    children: [
                      AnimatedAlign(
                        alignment: _vehicleUpdateCategory == 'private_car'
                            ? AlignmentDirectional.centerEnd
                            : AlignmentDirectional.centerStart,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: FractionallySizedBox(
                          widthFactor: 0.5,
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: AppColors.blueGradient),
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setCardState(() {
                                _vehicleUpdateCategory = 'motorcycle';
                                _vehicleUpdateHasAC = false;
                              }),
                              behavior: HitTestBehavior.opaque,
                              child: Center(
                                child: Text(
                                  'دراجة نارية',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12, fontWeight: FontWeight.bold,
                                    color: _vehicleUpdateCategory == 'motorcycle' ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setCardState(() { _vehicleUpdateCategory = 'private_car'; }),
                              behavior: HitTestBehavior.opaque,
                              child: Center(
                                child: Text(
                                  'سيارة ملاكي',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12, fontWeight: FontWeight.bold,
                                    color: _vehicleUpdateCategory == 'private_car' ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_vehicleUpdateCategory == 'private_car') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.ac_unit, color: _vehicleUpdateHasAC ? AppColors.mediumBlue : AppColors.textLight, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('مكيفة؟', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      Switch(
                        activeThumbColor: AppColors.mediumBlue,
                        value: _vehicleUpdateHasAC,
                        onChanged: (val) => setCardState(() { _vehicleUpdateHasAC = val; }),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: _vehicleUpdateMaxPassengers,
                    items: List.generate(7, (i) => i + 1).map((c) => DropdownMenuItem(value: c, child: Text('$c راكب'))).toList(),
                    onChanged: (val) => setCardState(() { _vehicleUpdateMaxPassengers = val ?? 4; }),
                    decoration: InputDecoration(
                      labelText: 'عدد الركاب',
                      labelStyle: GoogleFonts.cairo(fontSize: 12),
                      prefixIcon: const Icon(Icons.people_outline, size: 20),
                      isDense: true,
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isSavingVehicleUpdate ? null : () async {
                    setCardState(() { _isSavingVehicleUpdate = true; });
                    try {
                      await state.updateDriverVehicleDetails(
                        vehicleCategory: _vehicleUpdateCategory,
                        hasAC: _vehicleUpdateHasAC,
                        maxPassengers: _vehicleUpdateMaxPassengers,
                      );
                      if (!context.mounted) return;
                      setState(() {}); // Refresh profile
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم تحديث بيانات المركبة بنجاح!', style: GoogleFonts.cairo()),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('فشل التحديث: $e', style: GoogleFonts.cairo()),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    } finally {
                      setCardState(() { _isSavingVehicleUpdate = false; });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mediumBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isSavingVehicleUpdate
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('حفظ بيانات المركبة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDualRoleCard(BuildContext context, GlobalState state) {
    final isRider = state.currentRole == UserRole.rider;
    final hasDual = state.hasDualRole;
    final hasPassenger = state.hasPassengerProfile;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: hasDual ? AppColors.mediumBlue.withValues(alpha: 0.4) : AppColors.border,
          width: hasDual ? 1.5 : 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: hasDual
              ? LinearGradient(
                  colors: [
                    AppColors.mediumBlue.withValues(alpha: 0.05),
                    Colors.white,
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                )
              : null,
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.mediumBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasDual ? Icons.badge_outlined : (isRider ? Icons.person_outline : Icons.directions_car_outlined),
                    color: AppColors.mediumBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            hasDual
                                ? 'حساب مزدوج (كابتن وراكب)'
                                : (hasPassenger ? 'حساب راكب' : 'حساب كابتن'),
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasDual
                                  ? Colors.amber.shade100
                                  : AppColors.mediumBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              hasDual ? '⭐ مفعّل بالكامل' : (isRider ? 'الوضع الحالي: راكب' : 'الوضع الحالي: كابتن'),
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: hasDual ? Colors.amber.shade900 : AppColors.mediumBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasDual
                            ? 'تم التحقق من بيانات الراكب ومستندات الكابتن. يمكنك التبديل بين الوضعين بكل سهولة.'
                            : (hasPassenger
                                ? 'لديك حساب راكب مفعّل. يمكنك طلب إنشاء حساب كابتن للعمل معنا.'
                                : 'لديك حساب كابتن. يمكنك تفعيل حساب الراكب بضغطة زر لحجز الرحلات.'),
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),

            // Role Status Badges List
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: hasPassenger ? Colors.green.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hasPassenger ? Colors.green.shade200 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasPassenger ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: hasPassenger ? Colors.green : Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            hasPassenger ? 'الراكب: مفعّل تلقائياً' : 'الراكب: غير مفعّل',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: hasPassenger ? Colors.green.shade900 : Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: state.verificationStatus == DriverVerificationStatus.verified
                          ? Colors.green.shade50
                          : (state.verificationStatus == DriverVerificationStatus.submitted
                              ? Colors.orange.shade50
                              : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: state.verificationStatus == DriverVerificationStatus.verified
                            ? Colors.green.shade200
                            : (state.verificationStatus == DriverVerificationStatus.submitted
                                ? Colors.orange.shade200
                                : Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          state.verificationStatus == DriverVerificationStatus.verified
                              ? Icons.check_circle
                              : (state.verificationStatus == DriverVerificationStatus.submitted
                                  ? Icons.hourglass_top
                                  : Icons.radio_button_unchecked),
                          color: state.verificationStatus == DriverVerificationStatus.verified
                              ? Colors.green
                              : (state.verificationStatus == DriverVerificationStatus.submitted
                                  ? Colors.orange
                                  : Colors.grey),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            state.verificationStatus == DriverVerificationStatus.verified
                                ? 'الكابتن: معتمد ومفعل'
                                : (state.verificationStatus == DriverVerificationStatus.submitted
                                    ? 'الكابتن: قيد المراجعة'
                                    : 'الكابتن: غير مسجل'),
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: state.verificationStatus == DriverVerificationStatus.verified
                                  ? Colors.green.shade900
                                  : (state.verificationStatus == DriverVerificationStatus.submitted
                                      ? Colors.orange.shade900
                                      : Colors.grey.shade700),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (hasDual) {
                    final newRole = isRider ? UserRole.driver : UserRole.rider;
                    await state.selectRole(newRole);
                    if (!context.mounted) return;
                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  } else if (isRider) {
                    if (state.verificationStatus == DriverVerificationStatus.submitted) {
                      Navigator.push(context, SnappyPageRoute(page: const ReviewPendingPage()));
                    } else {
                      Navigator.push(context, SnappyPageRoute(page: const DocUploadPage()));
                    }
                  } else {
                    await state.ensurePassengerProfileExists();
                    await state.selectRole(UserRole.rider);
                    if (!context.mounted) return;
                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  }
                },
                icon: Icon(
                  hasDual
                      ? Icons.swap_horiz
                      : (isRider ? Icons.directions_car : Icons.person_add),
                  size: 18,
                ),
                label: Text(
                  hasDual
                      ? (isRider ? 'التحويل إلى وضع الكابتن 🚗' : 'التحويل إلى وضع الراكب 👤')
                      : (isRider ? 'إنشاء حساب سائق / الانضمام ككابتن 🚗' : 'تفعيل حساب الراكب 👤'),
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mediumBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
