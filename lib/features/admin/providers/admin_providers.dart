import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/route_service.dart';
import '../services/map_service.dart';

class AdminProviders extends StatelessWidget {
  final Widget child;

  const AdminProviders({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<MapService>(
          create: (context) => MapService(const String.fromEnvironment('OPENROUTE_API_KEY')),
        ),
      ],
      child: child,
    );
  }
} 