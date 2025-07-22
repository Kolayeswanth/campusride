import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/ola_maps_service.dart';
import '../../../core/theme/theme.dart';

class LocationSearchField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final Function(String locationName, LatLng coordinates) onLocationSelected;
  final String? initialValue;
  final LatLng? biasLocation; // To bias search results towards a specific area

  const LocationSearchField({
    Key? key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onLocationSelected,
    this.initialValue,
    this.biasLocation,
    this.iconColor = Colors.grey,
  }) : super(key: key);

  @override
  State<LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<LocationSearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final OlaMapsService _routeService = OlaMapsService();
  
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  String _searchQuery = '';
  Timer? _debounceTimer; // Add debounce timer
  
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      _controller.text = widget.initialValue!;
    }
    
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // Show overlay if we have suggestions or if we're searching when field gains focus
        if (_suggestions.isNotEmpty || _isLoading) {
          _showOverlay();
        }
      } else {
        // Hide overlay and reset when field loses focus
        _hideOverlay();
        setState(() {
          _suggestions = [];
          _isLoading = false;
          _searchQuery = ''; // Reset search query when focus is lost
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel(); // Cancel any pending timer
    _hideOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showOverlay() {
    // Always recreate the overlay to ensure it shows the latest suggestions
    _hideOverlay();
    
    // Show overlay if we have focus, even if suggestions are empty (to show "No locations found")
    if (_focusNode.hasFocus) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 5.0),
          child: Material(
            elevation: 8.0,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : _suggestions.isEmpty
                      ? _searchQuery.trim().isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'No locations found',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            )
                          : const SizedBox.shrink() // Don't show anything if no search has been made
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return _buildSuggestionItem(suggestion);
                          },
                        ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(Map<String, dynamic> suggestion) {
    return InkWell(
      onTap: () => _selectLocation(suggestion),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion['name'] ?? 'Unknown location',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (suggestion['address'] != null && 
                      suggestion['address'].toString().isNotEmpty &&
                      suggestion['address'] != suggestion['name'])
                    Text(
                      suggestion['address'],
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (suggestion['country'] == 'India' || suggestion['country'] == 'IN')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'India',
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.green.shade700,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _selectLocation(Map<String, dynamic> location) {
    final name = location['name'] ?? 'Unknown location';
    final lat = location['latitude']?.toDouble();
    final lng = location['longitude']?.toDouble();
    
    if (lat != null && lng != null) {
      setState(() {
        _controller.text = name;
      });
      _hideOverlay();
      _focusNode.unfocus();
      
      widget.onLocationSelected(name, LatLng(lat, lng));
    }
  }

  Future<void> _searchLocations(String query) async {
    final trimmedQuery = query.trim();
    
    if (trimmedQuery.isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      _hideOverlay();
      return;
    }

    // Don't search if it's the same as the last search
    if (_searchQuery == trimmedQuery) {
      debugPrint('Skipping duplicate search for: "$trimmedQuery"');
      return;
    }

    setState(() {
      _isLoading = true;
      _searchQuery = trimmedQuery;
    });

    debugPrint('Starting search for: "$trimmedQuery"');

    try {
      final results = await _routeService.searchLocations(
        trimmedQuery,
        biasLocation: widget.biasLocation,
      );
      
      // Only update if this is still the current search and widget is still mounted
      if (_searchQuery == trimmedQuery && mounted) {
        debugPrint('Search completed for: "$trimmedQuery" - Found ${results.length} results');
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
        
        // Always try to show overlay if we have focus, regardless of whether we have results
        if (_focusNode.hasFocus) {
          _showOverlay(); // This will show results or "No locations found" message
        } else {
          _hideOverlay();
        }
      } else {
        debugPrint('Search result discarded for: "$trimmedQuery" (query changed or widget disposed)');
      }
    } catch (e) {
      // Only update if this is still the current search and widget is still mounted
      if (_searchQuery == trimmedQuery && mounted) {
        debugPrint('Search failed for: "$trimmedQuery" - Error: $e');
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
        _hideOverlay();
        
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to search locations: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Ensure focus is given to the text field when tapped
        if (!_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            border: const OutlineInputBorder(),
            prefixIcon: Icon(widget.icon, color: widget.iconColor),
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _suggestions = [];
                            _isLoading = false;
                            _searchQuery = ''; // Reset search query
                          });
                          _hideOverlay();
                          _debounceTimer?.cancel(); // Cancel any pending search
                        },
                      )
                    : null,
          ),
          onChanged: (value) {
            // Cancel previous timer if it exists
            _debounceTimer?.cancel();
            
            // Always reset loading state when user is typing
            if (_isLoading) {
              setState(() {
                _isLoading = false;
              });
            }
            
            if (value.trim().length >= 2) {
              // Start new timer for debouncing with 1 second delay as requested
              _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
                if (mounted && _controller.text.trim() == value.trim()) {
                  debugPrint('Searching for: "$value"');
                  _searchLocations(value.trim());
                }
              });
            } else {
              // Clear suggestions for short text
              setState(() {
                _suggestions = [];
                _isLoading = false;
                _searchQuery = ''; // Reset search query for short text
              });
              _hideOverlay();
            }
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a location';
            }
            return null;
          },
        ),
      ),
    );
  }
}
