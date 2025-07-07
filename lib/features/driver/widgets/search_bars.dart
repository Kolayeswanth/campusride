import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../controllers/search_controller.dart';

class SearchBars extends StatelessWidget {
  final TextEditingController startLocationController;
  final TextEditingController destinationController;
  final Function(String) onStartLocationChanged;
  final Function() onStartLocationClear;
  final Function(String) onDestinationChanged;
  final Function() onDestinationClear;
  final Function(LatLng) onDestinationSelected;
  final Function() onUseCurrentLocation;
  final List<Map<String, dynamic>> startLocationResults;
  final List<Map<String, dynamic>> searchResults;
  final LocationSearchController searchController;

  const SearchBars({
    Key? key,
    required this.startLocationController,
    required this.destinationController,
    required this.onStartLocationChanged,
    required this.onStartLocationClear,
    required this.onDestinationChanged,
    required this.onDestinationClear,
    required this.onDestinationSelected,
    required this.onUseCurrentLocation,
    required this.startLocationResults,
    required this.searchResults,
    required this.searchController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Start location field
            TextField(
              controller: startLocationController,
              decoration: InputDecoration(
                hintText: 'Start Location',
                prefixIcon: const Icon(Icons.location_on_outlined),
                suffixIcon: startLocationController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: onStartLocationClear,
                      )
                    : IconButton(
                        icon: const Icon(Icons.my_location),
                        onPressed: onUseCurrentLocation,
                      ),
                border: const OutlineInputBorder(),
              ),
              onChanged: onStartLocationChanged,
            ),
            const SizedBox(height: 8),
            
            // Destination field
            TextField(
              controller: destinationController,
              decoration: InputDecoration(
                hintText: 'Destination',
                prefixIcon: const Icon(Icons.location_on),
                suffixIcon: destinationController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: onDestinationClear,
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: onDestinationChanged,
            ),
            
            // Search results
            if (searchResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final result = searchResults[index];
                    return ListTile(
                      title: Text(result['name']),
                      subtitle: Text(result['full_address']),
                      onTap: () {
                        destinationController.text = result['name'];
                        onDestinationSelected(LatLng(
                          result['latitude'],
                          result['longitude'],
                        ));
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}