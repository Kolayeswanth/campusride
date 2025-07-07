import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';

part 'route_model.freezed.dart';
part 'route_model.g.dart';

@freezed
class RouteModel with _$RouteModel {
  const factory RouteModel({
    required String name,
    required String startLocation,
    required String endLocation,
    required bool isActive,
    DateTime? createdAt,
    String? id,
    String? collegeId,
    String? driverId,
    LatLng? startCoordinates,
    LatLng? endCoordinates,
    String? routePolyline,
    DateTime? updatedAt,
  }) = _RouteModel;

  factory RouteModel.fromJson(Map<String, dynamic> json) =>
      _$RouteModelFromJson(json);
}

// Note: This file is using the 'freezed' package. You may need to run `flutter pub run build_runner build` to regenerate the part files after this edit. 