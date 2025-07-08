import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/widgets/widgets.dart';

class DriversManagementScreen extends StatefulWidget {
  const DriversManagementScreen({Key? key}) : super(key: key);

  @override
  State<DriversManagementScreen> createState() => _DriversManagementScreenState();
}

class _DriversManagementScreenState extends State<DriversManagementScreen> {
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final drivers = await authService.getAllDrivers();
      
      setState(() {
        _drivers = drivers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleDriverStatus(String driverId, bool currentStatus) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.updateDriverStatus(driverId, !currentStatus);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Driver ${!currentStatus ? 'activated' : 'deactivated'} successfully'
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _loadDrivers(); // Reload drivers
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating driver status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Drivers'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDrivers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading drivers',
                        style: AppTypography.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      CustomButton.primary(
                        text: 'Retry',
                        onPressed: _loadDrivers,
                        prefixIcon: Icons.refresh,
                      ),
                    ],
                  ),
                )
              : _drivers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.drive_eta_outlined,
                            size: 64,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No drivers found',
                            style: AppTypography.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No approved drivers yet',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadDrivers,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _drivers.length,
                        itemBuilder: (context, index) {
                          final driver = _drivers[index];
                          final profile = driver['profiles'] as Map<String, dynamic>?;
                          final college = driver['colleges'] as Map<String, dynamic>?;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: driver['is_active'] == true
                                            ? Colors.green
                                            : Colors.grey,
                                        child: Icon(
                                          Icons.drive_eta,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              profile?['display_name'] ?? 
                                              profile?['email'] ?? 'Unknown Driver',
                                              style: AppTypography.titleMedium.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (college != null)
                                              Text(
                                                college['name'] ?? 'Unknown College',
                                                style: AppTypography.bodySmall.copyWith(
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: driver['is_active'] == true
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.grey.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          driver['is_active'] == true ? 'Active' : 'Inactive',
                                          style: AppTypography.labelSmall.copyWith(
                                            color: driver['is_active'] == true
                                                ? Colors.green
                                                : Colors.grey,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Driver Details
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _InfoTile(
                                          icon: Icons.credit_card,
                                          label: 'License',
                                          value: driver['license_number'] ?? 'N/A',
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _InfoTile(
                                          icon: Icons.timeline,
                                          label: 'Experience',
                                          value: '${driver['driving_experience_years'] ?? 0} years',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _InfoTile(
                                          icon: Icons.star,
                                          label: 'Rating',
                                          value: '${driver['rating'] ?? 0.0}',
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _InfoTile(
                                          icon: Icons.drive_eta,
                                          label: 'Total Trips',
                                          value: '${driver['total_trips'] ?? 0}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  _InfoTile(
                                    icon: Icons.calendar_today,
                                    label: 'Approved',
                                    value: _formatDate(driver['approved_at']),
                                  ),
                                  
                                  if (profile?['email'] != null) ...[
                                    const SizedBox(height: 8),
                                    _InfoTile(
                                      icon: Icons.email,
                                      label: 'Email',
                                      value: profile!['email'],
                                    ),
                                  ],
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Action Buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CustomButton.secondary(
                                          text: driver['is_active'] == true ? 'Deactivate' : 'Activate',
                                          onPressed: () => _toggleDriverStatus(
                                            driver['id'],
                                            driver['is_active'] == true,
                                          ),
                                          prefixIcon: driver['is_active'] == true
                                              ? Icons.block
                                              : Icons.check_circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
