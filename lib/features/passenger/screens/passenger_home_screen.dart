import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/realtime_service.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeRealtimeSubscriptions();
  }

  /// Initialize real-time subscriptions for live data updates
  void _initializeRealtimeSubscriptions() {
    
    
    final realtimeService = Provider.of<RealtimeService>(context, listen: false);
    realtimeService.initializeSubscriptions();
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
                                          color: Colors.grey.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: Colors.grey,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'INACTIVE',
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
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
    // Sample offline buses - in real app, this would come from database
    final offlineBuses = [
      {
        'routeName': 'B2',
        'busNumber': 'AP28AB1234',
        'fromDestination': 'SRKR Engineering College',
        'toDestination': 'Bhimavaram Junction',
        'lastSeen': DateTime.now().subtract(Duration(hours: 2)),
        'status': 'Parked',
      },
      {
        'routeName': 'C3',
        'busNumber': 'AP28CD5678',
        'fromDestination': 'Narasapuram',
        'toDestination': 'Engineering College',
        'lastSeen': DateTime.now().subtract(Duration(hours: 5)),
        'status': 'Maintenance',
      },
      {
        'routeName': 'D1',
        'busNumber': 'AP28EF9012',
        'fromDestination': 'Palakoderu',
        'toDestination': 'College Campus',
        'lastSeen': DateTime.now().subtract(Duration(hours: 1)),
        'status': 'Break',
      },
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: offlineBuses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final bus = offlineBuses[index];
        return _buildOfflineBusCard(bus);
      },
    );
  }

  /// Builds a card for displaying offline bus information
  Widget _buildOfflineBusCard(Map<String, dynamic> bus) {
    final routeName = bus['routeName'] as String;
    final busNumber = bus['busNumber'] as String;
    final fromDestination = bus['fromDestination'] as String;
    final toDestination = bus['toDestination'] as String;
    final lastSeen = bus['lastSeen'] as DateTime;
    final status = bus['status'] as String;

    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'Parked':
        statusColor = Colors.blue;
        statusIcon = Icons.local_parking;
        break;
      case 'Maintenance':
        statusColor = Colors.orange;
        statusIcon = Icons.build;
        break;
      case 'Break':
        statusColor = Colors.purple;
        statusIcon = Icons.pause_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.bus_alert;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
        ),
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
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bus #$busNumber',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon,
                      size: 12,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
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
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fromDestination,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.grey[600],
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
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  toDestination,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.grey[600],
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
                color: Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                'Last seen ${_formatTimeDifference(lastSeen)}',
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
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
