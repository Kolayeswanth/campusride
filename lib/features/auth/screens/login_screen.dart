import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/widgets.dart';
import 'unified_registration_screen.dart';
import 'forgot_password_screen.dart';

/// LoginScreen handles user authentication via email/password
/// or social logins like Google.
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Handles the email login process
  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);

    await authService.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (authService.error == null && authService.isAuthenticated) {
      // Navigate based on user's actual role from their profile
      final userRole = authService.userRole;
      
      if (userRole == 'driver') {
        Navigator.of(context).pushReplacementNamed('/driver_home');
      } else if (userRole == 'admin' || userRole == 'super_admin') {
        Navigator.of(context).pushReplacementNamed('/admin_dashboard');
      } else {
        // Default to passenger home for 'user' role
        Navigator.of(context).pushReplacementNamed('/passenger_home');
      }
    }
  }

  /// Handles Google sign in
  Future<void> _signInWithGoogle() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signInWithGoogle();

    // Note: Actual navigation will happen in the splash screen once the authentication state changes
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: screenSize.height * 0.06),

                // Header section
                Text(
                  'Sign In',
                  style: AppTypography.displaySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome back! Sign in to access your CampusRide account',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),

                SizedBox(height: screenSize.height * 0.04),

                // Info section about roles
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryLight.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your dashboard will be based on your account type. New users start as passengers and can request driver access from their profile.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: screenSize.height * 0.06),

                // Form section
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Email field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          final emailRegExp =
                              RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegExp.hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Forgot password link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Forgot Password?',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      // Error message
                      if (authService.error != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.error.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authService.error!,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Sign in button
                      Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              text: 'Sign In',
                              onPressed: _signInWithEmail,
                              isLoading: authService.isLoading,
                              isFullWidth: true,
                              size: ButtonSize.large,
                              prefixIcon: Icons.login,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: screenSize.height * 0.04),

                // Divider
                Row(
                  children: [
                    const Expanded(
                      child: Divider(thickness: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Or sign in with',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(thickness: 1),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Social login buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Google signin
                    CustomButton(
                      text: 'Google',
                      onPressed:
                          authService.isLoading ? null : _signInWithGoogle,
                      type: ButtonType.outlined,
                      prefixIcon: Icons.g_mobiledata_rounded,
                    ),
                  ],
                ),

                SizedBox(height: screenSize.height * 0.04),

                // Register link
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: RichText(
                      text: TextSpan(
                        text: 'Don\'t have an account? ',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          TextSpan(
                            text: 'Register',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const UnifiedRegistrationScreen(),
                                  ),
                                );
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
