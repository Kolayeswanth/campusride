import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/driver.dart';
import '../../colleges/models/college.dart'; // Import College model
import '../services/driver_service.dart'; // Import DriverService
import 'driver_form_screen.dart'; // Import DriverFormScreen

class DriverListScreen extends StatefulWidget {
  final College college;
  const DriverListScreen({Key? key, required this.college}) : super(key: key);

  @override
  State<DriverListScreen> createState() => _DriverListScreenState();
}

class _DriverListScreenState extends State<DriverListScreen> {
  @override
  void initState() {
    super.initState();
    // Load drivers for the college when the screen initializes
    Future.microtask(() => context.read<DriverService>().loadDrivers(widget.college.id));
  }

  // Method to navigate to add driver screen
  void _navigateToAddDriver() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverFormScreen(college: widget.college),
      ),
    );
    if (result == true) {
      context.read<DriverService>().loadDrivers(widget.college.id);
    }
  }

  // Method to navigate to edit driver screen
  void _navigateToEditDriver(Driver driver) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverFormScreen(college: widget.college, driver: driver),
      ),
    );
    if (result == true) {
      context.read<DriverService>().loadDrivers(widget.college.id);
    }
  }

   // Method to confirm and delete driver
  void _confirmDeleteDriver(Driver driver) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Driver'),
        content: Text('Are you sure you want to delete ${driver.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<DriverService>().deleteDriver(driver.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Consume DriverService to get real-time updates
    return Scaffold(
      appBar: AppBar(
        title: Text('Drivers for ${widget.college.name}'),
      ),
      body: Consumer<DriverService>(
        builder: (context, driverService, child) {
          final drivers = driverService.getDriversForCollege(widget.college.id);
          final isLoading = driverService.isLoading;
          final error = driverService.error;

          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (error != null) {
            return Center(child: Text('Error: $error'));
          }

          if (drivers.isEmpty) {
            return const Center(
              child: Text('No drivers found for this college.'),
            );
          }

          return ListView.builder(
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              return ListTile(
                title: Text(driver.name),
                subtitle: Text(
                  'Phone: ${driver.phone}\nLicense: ${driver.licenseNumber}\nStatus: ${driver.isActive ? "Active" : "Inactive"}'
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edit Driver Button
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit Driver',
                      onPressed: () => _navigateToEditDriver(driver),
                    ),
                     // Toggle Status Button
                    IconButton(
                      icon: Icon(driver.isActive ? Icons.toggle_on : Icons.toggle_off),
                      tooltip: driver.isActive ? 'Deactivate Driver' : 'Activate Driver',
                       onPressed: () {
                         context.read<DriverService>().toggleDriverStatus(driver.id, !driver.isActive);
                       },
                    ),
                    // Delete Driver Button
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: 'Delete Driver',
                      onPressed: () => _confirmDeleteDriver(driver),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddDriver,
        child: const Icon(Icons.add),
        tooltip: 'Add Driver',
      ),
    );
  }
}

class DriverListTile extends StatelessWidget {
  final Driver driver;

  const DriverListTile({
    Key? key,
    required this.driver,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: driver.isActive ? Colors.green : Colors.grey,
          child: Text(
            driver.name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(driver.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(driver.email),
            Text(driver.phone),
            Text('Vehicle: ${driver.vehicleModel} (${driver.vehicleNumber})'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: const Text('Edit'),
              onTap: () => _showEditDriverDialog(context),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Text(driver.isActive ? 'Deactivate' : 'Activate'),
              onTap: () => _toggleDriverStatus(context),
            ),
            PopupMenuItem(
              value: 'delete',
              child: const Text('Delete'),
              onTap: () => _showDeleteConfirmation(context),
            ),
          ],
        ),
        onTap: () => _showDriverDetails(context),
      ),
    );
  }

  void _showEditDriverDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => EditDriverDialog(driver: driver),
    );
  }

  void _toggleDriverStatus(BuildContext context) {
    DriverService().toggleDriverStatus(driver.id, !driver.isActive);
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Driver'),
        content: const Text('Are you sure you want to delete this driver?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              DriverService().deleteDriver(driver.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDriverDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(driver.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${driver.email}'),
            Text('Phone: ${driver.phone}'),
            Text('License: ${driver.licenseNumber}'),
            Text('Vehicle: ${driver.vehicleModel}'),
            Text('Vehicle Number: ${driver.vehicleNumber}'),
            Text('Status: ${driver.isActive ? 'Active' : 'Inactive'}'),
            if (driver.lastActive != null)
              Text('Last Active: ${driver.lastActive!.toString()}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class AddDriverDialog extends StatefulWidget {
  const AddDriverDialog({Key? key}) : super(key: key);

  @override
  State<AddDriverDialog> createState() => _AddDriverDialogState();
}

class _AddDriverDialogState extends State<AddDriverDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _vehicleModelController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _vehicleNumberController.dispose();
    _vehicleModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Driver'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a name' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter an email' : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a phone number' : null,
              ),
              TextFormField(
                controller: _licenseController,
                decoration: const InputDecoration(labelText: 'License Number'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a license number' : null,
              ),
              TextFormField(
                controller: _vehicleNumberController,
                decoration: const InputDecoration(labelText: 'Vehicle Number'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a vehicle number' : null,
              ),
              TextFormField(
                controller: _vehicleModelController,
                decoration: const InputDecoration(labelText: 'Vehicle Model'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a vehicle model' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submitForm,
          child: const Text('Add'),
        ),
      ],
    );
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final driver = Driver(
        id: '', // Will be set by Firestore
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        licenseNumber: _licenseController.text,
        vehicleNumber: _vehicleNumberController.text,
        vehicleModel: _vehicleModelController.text,
        createdAt: DateTime.now(),
      );

      DriverService().addDriver(driver);
      Navigator.pop(context);
    }
  }
}

class EditDriverDialog extends StatefulWidget {
  final Driver driver;

  const EditDriverDialog({
    Key? key,
    required this.driver,
  }) : super(key: key);

  @override
  State<EditDriverDialog> createState() => _EditDriverDialogState();
}

class _EditDriverDialogState extends State<EditDriverDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _licenseController;
  late final TextEditingController _vehicleNumberController;
  late final TextEditingController _vehicleModelController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.driver.name);
    _emailController = TextEditingController(text: widget.driver.email);
    _phoneController = TextEditingController(text: widget.driver.phone);
    _licenseController = TextEditingController(text: widget.driver.licenseNumber);
    _vehicleNumberController = TextEditingController(text: widget.driver.vehicleNumber);
    _vehicleModelController = TextEditingController(text: widget.driver.vehicleModel);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _vehicleNumberController.dispose();
    _vehicleModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Driver'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a name' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter an email' : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a phone number' : null,
              ),
              TextFormField(
                controller: _licenseController,
                decoration: const InputDecoration(labelText: 'License Number'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a license number' : null,
              ),
              TextFormField(
                controller: _vehicleNumberController,
                decoration: const InputDecoration(labelText: 'Vehicle Number'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a vehicle number' : null,
              ),
              TextFormField(
                controller: _vehicleModelController,
                decoration: const InputDecoration(labelText: 'Vehicle Model'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a vehicle model' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submitForm,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final updatedDriver = widget.driver.copyWith(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        licenseNumber: _licenseController.text,
        vehicleNumber: _vehicleNumberController.text,
        vehicleModel: _vehicleModelController.text,
      );

      DriverService().updateDriver(updatedDriver);
      Navigator.pop(context);
    }
  }
} 