import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campusride/core/theme/app_colors.dart';
import '../models/college.dart';
import '../drivers/models/driver.dart';
import '../drivers/services/driver_service.dart';
import '../screens/driver_tracking_screen.dart';

class DriverManagementScreen extends StatefulWidget {
  final College college;

  const DriverManagementScreen({
    Key? key,
    required this.college,
  }) : super(key: key);

  @override
  State<DriverManagementScreen> createState() => _DriverManagementScreenState();
}

class _DriverManagementScreenState extends State<DriverManagementScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<DriverService>().loadDrivers(widget.college.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Drivers - ${widget.college.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Track Drivers',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DriverTrackingScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<DriverService>(
        builder: (context, service, child) {
          if (service.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    service.error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      service.loadDrivers(widget.college.id);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final List<Driver> driverList = service.getDriversForCollege(widget.college.id);
          
          if (driverList.isEmpty) {
            return const Center(
              child: Text('No drivers found'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: driverList.length,
            itemBuilder: (context, index) {
              final driver = driverList[index];
              return _DriverCard(
                driver: driver,
                onToggle: (isActive) {
                  service.toggleDriverStatus(driver.id, isActive);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDriverDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDriverDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final licenseController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Driver'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Driver Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter driver name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: licenseController,
                decoration: const InputDecoration(
                  labelText: 'License Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter license number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final driver = Driver(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  phone: phoneController.text,
                  licenseNumber: licenseController.text,
                  isActive: false,
                  currentCollegeId: widget.college.id,
                );
                context.read<DriverService>().addDriver(driver);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final Driver driver;
  final Function(bool) onToggle;

  const _DriverCard({
    Key? key,
    required this.driver,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      driver.name[0],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
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
                        driver.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        driver.phone,
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: driver.isActive,
                  onChanged: onToggle,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'License: ${driver.licenseNumber ?? 'N/A'}',
                style: const TextStyle(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 