import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/state/global_state.dart';
import '../../features/driver/presentation/pages/driver_home_page.dart';
import '../../features/passenger/presentation/pages/passenger_home_page.dart';

class SimulationControllerOverlay extends StatefulWidget {
  final Widget child;
  const SimulationControllerOverlay({super.key, required this.child});

  @override
  State<SimulationControllerOverlay> createState() => _SimulationControllerOverlayState();
}

class _SimulationControllerOverlayState extends State<SimulationControllerOverlay> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    GlobalState.instance.addListener(_onStateChange);
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    GlobalState.instance.removeListener(_onStateChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = GlobalState.instance;

    return Stack(
      children: [
        // The Actual App Content
        widget.child,

        // Floating Simulation Trigger Button
        Positioned(
          left: 16,
          bottom: _isExpanded ? 340 : 80,
          child: Material(
            type: MaterialType.transparency,
            child: FloatingActionButton.extended(
              onPressed: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              icon: Icon(_isExpanded ? Icons.close : Icons.tune),
              label: Text(
                _isExpanded ? 'إغلاق المحاكي' : 'لوحة المحاكاة التفاعلية',
                style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),

        // Expanded Simulation Control Panel Sheet
        if (_isExpanded)
          Positioned(
            left: 16,
            right: 16,
            bottom: 80,
            child: Material(
              elevation: 10,
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.3), width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '🎛️ أدوات المحاكاة الفورية (للاختبار)',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'الحالة: ${state.rideStatus.name}',
                            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    // Controls Grid
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Role selection shortcut
                        _buildSimButton(
                          label: 'التبديل لراكب 🚶',
                          onPressed: () {
                            state.selectRole(UserRole.rider);
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => const PassengerHomePage()),
                              (route) => false,
                            );
                          },
                        ),
                        _buildSimButton(
                          label: 'التبديل لسائق 🚗',
                          onPressed: () {
                            state.selectRole(UserRole.driver);
                            if (state.verificationStatus == DriverVerificationStatus.verified) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (context) => const DriverHomePage()),
                                (route) => false,
                              );
                            } else {
                              state.verificationStatus = DriverVerificationStatus.verified;
                              state.update();
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (context) => const DriverHomePage()),
                                (route) => false,
                              );
                            }
                          },
                        ),
                        // Admin Verification Shortcuts
                        _buildSimButton(
                          label: 'اعتماد السائق فوراً ✅',
                          onPressed: () {
                            state.verificationStatus = DriverVerificationStatus.verified;
                            state.update();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم تفعيل واعتماد حساب السائق بنجاح!', style: GoogleFonts.cairo()),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          },
                          color: Colors.green,
                        ),
                        _buildSimButton(
                          label: 'إلغاء التوثيق ❌',
                          onPressed: () {
                            state.verificationStatus = DriverVerificationStatus.unregistered;
                            state.update();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم إلغاء اعتماد السائق (غير مسجل)', style: GoogleFonts.cairo()),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          },
                          color: Colors.red,
                        ),

                        // Ride lifecycle shortcuts
                        if (state.rideStatus == RideStatus.searching)
                          _buildSimButton(
                            label: 'توليد عروض أسائقين قريبة ⚡',
                            onPressed: () {
                              // Force bids immediately
                              state.rideStatus = RideStatus.driverBidding;
                              state.driverOffers = [
                                DriverOffer(
                                  driverId: 'mock_driver_1',
                                  driver: DriverInfo(
                                    name: 'محمد سامي',
                                    rating: 4.9,
                                    vehicleType: 'اسكوتر',
                                    vehicleName: 'فيسبا',
                                    vehicleColor: 'أسود',
                                    licensePlate: 'أ ب 1234',
                                    avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200',
                                  ),
                                  price: state.offeredFare,
                                  etaMinutes: 3,
                                ),
                                DriverOffer(
                                  driverId: 'mock_driver_2',
                                  driver: DriverInfo(
                                    name: 'أحمد محمود',
                                    rating: 4.8,
                                    vehicleType: 'عربية',
                                    vehicleName: 'هيونداي إلنترا',
                                    vehicleColor: 'فضي',
                                    licensePlate: 'ج د 5678',
                                    avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200',
                                  ),
                                  price: state.offeredFare + 10.0,
                                  etaMinutes: 6,
                                ),
                              ];
                              state.update();
                            },
                            color: Colors.blue,
                          ),

                        if (state.rideStatus == RideStatus.driverOnWay)
                          _buildSimButton(
                            label: 'محاكاة وصول السائق 🏁',
                            onPressed: () {
                              state.rideStatus = RideStatus.arrived;
                              state.driverProgress = 0.0;
                              state.update();
                            },
                            color: Colors.orange,
                          ),

                        if (state.rideStatus == RideStatus.arrived)
                          _buildSimButton(
                            label: 'محاكاة بدء الرحلة 🚀',
                            onPressed: () {
                              state.startTrip();
                            },
                            color: Colors.teal,
                          ),

                        if (state.rideStatus == RideStatus.tripStarted)
                          _buildSimButton(
                            label: 'محاكاة إنهاء الرحلة الدفع 💳',
                            onPressed: () {
                              state.completeTrip();
                            },
                            color: Colors.indigo,
                          ),
                          
                        _buildSimButton(
                          label: 'إعادة ضبط الرحلات 🔄',
                          onPressed: () {
                            state.resetRide();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم إعادة تعيين كافة الطلبات النشطة.', style: GoogleFonts.cairo()),
                                backgroundColor: Colors.black87,
                              ),
                            );
                          },
                          color: Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ملاحظة: تتيح لك هذه اللوحة اختبار سيناريو الرحلة كاملاً (الطلب، المزايدة، القبول، التتبع، الوصول، الدفع) مباشرة دون الحاجة لأجهزة إضافية.',
                      style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSimButton({
    required String label,
    required VoidCallback onPressed,
    Color color = Colors.purple,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
