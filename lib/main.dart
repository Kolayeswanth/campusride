import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/logger_util.dart';
import 'core/utils/database_fixer.dart';
import 'core/services/auth_service.dart';
import 'core/services/map_service.dart';
import 'core/services/trip_service.dart';
import 'core/services/navigation_service.dart';
import 'core/services/route_management_service.dart';
import 'features/admin/services/super_admin_service.dart';
import 'features/admin/drivers/services/driver_service.dart';
import 'features/admin/services/driver_location_service.dart';
import 'features/admin/colleges/services/college_service.dart';
import 'features/admin/screens/super_admin_login_screen.dart';
import 'features/admin/screens/super_admin_dashboard_screen.dart';
import 'features/driver/screens/driver_home_screen.dart';
import 'features/passenger/screens/passenger_home_screen.dart';
import 'features/auth/screens/unified_login_screen.dart';
import 'features/auth/screens/unified_registration_screen.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/auth/widgets/auth_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print('Error loading .env file: $e');
  }

  // Initialize Supabase
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseKey = dotenv.env['SUPABASE_KEY'];

  if (supabaseUrl == null || supabaseKey == null) {
    LoggerUtil.fatal('SUPABASE_URL or SUPABASE_KEY not found in .env file. Please make sure your .env file is correctly configured.');
    throw Exception('SUPABASE_URL or SUPABASE_KEY not found in .env file.');
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
      debug: true, // Enable debug mode
    );
    LoggerUtil.info('Supabase initialized successfully');
    
    // Fix any database inconsistencies
    await DatabaseFixer.fixDatabaseIssues();
    
    runApp(const MyApp());
  } catch (e) {
    LoggerUtil.fatal('Error initializing Supabase: $e');
    // Continue with app initialization even if Supabase fails initially
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService.instance),
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
          '/passenger_home': (context) => const PassengerHomeScreen(),
          '/welcome': (context) => const WelcomeScreen(),
        },
      ),
    );
  }
}
