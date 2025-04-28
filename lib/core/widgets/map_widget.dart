import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../services/map_service.dart';
import 'platform_safe_map.dart';

class MapScreen extends StatefulWidget {
  final bool showControls;
  final Function(latlong2.LatLng)? onLocationSelected;
  final bool showCurrentLocation;
  
  const MapScreen({
    Key? key, 
    this.showControls = true,
    this.onLocationSelected,
    this.showCurrentLocation = true,
  }) : super(key: key);
  
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MaplibreMapController? mapController;
  latlong2.LatLng? _selectedLocation;
  latlong2.LatLng? _currentLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestedPermission = await Geolocator.requestPermission();
        if (requestedPermission == LocationPermission.denied) {
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoading = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = latlong2.LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error getting location: $e');
    }
  }

  void _onMapCreated(dynamic controller) {
    if (controller is MaplibreMapController) {
      mapController = controller;
    }
    
    // Notify the map service about the controller
    if (mounted) {
      final mapService = Provider.of<MapService>(context, listen: false);
      mapService.onMapCreated(controller);
    }
  }
  
  void _onMapClick(latlong2.LatLng location) {
    setState(() => _selectedLocation = location);
    
    if (widget.onLocationSelected != null) {
      widget.onLocationSelected!(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return PlatformSafeMap(
      onMapCreated: _onMapCreated,
      initialCameraPosition: CameraPosition(
        target: LatLng(
          _currentLocation?.latitude ?? 37.7749,
          _currentLocation?.longitude ?? -122.4194,
        ),
        zoom: 15,
      ),
      myLocationEnabled: widget.showCurrentLocation,
      onMapClick: _onMapClick,
    );
  }
}
