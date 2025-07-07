import 'package:flutter/material.dart';
import '../models/college.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuperAdminService extends ChangeNotifier {
  List<College> _colleges = [];
  bool _isLoading = false;
  String? _error;
  final _supabase = Supabase.instance.client;

  List<College> get colleges => _colleges;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadColleges() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _supabase
          .from('colleges')
          .select()
          .order('created_at', ascending: false);

      _colleges = (response as List)
          .map((college) => College(
                id: college['id'],
                name: college['name'],
                location: college['location'],
                code: college['code'],
                createdAt: DateTime.parse(college['created_at']),
              ))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load colleges';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCollege({
    required String name,
    required double latitude,
    required double longitude,
    required String code,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Construct the PostGIS POINT string
      final locationPoint = 'POINT($longitude $latitude)';

      final response = await _supabase.from('colleges').insert({
        'name': name,
        'location': locationPoint,
        'code': code,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();
      
      final newCollege = College(
        id: response['id'],
        name: name,
        location: response['location'],
        code: code,
        createdAt: DateTime.now(),
      );

      _colleges.add(newCollege);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to add college: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateCollege(College college) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabase.from('colleges').update({
        'name': college.name,
        'location': college.location,
        'code': college.code,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', college.id);
      
      final index = _colleges.indexWhere((c) => c.id == college.id);
      if (index != -1) {
        _colleges[index] = college;
        notifyListeners();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update college';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteCollege(String collegeId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabase.from('colleges').delete().eq('id', collegeId);
      
      _colleges.removeWhere((c) => c.id == collegeId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete college';
      _isLoading = false;
      notifyListeners();
    }
  }
} 