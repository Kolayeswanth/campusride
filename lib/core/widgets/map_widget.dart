import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/map_service.dart';

class MapWidget extends StatelessWidget {
  final LatLng? initialPosition;
  final double initialZoom;
  final bool showUserLocation;
  final bool enableInteraction;
  final Function(MapController)? onMapCreated;
  final Function(TapPosition, LatLng)? onTap;
  final Function(LatLng)? onLongPress;
  final Widget? topWidgets;
  final Widget? bottomWidgets;
  final Widget? floatingActionButton;
  final bool showZoomControls;
  final bool showAttributionButton;
  
  const MapWidget({
    super.key,
    this.initialPosition,
    this.initialZoom = 15.0,
    this.showUserLocation = true,
    this.enableInteraction = true,
    this.onMapCreated,
    this.onTap,
    this.onLongPress,
    this.topWidgets,
    this.bottomWidgets,
    this.floatingActionButton,
    this.showZoomControls = true,
    this.showAttributionButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final mapService = Provider.of<MapService>(context);
    final theme = Theme.of(context);
    
    // Use the map service's initial position if our initialPosition is null
    final position = initialPosition ?? mapService.initialPosition;
    
    return Stack(
      children: [
        FlutterMap(
          mapController: mapService.mapController,
          options: MapOptions(
            initialCenter: position,
            initialZoom: initialZoom,
            interactionOptions: InteractionOptions(
              flags: enableInteraction ? InteractiveFlag.all : InteractiveFlag.none,
            ),
            onTap: onTap,
            onLongPress: (position, point) {
              if (onLongPress != null) {
                onLongPress!(point);
              }
            },
            onMapReady: () {
              if (onMapCreated != null && mapService.mapController != null) {
                onMapCreated!(mapService.mapController!);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: mapService.getMapTileUrl(
                darkMode: theme.brightness == Brightness.dark,
              ),
              userAgentPackageName: 'com.campusride.app',
              tileBuilder: (context, tileWidget, tile) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.1),
                  ),
                  position: DecorationPosition.foreground,
                  child: tileWidget,
                );
              },
              backgroundColor: theme.colorScheme.surface.withOpacity(0.2),
            ),
            // Polylines for routes
            PolylineLayer(
              polylines: mapService.routes,
            ),
            // Markers
            MarkerLayer(
              markers: mapService.markers,
            ),
            // Add attribution
            if (showAttributionButton)
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () {},
                  ),
                ],
              ),
          ],
        ),
        
        // Add top widgets if provided
        if (topWidgets != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: topWidgets!,
          ),
        
        // Add bottom widgets if provided
        if (bottomWidgets != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: bottomWidgets!,
          ),
        
        // Add zoom controls if enabled
        if (showZoomControls)
          Positioned(
            right: 16,
            bottom: bottomWidgets != null ? 96 : 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoomIn',
                  onPressed: () {
                    final controller = mapService.mapController;
                    if (controller != null) {
                      final zoom = controller.camera.zoom + 1;
                      controller.move(controller.camera.center, zoom);
                    }
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoomOut',
                  onPressed: () {
                    final controller = mapService.mapController;
                    if (controller != null) {
                      final zoom = controller.camera.zoom - 1;
                      controller.move(controller.camera.center, zoom);
                    }
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        
        // Add floating action button if provided
        if (floatingActionButton != null)
          Positioned(
            right: 16,
            bottom: 16,
            child: floatingActionButton!,
          ),
      ],
    );
  }
} 