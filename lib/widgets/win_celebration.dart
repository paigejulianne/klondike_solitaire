import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/card.dart';
import 'card_view.dart';

/// Full-screen win celebration: a cascade of bouncing cards (classic
/// Solitaire "you win" effect) plus a panel with the move count and a
/// New Game button.
class WinCelebration extends StatefulWidget {
  final int moves;
  final VoidCallback onNewGame;

  const WinCelebration({super.key, required this.moves, required this.onNewGame});

  @override
  State<WinCelebration> createState() => _WinCelebrationState();
}

class _FallingCard {
  final PlayingCard card;
  Offset pos;
  double vx;
  double vy;
  double rotation;
  final double rotationSpeed;
  int bounces = 0;

  _FallingCard({
    required this.card,
    required this.pos,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class _WinCelebrationState extends State<WinCelebration> with SingleTickerProviderStateMixin {
  static const _cardW = 46.0;
  static const _cardH = _cardW * 1.4;
  static const _gravity = 900.0; // px/s^2
  static const _restitution = 0.6;
  static const _spawnInterval = Duration(milliseconds: 70);
  static const _maxCards = 30;

  late final Ticker _ticker;
  final List<_FallingCard> _cards = [];
  final _rng = Random();
  final List<PlayingCard> _deck = createShuffledDeck()..forEach((c) => c.faceUp = true);

  int _spawned = 0;
  Duration _lastElapsed = Duration.zero;
  Duration _sinceLastSpawn = Duration.zero;
  Size _size = Size.zero;
  bool _showPanel = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _showPanel = true);
    });
  }

  void _onTick(Duration elapsed) {
    if (_size.isEmpty) return;
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0 || dt > 0.05) return; // skip the first tick / a stalled frame

    _sinceLastSpawn += Duration(microseconds: (dt * 1e6).round());
    if (_spawned < _maxCards && _sinceLastSpawn >= _spawnInterval) {
      _sinceLastSpawn = Duration.zero;
      _spawnCard();
    }

    for (final c in _cards) {
      c.vy += _gravity * dt;
      c.pos += Offset(c.vx * dt, c.vy * dt);
      c.rotation += c.rotationSpeed * dt;
      final floor = _size.height - _cardH;
      if (c.pos.dy > floor && c.vy > 0) {
        c.pos = Offset(c.pos.dx, floor);
        c.vy = -c.vy * _restitution;
        c.bounces++;
      }
    }
    _cards.removeWhere((c) => c.bounces > 5 || c.pos.dx < -_cardW * 2 || c.pos.dx > _size.width + _cardW * 2);

    setState(() {});

    if (_spawned >= _maxCards && _cards.isEmpty) {
      _ticker.stop();
    }
  }

  void _spawnCard() {
    final card = _deck[_spawned % _deck.length];
    _spawned++;
    final x = _rng.nextDouble() * max(1.0, _size.width - _cardW);
    _cards.add(_FallingCard(
      card: card,
      pos: Offset(x, -_cardH),
      vx: (_rng.nextDouble() - 0.5) * 220,
      vy: _rng.nextDouble() * 60,
      rotation: (_rng.nextDouble() - 0.5) * 0.6,
      rotationSpeed: (_rng.nextDouble() - 0.5) * 3,
    ));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return Stack(
          children: [
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _showPanel ? 1 : 0,
                child: Container(color: Colors.black54),
              ),
            ),
            for (final c in _cards)
              Positioned(
                left: c.pos.dx,
                top: c.pos.dy,
                child: Transform.rotate(
                  angle: c.rotation,
                  child: CardView(card: c.card, width: _cardW, height: _cardH),
                ),
              ),
            Center(
              child: AnimatedScale(
                scale: _showPanel ? 1 : 0.6,
                duration: const Duration(milliseconds: 450),
                curve: Curves.elasticOut,
                child: AnimatedOpacity(
                  opacity: _showPanel ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: _WinPanel(moves: widget.moves, onNewGame: widget.onNewGame),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WinPanel extends StatelessWidget {
  final int moves;
  final VoidCallback onNewGame;

  const _WinPanel({required this.moves, required this.onNewGame});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(36, 28, 36, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            const Text(
              'You Win!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0A5A1F)),
            ),
            const SizedBox(height: 8),
            Text('Solved in $moves moves', style: const TextStyle(fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onNewGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A5A1F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('New Game', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
