import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as latlong2;

class SearchBars extends StatelessWidget {
  final TextEditingController startLocationController;
  final TextEditingController destinationController;
  final List<Map<String, dynamic>> searchResults;
  final List<Map<String, dynamic>> startLocationResults;
  final bool isSearching;
  final bool isSearchingStartLocation;
  final Function(String) onStartLocationSearch;
  final Function(String) onDestinationSearch;
  final Function(latlong2.LatLng) onDestinationSelected;
  final Function() onUseCurrentLocation;
  final Function() onClearStartLocation;
  final Function() onClearDestination;

  const SearchBars({
    Key? key,
    required this.startLocationController,
    required this.destinationController,
    required this.searchResults,
    required this.startLocationResults,
    required this.isSearching,
    required this.isSearchingStartLocation,
    required this.onStartLocationSearch,
    required this.onDestinationSearch,
    required this.onDestinationSelected,
    required this.onUseCurrentLocation,
    required this.onClearStartLocation,
    required this.onClearDestination,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStartLocationField(context),
          _buildDestinationField(),
          if (searchResults.isNotEmpty) _buildSearchResults(),
        ],
      ),
    );
  }

  Widget _buildStartLocationField(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: startLocationController,
              decoration: InputDecoration(
                hintText: 'Enter starting point or choose current location',
                border: InputBorder.none,
                suffixIcon: startLocationController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: onClearStartLocation,
                    )
                  : null,
              ),
              onChanged: onStartLocationSearch,
              onTap: () => _showStartLocationOptions(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: destinationController,
              decoration: InputDecoration(
                hintText: 'Enter destination',
                border: InputBorder.none,
                suffixIcon: destinationController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: onClearDestination,
                    )
                  : null,
              ),
              onChanged: onDestinationSearch,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          final result = searchResults[index];
          return ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text(result['name']),
            subtitle: Text(
              result['full_address'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              destinationController.text = result['name'];
              onDestinationSelected(latlong2.LatLng(
                result['latitude'],
                result['longitude'],
              ));
            },
          );
        },
      ),
    );
  }

  void _showStartLocationOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location, color: Colors.blue),
              title: const Text('Use Current Location'),
              onTap: () {
                Navigator.pop(context);
                onUseCurrentLocation();
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Or search for a location:', 
                style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: startLocationResults.length,
                itemBuilder: (context, index) {
                  final result = startLocationResults[index];
                  return ListTile(
                    leading: const Icon(Icons.location_city),
                    title: Text(result['name']),
                    subtitle: Text(
                      result['full_address'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      startLocationController.text = result['name'];
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