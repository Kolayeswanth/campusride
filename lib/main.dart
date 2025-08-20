import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/map_service.dart';
import 'core/services/trip_service.dart';
import 'core/services/navigation_service.dart';
import 'core/services/route_management_service.dart';
import 'core/services/realtime_service.dart';
import 'features/admin/services/super_admin_service.dart';
import 'features/admin/drivers/services/driver_service.dart';
import 'features/admin/services/driver_location_service.dart';
import 'features/admin/colleges/services/college_service.dart';
import 'features/admin/screens/super_admin_login_screen.dart';
import 'features/admin/screens/super_admin_dashboard_screen.dart';
import 'features/driver/screens/driver_home_screen.dart';
import 'features/passenger/screens/main_navigation_screen.dart';
import 'features/auth/screens/unified_login_screen.dart';
import 'features/auth/screens/unified_registration_screen.dart';
import 'features/auth/widgets/auth_wrapper.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables with error handling
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    if (kDebugMode) {
      print('Error loading .env file: $e');
    }
    // Continue execution even if .env fails to load
  }

  // Initialize Supabase
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseKey = dotenv.env['SUPABASE_KEY'];

  if (supabaseUrl == null || supabaseKey == null) {
    if (kDebugMode) {
      print('SUPABASE_URL or SUPABASE_KEY not found in .env file. Using fallback values.');
    }
    // Use fallback values for development
    final fallbackUrl = 'https://lraiyjinbsjloqjvlqwl.supabase.co';
    final fallbackKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxyYWl5amluYnNqbG9xanZscXdsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQzNDkyODgsImV4cCI6MjA1OTkyNTI4OH0.RvfjSaZSmX0EOmvvYOMOFeZ2x1pmg69hyeWNyOo4smE';
    
    try {
      await Supabase.initialize(
        url: supabaseUrl ?? fallbackUrl,
        anonKey: supabaseKey ?? fallbackKey,
        debug: kDebugMode,
      );
      if (kDebugMode) {
        print('Supabase initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Supabase: $e');
      }
      // Continue with app initialization even if Supabase fails
    }
  } else {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        debug: kDebugMode,
      );
      if (kDebugMode) {
        print('Supabase initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Supabase: $e');
      }
      // Continue with app initialization even if Supabase fails
    }
  }
  
  // Always run the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService.instance),
        ChangeNotifierProvider(create: (_) => RealtimeService()),
        ChangeNotifierProvider(create: (_) => SuperAdminService()),
        ChangeNotifierProvider(create: (_) => DriverService()),
        ChangeNotifierProvider(create: (_) => RouteManagementService()),
        ChangeNotifierProvider(create: (_) => DriverLocationService()),
        ChangeNotifierProvider(create: (_) => CollegeService()),
        ChangeNotifierProvider(create: (_) => MapService()),
        ChangeNotifierProvider(create: (_) => TripService()),
        ChangeNotifierProvider(create: (_) => NavigationService()),
      ],
      child: MaterialApp(
        title: 'CampusRide',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthWrapper(),
          '/login': (context) => const UnifiedLoginScreen(),
          '/register': (context) => const UnifiedRegistrationScreen(),
          '/admin/login': (context) => const SuperAdminLoginScreen(),
          '/admin/dashboard': (context) => const SuperAdminDashboardScreen(),
          '/driver_home': (context) => const DriverHomeScreen(),
          '/passenger_home': (context) => const MainNavigationScreen(),
        },
      ),
    );
  }
}
