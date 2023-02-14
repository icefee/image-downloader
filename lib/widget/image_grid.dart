import 'package:flutter/material.dart';

class ImageGrid extends StatelessWidget {

  final bool removing;
  final Widget child;
  final Animation<double> animation;

  const ImageGrid({
    super.key,
    required this.child,
    required this.animation,
    this.removing = false
  });

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return ScaleTransition(
      scale: CurvedAnimation(
          curve: removing ? Curves.easeInOut : Curves.bounceOut,
          parent: animation
      ),
      child: child,
    );
  }
}
