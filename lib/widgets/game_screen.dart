import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_state.dart';
import 'app_theme_scope.dart';
import 'appearance_sheet.dart';
import 'game_board.dart';
import 'win_celebration.dart';

/// Key the in-progress game is auto-saved under.
const _autoSaveKey = 'game.autosave';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameState gameState = GameState(deal: false);

  Timer? _solveTimer;
  Timer? _clockTicker;
  Timer? _saveDebounce;
  Timer? _hintTimer;

  /// Set once the saved game has been read, so we don't overwrite it with an
  /// empty board before it loads.
  bool _loaded = false;

  static const _solveInterval = Duration(milliseconds: 120);

  bool get _solving => _solveTimer != null;

  @override
  void initState() {
    super.initState();
    gameState.addListener(_onGameChanged);
    gameState.onPersist = _schedulePersist;
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !gameState.won && gameState.moves > 0) setState(() {});
    });
    _restoreOrDeal();
  }

  @override
  void dispose() {
    _solveTimer?.cancel();
    _clockTicker?.cancel();
    _saveDebounce?.cancel();
    _hintTimer?.cancel();
    gameState.onPersist = null;
    gameState.removeListener(_onGameChanged);
    gameState.dispose();
    super.dispose();
  }

  void _onGameChanged() => setState(() {});

  // ---- Persistence ----

  Future<void> _restoreOrDeal() async {
    String? saved;
    try {
      final prefs = await SharedPreferences.getInstance();
      saved = prefs.getString(_autoSaveKey);
    } catch (_) {
      // Storage unavailable (private mode, tests) - just deal a new game.
    }
    if (!mounted) return;
    _loaded = true;
    if (!gameState.restore(saved)) gameState.newGame();
  }

  void _schedulePersist() {
    if (!_loaded) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), _persist);
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (gameState.won) {
        await prefs.remove(_autoSaveKey);
      } else {
        await prefs.setString(_autoSaveKey, gameState.encode());
      }
    } catch (_) {
      // Saving is best-effort; never let it break the game.
    }
  }

  // ---- Actions ----

  void _newGame() {
    _stopSolve();
    gameState.newGame();
  }

  Future<void> _confirmNewGame() async {
    _stopSolve();
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

  void _undo() {
    _stopSolve();
    gameState.undo();
  }

  void _redo() {
    _stopSolve();
    gameState.redo();
  }

  void _draw() {
    _stopSolve();
    gameState.tapStock();
  }

  void _hint() {
    _stopSolve();
    gameState.showHint();
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) gameState.clearHint();
    });
    final hint = gameState.activeHint;
    if (hint == null && mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('No moves available'),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  /// Runs the autoplay cascade one move at a time so it can be watched, with
  /// the whole run collapsed into a single undo step.
  void _toggleSolve() {
    if (_solving) {
      _stopSolve();
      return;
    }
    if (gameState.won || !gameState.canSolve) return;
    gameState.beginBatch();
    if (!gameState.solveStep()) {
      gameState.endBatch();
      return;
    }
    setState(() {
      _solveTimer = Timer.periodic(_solveInterval, (_) {
        if (!gameState.solveStep()) _stopSolve();
      });
    });
  }

  void _stopSolve() {
    if (_solveTimer == null) return;
    _solveTimer!.cancel();
    _solveTimer = null;
    gameState.endBatch();
    if (mounted) setState(() {});
  }

  void _showShortcuts() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keyboard Shortcuts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _ShortcutRow('Space', 'Draw from the stock'),
            _ShortcutRow('S', 'Solve / stop solving'),
            _ShortcutRow('H', 'Hint'),
            _ShortcutRow('Ctrl+Z', 'Undo'),
            _ShortcutRow('Ctrl+Y', 'Redo'),
            _ShortcutRow('N', 'New game'),
            _ShortcutRow('Esc', 'Cancel selection'),
            SizedBox(height: 12),
            Text(
              'Double-click a card to send it to a foundation.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> get _bindings => {
        const SingleActivator(LogicalKeyboardKey.space): _draw,
        const SingleActivator(LogicalKeyboardKey.keyS): _toggleSolve,
        const SingleActivator(LogicalKeyboardKey.keyH): _hint,
        const SingleActivator(LogicalKeyboardKey.keyN): _confirmNewGame,
        const SingleActivator(LogicalKeyboardKey.escape): gameState.clearSelection,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
        const SingleActivator(LogicalKeyboardKey.keyY, meta: true): _redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
            _redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            _redo,
      };

  // ---- Build ----

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final tableTheme = AppThemeScope.of(context).tableTheme;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final stuck =
        _loaded && !gameState.won && !_solving && gameState.isStuck;

    return CallbackShortcuts(
      bindings: _bindings,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: wide ? null : 8,
            title: wide
                ? const Text('Klondike Solitaire')
                : _Stats(gameState: gameState, compact: true),
            backgroundColor: tableTheme.gradient.last,
            foregroundColor: Colors.white,
            actions: [
              if (wide) _Stats(gameState: gameState, compact: false),
              IconButton(
                icon: const Icon(Icons.lightbulb_outline),
                tooltip: 'Hint (H)',
                onPressed: gameState.won ? null : _hint,
              ),
              IconButton(
                icon: Icon(_solving ? Icons.stop_circle_outlined : Icons.auto_awesome),
                tooltip: _solving ? 'Stop solving (S)' : 'Solve (S)',
                color: _solving ? Colors.amberAccent : null,
                onPressed:
                    _solving || gameState.canSolve ? _toggleSolve : null,
              ),
              IconButton(
                icon: const Icon(Icons.undo),
                tooltip: 'Undo (Ctrl+Z)',
                onPressed: gameState.canUndo ? _undo : null,
              ),
              IconButton(
                icon: const Icon(Icons.redo),
                tooltip: 'Redo (Ctrl+Y)',
                onPressed: gameState.canRedo ? _redo : null,
              ),
              if (wide)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'New Game (N)',
                  onPressed: _confirmNewGame,
                ),
              PopupMenuButton<_MenuAction>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'More',
                onSelected: _onMenuSelected,
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(
                    value: _MenuAction.draw1,
                    checked: gameState.drawCount == 1,
                    child: const Text('Draw 1'),
                  ),
                  CheckedPopupMenuItem(
                    value: _MenuAction.draw3,
                    checked: gameState.drawCount == 3,
                    child: const Text('Draw 3'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: _MenuAction.appearance,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.palette_outlined),
                      title: Text('Appearance'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: _MenuAction.shortcuts,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.keyboard_outlined),
                      title: Text('Keyboard shortcuts'),
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: _MenuAction.newGame,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.refresh),
                      title: Text('New Game'),
                    ),
                  ),
                ],
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
                  // Any touch on the table interrupts an in-progress solve.
                  Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (_) => _stopSolve(),
                    child: GameBoard(gameState: gameState),
                  ),
                  if (gameState.activeHint != null)
                    _HintBanner(text: gameState.activeHint!.description),
                  if (stuck) _StuckBanner(onUndo: _undo, onNewGame: _newGame),
                  if (gameState.won)
                    WinCelebration(
                      moves: gameState.moves,
                      elapsed: gameState.elapsed,
                      score: gameState.score,
                      onNewGame: _newGame,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onMenuSelected(_MenuAction action) {
    switch (action) {
      case _MenuAction.draw1:
        gameState.setDrawCount(1);
      case _MenuAction.draw3:
        gameState.setDrawCount(3);
      case _MenuAction.appearance:
        showAppearanceSheet(context);
      case _MenuAction.shortcuts:
        _showShortcuts();
      case _MenuAction.newGame:
        _confirmNewGame();
    }
  }
}

