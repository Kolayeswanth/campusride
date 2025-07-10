import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/widgets.dart';

class UnifiedRegistrationScreen extends StatefulWidget {
  const UnifiedRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<UnifiedRegistrationScreen> createState() => _UnifiedRegistrationScreenState();
}

class _UnifiedRegistrationScreenState extends State<UnifiedRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String? _selectedCollegeId;
  List<Map<String, dynamic>> _colleges = [];
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _loadColleges();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadColleges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch colleges from Supabase
      final response = await Supabase.instance.client
          .from('colleges')
          .select('id, name')
          .order('name');

      print('Colleges response: $response'); // Debug log

      setState(() {
        _colleges = List<Map<String, dynamic>>.from(response);
      });
      
      print('Loaded ${_colleges.length} colleges'); // Debug log
    } catch (e) {
      print('Error loading colleges: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load colleges: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCollegeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a college')),
      );
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);

    // Register the user first
    await authService.registerWithEmail(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _displayNameController.text.trim(),
    );

    if (authService.error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authService.error!)),
        );
      }
      return;
    }

    // Then update the profile with college selection
    await authService.selectCollege(_selectedCollegeId!);

    if (authService.error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authService.error!)),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful!')),
        );
        // Navigate to appropriate screen based on role
        Navigator.pushReplacementNamed(context, '/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Create Account'),
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
                  'Join CampusRide',
                  style: AppTypography.displayLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your account to get started',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Display Name
                CustomTextField(
                  controller: _displayNameController,
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  prefixIcon: Icons.person_outline,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

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

                // Phone (Optional)
                CustomTextField(
                  controller: _phoneController,
                  label: 'Phone Number (Optional)',
                  hint: 'Enter your phone number',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // College Selection
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_colleges.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No colleges available. Please check your internet connection or try again.',
                                  style: TextStyle(color: Colors.orange[700]),
                                ),
                              ),
                              TextButton(
                                onPressed: _loadColleges,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedCollegeId,
                          decoration: InputDecoration(
                            labelText: 'Select College',
                            prefixIcon: const Icon(Icons.school_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          isExpanded: true,
                          items: _colleges.map((college) {
                            return DropdownMenuItem<String>(
                              value: college['id'],
                              child: Text(
                                college['name'],
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCollegeId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a college';
                            }
                            return null;
                          },
                        ),
                    ],
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
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    hintText: 'Confirm your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: _obscureConfirmPassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Register Button
                Consumer<AuthService>(
                  builder: (context, authService, child) {
                    return CustomButton.primary(
                      text: 'Create Account',
                      onPressed: authService.isLoading ? null : _register,
                      isFullWidth: true,
                      size: ButtonSize.large,
                      isLoading: authService.isLoading,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Sign In Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: Text(
                        'Sign In',
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
