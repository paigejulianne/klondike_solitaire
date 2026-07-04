import 'package:flutter/material.dart';

import 'widgets/game_screen.dart';

void main() {
  runApp(const KlondikeApp());
}

class KlondikeApp extends StatelessWidget {
  const KlondikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Klondike Solitaire',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}
