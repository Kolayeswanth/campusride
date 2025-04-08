import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/widgets.dart';
import 'init_database.dart';

/// Debug screen for development and testing
class DebugScreen extends StatefulWidget {
  const DebugScreen({Key? key}) : super(key: key);

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  /// Initialize database tables
  void _initializeDatabase() async {
    await InitDatabase.initializeDatabase(context);
  }
  
  /// Create a test account
  void _createTestAccount() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showSnackBar('Please fill all fields');
      return;
    }
    
    final authService = Provider.of<AuthService>(context, listen: false);
    
    await authService.registerWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
      _nameController.text.trim(),
    );
    
    if (authService.error != null) {
      if (mounted) {
        _showSnackBar('Error: ${authService.error}');
      }
    } else {
      if (mounted) {
        _showSnackBar('Account created successfully');
      }
    }
  }
  
  /// Test driver sign-in
  void _testDriverSignIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Please enter email and password');
      return;
    }
    
    final authService = Provider.of<AuthService>(context, listen: false);
    
    await authService.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
    );
    
    if (authService.error != null) {
      if (mounted) {
        _showSnackBar('Error: ${authService.error}');
        return;
      }
    }
    
    // Set role to driver
    await authService.updateUserRole('driver');
    
    if (authService.error != null) {
      if (mounted) {
        _showSnackBar('Error setting role: ${authService.error}');
      }
    } else {
      if (mounted) {
        _showSnackBar('Driver role set successfully');
      }
    }
  }
  
  /// Sign out
  void _signOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();
    
    if (authService.error != null) {
      if (mounted) {
        _showSnackBar('Error: ${authService.error}');
      }
    } else {
      if (mounted) {
        _showSnackBar('Signed out successfully');
      }
    }
  }
  
  /// Show snackbar message
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Tools'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Authentication status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Authentication Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          authService.isAuthenticated
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: authService.isAuthenticated
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          authService.isAuthenticated
                              ? 'Authenticated'
                              : 'Not Authenticated',
                        ),
                      ],
                    ),
                    if (authService.isAuthenticated) ...[
                      const SizedBox(height: 8),
                      Text('User: ${authService.currentUser?.email}'),
                      Text('Role: ${authService.userRole ?? 'Not set'}'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _signOut,
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Database initialization
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Database',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Initialize the database schema and create tables required for the app.',
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _initializeDatabase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                      ),
                      child: const Text('Initialize Database'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Account creation & role testing
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Test Account',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _createTestAccount,
                            child: const Text('Create Account'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _testDriverSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            child: const Text('Test Driver Sign In'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Current user profile
            if (authService.isAuthenticated)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Profile',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('ID: ${authService.currentUser!.id}'),
                      Text('Email: ${authService.currentUser!.email}'),
                      Text('Created At: ${authService.currentUser!.createdAt}'),
                      Text('Role: ${authService.userRole ?? 'Not set'}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              await authService.updateUserRole('driver');
                              if (authService.error != null) {
                                if (mounted) {
                                  _showSnackBar('Error: ${authService.error}');
                                }
                              } else {
                                if (mounted) {
                                  _showSnackBar('Role set to driver');
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            child: const Text('Set as Driver'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              await authService.updateUserRole('passenger');
                              if (authService.error != null) {
                                if (mounted) {
                                  _showSnackBar('Error: ${authService.error}');
                                }
                              } else {
                                if (mounted) {
                                  _showSnackBar('Role set to passenger');
                                }
                              }
                            },
                            child: const Text('Set as Passenger'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 