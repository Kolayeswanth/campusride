import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../screens/welcome_screen.dart';
import '../screens/unified_login_screen.dart';
import '../../passenger/screens/passenger_home_screen.dart';
import '../../driver/screens/driver_home_screen.dart';
import '../../admin/screens/super_admin_dashboard_screen.dart';

/// AuthWrapper handles authentication state and navigation
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // Show loading while checking auth state
        if (authService.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If not authenticated, show welcome screen
        if (!authService.isAuthenticated) {
          return const WelcomeScreen();
        }

        // If authenticated but no profile/role, show college selection
        if (authService.userRole == null) {
          return const UnifiedLoginScreen(); // This will redirect to profile creation
        }

        // Navigate based on user role
        switch (authService.userRole) {
          case 'driver':
            return const DriverHomeScreen();
          case 'admin':
          case 'super_admin':
            return const SuperAdminDashboardScreen();
          case 'user':
          default:
            return const PassengerHomeScreen();
        }
      },
    );
  }
}
