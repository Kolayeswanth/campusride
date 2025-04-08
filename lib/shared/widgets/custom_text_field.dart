import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/theme.dart';

/// A custom text field with consistent styling for the app.
class CustomTextField extends StatelessWidget {
  /// The controller for the text field.
  final TextEditingController controller;
  
  /// The label text to display.
  final String label;
  
  /// The hint text to display.
  final String? hint;
  
  /// The icon to display at the start of the field.
  final IconData? prefixIcon;
  
  /// The icon to display at the end of the field.
  final IconData? suffixIcon;
  
  /// Callback for when the suffix icon is tapped.
  final VoidCallback? onSuffixIconTap;
  
  /// Whether the text should be obscured (for passwords).
  final bool obscureText;
  
  /// The keyboard type to use.
  final TextInputType keyboardType;
  
  /// The input formatters to apply.
  final List<TextInputFormatter>? inputFormatters;
  
  /// The text capitalization to use.
  final TextCapitalization textCapitalization;
  
  /// The validator function.
  final String? Function(String?)? validator;
  
  /// Whether the field is enabled.
  final bool enabled;
  
  /// Whether the field should auto-focus.
  final bool autofocus;
  
  /// The text style for the field.
  final TextStyle? style;
  
  /// Maximum lines for the field.
  final int? maxLines;
  
  /// Minimum lines for the field.
  final int? minLines;
  
  /// Maximum length of text.
  final int? maxLength;
  
  /// Callback for when the field changes.
  final Function(String)? onChanged;
  
  /// Custom decoration to override the default.
  final InputDecoration? decoration;

  /// Creates a CustomTextField.
  const CustomTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.style,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.decoration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      enabled: enabled,
      autofocus: autofocus,
      style: style ?? AppTypography.bodyLarge.copyWith(
        color: AppColors.textPrimary,
      ),
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      decoration: decoration ?? InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon != null
            ? GestureDetector(
                onTap: onSuffixIconTap,
                child: Icon(suffixIcon),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.textHint.withOpacity(0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.textHint.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.error,
          ),
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
} 