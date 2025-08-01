import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// AuthService handles authentication state and user session management.
class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService();
  final _supabase = Supabase.instance.client;
  late final GoogleSignIn _googleSignIn;
  late SharedPreferences _prefs;
  
  User? _currentUser;
  String? _userRole;
  bool _isLoading = true;
  String? _error;
  String? _successMessage;
  
  StreamSubscription? _authSubscription;
  
  /// Constructor that sets up auth state listener
  AuthService() {
    _initGoogleSignIn();
    _initAuthState();
    _initPrefs();
  }

  /// Initialize GoogleSignIn with appropriate configuration
  void _initGoogleSignIn() {
    if (kIsWeb) {
      _googleSignIn = GoogleSignIn(
        clientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );
    } else {
      _googleSignIn = GoogleSignIn();
    }
  }
  
  /// Initialize Google Sign In
  void _initGoogleSignIn() {
    _googleSignIn = GoogleSignIn(
      clientId: kIsWeb ? dotenv.env['GOOGLE_CLIENT_ID'] : null,
    );
  }
  
  /// Initialize SharedPreferences
  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Current authenticated user
  User? get currentUser => _currentUser;
  
  /// User role (driver or passenger)
  String? get userRole => _userRole;
  
  /// Loading state
  bool get isLoading => _isLoading;
  
  /// Error message if any
  String? get error => _error;
  
  /// Success message if any
  String? get successMessage => _successMessage;
  
  /// Returns true if user is authenticated
  bool get isAuthenticated => _currentUser != null;
  
  /// Initialize and listen for auth state changes
  void _initAuthState() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Get initial session
      final session = _supabase.auth.currentSession;
      _currentUser = session?.user;
      
      if (_currentUser != null) {
        await _fetchUserRole();
      }
      
      // Listen for auth changes
      _authSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;
        
        switch (event) {
          case AuthChangeEvent.signedIn:
          case AuthChangeEvent.tokenRefreshed:
            _currentUser = session?.user;
            if (_currentUser != null) {
              await _fetchUserRole();
              await _saveSession(session!);
            }
            break;
          case AuthChangeEvent.signedOut:
          case AuthChangeEvent.userDeleted:
            _currentUser = null;
            _userRole = null;
            await _clearSession();
            break;
          default:
            break;
        }
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Save session to local storage
  Future<void> _saveSession(Session session) async {
    await _prefs.setString('session', session.accessToken);
    await _prefs.setString('refresh_token', session.refreshToken ?? '');
  }
  
  /// Clear session from local storage
  Future<void> _clearSession() async {
    await _prefs.remove('session');
    await _prefs.remove('refresh_token');
    _currentUser = null;
    _userRole = null;
    notifyListeners();
  }
  
  /// Fetch user role from profiles table
  Future<void> _fetchUserRole() async {
    if (_currentUser == null) return;
    
    try {
      final response = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', _currentUser!.id)
          .single();
      
      _userRole = response['role'] as String?;
      _error = null;
    } catch (e) {
      // If the error is because no role exists, that's okay - we'll handle it in needsRoleSelection
      _userRole = null;
      _error = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Check if user needs to select a role
  bool get needsRoleSelection => isAuthenticated && _userRole == null;
  
  /// Update user role
  Future<void> updateUserRole(String role) async {
    if (_currentUser == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      print('Updating user role to: $role for user ID: ${_currentUser!.id}');
      
      // Check internet connectivity first
      try {
        // First check if the profiles table exists and has the necessary row
        final userExists = await _supabase
            .from('profiles')
            .select('id')
            .eq('id', _currentUser!.id)
            .maybeSingle();
        
        if (userExists == null) {
          print('User profile does not exist, creating a new one');
          // Create a new profile if it doesn't exist
          await _supabase
              .from('profiles')
              .insert({
                'id': _currentUser!.id,
                'email': _currentUser!.email,
                'role': role,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              });
        } else {
          print('User profile exists, updating role');
          // Update existing profile
          await _supabase
              .from('profiles')
              .update({
                'role': role,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', _currentUser!.id);
        }
        
        _userRole = role;
        _error = null;
        print('User role updated successfully to: $role');
      } on SocketException catch (e) {
        print('Network error: $e');
        _error = 'Network error: Please check your internet connection and try again.';
      } on AuthException catch (e) {
        print('Auth error: $e');
        _error = 'Authentication error: ${e.message}';
      }
    } catch (e) {
      print('Error updating user role: $e');
      _error = 'Failed to update user role: $e';
      
      // More detailed error logging
      if (e.toString().contains('host lookup') || e.toString().contains('SocketException')) {
        _error = 'Network error: Unable to connect to the server. Please check your internet connection.';
      } else if (e.toString().contains('AuthException')) {
        _error = 'Authentication error: Your session may have expired. Please sign in again.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Sign in with email and password
  Future<void> signInWithEmail(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'An unexpected error occurred';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Start Google Sign In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Google Sign In was cancelled');
      }
      
      // Get auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Sign in to Supabase with Google credentials
      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );
      
      // Auth state change listener will handle the rest
    } catch (e) {
      _error = 'Failed to sign in with Google: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Register a new user
  Future<void> registerWithEmail(String email, String password, String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('Attempting to sign up user with email: $email');
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'created_at': DateTime.now().toIso8601String(),
        },
      );
      
      if (response.user != null) {
        print('User signed up successfully, user ID: ${response.user!.id}');
        
        try {
          // Second step: Insert into profiles table
          print('Attempting to create user profile record');
          await _supabase.from('profiles').insert({
            'id': response.user!.id,
            'email': email,
            'role': 'passenger', // Default role
            'created_at': DateTime.now().toIso8601String(),
          });
          print('User profile created successfully');
          
          // Set local user role
          _userRole = 'passenger';
        } catch (profileError) {
          print('Error creating user profile: $profileError');
          // If profile creation fails, we should log the specific error
          // but we don't need to fail the entire registration process
          // as the user is already authenticated
          _error = 'Registration successful but profile setup failed: $profileError';
          _isLoading = false;
          notifyListeners();
        }

      } else {
        print('Sign up response did not contain user object');
        _error = 'Registration failed: Please try again';
      }
    } on AuthException catch (e) {
      print('Auth Exception during registration: ${e.message}');
      _error = e.message;
    } catch (e) {
      print('Unexpected error during registration: $e');
      _error = 'An unexpected error occurred. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Reset password
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.campusride://reset-callback/',
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to send password reset email';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _supabase.auth.signOut();
      await _clearSession();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Update driver verification information
  Future<void> updateDriverInfo({
    required String driverId, 
    required String licenseNumber
  }) async {
    if (_currentUser == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      await _supabase
          .from('driver_verification')
          .upsert({
            'user_id': _currentUser!.id,
            'driver_id': driverId,
            'license_number': licenseNumber,
            'is_verified': false, // Admin needs to verify
            'created_at': DateTime.now().toIso8601String(),
          });
      
      _error = null;
    } catch (e) {
      _error = 'Failed to update driver information: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Debug: Test database access
  Future<void> testDatabaseAccess() async {
    try {
      // Print the current authentication status
      print('Current auth status:');
      print('User authenticated: ${_currentUser != null}');
      if (_currentUser != null) {
        print('User ID: ${_currentUser!.id}');
        print('User email: ${_currentUser!.email}');
      }
      
      // Try listing available tables
      try {
        print('\nTesting database function access:');
        final result = await _supabase.rpc('get_all_tables');
        print('Available tables: $result');
      } catch (e) {
        print('Error accessing get_all_tables function: $e');
      }
      
      // Try reading from profiles table
      try {
        print('\nTesting profiles table read:');
        if (_currentUser != null) {
          final data = await _supabase
              .from('profiles')
              .select('*')
              .eq('id', _currentUser!.id);
          print('User profile data: $data');
        } else {
          print('Not authenticated, skipping profile read test');
        }
      } catch (e) {
        print('Error reading profiles: $e');
      }
      
      // Try listing all buses (should be allowed for everyone)
      try {
        print('\nTesting buses table read:');
        final buses = await _supabase
            .from('buses')
            .select('*')
            .eq('is_active', true);
        print('Active buses: $buses');
      } catch (e) {
        print('Error reading buses: $e');
      }
      
      // Try inserting a test record (if authenticated)
      if (_currentUser != null) {
        try {
          print('\nTesting profiles table write:');
          print('Attempting to upsert into profiles...');
          final response = await _supabase.from('profiles').upsert({
            'id': _currentUser!.id,
            'email': _currentUser!.email,
            'role': 'passenger',
            'updated_at': DateTime.now().toIso8601String(),
          });
          print('Profile upsert success');
        } catch (e) {
          print('Profile upsert failed: $e');
        }
      }
    } catch (e) {
      print('Database test error: $e');
    }
  }
  
  /// Sign in as super admin
  Future<void> loginSuperAdmin(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        // Check if user is a super admin
        final profile = await _supabase
            .from('profiles')
            .select('role')
            .eq('id', response.user!.id)
            .single();
            
        if (profile['role'] != 'super_admin') {
          await _supabase.auth.signOut();
          throw Exception('Unauthorized: Not a super admin');
        }
        
        _currentUser = response.user;
        _userRole = 'super_admin';
      }
    } on AuthException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}