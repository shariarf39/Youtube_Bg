import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A rounded, cached YouTube thumbnail with a placeholder and error icon.
class Thumbnail extends StatelessWidget {
  const Thumbnail({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.radius = 8,
  });

  final String url;
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.music_note),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}
