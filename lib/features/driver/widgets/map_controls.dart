import 'package:flutter/material.dart';

class MapControls extends StatelessWidget {
  final Function() onCenterLocation;
  final Function() onToggleUIVisibility;
  final bool isUIVisible;

  const MapControls({
    Key? key,
    required this.onCenterLocation,
    required this.onToggleUIVisibility,
    required this.isUIVisible,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Location button
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCenterLocation,
              borderRadius: BorderRadius.circular(8.0),
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Icon(
                  Icons.my_location,
                  color: Colors.blue,
                  size: 28.0,
                ),
              ),
            ),
          ),
        ),

        // UI visibility toggle button
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggleUIVisibility,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Icon(
                  isUIVisible ? Icons.visibility_off : Icons.visibility,
                  color: Colors.blue,
                  size: 24.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
