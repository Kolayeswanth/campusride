import 'package:flutter/material.dart';
import '../screens/super_admin_dashboard_screen.dart';
import '../screens/super_admin_login_screen.dart';
import '../providers/admin_providers.dart';

class AdminRoutes {
  static const String login = '/admin/login';
  static const String dashboard = '/admin/dashboard';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      login: (context) => const SuperAdminLoginScreen(),
      dashboard: (context) => AdminProviders(
            child: const SuperAdminDashboardScreen(),
          ),
    };
  }
} 