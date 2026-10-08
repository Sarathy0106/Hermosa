import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

class CoverImage extends StatelessWidget {
  final String url;
  final double? size;
  final double radius;
  final BoxFit fit;

  const CoverImage({
    super.key,
    required this.url,
    this.size,
    this.radius = 12,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = (size != null && size!.isFinite) ? size : null;
    final effectiveHeight = (size != null && size!.isFinite) ? size : null;

    final placeholder = Container(
      width: effectiveWidth,
      height: effectiveHeight,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: AppColors.textSecondary,
        ),
      ),
    );

    if (url.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}
