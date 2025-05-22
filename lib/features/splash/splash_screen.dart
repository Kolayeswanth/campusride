import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/theme.dart';
import '../auth/screens/welcome_screen.dart';
import '../driver/screens/driver_home_screen.dart';
import '../passenger/screens/passenger_home_screen.dart';

/// SplashScreen is the first screen shown when the app starts.
/// It handles redirection based on authentication status.
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showDebugButton = false;
  
  @override
  void initState() {
    super.initState();
    
    // Set up animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    _animationController.forward();
    
    // Show debug button only in debug mode
    _showDebugButton = kDebugMode;
    
    // Set up timer for navigation
    _checkAuthAndNavigate();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  /// Check auth status and navigate accordingly
  Future<void> _checkAuthAndNavigate() async {
    // Delayed check to allow the splash screen to be shown
    Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      
      final authService = Provider.of<AuthService>(context, listen: false);
      
      if (authService.isAuthenticated) {
        // User is authenticated, check role
        if (authService.userRole == 'driver') {
          // Navigate to driver screen
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/driver_home');
        } else if (authService.userRole == 'passenger') {
          // Navigate to passenger screen
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/passenger_home');
        } else {
          // User needs to select a role
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/role_selection');
        }
      } else {
        // User is not authenticated, show welcome screen
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/welcome');
      }
    });
  }
  
  /// Navigate to debug screen
  void _navigateToDebug() {
    Navigator.of(context).pushNamed('/debug');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App logo
                  Container(
                    width: size.width * 0.4,
                    height: size.width * 0.4,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha((0.3 * 255).round()),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.directions_bus_rounded,
                      color: Colors.white,
                      size: 80,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // App name
                  Text(
                    'CampusRide',
                    style: AppTypography.displayLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tagline
                  Text(
                    'Campus Transportation Made Easy',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Loading indicator
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
          
          // Debug button (only shown in debug mode)
          if (_showDebugButton)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: _navigateToDebug,
                tooltip: 'Debug Menu',
                backgroundColor: Colors.grey,
                child: const Icon(Icons.bug_report),
              ),
            ),
        ],
      ),
    );
  }
} 