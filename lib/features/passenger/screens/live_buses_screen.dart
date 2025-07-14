import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/realtime_service.dart';
import '../models/bus_info.dart';
import 'live_bus_tracking_screen.dart';

/// Live Buses Screen - Shows only live/active buses
class LiveBusesScreen extends StatefulWidget {
  const LiveBusesScreen({Key? key}) : super(key: key);

  @override
  State<LiveBusesScreen> createState() => _LiveBusesScreenState();
}

class _LiveBusesScreenState extends State<LiveBusesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredLiveBuses(Map<String, Map<String, dynamic>> activeTrips) {
    if (_searchQuery.isEmpty) {
      return activeTrips.values.toList();
    }
    
    return activeTrips.values.where((trip) {
      final routeName = (trip['route_name'] as String? ?? '').toLowerCase();
      final busNumber = (trip['bus_number'] as String? ?? '').toLowerCase();
      final fromDest = (trip['from_destination'] as String? ?? '').toLowerCase();
      final toDest = (trip['to_destination'] as String? ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return routeName.contains(query) ||
             busNumber.contains(query) ||
             fromDest.contains(query) ||
             toDest.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Live Buses'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final realtimeService = Provider.of<RealtimeService>(context, listen: false);
              realtimeService.refreshCollegeFilter();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
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
                  decoration: InputDecoration(
                    hintText: 'Search live buses...',
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[400]),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ),

            // Live buses list
            Expanded(
              child: Consumer<RealtimeService>(
                builder: (context, realtimeService, child) {
                  final filteredBuses = _getFilteredLiveBuses(realtimeService.activeTrips);
                  
                  if (filteredBuses.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.live_tv_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty 
                                ? 'No buses found for "$_searchQuery"'
                                : 'No live buses right now',
                            style: AppTypography.titleMedium.copyWith(
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty 
                                ? 'Try a different search term'
                                : 'Buses will appear here when active',
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
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
                                      '${filteredBuses.length} LIVE',
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
                        ),
                        
                        // Buses list
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: filteredBuses.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final trip = filteredBuses[index];
                              final location = realtimeService.getDriverLocation(trip['id']);
                              return _buildLiveBusCard(trip, location);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
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
