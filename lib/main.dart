import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import './pages/entry.dart';
import './tools/theme.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '图片下载器',
      theme: ThemeData(
          useMaterial3: true,
          scrollbarTheme:
              ScrollbarThemeData(thumbColor: AppTheme.stateProperty),
          iconButtonTheme: IconButtonThemeData(
              style: ButtonStyle(iconColor: AppTheme.stateProperty))),
      home: const HomePage(title: '图片下载器'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      supportedLocales: const [Locale('zh', 'CN')],
    );
  }
}
