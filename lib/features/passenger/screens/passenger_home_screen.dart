import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/realtime_service.dart';
import '../../../core/services/favorites_service.dart';
import '../models/bus_info.dart';
import 'bus_list_screen.dart';
import 'live_bus_tracking_screen.dart';
import '../../auth/screens/profile_screen.dart';

/// PassengerHomeScreen is the main screen for passenger users.
/// It shows live bus information and provides quick access to tracking features.
class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({Key? key}) : super(key: key);

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _allBuses = [];
  List<Map<String, dynamic>> _activeDriverTrips = [];
  bool _isLoadingOfflineBuses = false;
  final FavoritesService _favoritesService = FavoritesService.instance;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeRealtimeSubscriptions();
    _loadAllBuses();
  }

  /// Initialize required services
  Future<void> _initializeServices() async {
    await _favoritesService.initialize();
  }

  /// Load all buses from database to show offline ones
  Future<void> _loadAllBuses() async {
    setState(() {
      _isLoadingOfflineBuses = true;
    });

    try {
      // Get all buses/routes from the database
      final routesResponse = await Supabase.instance.client
          .from('routes')
          .select('*')
          .order('route_name');
      
      // Get active driver trips from database
      final driverTripsResponse = await Supabase.instance.client
          .from('driver_trips')
          .select('''
            id,
            driver_id,
            route_id,
            status,
            created_at,
            routes(
              route_name,
              start_location,
              end_location,
              schedule_time
            )
          ''')
          .eq('status', 'active')
          .order('created_at', ascending: false);
      
      setState(() {
        _allBuses = List<Map<String, dynamic>>.from(routesResponse);
        _activeDriverTrips = List<Map<String, dynamic>>.from(driverTripsResponse);
        _isLoadingOfflineBuses = false;
      });
    } catch (e) {
      print('Error loading buses: $e');
      setState(() {
        _isLoadingOfflineBuses = false;
      });
    }
  }

  /// Initialize real-time subscriptions for live data updates
  void _initializeRealtimeSubscriptions() {
    
    
    final realtimeService = Provider.of<RealtimeService>(context, listen: false);
    realtimeService.initializeSubscriptions();
    
    // Listen to changes in active trips to update offline buses
    realtimeService.addListener(() {
      if (mounted) {
        setState(() {
          // This will trigger a rebuild of the offline buses section
          // with updated filtering based on new active trips
        });
      }
    });
  }

  /// Sign out the user
  Future<void> _signOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('CampusRide'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Show notifications
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                _signOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Text('Settings'),
              ),
              const PopupMenuItem(
                value: 'help',
                child: Text('Help & Support'),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Sign Out'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<RealtimeService>(
          builder: (context, realtimeService, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with user greeting and stats
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.1),
                        AppColors.primary.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome Back!',
                                style: AppTypography.headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Track your campus buses in real-time',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Colors.green,
                                  size: 8,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${realtimeService.activeTrips.length} Live',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Main Content with Live and Offline Bus Cards
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Consumer<RealtimeService>(
                      builder: (context, realtimeService, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Live Buses Section
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Live Buses',
                                        style: AppTypography.titleLarge.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${realtimeService.activeTrips.length} LIVE',
                                              style: TextStyle(
                                                color: Colors.green.shade700,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: realtimeService.activeTrips.isEmpty
                                          ? Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.live_tv_outlined,
                                                    size: 48,
                                                    color: Colors.grey[400],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    'No live buses right now',
                                                    style: AppTypography.titleMedium.copyWith(
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Buses will appear here when active',
                                                    style: AppTypography.bodySmall.copyWith(
                                                      color: Colors.grey[500],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : ListView.separated(
                                              padding: const EdgeInsets.all(16),
                                              itemCount: realtimeService.activeTrips.length,
                                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                                              itemBuilder: (context, index) {
                                                final trip = realtimeService.activeTrips.values.elementAt(index);
                                                final location = realtimeService.getDriverLocation(trip['id']);
                                                return _buildLiveBusCard(trip, location);
                                              },
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Offline Buses Section
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Offline Buses',
                                        style: AppTypography.titleLarge.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: Colors.orange,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'OFFLINE',
                                              style: TextStyle(
                                                color: Colors.orange.shade700,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: _buildOfflineBusesSection(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 1) { // Live tab - directly go to live tracking
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BusListScreen(initialTab: 0), // Tab 0 for live buses
              ),
            );
          } else if (index == 2) { // Favorites tab
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BusListScreen(initialTab: 1), // Tab 1 for favorites
              ),
            );
          } else if (index == 3) { // Profile tab
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProfileScreen(),
              ),
            );
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.live_tv_outlined),
            activeIcon: Icon(Icons.live_tv),
            label: 'Live',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Favourites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  /// Builds a card for displaying live bus information with direct tracking
  Widget _buildLiveBusCard(Map<String, dynamic> trip, Map<String, dynamic>? location) {
    final routeName = trip['route_name'] as String? ?? 'Unknown Route';
    final routeId = trip['route_id'] as String? ?? '';
    final busNumber = trip['bus_number'] as String? ?? 'Unknown';
    final fromDestination = trip['from_destination'] as String? ?? 'Unknown';
    final toDestination = trip['to_destination'] as String? ?? 'Unknown';
    final startTime = trip['start_time'] as String?;
    
    DateTime? tripStartTime;
    if (startTime != null) {
      try {
        tripStartTime = DateTime.parse(startTime);
      } catch (e) {
        // Handle parsing error
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routeName,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bus #$busNumber',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Favorite button
              IconButton(
                onPressed: () async {
                  await _favoritesService.toggleFavorite(routeId);
                  setState(() {}); // Refresh UI
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _favoritesService.isFavorite(routeId) 
                            ? 'Added to favorites' 
                            : 'Removed from favorites'
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: Icon(
                  _favoritesService.isFavorite(routeId) 
                      ? Icons.favorite 
                      : Icons.favorite_border,
                  color: _favoritesService.isFavorite(routeId) 
                      ? Colors.red 
                      : Colors.grey[600],
                ),
                iconSize: 20,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
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
          
          // Route information
          Row(
            children: [
              Icon(
                Icons.trip_origin,
                size: 16,
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fromDestination,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  toDestination,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                tripStartTime != null
                    ? 'Started ${_formatTimeDifference(tripStartTime)}'
                    : 'Active now',
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              if (location != null) ...[
                Icon(
                  Icons.gps_fixed,
                  size: 16,
                  color: Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  'Live GPS',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // Directly navigate to live tracking for this specific bus
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LiveBusTrackingScreen(
                      busInfo: BusInfo.fromActiveTrip(
                        busNumber: busNumber,
                        routeId: trip['route_id'] as String,
                        driverId: trip['driver_id'] as String,
                        tripId: trip['id'] as String,
                        isActive: true,
                        lastLocation: location != null
                            ? LatLng(
                                (location['latitude'] as num).toDouble(),
                                (location['longitude'] as num).toDouble(),
                              )
                            : null,
                        lastUpdateTime: location != null
                            ? DateTime.parse(location['timestamp'] as String)
                            : DateTime.parse(trip['start_time'] as String),
                        routeName: routeName,
                        fromDestination: fromDestination,
                        toDestination: toDestination,
                      ),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(Icons.live_tv, size: 18),
              label: Text(
                'Track Live Location',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the offline buses section
  Widget _buildOfflineBusesSection() {
    return Consumer<RealtimeService>(
      builder: (context, realtimeService, child) {
        if (_isLoadingOfflineBuses) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  'Loading buses...',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        // Show ALL buses: both offline routes and active driver trips that aren't live
        final activeTripRouteIds = realtimeService.activeTrips.values
            .map((trip) => trip['route_id'] as String?)
            .where((id) => id != null)
            .toSet();

        // Get buses from active driver trips that aren't live
        final activeOfflineTrips = _activeDriverTrips.where((driverTrip) {
          final routeId = driverTrip['route_id'] as String?;
          return routeId != null && !activeTripRouteIds.contains(routeId);
        }).toList();

        // Get all routes that don't have active driver trips
        final offlineRoutes = _allBuses.where((route) {
          final routeId = route['id'] as String?;
          final hasActiveTrip = _activeDriverTrips.any((trip) => trip['route_id'] == routeId);
          return routeId != null && !hasActiveTrip && !activeTripRouteIds.contains(routeId);
        }).toList();

        // Combine both types of offline buses
        final allOfflineBuses = <Map<String, dynamic>>[];
        
        // Add active driver trips that are offline
        for (final trip in activeOfflineTrips) {
          allOfflineBuses.add({
            'type': 'driver_trip',
            'data': trip,
            'route_id': trip['route_id'],
            'status': 'active_offline', // Driver started trip but not broadcasting
          });
        }
        
        // Add routes without any driver trips
        for (final route in offlineRoutes) {
          allOfflineBuses.add({
            'type': 'route',
            'data': route,
            'route_id': route['id'],
            'status': 'inactive', // No driver assigned/started
          });
        }

        if (allOfflineBuses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bus_alert_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  _activeDriverTrips.isEmpty 
                      ? 'No active driver trips'
                      : 'All active buses are currently live!',
                  style: AppTypography.titleMedium.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _activeDriverTrips.isEmpty
                      ? 'Drivers will appear here when they start trips'
                      : 'Great! All active buses are live with passengers',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: allOfflineBuses.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final busItem = allOfflineBuses[index];
            return _buildOfflineBusCard(busItem);
          },
        );
      },
    );
  }

  /// Builds a card for displaying offline bus information
  Widget _buildOfflineBusCard(Map<String, dynamic> busItem) {
    // Handle both types of bus items
    final String status = busItem['status'] as String? ?? 'inactive';
    final Map<String, dynamic> routeData;
    final String routeId;
    
    if (status == 'active_offline') {
      // This is a driver trip with route data nested
      routeData = busItem['routes'] as Map<String, dynamic>? ?? {};
      routeId = busItem['route_id'] as String? ?? '';
    } else {
      // This is a route without active driver trip
      routeData = busItem;
      routeId = busItem['id'] as String? ?? '';
    }
    
    final String routeName = routeData['route_name'] as String? ?? 'Unknown Route';
    final String fromDestination = routeData['start_location'] as String? ?? 'Unknown Start';
    final String toDestination = routeData['end_location'] as String? ?? 'Unknown End';
    final String? scheduleTime = routeData['schedule_time'] as String?;
    
    // Determine status display
    final bool isActiveOffline = status == 'active_offline';
    final String statusText = isActiveOffline ? 'OFFLINE' : 'INACTIVE';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with route name, offline status, and favorite button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  routeName,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const Spacer(),
              // Favorite button
              IconButton(
                onPressed: () async {
                  await _favoritesService.toggleFavorite(routeId);
                  setState(() {}); // Refresh UI
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _favoritesService.isFavorite(routeId) 
                            ? 'Added to favorites' 
                            : 'Removed from favorites'
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: Icon(
                  _favoritesService.isFavorite(routeId) 
                      ? Icons.favorite 
                      : Icons.favorite_border,
                  color: _favoritesService.isFavorite(routeId) 
                      ? Colors.red 
                      : Colors.grey[600],
                ),
                iconSize: 20,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActiveOffline ? Colors.orange[100] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActiveOffline ? Colors.orange[600] : Colors.grey[600],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: isActiveOffline ? Colors.orange[700] : Colors.grey[700],
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
          
          // Route information
          Row(
            children: [
              Icon(
                Icons.trip_origin,
                size: 16,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fromDestination,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  toDestination,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                scheduleTime != null 
                    ? 'Scheduled: $scheduleTime'
                    : 'Schedule not available',
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              Icon(
                Icons.gps_off,
                size: 16,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                'No GPS',
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // Show different info based on status
                final String message = isActiveOffline 
                    ? '$routeName is currently offline. Check back later for live tracking.'
                    : '$routeName is not currently active. Check the schedule for next availability.';
                    
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: isActiveOffline ? Colors.orange : Colors.grey,
                    duration: const Duration(seconds: 3),
                    action: SnackBarAction(
                      label: 'OK',
                      textColor: Colors.white,
                      onPressed: () {},
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isActiveOffline ? Colors.orange[100] : Colors.grey[300],
                foregroundColor: isActiveOffline ? Colors.orange[700] : Colors.grey[700],
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(Icons.schedule, size: 18),
              label: Text(
                isActiveOffline ? 'Currently Offline' : 'View Schedule',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Formats time difference in a human-readable way
  String _formatTimeDifference(DateTime startTime) {
    final now = DateTime.now();
    final difference = now.difference(startTime);
    
    if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
