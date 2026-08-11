import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';
import './app_text.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isLoading;
  final double? width;
  final Color? color;
  final Color? textColor;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const AppButton({
    super.key,
    required this.text,
    required this.onTap,
    this.isLoading = false,
    this.width,
    this.color,
    this.textColor,
    this.fontSize,
    this.padding,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppColors.primary,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: isLoading
             ? Shimmer.fromColors(
                 baseColor: Colors.white.withValues(alpha: 0.3),
                 highlightColor: Colors.white.withValues(alpha: 0.6),
                 child: Container(
                   height: 20,
                   width: 100,
                   decoration: BoxDecoration(
                     color: Colors.white,
                     borderRadius: BorderRadius.circular(4),
                   ),
                 ),
               )
            : AppText(
                text,
                color: textColor ?? AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: fontSize ?? 16,
              ),
      ),
    );
  }
}
