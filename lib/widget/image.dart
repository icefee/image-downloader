import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CachedImage extends StatelessWidget {
  final String url;

  const CachedImage({
    super.key,
    required this.url
  });

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (BuildContext context, String url) => const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 3
          ),
        ),
      ),
      errorWidget: (BuildContext context, String url, error) =>
      const Icon(Icons.error, size: 36, color: Colors.orange),
    );
  }
}
