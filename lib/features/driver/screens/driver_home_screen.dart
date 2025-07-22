import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/trip_service.dart';
import '../../../core/theme/app_colors.dart';
import './driver_route_screen.dart';
import './driver_trip_history_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _isLoading = true;
  String? _error;
  List<BusRoute> _routes = [];

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tripService = Provider.of<TripService>(context, listen: false);
      
      // Initialize trip service to check for any existing active trips
      await tripService.initializeTripService();
      
      print('Loading driver routes...');
      final routes = await tripService.fetchDriverRoutes();
      print('Routes loaded: ${routes.length}');
      
      if (mounted) {
        setState(() {
          _routes = routes;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading routes: $e');
      
      if (mounted) {
        setState(() {
          _error = 'Error loading routes: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshRoutes() async {
    if (!mounted) return;
    
    try {
      final tripService = Provider.of<TripService>(context, listen: false);
      print('Refreshing driver routes...');
      final routes = await tripService.refreshRoutes();
      print('Routes refreshed: ${routes.length}');
      
      if (mounted) {
        setState(() {
          _routes = routes;
          _error = null;
        });
      }
    } catch (e) {
      print('Error refreshing routes: $e');
      
      if (mounted) {
        setState(() {
          _error = 'Error refreshing routes: $e';
        });
      }
    }
  }

  void _navigateToRoute(String routeId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverRouteScreen(routeId: routeId),
      ),
    );
  }

  void _showRouteInUseMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This route is currently being used by another driver'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _navigateToTripHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DriverTripHistoryScreen(),
      ),
    );
  }

  Future<void> _signOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();
    
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Widget _buildRouteInfoRow(Widget icon, String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: icon,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildConcentricCirclesIcon({
    required Color outerColor,
    required Color innerColor,
    double size = 20,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer circle
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: outerColor,
              border: Border.all(color: Colors.grey.shade300, width: 0.5),
            ),
          ),
          // Middle white circle
          Container(
            width: size * 0.7,
            height: size * 0.7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
          // Inner circle
          Container(
            width: size * 0.4,
            height: size * 0.4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: innerColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTrip() {
    return Consumer<TripService>(
      builder: (context, tripService, child) {
        final tripStatus = tripService.getCurrentTripStatus();
        
        if (!tripStatus['hasActiveTrip']) {
          return const SizedBox.shrink();
        }

        final trip = tripStatus['trip'] as DriverTrip;
        final duration = tripStatus['formattedDuration'] as String;
        final isLiveSharing = tripStatus['isLiveLocationSharing'] as bool;

        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade50, Colors.green.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'ACTIVE TRIP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isLiveSharing)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.directions_bus, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Bus: ${trip.busNumber ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Duration: $duration',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.route, size: 16, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Route: ${trip.routeId}',
                        style: TextStyle(color: Colors.green.shade700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToRoute(trip.routeId),
                        icon: const Icon(Icons.map),
                        label: const Text('View Trip'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEndTripDialog(trip),
                        icon: const Icon(Icons.stop),
                        label: const Text('End Trip'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEndTripDialog(DriverTrip trip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Trip'),
        content: Text('Are you sure you want to end the trip for Bus ${trip.busNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _endCurrentTrip();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Trip'),
          ),
        ],
      ),
    );
  }

  Future<void> _endCurrentTrip() async {
    try {
      final tripService = Provider.of<TripService>(context, listen: false);
      final success = await tripService.endDriverTrip();
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip ended successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh routes to update status
        await _refreshRoutes();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to end trip'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ending trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildRouteCard(BusRoute route) {
    final isDisabled = route.isInUseByOther;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isDisabled ? 1 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1.0,
        child: Stack(
          children: [
            InkWell(
              onTap: isDisabled ? _showRouteInUseMessage : () => _navigateToRoute(route.id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: isDisabled 
                        ? [Colors.grey.shade200, Colors.grey.shade300]
                        : [AppColors.primary.withOpacity(0.1), AppColors.primary.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row with route name and status
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDisabled ? Colors.orange : AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            route.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDisabled 
                                ? Colors.orange
                                : (route.isActive ? Colors.green : Colors.grey),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isDisabled 
                                ? 'Trip ongoing...' 
                                : (route.isActive ? 'Active' : 'Inactive'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Route information
                    _buildRouteInfoRow(
                      _buildConcentricCirclesIcon(
                        outerColor: Colors.green.shade100,
                        innerColor: Colors.green,
                      ),
                      'From',
                      route.startLocationName.isNotEmpty 
                          ? route.startLocationName 
                          : 'Start Location',
                    ),
                    
                    const SizedBox(height: 8),
                    
                    _buildRouteInfoRow(
                      _buildConcentricCirclesIcon(
                        outerColor: Colors.red.shade100,
                        innerColor: Colors.red,
                      ),
                      'To',
                      route.endLocationName.isNotEmpty 
                          ? route.endLocationName 
                          : 'End Location',
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Route statistics
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoChip(
                            Icons.straighten,
                            'Distance',
                            route.formattedDistance,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoChip(
                            Icons.access_time,
                            'Duration',
                            route.formattedDuration,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Disabled overlay
            if (isDisabled)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withOpacity(0.1),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock,
                      color: Colors.orange,
                      size: 32,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('DriverHomeScreen build called - isLoading: $_isLoading, error: $_error, routes: ${_routes.length}');
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _navigateToTripHistory,
            tooltip: 'Trip History',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshRoutes,
            tooltip: 'Refresh Routes',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadRoutes,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshRoutes,
              child: _routes.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.route,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No routes available',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Pull to refresh or contact your administrator',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Show active trip at the top if exists
                        _buildActiveTrip(),
                        // Routes list
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _routes.length,
                            itemBuilder: (context, index) {
                              final route = _routes[index];
                              return _buildRouteCard(route);
                            },
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}
