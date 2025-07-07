import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/college.dart';
import 'package:campusride/core/utils/logger_util.dart';

class CollegeService extends ChangeNotifier {
  final List<College> _colleges = [];
  bool _isLoading = false;
  String? _error;
  final _supabase = Supabase.instance.client;

  List<College> get colleges => List.unmodifiable(_colleges);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadColleges() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('colleges')
          .select()
          .order('created_at', ascending: false);

      _colleges.clear();
      _colleges.addAll(
        (response as List).map((json) => College.fromJson(json)).toList(),
      );
    } catch (e) {
      _error = 'Failed to load colleges: $e';
      LoggerUtil.error('Failed to load colleges', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCollege(Map<String, dynamic> collegeData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('colleges')
          .insert(collegeData)
          .select()
          .single();

      final newCollege = College.fromJson(response);
      _colleges.insert(0, newCollege);
    } catch (e) {
      _error = 'Failed to add college: $e';
      LoggerUtil.error('Failed to add college', e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateCollege(College college) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('colleges')
          .update(college.toJson())
          .eq('id', college.id)
          .select()
          .single();

      final updatedCollege = College.fromJson(response);
      final index = _colleges.indexWhere((c) => c.id == college.id);
      if (index != -1) {
        _colleges[index] = updatedCollege;
      }
    } catch (e) {
      _error = 'Failed to update college: $e';
      LoggerUtil.error('Failed to update college', e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteCollege(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabase.from('colleges').delete().eq('id', id);
      _colleges.removeWhere((c) => c.id == id);
    } catch (e) {
      _error = 'Failed to delete college: $e';
      LoggerUtil.error('Failed to delete college', e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleCollegeStatus(String id, bool isActive) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('colleges')
          .update({'is_active': isActive})
          .eq('id', id)
          .select()
          .single();

      final updatedCollege = College.fromJson(response);
      final index = _colleges.indexWhere((c) => c.id == id);
      if (index != -1) {
        _colleges[index] = updatedCollege;
      }
    } catch (e) {
      _error = 'Failed to toggle college status: $e';
      LoggerUtil.error('Failed to toggle college status', e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> uploadLogo(String collegeId, Uint8List imageBytes) async {
    try {
      final fileName = 'collegelogos_$collegeId.jpg';
      final response = await _supabase.storage
          .from('collegelogos')
          .uploadBinary(fileName, imageBytes);

      return _supabase.storage.from('collegelogos').getPublicUrl(fileName);
    } catch (e) {
      LoggerUtil.error('Failed to upload college logos', e);
      rethrow;
    }
  }
} 