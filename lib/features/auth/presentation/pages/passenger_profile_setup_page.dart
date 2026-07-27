import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/map_coordinates_helper.dart';
import 'package:inride_app/features/passenger/presentation/pages/passenger_home_page.dart';

class PassengerProfileSetupPage extends StatefulWidget {
  const PassengerProfileSetupPage({super.key});

  @override
  State<PassengerProfileSetupPage> createState() => _PassengerProfileSetupPageState();
}

class _PassengerProfileSetupPageState extends State<PassengerProfileSetupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedGender = 'ذكر';
  bool _isLoading = false;
  bool _isDetectingLocation = false;

  // Tracks whether the phone number was pre-filled from a verified phone auth session.
  // If true, the phone field is read-only (user logged in with phone → no need to re-enter).
  bool _isPhoneFromAuth = false;

  @override
  void initState() {
    super.initState();
    _prefillPhoneFromAuth();
  }

  /// Pre-fill phone number from Supabase Auth (if user registered via phone/OTP).
  /// The phone number is already verified — so we make the field read-only.
  void _prefillPhoneFromAuth() {
    final state = GlobalState.instance;

    // Priority 1: Supabase Auth verified phone number
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    final authPhone = supabaseUser?.phone;

    // Priority 2: GlobalState.phoneNumber (may have been set from Supabase Auth response)
    final statePhone = state.phoneNumber;

    String? rawPhone;
    if (authPhone != null && authPhone.isNotEmpty) {
      rawPhone = authPhone;
      _isPhoneFromAuth = true;
      debugPrint('[ProfileSetup] ✓ Phone pre-filled from Supabase Auth: $rawPhone');
    } else if (statePhone != null && statePhone.isNotEmpty) {
      rawPhone = statePhone;
      _isPhoneFromAuth = true;
      debugPrint('[ProfileSetup] ✓ Phone pre-filled from GlobalState: $rawPhone');
    }

    if (rawPhone != null) {
      // Convert E.164 (+201012345678) to local display format (01012345678)
      final displayPhone = _toLocalFormat(rawPhone);
      _phoneController.text = displayPhone;
      debugPrint('[ProfileSetup] ✓ Phone field set to: $displayPhone (readOnly: $_isPhoneFromAuth)');
    }
  }

  /// Converts E.164 phone number to Egyptian local format for display.
  /// e.g., "+201012345678" → "01012345678"
  ///       "201012345678"  → "01012345678"
  String _toLocalFormat(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    // Remove Egyptian country code 20 and re-add leading 0
    if (cleaned.startsWith('20') && cleaned.length == 12) {
      return '0${cleaned.substring(2)}'; // → 01XXXXXXXXX
    }
    return cleaned;
  }

  /// Converts local or E.164 phone to E.164 for storage.
  /// e.g., "01012345678" → "+201012345678"
  String _toE164(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.startsWith('01') && cleaned.length == 11) {
      return '+20${cleaned.substring(1)}';
    } else if (cleaned.startsWith('0') && cleaned.length == 11) {
      return '+20${cleaned.substring(1)}';
    } else if (cleaned.startsWith('20') && cleaned.length == 12) {
      return '+$cleaned';
    } else if (!cleaned.startsWith('0') && cleaned.length == 10) {
      return '+20$cleaned';
    }
    return '+$cleaned';
  }

  void _detectLocation() async {
    setState(() {
      _isDetectingLocation = true;
    });

    try {
      final locationService = LocationService.instance;
      final position = await locationService.getCurrentLocation();
      if (position != null) {
        final address = await MapCoordinatesHelper.reverseGeocode(
          position.latitude,
          position.longitude,
        );
        setState(() {
          _addressController.text = address;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل تحديد الموقع. يرجى التأكد من تشغيل الـ GPS ومنح صلاحية الموقع للتطبيق.',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ProfileSetup] Error detecting location: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
        });
      }
    }
  }

  void _onConfirmPressed() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final state = GlobalState.instance;
        final uid = state.userUid;
        final nameText = _nameController.text.trim();
        final addressText = _addressController.text.trim();

        // Use the phone from the controller (may be pre-filled from auth or manually entered)
        final rawPhoneInput = _phoneController.text.trim();
        final e164Phone = _toE164(rawPhoneInput);

        debugPrint('[ProfileSetup] ▶ Saving profile for uid: $uid');
        debugPrint('[ProfileSetup] ▶ name: $nameText, phone: $e164Phone, gender: $_selectedGender');

        if (uid != null) {
          // 1. Ensure user row exists in 'users' table FIRST (satisfies foreign key constraint)
          await Supabase.instance.client.from('users').upsert({
            'id': uid,
            'name': nameText,
            'phone_number': e164Phone,
            'role': 'rider',
          });
          debugPrint('[ProfileSetup] ✓ users table updated');

          // 2. Insert/update passenger profile in 'passengers' table
          await Supabase.instance.client.from('passengers').upsert({
            'id': uid,
            'name': nameText,
            'gender': _selectedGender,
            'address': addressText,
            'phone': e164Phone,
            'created_at': DateTime.now().toIso8601String(),
          });
          debugPrint('[ProfileSetup] ✓ passengers table updated');

          // Update GlobalState
          state.passengerName = nameText;
          state.userName = nameText;
          state.passengerGender = _selectedGender;
          state.passengerAddress = addressText;
          state.phoneNumber = e164Phone;

          debugPrint('[ProfileSetup] ✓ Profile saved — navigating to PassengerHomePage');

          if (!mounted) return;
          // Route to home
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const PassengerHomePage()),
            (route) => false,
          );
        } else {
          throw Exception('لم يتم التعرف على المستخدم. يرجى تسجيل الدخول مرة أخرى.');
        }
      } catch (e) {
        debugPrint('[ProfileSetup] ✗ Error saving profile: $e');
        setState(() {
          _isLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حفظ البيانات: $e', style: GoogleFonts.cairo()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'إعداد الملف الشخصي',
          style: GoogleFonts.cairo(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative background elements
            Positioned(
              top: -60,
              left: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.mediumBlue.withValues(alpha: 0.02),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    // Styled avatar container with camera edit button
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            height: 110,
                            width: 110,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_outline_rounded,
                              size: 54,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(colors: AppColors.blueGradient),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Name Input Field
                    Text(
                      'الاسم الكامل',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال اسمك الكامل';
                        }
                        if (value.trim().length < 3) {
                          return 'الاسم قصير جداً';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'مثال: أحمد محمد',
                        fillColor: AppColors.background,
                        filled: true,
                        prefixIcon: const Icon(Icons.person_outline_rounded,
                            color: AppColors.textLight),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: AppColors.mediumBlue, width: 2),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      ),
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Phone Input Field — read-only if pre-filled from auth
                    Text(
                      'رقم الهاتف الجوال',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      // If phone was pre-filled from phone-auth, lock it (already verified by Supabase)
                      readOnly: _isPhoneFromAuth,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال رقم هاتفك الجوال';
                        }
                        final cleaned = value.trim().replaceAll(RegExp(r'[^\d]'), '');
                        if (cleaned.length < 10) {
                          return 'يرجى إدخال رقم هاتف صحيح';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'مثال: 01012345678',
                        fillColor: _isPhoneFromAuth
                            ? const Color(0xFFF0F4FF) // Subtle blue tint for locked field
                            : AppColors.background,
                        filled: true,
                        prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textLight),
                        // Show lock icon when field is locked (verified from auth)
                        suffixIcon: _isPhoneFromAuth
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: Icon(
                                  Icons.lock_outline_rounded,
                                  color: AppColors.mediumBlue,
                                  size: 20,
                                ),
                              )
                            : null,
                        // Subtle helper text when phone is locked
                        helperText:
                            _isPhoneFromAuth ? 'تم التحقق من رقم الهاتف عند التسجيل' : null,
                        helperStyle: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.mediumBlue,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: _isPhoneFromAuth
                                ? AppColors.mediumBlue.withValues(alpha: 0.4)
                                : AppColors.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: AppColors.mediumBlue, width: 2),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      ),
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        color: _isPhoneFromAuth
                            ? AppColors.mediumBlue
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Address/City Input Field with Auto-detect button
                    Text(
                      'المدينة / العنوان الحالي',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressController,
                      validator: (value) {
                        // Address is optional — user can auto-detect or enter later
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'مثال: الدقي، الجيزة',
                        fillColor: AppColors.background,
                        filled: true,
                        prefixIcon: const Icon(Icons.location_on_outlined,
                            color: AppColors.textLight),
                        suffixIcon: _isDetectingLocation
                            ? const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: AppColors.mediumBlue,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.my_location_rounded,
                                  color: AppColors.mediumBlue,
                                  size: 22,
                                ),
                                onPressed: _detectLocation,
                                tooltip: 'تحديد تلقائي للموقع',
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: AppColors.mediumBlue, width: 2),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      ),
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Gender Selection
                    Text(
                      'النوع',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGenderCard(
                            gender: 'ذكر',
                            icon: Icons.male_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildGenderCard(
                            gender: 'أنثى',
                            icon: Icons.female_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),

                    // Submit Button with Blue Gradient & Shadow
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: AppColors.blueGradient,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.mediumBlue.withValues(alpha: 0.3),
                            blurRadius: 16,
                            spreadRadius: 1,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _onConfirmPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                'بدء الاستخدام',
                                style: GoogleFonts.cairo(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderCard({required String gender, required IconData icon}) {
    final isSelected = _selectedGender == gender;

    return GestureDetector(
      onTap: () => setState(() => _selectedGender = gender),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.mediumBlue : AppColors.border,
            width: isSelected ? 2.2 : 1.0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.mediumBlue.withValues(alpha: 0.08),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.005),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.mediumBlue : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              gender,
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.mediumBlue : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
