import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/animations/animations.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../../../features/debug/debug_screen.dart';

/// WelcomeScreen is the first screen users see when they open the app
/// for the first time. It introduces the app and provides options to
/// sign in or register.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _animationController.forward();
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Header with hidden debug access
                      SizedBox(height: screenSize.height * 0.08),
                      GestureDetector(
                        // Add long press gesture for accessing debug screen
                        onLongPress: () {
                          // Hidden debug access with long press
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const DebugScreen()),
                          );
                        },
                        child: GlassmorphicContainer.large(
                          width: 140,
                          height: 140,
                          child: Center(
                            child: Icon(
                              Icons.directions_bus_rounded,
                              size: 80,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'CampusRide',
                        style: AppTypography.displayLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your College Transport Companion',
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      SizedBox(height: screenSize.height * 0.06),
                      
                      // Feature highlights
                      _buildFeatureItem(
                        icon: Icons.location_on,
                        title: 'Real-time Tracking',
                        description: 'Track college buses in real-time and never miss a ride',
                      ),
                      const SizedBox(height: 20),
                      _buildFeatureItem(
                        icon: Icons.notifications,
                        title: 'Smart Notifications',
                        description: 'Get notified when your bus is approaching your stop',
                      ),
                      const SizedBox(height: 20),
                      _buildFeatureItem(
                        icon: Icons.schedule,
                        title: 'Trip Planning',
                        description: 'Plan your trips and save your favorite routes',
                      ),
                      
                      SizedBox(height: screenSize.height * 0.08),
                      
                      // Action buttons
                      CustomButton.primary(
                        text: 'Create Account',
                        onPressed: () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        isFullWidth: true,
                        size: ButtonSize.large,
                      ),
                      const SizedBox(height: 16),
                      CustomButton.outlined(
                        text: 'Sign In',
                        onPressed: () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        isFullWidth: true,
                      ),
                      
                      SizedBox(height: screenSize.height * 0.06),
                      
                      // Terms and Privacy
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          text: 'By continuing, you agree to our ',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          children: [
                            TextSpan(
                              text: 'Terms of Service',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  // Show terms of service
                                },
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  // Show privacy policy
                                },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
  
  /// Builds a feature item with an icon, title, and description.
  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        GlassmorphicContainer.small(
          width: 60,
          height: 60,
          child: Center(
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 