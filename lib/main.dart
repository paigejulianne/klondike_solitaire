import 'package:flutter/material.dart';

import 'models/app_theme.dart';
import 'widgets/app_theme_scope.dart';
import 'widgets/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appTheme = AppTheme();
  await appTheme.load();
  runApp(KlondikeApp(appTheme: appTheme));
}

class KlondikeApp extends StatelessWidget {
  final AppTheme appTheme;

  const KlondikeApp({super.key, required this.appTheme});

  @override
  Widget build(BuildContext context) {
    return AppThemeScope(
      theme: appTheme,
      child: MaterialApp(
        title: 'Klondike Solitaire',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: const GameScreen(),
      ),
    );
  }
}
