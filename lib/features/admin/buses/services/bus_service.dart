import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../models/bus.dart';
import '../../../core/utils/logger_util.dart';

class BusService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<Bus> _buses = [];
  bool _isLoading = false;
  String? _error;

  List<Bus> get buses => _buses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadBuses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('buses')
          .select()
          .order('created_at', ascending: false);

      _buses = (response as List)
          .map((json) => Bus.fromJson(json as Map<String, dynamic>))
          .toList();
      _error = null;
    } catch (e) {
      _error = 'Failed to load buses: $e';
      LoggerUtil.error('Failed to load buses', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addBus(Bus bus) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase.from('buses').insert(bus.toJson()).select();
      final newBus = Bus.fromJson(response[0] as Map<String, dynamic>);
      _buses.insert(0, newBus);
      _error = null;
    } catch (e) {
      _error = 'Failed to add bus: $e';
      LoggerUtil.error('Failed to add bus', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateBus(Bus bus) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('buses')
          .update(bus.toJson())
          .eq('id', bus.id)
          .select();
      final updatedBus = Bus.fromJson(response[0] as Map<String, dynamic>);
      final index = _buses.indexWhere((b) => b.id == bus.id);
      if (index != -1) {
        _buses[index] = updatedBus;
      }
      _error = null;
    } catch (e) {
      _error = 'Failed to update bus: $e';
      LoggerUtil.error('Failed to update bus', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteBus(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabase.from('buses').delete().eq('id', id);
      _buses.removeWhere((bus) => bus.id == id);
      _error = null;
    } catch (e) {
      _error = 'Failed to delete bus: $e';
      LoggerUtil.error('Failed to delete bus', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleBusStatus(String id, bool isActive) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('buses')
          .update({'is_active': isActive})
          .eq('id', id)
          .select();
      final updatedBus = Bus.fromJson(response[0] as Map<String, dynamic>);
      final index = _buses.indexWhere((b) => b.id == id);
      if (index != -1) {
        _buses[index] = updatedBus;
      }
      _error = null;
    } catch (e) {
      _error = 'Failed to toggle bus status: $e';
      LoggerUtil.error('Failed to toggle bus status', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> assignRoute(String busId, String routeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('buses')
          .update({'route_id': routeId})
          .eq('id', busId)
          .select();
      final updatedBus = Bus.fromJson(response[0] as Map<String, dynamic>);
      final index = _buses.indexWhere((b) => b.id == busId);
      if (index != -1) {
        _buses[index] = updatedBus;
      }
      _error = null;
    } catch (e) {
      _error = 'Failed to assign route: $e';
      LoggerUtil.error('Failed to assign route', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> assignDriver(String busId, String driverId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('buses')
          .update({'driver_id': driverId})
          .eq('id', busId)
          .select();
      final updatedBus = Bus.fromJson(response[0] as Map<String, dynamic>);
      final index = _buses.indexWhere((b) => b.id == busId);
      if (index != -1) {
        _buses[index] = updatedBus;
      }
      _error = null;
    } catch (e) {
      _error = 'Failed to assign driver: $e';
      LoggerUtil.error('Failed to assign driver', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> uploadBusPhoto(String busId, Uint8List imageBytes) async {
    try {
      final filePath = 'bus_photos/$busId.jpg';
      await _supabase.storage.from('buses').uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return _supabase.storage.from('buses').getPublicUrl(filePath);
    } catch (e) {
      LoggerUtil.error('Failed to upload bus photo', e);
      return null;
    }
  }

  List<Bus> getBusesForCollege(String collegeId) {
    return _buses.where((bus) => bus.collegeId == collegeId).toList();
  }

  Bus? getBusById(String id) {
    try {
      return _buses.firstWhere((bus) => bus.id == id);
    } catch (e) {
      return null;
    }
  }
} 