import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/widgets.dart';

class DriverRequestScreen extends StatefulWidget {
  const DriverRequestScreen({Key? key}) : super(key: key);

  @override
  State<DriverRequestScreen> createState() => _DriverRequestScreenState();
}

class _DriverRequestScreenState extends State<DriverRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _licenseNumberController = TextEditingController();
  final _experienceController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _licenseNumberController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      final requestData = {
        'license_number': _licenseNumberController.text.trim(),
        'driving_experience_years': int.parse(_experienceController.text.trim()),
      };

      await authService.submitDriverRequest(requestData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driver request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Application'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apply to Become a Driver',
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please provide your license information to apply as a driver.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // License Information
              Text(
                'License Information',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _licenseNumberController,
                label: 'Driver\'s License Number',
                hint: 'Enter your license number',
                prefixIcon: Icons.credit_card,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'License number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _experienceController,
                label: 'Years of Driving Experience',
                hint: 'e.g., 3',
                prefixIcon: Icons.timer,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Driving experience is required';
                  }
                  final experience = int.tryParse(value!);
                  if (experience == null || experience < 0) {
                    return 'Enter a valid number of years';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Terms and Submit
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Important Information',
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Your application will be reviewed by college administrators\n'
                      '• Vehicle information will be collected after approval\n'
                      '• Approval is subject to background checks and college policies\n'
                      '• You must maintain good standing to remain as a driver',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              CustomButton.primary(
                text: 'Submit Driver Application',
                onPressed: _isLoading ? null : _submitRequest,
                isLoading: _isLoading,
                prefixIcon: Icons.send,
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
