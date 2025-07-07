import 'package:flutter/material.dart';
import '../services/route_service.dart';
import '../services/map_service.dart';
import '../models/route_model.dart';
import 'route_selection_screen.dart';

class CollegeRoutesScreen extends StatefulWidget {
  final String collegeId;
  final String collegeName;
  final RouteService routeService;
  final MapService mapService;

  const CollegeRoutesScreen({
    Key? key,
    required this.collegeId,
    required this.collegeName,
    required this.routeService,
    required this.mapService,
  }) : super(key: key);

  @override
  State<CollegeRoutesScreen> createState() => _CollegeRoutesScreenState();
}

class _CollegeRoutesScreenState extends State<CollegeRoutesScreen> {
  List<RouteModel> _routes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() => _isLoading = true);
    try {
      final routes = await widget.routeService.getRoutesByCollege(widget.collegeId);
      setState(() => _routes = routes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading routes: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectRoute(String driverId) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RouteSelectionScreen(
          collegeId: widget.collegeId,
          driverId: driverId,
          mapService: widget.mapService,
          routeService: widget.routeService,
        ),
      ),
    );

    if (result == true) {
      _loadRoutes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.collegeName} Routes'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _routes.length,
              itemBuilder: (context, index) {
                final route = _routes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ExpansionTile(
                    title: Text('Driver: ${route.driverId}'),
                    subtitle: Text(
                      '${route.startLocation} → ${route.endLocation}',
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Start: ${route.startLocation}'),
                            const SizedBox(height: 8),
                            Text('End: ${route.endLocation}'),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => _selectRoute(route.driverId),
                                  child: const Text('Edit Route'),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      await widget.routeService.deleteRoute(route.id);
                                      _loadRoutes();
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error deleting route: $e')),
                                      );
                                    }
                                  },
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _selectRoute('new_driver'),
        child: const Icon(Icons.add),
      ),
    );
  }
} 