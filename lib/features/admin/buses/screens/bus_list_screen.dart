import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bus_service.dart';
import '../models/bus.dart';
import 'bus_form_screen.dart';

class BusListScreen extends StatefulWidget {
  final String collegeId;

  const BusListScreen({
    Key? key,
    required this.collegeId,
  }) : super(key: key);

  @override
  State<BusListScreen> createState() => _BusListScreenState();
}

class _BusListScreenState extends State<BusListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<BusService>().loadBuses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<BusService>().loadBuses();
            },
          ),
        ],
      ),
      body: Consumer<BusService>(
        builder: (context, busService, child) {
          if (busService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (busService.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    busService.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      busService.loadBuses();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final buses = busService.getBusesForCollege(widget.collegeId);

          if (buses.isEmpty) {
            return const Center(
              child: Text('No buses found'),
            );
          }

          return ListView.builder(
            itemCount: buses.length,
            itemBuilder: (context, index) {
              final bus = buses[index];
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ListTile(
                  leading: bus.photoUrl != null
                      ? CircleAvatar(
                          backgroundImage: NetworkImage(bus.photoUrl!),
                        )
                      : const CircleAvatar(
                          child: Icon(Icons.directions_bus),
                        ),
                  title: Text(bus.vehicleId ?? bus.busNumber),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (bus.routeId != null)
                        Text('Route: ${bus.routeId}'),
                      if (bus.driverId != null)
                        Text('Driver: ${bus.driverId}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: bus.isActive,
                        onChanged: (value) {
                          busService.toggleBusStatus(bus.id, value);
                        },
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          switch (value) {
                            case 'edit':
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BusFormScreen(
                                    collegeId: widget.collegeId,
                                    bus: bus,
                                  ),
                                ),
                              );
                              break;
                            case 'delete':
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Bus'),
                                  content: const Text(
                                    'Are you sure you want to delete this bus?',
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
                                await busService.deleteBus(bus.id);
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
              builder: (context) => BusFormScreen(
                collegeId: widget.collegeId,
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
} 