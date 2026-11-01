import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
  });

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600 && tablet != null) {
          return tablet!;
        }
        return mobile;
      },
    );
  }
}
