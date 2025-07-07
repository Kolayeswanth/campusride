import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';

final routeServiceProvider = Provider<RouteService>((ref) {
  throw UnimplementedError('RouteService must be initialized');
});

final routesProvider = StateNotifierProvider<RoutesNotifier, AsyncValue<List<RouteModel>>>((ref) {
  final routeService = ref.watch(routeServiceProvider);
  return RoutesNotifier(routeService);
});

class RoutesNotifier extends StateNotifier<AsyncValue<List<RouteModel>>> {
  final RouteService _routeService;

  RoutesNotifier(this._routeService) : super(const AsyncValue.loading()) {
    loadRoutes();
  }

  Future<void> loadRoutes() async {
    try {
      state = const AsyncValue.loading();
      final routes = await _routeService.getRoutesByCollege('');
      state = AsyncValue.data(routes);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createRoute(RouteModel route) async {
    try {
      state = const AsyncValue.loading();
      final newRoute = await _routeService.createRoute(route);
      state.whenData((routes) {
        state = AsyncValue.data([...routes, newRoute]);
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateRoute(RouteModel route) async {
    try {
      state = const AsyncValue.loading();
      await _routeService.updateRoute(route);
      state.whenData((routes) {
        final updatedRoutes = routes.map((r) => r.id == route.id ? route : r).toList();
        state = AsyncValue.data(updatedRoutes);
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteRoute(String routeId) async {
    try {
      state = const AsyncValue.loading();
      await _routeService.deleteRoute(routeId);
      state.whenData((routes) {
        final updatedRoutes = routes.where((r) => r.id != routeId).toList();
        state = AsyncValue.data(updatedRoutes);
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
} 