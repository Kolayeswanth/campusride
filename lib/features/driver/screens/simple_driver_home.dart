import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';

class SimpleDriverHome extends StatelessWidget {
  const SimpleDriverHome({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard - Simple'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.local_shipping,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome, Driver!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'User ID: ${authService.currentUser?.id ?? 'Unknown'}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Role: ${authService.userRole ?? 'Unknown'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                print('Driver screen is working!');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Driver screen is working!')),
                );
              },
              child: const Text('Test Button'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await authService.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}
