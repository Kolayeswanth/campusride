# CampusRide MapLibre Integration Instructions

## Google Maps Flutter to MapLibre Migration

You were encountering errors related to Google Maps Flutter package. Here's how to properly integrate MapLibre as a drop-in replacement:

### 1. Update your pubspec.yaml dependencies:

```yaml
dependencies:
  # Remove google_maps_flutter and add these packages
  maplibre_gl: ^0.21.0
  flutter_map: ^6.1.0
  latlong2: ^0.9.1
```

### 2. Fix map_service.dart:

The key issues in your MapService were:
- Import conflict between Location and Geolocator's LocationAccuracy
- Using a final MapController that couldn't be set later
- LatLng type conversion issues

Replace lib/core/services/map_service.dart with the provided MapLibre implementation.

### 3. Update BusTrackingScreen:

Replace Google Maps implementation with:

```dart
MaplibreMap(
  initialCameraPosition: CameraPosition(
    target: currentLocation,
    zoom: 15.0,
  ),
  styleString: 'https://demotiles.maplibre.org/style.json', // Free MapLibre style
  myLocationEnabled: true,
  trackCameraPosition: true,
  onMapCreated: (controller) {
    mapService.onMapCreated(controller);
    _addBusStopsToMap();
  },
)
```

### 4. Update TripService:

Add the fetchRouteInfo method to your TripService class to handle route data fetching.

### 5. Android Configuration:

In your Android manifest, ensure you have the required permissions:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

### 6. iOS Configuration:

In your iOS Info.plist, add the following:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to location when open.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs access to location when in the background.</string>
<key>io.flutter.embedded_views_preview</key>
<true/>
```

After these changes, your app should successfully run with MapLibre maps instead of Google Maps. 