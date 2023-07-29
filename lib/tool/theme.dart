import 'package:flutter/material.dart';

class AppTheme {
  static Color themeColor = Colors.purple.shade200;
  static MaterialStateProperty<Color> stateProperty =
      MaterialStateProperty.all<Color>(themeColor);
}
