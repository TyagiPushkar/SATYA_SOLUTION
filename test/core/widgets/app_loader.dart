import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';
import './app_text.dart';

class AppLoader extends StatelessWidget {
  final Color? color;
  
  const AppLoader({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? AppColors.primary;
    final highlightColor = baseColor.withValues(alpha: 0.4);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  'SatyaSolution',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: baseColor,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: baseColor,
                      shape: BoxShape.circle,
                    ),
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
