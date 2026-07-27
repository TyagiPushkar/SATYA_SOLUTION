import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import './app_text.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool centerTitle;
  final Color backgroundColor;
  final Color textColor;
  final Widget? leading;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.centerTitle = false,
    this.backgroundColor = AppColors.background,
    this.textColor = AppColors.black,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0,
      centerTitle: centerTitle,
      iconTheme: IconThemeData(color: textColor),
      title: AppText(
        title,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      actions: actions,
      leading: leading,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
