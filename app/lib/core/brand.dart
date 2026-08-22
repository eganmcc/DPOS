import 'package:flutter/material.dart';
import 'theme.dart';

/// AppBar with the navy brand gradient behind it (Direction A).
class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandAppBar({super.key, this.title, this.actions, this.leading});

  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final ext = brandColors(context);
    return AppBar(
      title: title,
      actions: actions,
      leading: leading,
      toolbarHeight: 64,
      iconTheme: IconThemeData(color: ext.onGradient),
      flexibleSpace: Container(
        decoration: BoxDecoration(gradient: ext.headerGradient),
      ),
    );
  }
}

/// Navy gradient box decoration for panels (checkout total, sticky bars).
BoxDecoration brandGradient(BuildContext context, {double radius = 20, List<BoxShadow>? shadow}) {
  return BoxDecoration(
    gradient: brandColors(context).headerGradient,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: shadow,
  );
}
