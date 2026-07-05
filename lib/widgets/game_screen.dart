import 'package:flutter/material.dart';

import '../models/game_state.dart';
import 'app_theme_scope.dart';
import 'appearance_sheet.dart';
import 'game_board.dart';
import 'win_celebration.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameState gameState = GameState();

  @override
  void initState() {
    super.initState();
    gameState.addListener(_onGameChanged);
  }

  @override
  void dispose() {
    gameState.removeListener(_onGameChanged);
    gameState.dispose();
    super.dispose();
  }

  void _onGameChanged() => setState(() {});

  void _newGame() => gameState.newGame();

  Future<void> _confirmNewGame() async {
    if (gameState.moves == 0 || gameState.won) {
      _newGame();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Game?'),
        content: const Text('Your current game progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('New Game'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) _newGame();
  }

  @override
  Widget build(BuildContext context) {
    final tableTheme = AppThemeScope.of(context).tableTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Klondike Solitaire'),
        backgroundColor: tableTheme.gradient.last,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Text('Moves: ${gameState.moves}', style: const TextStyle(color: Colors.white70))),
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Appearance',
            onPressed: () => showAppearanceSheet(context),
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.tune),
            tooltip: 'Draw count',
            onSelected: gameState.setDrawCount,
            itemBuilder: (context) => [
              CheckedPopupMenuItem(value: 1, checked: gameState.drawCount == 1, child: const Text('Draw 1')),
              CheckedPopupMenuItem(value: 3, checked: gameState.drawCount == 3, child: const Text('Draw 3')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: gameState.canUndo ? gameState.undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New Game',
            onPressed: _confirmNewGame,
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: tableTheme.gradient,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              GameBoard(gameState: gameState),
              if (gameState.won) WinCelebration(moves: gameState.moves, onNewGame: _newGame),
            ],
          ),
        ),
      ),
    );
  }
}
