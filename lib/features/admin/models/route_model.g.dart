// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RouteModelImpl _$$RouteModelImplFromJson(Map<String, dynamic> json) =>
    _$RouteModelImpl(
      name: json['name'] as String,
      startLocation: json['startLocation'] as String,
      endLocation: json['endLocation'] as String,
      isActive: json['isActive'] as bool,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      id: json['id'] as String?,
      collegeId: json['collegeId'] as String?,
      driverId: json['driverId'] as String?,
      startCoordinates: json['startCoordinates'] == null
          ? null
          : LatLng.fromJson(json['startCoordinates'] as Map<String, dynamic>),
      endCoordinates: json['endCoordinates'] == null
          ? null
          : LatLng.fromJson(json['endCoordinates'] as Map<String, dynamic>),
      routePolyline: json['routePolyline'] as String?,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$RouteModelImplToJson(_$RouteModelImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'startLocation': instance.startLocation,
      'endLocation': instance.endLocation,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt?.toIso8601String(),
      'id': instance.id,
      'collegeId': instance.collegeId,
      'driverId': instance.driverId,
      'startCoordinates': instance.startCoordinates,
      'endCoordinates': instance.endCoordinates,
      'routePolyline': instance.routePolyline,
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
