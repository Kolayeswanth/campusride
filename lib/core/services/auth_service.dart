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
    _setLoading(true);
    
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
            final newUser = session?.user;
            if (_currentUser?.id != newUser?.id) {
              _currentUser = newUser;
              if (_currentUser != null) {
                await _fetchUserRole();
                await _saveSession(session!);
              }
            }
            break;
          case AuthChangeEvent.signedOut:
          case AuthChangeEvent.userDeleted:
            if (_currentUser != null || _userRole != null) {
              _currentUser = null;
              _userRole = null;
              await _clearSession();
            }
            break;
          default:
            break;
        }
        _setLoading(false);
      });
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Set loading state only if it has changed
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Set error state only if it has changed
  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  /// Set success message only if it has changed
  void _setSuccessMessage(String? message) {
    if (_successMessage != message) {
      _successMessage = message;
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
    final userChanged = _currentUser != null;
    final roleChanged = _userRole != null;
    _currentUser = null;
    _userRole = null;
    if (userChanged || roleChanged) {
      notifyListeners();
    }
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
      final newRole = profile?['role'] as String?;
      if (_userRole != newRole) {
        _userRole = newRole;
        _setError(null);
        _setLoading(false);
      }
    } catch (e) {
      // If the error is because no role exists, that's okay - we'll handle it in needsRoleSelection
      if (_userRole != null) {
        _userRole = null;
        _setError(null);
        _setLoading(false);
      }
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
    
    _setLoading(true);
    
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
        
        // Update local state only if it changed
        if (_userRole != role) {
          _userRole = role;
        }
        _setError(null);
        print('User role updated successfully to: $role');
      } on SocketException catch (e) {
        print('Network error: $e');
        _setError('Network error: Please check your internet connection and try again.');
      } on AuthException catch (e) {
        print('Auth error: $e');
        _setError('Authentication error: ${e.message}');
      }
    } catch (e) {
      print('Error updating user role: $e');
      
      // More detailed error logging
      String errorMessage;
      if (e.toString().contains('host lookup') || e.toString().contains('SocketException')) {
        errorMessage = 'Network error: Unable to connect to the server. Please check your internet connection.';
      } else if (e.toString().contains('AuthException')) {
        errorMessage = 'Authentication error: Your session may have expired. Please sign in again.';
      } else {
        errorMessage = 'Failed to update user role: $e';
      }
      _setError(errorMessage);
    } finally {
      _setLoading(false);
    }
  }
  
  /// Sign in with email and password
  Future<void> signInWithEmail(String email, String password) async {
    _setLoading(true);
    _setError(null);
    
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      _setError(e.message);
      _setLoading(false);
    } catch (e) {
      _setError('An unexpected error occurred');
      _setLoading(false);
    }
  }
  
  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    _setLoading(true);
    _setError(null);
    
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
      _setError('Failed to sign in with Google: ${e.toString()}');
      _setLoading(false);
    }
  }
  
  /// Register a new user
  Future<void> registerWithEmail(String email, String password, String name) async {
    _setLoading(true);
    _setError(null);
    
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
          
          // Set local user role only if it changed
          if (_userRole != 'user') {
            _userRole = 'user';
          }
        } catch (profileError) {
          print('Error creating user profile: $profileError');
          // If profile creation fails, we should log the specific error
          // but we don't need to fail the entire registration process
          // as the user is already authenticated
          _setError('Registration successful but profile setup failed: $profileError');
          _setLoading(false);
          return;
        }

      } else {
        print('Sign up response did not contain user object');
        _setError('Registration failed: Please try again');
      }
    } on AuthException catch (e) {
      print('Auth Exception during registration: ${e.message}');
      _setError(e.message);
    } catch (e) {
      print('Unexpected error during registration: $e');
      _setError('An unexpected error occurred. Please try again.');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Reset password
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _setError(null);
    
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.campusride://reset-callback/',
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to send password reset email');
      _setLoading(false);
      return false;
    }
  }
  
  /// Sign out
  Future<void> signOut() async {
    _setLoading(true);
    
    try {
      await _supabase.auth.signOut();
      await _clearSession();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
  
  /// Update driver verification information
  Future<void> updateDriverInfo({
    required String driverId, 
    required String licenseNumber
  }) async {
    if (_currentUser == null) return;
    
    _setLoading(true);
    
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
      
      _setError(null);
    } catch (e) {
      _setError('Failed to update driver information: $e');
    } finally {
      _setLoading(false);
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
  
  /// Update user's college selection
  Future<void> selectCollege(String collegeId) async {
    if (_currentUser == null) {
      _setError('User not authenticated');
      return;
    }

    _setLoading(true);
    _setError(null);

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
        _setError(null);
        _setSuccessMessage('College selected successfully');
        print('College selection verified successfully');
      } else {
        throw Exception('College selection was not saved properly');
      }
    } catch (e) {
      print('Error selecting college: $e');
      _setError('Failed to select college: $e');
    } finally {
      _setLoading(false);
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

    _setLoading(true);
    _setError(null);

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

      if (_userRole != 'user') {
        _userRole = 'user';
      }
      _setError(null);
      _setSuccessMessage('Profile created successfully');
    } catch (e) {
      print('Error creating profile: $e');
      _setError('Failed to create profile: $e');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Submit driver request (simplified - only license and experience)
  Future<void> submitDriverRequest(Map<String, dynamic> requestData) async {
    if (_currentUser == null) {
      _error = 'User not authenticated';
      _setLoading(false);
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      // Get user's college ID
      final profile = await _fetchUserProfile();
      print('Current user profile for driver request: $profile');
      
      if (profile == null || profile['college_id'] == null) {
        print('Profile is null or missing college_id. Profile: $profile');
        _setError('Please select your college first before applying to become a driver. Go to your profile to update your college information.');
        _setLoading(false);
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
      _setError('Failed to submit driver request: $e');
      throw e;
    } finally {
      _setLoading(false);
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