import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  final String _openRouteApiKey = '5b3ce3597851110001cf6248a0ac0e4cb1ac489fa0857d1c6fc7203e'; // Replace with your actual API key

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchPlaces(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.openrouteservice.org/geocode/search?api_key=$_openRouteApiKey&text=$query&boundary.country=IND',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        
        
        
        setState(() {
          _searchResults = features.map((feature) {
            final properties = feature['properties'];
            final geometry = feature['geometry'];
            return {
              'name': properties['name'] ?? properties['label'] ?? 'Unknown Location',
              'address': properties['label'] ?? properties['name'] ?? 'No address available',
              'latitude': geometry['coordinates'][1],
              'longitude': geometry['coordinates'][0],
              'type': properties['layer'] ?? 'unknown',
              'region': properties['region'] ?? '',
              'state': properties['region_a'] ?? '',
            };
          }).toList();
        });
      } else {
        
        
        setState(() {
          _searchResults = [];
        });
      }
    } catch (e) {
      
      setState(() {
        _searchResults = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search places...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return ListTile(
                  title: Text(result['name']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result['address']),
                      if (result['type'] != 'unknown')
                        Text('Type: ${result['type']}'),
                      if (result['region'].isNotEmpty)
                        Text('Region: ${result['region']}'),
                    ],
                  ),
                  onTap: () {
                    // Handle location selection
                    
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 
