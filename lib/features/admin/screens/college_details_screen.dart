import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/route_management_service.dart';
import '../../../core/theme/theme.dart';
import '../models/college.dart';
import 'new_route_management_screen.dart';

class CollegeDetailsScreen extends StatefulWidget {
  final College college;

  const CollegeDetailsScreen({
    Key? key,
    required this.college,
  }) : super(key: key);

  @override
  State<CollegeDetailsScreen> createState() => _CollegeDetailsScreenState();
}

class _CollegeDetailsScreenState extends State<CollegeDetailsScreen> {
  List<Map<String, dynamic>> _collegeDrivers = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCollegeDrivers();
  }

  Future<void> _loadCollegeDrivers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final drivers = await authService.getDriversByCollege(widget.college.id);
      
      setState(() {
        _collegeDrivers = drivers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.college.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // College Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Center(
                            child: Text(
                              widget.college.name[0],
                              style: AppTypography.headlineSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.college.name,
                                style: AppTypography.titleLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Code: ${widget.college.code}',
                                style: AppTypography.titleMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.college.location,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Cards
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    title: 'Drivers',
                    subtitle: '${_collegeDrivers.length} active drivers',
                    icon: Icons.people,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CollegeDriversScreen(
                            college: widget.college,
                            drivers: _collegeDrivers,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    title: 'Routes',
                    subtitle: 'Manage campus routes',
                    icon: Icons.route,
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NewRouteManagementScreen(
                            college: widget.college,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Stats
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error loading data: $_error',
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Stats',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                            icon: Icons.drive_eta,
                            label: 'Active Drivers',
                            value: '${_collegeDrivers.where((d) => d['is_active'] == true).length}',
                            color: Colors.blue,
                          ),
                          _StatItem(
                            icon: Icons.block,
                            label: 'Inactive Drivers',
                            value: '${_collegeDrivers.where((d) => d['is_active'] != true).length}',
                            color: Colors.orange,
                          ),
                          _StatItem(
                            icon: Icons.people,
                            label: 'Total Drivers',
                            value: '${_collegeDrivers.length}',
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class CollegeDriversScreen extends StatelessWidget {
  final College college;
  final List<Map<String, dynamic>> drivers;

  const CollegeDriversScreen({
    Key? key,
    required this.college,
    required this.drivers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${college.name} - Drivers'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: drivers.isEmpty
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
                    'No approved drivers for this college yet',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: drivers.length,
              itemBuilder: (context, index) {
                final driver = drivers[index];
                final profile = driver['profiles'] as Map<String, dynamic>?;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: driver['is_active'] == true
                          ? Colors.green
                          : Colors.grey,
                      child: Icon(
                        Icons.drive_eta,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      profile?['display_name'] ?? 
                      profile?['email'] ?? 'Unknown Driver',
                      style: AppTypography.titleMedium,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Experience: ${driver['driving_experience_years']} years'),
                        Text('Rating: ${driver['rating'] ?? 0.0} ⭐'),
                      ],
                    ),
                    trailing: Container(
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
                  ),
                );
              },
            ),
    );
  }
}
