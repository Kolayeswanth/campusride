import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/trip_service.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/animations/animations.dart';
import 'bus_tracking_screen.dart';
import 'bus_search_screen.dart';

/// PassengerHomeScreen is the main screen for passenger users.
/// It shows nearby buses, allows searching for routes, and displays a map.
class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({Key? key}) : super(key: key);

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  int _currentIndex = 0;
  Timer? _refreshTimer;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  
  // Demo data for buses
  final List<Map<String, dynamic>> _nearbyBuses = [
    {
      'id': 'bus1',
      'name': 'Engineering Campus Bus',
      'routeNumber': '101',
      'eta': '2 min',
      'distance': '0.3 km',
      'currentStop': 'Student Center',
      'nextStop': 'Engineering Building',
      'capacity': 'Low',
      'isExpress': false,
    },
    {
      'id': 'bus2',
      'name': 'Main Campus Express',
      'routeNumber': '202',
      'eta': '5 min',
      'distance': '0.8 km',
      'currentStop': 'Library',
      'nextStop': 'Student Center',
      'capacity': 'Medium',
      'isExpress': true,
    },
    {
      'id': 'bus3',
      'name': 'South Campus Shuttle',
      'routeNumber': '303',
      'eta': '8 min',
      'distance': '1.2 km',
      'currentStop': 'Sports Complex',
      'nextStop': 'Dining Hall',
      'capacity': 'High',
      'isExpress': false,
    },
  ];
  
  // Demo data for favorite routes
  final List<Map<String, dynamic>> _favoriteRoutes = [
    {
      'id': 'route1',
      'name': 'Dorm to Engineering',
      'startPoint': 'Residence Hall',
      'endPoint': 'Engineering Building',
      'busNumbers': ['101', '202'],
      'duration': '15 min',
    },
    {
      'id': 'route2',
      'name': 'Main Campus Loop',
      'startPoint': 'Student Center',
      'endPoint': 'Student Center',
      'busNumbers': ['101', '303'],
      'duration': '25 min',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Refresh bus data every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshBusData();
    });
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }
  
  /// Sign out the user
  Future<void> _signOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query.toLowerCase();
      });
      
      // If search query is not empty, show a snackbar with instructions
      if (query.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Searching for "$query"...'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'View All Results',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BusSearchScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
    });
  }
  
  void _navigateToRoute(String routeId, String routeName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusTrackingScreen(
          routeId: routeId,
          busId: 'bus_${routeId.substring(0, 4)}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripService = Provider.of<TripService>(context);
    final authService = Provider.of<AuthService>(context);
    
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with user greeting
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good Morning, Student',
                    style: AppTypography.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Where are you headed today?',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            // Plan Your Trip Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plan Your Trip',
                    style: AppTypography.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Enter starting point',
                      prefixIcon: const Icon(Icons.location_on, color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Enter destination',
                      prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Planning your trip... This feature is coming soon!'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Find Routes'),
                    ),
                  ),
                ],
              ),
            ),
            
            // Search bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search routes, buses, or stops',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textHint,
                  ),
                  prefixIcon: const Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nearby buses section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Nearby Buses',
                            style: AppTypography.titleLarge,
                          ),
                          TextButton(
                            onPressed: () {
                              // View all
                            },
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _nearbyBuses.length,
                        itemBuilder: (context, index) {
                          final bus = _nearbyBuses[index];
                          return _buildBusCard(bus);
                        },
                      ),
                    ),
                    
                    // Favorite routes section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Favorite Routes',
                            style: AppTypography.titleLarge,
                          ),
                          TextButton(
                            onPressed: () {
                              // View all
                            },
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _favoriteRoutes.length,
                      itemBuilder: (context, index) {
                        final route = _favoriteRoutes[index];
                        return _buildRouteCard(route);
                      },
                    ),
                    
                    // Map section
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Map View',
                        style: AppTypography.titleLarge,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 48,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Campus Map',
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            CustomButton.small(
                              text: 'Open Map',
                              onPressed: () {
                                // Open map
                              },
                              prefixIcon: Icons.open_in_new,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Routes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Favorites',
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
  
  /// Builds a card for a nearby bus.
  Widget _buildBusCard(Map<String, dynamic> bus) {
    final isExpress = bus['isExpress'] as bool;
    Color capacityColor;
    
    switch (bus['capacity']) {
      case 'Low':
        capacityColor = Colors.green;
        break;
      case 'Medium':
        capacityColor = Colors.orange;
        break;
      case 'High':
        capacityColor = Colors.red;
        break;
      default:
        capacityColor = Colors.grey;
    }
    
    return Container(
      width: 260,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: GlassmorphicContainer(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${bus['routeNumber']}',
                      style: AppTypography.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bus['name'],
                      style: AppTypography.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isExpress)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentPeach,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Express',
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.deepOrange[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.directions_bus_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ETA: ${bus['eta']}',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${bus['distance']} away',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: capacityColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: capacityColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          bus['capacity'],
                          style: AppTypography.labelSmall.copyWith(
                            color: capacityColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next Stop',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          bus['nextStop'],
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  CustomButton.small(
                    text: 'Track',
                    onPressed: () {
                      // Track this bus
                    },
                    prefixIcon: Icons.location_on,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Builds a card for a favorite route.
  Widget _buildRouteCard(Map<String, dynamic> route) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    route['name'],
                    style: AppTypography.titleMedium,
                  ),
                ),
                Icon(
                  Icons.favorite,
                  color: AppColors.accentPeach,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${route['startPoint']} → ${route['endPoint']}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.access_time_filled,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  route['duration'],
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                ...List.generate(
                  (route['busNumbers'] as List).length,
                  (index) => Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${route['busNumbers'][index]}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // This would be connected to a real API in a production app
  void _refreshBusData() {
    // Simulate API call
    if (mounted) {
      setState(() {
        // Update bus ETAs and distances
        for (var bus in _nearbyBuses) {
          final currentEta = bus['eta'].toString();
          final currentDistance = bus['distance'].toString();
          
          // Simulate movement
          if (currentEta.contains('min')) {
            final minutes = int.parse(currentEta.split(' ').first);
            if (minutes > 1) {
              bus['eta'] = '${minutes - 1} min';
              
              // Also update distance
              final distance = double.parse(currentDistance.split(' ').first);
              bus['distance'] = '${(distance - 0.1).toStringAsFixed(1)} km';
            } else {
              bus['eta'] = 'Arriving';
              bus['distance'] = 'At stop';
            }
          }
        }
      });
    }
  }
} 