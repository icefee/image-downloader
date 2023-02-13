import 'package:flutter/material.dart';

class Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  const Card({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.all(8.0)
  });

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(
      padding: const EdgeInsets.all(12),
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.0)
      ),
      child: child,
    );
  }
}
