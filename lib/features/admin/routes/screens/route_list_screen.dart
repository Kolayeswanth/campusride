import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/route_service.dart';
//import '../models/route.dart' as route_model;
import 'route_form_screen.dart';

class RouteListScreen extends StatefulWidget {
  final String collegeId;

  const RouteListScreen({
    Key? key,
    required this.collegeId,
  }) : super(key: key);

  @override
  State<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends State<RouteListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<RouteService>().loadRoutes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<RouteService>().loadRoutes();
            },
          ),
        ],
      ),
      body: Consumer<RouteService>(
        builder: (context, routeService, child) {
          if (routeService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (routeService.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    routeService.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      routeService.loadRoutes();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final routes = routeService.getRoutesForCollege(widget.collegeId);

          if (routes.isEmpty) {
            return const Center(
              child: Text('No routes found'),
            );
          }

          return ListView.builder(
            itemCount: routes.length,
            itemBuilder: (context, index) {
              final route = routes[index];
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.route),
                  ),
                  title: Text(route.name ?? 'Bus ${route.busNumber}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('From: ${route.startLocation}'),
                      Text('To: ${route.endLocation}'),
                      if (route.description != null) Text(route.description!),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: route.isActive,
                        onChanged: (value) {
                          routeService.toggleRouteStatus(route.id, value);
                        },
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          switch (value) {
                            case 'edit':
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RouteFormScreen(
                                    collegeId: widget.collegeId,
                                    route: route,
                                  ),
                                ),
                              );
                              context.read<RouteService>().loadRoutes();
                              break;
                            case 'delete':
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Route'),
                                  content: const Text(
                                    'Are you sure you want to delete this route?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context, false);
                                      },
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context, true);
                                      },
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                await routeService.deleteRoute(route.id);
                                context.read<RouteService>().loadRoutes();
                              }
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RouteFormScreen(
                          collegeId: widget.collegeId,
                          route: route,
                        ),
                      ),
                    );
                    context.read<RouteService>().loadRoutes();
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RouteFormScreen(
                collegeId: widget.collegeId,
              ),
            ),
          );
          context.read<RouteService>().loadRoutes();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
} 