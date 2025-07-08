import 'package:flutter/material.dart';

class MapConstants {
  // Zoom levels
  static const double defaultZoom = 15.0;
  static const double destinationZoom = 16.0;
  static const double liveLocationZoom = 18.0; // Approximately 100 meters view
  static const double overviewZoom = 12.0;
  
  // Animation durations
  static const Duration cameraAnimationDuration = Duration(milliseconds: 500);
  static const Duration notificationDuration = Duration(seconds: 5);
  static const Duration locationUpdateInterval = Duration(seconds: 2);
  
  // Location update settings
  static const double locationUpdateDistance = 10.0; // meters
  
  // UI Constants
  static const double speedIndicatorSize = 60.0;
  static const double locationSymbolSize = 40.0;
  static const double bottomPanelHeight = 120.0;
  static const double notificationBannerHeight = 60.0;
  static const double defaultBorderRadius = 12.0;
  static const double defaultPadding = 16.0;
  static const double defaultMargin = 8.0;
  static const double notificationBorderRadius = 12.0;
  static const EdgeInsets notificationPadding = EdgeInsets.all(16.0);
  
  // Colors
  static const Color notificationBackground = Color(0xFF333333);
  static const Color notificationText = Colors.white;
  static const Color speedIndicatorBackground = Color(0xFF2196F3);
  static const Color locationSymbolBackground = Color(0xFF4CAF50);
  
  // Village tracking
  static const double villageDetectionRadius = 100.0; // meters
  static const int maxVillageNotifications = 5;
} 