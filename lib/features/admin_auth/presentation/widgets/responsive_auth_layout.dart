import 'package:flutter/material.dart';

class ResponsiveAuthLayout extends StatelessWidget {
  final Widget child;

  const ResponsiveAuthLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          if (isDesktop) {
            return Row(
              children: [
                // Left Panel: Decorative & Branding Banner
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // App Branding Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'inRide Control Center',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),

                        // Center Value Proposition
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Secure Enterprise\nAdmin Portal',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Manage users, drivers, trips, and ride-hailing operations with encrypted Supabase authentication & Row-Level Security.',
                              style: TextStyle(
                                color: Colors.blue.shade100,
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildFeatureRow(
                              Icons.verified_user_rounded,
                              'Role-Based Authorization',
                              'Strict super_admin and admin verification',
                            ),
                            const SizedBox(height: 16),
                            _buildFeatureRow(
                              Icons.security_rounded,
                              'Database Row-Level Security',
                              'Hardware-isolated row access policies',
                            ),
                            const SizedBox(height: 16),
                            _buildFeatureRow(
                              Icons.lock_clock_rounded,
                              'Automatic Session Guarding',
                              'GoRouter deep-link route protection',
                            ),
                          ],
                        ),

                        // Footer Copyright
                        Text(
                          '© 2026 inRide Inc. All rights reserved.',
                          style: TextStyle(
                            color: Colors.blue.shade200.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Panel: Form Card Container
                Expanded(
                  flex: 6,
                  child: Container(
                    color: const Color(0xFFF8FAFC),
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Mobile / Tablet Fallback Layout
          return Container(
            color: const Color(0xFFF8FAFC),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'inRide Admin',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.lightBlueAccent, size: 20),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.blue.shade200,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
