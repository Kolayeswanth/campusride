import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bus_info.dart';
import '../../../core/utils/logger_util.dart';

class BusService {
  final _supabase = Supabase.instance.client;
  final String _table = 'buses';

  Stream<List<BusInfo>> getActiveBuses() {
    return _supabase
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .map((data) {
          return data.map((item) => BusInfo.fromJson(item)).toList();
        });
  }

  Future<BusInfo?> getBusById(String busId) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('id', busId)
          .single();
      
      return BusInfo.fromJson(response);
    } catch (e) {
      LoggerUtil.error('Error getting bus', e);
      return null;
    }
  }
  
  // Add a method to get bus locations for a specific route
  Future<List<BusInfo>> getBusesByRoute(String routeNumber) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('route_number', routeNumber)
          .eq('is_active', true);
      
      return response.map<BusInfo>((item) => BusInfo.fromJson(item)).toList();
    } catch (e) {
      LoggerUtil.error('Error getting buses by route', e);
      return [];
    }
  }
} 