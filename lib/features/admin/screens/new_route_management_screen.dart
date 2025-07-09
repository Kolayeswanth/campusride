import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/route_management_service.dart';
import '../models/college.dart';
import 'enhanced_route_creation_screen.dart';

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
      context.read<RouteManagementService>().loadCollegeRoutes(widget.college.code);
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
            onPressed: () => _navigateToRouteCreation(context),
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
                      routeService.loadCollegeRoutes(widget.college.code);
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
                    onPressed: () => _navigateToRouteCreation(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Route'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => routeService.loadCollegeRoutes(widget.college.code),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: routeService.routes.length,
              itemBuilder: (context, index) {
                final route = routeService.routes[index];
                return _RouteCard(
                  route: route,
                  college: widget.college,
                  onDelete: () => _confirmDeleteRoute(context, route),
                  onToggleStatus: (active) => routeService.toggleRouteStatus(
                    route['id'],
                    active,
                    widget.college.code,
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

  void _navigateToRouteCreation(BuildContext context, {Map<String, dynamic>? route}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedRouteCreationScreen(
          college: widget.college,
          existingRoute: route,
          onRouteSaved: (updatedRoute) {
            // Refresh the routes list after saving
            context.read<RouteManagementService>().loadCollegeRoutes(widget.college.code);
          },
        ),
      ),
    );
  }

  void _confirmDeleteRoute(BuildContext context, Map<String, dynamic> route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text('Are you sure you want to delete route ${route['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final routeService = context.read<RouteManagementService>();
              final success = await routeService.deleteRoute(route['id'], widget.college.code);
              
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
        builder: (context) => EnhancedRouteCreationScreen(
          college: widget.college,
          existingRoute: route,
          onRouteSaved: (updatedRoute) {
            // Refresh the routes list after saving
            context.read<RouteManagementService>().loadCollegeRoutes(widget.college.code);
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
  final VoidCallback onDelete;
  final Function(bool) onToggleStatus;
  final VoidCallback onSetRoute;

  const _RouteCard({
    required this.route,
    required this.college,
    required this.onDelete,
    required this.onToggleStatus,
    required this.onSetRoute,
  });

  @override
  Widget build(BuildContext context) {
    final hasPolyline = route['polyline_data'] != null && route['polyline_data'].toString().isNotEmpty;
    final isActive = route['is_active'] == true; // Changed from 'active' to 'is_active'
    
    // Extract location names from the JSONB objects
    String startLocationName = 'Unknown Start';
    String endLocationName = 'Unknown End';
    
    if (route['start_location'] is Map) {
      final startLocation = Map<String, dynamic>.from(route['start_location'] as Map);
      startLocationName = startLocation['name']?.toString() ?? 'Unknown Start';
    }
    
    if (route['end_location'] is Map) {
      final endLocation = Map<String, dynamic>.from(route['end_location'] as Map);
      endLocationName = endLocation['name']?.toString() ?? 'Unknown End';
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      elevation: isActive ? 4 : 2,
      clipBehavior: Clip.antiAlias,
      shadowColor: isActive 
          ? Colors.green.withOpacity(0.3) 
          : Colors.black.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isActive 
              ? Colors.green.withOpacity(0.4) 
              : Colors.grey.withOpacity(0.2),
          width: isActive ? 1.5 : 0.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              isActive 
                  ? Colors.green.withOpacity(0.07) 
                  : Colors.grey.withOpacity(0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row with route number and active status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route number badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    route['name'] ?? 'Unknown', // Changed from 'bus_number' to 'name'
                    style: AppTypography.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Route title and path
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        route['name'] ?? 'Unnamed Route', // Changed from 'route_name' to 'name'
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.route,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$startLocationName → $endLocationName', // Using extracted location names
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Active/Inactive status with toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive 
                        ? Colors.green.withOpacity(0.1) 
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? Icons.check_circle : Icons.cancel,
                        size: 16,
                        color: isActive ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: isActive ? Colors.green : Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 20, // Fixed height for the switch
                        width: 36,  // Fixed width for the switch
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Switch(
                            value: isActive,
                            onChanged: onToggleStatus,
                            activeColor: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            
            // Divider with gradient effect
            Container(
              height: 1.5,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.withOpacity(0.05),
                    isActive ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                    Colors.grey.withOpacity(0.05),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            const SizedBox(height: 18),
            
            // Route info section with chips and actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info chips in scrollable row
                SizedBox(
                  height: 36,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
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
                            label: '${(route['distance_km'] as num).toStringAsFixed(1)} km',
                            color: Colors.blue.shade700,
                          ),
                        ],
                        if (route['estimated_duration_minutes'] != null) ...[
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.access_time,
                            label: '${route['estimated_duration_minutes']} min',
                            color: Colors.purple.shade600,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Action buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Map/Set Route button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onSetRoute,
                        icon: Icon(
                          hasPolyline ? Icons.map : Icons.add_location,
                          size: 18,
                        ),
                        label: Text(
                          hasPolyline ? 'View Map' : 'Set Route',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasPolyline ? Colors.teal : AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: hasPolyline 
                              ? Colors.teal.withOpacity(0.3) 
                              : AppColors.primary.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Delete button
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onDelete,
                        child: Ink(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withOpacity(0.1),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {}, // Empty callback to show the ripple effect
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.05),
                color.withOpacity(0.15),
              ],
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


