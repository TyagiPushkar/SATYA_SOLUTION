import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final Widget? prefixIcon;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLines;

  final Color? fillColor;
  final Color? borderColor;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  const AppTextField({
    super.key,
    this.controller,
    required this.hint,
    this.prefixIcon,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines,
    this.fillColor,
    this.borderColor,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
    this.inputFormatters,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: obscureText ? 1 : maxLines,
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: const TextStyle(
          color: Colors.black38,
          fontSize: 14,
        ),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor ?? AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor ?? AppColors.borderGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor ?? AppColors.borderGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryOrange),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
      ),
    );
  }
}
