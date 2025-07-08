import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/offline_service.dart';
import '../../../core/services/maptiler_service.dart';

class OfflineSettingsScreen extends StatefulWidget {
  const OfflineSettingsScreen({Key? key}) : super(key: key);

  @override
  _OfflineSettingsScreenState createState() => _OfflineSettingsScreenState();
}

class _OfflineSettingsScreenState extends State<OfflineSettingsScreen> {
  final OfflineService _offlineService = OfflineService();
  final MapTilerService _mapService = MapTilerService();
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';
  bool _isApiKeyValid = false;

  @override
  void initState() {
    super.initState();
    _validateMapBoxApiKey();
  }

  Future<void> _validateMapBoxApiKey() async {
    final isValid = await _mapService.validateApiKey();
    setState(() {
      _isApiKeyValid = isValid;
    });
    if (!isValid) {
      _showError('Invalid MapTiler API key. Please check your configuration.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _downloadOfflineMap() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'Preparing download...';
    });

    try {
      // Define the campus area bounds
      final campusBounds = [
        const LatLng(33.7749, -84.3963), // Southwest corner
        const LatLng(33.7763, -84.3949), // Northeast corner
      ];

      if (!_isApiKeyValid) {
        throw Exception('MapTiler API key is not valid. Please configure it first.');
      }

      // Calculate center point for the campus area
      final center = LatLng(
        (campusBounds[0].latitude + campusBounds[1].latitude) / 2,
        (campusBounds[0].longitude + campusBounds[1].longitude) / 2,
      );

      // Get static map for the region
      final staticMapUrl = _mapService.getStaticMapUrl(
        center: center,
        zoom: 15,
        width: 1280, // Higher resolution for offline use
        height: 1280,
      );

      await _offlineService.saveOfflineMapRegion(
        regionId: 'campus_area',
        bounds: campusBounds,
        mapStyle: staticMapUrl,
      );

      setState(() {
        _downloadProgress = 1.0;
        _downloadStatus = 'Download completed!';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline map downloaded successfully')),
      );
    } catch (e) {
      setState(() {
        _downloadStatus = 'Error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading offline map: $e')),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _clearOfflineData() async {
    try {
      await _offlineService.clearOfflineData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline data cleared successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing offline data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Offline Map',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Download the campus area map for offline use',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    if (_isDownloading)
                      Column(
                        children: [
                          LinearProgressIndicator(value: _downloadProgress),
                          const SizedBox(height: 8),
                          Text(_downloadStatus),
                        ],
                      )
                    else
                      ElevatedButton(
                        onPressed: _downloadOfflineMap,
                        child: const Text('Download Offline Map'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Emergency Contacts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Emergency contacts will be available offline',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implement emergency contacts management
                      },
                      child: const Text('Manage Emergency Contacts'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cached Routes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Routes will be cached for offline navigation',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implement route caching management
                      },
                      child: const Text('Manage Cached Routes'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearOfflineData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear All Offline Data'),
            ),
          ],
        ),
      ),
    );
  }
}
