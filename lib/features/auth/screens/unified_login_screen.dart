import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/widgets.dart';
import '../../admin/screens/super_admin_login_screen.dart';

/// Unified login screen for all user types
class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({Key? key}) : super(key: key);

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  
  // Admin long-press feature
  Timer? _adminLongPressTimer;
  int _adminCountdown = 10;
  bool _isAdminLongPressing = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _adminLongPressTimer?.cancel();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    
    await authService.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (authService.error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authService.error!)),
        );
      }
    } else {
      if (mounted) {
        // Navigate based on user role
        _navigateBasedOnRole(authService.userRole);
      }
    }
  }

  void _navigateBasedOnRole(String? role) {
    switch (role) {
      case 'driver':
        Navigator.pushReplacementNamed(context, '/driver_home');
        break;
      case 'admin':
      case 'super_admin':
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
        break;
      case 'user':
      default:
        Navigator.pushReplacementNamed(context, '/passenger_home');
        break;
    }
  }

  Future<void> _signInWithGoogle() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    await authService.signInWithGoogle();

    if (authService.error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authService.error!)),
        );
      }
    } else {
      if (mounted) {
        // Navigate based on user role
        _navigateBasedOnRole(authService.userRole);
      }
    }
  }

  // Admin Long-Press Feature Methods
  void _startAdminLongPress() {
    setState(() {
      _isAdminLongPressing = true;
      _adminCountdown = 10;
    });

    _adminLongPressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _adminCountdown--;
      });

      if (_adminCountdown <= 0) {
        _navigateToAdminLogin();
      }
    });
  }

  void _cancelAdminLongPress() {
    _adminLongPressTimer?.cancel();
    setState(() {
      _isAdminLongPressing = false;
      _adminCountdown = 10;
    });
  }

  void _navigateToAdminLogin() {
    _adminLongPressTimer?.cancel();
    setState(() {
      _isAdminLongPressing = false;
      _adminCountdown = 10;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SuperAdminLoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Sign In'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                
                // Header
                Text(
                  'Welcome Back',
                  style: AppTypography.displayLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to your account',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Email
                CustomTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Enter your email address',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Sign In Button with Long-Press Admin Access
                Consumer<AuthService>(
                  builder: (context, authService, child) {
                    return GestureDetector(
                      onLongPressStart: (_) => _startAdminLongPress(),
                      onLongPressEnd: (_) => _cancelAdminLongPress(),
                      onLongPressCancel: _cancelAdminLongPress,
                      child: CustomButton.primary(
                        text: _isAdminLongPressing 
                            ? 'Admin Access (${_adminCountdown}s)' 
                            : 'Sign In',
                        onPressed: authService.isLoading ? null : _signIn,
                        isFullWidth: true,
                        size: ButtonSize.large,
                        isLoading: authService.isLoading,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),

                // Google Sign In Button
                Consumer<AuthService>(
                  builder: (context, authService, child) {
                    return CustomButton.outlined(
                      text: 'Continue with Google',
                      onPressed: authService.isLoading ? null : _signInWithGoogle,
                      isFullWidth: true,
                      prefixIcon: Icons.login, // You can replace with Google icon
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Sign Up Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Don\'t have an account? ',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: Text(
                        'Sign Up',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
