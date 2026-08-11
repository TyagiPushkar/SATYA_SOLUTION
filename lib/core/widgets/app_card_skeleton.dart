import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AppCardSkeleton extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const AppCardSkeleton({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.shrinkWrap = false,
    this.physics = const NeverScrollableScrollPhysics(),
  });

  const AppCardSkeleton.single({super.key, this.padding = EdgeInsets.zero})
    : itemCount = 1,
      shrinkWrap = true,
      physics = const NeverScrollableScrollPhysics();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: padding,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 16.0, 16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 140,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 70,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 220,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 160,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
