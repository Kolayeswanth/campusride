import 'package:flutter/material.dart';
import 'driver_dashboard_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  
  @override
  void initState() {
    super.initState();
    // Navigate to dashboard after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToDashboard();
    });
  }

  void _navigateToDashboard() {
    Navigator.pushNamed(context, '/driver_dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}