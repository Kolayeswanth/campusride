import 'package:flutter/material.dart';
import '../models/bus_info.dart';
import '../services/bus_service.dart';
import 'bus_tracking_screen.dart';

class BusListScreen extends StatefulWidget {
  const BusListScreen({Key? key}) : super(key: key);

  @override
  _BusListScreenState createState() => _BusListScreenState();
}

class _BusListScreenState extends State<BusListScreen> {
  final BusService _busService = BusService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Buses'),
      ),
      body: StreamBuilder<List<BusInfo>>(
        stream: _busService.getActiveBuses(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final buses = snapshot.data!;
          if (buses.isEmpty) {
            return const Center(
              child: Text('No active buses available'),
            );
          }

          return ListView.builder(
            itemCount: buses.length,
            itemBuilder: (context, index) {
              final bus = buses[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text('Bus ${bus.routeNumber}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Driver: ${bus.driverId}'),
                      Text('Available Seats: ${bus.availableSeats}'),
                      Text('ETA: ${bus.estimatedTime}'),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BusTrackingScreen(
                          busId: bus.busId,
                          routeId: bus.routeId ?? '',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
