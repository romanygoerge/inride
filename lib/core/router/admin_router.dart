import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/admin_auth/presentation/pages/admin_login_page.dart';
import '../../features/admin_auth/presentation/providers/admin_auth_provider.dart';
import '../../features/admin_dashboard/presentation/pages/admin_dashboard_page.dart';

final adminRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(adminAuthProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: authNotifier,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const AdminLoginPage(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const AdminDashboardPage(),
        routes: [
          GoRoute(
            path: 'users',
            name: 'dashboard_users',
            builder: (context, state) => const AdminDashboardPage(subTab: 'users'),
          ),
          GoRoute(
            path: 'drivers',
            name: 'dashboard_drivers',
            builder: (context, state) => const AdminDashboardPage(subTab: 'drivers'),
          ),
          GoRoute(
            path: 'trips',
            name: 'dashboard_trips',
            builder: (context, state) => const AdminDashboardPage(subTab: 'trips'),
          ),
          GoRoute(
            path: 'settings',
            name: 'dashboard_settings',
            builder: (context, state) => const AdminDashboardPage(subTab: 'settings'),
          ),
        ],
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final authState = authNotifier.state;

      // 1. If session is still initializing on browser reload, stay on current location
      if (authState.isInitializing) {
        return null;
      }

      final isAuthenticated = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      // 2. Unauthenticated or Non-Active Admin access attempt
      if (!isAuthenticated) {
        // If not logged in and trying to access protected route, force redirect to /login
        if (!isLoggingIn) {
          return '/login';
        }
        return null;
      }

      // 3. Authenticated Active Admin access attempt
      if (isAuthenticated) {
        // If logged in admin visits /login or root, redirect to /dashboard
        if (isLoggingIn || state.matchedLocation == '/') {
          return '/dashboard';
        }
      }

      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              '404 - Page Not Found',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text('The requested path "${state.uri}" does not exist.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Return to Dashboard'),
            ),
          ],
        ),
      ),
    ),
  );
});
