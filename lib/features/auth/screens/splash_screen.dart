import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/animations/animations.dart';
import '../../../shared/widgets/widgets.dart';
import 'unified_login_screen.dart';
import '../../passenger/screens/passenger_home_screen.dart';

/// The Splash Screen widget displays when the app is launched.
/// It shows the app logo and transitions to either the login screen
/// or the main app depending on authentication status.
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();

    // Set up animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeInOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeInOut),
      ),
    );

    // Start animation
    _animationController.forward();

    // Navigate after a delay
    Timer(const Duration(seconds: 3), _navigateToNextScreen);
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);

    // If service is still loading, wait a bit more but with a max retry count
    if (authService.isLoading) {
      // Add a retry counter to avoid infinite loops
      final retryCount = _retryCount + 1;
      if (retryCount > 5) {
        // If we've tried too many times, just navigate to login
        if (mounted) {
          AnimatedNavigation.fadeInReplacement(context, const UnifiedLoginScreen());
        }
        return;
      }
      
      _retryCount = retryCount;
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) _navigateToNextScreen();
      return;
    }

    // Check if there's an error
    if (authService.error != null) {
      // Clear any existing session and show login
      await authService.signOut();
      if (mounted) {
        AnimatedNavigation.fadeInReplacement(context, const UnifiedLoginScreen());
      }
      return;
    }

    // Check authentication state
    if (authService.isAuthenticated && authService.currentUser != null) {
      // User is logged in, navigate based on role
      final userRole = authService.userRole;

      if (userRole == null) {
        // No role assigned, go to login
        if (mounted) {
          AnimatedNavigation.fadeInReplacement(context, const UnifiedLoginScreen());
        }
      } else if (userRole == 'driver') {
        // User is a driver - clear the navigation stack completely
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/driver_home',
            (route) => false
          );
        }
      } else {
        // User is a passenger or other role
        if (mounted) {
          AnimatedNavigation.fadeInReplacement(
            context,
            const PassengerHomeScreen(),
          );
        }
      }
    } else {
      // User is not logged in, show login screen
      if (mounted) {
        AnimatedNavigation.fadeInReplacement(context, const UnifiedLoginScreen());
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background decorative elements
          Positioned(
            top: -screenSize.height * 0.1,
            right: -screenSize.width * 0.2,
            child: Container(
              width: screenSize.width * 0.7,
              height: screenSize.width * 0.7,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -screenSize.height * 0.05,
            left: -screenSize.width * 0.1,
            child: Container(
              width: screenSize.width * 0.6,
              height: screenSize.width * 0.6,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Main content
          Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Placeholder for logo (will be replaced with an actual image)
                        GlassmorphicContainer(
                          width: 120,
                          height: 120,
                          borderRadius: BorderRadius.circular(30),
                          child: const Center(
                            child: Icon(
                              Icons.directions_bus_rounded,
                              size: 60,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'CampusRide',
                          style: AppTypography.displayMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your College Transport Companion',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 48),
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
