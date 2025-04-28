import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/animations/animations.dart';
import '../../../shared/widgets/widgets.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';
import 'role_selection_screen.dart';
import '../../driver/screens/driver_home_screen.dart';
import '../../passenger/screens/passenger_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Splash Screen widget displays when the app is launched.
/// It shows the app logo and transitions to either the login screen
/// or the main app depending on authentication status.
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
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
    
    // If service is still loading, wait a bit more
    if (authService.isLoading) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) _navigateToNextScreen();
      return;
    }
    
    // Check if there's an error
    if (authService.error != null) {
      // Clear any existing session and show login
      await authService.signOut();
      if (mounted) {
        AnimatedNavigation.fadeInReplacement(context, const LoginScreen());
      }
      return;
    }
    
    // Check authentication state
    if (authService.isAuthenticated && authService.currentUser != null) {
      // User is logged in, check role
      final userRole = authService.userRole;
      
      if (userRole == null) {
        // User needs to select a role
        if (mounted) {
          AnimatedNavigation.fadeInReplacement(
            context, 
            const RoleSelectionScreen(),
          );
        }
      } else if (userRole == 'driver') {
        // User is a driver
        if (mounted) {
          AnimatedNavigation.fadeInReplacement(
            context, 
            const DriverHomeScreen(),
          );
        }
      } else {
        // User is a passenger
        if (mounted) {
          AnimatedNavigation.fadeInReplacement(
            context, 
            const PassengerHomeScreen(),
          );
        }
      }
    } else {
      // User is not logged in, show welcome or login
      final isFirstLaunch = await _isFirstLaunch();
      
      if (mounted) {
        if (isFirstLaunch) {
          AnimatedNavigation.fadeInReplacement(context, const WelcomeScreen());
        } else {
          AnimatedNavigation.fadeInReplacement(context, const LoginScreen());
        }
      }
    }
  }
  
  // Placeholder function to check if this is the first launch
  Future<bool> _isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
    
    if (isFirstLaunch) {
      await prefs.setBool('is_first_launch', false);
    }
    
    return isFirstLaunch;
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
                          child: Center(
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
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
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