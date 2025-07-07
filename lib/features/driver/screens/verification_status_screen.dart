import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/widgets/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// VerificationStatusScreen displays the driver's verification status and information.
class VerificationStatusScreen extends StatefulWidget {
  const VerificationStatusScreen({Key? key}) : super(key: key);

  @override
  State<VerificationStatusScreen> createState() =>
      _VerificationStatusScreenState();
}

class _VerificationStatusScreenState extends State<VerificationStatusScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  Map<String, dynamic>? _verificationData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchVerificationStatus();
  }

  /// Fetch the driver's verification status from the database
  Future<void> _fetchVerificationStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.currentUser == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'You must be logged in to view verification status';
      });
      return;
    }

    try {
      final response = await _supabase
          .from('driver_verification')
          .select()
          .eq('user_id', authService.currentUser!.id)
          .limit(1)
          .maybeSingle();

      setState(() {
        _verificationData = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load verification status: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Verification Status'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _verificationData == null
                  ? _buildNoVerificationDataView()
                  : _buildVerificationStatusView(),
    );
  }

  /// Widget for showing an error message
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Try Again',
              onPressed: _fetchVerificationStatus,
              prefixIcon: Icons.refresh,
            ),
          ],
        ),
      ),
    );
  }

  /// Widget for showing when no verification data is available
  Widget _buildNoVerificationDataView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.info_outline,
              color: AppColors.primary,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'No Verification Data',
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'You have not submitted your driver verification information yet. Please register as a driver to submit your information.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Go to Registration',
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/register');
              },
              prefixIcon: Icons.app_registration,
            ),
          ],
        ),
      ),
    );
  }

  /// Widget for showing the verification status
  Widget _buildVerificationStatusView() {
    final isVerified = _verificationData!['is_verified'] as bool;
    final verifiedAt = _verificationData!['verified_at'] as String?;
    final driverId = _verificationData!['driver_id'] as String;
    final licenseNumber = _verificationData!['license_number'] as String;
    final createdAt =
        DateTime.parse(_verificationData!['created_at'] as String);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Verification status card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isVerified
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isVerified
                    ? AppColors.success.withOpacity(0.3)
                    : AppColors.warning.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isVerified ? Icons.verified_user : Icons.pending_outlined,
                  color: isVerified ? AppColors.success : AppColors.warning,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  isVerified ? 'Verified' : 'Pending Verification',
                  style: AppTypography.titleLarge.copyWith(
                    color: isVerified ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isVerified
                      ? 'Your driver account has been verified. You can now drive buses and share your location.'
                      : 'Your verification is pending. An administrator will review your information and verify your account.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (isVerified && verifiedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Verified on: ${DateTime.parse(verifiedAt).toLocal().toString().substring(0, 16)}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Verification details
          Text(
            'Verification Details',
            style: AppTypography.titleMedium,
          ),
          const SizedBox(height: 16),

          // Driver ID
          _buildInfoItem(
            label: 'Driver ID',
            value: driverId,
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 16),

          // License Number
          _buildInfoItem(
            label: 'License Number',
            value: licenseNumber,
            icon: Icons.card_membership_outlined,
          ),
          const SizedBox(height: 16),

          // Submission Date
          _buildInfoItem(
            label: 'Submitted On',
            value: createdAt.toLocal().toString().substring(0, 16),
            icon: Icons.calendar_today_outlined,
          ),

          const SizedBox(height: 32),

          // Information about the verification process
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.info.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.info,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Verification Process',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Driver verification ensures that only authorized personnel can operate buses. '
                  'Our administrators verify your driver credentials against school records to ensure safety and security.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Helper widget for building info items
  Widget _buildInfoItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
