import 'package:flutter/material.dart';

import '../models/game_state.dart';
import 'game_board.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameState gameState = GameState();
  bool _winDialogShown = false;

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

  void _onGameChanged() {
    setState(() {});
    if (gameState.won && !_winDialogShown) {
      _winDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWinDialog());
    }
  }

  void _newGame() {
    _winDialogShown = false;
    gameState.newGame();
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('You Win!'),
        content: Text('Solved in ${gameState.moves} moves.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _newGame();
            },
            child: const Text('New Game'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B6623),
      appBar: AppBar(
        title: const Text('Klondike Solitaire'),
        backgroundColor: const Color(0xFF0A5A1F),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Text('Moves: ${gameState.moves}', style: const TextStyle(color: Colors.white70))),
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
            onPressed: _newGame,
          ),
        ],
      ),
      body: SafeArea(child: GameBoard(gameState: gameState)),
    );
  }
}
