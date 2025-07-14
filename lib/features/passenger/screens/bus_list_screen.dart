import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import '../../../core/services/realtime_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/bus_info.dart';
import 'live_bus_tracking_screen.dart';

class BusListScreen extends StatefulWidget {
  final int initialTab;
  
  const BusListScreen({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  State<BusListScreen> createState() => _BusListScreenState();
}

class _BusListScreenState extends State<BusListScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  String? _userCollege;
  List<BusInfo> _allBuses = [];
  List<BusInfo> _filteredBuses = [];
  Set<String> _favoriteBuses = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab > 1 ? 0 : widget.initialTab);
    _loadUserData();
    _loadFavorites();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _userCollege = 'sample_college'; // For demo purposes
        _isLoading = false;
      });
      
      if (_userCollege != null) {
        _loadBuses();
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _loadBuses() {
    final realtimeService = Provider.of<RealtimeService>(context, listen: false);
    
    // Listen to real-time updates
    realtimeService.addListener(_updateBusList);
    
    // Initial load
    _updateBusList();
  }

  void _updateBusList() {
    // Check if widget is still mounted before proceeding
    if (!mounted) return;
    
    final realtimeService = Provider.of<RealtimeService>(context, listen: false);
    final activeTrips = realtimeService.activeTrips;
    final driverLocations = realtimeService.driverLocations;
    
    // Create bus info from active trips
    final buses = <BusInfo>[];
    final activeBusNumbers = <String>{};
    
    // Add active buses from real-time trips
    for (final trip in activeTrips.values) {
      final busNumber = trip['bus_number'] as String?;
      final routeId = trip['route_id'] as String?;
      final driverId = trip['driver_id'] as String?;
      final tripId = trip['id'] as String?;
      
      if (busNumber != null && routeId != null && driverId != null && tripId != null) {
        final location = driverLocations[tripId];
        
        buses.add(BusInfo.fromActiveTrip(
          busNumber: busNumber,
          routeId: routeId,
          driverId: driverId,
          tripId: tripId,
          isActive: true,
          lastLocation: location != null 
            ? latlong2.LatLng(
                (location['latitude'] as num).toDouble(),
                (location['longitude'] as num).toDouble(),
              )
            : null,
          lastUpdateTime: location != null 
            ? DateTime.parse(location['timestamp'] as String)
            : DateTime.parse(trip['start_time'] as String),
          routeName: trip['route_name'] as String? ?? _getRouteDisplayName(routeId),
          fromDestination: trip['from_destination'] as String?,
          toDestination: trip['to_destination'] as String?,
        ));
        
        activeBusNumbers.add(busNumber);
      }
    }
    
    // Add some inactive buses for demo (in real app, fetch from routes/buses table)
    _addInactiveBuses(buses, activeBusNumbers);
    
    // Check if widget is still mounted before calling setState
    if (mounted) {
      setState(() {
        _allBuses = buses;
        _filterBuses();
      });
    }
  }

  void _addInactiveBuses(List<BusInfo> buses, Set<String> activeBusNumbers) {
    // Add some sample inactive buses for the college
    final inactiveBusNumbers = [
      'BUS-001', 'BUS-002', 'BUS-003', 'BUS-004', 'BUS-005',
      'BUS-006', 'BUS-007', 'BUS-008', 'BUS-009', 'BUS-010'
    ];
    
    for (final busNumber in inactiveBusNumbers) {
      if (!activeBusNumbers.contains(busNumber)) {
        buses.add(BusInfo.fromActiveTrip(
          busNumber: busNumber,
          routeId: 'route_sample_${busNumber.toLowerCase()}',
          driverId: null,
          tripId: null,
          isActive: false,
          lastLocation: null,
          lastUpdateTime: DateTime.now().subtract(Duration(hours: 2)),
          routeName: 'Route ${busNumber.split('-').last}',
          fromDestination: 'Campus Main Gate',
          toDestination: 'City Center ${busNumber.split('-').last}',
        ));
      }
    }
  }

  String _getRouteDisplayName(String routeId) {
    // Extract route number from route ID for display
    if (routeId.contains('_')) {
      final parts = routeId.split('_');
      return 'Route ${parts.last}';
    }
    return routeId;
  }

  void _filterBuses() {
    List<BusInfo> filtered = _allBuses;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((bus) =>
        (bus.busNumber ?? bus.routeNumber).toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (bus.routeName ?? bus.destination).toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    // Sort: Active buses first, then by bus number
    filtered.sort((a, b) {
      if (a.isActive != b.isActive) {
        return a.isActive ? -1 : 1;
      }
      final aNumber = a.busNumber ?? a.routeNumber;
      final bNumber = b.busNumber ?? b.routeNumber;
      return aNumber.compareTo(bNumber);
    });
    
    setState(() {
      _filteredBuses = filtered;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterBuses();
  }

  void _toggleFavorite(String busNumber) {
    setState(() {
      if (_favoriteBuses.contains(busNumber)) {
        _favoriteBuses.remove(busNumber);
      } else {
        _favoriteBuses.add(busNumber);
      }
    });
    _saveFavorites();
  }

  Future<void> _loadFavorites() async {
    // In a real app, load from SharedPreferences or Supabase
    // For now, use some sample favorites
    setState(() {
      _favoriteBuses = {'BUS-001', 'BUS-003'};
    });
  }

  Future<void> _saveFavorites() async {
    // In a real app, save to SharedPreferences or Supabase
    print('Saving favorites: $_favoriteBuses');
  }

  void _onBusTap(BusInfo bus) {
    if (bus.isActive && (bus.lastLocation != null || bus.currentLocation.latitude != 0)) {
      // Navigate to live tracking
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LiveBusTrackingScreen(
            busInfo: bus,
          ),
        ),
      );
    } else {
      // Show inactive bus dialog
      _showInactiveBusDialog(bus);
    }
  }

  void _showInactiveBusDialog(BusInfo bus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bus ${bus.busNumber ?? bus.routeNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This bus is currently not active.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Route: ${bus.routeName}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            if (bus.fromDestination != null && bus.toDestination != null) ...[
              SizedBox(height: 8),
              Text(
                'From: ${bus.fromDestination}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 4),
              Text(
                'To: ${bus.toDestination}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
            SizedBox(height: 8),
            Text(
              'Last active: ${_formatTime(bus.lastUpdateTime ?? bus.lastUpdated)}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Try calling your driver to start the trip, then refresh this screen.',
                      style: TextStyle(fontSize: 14, color: Colors.blue[800]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadBuses(); // Refresh data
            },
            child: Text('Refresh'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Campus Buses'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Campus Buses'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'All Buses'),
            Tab(text: 'Active Only'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[50],
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search buses or routes...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          
          // Bus List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All Buses
                _buildBusList(_filteredBuses),
                
                // Active Buses Only
                _buildBusList(_filteredBuses.where((bus) => bus.isActive).toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusList(List<BusInfo> buses) {
    if (buses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No buses found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty 
                ? 'Try adjusting your search'
                : 'Check back later for updates',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _loadBuses();
      },
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: buses.length,
        itemBuilder: (context, index) {
          final bus = buses[index];
          return _buildBusCard(bus);
        },
      ),
    );
  }

  Widget _buildBusCard(BusInfo bus) {
    final busNumber = bus.busNumber ?? bus.routeNumber;
    final isFavorite = _favoriteBuses.contains(busNumber);
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => _onBusTap(bus),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Bus Icon & Status
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: bus.isActive ? Colors.green[100] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    color: bus.isActive ? Colors.green[700] : Colors.grey[600],
                    size: 24,
                  ),
                ),
                
                SizedBox(width: 16),
                
                // Bus Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            busNumber,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: bus.isActive ? Colors.green[100] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              bus.isActive ? 'ACTIVE' : 'INACTIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: bus.isActive ? Colors.green[700] : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 4),
                      
                      // Route name
                      Text(
                        bus.routeName ?? bus.destination,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                      
                      SizedBox(height: 2),
                      
                      // From and To destinations
                      if (bus.fromDestination != null && bus.toDestination != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 12,
                              color: Colors.green[600],
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                bus.fromDestination!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 1),
                        Row(
                          children: [
                            Icon(
                              Icons.arrow_downward,
                              size: 12,
                              color: Colors.grey[500],
                            ),
                            SizedBox(width: 4),
                            Text(
                              'to',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 1),
                        Row(
                          children: [
                            Icon(
                              Icons.flag,
                              size: 12,
                              color: Colors.red[600],
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                bus.toDestination!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                      ],
                      
                      Text(
                        bus.isActive 
                          ? 'Last update: ${_formatTime(bus.lastUpdateTime ?? bus.lastUpdated)}'
                          : 'Last active: ${_formatTime(bus.lastUpdateTime ?? bus.lastUpdated)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Actions
                Column(
                  children: [
                    IconButton(
                      onPressed: () => _toggleFavorite(busNumber),
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.grey[400],
                      ),
                    ),
                    
                    if (bus.isActive)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Remove the listener from RealtimeService
    final realtimeService = Provider.of<RealtimeService>(context, listen: false);
    realtimeService.removeListener(_updateBusList);
    
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
