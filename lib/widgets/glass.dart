import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted-glass panel: background blur + translucent tint + hairline border.
class Glass extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final Color tint;
  final EdgeInsetsGeometry? padding;
  final Border? border;

  const Glass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.blur = 22,
    this.tint = const Color(0x2E1B1B29),
    this.padding,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: borderRadius,
            border: border ??
                Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Shows a modal bottom sheet with frosted-glass chrome.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Glass(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      tint: const Color(0xD912121C),
      blur: 28,
      child: builder(ctx),
    ),
  );
}
