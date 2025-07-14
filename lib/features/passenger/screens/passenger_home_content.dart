import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/realtime_service.dart';
import '../../../core/debug/realtime_debugger.dart';

/// PassengerHomeContent contains the main home screen content without Scaffold wrapper
/// This allows it to be embedded in MainNavigationScreen with persistent bottom navigation
class PassengerHomeContent extends StatefulWidget {
  const PassengerHomeContent({Key? key}) : super(key: key);

  @override
  State<PassengerHomeContent> createState() => _PassengerHomeContentState();
}

class _PassengerHomeContentState extends State<PassengerHomeContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RealtimeService>(
      builder: (context, realtimeService, child) {
        return Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLiveBusesTab(realtimeService),
                  _buildAllBusesTab(realtimeService),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue,
            Colors.blue.withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Campus Ride',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Track your bus in real-time',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RealtimeDebugScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.bug_report,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        // Add notification functionality
                      },
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 24,
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

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.blue,
        labelColor: Colors.blue,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        tabs: const [
          Tab(
            text: 'Live Buses',
            icon: Icon(Icons.live_tv, size: 20),
          ),
          Tab(
            text: 'All Buses',
            icon: Icon(Icons.directions_bus, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBusesTab(RealtimeService realtimeService) {
    final activeTrips = realtimeService.activeTrips;
    
    return Column(
      children: [
        // Debug info panel
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            border: Border.all(color: Colors.blue[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Real-time Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Active trips detected: ${activeTrips.length}',
                style: TextStyle(fontSize: 12, color: Colors.blue[600]),
              ),
              Text(
                'Last update: ${DateTime.now().toString().substring(11, 19)}',
                style: TextStyle(fontSize: 12, color: Colors.blue[600]),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RealtimeDebugScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 32),
                ),
                child: const Text('Debug Real-time Connection', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        // Buses list
        Expanded(
          child: activeTrips.isEmpty
              ? _buildEmptyState(
                  icon: Icons.live_tv_outlined,
                  title: 'No Live Buses',
                  subtitle: 'Tap the debug button above to troubleshoot connection issues',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: activeTrips.length,
                  itemBuilder: (context, index) {
                    final tripData = activeTrips.values.elementAt(index);
                    return _buildLiveBusCard(tripData);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAllBusesTab(RealtimeService realtimeService) {
    // For now, show active trips in all buses tab too
    // You can extend this to show all available buses from your database
    final activeTrips = realtimeService.activeTrips;
    
    if (activeTrips.isEmpty) {
      return _buildEmptyState(
        icon: Icons.directions_bus_outlined,
        title: 'No Buses Available',
        subtitle: 'Check back later for available buses',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeTrips.length,
      itemBuilder: (context, index) {
        final tripData = activeTrips.values.elementAt(index);
        return _buildBusCard(tripData, isLive: true);
      },
    );
  }

  Widget _buildLiveBusCard(Map<String, dynamic> tripData) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tripData['bus_number'] ?? 'Unknown Bus',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tripData['route_name'] ?? 'Unknown Route',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.location_on,
                    color: Colors.green,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      tripData['destination'] ?? 'Unknown Destination',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _openLiveTracking(tripData),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Track Live'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusCard(Map<String, dynamic> tripData, {required bool isLive}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      Row(
                        children: [
                          if (isLive) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            tripData['bus_number'] ?? 'Unknown Bus',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tripData['route_name'] ?? 'Unknown Route',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isLive ? Icons.location_on : Icons.directions_bus,
                  color: isLive ? Colors.green : Colors.grey,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    tripData['destination'] ?? 'Unknown Destination',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLive ? () => _openLiveTracking(tripData) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLive ? Colors.blue : Colors.grey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(isLive ? 'Track Live' : 'Not Available'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _openLiveTracking(Map<String, dynamic> tripData) {
    // For now, just show a message since we simplified the tracking screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tracking ${tripData['bus_number'] ?? 'Unknown Bus'}'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
