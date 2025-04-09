import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:maplibre_gl/mapbox_gl.dart';
import 'core/services/auth_service.dart';
import 'core/services/map_service.dart';
import 'core/services/trip_service.dart';
import 'core/theme/theme.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/auth/screens/role_selection_screen.dart';
import 'features/passenger/screens/passenger_home_screen.dart';
import 'features/driver/screens/driver_home_screen.dart';
import 'features/driver/screens/driver_dashboard_screen.dart';
import 'features/passenger/screens/bus_tracking_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? 'https://eaxrhqfjiuydbhqxaicv.supabase.co',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVheHJocWZqaXV5ZGJocXhhaWN2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDM2NzYzNTQsImV4cCI6MjA1OTI1MjM1NH0.z54KRmsOnm6kgHXnFF8cW69jZmqvoQa4dV8weYVes8w',
    debug: kDebugMode,
  );
  
  debugPrint('Supabase initialized successfully');
  
  // Configure MapLibre
  if (kIsWeb) {
    // Web-specific configuration
    Mapbox.setAccessToken(dotenv.env['MAPLIBRE_ACCESS_TOKEN'] ?? '');
  } else {
    // Mobile-specific configuration
    Mapbox.setRenderMode(RenderMode.surfaceView);
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider<MapService>(
          create: (_) => MapService(),
        ),
        ChangeNotifierProvider<TripService>(
          create: (_) => TripService(),
        ),
      ],
      child: MaterialApp(
        title: 'CampusRide',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/welcome': (context) => const WelcomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/role_selection': (context) => const RoleSelectionScreen(),
          '/passenger_home': (context) => const PassengerHomeScreen(),
          '/driver_home': (context) => const DriverHomeScreen(),
          '/driver_dashboard': (context) => const DriverDashboardScreen(),
        },
      ),
    );
  }
}

/// AuthWrapper widget that decides which screen to show based on auth state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Return to normal app flow with splash screen
    return const SplashScreen();
  }
}
