import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
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
  Future<Map<String, dynamic>?> _fetchUserProfile() async {
    if (_currentUser == null) return null;
    
    try {
      // First try to get profile with college relationship
      try {
        final response = await _supabase
            .from('profiles')
            .select('*, colleges(*)')
            .eq('id', _currentUser!.id)
            .single();
        
        return response;
      } catch (relationshipError) {
        // If the relationship doesn't exist, fall back to basic profile data
        print('College relationship not found, fetching basic profile: $relationshipError');
        final response = await _supabase
            .from('profiles')
            .select('*')
            .eq('id', _currentUser!.id)
            .single();
        
        return response;
      }
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }
  
  /// Fetch user role from profiles table
  Future<void> _fetchUserRole() async {
    if (_currentUser == null) return;
    
    try {
      final profile = await _fetchUserProfile();
      if (profile != null) {
        _userRole = profile['role'] as String?;
      }
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
  
  /// Check if user needs to select a college
  Future<bool> needsCollegeSelection() async {
    if (!isAuthenticated) return false;
    final profile = await _fetchUserProfile();
    return profile != null && profile['college_id'] == null;
  }
  
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
          
          // First, get the first available college ID
          String? defaultCollegeId;
          try {
            final collegesResponse = await _supabase
                .from('colleges')
                .select('id')
                .limit(1);
            
            if (collegesResponse.isNotEmpty) {
              defaultCollegeId = collegesResponse[0]['id'].toString();
              print('Using default college ID: $defaultCollegeId');
            } else {
              print('No colleges found, profile will be created without college_id');
            }
          } catch (collegeError) {
            print('Error fetching colleges: $collegeError');
          }
          
          final profileData = {
            'id': response.user!.id,
            'email': email,
            'display_name': name,
            'role': 'user', // Default role changed to 'user'
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };
          
          // Only add college_id if we have one
          if (defaultCollegeId != null) {
            profileData['college_id'] = defaultCollegeId;
          }
          
          await _supabase.from('profiles').insert(profileData);
          print('User profile created successfully');
          
          // Set local user role
          _userRole = 'user';
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
          await _supabase.from('profiles').upsert({
            'id': _currentUser!.id,
            'email': _currentUser!.email,
            'role': 'user',
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
  
  /// Sign in with email and password for a specific role
  Future<void> signInWithEmailAndRole(String email, String password, String role) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('Attempting login for: $email as $role');
      
      // First, check network connectivity by attempting a simple request
      try {
        await _supabase.from('profiles').select('count').limit(1);
        print('Network connectivity check passed');
      } catch (e) {
        if (e.toString().contains('host lookup') || e.toString().contains('SocketException')) {
          throw Exception('Network error: Unable to connect to the server. Please check your internet connection and try again.');
        }
        print('Network check failed with: $e');
      }
      
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        print('Authentication successful, setting up user profile...');
        
        // Try to get existing profile
        try {
          final profile = await _supabase
              .from('profiles')
              .select('role')
              .eq('id', response.user!.id)
              .maybeSingle();
              
          if (profile != null) {
            // User has existing profile, use their role
            _userRole = profile['role'] as String;
            print('Existing user role: $_userRole');
          } else {
            // New user, create profile with specified role
            await _supabase.from('profiles').insert({
              'id': response.user!.id,
              'email': email,
              'role': role,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
            _userRole = role;
            print('Created new user profile with role: $role');
          }
          
          _currentUser = response.user;
          print('Login successful for $_userRole');
        } catch (e) {
          await _supabase.auth.signOut();
          if (e.toString().contains('single')) {
            throw Exception('Profile setup failed: Please contact the administrator.');
          }
          rethrow;
        }
      } else {
        throw Exception('Login failed: Invalid credentials.');
      }
    } on SocketException catch (e) {
      print('Network error during login: $e');
      _error = 'Network error: Please check your internet connection and try again.';
    } on AuthException catch (e) {
      print('Auth error during login: ${e.message}');
      _error = e.message;
    } catch (e) {
      print('Error during login: $e');
      _error = e.toString();
      
      // Provide more user-friendly error messages
      if (e.toString().contains('host lookup') || e.toString().contains('SocketException')) {
        _error = 'Network error: Unable to connect to the server. Please check your internet connection.';
      } else if (e.toString().contains('Invalid login credentials')) {
        _error = 'Invalid email or password. Please check your credentials and try again.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Update user's college selection
  Future<void> selectCollege(String collegeId) async {
    if (_currentUser == null) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('Selecting college with ID: $collegeId for user: ${_currentUser!.id}');
      
      final updateResult = await _supabase
          .from('profiles')
          .update({
            'college_id': collegeId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _currentUser!.id);

      print('College update result: $updateResult');
      
      // Verify the update worked by fetching the profile
      final updatedProfile = await _fetchUserProfile();
      print('Updated profile after college selection: $updatedProfile');
      
      if (updatedProfile != null && updatedProfile['college_id'] == collegeId) {
        _error = null;
        _successMessage = 'College selected successfully';
        print('College selection verified successfully');
      } else {
        throw Exception('College selection was not saved properly');
      }
    } catch (e) {
      print('Error selecting college: $e');
      _error = 'Failed to select college: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create initial profile for new user
  Future<void> createProfile({
    required String displayName,
    required String collegeId,
    String? phone,
    String? photoUrl,
  }) async {
    if (_currentUser == null) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabase.from('profiles').insert({
        'id': _currentUser!.id,
        'email': _currentUser!.email!,
        'display_name': displayName,
        'college_id': collegeId,
        'photo_url': photoUrl,
        'role': 'user',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      _userRole = 'user';
      _error = null;
      _successMessage = 'Profile created successfully';
    } catch (e) {
      print('Error creating profile: $e');
      _error = 'Failed to create profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submit driver request (simplified - only license and experience)
  Future<void> submitDriverRequest(Map<String, dynamic> requestData) async {
    if (_currentUser == null) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get user's college ID
      final profile = await _fetchUserProfile();
      print('Current user profile for driver request: $profile');
      
      if (profile == null || profile['college_id'] == null) {
        print('Profile is null or missing college_id. Profile: $profile');
        _error = 'Please select your college first before applying to become a driver. Go to your profile to update your college information.';
        notifyListeners();
        return;
      }

      print('Submitting simplified driver request with college_id: ${profile['college_id']}');

      await _supabase.from('driver_requests').insert({
        'user_id': _currentUser!.id,
        'college_id': profile['college_id'],
        'license_number': requestData['license_number'],
        'driving_experience_years': requestData['driving_experience_years'],
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      _error = null;
      _successMessage = 'Driver request submitted successfully. You will be notified once approved.';
    } catch (e) {
      print('Error submitting driver request: $e');
      _error = 'Failed to submit driver request: $e';
      throw e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if user has pending driver request
  Future<bool> hasPendingDriverRequest() async {
    if (_currentUser == null) return false;

    try {
      final response = await _supabase
          .from('driver_requests')
          .select('id')
          .eq('user_id', _currentUser!.id)
          .eq('status', 'pending')
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking driver request: $e');
      return false;
    }
  }

  /// Get user's driver request status
  Future<String?> getDriverRequestStatus() async {
    if (_currentUser == null) return null;

    try {
      final response = await _supabase
          .from('driver_requests')
          .select('status')
          .eq('user_id', _currentUser!.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response?['status'] as String?;
    } catch (e) {
      print('Error getting driver request status: $e');
      return null;
    }
  }

  /// Get all driver requests (admin only)
  Future<List<Map<String, dynamic>>> getAllDriverRequests() async {
    if (_currentUser == null || (_userRole != 'admin' && _userRole != 'super_admin')) {
      throw Exception('Unauthorized access');
    }

    try {
      // Get driver requests
      final requestsResponse = await _supabase
          .from('driver_requests')
          .select('*')
          .order('created_at', ascending: false);

      final requests = List<Map<String, dynamic>>.from(requestsResponse);
      
      // For each request, fetch the associated profile and college data
      for (final request in requests) {
        // Fetch user profile
        try {
          final profileResponse = await _supabase
              .from('profiles')
              .select('id, email, display_name')
              .eq('id', request['user_id'])
              .single();
          request['profiles'] = profileResponse;
        } catch (e) {
          print('Could not fetch profile for user ${request['user_id']}: $e');
          request['profiles'] = null;
        }
        
        // Fetch college if college_id exists
        if (request['college_id'] != null) {
          try {
            final collegeResponse = await _supabase
                .from('colleges')
                .select('id, name')
                .eq('id', request['college_id'])
                .single();
            request['colleges'] = collegeResponse;
          } catch (e) {
            print('Could not fetch college for id ${request['college_id']}: $e');
            request['colleges'] = null;
          }
        } else {
          request['colleges'] = null;
        }
      }

      return requests;
    } catch (e) {
      print('Error fetching driver requests: $e');
      throw Exception('Failed to fetch driver requests: $e');
    }
  }

  /// Handle driver request approval/rejection (admin only)
  Future<void> handleDriverRequest(String requestId, String action) async {
    if (_currentUser == null || (_userRole != 'admin' && _userRole != 'super_admin')) {
      throw Exception('Unauthorized access');
    }

    if (action != 'approved' && action != 'rejected') {
      throw Exception('Invalid action. Must be "approved" or "rejected"');
    }

    try {
      // Update the driver request status
      await _supabase
          .from('driver_requests')
          .update({
            'status': action,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      // If approved, update the user's role to driver
      if (action == 'approved') {
        final request = await _supabase
            .from('driver_requests')
            .select('user_id')
            .eq('id', requestId)
            .single();

        await _supabase
            .from('profiles')
            .update({
              'role': 'driver',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', request['user_id']);
      }
    } catch (e) {
      print('Error handling driver request: $e');
      throw Exception('Failed to ${action.replaceAll('ed', '')} driver request: $e');
    }
  }

  /// Fetch drivers by college (admin only)
  Future<List<Map<String, dynamic>>> getDriversByCollege(String collegeId) async {
    if (_currentUser == null || (_userRole != 'admin' && _userRole != 'super_admin')) {
      throw Exception('Unauthorized access');
    }

    try {
      print('Fetching drivers for college: $collegeId');
      
      final driversResponse = await _supabase
          .from('drivers')
          .select('*')
          .eq('college_id', collegeId)
          .order('approved_at', ascending: false);

      final drivers = List<Map<String, dynamic>>.from(driversResponse);
      
      // For each driver, fetch the associated profile data
      for (final driver in drivers) {
        try {
          final profileResponse = await _supabase
              .from('user_profiles')
              .select('id, email, name')
              .eq('id', driver['user_id'])
              .single();
          driver['profiles'] = profileResponse;
        } catch (e) {
          print('Could not fetch profile for driver ${driver['user_id']}: $e');
          driver['profiles'] = null;
        }
      }

      return drivers;
    } catch (e) {
      print('Error fetching drivers: $e');
      throw Exception('Failed to fetch drivers: $e');
    }
  }

  /// Get all drivers (admin only)
  Future<List<Map<String, dynamic>>> getAllDrivers() async {
    if (_currentUser == null || (_userRole != 'admin' && _userRole != 'super_admin')) {
      throw Exception('Unauthorized access');
    }

    try {
      print('Fetching all drivers');
      
      final driversResponse = await _supabase
          .from('drivers')
          .select('*')
          .order('approved_at', ascending: false);

      final drivers = List<Map<String, dynamic>>.from(driversResponse);
      
      // For each driver, fetch the associated profile and college data
      for (final driver in drivers) {
        // Fetch user profile
        try {
          final profileResponse = await _supabase
              .from('user_profiles')
              .select('id, email, name')
              .eq('id', driver['user_id'])
              .single();
          driver['profiles'] = profileResponse;
        } catch (e) {
          print('Could not fetch profile for driver ${driver['user_id']}: $e');
          driver['profiles'] = null;
        }
        
        // Fetch college
        try {
          final collegeResponse = await _supabase
              .from('colleges')
              .select('id, name, code')
              .eq('id', driver['college_id'])
              .single();
          driver['colleges'] = collegeResponse;
        } catch (e) {
          print('Could not fetch college for driver ${driver['user_id']}: $e');
          driver['colleges'] = null;
        }
      }

      return drivers;
    } catch (e) {
      print('Error fetching all drivers: $e');
      throw Exception('Failed to fetch all drivers: $e');
    }
  }

  /// Update driver status (admin only)
  Future<void> updateDriverStatus(String driverId, bool isActive) async {
    if (_currentUser == null || (_userRole != 'admin' && _userRole != 'super_admin')) {
      throw Exception('Unauthorized access');
    }

    try {
      await _supabase
          .from('drivers')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId);
      
      print('Driver status updated successfully');
    } catch (e) {
      print('Error updating driver status: $e');
      throw Exception('Failed to update driver status: $e');
    }
  }

  // Keep the old method signature for backward compatibility
  Future<void> submitDriverRequestOld({
    required String licenseNumber,
    required String vehicleModel,
    required String vehicleNumber,
    String? requestMessage,
  }) async {
    return submitDriverRequest({
      'license_number': licenseNumber,
      'vehicle_make': '',
      'vehicle_model': vehicleModel,
      'vehicle_year': DateTime.now().year,
      'vehicle_plate_number': vehicleNumber,
      'driving_experience_years': 1,
      'reason': requestMessage ?? '',
    });
  }
  
  /// Check if user has selected a college, if not prompt for selection
  Future<bool> ensureCollegeSelected() async {
    if (_currentUser == null) return false;
    
    final profile = await _fetchUserProfile();
    if (profile != null && profile['college_id'] != null) {
      return true; // College already selected
    }
    
    // College not selected, return false to prompt user
    return false;
  }

  /// Get current user's profile data
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    return await _fetchUserProfile();
  }

  /// Get available colleges for selection
  Future<List<Map<String, dynamic>>> getAvailableColleges() async {
    try {
      final response = await _supabase
          .from('colleges')
          .select('id, name, code')
          .order('name');
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching colleges: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}