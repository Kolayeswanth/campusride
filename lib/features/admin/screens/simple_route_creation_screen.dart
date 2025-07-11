import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/route_management_service.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/location_search_field.dart';

class SimpleRouteCreationScreen extends StatefulWidget {
  const SimpleRouteCreationScreen({Key? key}) : super(key: key);

  @override
  State<SimpleRouteCreationScreen> createState() => _SimpleRouteCreationScreenState();
}

class _SimpleRouteCreationScreenState extends State<SimpleRouteCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _routeNameController = TextEditingController();
  final _busNumberController = TextEditingController();
  
  String? _fromLocationName;
  String? _toLocationName;
  LatLng? _fromLocationCoords;
  LatLng? _toLocationCoords;
  
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _routeNameController.dispose();
    _busNumberController.dispose();
    super.dispose();
  }

  void _onFromLocationSelected(String locationName, LatLng coordinates) {
    setState(() {
      _fromLocationName = locationName;
      _fromLocationCoords = coordinates;
    });
  }

  void _onToLocationSelected(String locationName, LatLng coordinates) {
    setState(() {
      _toLocationName = locationName;
      _toLocationCoords = coordinates;
    });
  }

  Future<void> _saveRoute() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_fromLocationCoords == null || _toLocationCoords == null) {
      setState(() {
        _error = 'Please select both start and end locations';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final routeService = Provider.of<RouteManagementService>(context, listen: false);
      
      await routeService.createRoute(
        routeName: _routeNameController.text.trim(),
        collegeCode: 'DEFAULT',
        busNumber: _busNumberController.text.trim(),
        startLocation: '${_fromLocationCoords!.latitude},${_fromLocationCoords!.longitude}',
        endLocation: '${_toLocationCoords!.latitude},${_toLocationCoords!.longitude}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error creating route: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Route'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Route Name
              TextFormField(
                controller: _routeNameController,
                decoration: const InputDecoration(
                  labelText: 'Route Name',
                  hintText: 'e.g., Campus to Downtown',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a route name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Bus Number
              TextFormField(
                controller: _busNumberController,
                decoration: const InputDecoration(
                  labelText: 'Bus Number',
                  hintText: 'e.g., BUS-001',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a bus number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // From Location
              const Text(
                'Start Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              LocationSearchField(
                label: 'Start Location',
                hint: 'Search for start location...',
                icon: Icons.location_on,
                onLocationSelected: _onFromLocationSelected,
                initialValue: _fromLocationName,
              ),
              const SizedBox(height: 16),

              // To Location
              const Text(
                'End Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              LocationSearchField(
                label: 'End Location',
                hint: 'Search for end location...',
                icon: Icons.location_on,
                onLocationSelected: _onToLocationSelected,
                initialValue: _toLocationName,
              ),
              const SizedBox(height: 24),

              // Error Message
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),

              // Route Summary
              if (_fromLocationName != null && _toLocationName != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Route Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          Expanded(child: Text('From: $_fromLocationName')),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.red, size: 16),
                          const SizedBox(width: 4),
                          Expanded(child: Text('To: $_toLocationName')),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveRoute,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Create Route',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
