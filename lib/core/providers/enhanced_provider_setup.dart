import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/realtime_service.dart';
import '../services/trip_service.dart';

/// Enhanced provider setup that includes RealtimeService
class EnhancedProviderSetup extends StatelessWidget {
  final Widget child;

  const EnhancedProviderSetup({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Add RealtimeService as a provider
        ChangeNotifierProvider(
          create: (context) {
            final realtimeService = RealtimeService();
            // Initialize subscriptions when the service is created
            realtimeService.initializeSubscriptions();
            return realtimeService;
          },
          lazy: false, // Initialize immediately
        ),
        
        // Enhanced TripService that can use RealtimeService
        ChangeNotifierProxyProvider<RealtimeService, TripService>(
          create: (context) => TripService(),
          update: (context, realtimeService, tripService) {
            // You can inject the realtime service into trip service here
            return tripService ?? TripService();
          },
        ),
      ],
      child: child,
    );
  }
}
