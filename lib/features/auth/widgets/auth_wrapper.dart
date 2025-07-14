import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../screens/unified_login_screen.dart';
import '../../passenger/screens/main_navigation_screen.dart';
import '../../admin/screens/super_admin_dashboard_screen.dart';
import '../../driver/screens/driver_home_screen.dart';

/// AuthWrapper handles authentication state and navigation
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use Selector to only rebuild when the specific auth state values we care about change
    return Selector<AuthService, ({bool isLoading, bool isAuthenticated, String? userRole})>(
      selector: (context, authService) => (
        isLoading: authService.isLoading,
        isAuthenticated: authService.isAuthenticated,
        userRole: authService.userRole,
      ),
      builder: (context, authState, child) {
        print('AuthWrapper build - isLoading: ${authState.isLoading}, isAuthenticated: ${authState.isAuthenticated}, userRole: ${authState.userRole}');
        
        // Show loading while checking auth state
        if (authState.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If not authenticated, show login screen
        if (!authState.isAuthenticated) {
          return const UnifiedLoginScreen();
        }

        // If authenticated but no role, redirect to login (shouldn't happen normally)
        if (authState.userRole == null) {
          return const UnifiedLoginScreen();
        }

        // Return appropriate screen based on user role
        final role = authState.userRole!;
        switch (role) {
          case 'driver':
            return const DriverHomeScreen();
          case 'admin':
          case 'super_admin':
            return const SuperAdminDashboardScreen();
          default:
            return const MainNavigationScreen();
        }
      },
    );
  }
}
