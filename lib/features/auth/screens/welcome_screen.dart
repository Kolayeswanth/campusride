import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import '../../../core/theme/theme.dart';
import '../../../shared/widgets/widgets.dart';
import 'unified_login_screen.dart';
import 'unified_registration_screen.dart';

/// WelcomeScreen is the first screen users see when they open the app
/// for the first time. It introduces the app and provides options to
/// sign in or register.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  AnimationController? _progressController;
  Timer? _adminAccessTimer;
  bool _isAdminAccessActive = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
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
    _progressController?.dispose();
    _adminAccessTimer?.cancel();
    super.dispose();
  }

  void _startAdminAccessTimer() {
    _adminAccessTimer?.cancel();
    _progressController?.reset();
    setState(() {
      _isAdminAccessActive = true;
    });
    
    _progressController?.forward();
    
    _adminAccessTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        // Navigate to admin login screen after 5 seconds
        Navigator.pushNamed(context, '/admin/login');
        setState(() {
          _isAdminAccessActive = false;
        });
        _progressController?.reset();
      }
    });
  }

  void _cancelAdminAccessTimer() {
    _adminAccessTimer?.cancel();
    _progressController?.stop();
    _progressController?.reset();
    if (mounted) {
      setState(() {
        _isAdminAccessActive = false;
      });
    }
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
                      // Bus Logo with Admin Access (Hold for 5 seconds)
                      SizedBox(height: screenSize.height * 0.08),
                      GestureDetector(
                        onLongPressStart: (_) => _startAdminAccessTimer(),
                        onLongPressEnd: (_) => _cancelAdminAccessTimer(),
                        onLongPressCancel: () => _cancelAdminAccessTimer(),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Progress indicator (only shown when active)
                            if (_isAdminAccessActive && _progressController != null)
                              SizedBox(
                                width: 180,
                                height: 180,
                                child: AnimatedBuilder(
                                  animation: _progressController!,
                                  builder: (context, child) {
                                    return CircularProgressIndicator(
                                      value: _progressController!.value,
                                      strokeWidth: 4,
                                      backgroundColor: AppColors.primary.withOpacity(0.2),
                                      valueColor: const AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            // Bus Logo Container
                            Container(
                              decoration: _isAdminAccessActive
                                  ? BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.primary.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    )
                                  : null,
                              child: GlassmorphicContainer.large(
                                width: 140,
                                height: 140,
                                child: const Center(
                                  child: Icon(
                                    Icons.directions_bus_rounded,
                                    size: 80,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // App Title
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
                      if (_isAdminAccessActive)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Hold bus logo for admin access...',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.primary,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      SizedBox(height: screenSize.height * 0.06),

                      // Feature highlights
                      _buildFeatureItem(
                        icon: Icons.location_on,
                        title: 'Real-time Tracking',
                        description:
                            'Track college buses in real-time and never miss a ride',
                      ),
                      const SizedBox(height: 20),
                      _buildFeatureItem(
                        icon: Icons.notifications,
                        title: 'Smart Notifications',
                        description:
                            'Get notified when your bus is approaching your stop',
                      ),
                      const SizedBox(height: 20),
                      _buildFeatureItem(
                        icon: Icons.schedule,
                        title: 'Trip Planning',
                        description:
                            'Plan your trips and save your favorite routes',
                      ),

                      SizedBox(height: screenSize.height * 0.08),

                      // Action buttons
                      CustomButton.primary(
                        text: 'Create Account',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UnifiedRegistrationScreen(),
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
                              builder: (context) => const UnifiedLoginScreen(),
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
