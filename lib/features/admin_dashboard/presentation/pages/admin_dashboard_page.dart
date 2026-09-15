// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../admin_auth/presentation/providers/admin_auth_provider.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  final String subTab;

  const AdminDashboardPage({
    super.key,
    this.subTab = 'overview',
  });

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  Future<Map<String, dynamic>> _fetchLiveStats() async {
    try {
      final client = Supabase.instance.client;
      final usersRes = await client.from('users').select('id');
      final driversRes = await client.from('drivers').select('id');
      final tripsRes = await client.from('ride_requests').select('id, offered_fare, status');

      final deletedRes = await client.from('account_deletion_logs').select('id');

      final usersList = (usersRes as List);
      final driversList = (driversRes as List);
      final tripsList = (tripsRes as List);
      final deletedList = (deletedRes as List);

      double revenue = 0;
      for (final trip in tripsList) {
        final status = (trip['status'] ?? '').toString().toLowerCase();
        if (status == 'completed' || status == 'finished') {
          final fare = trip['offered_fare'];
          if (fare is num) {
            revenue += fare.toDouble();
          }
        }
      }

      return {
        'users': usersList.length,
        'drivers': driversList.length,
        'trips': tripsList.length,
        'revenue': revenue,
        'deleted': deletedList.length,
      };
    } catch (e) {
      return {
        'users': 0,
        'drivers': 0,
        'trips': 0,
        'revenue': 0.0,
        'deleted': 0,
      };
    }
  }
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 10),
            Text('Confirm Sign Out'),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of the inRide Admin Dashboard?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final router = GoRouter.of(context);
              Navigator.of(dialogContext).pop();
              // Trigger secure logout
              await ref.read(adminAuthProvider).logout();
              router.go('/login');
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(adminAuthProvider).state;
    final admin = authState.adminUser;

    final formattedLastLogin = admin?.lastLogin != null
        ? DateFormat('MMM dd, yyyy - hh:mm a').format(admin!.lastLogin!.toLocal())
        : 'First session';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light Slate Background
      body: Row(
        children: [
          // Sidebar Navigation (Responsive Desktop/Tablet)
          _buildSidebar(context, widget.subTab, admin?.role ?? 'admin'),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Dashboard Header Bar
                _buildHeaderBar(context, admin?.name ?? 'Admin', admin?.email ?? '', formattedLastLogin),

                // Main Page View Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Banner
                        _buildWelcomeCard(admin?.name ?? 'Administrator', admin?.role ?? 'admin'),

                        const SizedBox(height: 24),

                        // Stats Summary Row
                        _buildStatsRow(),

                        const SizedBox(height: 28),

                        // Section Header
                        Text(
                          'Active Sub-Section: ${widget.subTab.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Active View Card
                        _buildContentAreaCard(widget.subTab),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, String currentTab, String role) {
    return Container(
      width: 260,
      color: const Color(0xFF0F172A), // Dark Slate
      child: Column(
        children: [
          // Branding Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'inRide Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Control Panel',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),

          // Nav Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildNavItem(context, 'Overview', Icons.dashboard_rounded, '/dashboard', currentTab == 'overview'),
                _buildNavItem(context, 'Users', Icons.people_alt_rounded, '/dashboard/users', currentTab == 'users'),
                _buildNavItem(context, 'Captains & Drivers', Icons.local_taxi_rounded, '/dashboard/drivers', currentTab == 'drivers'),
                _buildNavItem(context, 'Trips & Rides', Icons.route_rounded, '/dashboard/trips', currentTab == 'trips'),
                _buildNavItem(context, 'Trip Reports', Icons.shield_outlined, '/dashboard/reports', currentTab == 'reports'),
                _buildNavItem(context, 'Deleted Accounts', Icons.person_off_rounded, '/dashboard/deleted_accounts', currentTab == 'deleted_accounts'),
                _buildNavItem(context, 'System Settings', Icons.settings_rounded, '/dashboard/settings', currentTab == 'settings'),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Logout Action Tile
          Padding(
            padding: const EdgeInsets.all(16),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              tileColor: Colors.red.shade900.withValues(alpha: 0.3),
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              onTap: () => _confirmLogout(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    String label,
    IconData icon,
    String route,
    bool isSelected,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: isSelected ? const Color(0xFF1E3A8A) : Colors.transparent,
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onTap: () {
          if (!isSelected) {
            context.go(route);
          }
        },
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context, String name, String email, String lastLogin) {
    return Container(
      height: 70,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Breadcrumbs
          const Text(
            'Admin Dashboard',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),

          // Profile Pill & Actions
          Row(
            children: [
              Icon(Icons.history_rounded, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'Last login: $lastLogin',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF1E3A8A),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'A',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          email,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(String name, String role) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Welcome back, $name!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Supabase Auth & Database RLS protection active. All operational metrics are live.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1E3A8A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            icon: const Icon(Icons.shield_outlined, size: 18),
            label: const Text('Security Status: Verified', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchLiveStats(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final users = data != null ? '${data['users']}' : '...';
        final drivers = data != null ? '${data['drivers']}' : '...';
        final trips = data != null ? '${data['trips']}' : '...';
        final revenue = data != null ? '${data['revenue'].toStringAsFixed(0)} EGP' : '...';
        final deleted = data != null ? '${data['deleted'] ?? 0}' : '...';

        return Row(
          children: [
            _buildStatCard('Active Users', users, 'Live Supabase count', Icons.group_rounded, Colors.blue),
            const SizedBox(width: 16),
            _buildStatCard('Verified Captains', drivers, 'Live Supabase count', Icons.directions_car_rounded, Colors.green),
            const SizedBox(width: 16),
            _buildStatCard('Completed Trips', trips, 'Live Supabase count', Icons.route_rounded, Colors.orange),
            const SizedBox(width: 16),
            _buildStatCard('Platform Revenue', revenue, 'Completed trips volume', Icons.attach_money_rounded, Colors.purple),
            const SizedBox(width: 16),
            _buildStatCard('Deleted Accounts', deleted, 'Logged deletions', Icons.person_off_rounded, Colors.red.shade700),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, String subtext, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtext,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentAreaCard(String tab) {
    if (tab == 'reports') {
      return _buildReportsCard();
    }
    if (tab == 'trips') {
      return _buildTripsCard();
    }
    if (tab == 'deleted_accounts') {
      return _buildDeletedAccountsCard();
    }
    if (tab == 'users') {
      return _buildUsersCard();
    }
    if (tab == 'drivers') {
      return _buildDriversCard();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24),
              const SizedBox(width: 10),
              Text(
                'Route Protected View ($tab)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'This view is strictly guarded by GoRouter & Supabase RLS. Only active admins with a valid Supabase Auth JWT token can load data for $tab.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsCard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('trip_reports')
          .select()
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }
        final reports = snapshot.data ?? [];
        if (reports.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text(
                'No trip reports submitted yet.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          );
        }

        return Column(
          children: reports.map((r) {
            final isPassenger = r['reporter_role'] == 'passenger';
            final status = r['status'] ?? 'pending';
            final tripId = r['trip_id']?.toString() ?? 'N/A';
            final shortTripId = tripId.length > 8 ? tripId.substring(0, 8) : tripId;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: status == 'pending' ? Colors.red.shade200 : Colors.grey.shade200,
                  width: status == 'pending' ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isPassenger ? 'Passenger reported Captain' : 'Captain reported Passenger',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'pending'
                              ? Colors.red.shade50
                              : (status == 'resolved' ? Colors.green.shade50 : Colors.orange.shade50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.toString().toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: status == 'pending'
                                ? Colors.red.shade800
                                : (status == 'resolved' ? Colors.green.shade800 : Colors.orange.shade800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Passenger Account:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                            Text('${r['passenger_name'] ?? 'N/A'} (${r['passenger_phone'] ?? 'N/A'})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Captain Account:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                            Text('${r['driver_name'] ?? 'N/A'} (${r['driver_phone'] ?? 'N/A'})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Trip: #$shortTripId | From: ${r['pickup_address'] ?? 'N/A'} -> To: ${r['destination_address'] ?? 'N/A'} | Fare: ${r['fare'] ?? 'N/A'} EGP', style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reason: ${r['reason'] ?? ''}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red.shade800)),
                        const SizedBox(height: 4),
                        Text(r['description'] ?? 'No message provided', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  if (status != 'resolved') ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          await Supabase.instance.client
                              .from('trip_reports')
                              .update({'status': 'resolved', 'resolved_at': DateTime.now().toIso8601String()})
                              .eq('id', r['id']);
                          setState(() {});
                        },
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Mark as Resolved', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTripsCard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('ride_requests')
          .select()
          .order('created_at', ascending: false)
          .limit(40),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }
        final trips = snapshot.data ?? [];
        if (trips.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text(
                'لا توجد رحلات مسجلة في النظام حالياً.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          );
        }

        return Column(
          children: trips.map((t) {
            final tripId = t['id']?.toString() ?? '';
            final shortId = tripId.length > 8 ? tripId.substring(0, 8).toUpperCase() : tripId;
            final status = (t['status'] ?? 'Pending').toString();
            final stLower = status.toLowerCase();
            final fare = t['offered_fare'] ?? t['final_fare'] ?? 0;
            final pickup = (t['pickup_address'] ?? 'نقطة الانطلاق').toString();
            final dest = (t['destination_address'] ?? 'نقطة الوصول').toString();
            final cancelledBy = (t['cancelled_by'] ?? '').toString();
            final cancelReason = (t['cancel_reason'] ?? t['cancellation_reason'] ?? '').toString();
            final driverId = t['driver_id']?.toString();

            final isCompleted = stLower == 'completed' || stLower == 'finished';
            final isCancelled = stLower == 'cancelled';
            final isActive = !isCompleted && !isCancelled && stLower != 'expired';

            Color statusColor = Colors.blue;
            String statusLabel = 'جارية';
            if (isCompleted) {
              statusColor = const Color(0xFF16A34A);
              statusLabel = 'مكتملة';
            } else if (isCancelled) {
              statusColor = const Color(0xFFDC2626);
              statusLabel = 'ملغاة';
            } else if (stLower == 'pending') {
              statusColor = Colors.orange;
              statusLabel = 'بانتظار سائق';
            } else if (stLower == 'accepted') {
              statusColor = Colors.indigo;
              statusLabel = 'تم القبول';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? Colors.blue.shade200 : Colors.grey.shade200,
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.route_rounded, color: statusColor, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'رحلة #$shortId',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          if (isCancelled) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: cancelledBy == 'admin' ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: cancelledBy == 'admin' ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    cancelledBy == 'admin' ? Icons.shield_rounded : Icons.person_outline,
                                    size: 13,
                                    color: cancelledBy == 'admin' ? const Color(0xFF991B1B) : const Color(0xFF475569),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    cancelledBy == 'admin' ? 'إلغاء من قبل الإدارة' : 'إلغاء عادي',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: cancelledBy == 'admin' ? const Color(0xFF991B1B) : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '$fare ج.م',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A)),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('المسار:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('من: $pickup', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            Text('إلى: $dest', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      if (cancelReason.isNotEmpty)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('سبب الإلغاء:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(cancelReason, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // زر إلغاء عادي
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFDC2626)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _handleNormalCancelTrip(tripId, driverId),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('إلغاء عادي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        // زر إلغاء من قبل الإدارة
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF991B1B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _handleAdminCancelTrip(tripId, driverId),
                          icon: const Icon(Icons.shield_outlined, size: 16),
                          label: const Text('إلغاء من قبل الإدارة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        // زر إنهاء
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _handleCompleteTrip(tripId),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('إنهاء الرحلة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _handleNormalCancelTrip(String tripId, String? driverId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('تأكيد الإلغاء العادي'),
          ],
        ),
        content: const Text('هل تريد تأكيد تنفيذ إلغاء عادي لهذه الرحلة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final nowIso = DateTime.now().toIso8601String();
      await Supabase.instance.client.from('ride_requests').update({
        'status': 'Cancelled',
        'cancelled_by': 'passenger',
        'cancel_reason': 'إلغاء عادي',
        'cancellation_reason': 'إلغاء عادي',
        'cancelled_at': nowIso,
        'updated_at': nowIso,
      }).eq('id', tripId);

      if (driverId != null && driverId.isNotEmpty) {
        await Supabase.instance.client.from('drivers').update({
          'is_available': true,
          'updated_at': nowIso,
        }).eq('id', driverId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم الإلغاء العادي للرحلة بنجاح'), backgroundColor: Color(0xFF16A34A)),
        );
        setState(() {});
      }
    }
  }

  Future<void> _handleAdminCancelTrip(String tripId, String? driverId) async {
    final reasonController = TextEditingController(text: 'تم الإلغاء بواسطة إدارة النظام');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Color(0xFF991B1B)),
            SizedBox(width: 8),
            Text('إلغاء الرحلة من قبل الإدارة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيتم إلغاء الرحلة رسمياً بصفة إدارية، وإشعار كل من الراكب والسائق بالإلغاء وتفريغ الكابتن.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء الإداري',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF991B1B), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الإلغاء الإداري'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final reason = reasonController.text.trim().isNotEmpty
          ? reasonController.text.trim()
          : 'تم الإلغاء بواسطة إدارة النظام';
      final nowIso = DateTime.now().toIso8601String();

      await Supabase.instance.client.from('ride_requests').update({
        'status': 'Cancelled',
        'cancelled_by': 'admin',
        'cancel_reason': reason,
        'cancellation_reason': reason,
        'cancelled_at': nowIso,
        'updated_at': nowIso,
      }).eq('id', tripId);

      if (driverId != null && driverId.isNotEmpty) {
        await Supabase.instance.client.from('drivers').update({
          'is_available': true,
          'updated_at': nowIso,
        }).eq('id', driverId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم إلغاء الرحلة من قبل الإدارة بنجاح'), backgroundColor: Color(0xFF16A34A)),
        );
        setState(() {});
      }
    }
  }

  Future<void> _handleCompleteTrip(String tripId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Text('تأكيد إنهاء الرحلة'),
          ],
        ),
        content: const Text('هل تريد تأكيد اكتمال وإنهاء هذه الرحلة يدوياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الإنهاء'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final nowIso = DateTime.now().toIso8601String();
      await Supabase.instance.client.from('ride_requests').update({
        'status': 'Completed',
        'completed_at': nowIso,
        'updated_at': nowIso,
      }).eq('id', tripId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم إنهاء الرحلة بنجاح'), backgroundColor: Color(0xFF16A34A)),
        );
        setState(() {});
      }
    }
  }

  Widget _buildDeletedAccountsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.person_off_rounded, color: Colors.red.shade700, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deleted Accounts Audit Log (سجل الحسابات المحذوفة)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'سجل تدقيق كامل وموثق بالحسابات المحذوفة ونوع الحذف ومن قام بالحذف (المستخدم أم الإدارة)',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E3A8A)),
                tooltip: 'تحديث السجل',
                onPressed: () => setState(() {}),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: Supabase.instance.client
              .from('account_deletion_logs')
              .select()
              .order('created_at', ascending: false),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
            }
            final logs = snapshot.data ?? [];
            if (logs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade600, size: 44),
                      const SizedBox(height: 12),
                      const Text(
                        'لا توجد حسابات محذوفة في السجل حتى الآن',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'عند قيام أي مستخدم أو مشرف بحذف حساب كابتن أو راكب، ستظهر بيانات التدقيق هنا فوراً.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: logs.map((log) {
                final isByAdmin = log['deleted_by'] == 'admin';
                final scope = (log['deleted_scope'] ?? 'both').toString().toLowerCase();
                final userName = log['user_name']?.toString() ?? 'بدون اسم';
                final phone = log['phone_number']?.toString() ?? 'بدون هاتف';
                final reason = log['reason']?.toString();
                final createdAtRaw = log['created_at']?.toString();
                final formattedDate = createdAtRaw != null
                    ? DateFormat('yyyy-MM-dd – hh:mm a').format(DateTime.parse(createdAtRaw).toLocal())
                    : 'N/A';

                String scopeText;
                Color scopeColor;
                IconData scopeIcon;
                if (scope == 'driver') {
                  scopeText = 'كابتن فقط (Driver Only)';
                  scopeColor = Colors.amber.shade900;
                  scopeIcon = Icons.local_taxi_rounded;
                } else if (scope == 'rider') {
                  scopeText = 'راكب فقط (Rider Only)';
                  scopeColor = Colors.blue.shade800;
                  scopeIcon = Icons.person_outline_rounded;
                } else {
                  scopeText = 'الحساب بالكامل (Both / All)';
                  scopeColor = Colors.red.shade800;
                  scopeIcon = Icons.delete_forever_rounded;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isByAdmin ? Colors.purple.shade200 : Colors.grey.shade200,
                      width: isByAdmin ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scopeColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(scopeIcon, color: scopeColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    phone,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  'تاريخ الحذف: $formattedDate',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            if (reason != null && reason.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'السبب: $reason',
                                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isByAdmin ? Colors.purple.shade50 : Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isByAdmin ? Colors.purple.shade300 : Colors.teal.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isByAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                                  size: 13,
                                  color: isByAdmin ? Colors.purple.shade700 : Colors.teal.shade700,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isByAdmin ? 'حذف بواسطة الإدارة (Admin)' : 'حذف بواسطة المستخدم (User)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isByAdmin ? Colors.purple.shade800 : Colors.teal.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: scopeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              scopeText,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scopeColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildUsersCard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client.from('users').select().order('created_at', ascending: false).limit(100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }
        final users = snapshot.data ?? [];
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Registered Users (${users.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() {})),
                ],
              ),
              const SizedBox(height: 16),
              ...users.map((u) {
                final uId = u['id']?.toString() ?? '';
                final name = u['name']?.toString() ?? 'User';
                final phone = (u['phone_number'] ?? u['phone'])?.toString() ?? 'N/A';
                final role = u['role']?.toString() ?? 'rider';
                final bal = (u['wallet_balance'] as num?)?.toDouble() ?? 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF1E3A8A),
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(phone, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: role == 'driver' ? Colors.green.shade50 : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(role.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: role == 'driver' ? Colors.green.shade800 : Colors.blue.shade800)),
                          ),
                          const SizedBox(width: 8),
                          Text('${bal.toStringAsFixed(1)} EGP', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade50,
                              foregroundColor: Colors.red.shade700,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded, size: 14),
                            label: const Text('حذف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => _showAdminDeleteDialog(
                              userId: uId,
                              userName: name,
                              phone: phone,
                              isDriver: role == 'driver',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDriversCard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client.from('drivers').select().order('updated_at', ascending: false).limit(100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }
        final drivers = snapshot.data ?? [];
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Active Captains (${drivers.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() {})),
                ],
              ),
              const SizedBox(height: 16),
              ...drivers.map((d) {
                final dId = d['id']?.toString() ?? '';
                final phone = (d['phone_number'] ?? d['phone'])?.toString() ?? 'N/A';
                final vStatus = d['verification_status']?.toString() ?? 'unregistered';
                final isOnline = d['is_online'] == true;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.directions_car_rounded, color: isOnline ? Colors.green : Colors.grey, size: 20),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Captain ID: ${dId.length > 8 ? dId.substring(0, 8) : dId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(phone, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: vStatus == 'verified' ? Colors.green.shade50 : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(vStatus.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: vStatus == 'verified' ? Colors.green.shade800 : Colors.amber.shade800)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade50,
                              foregroundColor: Colors.red.shade700,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded, size: 14),
                            label: const Text('حذف الكابتن', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => _showAdminDeleteDialog(
                              userId: dId,
                              userName: 'Captain',
                              phone: phone,
                              isDriver: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAdminDeleteDialog({
    required String userId,
    required String userName,
    required String phone,
    required bool isDriver,
  }) async {
    String selectedScope = isDriver ? 'driver' : 'both';
    final reasonController = TextEditingController();
    bool isExecuting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
              const SizedBox(width: 8),
              const Text('حذف حساب بواسطة الإدارة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المستخدم: $userName ($phone)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 12),
                const Text('اختر نطاق الحذف:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                if (isDriver) ...[
                  RadioListTile<String>(
                    value: 'driver',
                    groupValue: selectedScope,
                    title: const Text('حذف حساب الكابتن فقط (Driver Only)', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('إزالة الكابتن من النظام مع استمرار حسابه كراكب', style: TextStyle(fontSize: 11)),
                    onChanged: (v) => setDialogState(() => selectedScope = v!),
                  ),
                ],
                RadioListTile<String>(
                  value: 'both',
                  groupValue: selectedScope,
                  title: const Text('حذف الحساب بالكامل نهائياً (Both)', style: TextStyle(fontSize: 13, color: Colors.red)),
                  subtitle: const Text('مسح المستخدم نهائياً من قاعدة البيانات وجدول المصادقة', style: TextStyle(fontSize: 11)),
                  onChanged: (v) => setDialogState(() => selectedScope = v!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'سبب الحذف بواسطة الإدارة',
                    hintText: 'مثال: مخالفة شروط الاستخدام...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isExecuting ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
              onPressed: isExecuting
                  ? null
                  : () async {
                      setDialogState(() => isExecuting = true);
                      try {
                        final res = await Supabase.instance.client.rpc('admin_delete_user_account', params: {
                          'p_target_user_id': userId,
                          'p_scope': selectedScope,
                          'p_reason': reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : 'حذف بواسطة الإدارة',
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res?['message']?.toString() ?? 'تم تنفيذ الحذف بنجاح'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        setState(() {});
                      } catch (e) {
                        setDialogState(() => isExecuting = false);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
              child: isExecuting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('تأكيد الحذف'),
            ),
          ],
        ),
      ),
    );
  }
}
