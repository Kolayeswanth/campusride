import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/driver.dart';
import '../services/driver_service.dart';
import 'package:uuid/uuid.dart';

class DriverFormScreen extends StatefulWidget {
  final Driver? driver; // If null, we're adding a new driver. If not null, we're editing an existing driver.
  final String collegeId; // The ID of the college this driver belongs to.

  const DriverFormScreen({Key? key, this.driver, required this.collegeId}) : super(key: key);

  @override
  State<DriverFormScreen> createState() => _DriverFormScreenState();
}

class _DriverFormScreenState extends State<DriverFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    if (widget.driver != null) {
      // If we're editing an existing driver, populate the form fields.
      _nameController.text = widget.driver!.name;
      _phoneController.text = widget.driver!.phone;
      _isActive = widget.driver!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveDriver() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _loading = true;
        _error = null;
      });

      try {
        final driverService = Provider.of<DriverService>(context, listen: false);

        if (widget.driver == null) {
          // Adding a new driver
          final newDriverId = const Uuid().v4(); // Generate a new UUID
          final driver = Driver(
            id: newDriverId, // Provide the generated ID
            name: _nameController.text,
            phone: _phoneController.text,
            isActive: _isActive, // Use the state variable
            currentCollegeId: widget.collegeId, // Use the provided collegeId
          );
          await driverService.addDriver(driver);
        } else {
          // Editing an existing driver
          await driverService.updateDriver(
            id: widget.driver!.id,
            name: _nameController.text,
            phone: _phoneController.text,
            isActive: _isActive, // Use the state variable
            currentCollegeId: widget.collegeId, // Use the provided collegeId
          );
        }

        Navigator.pop(context); // Go back to the previous screen.
      } catch (e) {
        setState(() { _error = e.toString(); });
      } finally {
        setState(() { _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.driver == null ? 'Add Driver' : 'Edit Driver'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _loading ? null : _saveDriver,
                child: _loading ? const CircularProgressIndicator() : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 