enum _MenuAction { draw1, draw3, appearance, shortcuts, newGame }

class _Stats extends StatelessWidget {
  final GameState gameState;
  final bool compact;

  const _Stats({required this.gameState, required this.compact});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Colors.white.withValues(alpha: 0.85),
      fontSize: compact ? 13 : 14,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget item(IconData icon, String value) => Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 15 : 16, color: Colors.white70),
              const SizedBox(width: 4),
              Text(value, style: style),
            ],
          ),
        );

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(Icons.timer_outlined,
              _GameScreenState._formatDuration(gameState.elapsed)),
          item(Icons.swap_horiz, '${gameState.moves}'),
          item(Icons.star_outline, '${gameState.score}'),
        ],
      ),
    );
  }
}

class _HintBanner extends StatelessWidget {
  final String text;
  const _HintBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 16,
      child: IgnorePointer(
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width - 48,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.6)),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.amberAccent, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}

class _StuckBanner extends StatelessWidget {
  final VoidCallback onUndo;
  final VoidCallback onNewGame;

  const _StuckBanner({required this.onUndo, required this.onNewGame});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 16,
      child: Center(
        child: Material(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                const Icon(Icons.block, color: Colors.orangeAccent, size: 18),
                const Text(
                  'No moves left',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                TextButton(onPressed: onUndo, child: const Text('Undo')),
                TextButton(onPressed: onNewGame, child: const Text('New Game')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String keys;
  final String description;
  const _ShortcutRow(this.keys, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(keys, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(description)),
        ],
      ),
    );
  }
}
