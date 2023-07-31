import 'package:flutter/material.dart';
import './entry.dart' as widgets;

class FormField extends StatelessWidget {
  const FormField({
    super.key,
    required this.title,
    required this.formWidget
  });

  final String title;
  final Widget formWidget;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return widgets.Card(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18)),
          formWidget
        ],
      ),
    );
  }
}
