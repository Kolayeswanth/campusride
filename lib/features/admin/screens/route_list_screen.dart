import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/route_model.dart';
import '../providers/route_provider.dart';

class RouteListScreen extends ConsumerWidget {
  final String collegeId;

  const RouteListScreen({
    Key? key,
    required this.collegeId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(routesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routes'),
      ),
      body: routesAsync.when(
        data: (routes) {
          final collegeRoutes = routes.where((r) => r.collegeId == collegeId).toList();
          
          if (collegeRoutes.isEmpty) {
            return const Center(
              child: Text('No routes found for this college'),
            );
          }

          return ListView.builder(
            itemCount: collegeRoutes.length,
            itemBuilder: (context, index) {
              final route = collegeRoutes[index];
              return RouteCard(route: route);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}

class RouteCard extends StatefulWidget {
  final RouteModel route;

  const RouteCard({
    Key? key,
    required this.route,
  }) : super(key: key);

  @override
  State<RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<RouteCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            title: Text('Route ${widget.route.id}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Start: ${widget.route.startLocation}'),
                Text('End: ${widget.route.endLocation}'),
              ],
            ),
            trailing: IconButton(
              icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Route Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Driver ID: ${widget.route.driverId}'),
                  Text('Status: ${widget.route.isActive ? 'Active' : 'Inactive'}'),
                  if (widget.route.createdAt != null)
                    Text('Created: ${widget.route.createdAt}'),
                  if (widget.route.updatedAt != null)
                    Text('Last Updated: ${widget.route.updatedAt}'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          // TODO: Implement edit route
                        },
                        child: const Text('Edit'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          // TODO: Implement delete route
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
  }
} 