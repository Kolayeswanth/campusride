import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';

/// A glassmorphic container widget that creates a frosted glass effect.
class GlassmorphicContainer extends StatelessWidget {
  /// The child widget.
  final Widget child;
  
  /// The width of the container.
  final double? width;
  
  /// The height of the container.
  final double? height;
  
  /// The border radius of the container.
  final BorderRadius borderRadius;
  
  /// The color of the container's border.
  final Color borderColor;
  
  /// The width of the container's border.
  final double borderWidth;
  
  /// The color of the container's background.
  final Color fillColor;
  
  /// The blur intensity of the glass effect.
  final double blur;
  
  /// The opacity of the container.
  final double opacity;
  
  /// The padding inside the container.
  final EdgeInsetsGeometry padding;
  
  /// The margin around the container.
  final EdgeInsetsGeometry margin;
  
  /// Creates a GlassmorphicContainer.
  const GlassmorphicContainer({
    Key? key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.borderColor = AppColors.glassBorder,
    this.borderWidth = 1.5,
    this.fillColor = AppColors.glassFill,
    this.blur = 10.0,
    this.opacity = 0.7,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blur,
            sigmaY: blur,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: borderRadius,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
  
  /// Creates a large version of the container with predefined properties.
  factory GlassmorphicContainer.large({
    required Widget child,
    double? width,
    double? height,
    EdgeInsetsGeometry padding = const EdgeInsets.all(24),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
  }) {
    return GlassmorphicContainer(
      child: child,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(24),
      padding: padding,
      margin: margin,
      blur: 15.0,
    );
  }
  
  /// Creates a medium version of the container with predefined properties.
  factory GlassmorphicContainer.medium({
    required Widget child,
    double? width,
    double? height,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
  }) {
    return GlassmorphicContainer(
      child: child,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(16),
      padding: padding,
      margin: margin,
    );
  }
  
  /// Creates a small version of the container with predefined properties.
  factory GlassmorphicContainer.small({
    required Widget child,
    double? width,
    double? height,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
  }) {
    return GlassmorphicContainer(
      child: child,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(12),
      borderWidth: 1.0,
      padding: padding,
      margin: margin,
      blur: 8.0,
    );
  }
} 