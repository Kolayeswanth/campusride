import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/college.dart';
import '../services/college_service.dart';
import '../../drivers/services/driver_service.dart';
import '../../drivers/models/driver.dart';
import '../../drivers/screens/driver_form_screen.dart';
import '../../routes/screens/route_form_screen.dart';
import 'college_form_screen.dart';
import '../../routes/services/route_service.dart';
import '../../routes/models/route.dart';

class CollegeDetailScreen extends StatefulWidget {
  final College college;

  const CollegeDetailScreen({Key? key, required this.college}) : super(key: key);

  @override
  State<CollegeDetailScreen> createState() => _CollegeDetailScreenState();
}

class _CollegeDetailScreenState extends State<CollegeDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<DriverService>().loadDrivers(widget.college.id);
      context.read<RouteService>().getRoutesByCollege(widget.college.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.college.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CollegeFormScreen(college: widget.college),
                ),
              );
              if (result == true) {
                Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // College Details Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'College Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Address: ${widget.college.address}'),
                  Text('Phone: ${widget.college.contactPhone ?? 'Not provided'}'),
                ],
              ),
            ),
            const Divider(),

            // Drivers Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Drivers',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DriverFormScreen(
                                collegeId: widget.college.id,
                              ),
                            ),
                          );
                          if (result == true) {
                            context.read<DriverService>().loadDrivers(widget.college.id);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Consumer<DriverService>(
                    builder: (context, driverService, child) {
                      if (driverService.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (driverService.error != null) {
                        return Center(
                          child: Text(
                            driverService.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      final drivers = driverService.getDriversForCollege(widget.college.id);
                      if (drivers.isEmpty) {
                        return const Center(
                          child: Text('No drivers found'),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: drivers.length,
                        itemBuilder: (context, index) {
                          final driver = drivers[index];
                          return Card(
                            child: ListTile(
                              title: Text(driver.name),
                              subtitle: Text(driver.phone),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: driver.isActive,
                                    onChanged: (value) {
                                      driverService.toggleDriverStatus(driver.id, value);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DriverFormScreen(
                                            collegeId: widget.college.id,
                                            driver: driver,
                                          ),
                                        ),
                                      );
                                      if (result == true) {
                                        driverService.loadDrivers(widget.college.id);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(),

            // Routes Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Routes',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RouteFormScreen(
                                collegeId: widget.college.id,
                              ),
                            ),
                          );
                          if (result == true) {
                            context.read<RouteService>().getRoutesByCollege(widget.college.id);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Consumer<RouteService>(
                    builder: (context, routeService, child) {
                      if (routeService.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (routeService.error != null) {
                        return Center(
                          child: Text(
                            routeService.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      final routes = routeService.routes;
                      if (routes.isEmpty) {
                        return const Center(
                          child: Text('No routes found'),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: routes.length,
                        itemBuilder: (context, index) {
                          final route = routes[index];
                          return Card(
                            child: ListTile(
                              title: Text(route.busNumber),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('From: ${route.startLocation}'),
                                  Text('To: ${route.endLocation}'),
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
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => RouteFormScreen(
                                            collegeId: widget.college.id,
                                            route: route,
                                          ),
                                        ),
                                      );
                                      if (result == true) {
                                        routeService.getRoutesByCollege(widget.college.id);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 