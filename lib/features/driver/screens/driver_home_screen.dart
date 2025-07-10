import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/trip_service.dart';
import '../../../core/theme/app_colors.dart';
import 'driver_route_screen.dart';

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

  void _navigateToRoute(String routeId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverRouteScreen(routeId: routeId),
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadRoutes,
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
              onRefresh: _loadRoutes,
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
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _routes.length,
                itemBuilder: (context, index) {
                  final route = _routes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(route.name),
                      subtitle: Text(
                        '${route.startLocation.latitude.toStringAsFixed(4)}, ${route.startLocation.longitude.toStringAsFixed(4)} → ${route.endLocation.latitude.toStringAsFixed(4)}, ${route.endLocation.longitude.toStringAsFixed(4)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _navigateToRoute(route.id),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
