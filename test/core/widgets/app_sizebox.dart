import 'package:flutter/material.dart';

class AppSizeBox extends StatelessWidget {
  final double? width;
  final double? height;

  const AppSizeBox({super.key, this.width, this.height});

  const AppSizeBox.h(this.height, {super.key}) : width = null;

  const AppSizeBox.w(this.width, {super.key}) : height = null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
    );
  }
}
