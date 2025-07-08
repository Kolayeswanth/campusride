import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/route_management_service.dart';
import '../models/college.dart';
import 'route_map_screen.dart';

class NewRouteManagementScreen extends StatefulWidget {
  final College college;

  const NewRouteManagementScreen({
    Key? key,
    required this.college,
  }) : super(key: key);

  @override
  State<NewRouteManagementScreen> createState() => _NewRouteManagementScreenState();
}

class _NewRouteManagementScreenState extends State<NewRouteManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RouteManagementService>().loadCollegeRoutes(widget.college.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.college.name} - Routes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateRouteDialog(context),
            tooltip: 'Add Route',
          ),
        ],
      ),
      body: Consumer<RouteManagementService>(
        builder: (context, routeService, child) {
          if (routeService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (routeService.error != null) {
            return Center(
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
                    'Error loading routes',
                    style: AppTypography.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    routeService.error!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      routeService.clearError();
                      routeService.loadCollegeRoutes(widget.college.id);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (routeService.routes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.route_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No routes found',
                    style: AppTypography.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first bus route to get started',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateRouteDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Route'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => routeService.loadCollegeRoutes(widget.college.id),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: routeService.routes.length,
              itemBuilder: (context, index) {
                final route = routeService.routes[index];
                return _RouteCard(
                  route: route,
                  college: widget.college,
                  onEdit: () => _showCreateRouteDialog(context, route: route),
                  onDelete: () => _confirmDeleteRoute(context, route),
                  onToggleStatus: (active) => routeService.toggleRouteStatus(
                    route['id'],
                    active,
                    widget.college.id,
                  ),
                  onSetRoute: () => _showRouteMapDialog(context, route),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showCreateRouteDialog(BuildContext context, {Map<String, dynamic>? route}) {
    final isEditing = route != null;
    final formKey = GlobalKey<FormState>();
    final busNumberController = TextEditingController(text: route?['bus_number'] ?? '');
    final routeNameController = TextEditingController(text: route?['route_name'] ?? '');
    final startLocationController = TextEditingController(text: route?['start_location'] ?? '');
    final endLocationController = TextEditingController(text: route?['end_location'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Route' : 'Create New Route'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: busNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Bus Number',
                    hintText: 'e.g., Bus 101',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.directions_bus),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter bus number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: routeNameController,
                  decoration: const InputDecoration(
                    labelText: 'Route Name',
                    hintText: 'e.g., Campus to Downtown',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.route),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter route name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: startLocationController,
                  decoration: const InputDecoration(
                    labelText: 'From Location',
                    hintText: 'e.g., Main Campus Gate',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter start location';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: endLocationController,
                  decoration: const InputDecoration(
                    labelText: 'To Location',
                    hintText: 'e.g., Downtown Station',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.flag),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter end location';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'After creating the route, you can set the path on the map',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
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
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final routeService = context.read<RouteManagementService>();
                
                // Check bus number uniqueness
                final isUnique = await routeService.isBusNumberUnique(
                  busNumberController.text.trim(),
                  widget.college.id,
                  route?['id'],
                );
                
                if (!isUnique) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bus number already exists for this college'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                bool success;
                if (isEditing) {
                  // Update logic would go here
                  success = false; // Placeholder
                } else {
                  success = await routeService.createRoute(
                    collegeId: widget.college.id,
                    busNumber: busNumberController.text.trim(),
                    routeName: routeNameController.text.trim(),
                    startLocation: startLocationController.text.trim(),
                    endLocation: endLocationController.text.trim(),
                  );
                }

                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEditing 
                            ? 'Route updated successfully' 
                            : 'Route created successfully'
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else if (routeService.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(routeService.error!),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(isEditing ? 'Update' : 'Create'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRoute(BuildContext context, Map<String, dynamic> route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text('Are you sure you want to delete route ${route['bus_number']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final routeService = context.read<RouteManagementService>();
              final success = await routeService.deleteRoute(route['id'], widget.college.id);
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Route deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else if (routeService.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(routeService.error!),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRouteMapDialog(BuildContext context, Map<String, dynamic> route) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteMapScreen(
          route: route,
          college: widget.college,
          onRouteSaved: (updatedRoute) {
            // Refresh the routes list after saving
            context.read<RouteManagementService>().loadCollegeRoutes(widget.college.id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Route path saved successfully'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final Map<String, dynamic> route;
  final College college;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(bool) onToggleStatus;
  final VoidCallback onSetRoute;

  const _RouteCard({
    required this.route,
    required this.college,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
    required this.onSetRoute,
  });

  @override
  Widget build(BuildContext context) {
    final hasPolyline = route['polyline_data'] != null && route['polyline_data'].toString().isNotEmpty;
    final isActive = route['active'] == true;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    route['bus_number'] ?? 'Unknown',
                    style: AppTypography.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route['route_name'] ?? 'Unnamed Route',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${route['start_location']} → ${route['end_location']}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isActive,
                  onChanged: onToggleStatus,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Route info chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _InfoChip(
                    icon: Icons.map,
                    label: hasPolyline ? 'Route Set' : 'No Route',
                    color: hasPolyline ? Colors.green : Colors.orange,
                  ),
                  if (route['distance_km'] != null) ...[
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.straighten,
                      label: '${route['distance_km']} km',
                      color: Colors.blue,
                    ),
                  ],
                  if (route['estimated_duration_minutes'] != null) ...[
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.access_time,
                      label: '${route['estimated_duration_minutes']} min',
                      color: Colors.purple,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Action buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: onSetRoute,
                    icon: Icon(hasPolyline ? Icons.map : Icons.add_location),
                    label: Text(hasPolyline ? 'View Map' : 'Set Route'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


