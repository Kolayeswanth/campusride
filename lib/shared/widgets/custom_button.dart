import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';

/// Button types for CustomButton.
enum ButtonType {
  primary,
  secondary,
  text,
  outlined,
  glass,
}

/// Button sizes for CustomButton.
enum ButtonSize {
  small,
  medium,
  large,
}

/// A custom button widget with various styles and configurations.
class CustomButton extends StatelessWidget {
  /// The button's label text.
  final String text;
  
  /// The callback when the button is pressed.
  final VoidCallback? onPressed;
  
  /// The icon to display before the text.
  final IconData? prefixIcon;
  
  /// The icon to display after the text.
  final IconData? suffixIcon;
  
  /// The type of button to display.
  final ButtonType type;
  
  /// The size of the button.
  final ButtonSize size;
  
  /// Whether the button is loading.
  final bool isLoading;
  
  /// Whether the button expands to fill available width.
  final bool isFullWidth;
  
  /// The color of the button (overrides the type's default color).
  final Color? color;

  /// Creates a CustomButton.
  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.prefixIcon,
    this.suffixIcon,
    this.type = ButtonType.primary,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = false,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate padding based on size
    EdgeInsetsGeometry padding;
    double? height;
    double iconSize;
    TextStyle textStyle;
    
    switch (size) {
      case ButtonSize.small:
        padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
        height = 36;
        iconSize = 18;
        textStyle = AppTypography.buttonSmall;
        break;
      case ButtonSize.medium:
        padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
        height = 48;
        iconSize = 20;
        textStyle = AppTypography.buttonMedium;
        break;
      case ButtonSize.large:
        padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
        height = 56;
        iconSize = 24;
        textStyle = AppTypography.buttonLarge;
        break;
    }
    
    // Build the child widget
    Widget childWidget = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (prefixIcon != null && !isLoading) ...[
          Icon(prefixIcon, size: iconSize),
          const SizedBox(width: 8),
        ],
        if (isLoading)
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getTextColor(),
              ),
            ),
          ),
        if (isLoading) const SizedBox(width: 8),
        Text(
          text,
          style: textStyle.copyWith(color: _getTextColor()),
        ),
        if (suffixIcon != null && !isLoading) ...[
          const SizedBox(width: 8),
          Icon(suffixIcon, size: iconSize),
        ],
      ],
    );
    
    // Create the appropriate button based on type
    Widget buttonWidget;
    
    switch (type) {
      case ButtonType.primary:
        buttonWidget = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? AppColors.primary,
            foregroundColor: Colors.white,
            padding: padding,
            minimumSize: Size(isFullWidth ? double.infinity : 0, height),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: childWidget,
        );
        break;
        
      case ButtonType.secondary:
        buttonWidget = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? AppColors.secondary,
            foregroundColor: Colors.white,
            padding: padding,
            minimumSize: Size(isFullWidth ? double.infinity : 0, height),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: childWidget,
        );
        break;
        
      case ButtonType.outlined:
        buttonWidget = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color ?? AppColors.primary,
            side: BorderSide(color: color ?? AppColors.primary, width: 1.5),
            padding: padding,
            minimumSize: Size(isFullWidth ? double.infinity : 0, height),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: childWidget,
        );
        break;
        
      case ButtonType.text:
        buttonWidget = TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: color ?? AppColors.primary,
            padding: padding,
            minimumSize: Size(isFullWidth ? double.infinity : 0, height),
          ),
          child: childWidget,
        );
        break;
        
      case ButtonType.glass:
        buttonWidget = Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: padding,
              height: height,
              width: isFullWidth ? double.infinity : null,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.glassBorder,
                  width: 1.5,
                ),
                color: AppColors.glassFill,
              ),
              child: childWidget,
            ),
          ),
        );
        break;
    }
    
    return buttonWidget;
  }
  
  /// Gets the text color based on the button type.
  Color _getTextColor() {
    switch (type) {
      case ButtonType.primary:
      case ButtonType.secondary:
        return Colors.white;
      case ButtonType.text:
      case ButtonType.outlined:
      case ButtonType.glass:
        return color ?? AppColors.primary;
    }
  }
  
  /// Creates a primary button.
  factory CustomButton.primary({
    required String text,
    required VoidCallback? onPressed,
    IconData? prefixIcon,
    IconData? suffixIcon,
    ButtonSize size = ButtonSize.medium,
    bool isLoading = false,
    bool isFullWidth = false,
    Color? color,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      type: ButtonType.primary,
      size: size,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      color: color,
    );
  }
  
  /// Creates a secondary button.
  factory CustomButton.secondary({
    required String text,
    required VoidCallback? onPressed,
    IconData? prefixIcon,
    IconData? suffixIcon,
    ButtonSize size = ButtonSize.medium,
    bool isLoading = false,
    bool isFullWidth = false,
    Color? color,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      type: ButtonType.secondary,
      size: size,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      color: color,
    );
  }
  
  /// Creates an outlined button.
  factory CustomButton.outlined({
    required String text,
    required VoidCallback? onPressed,
    IconData? prefixIcon,
    IconData? suffixIcon,
    ButtonSize size = ButtonSize.medium,
    bool isLoading = false,
    bool isFullWidth = false,
    Color? color,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      type: ButtonType.outlined,
      size: size,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      color: color,
    );
  }
  
  /// Creates a text button.
  factory CustomButton.text({
    required String text,
    required VoidCallback? onPressed,
    IconData? prefixIcon,
    IconData? suffixIcon,
    ButtonSize size = ButtonSize.medium,
    bool isLoading = false,
    bool isFullWidth = false,
    Color? color,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      type: ButtonType.text,
      size: size,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      color: color,
    );
  }
  
  /// Creates a glass button.
  factory CustomButton.glass({
    required String text,
    required VoidCallback? onPressed,
    IconData? prefixIcon,
    IconData? suffixIcon,
    ButtonSize size = ButtonSize.medium,
    bool isLoading = false,
    bool isFullWidth = false,
    Color? color,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      type: ButtonType.glass,
      size: size,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      color: color,
    );
  }
  
  /// Creates a small primary button.
  factory CustomButton.small({
    required String text,
    required VoidCallback? onPressed,
    IconData? prefixIcon,
    IconData? suffixIcon,
    ButtonType type = ButtonType.primary, 
    bool isLoading = false,
    bool isFullWidth = false,
    Color? color,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      type: type,
      size: ButtonSize.small,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      color: color,
    );
  }
} 