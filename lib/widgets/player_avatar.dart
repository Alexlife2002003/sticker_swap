import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A smart image widget that automatically renders SVG avatars using flutter_svg
/// and falls back to a soccer icon on any load error.
/// 
/// DiceBear returns SVG format URLs (e.g. .../svg?seed=...).
/// Android cannot natively decode SVG, so we detect it and use SvgPicture.network.
class PlayerAvatar extends StatelessWidget {
  final String url;
  final double? size;
  final BoxFit fit;

  const PlayerAvatar({
    super.key,
    required this.url,
    this.size,
    this.fit = BoxFit.contain,
  });

  bool get _isSvg =>
      url.contains('/svg') || url.endsWith('.svg') || url.contains('svg?');

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      Icons.sports_soccer,
      size: size != null ? size! * 0.6 : 24,
      color: Colors.white54,
    );

    if (_isSvg) {
      return SvgPicture.network(
        url,
        width: size,
        height: size,
        fit: fit,
        placeholderBuilder: (_) => SizedBox(
          width: size,
          height: size,
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white24),
            ),
          ),
        ),
      );
    }

    return Image.network(
      url,
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
