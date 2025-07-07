import 'package:flutter/material.dart';
import '../constants/map_constants.dart';

class VillageNotification extends StatelessWidget {
  final String villageName;
  final String time;
  final VoidCallback? onDismiss;

  const VillageNotification({
    Key? key,
    required this.villageName,
    required this.time,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MapConstants.notificationBannerHeight,
      margin: MapConstants.notificationPadding,
      decoration: BoxDecoration(
        color: MapConstants.notificationBackground,
        borderRadius: BorderRadius.circular(MapConstants.notificationBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onDismiss,
          borderRadius: BorderRadius.circular(MapConstants.notificationBorderRadius),
          child: Padding(
            padding: MapConstants.notificationPadding,
            child: Row(
              children: [
                const Icon(
                  Icons.location_city,
                  color: MapConstants.notificationText,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Crossed $villageName',
                        style: const TextStyle(
                          color: MapConstants.notificationText,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'at $time',
                        style: const TextStyle(
                          color: MapConstants.notificationText,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: MapConstants.notificationText,
                  ),
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 