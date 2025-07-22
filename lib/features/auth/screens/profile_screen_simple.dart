import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/widgets.dart';
import 'driver_request_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _hasPendingRequest = false;
  String? _requestStatus;

  @override
  void initState() {
    super.initState();
    _checkDriverRequestStatus();
  }

  Future<void> _checkDriverRequestStatus() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final hasPending = await authService.hasPendingDriverRequest();
    final status = await authService.getDriverRequestStatus();
    
    setState(() {
      _hasPendingRequest = hasPending;
      _requestStatus = status;
    });
  }

  Future<void> _showCollegeSelectionDialog() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Get available colleges
    final colleges = await authService.getAvailableColleges();
    
    if (colleges.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No colleges available. Please check your internet connection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    String? selectedCollegeId;

    if (mounted) {
      await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Select Your College'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Please select your college from the list below:'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCollegeId,
                      decoration: const InputDecoration(
                        labelText: 'College',
                        border: OutlineInputBorder(),
                      ),
                      items: colleges.map((college) {
                        return DropdownMenuItem<String>(
                          value: college['id'],
                          child: Text(college['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCollegeId = value;
                        });
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: selectedCollegeId == null ? null : () async {
                      // Update college selection
                      await authService.selectCollege(selectedCollegeId!);
                      
                      if (mounted) {
                        Navigator.of(context).pop();
                        
                        if (authService.error == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('College selected successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          setState(() {}); // Refresh the UI
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(authService.error!),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Select'),
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Information',
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined),
                            const SizedBox(width: 12),
                            Text(authService.currentUser?.email ?? 'No email'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person_outline),
                            const SizedBox(width: 12),
                            Text(authService.userRole ?? 'No role'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // College Selection Card
                FutureBuilder<Map<String, dynamic>?>(
                  future: authService.getCurrentUserProfile(),
                  builder: (context, snapshot) {
                    final profile = snapshot.data;
                    final hasCollege = profile != null && profile['college_id'] != null;
                    
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'College Information',
                              style: AppTypography.titleLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (hasCollege)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.school, color: Colors.green.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'College selected',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.warning, color: Colors.orange.shade700),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Please select your college to access all features',
                                            style: TextStyle(
                                              color: Colors.orange.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  CustomButton.primary(
                                    text: 'Select College',
                                    onPressed: () => _showCollegeSelectionDialog(),
                                    prefixIcon: Icons.school,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Driver Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver Status',
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        if (authService.userRole == 'driver')
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'You are approved as a driver',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_requestStatus == 'pending')
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.pending, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Driver request pending approval',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_requestStatus == 'rejected')
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.cancel, color: Colors.red.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Driver request was rejected',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Want to become a driver?',
                                style: AppTypography.bodyLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Submit a request to become a driver for your college.',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              CustomButton.primary(
                                text: 'Request to Become Driver',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const DriverRequestScreen(),
                                    ),
                                  ).then((_) => _checkDriverRequestStatus());
                                },
                                prefixIcon: Icons.drive_eta,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Logout Button
                CustomButton(
                  text: 'Sign Out',
                  onPressed: () async {
                    final authService = Provider.of<AuthService>(context, listen: false);
                    await authService.signOut();
                    if (mounted) {
                      Navigator.of(context).pushReplacementNamed('/');
                    }
                  },
                  type: ButtonType.outlined,
                  prefixIcon: Icons.logout,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
